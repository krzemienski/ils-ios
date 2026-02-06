import Foundation
import Vapor
import ILSShared

/// Service for Claude configuration file operations.
///
/// Manages reading and writing Claude settings files at different scopes:
/// - `user`: `~/.claude/settings.json`
/// - `project`: `.claude/settings.json`
/// - `local`: `.claude/settings.local.json`
struct ConfigFileService {
    private let fileManager = FileManager.default

    /// Home directory path
    var homeDirectory: String {
        fileManager.homeDirectoryForCurrentUser.path
    }

    /// Claude configuration directory path (`~/.claude`)
    var claudeDirectory: String {
        "\(homeDirectory)/.claude"
    }

    /// User settings file path (`~/.claude/settings.json`)
    var userSettingsPath: String {
        "\(claudeDirectory)/settings.json"
    }

    // MARK: - Config

    /// Read Claude settings for a specific scope.
    /// - Parameter scope: Scope name ("user", "project", or "local")
    /// - Returns: ConfigInfo with settings content and metadata
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

    /// Write Claude settings to a specific scope.
    /// - Parameters:
    ///   - scope: Scope name ("user" only currently supported)
    ///   - content: ClaudeConfig object to write
    /// - Returns: ConfigInfo with updated content
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
