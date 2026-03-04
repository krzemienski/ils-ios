import Fluent
import Vapor
import ILSShared

/// Fluent model for SessionCheckpoint
final class SessionCheckpointModel: Model, Content, @unchecked Sendable {
    static let schema = "session_checkpoints"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "session_id")
    var session: SessionModel

    @Field(key: "name")
    var name: String

    @Field(key: "message_count")
    var messageCount: Int

    @Field(key: "is_automatic")
    var isAutomatic: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        sessionId: UUID,
        name: String,
        messageCount: Int = 0,
        isAutomatic: Bool = false
    ) {
        self.id = id
        self.$session.id = sessionId
        self.name = name
        self.messageCount = messageCount
        self.isAutomatic = isAutomatic
    }

    /// Convert to shared SessionCheckpoint type
    func toShared() -> SessionCheckpoint {
        SessionCheckpoint(
            id: id ?? UUID(),
            sessionId: $session.id,
            name: name,
            createdAt: createdAt ?? Date(),
            messageCount: messageCount,
            isAutomatic: isAutomatic
        )
    }

    /// Create from shared SessionCheckpoint type
    static func from(_ checkpoint: SessionCheckpoint) -> SessionCheckpointModel {
        SessionCheckpointModel(
            id: checkpoint.id,
            sessionId: checkpoint.sessionId,
            name: checkpoint.name,
            messageCount: checkpoint.messageCount,
            isAutomatic: checkpoint.isAutomatic
        )
    }
}
