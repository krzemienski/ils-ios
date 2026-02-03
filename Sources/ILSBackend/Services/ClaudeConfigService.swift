import Foundation
import Vapor
import ILSShared

/// Service for Claude configuration settings operations
struct ClaudeConfigService {
    private let fileManager = FileManager.default

    /// Home directory path
    var homeDirectory: String {
        fileManager.homeDirectoryForCurrentUser.path
    }

    /// Claude directory path
    var claudeDirectory: String {
        "\(homeDirectory)/.claude"
    }

    /// User settings path
    var userSettingsPath: String {
        "\(claudeDirectory)/settings.json"
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
}
