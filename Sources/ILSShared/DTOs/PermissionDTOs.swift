import Foundation

// MARK: - Auto-Approve Rule

/// A rule that automatically approves permission requests matching specific criteria.
///
/// Rules are evaluated in order of creation. The first matching rule wins.
/// A rule matches when the tool name satisfies ``toolPattern`` and the
/// request's risk level is at or below ``maxRiskLevel``.
public struct AutoApproveRule: Codable, Sendable, Identifiable {
    /// Unique rule identifier (UUID string).
    public let id: String
    /// Glob pattern or exact tool name to match (e.g., "Bash", "Read*").
    public let toolPattern: String
    /// Restrict rule to a specific project UUID, or nil for all projects.
    public let projectId: String?
    /// Maximum risk level this rule will auto-approve.
    public let maxRiskLevel: PermissionRiskLevel
    /// Whether this rule is currently active.
    public let isEnabled: Bool
    /// When the rule was created (UTC).
    public let createdAt: Date

    public init(
        id: String,
        toolPattern: String,
        projectId: String? = nil,
        maxRiskLevel: PermissionRiskLevel = .low,
        isEnabled: Bool = true,
        createdAt: Date
    ) {
        precondition(!id.isEmpty, "AutoApproveRule id must not be empty")
        precondition(!toolPattern.isEmpty, "AutoApproveRule toolPattern must not be empty")
        self.id = id
        self.toolPattern = toolPattern
        self.projectId = projectId
        self.maxRiskLevel = maxRiskLevel
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}

// MARK: - Permission List Response

/// Paginated list of permission records for the history/queue views.
public struct PermissionListResponse: Codable, Sendable {
    /// Ordered list of permission records (newest first).
    public let items: [PermissionRecord]
    /// Total number of matching records (before pagination).
    public let total: Int
    /// Number of records with ``PermissionStatus/pending`` status.
    public let pendingCount: Int
    /// Whether additional pages of results are available.
    public let hasMore: Bool

    public init(
        items: [PermissionRecord],
        total: Int,
        pendingCount: Int,
        hasMore: Bool = false
    ) {
        precondition(total >= 0, "PermissionListResponse total must be non-negative")
        precondition(pendingCount >= 0, "PermissionListResponse pendingCount must be non-negative")
        self.items = items
        self.total = total
        self.pendingCount = pendingCount
        self.hasMore = hasMore
    }
}

// MARK: - Permission Detail Response

/// Full detail for a single permission record, including matching auto-approve rules.
public struct PermissionDetailResponse: Codable, Sendable {
    /// The permission record.
    public let permission: PermissionRecord
    /// Auto-approve rules that would match this request (for UI context).
    public let matchingAutoApproveRules: [AutoApproveRule]

    public init(permission: PermissionRecord, matchingAutoApproveRules: [AutoApproveRule] = []) {
        self.permission = permission
        self.matchingAutoApproveRules = matchingAutoApproveRules
    }
}

// MARK: - Approve Permission Request

/// Request payload for approving a pending permission request.
public struct ApprovePermissionRequest: Codable, Sendable {
    /// Whether the approval should persist for the remainder of the session.
    public let forSession: Bool

    public init(forSession: Bool = false) {
        self.forSession = forSession
    }
}

// MARK: - Deny Permission Request

/// Request payload for denying a pending permission request.
public struct DenyPermissionRequest: Codable, Sendable {
    /// Optional reason for the denial, shown in the audit trail.
    public let reason: String?

    public init(reason: String? = nil) {
        self.reason = reason
    }
}

// MARK: - Batch Permission Action

/// Action to apply in a batch permission operation.
public enum PermissionBatchAction: String, Codable, Sendable {
    /// Approve all specified requests.
    case approve = "approve"
    /// Deny all specified requests.
    case deny = "deny"
}

/// Request payload for batch-approving or batch-denying multiple permission requests.
public struct BatchPermissionRequest: Codable, Sendable {
    /// Identifiers of the permission requests to act on.
    public let requestIds: [String]
    /// Action to apply to all specified requests.
    public let action: PermissionBatchAction
    /// Whether approvals should persist for the remainder of the session.
    public let forSession: Bool
    /// Reason for denial when ``action`` is ``PermissionBatchAction/deny``.
    public let denyReason: String?

    public init(
        requestIds: [String],
        action: PermissionBatchAction,
        forSession: Bool = false,
        denyReason: String? = nil
    ) {
        precondition(!requestIds.isEmpty, "BatchPermissionRequest requestIds must not be empty")
        self.requestIds = requestIds
        self.action = action
        self.forSession = forSession
        self.denyReason = denyReason
    }
}

// MARK: - Auto-Approve Rule Requests

/// Request payload for creating a new auto-approve rule.
public struct CreateAutoApproveRuleRequest: Codable, Sendable {
    /// Glob pattern or exact tool name to match.
    public let toolPattern: String
    /// Restrict rule to a specific project UUID, or nil for all projects.
    public let projectId: String?
    /// Maximum risk level this rule will auto-approve.
    public let maxRiskLevel: PermissionRiskLevel

    public init(
        toolPattern: String,
        projectId: String? = nil,
        maxRiskLevel: PermissionRiskLevel = .low
    ) {
        self.toolPattern = toolPattern
        self.projectId = projectId
        self.maxRiskLevel = maxRiskLevel
    }
}

/// Request payload for updating an existing auto-approve rule.
///
/// All fields are optional; only non-nil values are applied.
public struct UpdateAutoApproveRuleRequest: Codable, Sendable {
    /// New glob pattern or exact tool name, or nil to leave unchanged.
    public let toolPattern: String?
    /// New maximum risk level, or nil to leave unchanged.
    public let maxRiskLevel: PermissionRiskLevel?
    /// Enable or disable the rule, or nil to leave unchanged.
    public let isEnabled: Bool?

    public init(
        toolPattern: String? = nil,
        maxRiskLevel: PermissionRiskLevel? = nil,
        isEnabled: Bool? = nil
    ) {
        self.toolPattern = toolPattern
        self.maxRiskLevel = maxRiskLevel
        self.isEnabled = isEnabled
    }
}

// MARK: - Auto-Approve Rules List Response

/// List of auto-approve rules for the settings view.
public struct AutoApproveRulesResponse: Codable, Sendable {
    /// All configured auto-approve rules.
    public let rules: [AutoApproveRule]
    /// Total number of rules.
    public let total: Int

    public init(rules: [AutoApproveRule], total: Int? = nil) {
        self.rules = rules
        self.total = total ?? rules.count
    }
}
