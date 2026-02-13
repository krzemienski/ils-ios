import SwiftUI
import ILSShared
import Combine

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
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var windowManager = WindowManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
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
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(windowManager)
                .environmentObject(notificationManager)
                .environment(\.theme, themeManager.currentTheme)
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
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhase(newPhase)
        }
        .commands {
            // Add keyboard shortcut Cmd+N for opening session in new window
            CommandGroup(after: .newItem) {
                OpenNewSessionWindowCommand(windowManager: windowManager)
            }
        }
        // .windowRestorationBehavior(.enabled) // Requires macOS 15+

        // Session windows for multi-window support
        WindowGroup("Session", for: UUID.self) { $sessionId in
            if let sessionId {
                SessionWindowView(sessionId: sessionId)
                    .environmentObject(appState)
                    .environmentObject(themeManager)
                    .environmentObject(windowManager)
                    .environmentObject(notificationManager)
                    .environment(\.theme, themeManager.currentTheme)
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

/// Command for opening a session in a new window
struct OpenNewSessionWindowCommand: View {
    let windowManager: WindowManager
    @FocusedValue(\.selectedSession) private var selectedSession: ChatSession?

    var body: some View {
        Button("Open in New Window") {
            if let session = selectedSession {
                windowManager.openSessionWindow(session)
            }
        }
        .keyboardShortcut("n", modifiers: [.command])
        .disabled(selectedSession == nil)
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
        case "projects", "plugins", "mcp", "skills":
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
                }
            } catch {
                // Session not found or network error — fall back to sessions list
                navigationIntent = .home
            }
        }
    }
}
