import Foundation
import Vapor
import ILSShared
import Yams

/// Service for file system operations related to Claude Code configuration
struct FileSystemService {
    private let fileManager = FileManager.default

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

    /// User claude.json path (for MCP servers)
    var userClaudeJsonPath: String {
        "\(homeDirectory)/.claude.json"
    }

    /// Claude projects directory for session scanning
    var claudeProjectsPath: String {
        "\(claudeDirectory)/projects"
    }

    // MARK: - Skills

    /// List all skills from the skills directory
    func listSkills() throws -> [Skill] {
        var skills: [Skill] = []

        guard fileManager.fileExists(atPath: skillsDirectory) else {
            return skills
        }

        let contents = try fileManager.contentsOfDirectory(atPath: skillsDirectory)

        for item in contents {
            let skillPath = "\(skillsDirectory)/\(item)"
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: skillPath, isDirectory: &isDirectory), isDirectory.boolValue {
                let skillMdPath = "\(skillPath)/SKILL.md"

                if fileManager.fileExists(atPath: skillMdPath) {
                    if let skill = try? parseSkillFile(at: skillMdPath, name: item) {
                        skills.append(skill)
                    }
                }
            }
        }

        return skills
    }

    /// Parse a SKILL.md file
    private func parseSkillFile(at path: String, name: String) throws -> Skill {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        var description: String?
        var version: String?

        // Parse YAML frontmatter if present
        if content.hasPrefix("---") {
            let parts = content.split(separator: "---", maxSplits: 2, omittingEmptySubsequences: false)
            if parts.count >= 2 {
                let yamlContent = String(parts[1])
                if let yaml = try? Yams.load(yaml: yamlContent) as? [String: Any] {
                    description = yaml["description"] as? String
                    version = yaml["version"] as? String
                }
            }
        }

        return Skill(
            name: name,
            description: description,
            version: version,
            isActive: true,
            path: path.replacingOccurrences(of: "/SKILL.md", with: ""),
            source: .local,
            content: content
        )
    }

    /// Get a specific skill by name
    func getSkill(name: String) throws -> Skill? {
        let skillPath = "\(skillsDirectory)/\(name)"
        let skillMdPath = "\(skillPath)/SKILL.md"

        guard fileManager.fileExists(atPath: skillMdPath) else {
            return nil
        }

        return try parseSkillFile(at: skillMdPath, name: name)
    }

    /// Create a new skill
    func createSkill(name: String, content: String) throws -> Skill {
        let skillPath = "\(skillsDirectory)/\(name)"
        let skillMdPath = "\(skillPath)/SKILL.md"

        // Create directory
        try fileManager.createDirectory(atPath: skillPath, withIntermediateDirectories: true)

        // Write SKILL.md
        try content.write(toFile: skillMdPath, atomically: true, encoding: .utf8)

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
    func deleteSkill(name: String) throws {
        let skillPath = "\(skillsDirectory)/\(name)"

        guard fileManager.fileExists(atPath: skillPath) else {
            throw Abort(.notFound, reason: "Skill not found")
        }

        try fileManager.removeItem(atPath: skillPath)
    }

    // MARK: - MCP Servers

    /// Read MCP servers from configuration
    func readMCPServers(scope: MCPScope? = nil) throws -> [MCPServer] {
        var servers: [MCPServer] = []

        // User scope - ~/.claude.json
        if scope == nil || scope == .user {
            if let userServers = try? readMCPFromFile(userClaudeJsonPath, scope: .user) {
                servers.append(contentsOf: userServers)
            }
        }

        return servers
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
            guard let configDict = config as? [String: Any],
                  let command = configDict["command"] as? String else {
                return nil
            }

            let args = configDict["args"] as? [String] ?? []
            let env = configDict["env"] as? [String: String]

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

    /// Add an MCP server to configuration
    func addMCPServer(_ server: MCPServer) throws {
        let path = server.scope == .user ? userClaudeJsonPath : userClaudeJsonPath

        var json: [String: Any] = [:]
        if fileManager.fileExists(atPath: path),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        var mcpServers = json["mcpServers"] as? [String: Any] ?? [:]

        var serverConfig: [String: Any] = [
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
        let path = scope == .user ? userClaudeJsonPath : userClaudeJsonPath

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
        var isValid = true

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
