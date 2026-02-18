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
    private static let maxQueueSize = 100

    /// File URL for queue persistence (Application Support/ILS/SyncQueue/queue.json)
    private static let queueFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("ILS/SyncQueue", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            AppLogger.shared.error("Failed to create sync queue directory: \(error)", category: "sync")
        }
        var mutableDir = dir
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try mutableDir.setResourceValues(values)
        } catch {
            AppLogger.shared.warning("Failed to exclude sync queue from backup: \(error)", category: "sync")
        }
        return dir.appendingPathComponent("queue.json")
    }()

    private var queue: [QueuedOperation] = []
    private var isDraining = false
    private var networkObserver: (any NSObjectProtocol)?

    private init() {
        queue = Self.loadQueue()
    }

    /// Call once after creation to begin observing network availability.
    func startObserving() {
        guard networkObserver == nil else { return }
        let observer = NotificationCenter.default.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await SyncCoordinator.shared.drainQueue()
            }
        }
        networkObserver = observer
    }

    deinit {
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Enqueue a failed operation for later retry.
    func enqueue(method: String, endpoint: String, body: Data?) {
        // Reserve capacity upfront to reduce allocations during high-traffic enqueue bursts
        if queue.isEmpty {
            queue.reserveCapacity(16)
        }
        // Enforce max queue size to prevent unbounded growth
        guard queue.count < Self.maxQueueSize else {
            AppLogger.shared.warning(
                "Sync queue full (\(Self.maxQueueSize) items), dropping \(method) \(endpoint)",
                category: "sync"
            )
            return
        }
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

    // MARK: - Persistence

    private func persistQueue() {
        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: Self.queueFileURL, options: [.atomic, .completeFileProtection])
        } catch {
            AppLogger.shared.error(
                "Failed to persist sync queue: \(error.localizedDescription)",
                category: "sync"
            )
        }
    }

    private static func loadQueue() -> [QueuedOperation] {
        guard FileManager.default.fileExists(atPath: queueFileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: queueFileURL)
            return try JSONDecoder().decode([QueuedOperation].self, from: data)
        } catch {
            AppLogger.shared.error(
                "Failed to load sync queue: \(error.localizedDescription)",
                category: "sync"
            )
            return []
        }
    }
}
