// Sources/ILSShared/Models/CLIMessage.swift

import Foundation

/// Raw CLI NDJSON envelope. Decoded directly from Claude CLI stdout.
/// Uses snake_case keys matching CLI output.
public enum CLIMessage: Codable, Sendable {
    case system(CLISystemMessage)
    case assistant(CLIAssistantMessage)
    case user(CLIUserMessage)
    case result(CLIResultMessage)
    case streamEvent(CLIStreamEvent)
    case permission(CLIPermissionMessage)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "system":
            self = .system(try CLISystemMessage(from: decoder))
        case "assistant":
            self = .assistant(try CLIAssistantMessage(from: decoder))
        case "user":
            self = .user(try CLIUserMessage(from: decoder))
        case "result":
            self = .result(try CLIResultMessage(from: decoder))
        case "stream_event":
            self = .streamEvent(try CLIStreamEvent(from: decoder))
        case "permission":
            self = .permission(try CLIPermissionMessage(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown CLI message type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .system(let m): try m.encode(to: encoder)
        case .assistant(let m): try m.encode(to: encoder)
        case .user(let m): try m.encode(to: encoder)
        case .result(let m): try m.encode(to: encoder)
        case .streamEvent(let m): try m.encode(to: encoder)
        case .permission(let m): try m.encode(to: encoder)
        }
    }
}

// MARK: - System

public struct CLISystemMessage: Codable, Sendable {
    public let type: String           // "system"
    public let subtype: String        // "init"
    public let uuid: String?
    public let sessionId: String      // snake_case decoded via strategy
    public let cwd: String?
    public let model: String?
    public let tools: [String]?
    public let mcpServers: [CLIMCPServer]?
    public let permissionMode: String?
    public let apiKeySource: String?
    public let slashCommands: [String]?
    public let agents: [String]?
    public let claudeCodeVersion: String?

    public init(
        type: String = "system",
        subtype: String = "init",
        uuid: String? = nil,
        sessionId: String,
        cwd: String? = nil,
        model: String? = nil,
        tools: [String]? = nil,
        mcpServers: [CLIMCPServer]? = nil,
        permissionMode: String? = nil,
        apiKeySource: String? = nil,
        slashCommands: [String]? = nil,
        agents: [String]? = nil,
        claudeCodeVersion: String? = nil
    ) {
        self.type = type
        self.subtype = subtype
        self.uuid = uuid
        self.sessionId = sessionId
        self.cwd = cwd
        self.model = model
        self.tools = tools
        self.mcpServers = mcpServers
        self.permissionMode = permissionMode
        self.apiKeySource = apiKeySource
        self.slashCommands = slashCommands
        self.agents = agents
        self.claudeCodeVersion = claudeCodeVersion
    }
}

public struct CLIMCPServer: Codable, Sendable {
    public let name: String
    public let status: String?

    public init(name: String, status: String? = nil) {
        self.name = name
        self.status = status
    }
}

// MARK: - Assistant

public struct CLIAssistantMessage: Codable, Sendable {
    public let type: String           // "assistant"
    public let uuid: String?
    public let sessionId: String?
    public let parentToolUseId: String?
    public let message: CLIAssistantPayload

    public init(
        type: String = "assistant",
        uuid: String? = nil,
        sessionId: String? = nil,
        parentToolUseId: String? = nil,
        message: CLIAssistantPayload
    ) {
        self.type = type
        self.uuid = uuid
        self.sessionId = sessionId
        self.parentToolUseId = parentToolUseId
        self.message = message
    }
}

public struct CLIAssistantPayload: Codable, Sendable {
    public let model: String?
    public let id: String?
    public let role: String?
    public let content: [CLIContentBlock]
    public let stopReason: String?
    public let usage: CLIUsage?

    public init(
        model: String? = nil,
        id: String? = nil,
        role: String? = nil,
        content: [CLIContentBlock] = [],
        stopReason: String? = nil,
        usage: CLIUsage? = nil
    ) {
        self.model = model
        self.id = id
        self.role = role
        self.content = content
        self.stopReason = stopReason
        self.usage = usage
    }
}

