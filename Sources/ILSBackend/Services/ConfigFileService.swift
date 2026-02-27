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
    /// - Parameter scope: Configuration scope (user, project, or local)
    /// - Returns: ConfigInfo with settings content and metadata
    func readConfig(scope: ConfigScope) throws -> ConfigInfo {
        let path: String
        switch scope {
        case .user:
            path = userSettingsPath
        case .project:
            path = ".claude/settings.json"
        case .local:
            path = ".claude/settings.local.json"
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
    ///   - scope: Configuration scope (currently only .user is supported for writes)
    ///   - content: ClaudeConfig object to write
    /// - Returns: ConfigInfo with updated content
    func writeConfig(scope: ConfigScope, content: ClaudeConfig) throws -> ConfigInfo {
        let path: String
        switch scope {
        case .user:
            path = userSettingsPath
            // Ensure directory exists
            try fileManager.createDirectory(atPath: claudeDirectory, withIntermediateDirectories: true)
        case .project, .local:
            throw Abort(.badRequest, reason: "Writing to \(scope.rawValue) scope is not currently supported")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(content)
        var fileURL = URL(fileURLWithPath: path)
        try data.write(to: fileURL)

        // Exclude config files from iCloud/Finder backups on macOS —
        // these are local machine-specific settings that shouldn't be restored onto a different host
        #if os(macOS)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try fileURL.setResourceValues(resourceValues)
        #endif

        return ConfigInfo(
            scope: scope,
            path: path,
            content: content,
            isValid: true
        )
    }
}
