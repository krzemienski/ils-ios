import Foundation

/// Role of a message in a conversation
public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

/// Represents a message in a chat session
public struct Message: Codable, Identifiable, Sendable {
    public let id: UUID
    public let sessionId: UUID
    public var role: MessageRole
    public var content: String
    public var toolCalls: String?
    public var toolResults: String?
    public let createdAt: Date
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
