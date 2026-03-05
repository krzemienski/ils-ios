import Foundation

/// Status of a workflow execution.
enum WorkflowExecutionStatus: String, Codable {
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
}

/// Represents a workflow execution instance with real-time progress tracking.
struct WorkflowExecution: Codable, Identifiable {
    let id: UUID
    /// Associated workflow ID.
    let workflowId: UUID
    /// Current execution status.
    var status: WorkflowExecutionStatus
    /// Currently executing node ID.
    var currentNodeId: UUID?
    /// Completed node IDs.
    var completedNodeIds: [UUID]
    /// Error message if execution failed.
    var error: String?
    /// Execution start time.
    var startedAt: Date?
    /// Execution end time.
    var completedAt: Date?
    /// Execution progress (0.0 to 1.0).
    var progress: Double?

    init(
        id: UUID = UUID(),
        workflowId: UUID,
        status: WorkflowExecutionStatus = .pending,
        currentNodeId: UUID? = nil,
        completedNodeIds: [UUID] = [],
        error: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        progress: Double? = nil
    ) {
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

    /// Duration of the execution in seconds.
    var duration: TimeInterval? {
        guard let startedAt = startedAt else { return nil }
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }

    /// Whether the execution is in a terminal state.
    var isFinished: Bool {
        status == .completed || status == .failed || status == .cancelled
    }

    /// Whether the execution is active.
    var isActive: Bool {
        status == .running || status == .pending
    }
}
