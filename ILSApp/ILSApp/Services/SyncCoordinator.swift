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
}

// MARK: - SyncCoordinator

/// Manages a retry queue of failed API operations with exponential backoff.
///
/// Operations are persisted to UserDefaults and automatically drained
/// when the network becomes available. Max 3 retries before discarding.
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
    /// Network restoration observer. Stored for cleanup in deinit, though as a singleton
    /// this instance is never deallocated. The observer closure creates a new Task that
    /// accesses SyncCoordinator.shared (not capturing self), so no retain cycle exists.
    /// MEM-04: Verified — observer lifecycle is correct for singleton pattern.
    /// CONC-14: nonisolated(unsafe) because NSObjectProtocol doesn't conform to Sendable,
    /// but this observer is only ever created once in init and read in deinit — no data race.
    nonisolated(unsafe) private let notificationObserver: NSObjectProtocol

    private init() {
        queue = Self.loadQueue()
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
        AppLogger.shared.info(
            "Queued \(method) \(endpoint) for retry (queue size: \(queue.count))",
            category: "sync"
        )
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
        persistQueue()
        AppLogger.shared.info("Sync queue cleared", category: "sync")
    }

    // MARK: - Queue Drain

    private func drainQueue() async {
        guard !isDraining, !queue.isEmpty else { return }
        isDraining = true

        AppLogger.shared.info(
            "Draining sync queue (\(queue.count) operations)",
            category: "sync"
        )

        var remainingOperations: [QueuedOperation] = []

        for operation in queue {
            guard operation.retryCount < Self.maxRetries else {
                AppLogger.shared.warning(
                    "Discarding \(operation.method) \(operation.endpoint) after \(operation.retryCount) retries",
                    category: "sync"
                )
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
                } else {
                    AppLogger.shared.warning(
                        "Discarding \(operation.method) \(operation.endpoint) after max retries",
                        category: "sync"
                    )
                }
            } else {
                AppLogger.shared.info(
                    "Synced \(operation.method) \(operation.endpoint)",
                    category: "sync"
                )
            }
        }

        queue = remainingOperations
        persistQueue()
        isDraining = false
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
