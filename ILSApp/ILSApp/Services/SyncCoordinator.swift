import Foundation

// MARK: - Queued Operation

/// A failed API operation queued for retry when connectivity returns.
struct QueuedOperation: Codable, Identifiable, Sendable {
    let id: UUID
    let method: String      // "POST", "PUT", "DELETE"
    let endpoint: String    // e.g. "/sessions/abc/messages"
    let bodyData: Data?     // JSON-encoded request body
    let createdAt: Date
    var retryCount: Int
    var nextRetryAt: Date
    /// COD-004: Schema version for forward-compatible deserialization.
    /// Increment when the QueuedOperation format changes so old entries
    /// can be detected and migrated or discarded during loadQueue().
    let schemaVersion: Int

    init(
        method: String,
        endpoint: String,
        bodyData: Data?,
        retryCount: Int = 0
    ) {
        self.id = UUID()
        self.method = method
        self.endpoint = endpoint
        self.bodyData = bodyData
        self.createdAt = Date()
        self.retryCount = retryCount
        self.nextRetryAt = Date()
        self.schemaVersion = 1
    }

    /// Custom decoder to handle backward compatibility: existing persisted entries
    /// without `schemaVersion` default to version 1.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        method = try container.decode(String.self, forKey: .method)
        endpoint = try container.decode(String.self, forKey: .endpoint)
        bodyData = try container.decodeIfPresent(Data.self, forKey: .bodyData)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        retryCount = try container.decode(Int.self, forKey: .retryCount)
        nextRetryAt = try container.decode(Date.self, forKey: .nextRetryAt)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }

    /// Extract a session ID from the endpoint path, if present.
    /// Supports patterns like `/sessions/<uuid>/...` and `/sessions/<uuid>`.
    var sessionId: String? {
        let components = endpoint.split(separator: "/")
        guard let sessionsIndex = components.firstIndex(of: "sessions"),
              sessionsIndex + 1 < components.count else {
            return nil
        }
        return String(components[sessionsIndex + 1])
    }
}

// MARK: - SyncCoordinator

