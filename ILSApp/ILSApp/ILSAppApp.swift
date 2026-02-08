import SwiftUI
import ILSShared

@main
struct ILSAppApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("colorScheme") private var colorSchemePreference: String = "dark"

    private var computedColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil  // "system" follows device setting
        }
    }

    var body: some Scene {
        WindowGroup {
            SidebarRootView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environment(\.theme, themeManager.currentTheme)
                .preferredColorScheme(computedColorScheme)
                .onOpenURL { url in
                    appState.handleURL(url)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhase(newPhase)
        }
    }
}

/// Global application state
@MainActor
class AppState: ObservableObject {
    @Published var selectedProject: Project?
    @Published var isConnected: Bool = false
    @Published var serverURL: String = ""
    @Published var selectedTab: String = "dashboard"

    /// Navigation intent for deep linking — consumed by SidebarRootView
    @Published var navigationIntent: ActiveScreen?

    // Spec 051: Session state persistence
    @Published var lastSessionId: UUID?

    // Spec 058: Offline mode detection
    @Published var isOffline: Bool = false

    // First-run onboarding
    @Published var showOnboarding: Bool = false

    var apiClient: APIClient
    var sseClient: SSEClient

    private var retryTask: Task<Void, Never>?
    private var healthPollTask: Task<Void, Never>?
    private var isInitialized = false

    init() {
        // Try to load full URL first (supports https:// Cloudflare URLs)
        let url: String
        if let savedURL = UserDefaults.standard.string(forKey: "serverURL"), !savedURL.isEmpty {
            url = savedURL
        } else {
            // Fallback to legacy host:port format or default
            let host = UserDefaults.standard.string(forKey: "serverHost") ?? "localhost"
            let port = UserDefaults.standard.integer(forKey: "serverPort")
            let actualPort = port > 0 ? port : 9090
            url = "http://\(host):\(actualPort)"
        }

        // Initialize clients and set URL directly (no didSet needed)
        self.apiClient = APIClient(baseURL: url)
        self.sseClient = SSEClient(baseURL: url)
        self.serverURL = url

        // Mark as initialized so updateServerURL can call checkConnection
        self.isInitialized = true

        // Check connection asynchronously (non-blocking)
        checkConnection()
    }

    /// Update the server URL, persist to UserDefaults, recreate clients, and check connection.
    /// Use this instead of assigning serverURL directly.
    func updateServerURL(_ url: String) {
        serverURL = url
        UserDefaults.standard.set(url, forKey: "serverURL")
        apiClient = APIClient(baseURL: url)
        sseClient = SSEClient(baseURL: url)
        if isInitialized {
            checkConnection()
        }
    }

    /// Update the last session ID and persist to UserDefaults.
    func updateLastSessionId(_ id: UUID?) {
        lastSessionId = id
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: "ils_last_session_id")
        }
    }

    func checkConnection() {
        Task {
            do {
                AppLogger.shared.info("Checking connection to: \(serverURL)", category: "app")
                let response = try await apiClient.healthCheck()
                AppLogger.shared.info("Connection successful! Response: \(response)", category: "app")
                isConnected = true
                stopRetryPolling()
                startHealthPolling()
            } catch let error as URLError {
                AppLogger.shared.error("Connection failed with URLError: \(error.code.rawValue) - \(error.localizedDescription)", category: "app")
                AppLogger.shared.error("URL: \(serverURL), details: \(error)", category: "app")
                isConnected = false
                stopHealthPolling()
                startRetryPolling()
                showOnboardingIfNeeded()
            } catch {
                AppLogger.shared.error("Connection failed: \(error.localizedDescription)", category: "app")
                AppLogger.shared.error("URL: \(serverURL), type: \(type(of: error))", category: "app")
                isConnected = false
                stopHealthPolling()
                startRetryPolling()
                showOnboardingIfNeeded()
            }
        }
    }

    /// Start periodic polling to detect backend recovery
    private func startRetryPolling() {
        guard retryTask == nil else { return }
        AppLogger.shared.info("Starting retry polling (every 5 seconds)", category: "app")
        retryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                guard !Task.isCancelled else { break }
                guard let self else { break }
                do {
                    AppLogger.shared.info("Retry attempt to: \(self.serverURL)", category: "app")
                    let response = try await self.apiClient.healthCheck()
                    AppLogger.shared.info("Reconnected! Response: \(response)", category: "app")
                    self.isConnected = true
                    self.stopRetryPolling()
                    self.startHealthPolling()
                    break
                } catch {
                    AppLogger.shared.warning("Still disconnected, retrying in 5s...", category: "app")
                }
            }
        }
    }

    /// Stop the retry polling timer
    private func stopRetryPolling() {
        retryTask?.cancel()
        retryTask = nil
    }

    /// Start periodic health check when connected (every 30 seconds)
    private func startHealthPolling() {
        guard healthPollTask == nil else { return }
        healthPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                guard !Task.isCancelled else { break }
                guard let self else { break }
                do {
                    _ = try await self.apiClient.healthCheck()
                    // Still connected
                } catch {
                    self.isConnected = false
                    self.stopHealthPolling()
                    self.startRetryPolling()
                    break
                }
            }
        }
    }

    /// Stop health polling
    private func stopHealthPolling() {
        healthPollTask?.cancel()
        healthPollTask = nil
    }

    /// Handle scene phase changes - stop polling in background, reconnect in foreground
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            checkConnection()
        case .background:
            stopHealthPolling()
            stopRetryPolling()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    /// Connect to a server URL — validates, persists, and updates state atomically.
    /// Used by ServerSetupSheet and Settings "Test Connection".
    func connectToServer(url: String) async throws {
        let cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        // Validate with a temporary client before committing the URL change
        let tempClient = APIClient(baseURL: cleanURL)
        _ = try await tempClient.healthCheck()

        // Success — update everything atomically (recreates self.apiClient with cleanURL)
        updateServerURL(cleanURL)
        isConnected = true
        UserDefaults.standard.set(true, forKey: "hasConnectedBefore")
        showOnboarding = false
        stopRetryPolling()
        startHealthPolling()
    }

    /// Show onboarding sheet if user has never successfully connected
    private func showOnboardingIfNeeded() {
        let hasConnectedBefore = UserDefaults.standard.bool(forKey: "hasConnectedBefore")
        if !hasConnectedBefore && !showOnboarding {
            showOnboarding = true
        }
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "ils" else { return }

        switch url.host {
        case "home":
            navigationIntent = .home
        case "sessions":
            navigationIntent = .home  // Sessions are in sidebar, go home to access
        case "projects", "plugins", "mcp", "skills":
            navigationIntent = .browser
        case "settings":
            navigationIntent = .settings
        case "system":
            navigationIntent = .system
        default:
            break
        }
    }
}
