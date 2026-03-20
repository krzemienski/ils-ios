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
    /// Set by `handleURL()` for `ils://mcp`, `ils://skills`, `ils://plugins`, `ils://marketplace/mcp` routes.
    /// Consumed and cleared by SidebarRootView's `.onChange(of: navigationIntent)` handler.
    var browserSegmentIntent: BrowserSegment? = nil
    /// Server name pre-populated from `ils://mcp/install?server=<name>` deep links.
    /// Consumed and cleared by BrowserView when opening the install wizard.
    var pendingMCPInstallName: String? = nil
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
    let connectionQualityService: ConnectionQualityService
    let iCloudSyncManager: ICloudSyncManager
    let backendManager: BackendManager

    /// Conflict resolver for offline-first session cache reconciliation.
    let conflictResolver: ConflictResolver

    /// Observer token for `.backendDidActivate` — used to update `serverURL` on backend switch.
    @ObservationIgnored private var backendActivateObserver: NSObjectProtocol?

    /// Observer token for `.networkDidBecomeAvailable` — triggers cache reconciliation on reconnect.
    @ObservationIgnored private var networkReconnectObserver: NSObjectProtocol?

    // MARK: - Computed Helpers

    /// True when two or more backend connections are registered.
    var hasMultipleBackends: Bool { backendManager.backends.count > 1 }

    /// Manages pending permission requests from Claude Code tool-use calls.
    /// Full polling lifecycle (start/stop) is wired in ILSAppApp (phase-5).
    let permissionService = PermissionService()

    /// Tracks sessions eligible for recovery (terminated with error status and at least one checkpoint).
    /// Updated via `refreshRecoverableSessions()` whenever a backend connection is established.
    let recoveryService = SessionRecoveryService.shared

    /// Cached list of sessions eligible for recovery, mirrored from `SessionRecoveryService`.
    var recoverableSessions: [ChatSession] = []

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
    var connectionQuality: ConnectionQuality { connectionQualityService.quality }

    /// The current iCloud synchronization status.
    var iCloudSyncStatus: ICloudSyncStatus { iCloudSyncManager.syncStatus }

    /// The date of the most recent iCloud sync, or `nil` if no sync has occurred yet.
    var iCloudLastSyncDate: Date? { iCloudSyncManager.lastSyncDate }

    /// Whether iCloud sync is enabled on this device.
    var isSyncEnabled: Bool { iCloudSyncManager.isSyncEnabled }

    // MARK: - Version Monitoring

    var updateCheck: UpdateCheckResponse?
    var isCheckingUpdates = false

    /// Whether an update is available for the Claude Code CLI.
    var hasUpdateAvailable: Bool {
        updateCheck?.updateAvailable ?? false
    }

    init() {
        let cm = ConnectionManager()
        self.connectionManager = cm
        self.pollingManager = PollingManager(connectionManager: cm)
        self.networkMonitor = NetworkMonitor.shared
        self.connectionQualityService = ConnectionQualityService.shared
        self.iCloudSyncManager = ICloudSyncManager.shared
        self.backendManager = BackendManager.shared
        self.conflictResolver = ConflictResolver.shared
        self.activeHostName = UserDefaults.standard.string(forKey: "activeHostName")

        connectionQualityService.serverURL = cm.serverURL
        pollingManager.checkConnection()
        // Start quality polling at launch so returning users see the indicator immediately.
        // startPolling() is idempotent (guards against duplicate starts) and measure()
        // handles the offline case gracefully, so this is safe to call unconditionally.
        connectionQualityService.startPolling()

        // Load persisted backend connections asynchronously on first launch.
        Task {
            await backendManager.loadBackends()
        }

        // Observe active-backend switches and update serverURL for backward compat.
        backendActivateObserver = NotificationCenter.default.addObserver(
            forName: .backendDidActivate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let url = notification.userInfo?["url"] as? String else { return }
            Task { @MainActor [weak self] in
                self?.updateServerURL(url)
                self?.refreshRecoverableSessions()
            }
        }

        // Reconcile local cache with server when network connectivity is restored.
        // Triggers conflict detection and auto-resolution for sessions modified while offline.
        networkReconnectObserver = NotificationCenter.default.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await CacheService.shared.reconcileOnReconnect()
            }
        }
    }

    deinit {
        if let observer = backendActivateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = networkReconnectObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
        connectionQualityService.serverURL = url
        pollingManager.checkConnection()
    }

    func connectToServer(url: String) async throws {
        try await connectionManager.connectToServer(url: url)
        connectionQualityService.serverURL = url
        pollingManager.stopRetryPolling()
        pollingManager.startHealthPolling()
        connectionQualityService.startPolling()
        refreshRecoverableSessions()
    }

    func checkConnection() {
        pollingManager.checkConnection()
    }

    /// Refreshes the `recoverableSessions` list from `SessionRecoveryService`.
    ///
    /// Fetches only when the cache is stale or empty (throttled to once per 5 minutes).
    /// Call after a successful backend connection is established.
    func refreshRecoverableSessions() {
        Task {
            await recoveryService.refreshIfNeeded(client: apiClient)
            let sessions = await recoveryService.recoverableSessions
            recoverableSessions = sessions
        }
    }

    /// Check for available Claude Code CLI updates from GitHub.
    /// Runs silently in the background on app launch and periodically.
    /// Respects user preferences for check frequency (daily/weekly) and enabled state.
    func checkForUpdates() async {
        guard isConnected else { return }

        // Check user preferences for periodic checks
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "versionCheckEnabled") else {
            return
        }

        // Check if enough time has passed since last check
        if let lastCheck = defaults.object(forKey: "versionCheckLastRun") as? Date {
            let interval = defaults.string(forKey: "versionCheckInterval") ?? "daily"
            let now = Date()

            let intervalSeconds: TimeInterval
            switch interval {
            case "daily":
                intervalSeconds = 24 * 60 * 60
            case "weekly":
                intervalSeconds = 7 * 24 * 60 * 60
            default:
                intervalSeconds = 24 * 60 * 60
            }

            // Skip check if not enough time has passed
            if now.timeIntervalSince(lastCheck) < intervalSeconds {
                return
            }
        }

        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        do {
            let response: APIResponse<UpdateCheckResponse> = try await apiClient.get("/system/version/check-updates")
            updateCheck = response.data

            // Update last check timestamp on success
            defaults.set(Date(), forKey: "versionCheckLastRun")
        } catch {
            // Non-fatal: update check failure shouldn't block app launch
            // Silently log the error without showing to user
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        let appPhase: PollingManager.AppPhase
        switch phase {
        case .active:
            appPhase = .active
            backendManager.startHealthPolling()
            if isConnected {
                permissionService.startPolling(apiClient: apiClient)
            }
        case .inactive:
            appPhase = .inactive
        case .background:
            appPhase = .background
            backendManager.stopHealthPolling()
            permissionService.stopPolling()
        @unknown default:
            appPhase = .inactive
        }
        pollingManager.handleScenePhase(appPhase)
    }

    func updateLastSessionId(_ id: UUID?) {
        lastSessionId = id
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: AppConstants.lastSessionIDKey)
        }
    }

    // TODO: SUIN-001 — Queue deep link navigation with DispatchQueue.main.asyncAfter to avoid animation conflicts
    func handleURL(_ url: URL) {
        guard url.scheme == "ils" else { return }

        // Extract resource ID from path (e.g., ils://sessions/{uuid})
        let resourceId: UUID? = {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !path.isEmpty else { return nil }
            return UUID(uuidString: path)
        }()

        // Normalised path without leading/trailing slashes
        let pathComponent = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()

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
            if pathComponent == "install" {
                // ils://mcp/install?server=<name> — open Discover tab and pre-populate wizard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                pendingMCPInstallName = components?.queryItems?.first(where: { $0.name == "server" })?.value
                browserSegmentIntent = .discover
            } else {
                browserSegmentIntent = .mcp
            }
            navigationIntent = .browser
        case "marketplace":
            // ils://marketplace/mcp — open Discover tab scoped to MCP marketplace
            if pathComponent == "mcp" {
                browserSegmentIntent = .discover
                navigationIntent = .browser
            }
        case "mcp-marketplace":
            // Shorthand: ils://mcp-marketplace
            browserSegmentIntent = .discover
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
        case "backends":
            navigationIntent = .backends
        case "teams":
            navigationIntent = .teams
        case "activity":
            navigationIntent = .activityFeed
        case "unified-sessions", "all-sessions":
            navigationIntent = .unifiedSessions
        case "permissions":
            navigationIntent = .permissions
        case "usage":
            navigationIntent = .usage
        case "terminal":
            navigationIntent = .terminal
        case "documentation", "docs":
            navigationIntent = .documentation
        case "split-view", "splitview":
            navigationIntent = .splitView
        case "search":
            navigationIntent = .search
        case "analytics":
            navigationIntent = .analytics
        case "agent-queue", "queue":
            navigationIntent = .agentQueue
        case "workflows":
            navigationIntent = .workflows
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