/// Manages a retry queue of failed API operations with exponential backoff.
///
/// Operations are persisted to Application Support and automatically drained
/// when the network becomes available. Max 3 retries before discarding.
///
/// Also tracks per-session sync status so the UI can show which sessions
/// have pending, syncing, synced, or failed changes.
actor SyncCoordinator {
    static let shared = SyncCoordinator()

    private static let maxRetries = 3
    private static let maxBackoffSeconds: Double = 30
    private static let storageKey = "ils_sync_queue"

    /// Reusable encoder/decoder — avoids allocating new instances on every
    /// persistQueue()/loadQueue() call (JSONEncoder/Decoder are expensive to init).
    private let encoder = JSONEncoder()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var queue: [QueuedOperation] = []
    private var isDraining = false
    private var persistTask: Task<Void, Never>?

    /// Per-session sync status map. Keyed by session ID string.
    /// Updated during drainQueue and trackChange operations.
    private(set) var syncStatusMap: [String: SyncStatus] = [:]

    /// Network restoration observer. Stored for cleanup in deinit, though as a singleton
    /// this instance is never deallocated. The observer closure creates a new Task that
    /// accesses SyncCoordinator.shared (not capturing self), so no retain cycle exists.
    /// MEM-04: Verified — observer lifecycle is correct for singleton pattern.
    /// CONC-14: nonisolated(unsafe) because NSObjectProtocol doesn't conform to Sendable,
    /// but this observer is only ever created once in init and read in deinit — no data race.
    nonisolated(unsafe) private let notificationObserver: NSObjectProtocol

    private init() {
        queue = Self.loadQueue()
        // Rebuild sync status map from loaded queue
        rebuildSyncStatusMap()
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await SyncCoordinator.shared.drainQueue()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(notificationObserver)
    }

    // MARK: - Public API

    /// Enqueue a failed operation for later retry.
    func enqueue(method: String, endpoint: String, body: Data?) {
        let operation = QueuedOperation(
            method: method,
            endpoint: endpoint,
            bodyData: body
        )
        queue.append(operation)
        persistQueue()

        // Update per-session sync status
        if let sessionId = operation.sessionId {
            updateSessionStatus(sessionId, to: .pending)
        }

        AppLogger.shared.info(
            "Queued \(method) \(endpoint) for retry (queue size: \(queue.count))",
            category: "sync"
        )
    }

    /// Record an offline mutation in the pending_changes table and update session sync status.
    ///
    /// - Parameters:
    ///   - entityType: The type of entity being changed (e.g. "session", "message").
    ///   - entityId: The unique ID of the entity being changed.
    ///   - changeType: The kind of mutation: "create", "update", or "delete".
    ///   - changeData: Optional JSON-encoded payload describing the change.
    func trackChange(entityType: String, entityId: String, changeType: String, changeData: Data?) {
        let change = PendingChange(
            id: UUID().uuidString,
            entityType: entityType,
            entityId: entityId,
            changeType: changeType,
            changeData: changeData,
            createdAt: Date(),
            status: "pending"
        )

        do {
            try LocalDatabase.shared.savePendingChange(change)
            AppLogger.shared.info(
                "Tracked \(changeType) change for \(entityType)/\(entityId)",
                category: "sync"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to track change for \(entityType)/\(entityId): \(error.localizedDescription)",
                category: "sync"
            )
        }

        // If the entity is a session, or belongs to a session, update status
        let sessionId = entityType == "session" ? entityId : extractSessionId(from: entityType, entityId: entityId)
        if let sessionId {
            updateSessionStatus(sessionId, to: .pending)
        }
    }

    /// Attempt to sync all pending changes for a single session.
    ///
    /// Filters the queue for operations matching the given session ID and
    /// attempts to execute them. Successfully synced operations are removed
    /// from the queue; failed ones remain for future retry.
    ///
    /// - Parameter sessionId: The session whose pending changes should be synced.
    func syncSession(sessionId: String) async {
        // Mark session as syncing
        updateSessionStatus(sessionId, to: .pending)

        let sessionOps = queue.filter { $0.sessionId == sessionId }
        guard !sessionOps.isEmpty else {
            // No queued operations — check pending_changes table
            await syncPendingChanges(for: sessionId)
            return
        }

        // Temporarily mark as syncing via notification
        postSyncStatusNotification()

        var remainingOps: [QueuedOperation] = []
        var allSucceeded = true

        for operation in sessionOps {
            let success = await executeOperation(operation)
            if !success {
                var updatedOp = operation
                updatedOp.retryCount += 1
                let backoff = min(
                    pow(2.0, Double(updatedOp.retryCount)),
                    Self.maxBackoffSeconds
                )
                updatedOp.nextRetryAt = Date().addingTimeInterval(backoff)
                remainingOps.append(updatedOp)
                allSucceeded = false
            }
        }

        // Remove synced operations, keep failed ones
        queue.removeAll { op in
            op.sessionId == sessionId && !remainingOps.contains(where: { $0.id == op.id })
        }
        // Re-insert updated failed operations
        for op in remainingOps {
            if let index = queue.firstIndex(where: { $0.id == op.id }) {
                queue[index] = op
            } else {
                queue.append(op)
            }
        }

        persistQueue()

        if allSucceeded {
            updateSessionStatus(sessionId, to: .synced)
            AppLogger.shared.info(
                "Session \(sessionId) sync completed successfully",
                category: "sync"
            )
        } else {
            updateSessionStatus(sessionId, to: .failed)
            AppLogger.shared.warning(
                "Session \(sessionId) sync partially failed (\(remainingOps.count) remaining)",
                category: "sync"
            )
        }
    }

    /// Return the current sync status for a given session.
    ///
    /// - Parameter sessionId: The session to query.
    /// - Returns: The current `SyncStatus`, or `.synced` if no status is tracked.
    func getSyncStatus(for sessionId: String) -> SyncStatus {
        syncStatusMap[sessionId] ?? .synced
    }

    /// Manually retry failed operations for a given session.
    ///
    /// Resets retry counts for the session's failed operations and triggers
    /// an immediate sync attempt.
    ///
    /// - Parameter sessionId: The session whose failed operations should be retried.
    func retryFailed(sessionId: String) async {
        // Reset retry counts for this session's operations
        for index in queue.indices where queue[index].sessionId == sessionId {
            queue[index].retryCount = 0
            queue[index].nextRetryAt = Date()
        }

        // Also reset pending_changes status for the session
        do {
            let allChanges = try LocalDatabase.shared.fetchAllPendingChanges()
            let sessionChanges = allChanges.filter { change in
                change.entityType == "session" && change.entityId == sessionId
            }
            for change in sessionChanges where change.status == "failed" {
                try LocalDatabase.shared.updatePendingChangeStatus(id: change.id, status: "pending")
            }
        } catch {
            AppLogger.shared.error(
                "Failed to reset pending changes for session \(sessionId): \(error.localizedDescription)",
                category: "sync"
            )
        }

        persistQueue()
        updateSessionStatus(sessionId, to: .pending)

        AppLogger.shared.info(
            "Retrying failed operations for session \(sessionId)",
            category: "sync"
        )

        // Trigger sync for this session
        await syncSession(sessionId: sessionId)
    }

    /// Number of operations waiting in the queue.
    var pendingCount: Int {
        queue.count
    }

    /// Manually trigger a drain attempt.
    func drainIfPossible() async {
        await drainQueue()
    }

    /// Clear all queued operations.
    func clearQueue() {
        queue.removeAll()
        syncStatusMap.removeAll()
        persistQueue()
        postSyncStatusNotification()
        AppLogger.shared.info("Sync queue cleared", category: "sync")
    }

    // MARK: - Per-Session Sync Status

    /// Update the sync status for a session and post a notification.
    private func updateSessionStatus(_ sessionId: String, to status: SyncStatus) {
        let previousStatus = syncStatusMap[sessionId]
        syncStatusMap[sessionId] = status

        // Remove synced sessions from the map to keep it lean
        if status == .synced {
            // Only keep synced status briefly — remove if no pending ops remain
            let hasRemainingOps = queue.contains { $0.sessionId == sessionId }
            if !hasRemainingOps {
                syncStatusMap.removeValue(forKey: sessionId)
            }
        }

        if previousStatus != status {
            postSyncStatusNotification()
        }
    }

    /// Rebuild the status map from the current queue state.
    /// Called on init after loading persisted queue.
    private func rebuildSyncStatusMap() {
        syncStatusMap.removeAll()
        for operation in queue {
            guard let sessionId = operation.sessionId else { continue }
            // If any op for this session has exhausted retries, mark as failed
            if operation.retryCount >= Self.maxRetries {
                syncStatusMap[sessionId] = .failed
            } else if syncStatusMap[sessionId] != .failed {
                // Otherwise mark as pending (don't downgrade from failed)
                syncStatusMap[sessionId] = .pending
            }
        }
    }

    /// Post sync status change notification on the main queue.
    private func postSyncStatusNotification() {
        let statusSnapshot = syncStatusMap
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .syncStatusDidChange,
                object: nil,
                userInfo: ["syncStatusMap": statusSnapshot]
            )
        }
    }

    /// Extract a session ID from related entity types.
    /// For messages, the entityId may encode the session relationship.
    private func extractSessionId(from entityType: String, entityId: String) -> String? {
        // For "message" entities, the entityId format may include the session ID
        // as a prefix (e.g. "sessionId:messageId"). Otherwise, callers should
        // use entityType == "session" directly.
        if entityType == "message" {
            let parts = entityId.split(separator: ":")
            if parts.count >= 2 {
                return String(parts[0])
            }
        }
        return nil
    }

    // MARK: - Pending Changes Sync

    /// Sync pending changes from the database for a specific session.
    private func syncPendingChanges(for sessionId: String) async {
        do {
            let allChanges = try LocalDatabase.shared.fetchAllPendingChanges()
            let sessionChanges = allChanges.filter { change in
                (change.entityType == "session" && change.entityId == sessionId) ||
                change.entityId.hasPrefix("\(sessionId):")
            }

            guard !sessionChanges.isEmpty else {
                updateSessionStatus(sessionId, to: .synced)
                return
            }

            var allSucceeded = true
            for change in sessionChanges where change.status == "pending" {
                // Mark as syncing
                try LocalDatabase.shared.updatePendingChangeStatus(id: change.id, status: "syncing")

                let success = await executePendingChange(change)
                if success {
                    try LocalDatabase.shared.deletePendingChange(id: change.id)
                } else {
                    try LocalDatabase.shared.updatePendingChangeStatus(id: change.id, status: "failed")
                    allSucceeded = false
                }
            }

            updateSessionStatus(sessionId, to: allSucceeded ? .synced : .failed)
        } catch {
            AppLogger.shared.error(
                "Failed to sync pending changes for session \(sessionId): \(error.localizedDescription)",
                category: "sync"
            )
            updateSessionStatus(sessionId, to: .failed)
        }
    }

    /// Execute a single pending change against the backend.
    private func executePendingChange(_ change: PendingChange) async -> Bool {
        do {
            let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? ConnectionDefaults.defaultURL
            let apiClient = APIClient(baseURL: baseURL)

            let method: String
            let endpoint: String

            switch change.changeType {
            case "create":
                method = "POST"
                endpoint = "/\(change.entityType)s"
            case "update":
                method = "PUT"
                endpoint = "/\(change.entityType)s/\(change.entityId)"
            case "delete":
                method = "DELETE"
                endpoint = "/\(change.entityType)s/\(change.entityId)"
            default:
                AppLogger.shared.warning(
                    "Unknown change type '\(change.changeType)' for \(change.entityType)/\(change.entityId)",
                    category: "sync"
                )
                return false
            }

            try await apiClient.rawRequest(
                method: method,
                endpoint: endpoint,
                body: change.changeData
            )
            return true
        } catch {
            AppLogger.shared.warning(
                "Failed to sync pending change \(change.id): \(error.localizedDescription)",
                category: "sync"
            )
            return false
        }
    }

    // MARK: - Queue Drain

    private func drainQueue() async {
        guard !isDraining, !queue.isEmpty else { return }
        isDraining = true

        AppLogger.shared.info(
            "Draining sync queue (\(queue.count) operations)",
            category: "sync"
        )

        // Collect session IDs that are about to be synced and mark them as syncing
        let syncingSessionIds = Set(queue.compactMap(\.sessionId))
        for sessionId in syncingSessionIds {
            syncStatusMap[sessionId] = .pending
        }
        postSyncStatusNotification()

        var remainingOperations: [QueuedOperation] = []
        var succeededSessionIds: Set<String> = []
        var failedSessionIds: Set<String> = []

        for operation in queue {
            guard operation.retryCount < Self.maxRetries else {
                AppLogger.shared.warning(
                    "Discarding \(operation.method) \(operation.endpoint) after \(operation.retryCount) retries",
                    category: "sync"
                )
                if let sessionId = operation.sessionId {
                    failedSessionIds.insert(sessionId)
                }
                continue
            }

            // Check if it's time to retry
            guard Date() >= operation.nextRetryAt else {
                remainingOperations.append(operation)
                continue
            }

            let success = await executeOperation(operation)

            if !success {
                var updatedOp = operation
                updatedOp.retryCount += 1
                let backoff = min(
                    pow(2.0, Double(updatedOp.retryCount)),
                    Self.maxBackoffSeconds
                )
                updatedOp.nextRetryAt = Date().addingTimeInterval(backoff)

                if updatedOp.retryCount < Self.maxRetries {
                    remainingOperations.append(updatedOp)
                    AppLogger.shared.warning(
                        "Retry \(updatedOp.retryCount)/\(Self.maxRetries) for \(operation.method) \(operation.endpoint), next in \(Int(backoff))s",
                        category: "sync"
                    )
                    if let sessionId = operation.sessionId {
                        failedSessionIds.insert(sessionId)
                    }
                } else {
                    AppLogger.shared.warning(
                        "Discarding \(operation.method) \(operation.endpoint) after max retries",
                        category: "sync"
                    )
                    if let sessionId = operation.sessionId {
                        failedSessionIds.insert(sessionId)
                    }
                }
            } else {
                AppLogger.shared.info(
                    "Synced \(operation.method) \(operation.endpoint)",
                    category: "sync"
                )
                if let sessionId = operation.sessionId {
                    succeededSessionIds.insert(sessionId)
                }
            }
        }

        queue = remainingOperations
        persistQueue()
        isDraining = false

        // Update per-session sync status based on drain results
        // Sessions with remaining operations in the queue are still pending/failed
        let remainingSessionIds = Set(remainingOperations.compactMap(\.sessionId))

        for sessionId in syncingSessionIds {
            if failedSessionIds.contains(sessionId) {
                updateSessionStatus(sessionId, to: .failed)
            } else if remainingSessionIds.contains(sessionId) {
                updateSessionStatus(sessionId, to: .pending)
            } else if succeededSessionIds.contains(sessionId) {
                updateSessionStatus(sessionId, to: .synced)
            }
        }
    }

    private func executeOperation(_ operation: QueuedOperation) async -> Bool {
        do {
            // Build the request directly to avoid MainActor dependency on ConnectionManager.
            // Read the server URL from UserDefaults (same source ConnectionManager uses).
            let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? ConnectionDefaults.defaultURL
            let apiClient = APIClient(baseURL: baseURL)
            try await apiClient.rawRequest(
                method: operation.method,
                endpoint: operation.endpoint,
                body: operation.bodyData
            )
            return true
        } catch {
            return false
        }
    }

    // MARK: - Persistence (file-backed in Application Support)

    /// File URL for persisting the sync queue. Uses Application Support instead of
    /// UserDefaults because queued operations can contain arbitrary-size request bodies
    /// and UserDefaults is not designed for large data blobs.
    private static var queueFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ILS", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("sync_queue.json")
    }

    /// Debounced persist: coalesces rapid queue mutations into a single
    /// file write after a quiet period (500ms normal, 2s in Low Power Mode).
    private func persistQueue() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            // ENRG-005: Increase debounce from 500ms to 2s in Low Power Mode to reduce I/O.
            let isLPM = await LowPowerModeMonitor.shared.isLowPowerModeEnabled
            let debounceNanos: UInt64 = isLPM ? 2_000_000_000 : 500_000_000
            try? await Task.sleep(nanoseconds: debounceNanos)
            guard !Task.isCancelled, let self else { return }
            await self.flushQueueToDisk()
        }
    }

    private func flushQueueToDisk() {
        let url = Self.queueFileURL

        // ENRG-005: Don't write empty queue — delete the file instead
        if queue.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }

        do {
            let data = try encoder.encode(queue)
            // PERF-006: Only use atomic write for files > 1KB. Atomic write creates
            // a temporary copy then renames, doubling I/O. For small queue files the
            // data-loss risk from non-atomic write is negligible vs. the I/O overhead.
            let writeOptions: Data.WritingOptions = data.count > 1024 ? [.atomic] : []
            try data.write(to: url, options: writeOptions)

            // STOR-002: Exclude sync queue from iCloud backup (contains chat message bodies)
            var mutableURL = url
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try mutableURL.setResourceValues(resourceValues)
        } catch {
            AppLogger.shared.error(
                "Failed to persist sync queue: \(error.localizedDescription)",
                category: "sync"
            )
        }
    }

    private static func loadQueue() -> [QueuedOperation] {
        let url = queueFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Migrate from UserDefaults if data exists there (one-time)
            if let legacyData = UserDefaults.standard.data(forKey: storageKey) {
                UserDefaults.standard.removeObject(forKey: storageKey)
                do {
                    let ops = try decoder.decode([QueuedOperation].self, from: legacyData)
                    try legacyData.write(to: url, options: [.atomic])
                    return ops
                } catch {
                    return []
                }
            }
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([QueuedOperation].self, from: data)
        } catch {
            AppLogger.shared.error(
                "Failed to load sync queue: \(error.localizedDescription)",
                category: "sync"
            )
            return []
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted after the per-session sync status map changes.
    /// `userInfo` contains `["syncStatusMap": [String: SyncStatus]]`.
    static let syncStatusDidChange = Notification.Name("syncStatusDidChange")
}
