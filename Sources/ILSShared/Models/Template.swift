import Foundation

/// Represents a reusable prompt template
public struct Template: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var content: String
    public var description: String?
    public var category: String?
    public let createdAt: Date
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        content: String,
        description: String? = nil,
        category: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.description = description
        self.category = category
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}
