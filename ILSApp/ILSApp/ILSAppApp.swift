import SwiftUI
import Observation
import ILSShared
import TipKit
import UserNotifications

@main
struct ILSAppApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("colorScheme") private var colorSchemePreference: String = "dark"
    @State private var showLaunchScreen = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .dynamicTypeSize(DynamicTypeSize.xSmall ... DynamicTypeSize.accessibility3)
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

                // Initialize local cache database
                await CacheService.shared.initialize()

                // Start observing network changes for retry queue
                await SyncCoordinator.shared.startObserving()
                // Setup notification handling
                await appState.setupNotifications()

                try? await Task.sleep(for: .seconds(2.2))
                if reduceMotion {
                    showLaunchScreen = false
                } else {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showLaunchScreen = false
                    }
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
    var browserSegmentIntent: BrowserSegment?
    var lastSessionId: UUID?
    var lastSyncDate: Date?

    /// Driven by NetworkMonitor — true when device has no network path.
    var isOffline: Bool { !networkMonitor.isConnected }

    let connectionManager: ConnectionManager
    let pollingManager: PollingManager
    let networkMonitor: NetworkMonitor

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
        self.networkMonitor = NetworkMonitor.shared

        Task { await pollingManager.checkConnection() }
    }

    // MARK: - Notification Handling

    func setupNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared

        // Request authorization
        await requestNotificationPermissions()
    }

    func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                // Permissions granted
            }
        } catch {
            // Handle error silently - user may have denied permissions
        }
    }

    func updateServerURL(_ url: String) {
        connectionManager.updateServerURL(url)
        Task { await pollingManager.checkConnection() }
    }

    func connectToServer(url: String) async throws {
        try await connectionManager.connectToServer(url: url)
        pollingManager.stopRetryPolling()
        pollingManager.startHealthPolling()
    }

    func checkConnection() {
        Task { await pollingManager.checkConnection() }
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
        case "browser", "projects":
            navigationIntent = .browser
        case "skills":
            browserSegmentIntent = .skills
            navigationIntent = .browser
        case "mcp":
            browserSegmentIntent = .mcp
            navigationIntent = .browser
        case "plugins":
            browserSegmentIntent = .plugins
            navigationIntent = .browser
        case "settings":
            navigationIntent = .settings
        case "system":
            navigationIntent = .system
        case "teams":
            // Parse path: ils://teams/test-team/workflow or ils://teams/test-team/dashboard or ils://teams/test-team/metrics
            let pathComponents = url.path.split(separator: "/").map(String.init)
            if pathComponents.count >= 2 {
                let teamName = pathComponents[0]
                let action = pathComponents[1]
                if action == "workflow" {
                    navigationIntent = .teamWorkflow(teamName)
                } else if action == "dashboard" {
                    navigationIntent = .teamDashboard(teamName)
                } else if action == "metrics" {
                    navigationIntent = .teamMetrics(teamName)
                } else {
                    navigationIntent = .teams
                }
            } else {
                navigationIntent = .teams
            }
        case "fleet", "hosts":
            navigationIntent = .hosts
        case "themes":
            navigationIntent = .themes
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

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() {
        super.init()
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Extract deep link URL from notification
        if let urlString = userInfo["url"] as? String,
           let url = URL(string: urlString) {
            // Post notification to open URL via deep link handler
            DispatchQueue.main.async {
                // Trigger deep link handling
                UIApplication.shared.open(url)
            }
        }

        completionHandler()
    }
}
