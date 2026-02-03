import Foundation

/// Represents a project (codebase directory) managed by ILS
public struct Project: Codable, Identifiable, Sendable, Hashable {
    /// Unique identifier for the project
    public let id: UUID

    /// Display name of the project
    public var name: String

    /// File system path to the project directory
    public var path: String

    /// Default AI model to use for sessions in this project
    public var defaultModel: String

    /// Optional description providing context about the project
    public var description: String?

    /// Timestamp when the project was first created
    public let createdAt: Date

    /// Timestamp of the most recent access to this project
    public var lastAccessedAt: Date

    /// Number of sessions associated with this project
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
