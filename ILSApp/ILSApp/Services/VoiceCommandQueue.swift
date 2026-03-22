#if os(iOS)
import Foundation
import Observation

// MARK: - QueuedCommandStatus

/// Status of a queued voice command.
enum QueuedCommandStatus: String, Codable, Sendable {
    /// Waiting to be executed when connectivity returns.
    case pending
    /// Currently being executed.
    case executing
    /// Successfully executed.
    case completed
    /// Execution failed after retries.
    case failed
    /// Expired before execution (stale command).
    case expired
}

// MARK: - QueuedVoiceCommand

/// A voice command queued for offline execution with persistence support.
struct QueuedVoiceCommand: Codable, Identifiable, Sendable {
    let id: UUID
    /// Reference to the VoiceCommand catalog entry by its stable identifier.
    let commandId: String
    /// Key-value parameters for the command (e.g., session name, workflow ID).
    let parameters: [String: String]
    /// When the command was queued.
    let createdAt: Date
    /// Current status of this queued command.
    var status: QueuedCommandStatus
    /// Number of execution attempts.
    var retryCount: Int
    /// When this command expires (createdAt + 5 minutes).
    let expiresAt: Date
    /// Next retry time (exponential backoff).
    var nextRetryAt: Date
    /// Schema version for forward-compatible deserialization.
    let schemaVersion: Int

    init(
        commandId: String,
        parameters: [String: String] = [:],
        retryCount: Int = 0
    ) {
        self.id = UUID()
        self.commandId = commandId
        self.parameters = parameters
        self.createdAt = Date()
        self.status = .pending
        self.retryCount = retryCount
        self.expiresAt = Date().addingTimeInterval(5 * 60) // 5 minutes
        self.nextRetryAt = Date()
        self.schemaVersion = 1
    }

    /// Custom decoder for backward compatibility: entries without `schemaVersion`
    /// default to version 1.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        commandId = try container.decode(String.self, forKey: .commandId)
        parameters = try container.decode([String: String].self, forKey: .parameters)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decode(QueuedCommandStatus.self, forKey: .status)
        retryCount = try container.decode(Int.self, forKey: .retryCount)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        nextRetryAt = try container.decode(Date.self, forKey: .nextRetryAt)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
}

// MARK: - VoiceCommandQueueError

/// Errors specific to voice command queueing.
enum VoiceCommandQueueError: LocalizedError {
    /// The command does not support offline execution.
    case notOfflineCapable
    /// The command was not found in the catalog.
    case commandNotFound(String)
    /// The queue is full.
    case queueFull
    /// Offline queueing is disabled in user settings.
    case queueDisabled

    var errorDescription: String? {
        switch self {
        case .notOfflineCapable:
            return "This command cannot be queued for offline execution."
        case .commandNotFound(let id):
            return "Command '\(id)' not found in catalog."
        case .queueFull:
            return "Voice command queue is full. Please wait for pending commands to execute."
        case .queueDisabled:
            return "Offline voice command queueing is disabled in settings."
        }
    }
}

// MARK: - VoiceCommandQueue

