import Foundation
import Vapor
import ILSShared

/// Cache entry with timestamp for TTL-based invalidation
private struct CacheEntry<T> {
    let value: T
    let timestamp: Date

    func isValid(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) < ttl
    }
}

/// Actor for thread-safe cache management
private actor MCPCache {
    private var mcpServersCache: CacheEntry<[MCPServer]>?

    /// Default TTL: 30 seconds
    private let defaultTTL: TimeInterval = 30

    func getCachedMCPServers(ttl: TimeInterval? = nil) -> [MCPServer]? {
        guard let cache = mcpServersCache, cache.isValid(ttl: ttl ?? defaultTTL) else {
            return nil
        }
        return cache.value
    }

    func setCachedMCPServers(_ servers: [MCPServer]) {
        mcpServersCache = CacheEntry(value: servers, timestamp: Date())
    }

    func invalidateMCPServers() {
        mcpServersCache = nil
    }
}

/// Shared cache instance
private let sharedCache = MCPCache()

/// Service for MCP server configuration operations
struct MCPConfigService {
    private let fileManager = FileManager.default

    /// Cache TTL in seconds (configurable)
    var cacheTTL: TimeInterval = 30

    /// Home directory path
    var homeDirectory: String {
        fileManager.homeDirectoryForCurrentUser.path
    }

    /// Claude directory path
    var claudeDirectory: String {
        "\(homeDirectory)/.claude"
    }

    /// User MCP config path (~/.mcp.json)
    var userMCPConfigPath: String {
        "\(homeDirectory)/.mcp.json"
    }

    /// User claude.json path (legacy)
    var userClaudeJsonPath: String {
        "\(homeDirectory)/.claude.json"
    }

    // MARK: - MCP Servers

    /// Read MCP servers from configuration (with caching)
    /// Checks ~/.mcp.json (primary), ~/.claude.json (legacy), and project .mcp.json
    func readMCPServers(scope: MCPScope? = nil, bypassCache: Bool = false) async throws -> [MCPServer] {
        // Check cache first unless bypassed
        if !bypassCache, let cached = await sharedCache.getCachedMCPServers(ttl: cacheTTL) {
            return cached
        }

        let servers = try scanMCPServers(scope: scope)

        // Update cache
        await sharedCache.setCachedMCPServers(servers)

        return servers
    }

    /// Scan MCP servers from configuration (no caching)
    func scanMCPServers(scope: MCPScope? = nil) throws -> [MCPServer] {
        var servers: [MCPServer] = []

        // User scope - check ~/.mcp.json first, then ~/.claude.json as fallback
        if scope == nil || scope == .user {
            // Primary: ~/.mcp.json
            if let userServers = try? readMCPFromFile(userMCPConfigPath, scope: .user) {
                servers.append(contentsOf: userServers)
            }
            // Fallback: ~/.claude.json (legacy location)
            else if let legacyServers = try? readMCPFromFile(userClaudeJsonPath, scope: .user) {
                servers.append(contentsOf: legacyServers)
            }
        }

        // Get enabled status from settings.local.json
        var enabledServers: [String]?
        if fileManager.fileExists(atPath: "\(claudeDirectory)/settings.local.json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: "\(claudeDirectory)/settings.local.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            enabledServers = json["enabledMcpjsonServers"] as? [String]
        }

        // Mark servers as healthy if they're in the enabled list
        if let enabled = enabledServers {
            servers = servers.map { server in
                var updated = server
                if enabled.contains(server.name) {
                    updated.status = .healthy
                }
                return updated
            }
        }

        return servers
    }

    /// Invalidate MCP servers cache (call after modifications)
    func invalidateMCPServersCache() async {
        await sharedCache.invalidateMCPServers()
    }

    private func readMCPFromFile(_ path: String, scope: MCPScope) throws -> [MCPServer] {
        guard fileManager.fileExists(atPath: path) else {
            return []
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mcpServers = json["mcpServers"] as? [String: Any] else {
            return []
        }

        return mcpServers.compactMap { name, config -> MCPServer? in
            guard let configDict = config as? [String: Any] else {
                return nil
            }

            // Handle both stdio and http types
            let serverType = configDict["type"] as? String ?? "stdio"
            var command: String
            var args: [String] = []
            var env: [String: String]?

            if serverType == "http" {
                // HTTP MCP server - use url as command
                command = configDict["url"] as? String ?? ""
            } else {
                // stdio MCP server
                command = configDict["command"] as? String ?? ""
                args = configDict["args"] as? [String] ?? []
            }

            // Filter out sensitive env vars for response
            if let envDict = configDict["env"] as? [String: String] {
                env = envDict.mapValues { value in
                    // Mask sensitive values
                    if value.count > 10 {
                        return String(value.prefix(4)) + "..." + String(value.suffix(4))
                    }
                    return value
                }
            }

            return MCPServer(
                name: name,
                command: command,
                args: args,
                env: env,
                scope: scope,
                status: .unknown,
                configPath: path
            )
        }
    }

    /// Add an MCP server to configuration (~/.mcp.json)
    func addMCPServer(_ server: MCPServer) throws {
        let path = userMCPConfigPath

        var json: [String: Any] = [:]
        if fileManager.fileExists(atPath: path),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        var mcpServers = json["mcpServers"] as? [String: Any] ?? [:]

        var serverConfig: [String: Any] = [
            "type": "stdio",
            "command": server.command,
            "args": server.args
        ]
        if let env = server.env {
            serverConfig["env"] = env
        }

        mcpServers[server.name] = serverConfig
        json["mcpServers"] = mcpServers

        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: path))
    }

    /// Remove an MCP server from configuration
    func removeMCPServer(name: String, scope: MCPScope) throws {
        let path = userMCPConfigPath

        guard fileManager.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Abort(.notFound, reason: "MCP server not found")
        }

        var mcpServers = json["mcpServers"] as? [String: Any] ?? [:]
        mcpServers.removeValue(forKey: name)
        json["mcpServers"] = mcpServers

        let newData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try newData.write(to: URL(fileURLWithPath: path))
    }
}
