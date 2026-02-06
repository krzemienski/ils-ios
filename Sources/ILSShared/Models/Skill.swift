import Foundation

/// Source of the skill.
public enum SkillSource: String, Codable, Sendable {
    /// User-created local skill.
    case local
    /// Skill from an installed plugin.
    case plugin
    /// Built-in Claude Code skill.
    case builtin
    /// Skill from GitHub marketplace.
    case github
}

/// Represents a Claude Code skill (custom command/workflow).
public struct Skill: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier.
    public let id: UUID
    /// Skill name (used as command).
    public var name: String
    /// Optional description.
    public var description: String?
    /// Skill version.
    public var version: String?
    /// Tags for categorization.
    public var tags: [String]
    /// Whether the skill is active/enabled.
    public var isActive: Bool
    /// Filesystem path to the skill file.
    public var path: String
    /// Source of the skill.
    public var source: SkillSource
    /// Processed skill content (rendered markdown).
    public var content: String?
    /// Raw markdown content.
    public var rawContent: String?
    /// GitHub stars (for marketplace skills).
    public var stars: Int?
    /// Skill author.
    public var author: String?
    /// Last update timestamp.
    public var lastUpdated: String?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        version: String? = nil,
        tags: [String] = [],
        isActive: Bool = true,
        path: String,
        source: SkillSource = .local,
        content: String? = nil,
        rawContent: String? = nil,
        stars: Int? = nil,
        author: String? = nil,
        lastUpdated: String? = nil
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
        self.rawContent = rawContent
        self.stars = stars
        self.author = author
        self.lastUpdated = lastUpdated
    }

    public static func == (lhs: Skill, rhs: Skill) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