// MARK: - User (tool results)

public struct CLIUserMessage: Codable, Sendable {
    public let type: String           // "user"
    public let uuid: String?
    public let sessionId: String?
    public let parentToolUseId: String?
    public let message: CLIUserPayload
    public let toolUseResult: CLIToolUseResultMeta?

    public init(
        type: String = "user",
        uuid: String? = nil,
        sessionId: String? = nil,
        parentToolUseId: String? = nil,
        message: CLIUserPayload,
        toolUseResult: CLIToolUseResultMeta? = nil
    ) {
        self.type = type
        self.uuid = uuid
        self.sessionId = sessionId
        self.parentToolUseId = parentToolUseId
        self.message = message
        self.toolUseResult = toolUseResult
    }
}

public struct CLIUserPayload: Codable, Sendable {
    public let role: String?
    public let content: [CLIContentBlock]

    public init(role: String? = nil, content: [CLIContentBlock] = []) {
        self.role = role
        self.content = content
    }
}

public struct CLIToolUseResultMeta: Codable, Sendable {
    public let filenames: [String]?
    public let durationMs: Int?
    public let numFiles: Int?
    public let truncated: Bool?

    public init(
        filenames: [String]? = nil,
        durationMs: Int? = nil,
        numFiles: Int? = nil,
        truncated: Bool? = nil
    ) {
        self.filenames = filenames
        self.durationMs = durationMs
        self.numFiles = numFiles
        self.truncated = truncated
    }
}

// MARK: - Result

public struct CLIResultMessage: Codable, Sendable {
    public let type: String           // "result"
    public let subtype: String        // "success", "error_max_turns", etc.
    public let uuid: String?
    public let sessionId: String?
    public let isError: Bool?
    public let durationMs: Int?
    public let durationApiMs: Int?
    public let numTurns: Int?
    public let result: String?        // final text
    public let totalCostUsd: Double?
    public let usage: CLIUsage?
    public let modelUsage: [String: CLIModelUsageEntry]?
    public let permissionDenials: [AnyCodable]?
    public let errors: [AnyCodable]?

    public init(
        type: String = "result",
        subtype: String = "success",
        uuid: String? = nil,
        sessionId: String? = nil,
        isError: Bool? = nil,
        durationMs: Int? = nil,
        durationApiMs: Int? = nil,
        numTurns: Int? = nil,
        result: String? = nil,
        totalCostUsd: Double? = nil,
        usage: CLIUsage? = nil,
        modelUsage: [String: CLIModelUsageEntry]? = nil,
        permissionDenials: [AnyCodable]? = nil,
        errors: [AnyCodable]? = nil
    ) {
        self.type = type
        self.subtype = subtype
        self.uuid = uuid
        self.sessionId = sessionId
        self.isError = isError
        self.durationMs = durationMs
        self.durationApiMs = durationApiMs
        self.numTurns = numTurns
        self.result = result
        self.totalCostUsd = totalCostUsd
        self.usage = usage
        self.modelUsage = modelUsage
        self.permissionDenials = permissionDenials
        self.errors = errors
    }
}

public struct CLIModelUsageEntry: Codable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let cacheCreationInputTokens: Int?
    public let costUSD: Double?       // note: uppercase USD in CLI
    public let contextWindow: Int?
    public let maxOutputTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case inputTokens, outputTokens, cacheReadInputTokens
        case cacheCreationInputTokens, costUSD, contextWindow, maxOutputTokens
    }

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil,
        costUSD: Double? = nil,
        contextWindow: Int? = nil,
        maxOutputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.costUSD = costUSD
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
    }
}

// MARK: - Stream Event

public struct CLIStreamEvent: Codable, Sendable {
    public let type: String           // "stream_event"
    public let uuid: String?
    public let sessionId: String?
    public let parentToolUseId: String?
    public let event: CLIRawEvent

