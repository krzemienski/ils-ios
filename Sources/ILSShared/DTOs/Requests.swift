import Foundation

// MARK: - API Response Wrapper

/// Standard API response wrapper
public struct APIResponse<T: Codable>: Codable where T: Sendable {
    public let success: Bool
    public let data: T?
    public let error: APIError?

    public init(success: Bool, data: T? = nil, error: APIError? = nil) {
        self.success = success
        self.data = data
        self.error = error
    }
}

public struct APIError: Codable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

/// List response with items and total
public struct ListResponse<T: Codable>: Codable where T: Sendable {
    public let items: [T]
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

public struct CreateSessionRequest: Codable, Sendable {
    public let projectId: UUID?
    public let name: String?
    public let model: String?
    public let permissionMode: PermissionMode?
    public let systemPrompt: String?
    public let maxBudgetUSD: Double?
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

public struct ChatStreamRequest: Codable, Sendable {
    public let prompt: String
    public let sessionId: UUID?
    public let projectId: UUID?
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

public struct ChatOptions: Codable, Sendable {
    public let model: String?
    public let permissionMode: PermissionMode?
    public let maxTurns: Int?
    public let maxBudgetUSD: Double?
    public let allowedTools: [String]?
    public let disallowedTools: [String]?
    public let resume: String?
    public let forkSession: Bool?
    public let systemPrompt: String?
    public let appendSystemPrompt: String?
    public let addDirs: [String]?
    public let continueConversation: Bool?
    public let includePartialMessages: Bool?
    public let noSessionPersistence: Bool?
    public let inputFormat: String?
    public let agent: String?
    public let betas: [String]?
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

public struct CreateSkillRequest: Codable, Sendable {
    public let name: String
    public let description: String?
    public let content: String

    public init(name: String, description: String? = nil, content: String) {
        self.name = name
        self.description = description
        self.content = content
    }
}

public struct UpdateSkillRequest: Codable, Sendable {
    public let content: String

    public init(content: String) {
        self.content = content
    }
}

// MARK: - MCP Requests

public struct CreateMCPRequest: Codable, Sendable {
    public let name: String
    public let command: String
    public let args: [String]?
    public let env: [String: String]?
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

public struct InstallPluginRequest: Codable, Sendable {
    public let pluginName: String
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

