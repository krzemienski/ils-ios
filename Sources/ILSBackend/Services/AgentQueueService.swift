import Foundation
import Fluent
import Vapor
import ILSShared
import Logging

/// Actor managing the agent task queue execution lifecycle.
///
/// ## Architecture
///
/// The service maintains a list of running Swift Tasks keyed by `AgentQueueItemModel` UUID.
/// When `startNextTask()` is called it queries the database for eligible queued items and
/// dispatches them via `ClaudeExecutorService`, respecting the current execution mode:
///
/// - **Sequential**: at most one task runs at a time (the highest-priority queued item).
/// - **Parallel**: up to `maxParallelTasks` items run concurrently.
///
/// ## Status Lifecycle
///
/// ```
/// queued → running → completed
///                 → failed
///                 → cancelled
///       → paused  → queued (on resume)
/// ```
///
/// ## Dependency Handling
///
/// Items with a non-empty `dependsOn` list are skipped until every listed item has
/// reached `.completed` status.
actor AgentQueueService {
    /// Structured logger for queue operations
    private static let logger = Logger(label: "ils.agent-queue")

    /// Database handle for reading and updating queue items
    private let db: Database

    /// Executor used to launch Claude subprocesses for each task
    private let executor: ClaudeExecutorService

    /// Running Swift Tasks keyed by queue item UUID
    private var runningTasks: [UUID: Task<Void, Never>] = [:]

    /// Whether the queue as a whole is paused (no new tasks will start)
    private var isPaused: Bool = false

    /// Maximum number of concurrent tasks in parallel mode
    private let maxParallelTasks: Int = 3

    // MARK: - Initializer

    init(db: Database, executor: ClaudeExecutorService) {
        self.db = db
        self.executor = executor
    }

    // MARK: - Queue-Level Control

    /// Pause the entire queue. Running tasks continue to completion but no new
    /// tasks are dispatched until `resumeQueue()` is called.
    func pauseQueue() {
        isPaused = true
    }

    /// Resume the queue and immediately attempt to dispatch the next task.
    func resumeQueue() async {
        isPaused = false
        await startNextTask()
    }

    // MARK: - Item-Level Control

    /// Cancel a specific queue item, stopping execution if it is currently running.
    ///
    /// - Parameter id: UUID of the `AgentQueueItemModel` to cancel
    /// - Throws: `Abort(.notFound)` if the item does not exist
    func cancelTask(id: UUID) async throws {
        // Stop the running Swift Task if one exists
        runningTasks[id]?.cancel()
        runningTasks.removeValue(forKey: id)

        guard let model = try await AgentQueueItemModel.find(id, on: db) else {
            throw Abort(.notFound, reason: "Queue item \(id) not found")
        }

        let currentStatus = AgentQueueStatus(rawValue: model.status) ?? .queued
        let terminalStatuses: [AgentQueueStatus] = [.completed, .failed, .cancelled]
        guard !terminalStatuses.contains(currentStatus) else {
            return // Already in a terminal state; nothing to do
        }

        model.status = AgentQueueStatus.cancelled.rawValue
        model.completedAt = Date()
        try await model.update(on: db)
    }

    /// Pause a specific running task. The task is cancelled in-process and its
    /// status transitions to `.paused` so it can be resumed later.
    ///
    /// - Parameter id: UUID of the `AgentQueueItemModel` to pause
    /// - Throws: `Abort(.notFound)` if the item does not exist
    func pauseTask(id: UUID) async throws {
        guard let model = try await AgentQueueItemModel.find(id, on: db) else {
            throw Abort(.notFound, reason: "Queue item \(id) not found")
        }

        guard model.status == AgentQueueStatus.running.rawValue else {
            return // Can only pause running tasks
        }

        // Cancel the underlying Swift Task
        runningTasks[id]?.cancel()
        runningTasks.removeValue(forKey: id)

        model.status = AgentQueueStatus.paused.rawValue
        try await model.update(on: db)
    }

    /// Resume a paused task by re-queuing it and triggering dispatch.
    ///
    /// - Parameter id: UUID of the `AgentQueueItemModel` to resume
    /// - Throws: `Abort(.notFound)` if the item does not exist
    func resumeTask(id: UUID) async throws {
        guard let model = try await AgentQueueItemModel.find(id, on: db) else {
            throw Abort(.notFound, reason: "Queue item \(id) not found")
        }

        guard model.status == AgentQueueStatus.paused.rawValue else {
            return // Only paused tasks can be resumed
        }

        model.status = AgentQueueStatus.queued.rawValue
        model.startedAt = nil
        try await model.update(on: db)

        await startNextTask()
    }

    // MARK: - Task Dispatch

    /// Pick the next eligible task(s) and launch them according to the execution mode.
    ///
    /// **Sequential mode** (per item): skips launch if any task is already running.
    /// **Parallel mode** (per item): launches up to `maxParallelTasks` concurrently.
    ///
    /// Items whose dependencies are not yet satisfied (all `dependsOn` IDs must have
    /// `.completed` status) are skipped in this pass.
    ///
    /// This method is idempotent and safe to call multiple times concurrently —
    /// actor isolation ensures only one dispatch loop runs at a time.
    func startNextTask() async {
        guard !isPaused else { return }

        do {
            // Load all currently-queued items ordered by priority then position
            let queuedItems = try await AgentQueueItemModel.query(on: db)
                .filter(\.$status == AgentQueueStatus.queued.rawValue)
                .sort(\.$priority, .ascending)
                .sort(\.$position, .ascending)
                .all()

            guard !queuedItems.isEmpty else { return }

            for item in queuedItems {
                guard let itemId = item.id else { continue }

                // Skip if task is already tracked as running locally
                if runningTasks[itemId] != nil { continue }

                let mode = QueueExecutionMode(rawValue: item.executionMode) ?? .sequential
                let currentRunningCount = runningTasks.count

                if mode == .sequential {
                    // Sequential: do not start if anything is already running
                    if currentRunningCount > 0 { break }
                } else {
                    // Parallel: respect the concurrency cap
                    if currentRunningCount >= maxParallelTasks { break }
                }

                // Check dependency satisfaction
                if !item.dependsOn.isNilOrEmpty {
                    let satisfied = try await areDependenciesSatisfied(for: item)
                    guard satisfied else { continue }
                }

                // Dispatch
                let task = Task<Void, Never> { [weak self] in
                    await self?.executeTask(itemId: itemId)
                }
                runningTasks[itemId] = task

                // For sequential items stop after scheduling one
                if mode == .sequential { break }
            }
        } catch {
            Self.logger.error("startNextTask failed: \(error)")
        }
    }

    // MARK: - Private Execution

    /// Execute a single queue item end-to-end via `ClaudeExecutorService`.
    ///
    /// Transitions the item through `running → completed / failed / cancelled`.
    /// Calls `startNextTask()` on completion so the queue progresses automatically.
    private func executeTask(itemId: UUID) async {
        // --- Mark as running ---
        do {
            guard let model = try await AgentQueueItemModel.find(itemId, on: db) else {
                Self.logger.warning("Queue item \(itemId) not found at execution start")
                runningTasks.removeValue(forKey: itemId)
                return
            }

            // Guard against races: only start if still queued
            guard model.status == AgentQueueStatus.queued.rawValue else {
                runningTasks.removeValue(forKey: itemId)
                return
            }

            model.status = AgentQueueStatus.running.rawValue
            model.startedAt = Date()
            try await model.update(on: db)
        } catch {
            Self.logger.error("Failed to mark item \(itemId) as running: \(error)")
            runningTasks.removeValue(forKey: itemId)
            return
        }

        // --- Resolve working directory ---
        var workingDirectory: String? = nil
        if let model = try? await AgentQueueItemModel.find(itemId, on: db),
           let projectId = model.projectId,
           let project = try? await ProjectModel.find(projectId, on: db) {
            workingDirectory = project.path
        }

        // --- Fetch prompt ---
        guard let model = try? await AgentQueueItemModel.find(itemId, on: db) else {
            runningTasks.removeValue(forKey: itemId)
            return
        }
        let prompt = model.prompt ?? model.title

        // --- Execute ---
        var didSucceed = true
        var errorMessage: String? = nil

        let options = ExecutionOptions()
        let stream = executor.execute(
            prompt: prompt,
            workingDirectory: workingDirectory,
            options: options
        )

        do {
            for try await message in stream {
                try Task.checkCancellation()

                if case .error(let err) = message {
                    didSucceed = false
                    errorMessage = err.message
                    break
                }
            }
        } catch is CancellationError {
            didSucceed = false
        } catch {
            didSucceed = false
            errorMessage = error.localizedDescription
        }

        // --- Update final status ---
        do {
            guard let finalModel = try await AgentQueueItemModel.find(itemId, on: db) else {
                runningTasks.removeValue(forKey: itemId)
                return
            }

            // Respect external status changes (e.g. cancelled via cancelTask)
            guard finalModel.status == AgentQueueStatus.running.rawValue else {
                runningTasks.removeValue(forKey: itemId)
                await startNextTask()
                return
            }

            if Task.isCancelled {
                finalModel.status = AgentQueueStatus.cancelled.rawValue
            } else if didSucceed {
                finalModel.status = AgentQueueStatus.completed.rawValue
            } else {
                finalModel.status = AgentQueueStatus.failed.rawValue
                finalModel.errorMessage = errorMessage
            }
            finalModel.completedAt = Date()
            try await finalModel.update(on: db)
        } catch {
            Self.logger.error("Failed to finalize item \(itemId): \(error)")

            // Best-effort mark as failed
            if let failedModel = try? await AgentQueueItemModel.find(itemId, on: db),
               failedModel.status == AgentQueueStatus.running.rawValue {
                failedModel.status = AgentQueueStatus.failed.rawValue
                failedModel.errorMessage = error.localizedDescription
                failedModel.completedAt = Date()
                try? await failedModel.update(on: db)
            }
        }

        // Clean up and trigger next task
        runningTasks.removeValue(forKey: itemId)
        await startNextTask()
    }

    // MARK: - Helpers

    /// Check whether all items listed in `model.dependsOn` have `.completed` status.
    private func areDependenciesSatisfied(for model: AgentQueueItemModel) async throws -> Bool {
        guard let raw = model.dependsOn,
              let data = raw.data(using: .utf8),
              let depIdStrings = try? JSONDecoder().decode([String].self, from: data),
              !depIdStrings.isEmpty else {
            return true
        }

        let depUUIDs = depIdStrings.compactMap { UUID(uuidString: $0) }
        guard !depUUIDs.isEmpty else { return true }

        let completedCount = try await AgentQueueItemModel.query(on: db)
            .filter(\.$id ~~ depUUIDs)
            .filter(\.$status == AgentQueueStatus.completed.rawValue)
            .count()

        return completedCount == depUUIDs.count
    }
}

// MARK: - Optional String Helper

private extension Optional where Wrapped == String {
    /// Returns `true` if the optional is `nil` or the string is empty.
    var isNilOrEmpty: Bool {
        switch self {
        case .none: return true
        case .some(let s): return s.isEmpty
        }
    }
}
