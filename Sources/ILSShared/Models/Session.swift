import Foundation

/// Session status enumeration
public enum SessionStatus: String, Codable, Sendable {
    case active
    case completed
    case cancelled
    case error
}

/// Source of the session (ILS-created or discovered from Claude Code)
public enum SessionSource: String, Codable, Sendable {
    case ils
    case external
}

/// Permission mode for Claude Code execution
public enum PermissionMode: String, Codable, Sendable {
    case `default` = "default"
    case acceptEdits = "acceptEdits"
    case plan = "plan"
    case bypassPermissions = "bypassPermissions"
}

/// Represents a chat session with Claude Code
public struct ChatSession: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public var claudeSessionId: String?
    public var name: String?
    public var projectId: UUID?
    public var projectName: String?
    public var model: String
    public var permissionMode: PermissionMode
    public var status: SessionStatus
    public var messageCount: Int
    public var totalCostUSD: Double?
    public var source: SessionSource
    public var forkedFrom: UUID?
    public let createdAt: Date
    public var lastActiveAt: Date
    public var encodedProjectPath: String?
    public var firstPrompt: String?

    public init(
        id: UUID = UUID(),
        claudeSessionId: String? = nil,
        name: String? = nil,
        projectId: UUID? = nil,
        projectName: String? = nil,
        model: String = "sonnet",
        permissionMode: PermissionMode = .default,
        status: SessionStatus = .active,
        messageCount: Int = 0,
        totalCostUSD: Double? = nil,
        source: SessionSource = .ils,
        forkedFrom: UUID? = nil,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date(),
        encodedProjectPath: String? = nil,
        firstPrompt: String? = nil
    ) {
        self.id = id
        self.claudeSessionId = claudeSessionId
        self.name = name
        self.projectId = projectId
        self.projectName = projectName
        self.model = model
        self.permissionMode = permissionMode
        self.status = status
        self.messageCount = messageCount
        self.totalCostUSD = totalCostUSD
        self.source = source
        self.forkedFrom = forkedFrom
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.encodedProjectPath = encodedProjectPath
        self.firstPrompt = firstPrompt
    }
}

/// External session discovered from Claude Code storage
public struct ExternalSession: Codable, Identifiable, Sendable {
    public var id: String { claudeSessionId }
    public let claudeSessionId: String
    public var name: String?
    public let projectPath: String?
    public let encodedProjectPath: String?
    public let projectName: String?
    public let source: SessionSource
    public let lastActiveAt: Date?
    public let createdAt: Date?
    public let messageCount: Int?
    public let firstPrompt: String?
    public let summary: String?
    public let gitBranch: String?

    public init(
        claudeSessionId: String,
        name: String? = nil,
        projectPath: String? = nil,
        encodedProjectPath: String? = nil,
        projectName: String? = nil,
        source: SessionSource = .external,
        lastActiveAt: Date? = nil,
        createdAt: Date? = nil,
        messageCount: Int? = nil,
        firstPrompt: String? = nil,
        summary: String? = nil,
        gitBranch: String? = nil
    ) {
        self.claudeSessionId = claudeSessionId
        self.name = name
        self.projectPath = projectPath
        self.encodedProjectPath = encodedProjectPath
        self.projectName = projectName
        self.source = source
        self.lastActiveAt = lastActiveAt
        self.createdAt = createdAt
        self.messageCount = messageCount
        self.firstPrompt = firstPrompt
        self.summary = summary
        self.gitBranch = gitBranch
    }
}
