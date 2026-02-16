import SwiftUI
import Observation
import ILSShared
import TipKit

@main
struct ILSAppApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("colorScheme") private var colorSchemePreference: String = "dark"
    @State private var showLaunchScreen = true

    private var computedColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil  // "system" follows device setting
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                SidebarRootView()
                    .environment(appState)
                    .environment(themeManager)
                    .environment(\.theme, themeManager.currentSnapshot)
                    .preferredColorScheme(computedColorScheme)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .onOpenURL { url in
                        appState.handleURL(url)
                    }

                if showLaunchScreen {
                    LaunchScreenView()
                        .environment(\.theme, themeManager.currentSnapshot)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // Configure TipKit onboarding system
                try? Tips.configure([
                    .displayFrequency(.daily),
                    .datastoreLocation(.applicationDefault)
                ])

                try? await Task.sleep(for: .seconds(2.2))
                withAnimation(.easeOut(duration: 0.5)) {
                    showLaunchScreen = false
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhase(newPhase)
        }
    }
}

/// Global application state — thin coordinator delegating to focused managers.
@MainActor
@Observable
class AppState {
    var selectedProject: Project?
    var selectedTab: String = "dashboard"
    var navigationIntent: ActiveScreen?
    var lastSessionId: UUID?
    var isOffline: Bool = false

    let connectionManager: ConnectionManager
    let pollingManager: PollingManager

    // MARK: - Forwarding Properties
    // With @Observable, SwiftUI automatically tracks through property chains,
    // so no Combine forwarding is needed.

    var isConnected: Bool { connectionManager.isConnected }
    var serverURL: String { connectionManager.serverURL }
    var apiClient: APIClient { connectionManager.apiClient }
    var sseClient: SSEClient { connectionManager.sseClient }
    var showOnboarding: Bool {
        get { connectionManager.showOnboarding }
        set { connectionManager.showOnboarding = newValue }
    }

    init() {
        let cm = ConnectionManager()
        self.connectionManager = cm
        self.pollingManager = PollingManager(connectionManager: cm)

        pollingManager.checkConnection()
    }

    func updateServerURL(_ url: String) {
        connectionManager.updateServerURL(url)
        pollingManager.checkConnection()
    }

    func connectToServer(url: String) async throws {
        try await connectionManager.connectToServer(url: url)
        pollingManager.stopRetryPolling()
        pollingManager.startHealthPolling()
    }

    func checkConnection() {
        pollingManager.checkConnection()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        pollingManager.handleScenePhase(phase)
    }

    func updateLastSessionId(_ id: UUID?) {
        lastSessionId = id
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: "ils_last_session_id")
        }
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "ils" else { return }

        // Extract resource ID from path (e.g., ils://sessions/{uuid})
        let resourceId: UUID? = {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !path.isEmpty else { return nil }
            return UUID(uuidString: path)
        }()

        switch url.host {
        case "home":
            navigationIntent = .home
        case "sessions":
            if let resourceId {
                navigateToSession(id: resourceId)
            } else {
                navigationIntent = .home
            }
        case "browser", "projects", "plugins", "mcp", "skills":
            navigationIntent = .browser
        case "settings":
            navigationIntent = .settings
        case "system":
            navigationIntent = .system
        case "fleet":
            navigationIntent = .fleet
        default:
            break
        }
    }

    private func navigateToSession(id: UUID) {
        Task {
            do {
                let response: APIResponse<ChatSession> = try await apiClient.get("/sessions/\(id.uuidString)")
                if let session = response.data {
                    navigationIntent = .chat(session)
                } else {
                    // API returned no data — open a minimal session
                    let session = ChatSession(id: id, name: "Session")
                    navigationIntent = .chat(session)
                }
            } catch {
                // Session not found in DB (may be external) — open with minimal info
                let session = ChatSession(id: id, name: "Session")
                navigationIntent = .chat(session)
            }
        }
    }
}
