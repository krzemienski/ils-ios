import Foundation
import Vapor
import ILSShared

/// Service for Claude configuration file operations.
///
/// Manages reading and writing Claude settings files at different scopes:
/// - `user`: `~/.claude/settings.json`
/// - `project`: `.claude/settings.json`
/// - `local`: `.claude/settings.local.json`
struct ConfigFileService: @unchecked Sendable {
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

    /// Managed settings path (enterprise deployments).
    /// macOS: /Library/Application Support/ClaudeCode/managed-settings.json
    /// Linux: /etc/claude-code/managed-settings.json
    var managedSettingsPath: String {
        #if os(macOS)
        return "/Library/Application Support/ClaudeCode/managed-settings.json"
        #else
        return "/etc/claude-code/managed-settings.json"
        #endif
    }

    /// Read Claude settings for a specific scope.
    /// - Parameter scope: Configuration scope (user, project, local, or managed)
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
        case .managed:
            if let managed = readManagedConfig() {
                return managed
            }
            return ConfigInfo(scope: .managed, path: managedSettingsPath, content: ClaudeConfig(), isValid: true)
        }

        var config = ClaudeConfig()
        let isValid = true

        if fileManager.fileExists(atPath: path) {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            do {
                config = try JSONDecoder().decode(ClaudeConfig.self, from: data)
            } catch {
                // Return partial config with validation error instead of failing the entire request.
                // This allows the iOS app to display what it can while surfacing the parse issue.
                return ConfigInfo(
                    scope: scope,
                    path: path,
                    content: config,
                    isValid: false,
                    errors: [error.localizedDescription]
                )
            }
        }

        return ConfigInfo(
            scope: scope,
            path: path,
            content: config,
            isValid: isValid
        )
    }

    /// Read managed settings. Returns nil if file doesn't exist (normal for non-enterprise).
    func readManagedConfig() -> ConfigInfo? {
        let path = managedSettingsPath
        guard fileManager.fileExists(atPath: path) else { return nil }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let config = try? JSONDecoder().decode(ClaudeConfig.self, from: data) else {
            return nil
        }
        return ConfigInfo(scope: .managed, path: path, content: config, isValid: true)
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
        case .project, .local, .managed:
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

    // MARK: - Effective Config (Merge)

    /// Read effective (merged) configuration across all scopes.
    ///
    /// Reads all 4 scopes (user, project, local, managed) and merges them
    /// with precedence: managed > local > project > user. For each key,
    /// the highest-precedence non-nil value wins.
    ///
    /// Missing scope files are treated as empty config (no errors).
    ///
    /// - Returns: EffectiveConfig with merged values and per-key scope annotations
    func readEffectiveConfig() -> EffectiveConfig {
        let userInfo = try? readConfig(scope: .user)
        let projectInfo = try? readConfig(scope: .project)
        let localInfo = try? readConfig(scope: .local)
        let managedInfo = readManagedConfig()

        let user = userInfo?.content ?? ClaudeConfig()
        let project = projectInfo?.content ?? ClaudeConfig()
        let local = localInfo?.content ?? ClaudeConfig()
        let managed = managedInfo?.content ?? ClaudeConfig()

        // Scopes in precedence order (lowest to highest)
        let scopes: [(ConfigScope, ClaudeConfig)] = [
            (.user, user), (.project, project), (.local, local), (.managed, managed)
        ]

        var merged = ClaudeConfig()
        var overrides: [ConfigOverride] = []

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        // Helper to serialize an Encodable value to a string representation
        func serialize<T: Encodable>(_ val: T?) -> String? {
            guard let v = val else { return nil }
            if let s = v as? String { return s }
            if let b = v as? Bool { return b ? "true" : "false" }
            guard let data = try? encoder.encode(v),
                  let str = String(data: data, encoding: .utf8) else { return nil }
            return str
        }

        // Resolve model
        do {
            let values: [(ConfigScope, String)] = scopes.compactMap { scope, cfg in
                cfg.model.map { (scope, $0) }
            }
            if let winner = values.last {
                merged.model = winner.1
                overrides.append(ConfigOverride(
                    key: "model", winningScope: winner.0, winningValue: winner.1,
                    userValue: user.model, projectValue: project.model,
                    localValue: local.model, managedValue: managed.model
                ))
            }
        }

        // Resolve permissions
        do {
            let values: [(ConfigScope, PermissionsConfig)] = scopes.compactMap { scope, cfg in
                cfg.permissions.map { (scope, $0) }
            }
            if let winner = values.last {
                merged.permissions = winner.1
                overrides.append(ConfigOverride(
                    key: "permissions", winningScope: winner.0, winningValue: serialize(winner.1) ?? "",
                    userValue: serialize(user.permissions), projectValue: serialize(project.permissions),
                    localValue: serialize(local.permissions), managedValue: serialize(managed.permissions)
                ))
            }
        }

        // Resolve env
        do {
            let values: [(ConfigScope, [String: String])] = scopes.compactMap { scope, cfg in
                cfg.env.map { (scope, $0) }
            }
            if let winner = values.last {
                merged.env = winner.1
                overrides.append(ConfigOverride(
                    key: "env", winningScope: winner.0, winningValue: serialize(winner.1) ?? "",
                    userValue: serialize(user.env), projectValue: serialize(project.env),
                    localValue: serialize(local.env), managedValue: serialize(managed.env)
                ))
            }
        }

        // Resolve hooks
        do {
            let values: [(ConfigScope, HooksConfig)] = scopes.compactMap { scope, cfg in
                cfg.hooks.map { (scope, $0) }
            }
            if let winner = values.last {
                merged.hooks = winner.1
                overrides.append(ConfigOverride(
                    key: "hooks", winningScope: winner.0, winningValue: serialize(winner.1) ?? "",
                    userValue: serialize(user.hooks), projectValue: serialize(project.hooks),
                    localValue: serialize(local.hooks), managedValue: serialize(managed.hooks)
                ))
            }
        }

        // Resolve enabledPlugins
        do {
            let values: [(ConfigScope, [String: Bool])] = scopes.compactMap { scope, cfg in
                cfg.enabledPlugins.map { (scope, $0) }
            }
            if let winner = values.last {
                merged.enabledPlugins = winner.1
                overrides.append(ConfigOverride(
                    key: "enabledPlugins", winningScope: winner.0, winningValue: serialize(winner.1) ?? "",
                    userValue: serialize(user.enabledPlugins), projectValue: serialize(project.enabledPlugins),
                    localValue: serialize(local.enabledPlugins), managedValue: serialize(managed.enabledPlugins)
                ))
            }
        }

        // Resolve extraKnownMarketplaces
        do {
            let values: [(ConfigScope, [String: MarketplaceValue])] = scopes.compactMap { scope, cfg in
                cfg.extraKnownMarketplaces.map { (scope, $0) }
            }
            if let winner = values.last {
                merged.extraKnownMarketplaces = winner.1
                overrides.append(ConfigOverride(
                    key: "extraKnownMarketplaces", winningScope: winner.0, winningValue: serialize(winner.1) ?? "",
                    userValue: serialize(user.extraKnownMarketplaces), projectValue: serialize(project.extraKnownMarketplaces),
                    localValue: serialize(local.extraKnownMarketplaces), managedValue: serialize(managed.extraKnownMarketplaces)
                ))
            }
        }

        // Resolve includeCoAuthoredBy
        do {
            let values: [(ConfigScope, Bool)] = scopes.compactMap { scope, cfg in
                cfg.includeCoAuthoredBy.map { (scope, $0) }
            }
            if let winner = values.last {
                merged.includeCoAuthoredBy = winner.1
                overrides.append(ConfigOverride(
                    key: "includeCoAuthoredBy", winningScope: winner.0, winningValue: winner.1 ? "true" : "false",
                    userValue: serialize(user.includeCoAuthoredBy), projectValue: serialize(project.includeCoAuthoredBy),
                    localValue: serialize(local.includeCoAuthoredBy), managedValue: serialize(managed.includeCoAuthoredBy)
                ))
            }
        }

        // Resolve statusLine
        do {
            let values: [(ConfigScope, StatusLineConfig)] = scopes.compactMap { scope, cfg in
                cfg.statusLine.map { (scope, $0) }
            }
            if let winner = values.last {
                merged.statusLine = winner.1
                overrides.append(ConfigOverride(
                    key: "statusLine", winningScope: winner.0, winningValue: serialize(winner.1) ?? "",
                    userValue: serialize(user.statusLine), projectValue: serialize(project.statusLine),
                    localValue: serialize(local.statusLine), managedValue: serialize(managed.statusLine)
                ))
            }
        }

        // Resolve alwaysThinkingEnabled
        do {
            let values: [(ConfigScope, Bool)] = scopes.compactMap { scope, cfg in
                cfg.alwaysThinkingEnabled.map { (scope, $0) }
            }
            if let winner = values.last {
                merged.alwaysThinkingEnabled = winner.1
                overrides.append(ConfigOverride(
                    key: "alwaysThinkingEnabled", winningScope: winner.0, winningValue: winner.1 ? "true" : "false",
                    userValue: serialize(user.alwaysThinkingEnabled), projectValue: serialize(project.alwaysThinkingEnabled),
                    localValue: serialize(local.alwaysThinkingEnabled), managedValue: serialize(managed.alwaysThinkingEnabled)
                ))
            }
        }

        // Resolve autoUpdatesChannel
        do {
            let values: [(ConfigScope, String)] = scopes.compactMap { scope, cfg in
                cfg.autoUpdatesChannel.map { (scope, $0) }
            }
            if let winner = values.last {
                merged.autoUpdatesChannel = winner.1
                overrides.append(ConfigOverride(
                    key: "autoUpdatesChannel", winningScope: winner.0, winningValue: winner.1,
                    userValue: user.autoUpdatesChannel, projectValue: project.autoUpdatesChannel,
                    localValue: local.autoUpdatesChannel, managedValue: managed.autoUpdatesChannel
                ))
            }
        }

        // Resolve theme
        do {
            let values: [(ConfigScope, ThemeConfig)] = scopes.compactMap { scope, cfg in
                cfg.theme.map { (scope, $0) }
            }
            if let winner = values.last {
                merged.theme = winner.1
                overrides.append(ConfigOverride(
                    key: "theme", winningScope: winner.0, winningValue: serialize(winner.1) ?? "",
                    userValue: serialize(user.theme), projectValue: serialize(project.theme),
                    localValue: serialize(local.theme), managedValue: serialize(managed.theme)
                ))
            }
        }

        // Resolve apiKeyStatus
        do {
            let values: [(ConfigScope, APIKeyStatus)] = scopes.compactMap { scope, cfg in
                cfg.apiKeyStatus.map { (scope, $0) }
            }
            if let winner = values.last {
                merged.apiKeyStatus = winner.1
                overrides.append(ConfigOverride(
                    key: "apiKeyStatus", winningScope: winner.0, winningValue: serialize(winner.1) ?? "",
                    userValue: serialize(user.apiKeyStatus), projectValue: serialize(project.apiKeyStatus),
                    localValue: serialize(local.apiKeyStatus), managedValue: serialize(managed.apiKeyStatus)
                ))
            }
        }

        return EffectiveConfig(
            config: merged,
            overrides: overrides,
            profiles: ConfigProfiles(
                user: userInfo,
                project: projectInfo,
                local: localInfo,
                managed: managedInfo
            )
        )
    }
}
