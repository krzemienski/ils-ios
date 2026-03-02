import Foundation

// MARK: - API Response Wrapper

/// Standard API response envelope for all backend responses.
///
/// All ILS backend endpoints return this envelope structure, which includes:
/// - Success indicator
/// - Data payload (nil on error)
/// - Error information (nil on success)
///
/// - Parameters:
///   - T: The type of the data payload
public struct APIResponse<T: Codable>: Codable where T: Sendable {
    /// Whether the request succeeded.
    public let success: Bool
    /// Response data payload (nil on error).
    public let data: T?
    /// Error details (nil on success).
    public let error: APIError?

    public init(success: Bool, data: T? = nil, error: APIError? = nil) {
        self.success = success
        self.data = data
        self.error = error
    }
}

/// Error information returned in APIResponse when success is false.
public struct APIError: Codable, Sendable {
    /// Error code (e.g., "validation_error", "not_found").
    public let code: String
    /// Human-readable error message.
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

/// Generic list response with items array and total count.
///
/// Used for paginated endpoints that return collections.
public struct ListResponse<T: Codable>: Codable where T: Sendable {
    /// Array of items in this page.
    public let items: [T]
    /// Total number of items available.
    public let total: Int

    public init(items: [T], total: Int? = nil) {
        self.items = items
        self.total = total ?? items.count
    }
}

// MARK: - Project Requests

/// Request payload for creating a new project in ILS.
public struct CreateProjectRequest: Codable, Sendable {
    /// Display name for the project.
    public let name: String
    /// Absolute filesystem path to the project's root directory.
    public let path: String
    /// Default Claude model to use for sessions in this project (e.g., `"sonnet"`, `"opus"`).
    public let defaultModel: String?
    /// Optional human-readable description of the project.
    public let description: String?

    /// Creates a new project request.
    /// - Parameters:
    ///   - name: Display name for the project.
    ///   - path: Absolute filesystem path to the project's root directory.
    ///   - defaultModel: Default Claude model for sessions in this project.
    ///   - description: Optional human-readable description of the project.
    public init(name: String, path: String, defaultModel: String? = nil, description: String? = nil) {
        self.name = name
        self.path = path
        self.defaultModel = defaultModel
        self.description = description
    }
}

/// Request payload for updating an existing project's metadata.
///
/// All fields are optional; only non-nil values are applied.
public struct UpdateProjectRequest: Codable, Sendable {
    /// New display name for the project, or `nil` to leave unchanged.
    public let name: String?
    /// New default Claude model for sessions, or `nil` to leave unchanged.
    public let defaultModel: String?
    /// New human-readable description, or `nil` to leave unchanged.
    public let description: String?

    /// Creates an update project request.
    /// - Parameters:
    ///   - name: New display name for the project.
    ///   - defaultModel: New default Claude model for sessions.
    ///   - description: New human-readable description of the project.
    public init(name: String? = nil, defaultModel: String? = nil, description: String? = nil) {
        self.name = name
        self.defaultModel = defaultModel
        self.description = description
    }
}

/// Request to bulk-delete projects by ID.
public struct BulkDeleteProjectsRequest: Codable, Sendable {
    /// Array of project UUIDs to delete.
    public let ids: [UUID]

    public init(ids: [UUID]) {
        self.ids = ids
    }
}

// MARK: - Session Requests

/// Request to create a new Claude Code session.
public struct CreateSessionRequest: Codable, Sendable {
    /// Optional project to associate with this session.
    public let projectId: UUID?
    /// Optional name for the session.
    public let name: String?
    /// Model to use (e.g., "sonnet", "opus", "haiku"). Defaults to "sonnet".
    public let model: String?
    /// Permission mode for tool execution.
    public let permissionMode: PermissionMode?
    /// Custom system prompt.
    public let systemPrompt: String?
    /// Maximum cost in USD before stopping.
    public let maxBudgetUSD: Double?
    /// Maximum conversation turns before stopping.
    public let maxTurns: Int?

