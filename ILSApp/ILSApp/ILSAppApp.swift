import SwiftUI
import ILSShared
import Combine

@main
struct ILSAppApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()
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
                    .environmentObject(appState)
                    .environmentObject(themeManager)
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
class AppState: ObservableObject {
    @Published var selectedProject: Project?
    @Published var selectedTab: String = "dashboard"
    @Published var navigationIntent: ActiveScreen?
    @Published var lastSessionId: UUID?
    @Published var isOffline: Bool = false
    @Published var showOnboarding: Bool = false

    let connectionManager: ConnectionManager
    let pollingManager: PollingManager

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Forwarding Properties

    var isConnected: Bool { connectionManager.isConnected }
    var serverURL: String { connectionManager.serverURL }
    var apiClient: APIClient { connectionManager.apiClient }
    var sseClient: SSEClient { connectionManager.sseClient }

    init() {
        let cm = ConnectionManager()
        self.connectionManager = cm
        self.pollingManager = PollingManager(connectionManager: cm)

        // Forward ConnectionManager changes so SwiftUI views observing AppState update
        cm.objectWillChange.sink { [weak self] (_: Void) in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        // Sync showOnboarding bidirectionally with removeDuplicates to prevent
        // infinite recursion (@Published emits on willSet before storage updates,
        // so property-read guards are unreliable — use stream dedup instead)
        cm.$showOnboarding.removeDuplicates().sink { [weak self] (value: Bool) in
            self?.showOnboarding = value
        }.store(in: &cancellables)

        $showOnboarding.dropFirst().removeDuplicates().sink { [weak cm] (value: Bool) in
            cm?.showOnboarding = value
        }.store(in: &cancellables)

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
