import Foundation

// MARK: - API Response Wrapper

/// Standard API response wrapper with success/error handling.
public struct APIResponse<T: Codable>: Codable where T: Sendable {
    /// Whether the request was successful.
    public let success: Bool
    /// Response data (present on success).
    public let data: T?
    /// Error details (present on failure).
    public let error: APIError?

    public init(success: Bool, data: T? = nil, error: APIError? = nil) {
        self.success = success
        self.data = data
        self.error = error
    }
}

/// API error details.
public struct APIError: Codable, Sendable {
    /// Error code.
    public let code: String
    /// Human-readable error message.
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

/// List response with items and total count.
public struct ListResponse<T: Codable>: Codable where T: Sendable {
    /// Array of items.
    public let items: [T]
    /// Total count of items.
    public let total: Int

    public init(items: [T], total: Int? = nil) {
        self.items = items
        self.total = total ?? items.count
    }
}

// MARK: - Project Requests

/// Request to create a new project.
public struct CreateProjectRequest: Codable, Sendable {
    /// Project name.
    public let name: String
    /// Filesystem path to the project directory.
    public let path: String
    /// Default model for new sessions.
    public let defaultModel: String?
    /// Optional project description.
    public let description: String?

    public init(name: String, path: String, defaultModel: String? = nil, description: String? = nil) {
        self.name = name
        self.path = path
        self.defaultModel = defaultModel
        self.description = description
    }
}

/// Request to update an existing project.
public struct UpdateProjectRequest: Codable, Sendable {
    /// New project name.
    public let name: String?
    /// New default model.
    public let defaultModel: String?
    /// New description.
    public let description: String?

    public init(name: String? = nil, defaultModel: String? = nil, description: String? = nil) {
        self.name = name
        self.defaultModel = defaultModel
        self.description = description
    }
}

// MARK: - Session Requests

/// Request to create a new chat session.
public struct CreateSessionRequest: Codable, Sendable {
    /// Associated project ID.
    public let projectId: UUID?
    /// Session name.
    public let name: String?
    /// Claude model to use.
    public let model: String?
    /// Permission mode for the session.
    public let permissionMode: PermissionMode?
    /// Custom system prompt.
    public let systemPrompt: String?
    /// Maximum budget in USD.
    public let maxBudgetUSD: Double?
    /// Maximum conversation turns.
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

/// Request to rename a session.
public struct RenameSessionRequest: Codable, Sendable {
    /// New session name.
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

/// Response from scanning Claude Code storage for sessions.
public struct SessionScanResponse: Codable, Sendable {
    /// Discovered external sessions.
    public let items: [ExternalSession]
    /// Filesystem paths that were scanned.
    public let scannedPaths: [String]
    /// Total count of sessions found.
    public let total: Int

    public init(items: [ExternalSession], scannedPaths: [String], total: Int? = nil) {
        self.items = items
        self.scannedPaths = scannedPaths
        self.total = total ?? items.count
    }
}

/// Response for recent sessions (used in dashboard timeline).
public struct RecentSessionsResponse: Codable, Sendable {
    /// Recent chat sessions.
    public let items: [ChatSession]
    /// Total count.
    public let total: Int

    public init(items: [ChatSession], total: Int? = nil) {
        self.items = items
        self.total = total ?? items.count
    }
}

// MARK: - Chat Requests

/// Request to start a chat stream.
public struct ChatStreamRequest: Codable, Sendable {
    /// User prompt text.
    public let prompt: String
    /// Existing session ID to continue.
    public let sessionId: UUID?
    /// Project ID for context.
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

/// Chat configuration options (mirrors Claude Code CLI flags).
public struct ChatOptions: Codable, Sendable {
    // Core options
    /// Claude model to use.
    public let model: String?
    /// Permission mode for tool execution.
    public let permissionMode: PermissionMode?
    /// Maximum conversation turns.
    public let maxTurns: Int?
    /// Maximum budget in USD.
    public let maxBudgetUSD: Double?
    /// Tools that are allowed.
    public let allowedTools: [String]?
    /// Tools that are disallowed.
    public let disallowedTools: [String]?
    /// Session ID to resume.
    public let resume: String?
    /// Whether to fork an existing session.
    public let forkSession: Bool?