    public init(
        type: String = "stream_event",
        uuid: String? = nil,
        sessionId: String? = nil,
        parentToolUseId: String? = nil,
        event: CLIRawEvent
    ) {
        self.type = type
        self.uuid = uuid
        self.sessionId = sessionId
        self.parentToolUseId = parentToolUseId
        self.event = event
    }
}

public struct CLIRawEvent: Codable, Sendable {
    public let type: String           // message_start, content_block_delta, etc.
    public let index: Int?
    public let delta: CLIDelta?
    public let contentBlock: CLIContentBlockStart?
    public let message: AnyCodable?   // for message_start
    public let usage: CLIUsage?       // for message_delta

    public init(
        type: String,
        index: Int? = nil,
        delta: CLIDelta? = nil,
        contentBlock: CLIContentBlockStart? = nil,
        message: AnyCodable? = nil,
        usage: CLIUsage? = nil
    ) {
        self.type = type
        self.index = index
        self.delta = delta
        self.contentBlock = contentBlock
        self.message = message
        self.usage = usage
    }
}

public enum CLIDelta: Codable, Sendable {
    case textDelta(String)
    case inputJsonDelta(String)
    case thinkingDelta(String)
    case unknown(String)

    private enum CodingKeys: String, CodingKey {
        case type, text, partialJson, thinking
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text_delta":
            let text = try container.decode(String.self, forKey: .text)
            self = .textDelta(text)
        case "input_json_delta":
            let json = try container.decode(String.self, forKey: .partialJson)
            self = .inputJsonDelta(json)
        case "thinking_delta":
            let thinking = try container.decode(String.self, forKey: .thinking)
            self = .thinkingDelta(thinking)
        default:
            self = .unknown(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .textDelta(let text):
            try container.encode("text_delta", forKey: .type)
            try container.encode(text, forKey: .text)
        case .inputJsonDelta(let json):
            try container.encode("input_json_delta", forKey: .type)
            try container.encode(json, forKey: .partialJson)
        case .thinkingDelta(let thinking):
            try container.encode("thinking_delta", forKey: .type)
            try container.encode(thinking, forKey: .thinking)
        case .unknown(let type):
            try container.encode(type, forKey: .type)
        }
    }
}

public struct CLIContentBlockStart: Codable, Sendable {
    public let type: String           // "text", "tool_use", "thinking"
    public let id: String?
    public let name: String?

    public init(type: String, id: String? = nil, name: String? = nil) {
        self.type = type
        self.id = id
        self.name = name
    }
}

// MARK: - Permission

/// Permission request from Claude CLI when a tool needs user approval.
public struct CLIPermissionMessage: Codable, Sendable {
    public let type: String           // "permission"
    public let toolName: String
    public let toolInput: AnyCodable?
    public let description: String?
    public let sessionId: String?
    public let requestId: String?

    public init(
        type: String = "permission",
        toolName: String,
        toolInput: AnyCodable? = nil,
        description: String? = nil,
        sessionId: String? = nil,
        requestId: String? = nil
    ) {
        self.type = type
        self.toolName = toolName
        self.toolInput = toolInput
        self.description = description
        self.sessionId = sessionId
        self.requestId = requestId
    }
}

// MARK: - Shared Sub-Types

public struct CLIContentBlock: Codable, Sendable {
    public let type: String
    // text
    public let text: String?
    // tool_use
    public let id: String?
    public let name: String?
    public let input: AnyCodable?
    // tool_result
    public let toolUseId: String?
    public let content: AnyCodable?   // String or [{"type":"text","text":"..."}]
    public let isError: Bool?
    // thinking
    public let thinking: String?

    public init(
        type: String,
        text: String? = nil,
        id: String? = nil,
        name: String? = nil,
        input: AnyCodable? = nil,
        toolUseId: String? = nil,
        content: AnyCodable? = nil,
        isError: Bool? = nil,
        thinking: String? = nil
    ) {
        self.type = type
        self.text = text
        self.id = id
        self.name = name
        self.input = input
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
        self.thinking = thinking
    }
}

public struct CLIUsage: Codable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let cacheCreationInputTokens: Int?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
    }
}
