import Foundation

// MARK: - Agent Queue Status

/// Lifecycle status of an item in the agent task queue.
public enum AgentQueueStatus: String, Codable, Sendable, CaseIterable {
    /// Task is waiting to be executed.
    case queued
    /// Task is currently executing.
    case running
    /// Task execution has been suspended.
    case paused
    /// Task completed successfully.
    case completed
    /// Task terminated with an error.
    case failed
    /// Task was cancelled before completion.
    case cancelled

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized AgentQueueStatus: '\(raw)'. Expected: queued, running, paused, completed, failed, cancelled"
                )
            )
        }
        self = value
    }
}

// MARK: - Queue Execution Mode

/// Controls how items in the queue are dispatched.
public enum QueueExecutionMode: String, Codable, Sendable, CaseIterable {
    /// Items execute one at a time, in order.
    case sequential
    /// Eligible items execute concurrently.
    case parallel

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized QueueExecutionMode: '\(raw)'. Expected: sequential, parallel"
                )
            )
        }
        self = value
    }
}

// MARK: - Agent Queue Item

/// A task queued for execution by a Claude Code agent.
public struct AgentQueueItem: Codable, Sendable, Identifiable {
    /// Unique identifier (UUID string).
    public let id: String
    /// Short human-readable title.
    public let title: String
    /// Detailed task description or prompt.
    public let description: String?
    /// ID of the project this task belongs to.
    public let projectId: String?
    /// Session ID if this item is associated with an existing session.
    public let sessionId: String?
    /// Current lifecycle status.
    public var status: AgentQueueStatus
    /// Relative execution priority (lower value = higher priority).
    public var priority: Int
    /// Position in the ordered queue (0-based).
    public var position: Int
    /// IDs of items that must complete before this one can run.
    public var dependsOn: [String]?
    /// When the item was added to the queue.
    public let createdAt: Date?
    /// When execution started, if applicable.
    public var startedAt: Date?
    /// When execution finished (success, failure, or cancellation).
    public var completedAt: Date?
    /// Human-readable error message if status is `.failed`.
    public var errorMessage: String?

    public init(
        id: String,
        title: String,
        description: String? = nil,
        projectId: String? = nil,
        sessionId: String? = nil,
        status: AgentQueueStatus = .queued,
        priority: Int = 0,
        position: Int = 0,
        dependsOn: [String]? = nil,
        createdAt: Date? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        precondition(!id.isEmpty, "AgentQueueItem id must not be empty")
        precondition(!title.isEmpty, "AgentQueueItem title must not be empty")
        precondition(priority >= 0, "AgentQueueItem priority must be non-negative")
        precondition(position >= 0, "AgentQueueItem position must be non-negative")
        self.id = id
        self.title = title
        self.description = description
        self.projectId = projectId
        self.sessionId = sessionId
        self.status = status
        self.priority = priority
        self.position = position
        self.dependsOn = dependsOn
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.errorMessage = errorMessage
    }
}

// MARK: - Queue State

/// Snapshot of the entire agent task queue.
public struct AgentQueue: Codable, Sendable {
    /// Ordered list of items (by position).
    public let items: [AgentQueueItem]
    /// Current dispatch strategy.
    public let executionMode: QueueExecutionMode
    /// Whether the queue is accepting and dispatching new work.
    public let isPaused: Bool
    /// Total number of items across all statuses.
    public let totalCount: Int
    /// Number of items currently executing.
    public let runningCount: Int
    /// Number of items waiting to execute.
    public let pendingCount: Int

    public init(
        items: [AgentQueueItem],
        executionMode: QueueExecutionMode = .sequential,
        isPaused: Bool = false,
        totalCount: Int,
        runningCount: Int,
        pendingCount: Int
    ) {
        precondition(totalCount >= 0, "AgentQueue totalCount must be non-negative")
        precondition(runningCount >= 0, "AgentQueue runningCount must be non-negative")
        precondition(pendingCount >= 0, "AgentQueue pendingCount must be non-negative")
        self.items = items
        self.executionMode = executionMode
        self.isPaused = isPaused
        self.totalCount = totalCount
        self.runningCount = runningCount
        self.pendingCount = pendingCount
    }
}

// MARK: - Request Types

/// Request to add a new item to the agent task queue.
public struct CreateQueueItemRequest: Codable, Sendable {
    /// Short human-readable title.
    public let title: String
    /// Detailed task description or prompt sent to the agent.
    public let description: String?
    /// Project to associate the task with.
    public let projectId: String?
    /// Relative execution priority (lower value = higher priority).
    public let priority: Int?
    /// IDs of queue items that must complete before this one starts.
    public let dependsOn: [String]?
    /// Execution mode for this item (nil defaults to .sequential on the backend).
    public let executionMode: QueueExecutionMode?

    public init(
        title: String,
        description: String? = nil,
        projectId: String? = nil,
        priority: Int? = nil,
        dependsOn: [String]? = nil,
        executionMode: QueueExecutionMode? = nil
    ) {
        self.title = title
        self.description = description
        self.projectId = projectId
        self.priority = priority
        self.dependsOn = dependsOn
        self.executionMode = executionMode
    }
}

/// Request to update mutable fields of an existing queue item.
public struct UpdateQueueItemRequest: Codable, Sendable {
    /// Updated title (nil = no change).
    public let title: String?
    /// Updated description (nil = no change).
    public let description: String?
    /// Updated priority (nil = no change).
    public let priority: Int?
    /// Updated dependency list (nil = no change).
    public let dependsOn: [String]?

    public init(
        title: String? = nil,
        description: String? = nil,
        priority: Int? = nil,
        dependsOn: [String]? = nil
    ) {
        self.title = title
        self.description = description
        self.priority = priority
        self.dependsOn = dependsOn
    }
}

/// Request to reorder items in the queue by supplying the desired ID sequence.
public struct ReorderQueueRequest: Codable, Sendable {
    /// Item IDs in the desired execution order (all queued item IDs must be present).
    public let orderedIds: [String]

    public init(orderedIds: [String]) {
        precondition(!orderedIds.isEmpty, "ReorderQueueRequest orderedIds must not be empty")
        self.orderedIds = orderedIds
    }
}

/// A control action applied to the queue or a specific item.
public struct QueueControlAction: Codable, Sendable {
    /// The operation to perform.
    public let action: Action
    /// Target item ID; nil applies the action to the entire queue.
    public let itemId: String?

    /// Supported queue control operations.
    public enum Action: String, Codable, Sendable {
        /// Begin or resume execution.
        case start
        /// Suspend execution without discarding state.
        case pause
        /// Resume a paused item or queue.
        case resume
        /// Terminate and discard.
        case cancel
        /// Remove all completed and failed items.
        case clearFinished

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let value = Self(rawValue: raw) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unrecognized QueueControlAction.Action: '\(raw)'. Expected: start, pause, resume, cancel, clearFinished"
                    )
                )
            }
            self = value
        }
    }

    public init(action: Action, itemId: String? = nil) {
        self.action = action
        self.itemId = itemId
    }
}