    public init(
        projectId: UUID? = nil,
        name: String? = nil,
        model: String? = nil,
        permissionMode: PermissionMode? = nil,
        systemPrompt: String? = nil,
        maxBudgetUSD: Double? = nil,
        maxTurns: Int? = nil
    ) {
        self.projectId = projectId
        self.name = name
        self.model = model
        self.permissionMode = permissionMode
        self.systemPrompt = systemPrompt
        self.maxBudgetUSD = maxBudgetUSD
        self.maxTurns = maxTurns
    }
}

/// Response from a filesystem scan for external Claude Code sessions.
public struct SessionScanResponse: Codable, Sendable {
    /// External sessions discovered during the scan.
    public let items: [ExternalSession]
    /// Filesystem paths that were scanned during the operation.
    public let scannedPaths: [String]
    /// Total number of sessions discovered across all scanned paths.
    public let total: Int

    /// Creates a session scan response.
    /// - Parameters:
    ///   - items: External sessions discovered during the scan.
    ///   - scannedPaths: Filesystem paths that were scanned.
    ///   - total: Total session count; defaults to the number of items.
    public init(items: [ExternalSession], scannedPaths: [String], total: Int? = nil) {
        self.items = items
        self.scannedPaths = scannedPaths
        self.total = total ?? items.count
    }
}

/// Response containing recently active sessions for the dashboard timeline.
public struct RecentSessionsResponse: Codable, Sendable {
    /// Recently active sessions ordered by last activity.
    public let items: [ChatSession]
    /// Total number of recent sessions available.
    public let total: Int

    /// Creates a recent sessions response.
    /// - Parameters:
    ///   - items: Recently active sessions ordered by last activity.
    ///   - total: Total session count; defaults to the number of items.
    public init(items: [ChatSession], total: Int? = nil) {
        self.items = items
        self.total = total ?? items.count
    }
}

// MARK: - Chat Requests

/// Execution backend for Claude queries.
///
/// Controls whether the backend routes through the Python Agent SDK wrapper
/// or directly invokes `claude -p` CLI.
public enum ExecutionBackend: String, Codable, Sendable {
    /// Python Agent SDK — works inside Claude Code sessions, no permission forwarding.
    case sdk
    /// Direct `claude -p` — has permission forwarding + stream events, hangs in CC sessions.
    case cli
    /// Auto-detect: SDK if CLAUDECODE env var present, CLI otherwise.
    case auto
}

/// Request to stream a chat message via Server-Sent Events.
///
/// Sends a prompt to Claude and receives streaming responses via SSE.
public struct ChatStreamRequest: Codable, Sendable {
    /// User message to send to Claude.
    public let prompt: String
    /// Session to continue (creates new session if nil).
    public let sessionId: UUID?
    /// Project context for the session.
    public let projectId: UUID?
    /// Additional chat options.
    public let options: ChatOptions?

    public init(
        prompt: String,
        sessionId: UUID? = nil,
        projectId: UUID? = nil,
        options: ChatOptions? = nil
    ) {
        self.prompt = prompt
        self.sessionId = sessionId
        self.projectId = projectId
        self.options = options
    }
}

/// Advanced options for chat requests.
///
/// Maps to Claude CLI flags and configuration options.
public struct ChatOptions: Codable, Sendable {
    /// Model to use (overrides session default).
    public let model: String?
    /// Permission mode for tool execution.
    public let permissionMode: PermissionMode?
    /// Maximum conversation turns.
    public let maxTurns: Int?
    /// Maximum cost in USD.
    public let maxBudgetUSD: Double?
    /// Whitelist of allowed tools.
    public let allowedTools: [String]?
    /// Blacklist of disallowed tools.
    public let disallowedTools: [String]?
    /// Claude session ID to resume.
    public let resume: String?
    /// Whether to fork the session before continuing.
    public let forkSession: Bool?
    /// Custom system prompt (replaces default).
    public let systemPrompt: String?
    /// System prompt to append to default.
    public let appendSystemPrompt: String?
    /// Additional directories for context.
    public let addDirs: [String]?
    /// Whether to continue previous conversation.
    public let continueConversation: Bool?
    /// Whether to include partial messages.
    public let includePartialMessages: Bool?
    /// Whether to disable session persistence.
    public let noSessionPersistence: Bool?
    /// Input format (e.g., "markdown").
    public let inputFormat: String?
    /// Agent mode to use.
    public let agent: String?
    /// Beta features to enable.
    public let betas: [String]?
    /// Whether to enable debug mode.
    public let debug: Bool?
    /// Execution backend to use (sdk, cli, or auto-detect).
    public let backend: ExecutionBackend?

