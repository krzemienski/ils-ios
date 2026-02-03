import Foundation

/// Source of the skill
public enum SkillSource: String, Codable, Sendable {
    case local
    case plugin
    case builtin
    case github
}

/// Represents a Claude Code skill
public struct Skill: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var version: String?
    public var tags: [String]
    public var isActive: Bool
    public var path: String
    public var source: SkillSource
    public var content: String?

    // GitHub-specific fields (populated when source is .github)
    public var githubUrl: String?
    public var stargazersCount: Int?
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
        githubUrl: String? = nil,
        stargazersCount: Int? = nil,
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
        self.githubUrl = githubUrl
        self.stargazersCount = stargazersCount
        self.lastUpdated = lastUpdated
    }
}
