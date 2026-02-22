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
    private static let decoder = JSONDecoder()

    private var queue: [QueuedOperation] = []
    private var isDraining = false
    private var persistTask: Task<Void, Never>?
    private nonisolated let notificationObserver: NSObjectProtocol

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
            let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:9999"
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
    /// file write after a 200ms quiet period.
    private func persistQueue() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            guard !Task.isCancelled, let self else { return }
            await self.flushQueueToDisk()
        }
    }

    private func flushQueueToDisk() {
        do {
            let data = try encoder.encode(queue)
            try data.write(to: Self.queueFileURL, options: [.atomic])
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