    public init(
        model: String? = nil,
        permissionMode: PermissionMode? = nil,
        maxTurns: Int? = nil,
        maxBudgetUSD: Double? = nil,
        allowedTools: [String]? = nil,
        disallowedTools: [String]? = nil,
        resume: String? = nil,
        forkSession: Bool? = nil,
        systemPrompt: String? = nil,
        appendSystemPrompt: String? = nil,
        addDirs: [String]? = nil,
        continueConversation: Bool? = nil,
        includePartialMessages: Bool? = nil,
        noSessionPersistence: Bool? = nil,
        inputFormat: String? = nil,
        agent: String? = nil,
        betas: [String]? = nil,
        debug: Bool? = nil,
        backend: ExecutionBackend? = nil
    ) {
        self.model = model
        self.permissionMode = permissionMode
        self.maxTurns = maxTurns
        self.maxBudgetUSD = maxBudgetUSD
        self.allowedTools = allowedTools
        self.disallowedTools = disallowedTools
        self.resume = resume
        self.forkSession = forkSession
        self.systemPrompt = systemPrompt
        self.appendSystemPrompt = appendSystemPrompt
        self.addDirs = addDirs
        self.continueConversation = continueConversation
        self.includePartialMessages = includePartialMessages
        self.noSessionPersistence = noSessionPersistence
        self.inputFormat = inputFormat
        self.agent = agent
        self.betas = betas
        self.debug = debug
        self.backend = backend
    }
}

/// Request to rename a session
public struct RenameSessionRequest: Codable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

/// Request to bulk-delete sessions by ID.
public struct BulkDeleteSessionsRequest: Codable, Sendable {
    /// Array of session UUIDs to delete.
    public let ids: [UUID]

    public init(ids: [UUID]) {
        self.ids = ids
    }
}

// MARK: - Message Search

/// A message search result with session context.
public struct MessageSearchResult: Codable, Identifiable, Sendable {
    /// Message ID.
    public let id: UUID
    /// Session ID the message belongs to.
    public let sessionId: UUID
    /// Session name for display context.
    public let sessionName: String?
    /// Model used in the session.
    public let sessionModel: String?
    /// Message role.
    public let role: MessageRole
    /// Message content (may be a snippet around the match).
    public let content: String
    /// When the message was created.
    public let createdAt: Date
    /// Context snippet highlighting the matched text.
    public let snippet: String?
    /// Name of the project the session belongs to.
    public let projectName: String?
    /// ID of the project the session belongs to.
    public let projectId: UUID?

    public init(
        id: UUID,
        sessionId: UUID,
        sessionName: String?,
        sessionModel: String?,
        role: MessageRole,
        content: String,
        createdAt: Date,
        snippet: String? = nil,
        projectName: String? = nil,
        projectId: UUID? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.sessionModel = sessionModel
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.snippet = snippet
        self.projectName = projectName
        self.projectId = projectId
    }
}

/// Filters for narrowing message search results.
public struct MessageSearchFilters: Codable, Sendable {
    /// Include only messages created on or after this date.
    public let dateFrom: Date?
    /// Include only messages created on or before this date.
    public let dateTo: Date?
    /// Include only messages with this role (e.g., `.user`, `.assistant`).
    public let role: MessageRole?
    /// Restrict search to sessions belonging to this project.
    public let projectId: UUID?
    /// When true, restrict results to messages containing code blocks.
    public let codeOnly: Bool?

    public init(
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        role: MessageRole? = nil,
        projectId: UUID? = nil,
        codeOnly: Bool? = nil
    ) {
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.role = role
        self.projectId = projectId
        self.codeOnly = codeOnly
    }
}

// MARK: - Chat Export

/// Export format for chat sessions.
public enum ExportFormat: String, Codable, Sendable {
    case json
    case markdown
    case text

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized ExportFormat: '\(raw)'. Expected: json, markdown, text"
                )
            )
        }
        self = value
    }
}

