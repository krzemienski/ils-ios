import Foundation
import Observation
import ILSShared

// SEC-MED-1: Centralized connection defaults — avoids scattered localhost hardcoding.
enum ConnectionDefaults {
    static let host = "localhost"
    static let port = 9999
    static let scheme = "http"

    /// Build default URL from components.
    static var defaultURL: String { "\(scheme)://\(host):\(port)" }
}

/// Manages server connection state, URL persistence, and client lifecycle.
@MainActor
@Observable
class ConnectionManager {
    var isConnected: Bool = false
    var serverURL: String = ""
    var showOnboarding: Bool = false

    var apiClient: APIClient
    var sseClient: SSEClient

    private(set) var isInitialized = false

    init() {
        // Try to load full URL first (supports https:// Cloudflare URLs)
        let url: String
        if let savedURL = UserDefaults.standard.string(forKey: "serverURL"), !savedURL.isEmpty {
            url = savedURL
        } else {
            let host = UserDefaults.standard.string(forKey: "serverHost") ?? ConnectionDefaults.host
            let port = UserDefaults.standard.integer(forKey: "serverPort")
            let actualPort = port > 0 ? port : ConnectionDefaults.port
            url = "\(ConnectionDefaults.scheme)://\(host):\(actualPort)"
        }

        self.apiClient = APIClient(baseURL: url)
        self.sseClient = SSEClient(baseURL: url)
        self.serverURL = url
        self.isInitialized = true
    }

    /// Update the server URL, persist to UserDefaults, recreate clients.
    func updateServerURL(_ url: String) {
        serverURL = url
        UserDefaults.standard.set(url, forKey: "serverURL")
        apiClient = APIClient(baseURL: url)
        sseClient = SSEClient(baseURL: url)
    }

    /// Connect to a server URL — validates, persists, and updates state atomically.
    func connectToServer(url: String) async throws {
        let cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let tempClient = APIClient(baseURL: cleanURL)
        _ = try await tempClient.healthCheck()

        updateServerURL(cleanURL)
        isConnected = true
        UserDefaults.standard.set(true, forKey: "hasConnectedBefore")
        showOnboarding = false
    }

    /// Show onboarding sheet if user has never successfully connected
    func showOnboardingIfNeeded() {
        let hasConnectedBefore = UserDefaults.standard.bool(forKey: "hasConnectedBefore")
        if !hasConnectedBefore && !showOnboarding {
            showOnboarding = true
        }
    }
}
