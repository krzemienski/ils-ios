import Foundation

/// Centralized app-wide constants to eliminate magic strings.
enum AppConstants {
    /// Default backend server URL used when no user-configured URL is available.
    static let defaultServerURL = "http://localhost:9999"

    // MARK: - UserDefaults Keys

    /// UserDefaults key for the persisted server URL.
    static let serverURLKey = "serverURL"

    /// UserDefaults key for the server hostname (legacy fallback).
    static let serverHostKey = "serverHost"

    /// UserDefaults key for the server port number (legacy fallback).
    static let serverPortKey = "serverPort"

    /// UserDefaults key tracking whether the user has connected at least once.
    static let hasConnectedBeforeKey = "hasConnectedBefore"

    /// UserDefaults key for recent connection URL history.
    static let connectionHistoryKey = "connectionHistory"

    /// UserDefaults key for the Settings-persisted server host (display only).
    static let settingsServerHostKey = "ils_server_host"

    /// UserDefaults key for the Settings-persisted server port (display only).
    static let settingsServerPortKey = "ils_server_port"

    /// UserDefaults key for analytics opt-in preference.
    static let analyticsOptedInKey = "analytics_opted_in"

    /// UserDefaults key for the last-opened session ID (macOS).
    static let lastSessionIDKey = "ils_last_session_id"

    /// UserDefaults key for the user's preferred default model.
    static let defaultModelKey = "defaultModel"

    /// The user's preferred default model, reading from UserDefaults.
    /// Falls back to "sonnet" if no preference is set.
    static var defaultModel: String {
        UserDefaults.standard.string(forKey: defaultModelKey) ?? "sonnet"
    }

    /// UserDefaults key for cache configuration settings.
    static let cacheConfigKey = "cacheConfig"

    // MARK: - Cache Configuration

    /// Default cache size limit in megabytes (50MB).
    static let defaultCacheSizeMB = 50

    /// Maximum cache size limit in megabytes (100MB).
    static let maxCacheSizeMB = 100

    /// Default cache time-to-live in seconds (5 minutes).
    static let defaultCacheTTL = 300

    // MARK: - iCloud Sync Keys

    /// iCloud KV store key for the synced server URL.
    static let iCloudServerURLKey = "ils_icloud_server_url"

    /// iCloud KV store key for the synced default model preference.
    static let iCloudDefaultModelKey = "ils_icloud_default_model"

    /// iCloud KV store key for the synced active theme identifier.
    static let iCloudActiveThemeKey = "ils_icloud_active_theme"

    /// iCloud KV store key for the synced skill favorites list.
    static let iCloudSkillFavoritesKey = "ils_icloud_skill_favorites"

    /// iCloud KV store key for the synced session bookmarks.
    static let iCloudSessionBookmarksKey = "ils_icloud_session_bookmarks"

    /// iCloud KV store key for the synced notification preferences.
    static let iCloudNotificationPrefsKey = "ils_icloud_notification_prefs"

    /// iCloud KV store key for the synced active host profile name.
    static let iCloudActiveHostNameKey = "ils_icloud_active_host_name"

    // MARK: - Quick Reply Templates Keys

    /// UserDefaults key for persisted custom quick reply templates.
    static let quickReplyTemplatesKey = "quick_reply_templates"

    /// iCloud KV store key for the synced custom quick reply templates.
    static let iCloudQuickReplyTemplatesKey = "ils_icloud_quick_reply_templates"

    // MARK: - Command Palette Keys

    /// UserDefaults key for the command palette recently used command IDs (array of String).
    static let commandPaletteRecentCommandsKey = "commandPaletteRecentCommands"

    /// UserDefaults key for the command palette per-command usage counts (JSON-encoded [String: Int]).
    static let commandPaletteUsageCountKey = "commandPaletteUsageCount"

    // MARK: - Keyboard Shortcut Keys

    /// UserDefaults key for custom keyboard shortcut bindings (JSON-encoded [String: KeyboardShortcutConfig]).
    static let keyboardShortcutBindingsKey = "keyboardShortcutBindings"

    // MARK: - Hooks Builder Keys

    /// UserDefaults key for the set of disabled hook identifiers.
    /// Stored as a JSON-encoded array of hook ID strings.
    static let disabledHooksKey = "ils_disabled_hooks"

    /// UserDefaults key for the hook execution log.
    /// Stored as a JSON-encoded array of HookExecutionRecord values.
    static let hookExecutionLogKey = "ils_hook_execution_log"

    // MARK: - Dashboard Layout Keys

    /// UserDefaults / NSUbiquitousKeyValueStore key for the JSON-encoded array of ``DashboardLayout`` objects.
    static let dashboardLayoutsKey = "dashboard_layouts"

    /// UserDefaults / NSUbiquitousKeyValueStore key for the UUID string of the active ``DashboardLayout``.
    static let dashboardActiveLayoutIDKey = "dashboard_active_layout_id"

    /// UserDefaults key for the dashboard iCloud Key-Value Store sync enabled flag.
    static let dashboardICloudSyncEnabledKey = "dashboard_icloud_sync_enabled"

    /// UserDefaults key for the widget auto-refresh interval in seconds.
    /// Default value is 30 seconds; valid options are 15, 30, 60, and 300.
    static let dashboardWidgetRefreshIntervalKey = "dashboard_widget_refresh_interval"

    // MARK: - Offline Cache Settings Keys

    /// UserDefaults key for whether offline caching is enabled.
    static let offlineCacheEnabledKey = "offline_cache_enabled"

    /// UserDefaults key for the maximum number of sessions to cache offline.
    static let offlineCacheMaxSessionsKey = "offline_cache_max_sessions"

    /// UserDefaults key for the cache TTL in seconds.
    static let offlineCacheTTLKey = "offline_cache_ttl"

    /// UserDefaults key for whether session caching is enabled.
    static let offlineCacheSessionsEnabledKey = "offline_cache_sessions_enabled"

    /// UserDefaults key for whether message caching is enabled.
    static let offlineCacheMessagesEnabledKey = "offline_cache_messages_enabled"

    /// UserDefaults key for whether project caching is enabled.
    static let offlineCacheProjectsEnabledKey = "offline_cache_projects_enabled"

    /// UserDefaults key for whether skills caching is enabled.
    static let offlineCacheSkillsEnabledKey = "offline_cache_skills_enabled"

    /// UserDefaults key for whether MCP server caching is enabled.
    static let offlineCacheMCPServersEnabledKey = "offline_cache_mcp_servers_enabled"

    /// UserDefaults key for whether plugin caching is enabled.
    static let offlineCachePluginsEnabledKey = "offline_cache_plugins_enabled"

    /// UserDefaults key for whether auto-resolve conflicts is enabled.
    static let offlineCacheAutoResolveConflictsKey = "offline_cache_auto_resolve_conflicts"

    // MARK: - Chat Draft Limits

    /// Maximum number of chat drafts to retain in UserDefaults.
    /// Older drafts beyond this cap should be pruned to prevent unbounded storage growth.
    static let maxChatDrafts = 50

    // MARK: - Permission Polling Intervals

    /// Permission polling interval in nanoseconds under normal conditions (5 seconds).
    static let permissionPollingInterval: UInt64 = 5_000_000_000

    /// Permission polling interval in nanoseconds when Low Power Mode is active (10 seconds).
    static let permissionPollingIntervalLPM: UInt64 = 10_000_000_000
}
