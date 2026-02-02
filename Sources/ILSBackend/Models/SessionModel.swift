import Fluent
import Vapor
import ILSShared

/// Fluent model for Session
final class SessionModel: Model, Content, @unchecked Sendable {
    static let schema = "sessions"

    @ID(key: .id)
    var id: UUID?

    @OptionalField(key: "claude_session_id")
    var claudeSessionId: String?

    @OptionalField(key: "name")
    var name: String?

    @OptionalParent(key: "project_id")
    var project: ProjectModel?

    @Field(key: "model")
    var model: String

    @Field(key: "permission_mode")
    var permissionMode: String

    @Field(key: "status")
    var status: String

    @Field(key: "message_count")
    var messageCount: Int

    @OptionalField(key: "total_cost_usd")
    var totalCostUSD: Double?

    @Field(key: "source")
    var source: String

    @OptionalField(key: "forked_from")
    var forkedFrom: UUID?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "last_active_at", on: .update)
    var lastActiveAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        claudeSessionId: String? = nil,
        name: String? = nil,
        projectId: UUID? = nil,
        model: String = "sonnet",
        permissionMode: PermissionMode = .default,
        status: SessionStatus = .active,
        messageCount: Int = 0,
        totalCostUSD: Double? = nil,
        source: SessionSource = .ils,
        forkedFrom: UUID? = nil
    ) {
        self.id = id
        self.claudeSessionId = claudeSessionId
        self.name = name
        if let projectId = projectId {
            self.$project.id = projectId
        }
        self.model = model
        self.permissionMode = permissionMode.rawValue
        self.status = status.rawValue
        self.messageCount = messageCount
        self.totalCostUSD = totalCostUSD
        self.source = source.rawValue
        self.forkedFrom = forkedFrom
    }

    /// Convert to shared ChatSession type
    func toShared(projectName: String? = nil) -> ChatSession {
        ChatSession(
            id: id ?? UUID(),
            claudeSessionId: claudeSessionId,
            name: name,
            projectId: $project.id,
            projectName: projectName,
            model: model,
            permissionMode: PermissionMode(rawValue: permissionMode) ?? .default,
            status: SessionStatus(rawValue: status) ?? .active,
            messageCount: messageCount,
            totalCostUSD: totalCostUSD,
            source: SessionSource(rawValue: source) ?? .ils,
            forkedFrom: forkedFrom,
            createdAt: createdAt ?? Date(),
            lastActiveAt: lastActiveAt ?? Date()
        )
    }

    /// Create from shared ChatSession type
    static func from(_ session: ChatSession) -> SessionModel {
        SessionModel(
            id: session.id,
            claudeSessionId: session.claudeSessionId,
            name: session.name,
            projectId: session.projectId,
            model: session.model,
            permissionMode: session.permissionMode,
            status: session.status,
            messageCount: session.messageCount,
            totalCostUSD: session.totalCostUSD,
            source: session.source,
            forkedFrom: session.forkedFrom
        )
    }
}
