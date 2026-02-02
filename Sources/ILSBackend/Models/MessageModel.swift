import Fluent
import Vapor
import ILSShared

/// Fluent model for Message persistence
final class MessageModel: Model, Content, @unchecked Sendable {
    static let schema = "messages"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "session_id")
    var session: SessionModel

    @Field(key: "role")
    var role: String

    @Field(key: "content")
    var content: String

    @OptionalField(key: "tool_calls")
    var toolCalls: String?

    @OptionalField(key: "tool_results")
    var toolResults: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        sessionId: UUID,
        role: MessageRole,
        content: String,
        toolCalls: String? = nil,
        toolResults: String? = nil
    ) {
        self.id = id
        self.$session.id = sessionId
        self.role = role.rawValue
        self.content = content
        self.toolCalls = toolCalls
        self.toolResults = toolResults
    }

    /// Convert to shared Message type
    func toShared() -> Message {
        Message(
            id: id ?? UUID(),
            sessionId: $session.id,
            role: MessageRole(rawValue: role) ?? .user,
            content: content,
            toolCalls: toolCalls,
            toolResults: toolResults,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }

    /// Create from shared Message type
    static func from(_ message: Message) -> MessageModel {
        MessageModel(
            id: message.id,
            sessionId: message.sessionId,
            role: message.role,
            content: message.content,
            toolCalls: message.toolCalls,
            toolResults: message.toolResults
        )
    }
}
