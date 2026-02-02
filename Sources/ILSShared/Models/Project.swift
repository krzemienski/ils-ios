import Foundation

/// Represents a project (codebase directory) managed by ILS
public struct Project: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var path: String
    public var defaultModel: String
    public var description: String?
    public let createdAt: Date
    public var lastAccessedAt: Date
    public var sessionCount: Int?

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        defaultModel: String = "sonnet",
        description: String? = nil,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        sessionCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.defaultModel = defaultModel
        self.description = description
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.sessionCount = sessionCount
    }
}
