import SwiftUI
import ILSShared

/// Global application state — thin coordinator delegating to focused managers.
///
/// Shared by both iOS (ILSAppApp) and macOS (ILSMacApp) targets.
/// Lives in ILSApp/ILSApp/ which is included in both targets via project.yml.
@MainActor
@Observable
class AppState {
    var selectedProject: Project?
    var selectedTab: String = "dashboard"
    var navigationIntent: ActiveScreen?
    /// The browser segment to select when navigating via deep link.
    /// Set by `handleURL()` for `ils://mcp`, `ils://skills`, `ils://plugins` routes.
    /// Consumed and cleared by SidebarRootView's `.onChange(of: navigationIntent)` handler.
    var browserSegmentIntent: BrowserSegment? = nil
    var lastSessionId: UUID?
    var lastSyncDate: Date?

    /// The display name of the active host profile, or `nil` when no profile is selected.
    /// When connected with no profile, the sidebar shows "Local".
    /// Set by `HostProfilesViewModel.activate()` in Phase 34.
    var activeHostName: String? = nil

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
        self.activeHostName = UserDefaults.standard.string(forKey: "activeHostName")

        pollingManager.checkConnection()
    }

    // MARK: - Performance Test Mock Data

#if DEBUG
    /// Generates a predictable array of mock `ChatSession` objects for performance testing.
    ///
    /// Used by `LargeListRenderTests` when `PERF_ITEM_COUNT` is set in the launch environment.
    /// Each session is given a deterministic name, timestamp, and message count so that
    /// multiple test iterations produce identical cell layouts (avoiding measurement noise
    /// caused by varying label widths or accessory states).
    ///
    /// - Parameter count: The number of mock sessions to generate.
    /// - Returns: An array of `ChatSession` values suitable for populating a session list.
    static func makeMockSessions(count: Int) -> [ChatSession] {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let projects: [String] = ["ILS iOS", "Backend Service", "Claude Integration", "Performance Suite"]
        var result: [ChatSession] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            let status: SessionStatus = index % 5 == 0 ? .active : .completed
            let session = ChatSession(
                id: UUID(),
                name: "Perf Session \(index + 1)",
                projectName: projects[index % projects.count],
                model: "sonnet",
                status: status,
                messageCount: (index % 20) + 1,
                totalCostUSD: Double(index % 10) * 0.05,
                source: .ils,
                createdAt: baseDate.addingTimeInterval(Double(-index) * 120),
                lastActiveAt: baseDate.addingTimeInterval(Double(-index) * 60),
                firstPrompt: "Performance test \(index + 1): verifying render speed with predictable data"
            )
            result.append(session)
        }
        return result
    }
#endif

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
            UserDefaults.standard.set(id.uuidString, forKey: AppConstants.lastSessionIDKey)
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
        case "mcp":
            browserSegmentIntent = .mcp
            navigationIntent = .browser
        case "skills":
            browserSegmentIntent = .skills
            navigationIntent = .browser
        case "plugins":
            browserSegmentIntent = .plugins
            navigationIntent = .browser
        case "settings":
            navigationIntent = .settings
        case "system":
            navigationIntent = .system
        case "fleet", "profiles", "host-profiles":
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
