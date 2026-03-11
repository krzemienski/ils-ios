import Foundation

// MARK: - Audit Action Filter

/// Query parameters for fetching a filtered audit trail.
///
/// All fields are optional — omitting a field applies no constraint for that dimension.
public struct AuditActionFilter: Codable, Sendable {
    /// Restrict to actions of these types.
    public let actionTypes: [AuditActionType]?
    /// Restrict to a single session.
    public let sessionId: String?
    /// Restrict to sessions belonging to this project.
    public let projectName: String?
    /// Restrict to actions affecting this file path (prefix match).
    public let filePath: String?
    /// Return only actions that occurred at or after this date.
    public let since: Date?
    /// Return only actions that occurred at or before this date.
    public let until: Date?
    /// When `true`, exclude actions that have already been rolled back.
    public let excludeRolledBack: Bool?
    /// Full-text search query matched against description, file path, and command.
    public let searchQuery: String?
    /// Maximum number of actions to return.
    public let limit: Int?
    /// Offset for pagination.
    public let offset: Int?

    public init(
        actionTypes: [AuditActionType]? = nil,
        sessionId: String? = nil,
        projectName: String? = nil,
        filePath: String? = nil,
        since: Date? = nil,
        until: Date? = nil,
        excludeRolledBack: Bool? = nil,
        searchQuery: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        if let limit { precondition(limit > 0, "AuditActionFilter limit must be positive") }
        if let offset { precondition(offset >= 0, "AuditActionFilter offset must be non-negative") }
        self.actionTypes = actionTypes
        self.sessionId = sessionId
        self.projectName = projectName
        self.filePath = filePath
        self.since = since
        self.until = until
        self.excludeRolledBack = excludeRolledBack
        self.searchQuery = searchQuery
        self.limit = limit
        self.offset = offset
    }
}

// MARK: - Audit Action List Response

/// Paginated response from the audit trail list endpoint.
public struct AuditActionListResponse: Codable, Sendable {
    /// Ordered list of actions (newest first).
    public let actions: [AuditAction]
    /// Total number of matching actions (before pagination).
    public let totalCount: Int
    /// Whether additional pages of results are available.
    public let hasMore: Bool

    public init(
        actions: [AuditAction],
        totalCount: Int,
        hasMore: Bool = false
    ) {
        precondition(totalCount >= 0, "AuditActionListResponse totalCount must be non-negative")
        self.actions = actions
        self.totalCount = totalCount
        self.hasMore = hasMore
    }
}

// MARK: - Log Audit Action Request

/// Request body for creating a new audit action entry.
public struct LogAuditActionRequest: Codable, Sendable {
    /// Identifier of the session that generated this action.
    public let sessionId: String
    /// Human-readable session name, if available.
    public let sessionName: String?
    /// Category of action performed.
    public let actionType: AuditActionType
    /// Human-readable description of the action.
    public let description: String
    /// File path affected by this action, if applicable.
    public let filePath: String?
    /// Command executed, if applicable.
    public let command: String?
    /// Name of the tool invoked, if applicable.
    public let toolName: String?
    /// File content before the action (for file operations).
    public let beforeContent: String?
    /// File content after the action (for file operations).
    public let afterContent: String?
    /// Additional structured metadata as a JSON string.
    public let metadata: String?
    /// Whether this action can be individually rolled back.
    public let isRollbackable: Bool

    public init(
        sessionId: String,
        sessionName: String? = nil,
        actionType: AuditActionType,
        description: String,
        filePath: String? = nil,
        command: String? = nil,
        toolName: String? = nil,
        beforeContent: String? = nil,
        afterContent: String? = nil,
        metadata: String? = nil,
        isRollbackable: Bool
    ) {
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.actionType = actionType
        self.description = description
        self.filePath = filePath
        self.command = command
        self.toolName = toolName
        self.beforeContent = beforeContent
        self.afterContent = afterContent
        self.metadata = metadata
        self.isRollbackable = isRollbackable
    }
}

// MARK: - Rollback Request

/// Request body for rolling back one or more audit actions.
///
/// Actions are rolled back in reverse chronological order to ensure
/// consistent file state is restored. The rollback itself is audited.
public struct RollbackRequest: Codable, Sendable {
    /// IDs of the actions to roll back.
    public let actionIds: [UUID]
    /// Optional human-readable reason for the rollback, stored in the audit entry.
    public let reason: String?

    public init(actionIds: [UUID], reason: String? = nil) {
        precondition(!actionIds.isEmpty, "RollbackRequest actionIds must not be empty")
        self.actionIds = actionIds
        self.reason = reason
    }
}

// MARK: - Rollback Result Item

/// Result for a single action rollback attempt.
public struct RollbackResultItem: Codable, Sendable {
    /// ID of the action that was attempted.
    public let actionId: UUID
    /// Whether the rollback succeeded.
    public let succeeded: Bool
    /// Error description if rollback failed.
    public let errorMessage: String?
    /// The new audit entry created to record this rollback, if successful.
    public let rollbackAuditAction: AuditAction?

    public init(
        actionId: UUID,
        succeeded: Bool,
        errorMessage: String? = nil,
        rollbackAuditAction: AuditAction? = nil
    ) {
        self.actionId = actionId
        self.succeeded = succeeded
        self.errorMessage = errorMessage
        self.rollbackAuditAction = rollbackAuditAction
    }
}

// MARK: - Rollback Response

/// Result of a bulk rollback operation.
public struct RollbackResponse: Codable, Sendable {
    /// Per-action results for the rollback request.
    public let results: [RollbackResultItem]
    /// Number of actions that were successfully rolled back.
    public let succeededCount: Int
    /// Number of actions that could not be rolled back.
    public let failedCount: Int

    public init(results: [RollbackResultItem]) {
        self.results = results
        self.succeededCount = results.filter(\.succeeded).count
        self.failedCount = results.filter { !$0.succeeded }.count
    }
}
