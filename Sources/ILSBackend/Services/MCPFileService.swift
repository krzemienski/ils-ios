import Foundation
import Vapor
import ILSShared

/// Service for MCP server configuration file operations.
///
/// Reads MCP server definitions from:
/// - `~/.mcp.json` (primary location)
/// - `~/.claude.json` (legacy fallback)
/// - Checks `~/.claude/settings.local.json` for enabled server list
///
/// Supports both stdio and HTTP MCP server types.
struct MCPFileService {
    private let fileManager = FileManager.default

    /// Cache TTL in seconds (default: 30s)
    var cacheTTL: TimeInterval = 30

    /// Home directory path
    var homeDirectory: String {
        fileManager.homeDirectoryForCurrentUser.path
    }

    /// Claude configuration directory path (`~/.claude`)
    var claudeDirectory: String {
        "\(homeDirectory)/.claude"
    }

    /// Primary MCP configuration path (`~/.mcp.json`)
    var userMCPConfigPath: String {
        "\(homeDirectory)/.mcp.json"
    }

    /// Legacy MCP configuration path (`~/.claude.json`)
    var userClaudeJsonPath: String {
        "\(homeDirectory)/.claude.json"
    }

    // MARK: - MCP Servers

    /// Read MCP servers from configuration files with caching.
    ///
    /// Checks `~/.mcp.json` first, falls back to `~/.claude.json` if not found.
    /// Cross-references `~/.claude/settings.local.json` for enabled server status.
    ///
    /// - Parameters:
    ///   - scope: Optional scope filter (user or project)
    ///   - bypassCache: If true, forces fresh scan from disk
    /// - Returns: Array of MCPServer objects
    func readMCPServers(scope: MCPScope? = nil, bypassCache: Bool = false) async throws -> [MCPServer] {
        // Check cache first unless bypassed
        if !bypassCache, let cached = await FileSystemCache.shared.getCachedMCPServers(ttl: cacheTTL) {
            return cached
        }

        let servers = try scanMCPServers(scope: scope)

        // Update cache
        await FileSystemCache.shared.setCachedMCPServers(servers)

        return servers
    }

    /// Scan MCP servers from disk without using cache.
    /// - Parameter scope: Optional scope filter
    /// - Returns: Array of MCPServer objects
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
        // Dynamic JSON — Claude settings files have evolving schema with arbitrary keys
        var enabledServers: [String]?
        if fileManager.fileExists(atPath: "\(claudeDirectory)/settings.local.json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: "\(claudeDirectory)/settings.local.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            enabledServers = json["enabledMcpjsonServers"] as? [String]
        }

        // Mark servers enabled/disabled and healthy based on enabledMcpjsonServers list
        if let enabled = enabledServers {
            servers = servers.map { server in
                var updated = server
                let isInEnabledList = enabled.contains(server.name)
                updated.isEnabled = isInEnabledList
                if isInEnabledList {
                    updated.status = .healthy
                }
                return updated
            }
        }
        // If enabledServers is nil (file doesn't exist or key absent), isEnabled remains true (default) — correct.

        return servers
    }

    /// Invalidate MCP servers cache, forcing next read to scan from disk.
    func invalidateMCPServersCache() async {
        await FileSystemCache.shared.invalidateMCPServers()
    }

    /// Read MCP servers from a specific configuration file.
    ///
    /// Uses JSONSerialization intentionally: MCP config files (`~/.mcp.json`, `~/.claude.json`)
    /// have a dynamic schema where server entries contain arbitrary keys (command, args, env,
    /// url, type, plus user-defined extensions). A Codable struct would be too rigid for this
    /// user-authored configuration format.
    ///
    /// - Parameters:
    ///   - path: Configuration file path
    ///   - scope: Scope to tag servers with (user or project)
    /// - Returns: Array of MCPServer objects from this file
    private func readMCPFromFile(_ path: String, scope: MCPScope) throws -> [MCPServer] {
        guard fileManager.fileExists(atPath: path) else {
            return []
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        // Dynamic JSON — MCP configs have user-defined server entries with arbitrary keys
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

    /// Add a new MCP server to `~/.mcp.json`.
    ///
    /// Uses JSONSerialization to preserve existing user-authored JSON structure and
    /// arbitrary keys in the MCP config file.
    ///
    /// - Parameter server: MCPServer object to add
    func addMCPServer(_ server: MCPServer) throws {
        let path = userMCPConfigPath

        // Dynamic JSON — must preserve user-authored config structure
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

    /// Remove an MCP server from `~/.mcp.json`.
    ///
    /// Uses JSONSerialization to preserve existing user-authored JSON structure.
    ///
    /// - Parameters:
    ///   - name: Server name to remove
    ///   - scope: Configuration scope (currently only user scope supported)
    func removeMCPServer(name: String, scope: MCPScope) throws {
        let path = userMCPConfigPath

        // Dynamic JSON — must preserve user-authored config structure
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

    // MARK: - Enable / Disable

    /// Enable an MCP server by adding it to the enabled servers list in `~/.claude/settings.local.json`.
    ///
    /// Claude reads `enabledMcpjsonServers` from settings.local.json to determine which servers
    /// are active. Adding a server name here marks it as enabled without modifying the server
    /// definition in `~/.mcp.json`.
    ///
    /// - Parameter name: Server name to enable
    func enableMCPServer(name: String) throws {
        let settingsPath = "\(claudeDirectory)/settings.local.json"

        // Read existing settings — Dynamic JSON: Claude settings have evolving schema
        var json: [String: Any] = [:]
        if fileManager.fileExists(atPath: settingsPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        var enabledServers = json["enabledMcpjsonServers"] as? [String] ?? []

        // Add server if not already in the enabled list
        if !enabledServers.contains(name) {
            enabledServers.append(name)
        }

        json["enabledMcpjsonServers"] = enabledServers

        // Ensure the ~/.claude directory exists
        try fileManager.createDirectory(atPath: claudeDirectory, withIntermediateDirectories: true)

        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: settingsPath))
    }

    /// Disable an MCP server by removing it from the enabled servers list in `~/.claude/settings.local.json`.
    ///
    /// Removes the server name from `enabledMcpjsonServers` in settings.local.json.
    /// The server definition in `~/.mcp.json` is preserved; only the enabled state changes.
    ///
    /// - Parameter name: Server name to disable
    func disableMCPServer(name: String) throws {
        let settingsPath = "\(claudeDirectory)/settings.local.json"

        // If settings file doesn't exist there's nothing to disable
        guard fileManager.fileExists(atPath: settingsPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        var enabledServers = json["enabledMcpjsonServers"] as? [String] ?? []
        enabledServers.removeAll { $0 == name }
        json["enabledMcpjsonServers"] = enabledServers

        let newData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try newData.write(to: URL(fileURLWithPath: settingsPath))
    }
}