    // Claude Code CLI parity fields
    /// Custom system prompt.
    public let systemPrompt: String?
    /// Append to existing system prompt.
    public let appendSystemPrompt: String?
    /// Additional directories to include.
    public let addDirs: [String]?
    /// Continue previous conversation.
    public let continueConversation: Bool?
    /// Include partial messages in context.
    public let includePartialMessages: Bool?
    /// Fallback model if primary fails.
    public let fallbackModel: String?
    /// JSON schema for structured output.
    public let jsonSchema: String?
    /// MCP configuration path.
    public let mcpConfig: String?
    /// Custom agents configuration path.
    public let customAgents: String?
    /// Explicit session ID.
    public let sessionId: String?
    /// Specific tools to enable.
    public let tools: [String]?
    /// Disable session persistence.
    public let noSessionPersistence: Bool?
    /// Input format (e.g., "markdown", "plain").
    public let inputFormat: String?
    /// Agent mode identifier.
    public let agent: String?
    /// Beta feature flags.
    public let betas: [String]?
    /// Enable debug mode.
    public let debug: Bool?
    /// Path for debug output.
    public let debugFile: String?
    /// Disable slash commands.
    public let disableSlashCommands: Bool?
    /// Path to system prompt file.
    public let systemPromptFile: String?
    /// Path to append system prompt file.
    public let appendSystemPromptFile: String?
    /// Custom plugin directory.
    public let pluginDir: String?
    /// Strict MCP config validation.
    public let strictMcpConfig: Bool?
    /// Custom settings path.
    public let settingsPath: String?

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
        fallbackModel: String? = nil,
        jsonSchema: String? = nil,
        mcpConfig: String? = nil,
        customAgents: String? = nil,
        sessionId: String? = nil,
        tools: [String]? = nil,
        noSessionPersistence: Bool? = nil,
        inputFormat: String? = nil,
        agent: String? = nil,
        betas: [String]? = nil,
        debug: Bool? = nil,
        debugFile: String? = nil,
        disableSlashCommands: Bool? = nil,
        systemPromptFile: String? = nil,
        appendSystemPromptFile: String? = nil,
        pluginDir: String? = nil,
        strictMcpConfig: Bool? = nil,
        settingsPath: String? = nil
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
        self.fallbackModel = fallbackModel
        self.jsonSchema = jsonSchema
        self.mcpConfig = mcpConfig
        self.customAgents = customAgents
        self.sessionId = sessionId
        self.tools = tools
        self.noSessionPersistence = noSessionPersistence
        self.inputFormat = inputFormat
        self.agent = agent
        self.betas = betas
        self.debug = debug
        self.debugFile = debugFile
        self.disableSlashCommands = disableSlashCommands
        self.systemPromptFile = systemPromptFile
        self.appendSystemPromptFile = appendSystemPromptFile
        self.pluginDir = pluginDir
        self.strictMcpConfig = strictMcpConfig
        self.settingsPath = settingsPath
    }
}

/// Permission decision from client in response to a permission request.
public struct PermissionDecision: Codable, Sendable {
    /// Decision ("allow" or "deny").
    public let decision: String
    /// Optional reason for the decision.
    public let reason: String?

    public init(decision: String, reason: String? = nil) {
        self.decision = decision
        self.reason = reason
    }
}

// MARK: - WebSocket Messages

/// Client-to-server WebSocket message.
public enum WSClientMessage: Codable, Sendable {
    /// Send a chat message.
    case message(prompt: String)
    /// Respond to a permission request.
    case permission(requestId: String, decision: String, reason: String?)
    /// Cancel the current operation.
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

/// Server-to-client WebSocket message.
public enum WSServerMessage: Codable, Sendable {
    /// Streaming content from Claude.
    case stream(StreamMessage)
    /// Permission request requiring user decision.
    case permission(PermissionRequest)
    /// Error occurred during execution.
    case error(StreamError)
    /// Conversation turn completed.
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

/// Request to create a new skill.
public struct CreateSkillRequest: Codable, Sendable {
    /// Skill name.
    public let name: String
    /// Optional description.
    public let description: String?
    /// Skill content (markdown).
    public let content: String

    public init(name: String, description: String? = nil, content: String) {
        self.name = name
        self.description = description
        self.content = content
    }
}

/// Request to update an existing skill.
public struct UpdateSkillRequest: Codable, Sendable {
    /// New skill content.
    public let content: String

    public init(content: String) {
        self.content = content
    }
}

// MARK: - MCP Requests

/// Request to create a new MCP server configuration.
public struct CreateMCPRequest: Codable, Sendable {
    /// MCP server name.
    public let name: String
    /// Command to execute.
    public let command: String
    /// Command arguments.
    public let args: [String]?
    /// Environment variables.
    public let env: [String: String]?
    /// Configuration scope.
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

/// Request to install a plugin from a marketplace.
public struct InstallPluginRequest: Codable, Sendable {
    /// Name of the plugin to install.
    public let pluginName: String
    /// Marketplace source.
    public let marketplace: String
    /// Installation scope.
    public let scope: String?

    public init(pluginName: String, marketplace: String, scope: String? = nil) {
        self.pluginName = pluginName
        self.marketplace = marketplace
        self.scope = scope
    }
}


