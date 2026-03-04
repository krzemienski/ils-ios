#if os(iOS)
import BackgroundTasks
import Foundation
import ILSShared

/// Monitors active sessions in the background using BGTaskScheduler.
/// When iOS wakes the app via BGAppRefreshTask, checks each monitored session
/// and posts a local notification if the status changed to completed or error.
///
/// iOS-only: BGTaskScheduler is not available on macOS.
@MainActor
class SessionMonitorService {
    /// Singleton instance for app-wide access.
    static let shared = SessionMonitorService()

    /// Background task identifier registered in Info.plist.
    static let taskIdentifier = "com.ils.app.session-monitor"

    /// Session IDs currently being monitored.
    private var monitoredSessionIDs: Set<UUID> = []

    /// Display names keyed by session ID for notification titles.
    private var sessionNames: [UUID: String] = [:]

    /// API client used for polling. Strong reference so a reconstructed client
    /// (after app termination + BGTask relaunch) is retained for the duration of the task.
    private var apiClient: APIClient?

    // MARK: - UserDefaults Keys

    private static let idsKey = "sessionMonitor_ids"
    private static let namesKey = "sessionMonitor_names"
    private static let serverURLKey = "sessionMonitor_serverURL"

    private init() {}

    // MARK: - Session Registration

    /// Add a session to the monitored set.
    /// - Parameters:
    ///   - session: The session to monitor.
    ///   - apiClient: The API client to use for status polling.
    func addSession(_ session: ChatSession, apiClient: APIClient) {
        monitoredSessionIDs.insert(session.id)
        sessionNames[session.id] = session.displayName
        self.apiClient = apiClient
        // Persist base URL so a fresh BGTask process can reconstruct the client.
        UserDefaults.standard.set(apiClient.baseURL, forKey: Self.serverURLKey)
        persistToDisk()
        AppLogger.shared.info(
            "SessionMonitor: now watching \(monitoredSessionIDs.count) session(s)",
            category: "notifications"
        )
    }

    /// Remove a session from the monitored set.
    /// - Parameter sessionId: The ID of the session to stop monitoring.
    func removeSession(_ sessionId: UUID) {
        monitoredSessionIDs.remove(sessionId)
        sessionNames.removeValue(forKey: sessionId)
        persistToDisk()
        AppLogger.shared.info(
            "SessionMonitor: removed session \(sessionId), \(monitoredSessionIDs.count) remaining",
            category: "notifications"
        )
    }

    // MARK: - Background Task Scheduling

    /// Submit a BGAppRefreshTaskRequest so iOS wakes us up within ~60 seconds.
    /// Call this whenever there are sessions to monitor.
    func scheduleBackgroundTask() {
        guard !monitoredSessionIDs.isEmpty else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.shared.info(
                "SessionMonitor: background task scheduled",
                category: "notifications"
            )
        } catch {
            AppLogger.shared.error(
                "SessionMonitor: failed to schedule background task: \(error)",
                category: "notifications"
            )
        }
    }

    // MARK: - Background Task Handling

    /// Handle a BGAppRefreshTask wake-up by polling all monitored sessions.
    /// - Parameter task: The background task provided by the system.
    func handleBackgroundTask(_ task: BGAppRefreshTask) {
        // If the app was killed and relaunched by BGTaskScheduler, restore persisted sessions.
        if monitoredSessionIDs.isEmpty {
            restoreFromDisk()
        }

        // Snapshot the monitored set at task start.
        let sessionIDs = monitoredSessionIDs
        guard let client = apiClient, !sessionIDs.isEmpty else {
            task.setTaskCompleted(success: true)
            return
        }

        // Handle system expiration: mark task as failed if we run out of time.
        task.expirationHandler = {
            AppLogger.shared.warning(
                "SessionMonitor: background task expired before completion",
                category: "notifications"
            )
            task.setTaskCompleted(success: false)
        }

        Task {
            await pollSessions(sessionIDs: sessionIDs, apiClient: client)

            // Reschedule if sessions remain after this poll cycle.
            if !monitoredSessionIDs.isEmpty {
                scheduleBackgroundTask()
            }

            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - UserDefaults Persistence

    /// Write monitored session IDs and names to UserDefaults so they survive app termination.
    private func persistToDisk() {
        let idStrings = monitoredSessionIDs.map { $0.uuidString }
        UserDefaults.standard.set(idStrings, forKey: Self.idsKey)

        // Encode names as [String: String] for UserDefaults compatibility.
        let namesDict = Dictionary(uniqueKeysWithValues: sessionNames.map { ($0.key.uuidString, $0.value) })
        UserDefaults.standard.set(namesDict, forKey: Self.namesKey)
    }

    /// Restore monitored sessions from UserDefaults after the app was terminated.
    private func restoreFromDisk() {
        guard let idStrings = UserDefaults.standard.stringArray(forKey: Self.idsKey) else { return }
        let restoredIDs = Set(idStrings.compactMap { UUID(uuidString: $0) })
        guard !restoredIDs.isEmpty else { return }

        monitoredSessionIDs = restoredIDs

        if let namesDict = UserDefaults.standard.dictionary(forKey: Self.namesKey) as? [String: String] {
            sessionNames = Dictionary(uniqueKeysWithValues: namesDict.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        }

        // Reconstruct API client from persisted server URL if not already set.
        // This handles the case where the app was terminated by iOS and later relaunched
        // by BGTaskScheduler — apiClient is nil in the new process.
        if apiClient == nil,
           let urlString = UserDefaults.standard.string(forKey: Self.serverURLKey) {
            self.apiClient = APIClient(baseURL: urlString)
        }

        AppLogger.shared.info(
            "SessionMonitor: restored \(monitoredSessionIDs.count) session(s) from disk",
            category: "notifications"
        )
    }

    // MARK: - Private Polling

    /// Poll each session and fire notifications for terminal-state transitions.
    private func pollSessions(sessionIDs: Set<UUID>, apiClient: APIClient) async {
        await withTaskGroup(of: Void.self) { group in
            for sessionId in sessionIDs {
                group.addTask {
                    await self.pollSession(id: sessionId, apiClient: apiClient)
                }
            }
        }
    }

    private func pollSession(id: UUID, apiClient: APIClient) async {
        do {
            let session: ChatSession = try await apiClient.get("/sessions/\(id.uuidString)")
            let name = await MainActor.run { sessionNames[id] ?? session.displayName }

            switch session.status {
            case .completed:
                await NotificationService.shared.postStreamingCompleteNotification(
                    sessionId: id,
                    sessionName: name
                )
                await MainActor.run { removeSession(id) }

            case .error, .cancelled:
                let body = session.status == .error
                    ? "Session encountered an error"
                    : "Session was cancelled"
                await NotificationService.shared.postSessionErrorNotification(
                    sessionId: id,
                    sessionName: name,
                    errorMessage: body
                )
                await MainActor.run { removeSession(id) }

            case .active:
                // Still running — leave in monitored set for next poll cycle.
                break
            }
        } catch {
            AppLogger.shared.error(
                "SessionMonitor: failed to poll session \(id): \(error)",
                category: "notifications"
            )
        }
    }
}
#endif
