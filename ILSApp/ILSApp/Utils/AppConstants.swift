import Foundation

/// Centralized app-wide constants to eliminate magic strings.
enum AppConstants {
    /// Default backend server URL used when no user-configured URL is available.
    static let defaultServerURL = "http://localhost:9999"

    /// UserDefaults key for the persisted server URL.
    static let serverURLKey = "serverURL"
}
