import Foundation

/// Manages user-configurable settings for offline caching behavior.
///
/// All settings are persisted to UserDefaults and observed via `@Published`
/// properties so SwiftUI views can react to changes automatically.
final class OfflineCacheSettings: ObservableObject {
    static let shared = OfflineCacheSettings()

    // MARK: - Defaults

    /// Default maximum number of sessions to retain in the offline cache.
    static let defaultMaxSessions = 50

    /// Default cache TTL: 7 days in seconds.
    static let defaultCacheTTL: TimeInterval = 604_800

    // MARK: - Master Toggle

    /// Whether offline caching is enabled at all.
    @Published var isCacheEnabled: Bool {
        didSet { UserDefaults.standard.set(isCacheEnabled, forKey: AppConstants.offlineCacheEnabledKey) }
    }

    // MARK: - Capacity

    /// Maximum number of sessions to store in the offline cache.
    /// A value of 0 means unlimited.
    @Published var maxSessions: Int {
        didSet { UserDefaults.standard.set(maxSessions, forKey: AppConstants.offlineCacheMaxSessionsKey) }
    }

    /// Time-to-live for cached data, in seconds.
    /// Entries older than this threshold are considered stale.
    @Published var cacheTTL: TimeInterval {
        didSet { UserDefaults.standard.set(cacheTTL, forKey: AppConstants.offlineCacheTTLKey) }
    }

    // MARK: - Per-Type Toggles

    /// Whether session list data should be cached for offline access.
    @Published var sessionsEnabled: Bool {
        didSet { UserDefaults.standard.set(sessionsEnabled, forKey: AppConstants.offlineCacheSessionsEnabledKey) }
    }

    /// Whether session messages should be cached for offline reading.
    @Published var messagesEnabled: Bool {
        didSet { UserDefaults.standard.set(messagesEnabled, forKey: AppConstants.offlineCacheMessagesEnabledKey) }
    }

    /// Whether project data should be cached for offline access.
    @Published var projectsEnabled: Bool {
        didSet { UserDefaults.standard.set(projectsEnabled, forKey: AppConstants.offlineCacheProjectsEnabledKey) }
    }

    /// Whether skills data should be cached for offline access.
    @Published var skillsEnabled: Bool {
        didSet { UserDefaults.standard.set(skillsEnabled, forKey: AppConstants.offlineCacheSkillsEnabledKey) }
    }

    /// Whether MCP server data should be cached for offline access.
    @Published var mcpServersEnabled: Bool {
        didSet { UserDefaults.standard.set(mcpServersEnabled, forKey: AppConstants.offlineCacheMCPServersEnabledKey) }
    }

    /// Whether plugin data should be cached for offline access.
    @Published var pluginsEnabled: Bool {
        didSet { UserDefaults.standard.set(pluginsEnabled, forKey: AppConstants.offlineCachePluginsEnabledKey) }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        // Master toggle defaults to enabled
        isCacheEnabled = defaults.object(forKey: AppConstants.offlineCacheEnabledKey) as? Bool ?? true

        // Capacity defaults
        maxSessions = defaults.object(forKey: AppConstants.offlineCacheMaxSessionsKey) as? Int
            ?? OfflineCacheSettings.defaultMaxSessions
        cacheTTL = defaults.object(forKey: AppConstants.offlineCacheTTLKey) as? TimeInterval
            ?? OfflineCacheSettings.defaultCacheTTL

        // Per-type toggles — all enabled by default
        sessionsEnabled = defaults.object(forKey: AppConstants.offlineCacheSessionsEnabledKey) as? Bool ?? true
        messagesEnabled = defaults.object(forKey: AppConstants.offlineCacheMessagesEnabledKey) as? Bool ?? true
        projectsEnabled = defaults.object(forKey: AppConstants.offlineCacheProjectsEnabledKey) as? Bool ?? true
        skillsEnabled = defaults.object(forKey: AppConstants.offlineCacheSkillsEnabledKey) as? Bool ?? true
        mcpServersEnabled = defaults.object(forKey: AppConstants.offlineCacheMCPServersEnabledKey) as? Bool ?? true
        pluginsEnabled = defaults.object(forKey: AppConstants.offlineCachePluginsEnabledKey) as? Bool ?? true
    }

    // MARK: - Helpers

    /// Returns `true` when caching is globally enabled and the given data type is enabled.
    func isCachingEnabled(for type: CacheDataType) -> Bool {
        guard isCacheEnabled else { return false }
        switch type {
        case .sessions: return sessionsEnabled
        case .messages: return messagesEnabled
        case .projects: return projectsEnabled
        case .skills: return skillsEnabled
        case .mcpServers: return mcpServersEnabled
        case .plugins: return pluginsEnabled
        }
    }

    /// Resets all settings to their factory defaults.
    func resetToDefaults() {
        isCacheEnabled = true
        maxSessions = OfflineCacheSettings.defaultMaxSessions
        cacheTTL = OfflineCacheSettings.defaultCacheTTL
        sessionsEnabled = true
        messagesEnabled = true
        projectsEnabled = true
        skillsEnabled = true
        mcpServersEnabled = true
        pluginsEnabled = true
    }
}

// MARK: - CacheDataType

/// Enumeration of data types that can be individually toggled in the offline cache.
enum CacheDataType {
    case sessions
    case messages
    case projects
    case skills
    case mcpServers
    case plugins

    /// Human-readable display name for use in settings UI.
    var displayName: String {
        switch self {
        case .sessions: return "Sessions"
        case .messages: return "Messages"
        case .projects: return "Projects"
        case .skills: return "Skills"
        case .mcpServers: return "MCP Servers"
        case .plugins: return "Plugins"
        }
    }
}
