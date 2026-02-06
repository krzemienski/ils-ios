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
    @Published var serverURL: String = "http://localhost:9090" {
        didSet {
            apiClient = APIClient(baseURL: serverURL)
            sseClient = SSEClient(baseURL: serverURL)
            checkConnection()
        }
    }
    @Published var selectedTab: String = "sessions"
    @Published var isServerConnected: Bool = false
    @Published var serverConnectionInfo: ConnectionResponse?

    var apiClient: APIClient
    var sseClient: SSEClient

    private var retryTask: Task<Void, Never>?
    private var healthPollTask: Task<Void, Never>?

    init() {
        let host = UserDefaults.standard.string(forKey: "serverHost") ?? "localhost"
        let port = UserDefaults.standard.integer(forKey: "serverPort")
        let actualPort = port > 0 ? port : 9090
        let url = "http://\(host):\(actualPort)"
        self.serverURL = url
        self.apiClient = APIClient(baseURL: url)
        self.sseClient = SSEClient(baseURL: url)
        checkConnection()
    }

    func checkConnection() {
        Task {
            do {
                let client = APIClient(baseURL: serverURL)
                _ = try await client.healthCheck()
                let wasDisconnected = !isConnected
                isConnected = true
                stopRetryPolling()
                startHealthPolling()
                if wasDisconnected {
                    // Notify views to reload after recovery
                    objectWillChange.send()
                }
            } catch {
                isConnected = false
                stopHealthPolling()
                startRetryPolling()
            }
        }
    }

    /// Start periodic polling to detect backend recovery
    private func startRetryPolling() {
        guard retryTask == nil else { return }
        retryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                guard !Task.isCancelled else { break }
                guard let self else { break }
                do {
                    let client = APIClient(baseURL: self.serverURL)
                    _ = try await client.healthCheck()
                    self.isConnected = true
                    self.stopRetryPolling()
                    self.startHealthPolling()
                    break
                } catch {
                    // Still disconnected, continue polling
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
