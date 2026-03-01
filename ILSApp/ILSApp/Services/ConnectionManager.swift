import Foundation
import Observation
import ILSShared

// SEC-MED-1: Centralized connection defaults — avoids scattered localhost hardcoding.
enum ConnectionDefaults {
    static let host = "localhost"
    static let port = 9999
    // Intentionally "http" — the default connection is localhost-only.
    // Remote/tunnel connections use user-configured URLs (which may be https).
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

    // MARK: - Onboarding State

    /// True only on the first successful connection (hasConnectedBefore transitions false → true).
    var shouldShowFirstSessionWizard: Bool = false

    /// The date onboarding was completed, persisted to UserDefaults.
    var onboardingCompletedDate: Date? {
        get { UserDefaults.standard.object(forKey: "onboardingCompletionDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "onboardingCompletionDate") }
    }

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

        let wasFirstConnection = !UserDefaults.standard.bool(forKey: "hasConnectedBefore")

        updateServerURL(cleanURL)
        isConnected = true
        UserDefaults.standard.set(true, forKey: "hasConnectedBefore")
        // NOTE: showOnboarding is managed by the wizard via onComplete() in ServerSetupSheet

        // Trigger first-session wizard exactly once: when hasConnectedBefore flips false → true.
        if wasFirstConnection {
            shouldShowFirstSessionWizard = true
        }
    }

    /// Show onboarding sheet if user has never successfully connected
    func showOnboardingIfNeeded() {
        let hasConnectedBefore = UserDefaults.standard.bool(forKey: "hasConnectedBefore")
        if !hasConnectedBefore && !showOnboarding {
            showOnboarding = true
        }
    }

    /// Mark onboarding as complete and record the completion date.
    func markOnboardingComplete() {
        onboardingCompletedDate = Date()
        shouldShowFirstSessionWizard = false
        showOnboarding = false
    }

    /// Attempt to auto-detect a local backend at the default address.
    /// Returns the detected URL on success, nil if unreachable.
    func autoDetectLocalBackend() async -> String? {
        let localURL = ConnectionDefaults.defaultURL
        let tempClient = APIClient(baseURL: localURL)
        do {
            _ = try await tempClient.healthCheck()
            return localURL
        } catch {
            return nil
        }
    }
}
