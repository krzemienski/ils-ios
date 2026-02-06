import Foundation

/// Role of a message in a conversation.
public enum MessageRole: String, Codable, Sendable {
    /// User message.
    case user
    /// Assistant response.
    case assistant
    /// System message.
    case system
}

/// Represents a message in a chat session (persisted in database).
public struct Message: Codable, Identifiable, Sendable {
    /// Unique identifier.
    public let id: UUID
    /// Associated session ID.
    public let sessionId: UUID
    /// Message role.
    public var role: MessageRole
    /// Message content text.
    public var content: String
    /// JSON-encoded tool calls.
    public var toolCalls: String?
    /// JSON-encoded tool results.
    public var toolResults: String?
    /// When the message was created.
    public let createdAt: Date
    /// When the message was last updated.
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        role: MessageRole,
        content: String,
        toolCalls: String? = nil,
        toolResults: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolResults = toolResults
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
