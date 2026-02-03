import Foundation

/// Category of the skill
public enum SkillCategory: String, Codable, Sendable {
    case coding
    case writing
    case research
    case productivity
    case other
}

/// Represents a skill available from a remote GitHub repository
public struct RemoteSkill: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var version: String?
    public var tags: [String]
    public var githubUrl: String
    public var stars: Int
    public var author: String
    public var lastUpdated: Date
    public var installCount: Int
    public var compatibility: String?
    public var category: SkillCategory

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        version: String? = nil,
        tags: [String] = [],
        githubUrl: String,
        stars: Int = 0,
        author: String,
        lastUpdated: Date = Date(),
        installCount: Int = 0,
        compatibility: String? = nil,
        category: SkillCategory = .other
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.tags = tags
        self.githubUrl = githubUrl
        self.stars = stars
        self.author = author
        self.lastUpdated = lastUpdated
        self.installCount = installCount
        self.compatibility = compatibility
        self.category = category
    }
}
