import Foundation

/// Source of the skill
public enum SkillSource: String, Codable, Sendable {
    case local
    case plugin
    case builtin
    case github
}

/// Represents a Claude Code skill
public struct Skill: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var version: String?
    public var tags: [String]
    public var isActive: Bool
    public var path: String
    public var source: SkillSource
    public var content: String?
    public var rawContent: String?
    public var stars: Int?
    public var author: String?
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
