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

public struct CreateProjectRequest: Codable, Sendable {
    public let name: String
    public let path: String
    public let defaultModel: String?
    public let description: String?

    public init(name: String, path: String, defaultModel: String? = nil, description: String? = nil) {
        self.name = name
        self.path = path
        self.defaultModel = defaultModel
        self.description = description
    }
}

public struct UpdateProjectRequest: Codable, Sendable {
    public let name: String?
    public let defaultModel: String?
    public let description: String?

    public init(name: String? = nil, defaultModel: String? = nil, description: String? = nil) {
        self.name = name
        self.defaultModel = defaultModel
        self.description = description
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

/// Response from session scan
public struct SessionScanResponse: Codable, Sendable {
    public let items: [ExternalSession]
    public let scannedPaths: [String]
    public let total: Int

    public init(items: [ExternalSession], scannedPaths: [String], total: Int? = nil) {
        self.items = items
        self.scannedPaths = scannedPaths
        self.total = total ?? items.count
    }
}

/// Response for recent sessions (for dashboard timeline)
public struct RecentSessionsResponse: Codable, Sendable {
    public let items: [ChatSession]
    public let total: Int

    public init(items: [ChatSession], total: Int? = nil) {
        self.items = items
        self.total = total ?? items.count
    }
}

// MARK: - Chat Requests

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
        debug: Bool? = nil
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
    }
}

/// Request to rename a session
public struct RenameSessionRequest: Codable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

/// Permission decision from client
public struct PermissionDecision: Codable, Sendable {
    public let decision: String // "allow" or "deny"
    public let reason: String?

    public init(decision: String, reason: String? = nil) {
        self.decision = decision
        self.reason = reason
    }
}

// MARK: - WebSocket Messages

public enum WSClientMessage: Codable, Sendable {
    case message(prompt: String)
    case permission(requestId: String, decision: String, reason: String?)
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

public enum WSServerMessage: Codable, Sendable {
    case stream(StreamMessage)
    case permission(PermissionRequest)
    case error(StreamError)
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

public struct CreateCustomThemeRequest: Codable, Sendable {
    public let name: String
    public let description: String?
    public let author: String?
    public let version: String?
    public let colors: ColorTokens?
    public let typography: TypographyTokens?
    public let spacing: SpacingTokens?
    public let cornerRadius: CornerRadiusTokens?
    public let shadows: ShadowTokens?

    public init(
        name: String,
        description: String? = nil,
        author: String? = nil,
        version: String? = nil,
        colors: ColorTokens? = nil,
        typography: TypographyTokens? = nil,
        spacing: SpacingTokens? = nil,
        cornerRadius: CornerRadiusTokens? = nil,
        shadows: ShadowTokens? = nil
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
    }
}

public struct UpdateCustomThemeRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let author: String?
    public let version: String?
    public let colors: ColorTokens?
    public let typography: TypographyTokens?
    public let spacing: SpacingTokens?
    public let cornerRadius: CornerRadiusTokens?
    public let shadows: ShadowTokens?

    public init(
        name: String? = nil,
        description: String? = nil,
        author: String? = nil,
        version: String? = nil,
        colors: ColorTokens? = nil,
        typography: TypographyTokens? = nil,
        spacing: SpacingTokens? = nil,
        cornerRadius: CornerRadiusTokens? = nil,
        shadows: ShadowTokens? = nil
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
    }
}

