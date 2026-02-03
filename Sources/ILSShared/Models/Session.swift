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
public struct ChatSession: Codable, Identifiable, Sendable {
    /// Unique identifier for the session
    public let id: UUID

    /// Claude Code's internal session identifier
    public var claudeSessionId: String?

    /// Display name for the session
    public var name: String?

    /// Associated project identifier
    public var projectId: UUID?

    /// Display name of the associated project
    public var projectName: String?

    /// Claude model being used (e.g., "sonnet", "opus", "haiku")
    public var model: String

    /// Permission mode controlling Claude Code execution behavior
    public var permissionMode: PermissionMode

    /// Current status of the session
    public var status: SessionStatus

    /// Total number of messages in the session
    public var messageCount: Int

    /// Total cost in USD for API usage (optional)
    public var totalCostUSD: Double?

    /// Source indicating whether session was created by ILS or discovered externally
    public var source: SessionSource

    /// Identifier of the parent session if this was forked
    public var forkedFrom: UUID?

    /// Timestamp when the session was created
    public let createdAt: Date

    /// Timestamp of the last activity in this session
    public var lastActiveAt: Date

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
        lastActiveAt: Date = Date()
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
    }
}

/// External session discovered from Claude Code storage
public struct ExternalSession: Codable, Sendable {
    /// Claude Code's internal session identifier
    public let claudeSessionId: String

    /// Display name for the session
    public var name: String?

    /// File system path to the project directory
    public let projectPath: String?

    /// Source indicating the session origin (typically external)
    public let source: SessionSource

    /// Timestamp of the last activity in this session
    public let lastActiveAt: Date?

    public init(
        claudeSessionId: String,
        name: String? = nil,
        projectPath: String? = nil,
        source: SessionSource = .external,
        lastActiveAt: Date? = nil
    ) {
        self.claudeSessionId = claudeSessionId
        self.name = name
        self.projectPath = projectPath
        self.source = source
        self.lastActiveAt = lastActiveAt
    }
}
