import Foundation

// MARK: - Claude Model

/// Claude model identifier for session and project configuration.
///
/// Known model families are represented as enum cases. Unknown or future
/// model identifiers are preserved via the ``unknown(_:)`` case so that
/// Codable round-tripping never fails on new model strings from the CLI.
public enum ClaudeModel: Codable, Hashable, Sendable, CustomStringConvertible {
    /// Claude Haiku -- fast, lightweight model.
    case haiku
    /// Claude Sonnet -- balanced performance model.
    case sonnet
    /// Claude Opus -- most capable model.
    case opus

    /// An unrecognized model string from the API or CLI.
    case unknown(String)

    /// The raw string value used for serialization and display.
    public var rawValue: String {
        switch self {
        case .haiku: return "haiku"
        case .sonnet: return "sonnet"
        case .opus: return "opus"
        case .unknown(let value): return value
        }
    }

    public var description: String { rawValue }

    /// Human-readable display name for the model.
    public var displayName: String {
        switch self {
        case .haiku: return "Claude Haiku"
        case .sonnet: return "Claude Sonnet"
        case .opus: return "Claude Opus"
        case .unknown(let value): return value
        }
    }

    /// All known model families (excludes `.unknown`).
    public static let allKnown: [ClaudeModel] = [.sonnet, .opus, .haiku]

    /// Full model ID strings used in Claude CLI config files.
    /// These map to the model families above and are the values
    /// stored in `~/.claude/settings.json` under the `model` key.
    public static let allModelIDs: [String] = [
        "claude-sonnet-4-20250514",
        "claude-opus-4-20250514",
        "claude-haiku-3-5-20241022"
    ]

    /// Returns a display-friendly name for a full model ID string.
    public static func displayNameForID(_ modelID: String) -> String {
        if modelID.contains("sonnet") {
            return "Claude Sonnet"
        } else if modelID.contains("opus") {
            return "Claude Opus"
        } else if modelID.contains("haiku") {
            return "Claude Haiku"
        }
        return modelID
    }

    /// Creates a ``ClaudeModel`` from a raw string value.
    public init(rawValue: String) {
        switch rawValue {
        case "haiku": self = .haiku
        case "sonnet": self = .sonnet
        case "opus": self = .opus
        default: self = .unknown(rawValue)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.init(rawValue: value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Session Enums

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

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized SessionStatus: '\(raw)'. Expected: active, completed, cancelled, error"
                )
            )
        }
        self = value
    }
}

/// Source of the session (ILS-created or discovered from Claude Code).
public enum SessionSource: String, Codable, Sendable {
    /// Session created within ILS.
    case ils
    /// Session discovered from Claude Code storage.
    case external

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized SessionSource: '\(raw)'. Expected: ils, external"
                )
            )
        }
        self = value
    }
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized PermissionMode: '\(raw)'. Expected: default, acceptEdits, plan, bypassPermissions, delegate, dontAsk"
                )
            )
        }
        self = value
    }
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

    /// Creates a new chat session.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - claudeSessionId: Claude Code's internal session ID.
    ///   - name: Optional user-provided session name.
    ///   - projectId: Optional associated project ID.
    ///   - projectName: Optional project display name.
    ///   - model: Claude model to use (default: "sonnet").
    ///   - permissionMode: Permission mode for tool execution.
    ///   - status: Initial session status.
    ///   - messageCount: Number of messages exchanged.
    ///   - totalCostUSD: Total cost in USD.
    ///   - source: Session source (ILS or external).
    ///   - forkedFrom: ID of the session this was forked from.
    ///   - createdAt: Creation timestamp.
    ///   - lastActiveAt: Last activity timestamp.
    ///   - encodedProjectPath: URL-encoded project path.
    ///   - firstPrompt: First user prompt.
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
        precondition(!model.isEmpty, "ChatSession model must not be empty")
        precondition(messageCount >= 0, "ChatSession messageCount must be non-negative")
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

    /// Pre-compiled regex for stripping markdown heading prefixes.
    /// Avoids recompiling the pattern on every `displayName` access (hot path for 22K+ sessions).
    private static let headingPrefixRegex = try! NSRegularExpression(pattern: "^#{1,6}\\s*")

    /// A cleaned display name suitable for UI rendering.
    ///
    /// Strips leading markdown heading prefixes (`#`, `##`, `###`, etc.) and trims
    /// whitespace so that session names imported from Claude Code conversations
    /// render cleanly in lists and navigation bars.  Falls back to `"Unnamed Session"`
    /// when no meaningful name is available.
    public var displayName: String {
        if let name, !name.isEmpty {
            let range = NSRange(name.startIndex..., in: name)
            let cleaned = Self.headingPrefixRegex
                .stringByReplacingMatches(in: name, range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespaces)
            return cleaned.isEmpty ? "Unnamed Session" : cleaned
        }
        if let prompt = firstPrompt, !prompt.isEmpty {
            let range = NSRange(prompt.startIndex..., in: prompt)
            let trimmed = Self.headingPrefixRegex
                .stringByReplacingMatches(in: prompt, range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespaces)
            return String(trimmed.prefix(40))
        }
        return "Unnamed Session"
    }
}

/// External session discovered from Claude Code storage.
public struct ExternalSession: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier (maps to claudeSessionId).
    public var id: String { claudeSessionId }
    /// Claude Code's internal session ID.
    public let claudeSessionId: String
    /// User-provided name for the session.
    public var name: String?
    /// Filesystem path to the project directory.
    public let projectPath: String?
    /// URL-encoded project path for API calls.
    public let encodedProjectPath: String?
    /// Display name of the associated project.
    public let projectName: String?
    /// Source of the session (always `.external` for discovered sessions).
    public let source: SessionSource
    /// Last time the session was active.
    public let lastActiveAt: Date?
    /// When the session was originally created.
    public let createdAt: Date?
    /// Number of messages exchanged in the session.
    public let messageCount: Int?
    /// First user prompt in the session (for display/search).
    public let firstPrompt: String?
    /// AI-generated summary of the session conversation.
    public let summary: String?
    /// Git branch that was active during the session.
    public let gitBranch: String?

    /// Creates an external session entry.
    /// - Parameters:
    ///   - claudeSessionId: Claude Code's internal session ID.
    ///   - name: Optional user-provided name.
    ///   - projectPath: Filesystem path to the project.
    ///   - encodedProjectPath: URL-encoded project path.
    ///   - projectName: Display name of the project.
    ///   - source: Session source (default: `.external`).
    ///   - lastActiveAt: Last activity timestamp.
    ///   - createdAt: Creation timestamp.
    ///   - messageCount: Number of messages.
    ///   - firstPrompt: First user prompt.
    ///   - summary: AI-generated summary.
    ///   - gitBranch: Associated git branch.
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
        precondition(!claudeSessionId.isEmpty, "ExternalSession claudeSessionId must not be empty")
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