/// Manages offline queueing of voice commands with file-based persistence.
///
/// Commands are enqueued when the device is offline and automatically drained
/// when connectivity returns. Only commands marked as `offlineCapable` can be
/// queued. Commands expire after 5 minutes to prevent stale actions from executing.
///
/// Follows the actor pattern established by `SyncCoordinator` with exponential
/// backoff (max 3 retries, 30s max backoff) and debounced file persistence.
actor VoiceCommandQueue {
    static let shared = VoiceCommandQueue()

    private static let maxRetries = 3
    private static let maxBackoffSeconds: Double = 30
    private static let maxQueueSize = 20

    /// Reusable encoder — avoids allocating new instances on every persist call.
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var queue: [QueuedVoiceCommand] = []
    private var isDraining = false
    private var persistTask: Task<Void, Never>?

    /// Network restoration observer. See SyncCoordinator for pattern rationale.
    /// CONC-14: nonisolated(unsafe) because NSObjectProtocol doesn't conform to Sendable,
    /// but this observer is only ever created once in init and read in deinit.
    nonisolated(unsafe) private let notificationObserver: NSObjectProtocol

    private init() {
        queue = Self.loadQueue()
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await VoiceCommandQueue.shared.drainQueue()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(notificationObserver)
    }

    // MARK: - Public API

    /// Enqueue a voice command for offline execution.
    ///
    /// Only commands with `offlineCapable == true` can be queued. Commands that
    /// are not offline-capable will throw `VoiceCommandQueueError.notOfflineCapable`.
    ///
    /// - Parameters:
    ///   - command: The voice command to queue.
    ///   - parameters: Optional key-value parameters for the command.
    /// - Throws: `VoiceCommandQueueError` if the command cannot be queued.
    func enqueue(_ command: VoiceCommand, parameters: [String: String] = [:]) throws {
        // Check user preference for offline queueing
        let offlineEnabled = UserDefaults.standard.object(forKey: "voiceCommandOfflineQueue") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "voiceCommandOfflineQueue")
        guard offlineEnabled else {
            throw VoiceCommandQueueError.queueDisabled
        }

        guard command.offlineCapable else {
            throw VoiceCommandQueueError.notOfflineCapable
        }

        // Expire stale commands before checking queue size
        expireStaleCommands()

        let pendingCount = queue.filter { $0.status == .pending }.count
        guard pendingCount < Self.maxQueueSize else {
            throw VoiceCommandQueueError.queueFull
        }

        let queued = QueuedVoiceCommand(
            commandId: command.id,
            parameters: parameters
        )
        queue.append(queued)
        persistQueue()

        AppLogger.shared.info(
            "Queued voice command '\(command.id)' for offline execution (queue size: \(queue.count))",
            category: "voice-queue"
        )
    }

    /// Number of pending operations in the queue.
    var pendingCount: Int {
        queue.filter { $0.status == .pending }.count
    }

    /// All queued commands (for UI display).
    var allQueued: [QueuedVoiceCommand] {
        queue
    }

    /// Manually trigger a drain attempt.
    func drainIfPossible() async {
        await drainQueue()
    }

    /// Clear all queued commands.
    func clearQueue() {
        queue.removeAll()
        persistQueue()
        AppLogger.shared.info("Voice command queue cleared", category: "voice-queue")
    }

    /// Remove completed and failed entries from the queue.
    func pruneFinished() {
        queue.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .expired }
        persistQueue()
    }

    // MARK: - Expiration

    /// Remove commands that have exceeded their 5-minute expiration window.
    func expireStaleCommands() {
        let now = Date()
        var expired = false

        for i in queue.indices where queue[i].status == .pending && now >= queue[i].expiresAt {
            queue[i].status = .expired
            expired = true
            AppLogger.shared.warning(
                "Voice command '\(queue[i].commandId)' expired (queued \(Int(now.timeIntervalSince(queue[i].createdAt)))s ago)",
                category: "voice-queue"
            )
        }

        if expired {
            persistQueue()
            NotificationCenter.default.post(
                name: .voiceCommandExpired,
                object: nil
            )
        }
    }

    // MARK: - Queue Drain

    private func drainQueue() async {
        guard !isDraining else { return }

        // Expire stale commands first
        expireStaleCommands()

        let pendingCommands = queue.filter { $0.status == .pending }
        guard !pendingCommands.isEmpty else { return }

        isDraining = true

        AppLogger.shared.info(
            "Draining voice command queue (\(pendingCommands.count) pending)",
            category: "voice-queue"
        )

        var results: [(commandId: String, success: Bool)] = []

        for i in queue.indices {
            guard queue[i].status == .pending else { continue }

            // Check expiration
            guard Date() < queue[i].expiresAt else {
                queue[i].status = .expired
                AppLogger.shared.warning(
                    "Voice command '\(queue[i].commandId)' expired during drain",
                    category: "voice-queue"
                )
                continue
            }

            // Check retry count
            guard queue[i].retryCount < Self.maxRetries else {
                queue[i].status = .failed
                AppLogger.shared.warning(
                    "Discarding voice command '\(queue[i].commandId)' after \(queue[i].retryCount) retries",
                    category: "voice-queue"
                )
                results.append((queue[i].commandId, false))
                continue
            }

            // Check backoff timing
            guard Date() >= queue[i].nextRetryAt else { continue }

            queue[i].status = .executing
            let success = await executeQueuedCommand(queue[i])

            if success {
                queue[i].status = .completed
                results.append((queue[i].commandId, true))
                AppLogger.shared.info(
                    "Queued voice command '\(queue[i].commandId)' executed successfully",
                    category: "voice-queue"
                )
            } else {
                queue[i].retryCount += 1
                let backoff = min(
                    pow(2.0, Double(queue[i].retryCount)),
                    Self.maxBackoffSeconds
                )
                queue[i].nextRetryAt = Date().addingTimeInterval(backoff)

                if queue[i].retryCount < Self.maxRetries {
                    queue[i].status = .pending
                    AppLogger.shared.warning(
                        "Retry \(queue[i].retryCount)/\(Self.maxRetries) for voice command '\(queue[i].commandId)', next in \(Int(backoff))s",
                        category: "voice-queue"
                    )
                } else {
                    queue[i].status = .failed
                    results.append((queue[i].commandId, false))
                    AppLogger.shared.warning(
                        "Discarding voice command '\(queue[i].commandId)' after max retries",
                        category: "voice-queue"
                    )
                }
            }
        }

        persistQueue()
        isDraining = false

        // Post drain results notification
        if !results.isEmpty {
            let successCount = results.filter(\.success).count
            let failCount = results.count - successCount
            NotificationCenter.default.post(
                name: .voiceCommandQueueDrained,
                object: nil,
                userInfo: [
                    "successCount": successCount,
                    "failCount": failCount,
                    "results": results.map { ["commandId": $0.commandId, "success": $0.success] }
                ]
            )
        }
    }

    private func executeQueuedCommand(_ command: QueuedVoiceCommand) async -> Bool {
        // Look up the command definition from the catalog
        guard let voiceCommand = VoiceCommandCatalog.command(withId: command.commandId) else {
            AppLogger.shared.error(
                "Voice command '\(command.commandId)' not found in catalog",
                category: "voice-queue"
            )
            return false
        }

        // For offline-capable commands (navigation), dispatch via MainActor
        switch voiceCommand.action {
        case .navigate(let screen):
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ILSNavigateToScreen"),
                    object: screen
                )
            }
            return true

        case .newSession:
            await MainActor.run {
                NotificationCenter.default.post(name: .ilsCreateNewSession, object: nil)
            }
            return true

        case .triggerWorkflow:
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ILSTriggerWorkflow"),
                    object: command.parameters["workflowName"]
                )
            }
            return true

        default:
            // Non-offline-capable commands should not reach here due to enqueue guard
            AppLogger.shared.warning(
                "Cannot execute non-offline command '\(command.commandId)' from queue",
                category: "voice-queue"
            )
            return false
        }
    }

    // MARK: - Persistence (file-backed in Application Support)

    /// File URL for persisting the voice command queue.
    private static var queueFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ILS", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("voice_command_queue.json")
    }

    /// Debounced persist: coalesces rapid queue mutations into a single
    /// file write after a quiet period (500ms normal, 2s in Low Power Mode).
    private func persistQueue() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            let isLPM = await LowPowerModeMonitor.shared.isLowPowerModeEnabled
            let debounceNanos: UInt64 = isLPM ? 2_000_000_000 : 500_000_000
            try? await Task.sleep(nanoseconds: debounceNanos)
            guard !Task.isCancelled, let self else { return }
            await self.flushQueueToDisk()
        }
    }

    private func flushQueueToDisk() {
        let url = Self.queueFileURL

        // Don't write empty queue — delete the file instead
        if queue.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }

        do {
            let data = try encoder.encode(queue)
            let writeOptions: Data.WritingOptions = data.count > 1024 ? [.atomic] : []
            try data.write(to: url, options: writeOptions)

            // Exclude from iCloud backup
            var mutableURL = url
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try mutableURL.setResourceValues(resourceValues)
        } catch {
            AppLogger.shared.error(
                "Failed to persist voice command queue: \(error.localizedDescription)",
                category: "voice-queue"
            )
        }
    }

    private static func loadQueue() -> [QueuedVoiceCommand] {
        let url = queueFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([QueuedVoiceCommand].self, from: data)
        } catch {
            AppLogger.shared.error(
                "Failed to load voice command queue: \(error.localizedDescription)",
                category: "voice-queue"
            )
            return []
        }
    }
}

