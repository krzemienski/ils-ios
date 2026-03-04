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
}
