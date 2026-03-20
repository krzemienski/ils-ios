import Foundation
import ILSShared

/// Fetches and tracks sessions that are eligible for recovery.
///
/// A session is recoverable when it terminated with an error status and has at
/// least one checkpoint saved.  This actor caches the last-fetched list and
/// lets the caller dismiss individual sessions so they are no longer surfaced
/// in the recovery UI.
///
/// Dismissed session IDs are persisted in `UserDefaults` so the suppression
/// survives app restarts.  Call `refreshIfNeeded(client:)` on app foreground or
/// after a reconnect to keep the list current.
actor SessionRecoveryService {
    static let shared = SessionRecoveryService()

    // MARK: - Constants

    /// UserDefaults key for the array of dismissed session ID strings.
    private let dismissedKey = "recoveryDismissedSessionIDs"
    /// Minimum seconds between automatic refreshes (5 minutes).
    private let refreshThreshold: TimeInterval = 5 * 60

    private init() {}

    // MARK: - State

    /// Sessions currently eligible for recovery (not yet dismissed).
    private(set) var recoverableSessions: [ChatSession] = []

    /// Most-recently-fetched checkpoints keyed by session ID.
    private(set) var checkpointsBySession: [UUID: [SessionCheckpoint]] = [:]

    /// Timestamp of the last successful refresh.
    private var lastRefreshDate: Date?

    // MARK: - Dismissed IDs

    /// Session IDs the user has explicitly dismissed.
    var dismissedSessionIDs: Set<UUID> {
        let stored = UserDefaults.standard.stringArray(forKey: dismissedKey) ?? []
        return Set(stored.compactMap { UUID(uuidString: $0) })
    }

    // MARK: - Public API

    /// Marks a session as dismissed so it is hidden from recovery prompts.
    ///
    /// - Parameter sessionId: The session to suppress.
    func dismissRecovery(for sessionId: UUID) {
        var current = dismissedSessionIDs
        current.insert(sessionId)
        UserDefaults.standard.set(current.map { $0.uuidString }, forKey: dismissedKey)
        recoverableSessions.removeAll { $0.id == sessionId }
        checkpointsBySession.removeValue(forKey: sessionId)
        AppLogger.shared.info(
            "Recovery dismissed for session \(sessionId)",
            category: "recovery"
        )
    }

    /// Removes all dismissed session IDs, allowing previously suppressed sessions
    /// to appear again on the next refresh.
    func clearAllDismissed() {
        UserDefaults.standard.removeObject(forKey: dismissedKey)
        AppLogger.shared.info("All dismissed recovery sessions cleared", category: "recovery")
    }

    /// Refreshes recoverable sessions if the cache is stale or empty.
    ///
    /// This is a no-op when a refresh was performed within the last
    /// `refreshThreshold` seconds.  Call it on app foreground and after a
    /// successful server reconnect.
    ///
    /// - Parameter client: The `APIClient` instance used to reach the backend.
    func refreshIfNeeded(client: APIClient) async {
        if let last = lastRefreshDate,
           Date().timeIntervalSince(last) < refreshThreshold,
           !recoverableSessions.isEmpty {
            return
        }
        await refresh(client: client)
    }

    /// Forces an unconditional refresh regardless of cache age.
    ///
    /// - Parameter client: The `APIClient` instance used to reach the backend.
    func refresh(client: APIClient) async {
        do {
            let response: APIResponse<ListResponse<ChatSession>> =
                try await client.listRecoverableSessions()

            let dismissed = dismissedSessionIDs
            let all = response.data?.items ?? []
            let filtered = all.filter { !dismissed.contains($0.id) }

            recoverableSessions = filtered
            lastRefreshDate = Date()

            await fetchCheckpoints(for: filtered, client: client)

            AppLogger.shared.info(
                "Recoverable sessions refreshed — \(filtered.count) eligible",
                category: "recovery"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to fetch recoverable sessions: \(error.localizedDescription)",
                category: "recovery"
            )
        }
    }

    // MARK: - Private Helpers

    /// Fetches and caches checkpoints for each recoverable session.
    ///
    /// Errors for individual sessions are logged but do not abort the overall
    /// fetch; sessions whose checkpoints cannot be loaded are stored with an
    /// empty array.
    private func fetchCheckpoints(for sessions: [ChatSession], client: APIClient) async {
        await withTaskGroup(of: (UUID, [SessionCheckpoint]).self) { group in
            for session in sessions {
                group.addTask {
                    do {
                        let response: APIResponse<ListResponse<SessionCheckpoint>> =
                            try await client.listCheckpoints(sessionId: session.id)
                        return (session.id, response.data?.items ?? [])
                    } catch {
                        AppLogger.shared.error(
                            "Failed to fetch checkpoints for session \(session.id): \(error.localizedDescription)",
                            category: "recovery"
                        )
                        return (session.id, [])
                    }
                }
            }

            for await (sessionId, checkpoints) in group {
                checkpointsBySession[sessionId] = checkpoints
            }
        }
    }
}