// MARK: - VoiceCommandQueueObserver

/// MainActor-bound observable wrapper around the `VoiceCommandQueue` actor
/// for SwiftUI data binding. Polls the actor state on demand.
@MainActor
@Observable
final class VoiceCommandQueueObserver {

    /// Number of pending commands in the queue.
    private(set) var pendingCount: Int = 0

    /// Results from the last drain operation.
    private(set) var lastDrainSuccessCount: Int = 0
    private(set) var lastDrainFailCount: Int = 0

    /// Whether results are available for display.
    private(set) var hasDrainResults: Bool = false

    /// Notification observers for queue events.
    nonisolated(unsafe) private var drainObserver: NSObjectProtocol?
    nonisolated(unsafe) private var expireObserver: NSObjectProtocol?

    init() {
        drainObserver = NotificationCenter.default.addObserver(
            forName: .voiceCommandQueueDrained,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let successCount = notification.userInfo?["successCount"] as? Int ?? 0
            let failCount = notification.userInfo?["failCount"] as? Int ?? 0
            self.lastDrainSuccessCount = successCount
            self.lastDrainFailCount = failCount
            self.hasDrainResults = true
            Task {
                await self.refresh()
            }
        }

        expireObserver = NotificationCenter.default.addObserver(
            forName: .voiceCommandExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.refresh()
            }
        }

        Task {
            await refresh()
        }
    }

    deinit {
        let drain = drainObserver
        let expire = expireObserver
        if let drain { NotificationCenter.default.removeObserver(drain) }
        if let expire { NotificationCenter.default.removeObserver(expire) }
    }

    /// Refresh state from the actor.
    func refresh() async {
        pendingCount = await VoiceCommandQueue.shared.pendingCount
    }

    /// Clear drain results after the UI has consumed them.
    func clearDrainResults() {
        hasDrainResults = false
        lastDrainSuccessCount = 0
        lastDrainFailCount = 0
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the voice command queue has been drained.
    /// `userInfo` contains "successCount" (Int), "failCount" (Int), and "results" array.
    static let voiceCommandQueueDrained = Notification.Name("voiceCommandQueueDrained")
    /// Posted when queued voice commands expire before execution.
    static let voiceCommandExpired = Notification.Name("voiceCommandExpired")
}
#endif
