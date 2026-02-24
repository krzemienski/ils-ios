import SwiftUI
import ILSShared
/// Focused value key for the currently selected session
struct FocusedSessionKey: FocusedValueKey {
    typealias Value = ChatSession
}

extension FocusedValues {
    var selectedSession: ChatSession? {
        get { self[FocusedSessionKey.self] }
        set { self[FocusedSessionKey.self] = newValue }
    }
}

@main
struct ILSMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager()
    @State private var windowManager = WindowManager.shared
    @State private var notificationManager = NotificationManager.shared
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
        // Main application window
        WindowGroup {
            MacContentView()
                .environment(appState)
                .environment(themeManager)
                .environment(windowManager)
                .environment(notificationManager)
                .environment(\.theme, themeManager.currentSnapshot)
                .preferredColorScheme(computedColorScheme)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .onOpenURL { url in
                    appState.handleURL(url)
                }
                .task {
                    // Request notification permissions on first launch
                    do {
                        try await notificationManager.requestAuthorization()
                    } catch {
                        print("Failed to request notification permissions: \(error)")
                    }
                }
        }
        .defaultSize(width: 1200, height: 800)
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhase(newPhase)
        }
        .commands {
            ILSCommands()
        }
        // .windowRestorationBehavior(.enabled) // Requires macOS 15+

        // Session windows for multi-window support
        WindowGroup("Session", for: UUID.self) { $sessionId in
            if let sessionId {
                SessionWindowView(sessionId: sessionId)
                    .environment(appState)
                    .environment(themeManager)
                    .environment(windowManager)
                    .environment(notificationManager)
                    .environment(\.theme, themeManager.currentSnapshot)
                    .preferredColorScheme(computedColorScheme)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            } else {
                Text("No session selected")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .handlesExternalEvents(matching: Set(["session"]))
        // .windowRestorationBehavior(.enabled) // Requires macOS 15+
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
    var showOnboarding: Bool = false {
        didSet {
            if connectionManager.showOnboarding != showOnboarding {
                connectionManager.showOnboarding = showOnboarding
            }
        }
    }

    let connectionManager: ConnectionManager
    let pollingManager: PollingManager

    // MARK: - Forwarding Properties

    var isConnected: Bool { connectionManager.isConnected }
    var serverURL: String { connectionManager.serverURL }
    var apiClient: APIClient { connectionManager.apiClient }
    var sseClient: SSEClient { connectionManager.sseClient }

    init() {
        let cm = ConnectionManager()
        self.connectionManager = cm
        self.pollingManager = PollingManager(connectionManager: cm)

        // Sync initial onboarding state from ConnectionManager
        self.showOnboarding = cm.showOnboarding

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
        let appPhase: PollingManager.AppPhase
        switch phase {
        case .active: appPhase = .active
        case .inactive: appPhase = .inactive
        case .background: appPhase = .background
        @unknown default: appPhase = .inactive
        }
        pollingManager.handleScenePhase(appPhase)
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
        case "fleet", "profiles":
            navigationIntent = .hostProfiles
        case "themes":
            navigationIntent = .themes
        case "hooks":
            navigationIntent = .hooks
        case "teams":
            navigationIntent = .teams
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
                }
            } catch {
                // Session not found or network error — fall back to sessions list
                navigationIntent = .home
            }
        }
    }
}
