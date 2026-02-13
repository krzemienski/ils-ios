import Foundation

/// Represents a reusable code snippet
public struct Snippet: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var content: String
    public var description: String?
    public var language: String?
    public var category: String?
    public let createdAt: Date
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        content: String,
        description: String? = nil,
        language: String? = nil,
        category: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.description = description
        self.language = language
        self.category = category
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}
