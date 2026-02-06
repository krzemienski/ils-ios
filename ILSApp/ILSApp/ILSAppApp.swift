import SwiftUI
import ILSShared

@main
struct ILSAppApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    appState.handleURL(url)
                }
                .sheet(isPresented: $appState.showOnboarding) {
                    ServerSetupSheet()
                        .environmentObject(appState)
                        .presentationBackground(Color.black)
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
    @Published var serverURL: String = "" {
        didSet {
            // Persist full URL to UserDefaults
            UserDefaults.standard.set(serverURL, forKey: "serverURL")
            apiClient = APIClient(baseURL: serverURL)
            sseClient = SSEClient(baseURL: serverURL)
            // Only check connection if not initializing
            if isInitialized {
                checkConnection()
            }
        }
    }
    @Published var selectedTab: String = "sessions"
    @Published var isServerConnected: Bool = false
    @Published var serverConnectionInfo: ConnectionResponse?

    // Spec 051: Session state persistence
    @Published var lastSessionId: UUID? {
        didSet {
            if let id = lastSessionId {
                UserDefaults.standard.set(id.uuidString, forKey: "ils_last_session_id")
            }
        }
    }

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
        
        // Initialize clients before setting serverURL to avoid didSet cascade
        self.apiClient = APIClient(baseURL: url)
        self.sseClient = SSEClient(baseURL: url)
        self.serverURL = url
        
        // Mark as initialized so didSet can call checkConnection
        self.isInitialized = true
        
        // Check connection asynchronously (non-blocking)
        checkConnection()
    }

    func checkConnection() {
        Task {
            do {
                print("🔵 Checking connection to: \(serverURL)")
                let client = APIClient(baseURL: serverURL)
                let response = try await client.healthCheck()
                print("✅ Connection successful! Response: \(response)")
                let wasDisconnected = !isConnected
                isConnected = true
                stopRetryPolling()
                startHealthPolling()
                if wasDisconnected {
                    // Notify views to reload after recovery
                    objectWillChange.send()
                }
            } catch let error as URLError {
                print("❌ Connection failed with URLError: \(error.code.rawValue) - \(error.localizedDescription)")
                print("   URL: \(serverURL)")
                print("   Error details: \(error)")
                isConnected = false
                stopHealthPolling()
                startRetryPolling()
                showOnboardingIfNeeded()
            } catch {
                print("❌ Connection failed with error: \(error.localizedDescription)")
                print("   URL: \(serverURL)")
                print("   Error type: \(type(of: error))")
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
        print("🔄 Starting retry polling (checking every 5 seconds)")
        retryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                guard !Task.isCancelled else { break }
                guard let self else { break }
                do {
                    print("🔄 Retry attempt to: \(self.serverURL)")
                    let client = APIClient(baseURL: self.serverURL)
                    let response = try await client.healthCheck()
                    print("✅ Reconnected! Response: \(response)")
                    self.isConnected = true
                    self.stopRetryPolling()
                    self.startHealthPolling()
                    break
                } catch {
                    print("⏳ Still disconnected, retrying in 5s...")
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
                    let client = APIClient(baseURL: self.serverURL)
                    _ = try await client.healthCheck()
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
        case "projects":
            selectedTab = "projects"
        case "plugins":
            selectedTab = "plugins"
        case "mcp":
            selectedTab = "mcp"
        case "sessions":
            selectedTab = "sessions"
        case "settings":
            selectedTab = "settings"
        case "skills":
            selectedTab = "skills"
        default:
            break
        }
    }
}