/// Structured JSON export of a chat session.
public struct ChatExport: Codable, Sendable {
    /// Session metadata.
    public let session: ChatExportSession
    /// All messages in chronological order.
    public let messages: [ChatExportMessage]
    /// Export timestamp.
    public let exportedAt: Date

    public init(session: ChatExportSession, messages: [ChatExportMessage], exportedAt: Date = Date()) {
        self.session = session
        self.messages = messages
        self.exportedAt = exportedAt
    }
}

/// Session metadata included in a chat export payload.
public struct ChatExportSession: Codable, Sendable {
    /// Unique identifier of the exported session.
    public let id: UUID
    /// Display name of the session, if one was assigned.
    public let name: String?
    /// Claude model used for this session (e.g., `"sonnet"`, `"opus"`).
    public let model: String
    /// Timestamp when the session was created.
    public let createdAt: Date
    /// Timestamp of the most recent activity in the session.
    public let lastActiveAt: Date
    /// Total number of messages in the session.
    public let messageCount: Int
    /// Cumulative cost of all Claude API calls in the session, in USD.
    public let totalCostUSD: Double?
    /// Name of the project this session is associated with, if any.
    public let projectName: String?

    /// Creates a chat export session metadata value.
    /// - Parameters:
    ///   - id: Unique identifier of the exported session.
    ///   - name: Display name of the session.
    ///   - model: Claude model used for this session.
    ///   - createdAt: Timestamp when the session was created.
    ///   - lastActiveAt: Timestamp of the most recent activity.
    ///   - messageCount: Total number of messages in the session.
    ///   - totalCostUSD: Cumulative API cost in USD.
    ///   - projectName: Name of the associated project, if any.
    public init(
        id: UUID,
        name: String?,
        model: String,
        createdAt: Date,
        lastActiveAt: Date,
        messageCount: Int,
        totalCostUSD: Double?,
        projectName: String?
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.messageCount = messageCount
        self.totalCostUSD = totalCostUSD
        self.projectName = projectName
    }
}

/// A single message included in a chat export payload.
public struct ChatExportMessage: Codable, Sendable {
    /// Role of the message author (e.g., user or assistant).
    public let role: MessageRole
    /// Text content of the message.
    public let content: String
    /// Timestamp when the message was created.
    public let createdAt: Date

    /// Creates a chat export message.
    /// - Parameters:
    ///   - role: Role of the message author.
    ///   - content: Text content of the message.
    ///   - createdAt: Timestamp when the message was created.
    public init(role: MessageRole, content: String, createdAt: Date) {
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

/// Permission decision sent by the client in response to a tool-use permission request.
public struct PermissionDecision: Codable, Sendable {
    /// The client's decision — either `"allow"` or `"deny"`.
    public let decision: String
    /// Optional human-readable explanation for the decision.
    public let reason: String?

    /// Creates a permission decision.
    /// - Parameters:
    ///   - decision: The client's decision (`"allow"` or `"deny"`).
    ///   - reason: Optional human-readable explanation for the decision.
    public init(decision: String, reason: String? = nil) {
        self.decision = decision
        self.reason = reason
    }
}

// MARK: - WebSocket Messages

/// Messages that the client sends to the server over a WebSocket connection.
public enum WSClientMessage: Codable, Sendable {
    /// A user prompt to send to Claude.
    case message(prompt: String)
    /// A permission decision responding to a server ``PermissionRequest``.
    case permission(requestId: String, decision: String, reason: String?)
    /// A cancellation request for the current in-progress Claude operation.
    case cancel

    private enum CodingKeys: String, CodingKey {
        case type, prompt, requestId, decision, reason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "message":
            let prompt = try container.decode(String.self, forKey: .prompt)
            self = .message(prompt: prompt)
        case "permission":
            let requestId = try container.decode(String.self, forKey: .requestId)
            let decision = try container.decode(String.self, forKey: .decision)
            let reason = try container.decodeIfPresent(String.self, forKey: .reason)
            self = .permission(requestId: requestId, decision: decision, reason: reason)
        case "cancel":
            self = .cancel
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .message(let prompt):
            try container.encode("message", forKey: .type)
            try container.encode(prompt, forKey: .prompt)
        case .permission(let requestId, let decision, let reason):
            try container.encode("permission", forKey: .type)
            try container.encode(requestId, forKey: .requestId)
            try container.encode(decision, forKey: .decision)
            try container.encodeIfPresent(reason, forKey: .reason)
        case .cancel:
            try container.encode("cancel", forKey: .type)
        }
    }
}

/// Messages that the server sends to the client over a WebSocket connection.
public enum WSServerMessage: Codable, Sendable {
    /// An incremental streaming chunk from Claude's response.
    case stream(StreamMessage)
    /// A tool-use permission request that requires a client decision before Claude can proceed.
    case permission(PermissionRequest)
    /// A fatal error that terminated the current Claude operation.
    case error(StreamError)
    /// Confirmation that the current Claude operation has finished, with a result summary.
    case complete(ResultMessage)

