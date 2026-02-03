import Foundation

/// Role of a message in a conversation
public enum MessageRole: String, Codable, Sendable {
    /// Message from the user
    case user
    /// Message from the AI assistant
    case assistant
    /// System-level message for context or instructions
    case system
}

/// Represents a message in a chat session
public struct Message: Codable, Identifiable, Sendable {
    /// Unique identifier for the message
    public let id: UUID
    /// Identifier of the session this message belongs to
    public let sessionId: UUID
    /// Role of the message sender (user, assistant, or system)
    public var role: MessageRole
    /// Text content of the message
    public var content: String
    /// JSON string of tool calls made during message generation
    public var toolCalls: String?
    /// JSON string of tool execution results
    public var toolResults: String?
    /// Timestamp when the message was created
    public let createdAt: Date
    /// Timestamp when the message was last updated
    public var updatedAt: Date

    /// Creates a new message
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - sessionId: Identifier of the session this message belongs to
    ///   - role: Role of the message sender
    ///   - content: Text content of the message
    ///   - toolCalls: Optional JSON string of tool calls
    ///   - toolResults: Optional JSON string of tool results
    ///   - createdAt: Creation timestamp (defaults to current date)
    ///   - updatedAt: Last update timestamp (defaults to current date)
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
