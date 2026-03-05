import Foundation

// MARK: - Request Types

/// Request to create a new workflow.
public struct CreateWorkflowRequest: Codable, Sendable {
    /// Workflow name.
    public let name: String
    /// Workflow description.
    public let description: String?
    /// Initial nodes.
    public let nodes: [WorkflowNode]?
    /// Initial connections.
    public let connections: [WorkflowConnection]?

    public init(
        name: String,
        description: String? = nil,
        nodes: [WorkflowNode]? = nil,
        connections: [WorkflowConnection]? = nil
    ) {
        self.name = name
        self.description = description
        self.nodes = nodes
        self.connections = connections
    }
}

/// Request to update an existing workflow.
public struct UpdateWorkflowRequest: Codable, Sendable {
    /// New name.
    public let name: String?
    /// New description.
    public let description: String?
    /// New status.
    public let status: WorkflowStatus?
    /// Updated nodes.
    public let nodes: [WorkflowNode]?
    /// Updated connections.
    public let connections: [WorkflowConnection]?

    public init(
        name: String? = nil,
        description: String? = nil,
        status: WorkflowStatus? = nil,
        nodes: [WorkflowNode]? = nil,
        connections: [WorkflowConnection]? = nil
    ) {
        self.name = name
        self.description = description
        self.status = status
        self.nodes = nodes
        self.connections = connections
    }
}

/// Request to execute a workflow.
public struct ExecuteWorkflowRequest: Codable, Sendable {
    /// Optional input parameters for the workflow execution.
    public let parameters: [String: String]?

    public init(parameters: [String: String]? = nil) {
        self.parameters = parameters
    }
}

// MARK: - Execution Models

/// Status of a workflow execution.
public enum WorkflowExecutionStatus: String, Codable, Sendable {
    /// Execution is pending start.
    case pending
    /// Execution is currently running.
    case running
    /// Execution is paused.
    case paused
    /// Execution completed successfully.
    case completed
    /// Execution failed.
    case failed
    /// Execution was cancelled.
    case cancelled

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized WorkflowExecutionStatus: '\(raw)'. Expected: pending, running, paused, completed, failed, cancelled"
                )
            )
        }
        self = value
    }
}

/// Represents a workflow execution instance.
public struct WorkflowExecution: Codable, Identifiable, Hashable, Sendable {
    /// Unique execution identifier.
    public let id: String
    /// Associated workflow ID.
    public let workflowId: String
    /// Current execution status.
    public var status: WorkflowExecutionStatus
    /// Currently executing node ID.
    public var currentNodeId: String?
    /// Completed node IDs.
    public var completedNodeIds: [String]
    /// Error message if execution failed.
    public var error: String?
    /// Execution start time.
    public var startedAt: Date?
    /// Execution end time.
    public var completedAt: Date?
    /// Execution progress (0.0 to 1.0).
    public var progress: Double?

    public init(
        id: String = UUID().uuidString,
        workflowId: String,
        status: WorkflowExecutionStatus = .pending,
        currentNodeId: String? = nil,
        completedNodeIds: [String] = [],
        error: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        progress: Double? = nil
    ) {
        precondition(!id.isEmpty, "WorkflowExecution id must not be empty")
        precondition(!workflowId.isEmpty, "workflowId must not be empty")
        self.id = id
        self.workflowId = workflowId
        self.status = status
        self.currentNodeId = currentNodeId
        self.completedNodeIds = completedNodeIds
        self.error = error
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.progress = progress
    }

    public static func == (lhs: WorkflowExecution, rhs: WorkflowExecution) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Schedule Models

/// A schedule for automated workflow execution.
public struct WorkflowSchedule: Codable, Identifiable, Hashable, Sendable {
    /// Unique schedule identifier.
    public let id: String
    /// Associated workflow ID.
    public let workflowId: String
    /// Cron expression for schedule (e.g., "0 0 * * *" for daily at midnight).
    public var cron: String
    /// Whether the schedule is enabled.
    public var enabled: Bool
    /// Optional timezone for schedule (defaults to UTC).
    public var timezone: String?
    /// When the schedule was created.
    public var createdAt: Date?
    /// When the schedule was last triggered.
    public var lastTriggeredAt: Date?
    /// When the schedule will next trigger.
    public var nextTriggerAt: Date?

    public init(
        id: String = UUID().uuidString,
        workflowId: String,
        cron: String,
        enabled: Bool = true,
        timezone: String? = nil,
        createdAt: Date? = nil,
        lastTriggeredAt: Date? = nil,
        nextTriggerAt: Date? = nil
    ) {
        precondition(!id.isEmpty, "WorkflowSchedule id must not be empty")
        precondition(!workflowId.isEmpty, "workflowId must not be empty")
        precondition(!cron.isEmpty, "cron expression must not be empty")
        self.id = id
        self.workflowId = workflowId
        self.cron = cron
        self.enabled = enabled
        self.timezone = timezone
        self.createdAt = createdAt
        self.lastTriggeredAt = lastTriggeredAt
        self.nextTriggerAt = nextTriggerAt
    }

    public static func == (lhs: WorkflowSchedule, rhs: WorkflowSchedule) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Request to create a workflow schedule.
public struct CreateScheduleRequest: Codable, Sendable {
    /// Cron expression.
    public let cron: String
    /// Whether the schedule should be enabled immediately.
    public let enabled: Bool
    /// Optional timezone.
    public let timezone: String?

    public init(
        cron: String,
        enabled: Bool = true,
        timezone: String? = nil
    ) {
        self.cron = cron
        self.enabled = enabled
        self.timezone = timezone
    }
}

/// Request to update a workflow schedule.
public struct UpdateScheduleRequest: Codable, Sendable {
    /// New cron expression.
    public let cron: String?
    /// New enabled state.
    public let enabled: Bool?
    /// New timezone.
    public let timezone: String?

    public init(
        cron: String? = nil,
        enabled: Bool? = nil,
        timezone: String? = nil
    ) {
        self.cron = cron
        self.enabled = enabled
        self.timezone = timezone
    }
}
