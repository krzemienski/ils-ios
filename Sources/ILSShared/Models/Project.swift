import Foundation

/// Represents a project (codebase directory) managed by ILS.
public struct Project: Codable, Identifiable, Sendable, Hashable {
    /// Unique identifier for the project.
    public let id: UUID
    /// Display name of the project.
    public var name: String
    /// Filesystem path to the project directory.
    public var path: String
    /// Default Claude model for new sessions (e.g., "sonnet").
    public var defaultModel: String
    /// Optional description of the project.
    public var description: String?
    /// When the project was created.
    public let createdAt: Date
    /// Last time the project was accessed.
    public var lastAccessedAt: Date
    /// Number of sessions associated with this project.
    public var sessionCount: Int?
    /// URL-encoded version of the path.
    public var encodedPath: String?

    /// Creates a new project entry.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - name: Display name. Must not be empty.
    ///   - path: Filesystem path to the project directory. Must not be empty.
    ///   - defaultModel: Default Claude model for new sessions (default: "sonnet").
    ///   - description: Optional project description.
    ///   - createdAt: Creation timestamp.
    ///   - lastAccessedAt: Last access timestamp.
    ///   - sessionCount: Number of associated sessions.
    ///   - encodedPath: URL-encoded version of the path.
    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        defaultModel: String = "sonnet",
        description: String? = nil,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        sessionCount: Int? = nil,
        encodedPath: String? = nil
    ) {
        precondition(!name.isEmpty, "Project name must not be empty")
        precondition(!path.isEmpty, "Project path must not be empty")
        self.id = id
        self.name = name
        self.path = path
        self.defaultModel = defaultModel
        self.description = description
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.sessionCount = sessionCount
        self.encodedPath = encodedPath
    }
}
