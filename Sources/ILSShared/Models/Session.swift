import Foundation

/// Represents the execution status of a Claude Code session.
public enum SessionStatus: String, Codable, Sendable {
    /// Session is actively running and can accept messages.
    case active
    /// Session completed successfully.
    case completed
    /// Session was cancelled by the user.
    case cancelled
    /// Session terminated due to an error.
    case error
}

/// Source of the session (ILS-created or discovered from Claude Code).
public enum SessionSource: String, Codable, Sendable {
    /// Session created within ILS.
    case ils
    /// Session discovered from Claude Code storage.
    case external
}

/// Permission mode for Claude Code execution.
public enum PermissionMode: String, Codable, Sendable {
    /// Default permission mode (prompt for each action).
    case `default` = "default"
    /// Automatically accept edit operations.
    case acceptEdits = "acceptEdits"
    /// Planning mode (no execution).
    case plan = "plan"
    /// Bypass all permission checks (auto-accept all).
    case bypassPermissions = "bypassPermissions"
    /// Delegate mode for agent orchestration.
    case delegate = "delegate"
    /// Don't ask for permissions (similar to bypassPermissions).
    case dontAsk = "dontAsk"
}

/// Represents a chat session with Claude Code.
public struct ChatSession: Codable, Identifiable, Sendable, Hashable {
    /// Unique identifier for the session.
    public let id: UUID
    /// Claude Code's internal session ID.
    public var claudeSessionId: String?
    /// User-provided name for the session.
    public var name: String?
    /// Associated project ID.
    public var projectId: UUID?
    /// Name of the associated project.
    public var projectName: String?
    /// Claude model used (e.g., "sonnet", "opus", "haiku").
    public var model: String
    /// Permission mode for this session.
    public var permissionMode: PermissionMode
    /// Current status of the session.
    public var status: SessionStatus
    /// Number of messages exchanged in this session.
    public var messageCount: Int
    /// Total cost in USD for this session.
    public var totalCostUSD: Double?
    /// Source of the session.
    public var source: SessionSource
    /// ID of the session this was forked from.
    public var forkedFrom: UUID?
    /// When the session was created.
    public let createdAt: Date
    /// Last time the session was active.
    public var lastActiveAt: Date
    /// URL-encoded project path for the session.
    public var encodedProjectPath: String?
    /// First user prompt in the session.
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

/// External session discovered from Claude Code storage.
public struct ExternalSession: Codable, Identifiable, Sendable {
    /// Unique identifier (maps to claudeSessionId).
    public var id: String { claudeSessionId }
    /// Claude Code's internal session ID.
    public let claudeSessionId: String
    /// User-provided name for the session.
    public var name: String?
    /// Filesystem path to the project.
    public let projectPath: String?
    /// URL-encoded project path.
    public let encodedProjectPath: String?
    /// Name of the project.
    public let projectName: String?
    /// Source of the session.
    public let source: SessionSource
    /// Last time the session was active.
    public let lastActiveAt: Date?
    /// When the session was created.
    public let createdAt: Date?
    /// Number of messages in the session.
    public let messageCount: Int?
    /// First user prompt.
    public let firstPrompt: String?
    /// AI-generated summary of the session.
    public let summary: String?
    /// Git branch associated with the session.
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
