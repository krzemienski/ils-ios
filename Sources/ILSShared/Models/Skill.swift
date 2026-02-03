import Foundation

/// Source of the skill
public enum SkillSource: String, Codable, Sendable {
    /// Skill from local filesystem
    case local
    /// Skill from installed plugin
    case plugin
    /// Built-in system skill
    case builtin
}

/// Represents a Claude Code skill
public struct Skill: Codable, Identifiable, Sendable {
    /// Unique identifier for the skill
    public let id: UUID
    /// Display name of the skill
    public var name: String
    /// Optional description explaining what the skill does
    public var description: String?
    /// Version string for the skill (e.g., "1.0.0")
    public var version: String?
    /// Array of tags for categorizing and filtering skills
    public var tags: [String]
    /// Whether the skill is currently enabled
    public var isActive: Bool
    /// File system path to the skill file
    public var path: String
    /// Origin of the skill (local, plugin, or builtin)
    public var source: SkillSource
    /// Optional raw content/source code of the skill
    public var content: String?

    /// Creates a new skill instance
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - name: Display name of the skill
    ///   - description: Optional description of what the skill does
    ///   - version: Version string for the skill
    ///   - tags: Array of tags for categorization
    ///   - isActive: Whether the skill is enabled (defaults to true)
    ///   - path: File system path to the skill file
    ///   - source: Origin of the skill (defaults to .local)
    ///   - content: Optional raw content/source code
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        version: String? = nil,
        tags: [String] = [],
        isActive: Bool = true,
        path: String,
        source: SkillSource = .local,
        content: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.tags = tags
        self.isActive = isActive
        self.path = path
        self.source = source
        self.content = content
    }
}
