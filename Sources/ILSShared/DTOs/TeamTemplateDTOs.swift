import Foundation

// MARK: - Team Template Models

/// A reusable team template for common workflows.
public struct TeamTemplate: Codable, Sendable, Identifiable, Hashable {
    /// Unique template identifier.
    public let id: String
    /// Template display name.
    public let name: String
    /// Template description and purpose.
    public let description: String?
    /// Category (e.g., "research", "development", "testing").
    public let category: String?
    /// Pre-configured team members.
    public var members: [TemplateMember]
    /// Pre-configured tasks with dependencies.
    public var tasks: [TemplateTask]
    /// Whether this is a built-in template.
    public let isBuiltIn: Bool
    /// When the template was created.
    public let createdAt: Date?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        category: String? = nil,
        members: [TemplateMember] = [],
        tasks: [TemplateTask] = [],
        isBuiltIn: Bool = false,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.members = members
        self.tasks = tasks
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }
}

/// A pre-configured team member in a template.
public struct TemplateMember: Codable, Sendable, Identifiable, Hashable {
    /// Member name.
    public let name: String
    /// Agent type/role.
    public let agentType: String?
    /// Recommended model (haiku/sonnet/opus).
    public let model: String?
    /// Initial prompt for the agent.
    public let prompt: String?

    public var id: String { name }

    public init(name: String, agentType: String? = nil, model: String? = nil, prompt: String? = nil) {
        self.name = name
        self.agentType = agentType
        self.model = model
        self.prompt = prompt
    }
}

/// A pre-configured task in a template.
public struct TemplateTask: Codable, Sendable, Identifiable, Hashable {
    /// Task identifier.
    public let id: String
    /// Brief task title.
    public let subject: String
    /// Detailed task description.
    public let description: String?
    /// Pre-assigned owner name.
    public let owner: String?
    /// IDs of tasks that block this one.
    public var blockedBy: [String]?
    /// Visual position in workflow builder (x, y).
    public var position: CGPoint?
    /// Execution order priority (lower = earlier).
    public var executionOrder: Int?

    public init(
        id: String,
        subject: String,
        description: String? = nil,
        owner: String? = nil,
        blockedBy: [String]? = nil,
        position: CGPoint? = nil,
        executionOrder: Int? = nil
    ) {
        self.id = id
        self.subject = subject
        self.description = description
        self.owner = owner
        self.blockedBy = blockedBy
        self.position = position
        self.executionOrder = executionOrder
    }
}

// MARK: - CGPoint Codable Extension

extension CGPoint: @retroactive Codable, @retroactive Hashable {
    enum CodingKeys: String, CodingKey {
        case x
        case y
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }

    public static func == (lhs: CGPoint, rhs: CGPoint) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y
    }
}

// MARK: - Request Types

/// Request to create a new team template.
public struct CreateTeamTemplateRequest: Codable, Sendable {
    /// Template name.
    public let name: String
    /// Template description.
    public let description: String?
    /// Template category.
    public let category: String?
    /// Pre-configured members.
    public let members: [TemplateMember]?
    /// Pre-configured tasks.
    public let tasks: [TemplateTask]?

    public init(
        name: String,
        description: String? = nil,
        category: String? = nil,
        members: [TemplateMember]? = nil,
        tasks: [TemplateTask]? = nil
    ) {
        self.name = name
        self.description = description
        self.category = category
        self.members = members
        self.tasks = tasks
    }
}

/// Request to update an existing team template.
public struct UpdateTeamTemplateRequest: Codable, Sendable {
    /// New name.
    public let name: String?
    /// New description.
    public let description: String?
    /// New category.
    public let category: String?
    /// Updated members.
    public let members: [TemplateMember]?
    /// Updated tasks.
    public let tasks: [TemplateTask]?

    public init(
        name: String? = nil,
        description: String? = nil,
        category: String? = nil,
        members: [TemplateMember]? = nil,
        tasks: [TemplateTask]? = nil
    ) {
        self.name = name
        self.description = description
        self.category = category
        self.members = members
        self.tasks = tasks
    }
}

/// Request to create a team from a template.
public struct ApplyTemplateRequest: Codable, Sendable {
    /// New team name.
    public let teamName: String
    /// Optional team description (overrides template).
    public let teamDescription: String?

    public init(teamName: String, teamDescription: String? = nil) {
        self.teamName = teamName
        self.teamDescription = teamDescription
    }
}
