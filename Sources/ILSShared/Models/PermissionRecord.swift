import Foundation

// MARK: - Permission Status

/// Current resolution state of a permission request.
public enum PermissionStatus: String, Codable, Sendable, CaseIterable {
    /// Awaiting user or auto-approval decision.
    case pending = "pending"
    /// Manually approved by the user.
    case approved = "approved"
    /// Manually denied by the user.
    case denied = "denied"
    /// Request timed out before a decision was made.
    case expired = "expired"
    /// Automatically approved by a matching auto-approve rule.
    case autoApproved = "auto_approved"
}

// MARK: - Permission Risk Level

/// Assessed risk level of a tool-use permission request.
public enum PermissionRiskLevel: String, Codable, Sendable, CaseIterable {
    /// Low-risk read-only operation (e.g., reading a file).
    case low = "low"
    /// Moderate-risk operation (e.g., writing a file).
    case medium = "medium"
    /// High-risk operation (e.g., running a shell command).
    case high = "high"
    /// Critical operation with potential for irreversible effects.
    case critical = "critical"
}

// MARK: - Permission Record

/// A persisted record of a Claude Code tool-use permission request.
///
/// Captures the full lifecycle of a permission request — from initial creation
/// when Claude asks for authorization, through resolution by the user or an
/// auto-approve rule, providing a complete audit trail.
public struct PermissionRecord: Codable, Sendable, Identifiable {
    /// Unique record identifier (UUID string).
    public let id: String
    /// Identifier of the original permission request from the stream.
    public let requestId: String
    /// Session that generated this permission request.
    public let sessionId: String
    /// Human-readable session name, if available.
    public let sessionName: String?
    /// Project the session belongs to, if assigned.
    public let projectName: String?
    /// Name of the tool requesting authorization.
    public let toolName: String
    /// Input parameters supplied to the tool.
    public let toolInput: AnyCodable
    /// Current resolution status of the request.
    public let status: PermissionStatus
    /// Assessed risk level of this operation.
    public let riskLevel: PermissionRiskLevel
    /// When the permission request was received (UTC).
    public let requestedAt: Date
    /// When the request was resolved, or nil if still pending.
    public let resolvedAt: Date?
    /// Who resolved the request: "user", "auto", or "timeout".
    public let resolvedBy: String?
    /// Reason provided when denying the request, if any.
    public let denyReason: String?
    /// Whether approval applies for the entire session (not just once).
    public let isSessionApproval: Bool

    public init(
        id: String,
        requestId: String,
        sessionId: String,
        sessionName: String? = nil,
        projectName: String? = nil,
        toolName: String,
        toolInput: AnyCodable,
        status: PermissionStatus,
        riskLevel: PermissionRiskLevel = .medium,
        requestedAt: Date,
        resolvedAt: Date? = nil,
        resolvedBy: String? = nil,
        denyReason: String? = nil,
        isSessionApproval: Bool = false
    ) {
        precondition(!id.isEmpty, "PermissionRecord id must not be empty")
        precondition(!requestId.isEmpty, "PermissionRecord requestId must not be empty")
        precondition(!sessionId.isEmpty, "PermissionRecord sessionId must not be empty")
        precondition(!toolName.isEmpty, "PermissionRecord toolName must not be empty")
        self.id = id
        self.requestId = requestId
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.projectName = projectName
        self.toolName = toolName
        self.toolInput = toolInput
        self.status = status
        self.riskLevel = riskLevel
        self.requestedAt = requestedAt
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
        self.denyReason = denyReason
        self.isSessionApproval = isSessionApproval
    }
}