    private enum CodingKeys: String, CodingKey {
        case type, message, request, error, result
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .stream(let message):
            try container.encode("stream", forKey: .type)
            try container.encode(message, forKey: .message)
        case .permission(let request):
            try container.encode("permission", forKey: .type)
            try container.encode(request, forKey: .request)
        case .error(let error):
            try container.encode("error", forKey: .type)
            try container.encode(error, forKey: .error)
        case .complete(let result):
            try container.encode("complete", forKey: .type)
            try container.encode(result, forKey: .result)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "stream":
            let message = try container.decode(StreamMessage.self, forKey: .message)
            self = .stream(message)
        case "permission":
            let request = try container.decode(PermissionRequest.self, forKey: .request)
            self = .permission(request)
        case "error":
            let error = try container.decode(StreamError.self, forKey: .error)
            self = .error(error)
        case "complete":
            let result = try container.decode(ResultMessage.self, forKey: .result)
            self = .complete(result)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
        }
    }
}

// MARK: - Skill Requests

/// Request to create a new skill in `~/.claude/skills/`.
public struct CreateSkillRequest: Codable, Sendable {
    /// Skill name (used as filename).
    public let name: String
    /// Optional description (added to frontmatter).
    public let description: String?
    /// Markdown content of the skill.
    public let content: String

    public init(name: String, description: String? = nil, content: String) {
        self.name = name
        self.description = description
        self.content = content
    }
}

/// Request to update an existing skill's content.
public struct UpdateSkillRequest: Codable, Sendable {
    /// New markdown content for the skill.
    public let content: String

    public init(content: String) {
        self.content = content
    }
}

// MARK: - MCP Requests

/// Request to create or update an MCP server configuration.
public struct CreateMCPRequest: Codable, Sendable {
    /// Server name (unique identifier).
    public let name: String
    /// Executable command to start the server (e.g., "npx", "python3").
    public let command: String
    /// Command-line arguments.
    public let args: [String]?
    /// Environment variables.
    public let env: [String: String]?
    /// Configuration scope (user, project, or local).
    public let scope: MCPScope?

    public init(
        name: String,
        command: String,
        args: [String]? = nil,
        env: [String: String]? = nil,
        scope: MCPScope? = nil
    ) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.scope = scope
    }
}

// MARK: - Plugin Requests

/// Request to install a plugin from a GitHub marketplace.
public struct InstallPluginRequest: Codable, Sendable {
    /// Plugin name (repository name).
    public let pluginName: String
    /// Marketplace identifier (GitHub owner/repo format).
    public let marketplace: String

    public init(pluginName: String, marketplace: String) {
        self.pluginName = pluginName
        self.marketplace = marketplace
    }
}

// MARK: - Theme Requests

/// Request payload for creating a new custom UI theme.
public struct CreateCustomThemeRequest: Codable, Sendable {
    /// Unique display name for the theme.
    public let name: String
    /// Optional human-readable description of the theme.
    public let description: String?
    /// Optional author or creator of the theme.
    public let author: String?
    /// Optional semantic version string for the theme (e.g., `"1.0.0"`).
    public let version: String?
    /// Color design tokens for the theme.
    public let colors: ColorTokens?
    /// Typography design tokens for the theme.
    public let typography: TypographyTokens?
    /// Spacing design tokens for the theme.
    public let spacing: SpacingTokens?
    /// Corner radius design tokens for the theme.
    public let cornerRadius: CornerRadiusTokens?
    /// Shadow design tokens for the theme.
    public let shadows: ShadowTokens?
    /// Mesh gradient configuration for the theme's background.
    public let meshGradient: MeshGradientConfig?

