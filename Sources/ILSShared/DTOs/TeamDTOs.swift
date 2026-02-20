import Foundation

// MARK: - Agent Team Models

/// An agent team with members working on shared tasks.
public struct AgentTeam: Codable, Sendable, Identifiable {
    /// Team name (alphanumeric + hyphens).
    public let name: String
    /// Optional description of team purpose.
    public let description: String?
    /// Team members.
    public var members: [TeamMember]
    /// When the team was created.
    public let createdAt: Date?

    public var id: String { name }

    public init(name: String, description: String? = nil, members: [TeamMember] = [], createdAt: Date? = nil) {
        self.name = name
        self.description = description
        self.members = members
        self.createdAt = createdAt
    }
}

/// A member of an agent team.
public struct TeamMember: Codable, Sendable, Identifiable {
    /// Human-readable member name.
    public let name: String
    /// Unique agent identifier.
    public let agentId: String?
    /// Agent type/role (e.g., "researcher", "executor").
    public let agentType: String?
    /// Current member status.
    public var status: TeamMemberStatus?
    /// Process ID if running.
    public let pid: Int?

    public var id: String { name }

    public init(name: String, agentId: String? = nil, agentType: String? = nil, status: TeamMemberStatus? = nil, pid: Int? = nil) {
        self.name = name
        self.agentId = agentId
        self.agentType = agentType
        self.status = status
        self.pid = pid
    }
}

/// Status of a team member.
public enum TeamMemberStatus: String, Codable, Sendable {
    case idle
    case active
    case shutdown
}

// MARK: - Team Tasks

/// A task in a team's task list.
public struct TeamTask: Codable, Sendable, Identifiable {
    /// Task identifier.
    public let id: String
    /// Brief task title.
    public let subject: String
    /// Detailed task description.
    public let description: String?
    /// Current task status.
    public var status: TeamTaskStatus
    /// Name of the assigned owner.
    public var owner: String?
    /// IDs of tasks that block this one.
    public var blockedBy: [String]?

    public init(id: String, subject: String, description: String? = nil, status: TeamTaskStatus = .pending, owner: String? = nil, blockedBy: [String]? = nil) {
        self.id = id
        self.subject = subject
        self.description = description
        self.status = status
        self.owner = owner
        self.blockedBy = blockedBy
    }
}

/// Status of a team task.
public enum TeamTaskStatus: String, Codable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case deleted
}

// MARK: - Team Messages

/// A message sent between team members.
public struct TeamMessage: Codable, Sendable, Identifiable {
    /// Sender name.
    public let from: String
    /// Recipient name (nil = broadcast).
    public let to: String?
    /// Message content.
    public let content: String
    /// When the message was sent.
    public let timestamp: Date?

    public var id: String { "\(from)-\(timestamp?.timeIntervalSince1970 ?? 0)" }

    public init(from: String, to: String? = nil, content: String, timestamp: Date? = nil) {
        self.from = from
        self.to = to
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Request Types

/// Request to create a new team.
public struct CreateTeamRequest: Codable, Sendable {
    /// Team name (alphanumeric + hyphens only).
    public let name: String
    /// Optional team description.
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

/// Request to spawn a new teammate.
public struct SpawnTeammateRequest: Codable, Sendable {
    /// Teammate name.
    public let name: String
    /// Agent type/role.
    public let agentType: String?
    /// Model to use (haiku/sonnet/opus).
    public let model: String?
    /// Initial prompt for the agent.
    public let prompt: String?

    public init(name: String, agentType: String? = nil, model: String? = nil, prompt: String? = nil) {
        self.name = name
        self.agentType = agentType
        self.model = model
        self.prompt = prompt
    }
}

/// Request to send a message to a team member.
public struct SendTeamMessageRequest: Codable, Sendable {
    /// Recipient name (nil = broadcast).
    public let to: String?
    /// Message content.
    public let content: String
    /// Sender name.
    public let from: String?

    public init(to: String? = nil, content: String, from: String? = nil) {
        self.to = to
        self.content = content
        self.from = from
    }
}

/// Request to create a task in a team's task list.
public struct CreateTeamTaskRequest: Codable, Sendable {
    /// Brief task title.
    public let subject: String
    /// Detailed description.
    public let description: String?

    public init(subject: String, description: String? = nil) {
        self.subject = subject
        self.description = description
    }
}

/// Request to update a team task.
public struct UpdateTeamTaskRequest: Codable, Sendable {
    /// New status.
    public let status: TeamTaskStatus?
    /// New owner.
    public let owner: String?
    /// New subject.
    public let subject: String?
    /// New description.
    public let description: String?

    public init(status: TeamTaskStatus? = nil, owner: String? = nil, subject: String? = nil, description: String? = nil) {
        self.status = status
        self.owner = owner
        self.subject = subject
        self.description = description
    }
}

/// Request to shutdown a specific or all teammates.
public struct ShutdownTeammateRequest: Codable, Sendable {
    /// Member name to shutdown (nil = shutdown all).
    public let memberName: String?

    public init(memberName: String? = nil) {
        self.memberName = memberName
    }
}
