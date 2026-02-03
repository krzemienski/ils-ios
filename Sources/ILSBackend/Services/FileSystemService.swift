import Foundation
import Vapor
import ILSShared
import Yams

/// Cache entry with timestamp for TTL-based invalidation
private struct CacheEntry<T> {
    let value: T
    let timestamp: Date

    func isValid(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) < ttl
    }
}

/// Actor for thread-safe cache management
private actor FileSystemCache {
    private var skillsCache: CacheEntry<[Skill]>?
    private var mcpServersCache: CacheEntry<[MCPServer]>?

    /// Default TTL: 30 seconds
    private let defaultTTL: TimeInterval = 30

    func getCachedSkills(ttl: TimeInterval? = nil) -> [Skill]? {
        guard let cache = skillsCache, cache.isValid(ttl: ttl ?? defaultTTL) else {
            return nil
        }
        return cache.value
    }

    func setCachedSkills(_ skills: [Skill]) {
        skillsCache = CacheEntry(value: skills, timestamp: Date())
    }

    func getCachedMCPServers(ttl: TimeInterval? = nil) -> [MCPServer]? {
        guard let cache = mcpServersCache, cache.isValid(ttl: ttl ?? defaultTTL) else {
            return nil
        }
        return cache.value
    }

    func setCachedMCPServers(_ servers: [MCPServer]) {
        mcpServersCache = CacheEntry(value: servers, timestamp: Date())
    }

    func invalidateAll() {
        skillsCache = nil
        mcpServersCache = nil
    }

    func invalidateSkills() {
        skillsCache = nil
    }

    func invalidateMCPServers() {
        mcpServersCache = nil
    }
}

/// Shared cache instance
private let sharedCache = FileSystemCache()

/// Service for file system operations related to Claude Code configuration
struct FileSystemService {
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

    /// Skills directory path
    var skillsDirectory: String {
        "\(claudeDirectory)/skills"
    }

    /// User settings path
    var userSettingsPath: String {
        "\(claudeDirectory)/settings.json"
    }

    /// User claude.json path (legacy)
    var userClaudeJsonPath: String {
        "\(homeDirectory)/.claude.json"
    }

    /// User MCP config path (~/.mcp.json)
    var userMCPConfigPath: String {
        "\(homeDirectory)/.mcp.json"
    }

    /// Claude projects directory for session scanning
    var claudeProjectsPath: String {
        "\(claudeDirectory)/projects"
    }

    // MARK: - Skills

    /// List all skills from the skills directory (with caching)
    func listSkills(bypassCache: Bool = false) async throws -> [Skill] {
        // Check cache first unless bypassed
        if !bypassCache, let cached = await sharedCache.getCachedSkills(ttl: cacheTTL) {
            return cached
        }

        let skills = try scanSkills()

        // Update cache
        await sharedCache.setCachedSkills(skills)

        return skills
    }

    /// Scan all skills from the skills directory (no caching)
    func scanSkills() throws -> [Skill] {
        var skills: [Skill] = []

        guard fileManager.fileExists(atPath: skillsDirectory) else {
            return skills
        }

        // Recursively scan for all .md files in the skills directory
        skills = try scanSkillsRecursively(at: skillsDirectory, basePath: skillsDirectory)

        return skills
    }