    /// Creates a new custom theme request.
    /// - Parameters:
    ///   - name: Unique display name for the theme.
    ///   - description: Optional human-readable description of the theme.
    ///   - author: Optional author or creator of the theme.
    ///   - version: Optional semantic version string for the theme.
    ///   - colors: Color design tokens.
    ///   - typography: Typography design tokens.
    ///   - spacing: Spacing design tokens.
    ///   - cornerRadius: Corner radius design tokens.
    ///   - shadows: Shadow design tokens.
    ///   - meshGradient: Mesh gradient configuration for the background.
    public init(
        name: String,
        description: String? = nil,
        author: String? = nil,
        version: String? = nil,
        colors: ColorTokens? = nil,
        typography: TypographyTokens? = nil,
        spacing: SpacingTokens? = nil,
        cornerRadius: CornerRadiusTokens? = nil,
        shadows: ShadowTokens? = nil,
        meshGradient: MeshGradientConfig? = nil
    ) {
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.colors = colors
        self.typography = typography
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.shadows = shadows
        self.meshGradient = meshGradient
    }
}

/// Request payload for updating an existing custom UI theme.
///
/// All fields are optional; only non-nil values are applied to the existing theme.
public struct UpdateCustomThemeRequest: Codable, Sendable {
    /// New display name for the theme, or `nil` to leave unchanged.
    public let name: String?
    /// New human-readable description, or `nil` to leave unchanged.
    public let description: String?
    /// New author attribution, or `nil` to leave unchanged.
    public let author: String?
    /// New semantic version string, or `nil` to leave unchanged.
    public let version: String?
    /// Updated color design tokens, or `nil` to leave unchanged.
    public let colors: ColorTokens?
    /// Updated typography design tokens, or `nil` to leave unchanged.
    public let typography: TypographyTokens?
    /// Updated spacing design tokens, or `nil` to leave unchanged.
    public let spacing: SpacingTokens?
    /// Updated corner radius design tokens, or `nil` to leave unchanged.
    public let cornerRadius: CornerRadiusTokens?
    /// Updated shadow design tokens, or `nil` to leave unchanged.
    public let shadows: ShadowTokens?
    /// Updated mesh gradient configuration, or `nil` to leave unchanged.
    public let meshGradient: MeshGradientConfig?

    /// Creates an update custom theme request.
    /// - Parameters:
    ///   - name: New display name for the theme.
    ///   - description: New human-readable description of the theme.
    ///   - author: New author attribution.
    ///   - version: New semantic version string.
    ///   - colors: Updated color design tokens.
    ///   - typography: Updated typography design tokens.
    ///   - spacing: Updated spacing design tokens.
    ///   - cornerRadius: Updated corner radius design tokens.
    ///   - shadows: Updated shadow design tokens.
    ///   - meshGradient: Updated mesh gradient configuration for the background.
    public init(
        name: String? = nil,
        description: String? = nil,
        author: String? = nil,
        version: String? = nil,
        colors: ColorTokens? = nil,
        typography: TypographyTokens? = nil,
        spacing: SpacingTokens? = nil,
        cornerRadius: CornerRadiusTokens? = nil,
        shadows: ShadowTokens? = nil,
        meshGradient: MeshGradientConfig? = nil
    ) {
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.colors = colors
        self.typography = typography
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.shadows = shadows
        self.meshGradient = meshGradient
    }
}

// MARK: - Suggestion Requests

/// Feedback event recording user interaction with a suggestion.
public struct SuggestionFeedbackRequest: Codable, Sendable {
    /// Session context in which the suggestion was shown (optional).
    public let sessionId: UUID?
    /// User action taken (e.g., "click", "dismiss", "view").
    public let action: String
    /// Type of suggestion (e.g., "session", "skill").
    public let suggestionType: String
    /// Identifier of the suggested resource.
    public let targetId: String

    public init(
        sessionId: UUID? = nil,
        action: String,
        suggestionType: String,
        targetId: String
    ) {
        self.sessionId = sessionId
        self.action = action
        self.suggestionType = suggestionType
        self.targetId = targetId
    }
}

