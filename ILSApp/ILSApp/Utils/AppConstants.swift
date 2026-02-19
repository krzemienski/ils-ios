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
}
