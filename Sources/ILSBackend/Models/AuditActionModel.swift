import Fluent
import Vapor
import ILSShared

/// Fluent model for AuditAction persistence.
///
/// Every file modification, command execution, tool use, and permission decision
/// made by Claude is stored as an immutable ``AuditActionModel``. Before/after
/// content is retained for file operations to support one-tap rollback.
final class AuditActionModel: Model, Content, @unchecked Sendable {
    static let schema = "audit_actions"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "session_id")
    var sessionId: String

    @OptionalField(key: "session_name")
    var sessionName: String?

    @Field(key: "action_type")
    var actionType: String

    @Field(key: "description")
    var description: String

    @OptionalField(key: "file_path")
    var filePath: String?

    @OptionalField(key: "command")
    var command: String?

    @OptionalField(key: "tool_name")
    var toolName: String?

    @OptionalField(key: "before_content")
    var beforeContent: String?

    @OptionalField(key: "after_content")
    var afterContent: String?

    @OptionalField(key: "metadata")
    var metadata: String?

    @Field(key: "is_rollbackable")
    var isRollbackable: Bool

    @Field(key: "rollback_status")
    var rollbackStatus: String

    @OptionalField(key: "rolled_back_at")
    var rolledBackAt: Date?

    @OptionalField(key: "rollback_audit_id")
    var rollbackAuditId: UUID?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
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
        isRollbackable: Bool,
        rollbackStatus: RollbackStatus = .notRolledBack,
        rolledBackAt: Date? = nil,
        rollbackAuditId: UUID? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.actionType = actionType.rawValue
        self.description = description
        self.filePath = filePath
        self.command = command
        self.toolName = toolName
        self.beforeContent = beforeContent
        self.afterContent = afterContent
        self.metadata = metadata
        self.isRollbackable = isRollbackable
        self.rollbackStatus = rollbackStatus.rawValue
        self.rolledBackAt = rolledBackAt
        self.rollbackAuditId = rollbackAuditId
    }

    // MARK: - Conversions

    /// Converts this model to the shared ``AuditAction`` type.
    func toShared() throws -> AuditAction {
        guard let id = id else {
            throw Abort(.internalServerError, reason: "AuditAction missing ID")
        }

        let actionTypeEnum = AuditActionType(rawValue: actionType) ?? .toolUse
        let rollbackStatusEnum = RollbackStatus(rawValue: rollbackStatus) ?? .notRolledBack

        return AuditAction(
            id: id,
            sessionId: sessionId,
            sessionName: sessionName,
            actionType: actionTypeEnum,
            description: description,
            filePath: filePath,
            command: command,
            toolName: toolName,
            beforeContent: beforeContent,
            afterContent: afterContent,
            metadata: metadata,
            isRollbackable: isRollbackable,
            rollbackStatus: rollbackStatusEnum,
            rolledBackAt: rolledBackAt,
            rollbackAuditId: rollbackAuditId,
            createdAt: createdAt ?? Date()
        )
    }

    /// Creates a model from the shared ``AuditAction`` type.
    static func from(_ action: AuditAction) -> AuditActionModel {
        AuditActionModel(
            id: action.id,
            sessionId: action.sessionId,
            sessionName: action.sessionName,
            actionType: action.actionType,
            description: action.description,
            filePath: action.filePath,
            command: action.command,
            toolName: action.toolName,
            beforeContent: action.beforeContent,
            afterContent: action.afterContent,
            metadata: action.metadata,
            isRollbackable: action.isRollbackable,
            rollbackStatus: action.rollbackStatus,
            rolledBackAt: action.rolledBackAt,
            rollbackAuditId: action.rollbackAuditId
        )
    }
}
