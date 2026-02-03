import Foundation

/// Source of the skill
public enum SkillSource: String, Codable, Sendable {
    case local
    case plugin
    case builtin
}

/// Represents a Claude Code skill
public struct Skill: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var author: String?
    public var version: String?
    public var tags: [String]
    public var tools: [String]
    public var isActive: Bool
    public var path: String
    public var source: SkillSource
    public var content: String?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        author: String? = nil,
        version: String? = nil,
        tags: [String] = [],
        tools: [String] = [],
        isActive: Bool = true,
        path: String,
        source: SkillSource = .local,
        content: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.tags = tags
        self.tools = tools
        self.isActive = isActive
        self.path = path
        self.source = source
        self.content = content
    }
}
