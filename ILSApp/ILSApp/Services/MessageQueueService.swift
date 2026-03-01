import Foundation
import Observation

// MARK: - QueuedMessage

/// A pending outgoing message awaiting delivery to the backend.
///
/// Stored in UserDefaults when the connection is unavailable, then
/// replayed in order once connectivity is restored.
struct QueuedMessage: Codable, Identifiable, Sendable {
    /// Unique identifier for deduplication.
    let id: UUID
    /// Session this message belongs to.
    let sessionId: UUID
    /// Plain-text content typed by the user.
    let content: String
    /// Timestamp when the message was queued.
    let queuedAt: Date

    init(id: UUID = UUID(), sessionId: UUID, content: String, queuedAt: Date = Date()) {
        self.id = id
        self.sessionId = sessionId
        self.content = content
        self.queuedAt = queuedAt
    }
}

// MARK: - MessageQueueService

/// Persists pending outgoing messages during connectivity loss and replays them on reconnection.
///
/// Backed by UserDefaults so messages survive app termination.
/// Observable `pendingCount` lets UI react to queue depth without polling.
@MainActor
@Observable
final class MessageQueueService {
    static let shared = MessageQueueService()

    /// Number of messages waiting to be delivered. Updates automatically after every mutation.
    private(set) var pendingCount: Int = 0

    private let defaultsKey = "com.ils.app.messageQueue"

    private init() {
        pendingCount = loadQueue().count
        AppLogger.shared.info("MessageQueueService initialized (\(pendingCount) pending)", category: "queue")
    }

    // MARK: - Queue Operations

    /// Add a message to the back of the queue and persist it.
    func enqueue(_ message: QueuedMessage) {
        var queue = loadQueue()
        queue.append(message)
        saveQueue(queue)
        pendingCount = queue.count
        AppLogger.shared.info(
            "Queued message for session \(message.sessionId) (pending: \(pendingCount))",
            category: "queue"
        )
        NotificationCenter.default.post(name: .messageQueueDidChange, object: nil)
    }

    /// Remove and return the oldest message in the queue, or `nil` if empty.
    @discardableResult
    func dequeue() -> QueuedMessage? {
        var queue = loadQueue()
        guard !queue.isEmpty else { return nil }
        let message = queue.removeFirst()
        saveQueue(queue)
        pendingCount = queue.count
        AppLogger.shared.info(
            "Dequeued message \(message.id) (pending: \(pendingCount))",
            category: "queue"
        )
        NotificationCenter.default.post(name: .messageQueueDidChange, object: nil)
        return message
    }

    /// Return all queued messages and clear the queue atomically.
    func dequeueAll() -> [QueuedMessage] {
        let queue = loadQueue()
        guard !queue.isEmpty else { return [] }
        saveQueue([])
        pendingCount = 0
        AppLogger.shared.info("Dequeued all \(queue.count) message(s)", category: "queue")
        NotificationCenter.default.post(name: .messageQueueDidChange, object: nil)
        return queue
    }

    /// Remove all pending messages without returning them.
    func clearQueue() {
        let previous = pendingCount
        saveQueue([])
        pendingCount = 0
        if previous > 0 {
            AppLogger.shared.info("Message queue cleared (\(previous) discarded)", category: "queue")
            NotificationCenter.default.post(name: .messageQueueDidChange, object: nil)
        }
    }

    // MARK: - Persistence

    private func loadQueue() -> [QueuedMessage] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [] }
        do {
            return try JSONDecoder().decode([QueuedMessage].self, from: data)
        } catch {
            AppLogger.shared.error(
                "Failed to decode message queue: \(error.localizedDescription)",
                category: "queue"
            )
            return []
        }
    }

    private func saveQueue(_ queue: [QueuedMessage]) {
        do {
            let data = try JSONEncoder().encode(queue)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            AppLogger.shared.error(
                "Failed to persist message queue: \(error.localizedDescription)",
                category: "queue"
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted after any mutation to the message queue (enqueue, dequeue, clear).
    static let messageQueueDidChange = Notification.Name("messageQueueDidChange")
}