    /// Recursively scan directory for skill .md files
    private func scanSkillsRecursively(at path: String, basePath: String) throws -> [Skill] {
        var skills: [Skill] = []

        let contents = try fileManager.contentsOfDirectory(atPath: path)

        for item in contents {
            let itemPath = "\(path)/\(item)"
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Check for SKILL.md in this directory (traditional format)
                    let skillMdPath = "\(itemPath)/SKILL.md"
                    if fileManager.fileExists(atPath: skillMdPath) {
                        if let skill = try? parseSkillFile(at: skillMdPath, name: item) {
                            skills.append(skill)
                        }
                    }

                    // Recursively scan subdirectory for more skills
                    let subSkills = try scanSkillsRecursively(at: itemPath, basePath: basePath)
                    skills.append(contentsOf: subSkills)
                } else if item.hasSuffix(".md") && item != "SKILL.md" {
                    // Parse standalone .md files as skills
                    let skillName = String(item.dropLast(3)) // Remove .md extension
                    if let skill = try? parseSkillFile(at: itemPath, name: skillName) {
                        skills.append(skill)
                    }
                }
            }
        }

        return skills
    }

    /// Invalidate skills cache (call after modifications)
    func invalidateSkillsCache() async {
        await sharedCache.invalidateSkills()
    }

    /// Parse a SKILL.md file or standalone .md skill file
    private func parseSkillFile(at path: String, name: String) throws -> Skill {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        var description: String?
        var version: String?
        var tags: [String] = []
        var parsedName = name

        // Parse YAML frontmatter if present
        if content.hasPrefix("---") {
            let parts = content.split(separator: "---", maxSplits: 2, omittingEmptySubsequences: false)
            if parts.count >= 2 {
                let yamlContent = String(parts[1])
                if let yaml = try? Yams.load(yaml: yamlContent) as? [String: Any] {
                    description = yaml["description"] as? String
                    version = yaml["version"] as? String

                    // Parse tags - can be array or comma-separated string
                    if let tagArray = yaml["tags"] as? [String] {
                        tags = tagArray
                    } else if let tagString = yaml["tags"] as? String {
                        tags = tagString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    }

                    // Use name from frontmatter if available
                    if let frontmatterName = yaml["name"] as? String {
                        parsedName = frontmatterName
                    }
                }
            }
        }

        // Determine the skill path (directory for SKILL.md, file path for standalone)
        let skillPath: String
        if path.hasSuffix("/SKILL.md") {
            skillPath = path.replacingOccurrences(of: "/SKILL.md", with: "")
        } else {
            skillPath = path
        }

        return Skill(
            name: parsedName,
            description: description,
            version: version,
            tags: tags,
            isActive: true,
            path: skillPath,
            source: .local,
            content: content
        )
    }

    /// Get a specific skill by name
    func getSkill(name: String) throws -> Skill? {
        // Try directory-based skill first (name/SKILL.md)
        let skillPath = "\(skillsDirectory)/\(name)"
        let skillMdPath = "\(skillPath)/SKILL.md"

        if fileManager.fileExists(atPath: skillMdPath) {
            return try parseSkillFile(at: skillMdPath, name: name)
        }

        // Try standalone .md file (name.md)
        let standalonePath = "\(skillsDirectory)/\(name).md"
        if fileManager.fileExists(atPath: standalonePath) {
            return try parseSkillFile(at: standalonePath, name: name)
        }

        // Search recursively for the skill by name
        let allSkills = try scanSkills()
        return allSkills.first { $0.name == name }
    }

    /// Create a new skill
    func createSkill(name: String, content: String) async throws -> Skill {
        let skillPath = "\(skillsDirectory)/\(name)"
        let skillMdPath = "\(skillPath)/SKILL.md"

        // Create directory
        try fileManager.createDirectory(atPath: skillPath, withIntermediateDirectories: true)

        // Write SKILL.md
        try content.write(toFile: skillMdPath, atomically: true, encoding: .utf8)

        // Invalidate cache after creation
        await invalidateSkillsCache()

        return try parseSkillFile(at: skillMdPath, name: name)
    }

    /// Update a skill's content
    func updateSkill(name: String, content: String) throws -> Skill {
        let skillMdPath = "\(skillsDirectory)/\(name)/SKILL.md"

        guard fileManager.fileExists(atPath: skillMdPath) else {
            throw Abort(.notFound, reason: "Skill not found")
        }

        try content.write(toFile: skillMdPath, atomically: true, encoding: .utf8)

        return try parseSkillFile(at: skillMdPath, name: name)
    }

    /// Delete a skill
    func deleteSkill(name: String) async throws {
        // Try directory-based skill first (name/SKILL.md format)
        let skillPath = "\(skillsDirectory)/\(name)"

        if fileManager.fileExists(atPath: skillPath) {
            // Check if this is a directory
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: skillPath, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                // Remove entire directory (works for both local and GitHub skills)
                try fileManager.removeItem(atPath: skillPath)

                // Invalidate cache after deletion
                await invalidateSkillsCache()
                return
            }
        }

        // Try standalone .md file (name.md format)
        let standalonePath = "\(skillsDirectory)/\(name).md"
        if fileManager.fileExists(atPath: standalonePath) {
            try fileManager.removeItem(atPath: standalonePath)

            // Invalidate cache after deletion
            await invalidateSkillsCache()
            return
        }

        // Skill not found in either format
        throw Abort(.notFound, reason: "Skill not found")
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

    // MARK: - Config

    /// Read Claude settings
    func readConfig(scope: String) throws -> ConfigInfo {
        let path: String
        switch scope {
        case "user":
            path = userSettingsPath
        case "project":
            path = ".claude/settings.json"
        case "local":
            path = ".claude/settings.local.json"
        default:
            throw Abort(.badRequest, reason: "Invalid scope")
        }

        var config = ClaudeConfig()
        let isValid = true

        if fileManager.fileExists(atPath: path) {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            config = try JSONDecoder().decode(ClaudeConfig.self, from: data)
        }

        return ConfigInfo(
            scope: scope,
            path: path,
            content: config,
            isValid: isValid
        )
    }

    /// Write Claude settings
    func writeConfig(scope: String, content: ClaudeConfig) throws -> ConfigInfo {
        let path: String
        switch scope {
        case "user":
            path = userSettingsPath
            // Ensure directory exists
            try fileManager.createDirectory(atPath: claudeDirectory, withIntermediateDirectories: true)
        default:
            throw Abort(.badRequest, reason: "Invalid scope for writing")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(content)
        try data.write(to: URL(fileURLWithPath: path))

        return ConfigInfo(
            scope: scope,
            path: path,
            content: content,
            isValid: true
        )
    }

    // MARK: - Session Scanning

    /// Scan for external Claude Code sessions
    func scanExternalSessions() throws -> [ExternalSession] {
        var sessions: [ExternalSession] = []

        guard fileManager.fileExists(atPath: claudeProjectsPath) else {
            return sessions
        }

        let contents = try fileManager.contentsOfDirectory(atPath: claudeProjectsPath)

        for item in contents {
            let projectPath = "\(claudeProjectsPath)/\(item)"
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: projectPath, isDirectory: &isDirectory), isDirectory.boolValue {
                // Look for session files
                let projectContents = try? fileManager.contentsOfDirectory(atPath: projectPath)
                for sessionFile in projectContents ?? [] {
                    if sessionFile.hasSuffix(".json") {
                        let sessionId = sessionFile.replacingOccurrences(of: ".json", with: "")
                        let fullPath = "\(projectPath)/\(sessionFile)"

                        // Get file modification date
                        let attrs = try? fileManager.attributesOfItem(atPath: fullPath)
                        let modDate = attrs?[.modificationDate] as? Date

                        sessions.append(ExternalSession(
                            claudeSessionId: sessionId,
                            projectPath: item,
                            source: .external,
                            lastActiveAt: modDate
                        ))
                    }
                }
            }
        }

        return sessions
    }
}
