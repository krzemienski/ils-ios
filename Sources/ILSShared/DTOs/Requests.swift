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

    public init(
        projectId: UUID? = nil,
        name: String? = nil,
        model: String? = nil,
        permissionMode: PermissionMode? = nil
    ) {
        self.projectId = projectId
        self.name = name
        self.model = model
        self.permissionMode = permissionMode
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

    public init(
        model: String? = nil,
        permissionMode: PermissionMode? = nil,
        maxTurns: Int? = nil,
        maxBudgetUSD: Double? = nil,
        allowedTools: [String]? = nil,
        disallowedTools: [String]? = nil,
        resume: String? = nil,
        forkSession: Bool? = nil
    ) {
        self.model = model
        self.permissionMode = permissionMode
        self.maxTurns = maxTurns
        self.maxBudgetUSD = maxBudgetUSD
        self.allowedTools = allowedTools
        self.disallowedTools = disallowedTools
        self.resume = resume
        self.forkSession = forkSession
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

// MARK: - Config Requests

public struct UpdateConfigRequest: Codable, Sendable {
    public let scope: String
    public let content: ClaudeConfig

    public init(scope: String, content: ClaudeConfig) {
        self.scope = scope
        self.content = content
    }
}

public struct ValidateConfigRequest: Codable, Sendable {
    public let content: ClaudeConfig

    public init(content: ClaudeConfig) {
        self.content = content
    }
}

public struct ConfigValidationResult: Codable, Sendable {
    public let isValid: Bool
    public let errors: [String]

    public init(isValid: Bool, errors: [String] = []) {
        self.isValid = isValid
        self.errors = errors
    }
}

// MARK: - Stats Response

public struct StatsResponse: Codable, Sendable {
    public let projects: CountStat
    public let sessions: SessionStat
    public let skills: CountStat
    public let mcpServers: MCPStat
    public let plugins: PluginStat

    public init(
        projects: CountStat,
        sessions: SessionStat,
        skills: CountStat,
        mcpServers: MCPStat,
        plugins: PluginStat
    ) {
        self.projects = projects
        self.sessions = sessions
        self.skills = skills
        self.mcpServers = mcpServers
        self.plugins = plugins
    }
}

public struct CountStat: Codable, Sendable {
    public let total: Int
    public let active: Int?

    public init(total: Int, active: Int? = nil) {
        self.total = total
        self.active = active
    }
}

public struct SessionStat: Codable, Sendable {
    public let total: Int
    public let active: Int

    public init(total: Int, active: Int) {
        self.total = total
        self.active = active
    }
}

public struct MCPStat: Codable, Sendable {
    public let total: Int
    public let healthy: Int

    public init(total: Int, healthy: Int) {
        self.total = total
        self.healthy = healthy
    }
}

public struct PluginStat: Codable, Sendable {
    public let total: Int
    public let enabled: Int

    public init(total: Int, enabled: Int) {
        self.total = total
        self.enabled = enabled
    }
}

// MARK: - Simple Responses

public struct DeletedResponse: Codable, Sendable {
    public let deleted: Bool

    public init(deleted: Bool = true) {
        self.deleted = deleted
    }
}

public struct AcknowledgedResponse: Codable, Sendable {
    public let acknowledged: Bool

    public init(acknowledged: Bool = true) {
        self.acknowledged = acknowledged
    }
}

public struct CancelledResponse: Codable, Sendable {
    public let cancelled: Bool

    public init(cancelled: Bool = true) {
        self.cancelled = cancelled
    }
}

public struct EnabledResponse: Codable, Sendable {
    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }
}

// MARK: - Analytics Requests

public struct CreateAnalyticsEventRequest: Codable, Sendable {
    public let eventName: String
    public let eventData: String
    public let deviceId: String?
    public let userId: UUID?
    public let sessionId: UUID?

    public init(
        eventName: String,
        eventData: String,
        deviceId: String? = nil,
        userId: UUID? = nil,
        sessionId: UUID? = nil
    ) {
        self.eventName = eventName
        self.eventData = eventData
        self.deviceId = deviceId
        self.userId = userId
        self.sessionId = sessionId
    }
}

public struct CreatedResponse: Codable, Sendable {
    public let id: UUID
    public let createdAt: Date

    public init(id: UUID, createdAt: Date) {
        self.id = id
        self.createdAt = createdAt
    }
}
