import Fluent
import Vapor
import ILSShared

/// Fluent model for persisting Claude Code tool-use permission request history.
final class PermissionModel: Model, Content, @unchecked Sendable {
    static let schema = "permissions"

    @ID(key: .id)
    var id: UUID?

    /// Original request identifier from the Claude Code stream.
    @Field(key: "request_id")
    var requestId: String

    /// Session UUID that generated this permission request.
    @Field(key: "session_id")
    var sessionId: String

    /// Human-readable session name at the time of the request.
    @OptionalField(key: "session_name")
    var sessionName: String?

    /// Project name at the time of the request, if session belongs to a project.
    @OptionalField(key: "project_name")
    var projectName: String?

    /// Name of the tool requesting authorization (e.g., "Bash", "Write").
    @Field(key: "tool_name")
    var toolName: String

    /// Tool input parameters encoded as a JSON string.
    @Field(key: "tool_input")
    var toolInput: String

    /// Resolution status of the request (pending, approved, denied, expired, auto_approved).
    @Field(key: "status")
    var status: String

    /// Assessed risk level (low, medium, high, critical).
    @Field(key: "risk_level")
    var riskLevel: String

    /// When the permission request was received.
    @Field(key: "requested_at")
    var requestedAt: Date

    /// When the request was resolved, or nil if still pending.
    @OptionalField(key: "resolved_at")
    var resolvedAt: Date?

    /// Who resolved the request: "user", "auto", or "timeout".
    @OptionalField(key: "resolved_by")
    var resolvedBy: String?

    /// Reason provided when denying the request, if any.
    @OptionalField(key: "deny_reason")
    var denyReason: String?

    /// Whether approval applies for the entire session, not just the single request.
    @Field(key: "is_session_approval")
    var isSessionApproval: Bool

    /// ID of the permission policy that automatically resolved this request, if any.
    @OptionalField(key: "matched_policy_id")
    var matchedPolicyId: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        requestId: String,
        sessionId: String,
        sessionName: String? = nil,
        projectName: String? = nil,
        toolName: String,
        toolInput: String,
        status: PermissionStatus = .pending,
        riskLevel: PermissionRiskLevel = .medium,
        requestedAt: Date = Date(),
        resolvedAt: Date? = nil,
        resolvedBy: String? = nil,
        denyReason: String? = nil,
        isSessionApproval: Bool = false,
        matchedPolicyId: String? = nil
    ) {
        self.id = id
        self.requestId = requestId
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.projectName = projectName
        self.toolName = toolName
        self.toolInput = toolInput
        self.status = status.rawValue
        self.riskLevel = riskLevel.rawValue
        self.requestedAt = requestedAt
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
        self.denyReason = denyReason
        self.isSessionApproval = isSessionApproval
        self.matchedPolicyId = matchedPolicyId
    }

    /// Convert to shared PermissionRecord type.
    func toShared() -> PermissionRecord {
        let inputData = toolInput.data(using: .utf8) ?? Data()
        let decoded = (try? JSONDecoder().decode(AnyCodable.self, from: inputData)) ?? AnyCodable([:] as [String: String])

        return PermissionRecord(
            id: (id ?? UUID()).uuidString,
            requestId: requestId,
            sessionId: sessionId,
            sessionName: sessionName,
            projectName: projectName,
            toolName: toolName,
            toolInput: decoded,
            status: PermissionStatus(rawValue: status) ?? .pending,
            riskLevel: PermissionRiskLevel(rawValue: riskLevel) ?? .medium,
            requestedAt: requestedAt,
            resolvedAt: resolvedAt,
            resolvedBy: resolvedBy,
            denyReason: denyReason,
            isSessionApproval: isSessionApproval,
            matchedPolicyId: matchedPolicyId.flatMap { UUID(uuidString: $0) }
        )
    }

    /// Create from shared PermissionRecord type.
    static func from(_ record: PermissionRecord) -> PermissionModel {
        let inputData = (try? JSONEncoder().encode(record.toolInput)) ?? Data()
        let inputString = String(data: inputData, encoding: .utf8) ?? "{}"

        return PermissionModel(
            id: UUID(uuidString: record.id),
            requestId: record.requestId,
            sessionId: record.sessionId,
            sessionName: record.sessionName,
            projectName: record.projectName,
            toolName: record.toolName,
            toolInput: inputString,
            status: record.status,
            riskLevel: record.riskLevel,
            requestedAt: record.requestedAt,
            resolvedAt: record.resolvedAt,
            resolvedBy: record.resolvedBy,
            denyReason: record.denyReason,
            isSessionApproval: record.isSessionApproval,
            matchedPolicyId: record.matchedPolicyId?.uuidString
        )
    }
}
