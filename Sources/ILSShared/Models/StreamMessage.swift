import Foundation

// MARK: - Main Stream Message Types

/// Top-level streaming message from Claude Code.
public enum StreamMessage: Codable, Sendable {
    /// System initialization or control message.
    case system(SystemMessage)
    /// Assistant response with content blocks.
    case assistant(AssistantMessage)
    /// User message (tool results from agent).
    case user(UserMessage)
    /// Final result message with usage and cost information.
    case result(ResultMessage)
    /// Stream event for character-by-character delivery.
    case streamEvent(StreamEventMessage)
    /// Permission request for tool execution.
    case permission(PermissionRequest)
    /// Error message from the stream.
    case error(StreamError)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "system":
            self = .system(try SystemMessage(from: decoder))
        case "assistant":
            self = .assistant(try AssistantMessage(from: decoder))
        case "user":
            self = .user(try UserMessage(from: decoder))
        case "result":
            self = .result(try ResultMessage(from: decoder))
        case "streamEvent":
            self = .streamEvent(try StreamEventMessage(from: decoder))
        case "permission":
            self = .permission(try PermissionRequest(from: decoder))
        case "error":
            self = .error(try StreamError(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown message type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .system(let msg):
            try msg.encode(to: encoder)
        case .assistant(let msg):
            try msg.encode(to: encoder)
        case .user(let msg):
            try msg.encode(to: encoder)
        case .result(let msg):
            try msg.encode(to: encoder)
        case .streamEvent(let msg):
            try msg.encode(to: encoder)
        case .permission(let msg):
            try msg.encode(to: encoder)
        case .error(let msg):
            try msg.encode(to: encoder)
        }
    }
}

// MARK: - System Message

/// System message containing session initialization data.
public struct SystemMessage: Codable, Sendable {
    /// Message type (always "system").
    public let type: String
    /// Message subtype (e.g., "init").
    public let subtype: String
    /// System data payload.
    public let data: SystemData
    /// Unique message identifier.
    public let uuid: String?

    public init(type: String = "system", subtype: String = "init", data: SystemData, uuid: String? = nil) {
        self.type = type
        self.subtype = subtype
        self.data = data
        self.uuid = uuid
    }
}

/// System initialization data from Claude Code.
public struct SystemData: Codable, Sendable {
    /// Claude session ID.
    public let sessionId: String
    /// Available plugins.
    public let plugins: [String]?
    /// Available slash commands.
    public let slashCommands: [String]?
    /// Available tools.
    public let tools: [String]?
    /// Model used for this session.
    public let model: String?
    /// Current working directory.
    public let cwd: String?

    public init(
        sessionId: String,
        plugins: [String]? = nil,
        slashCommands: [String]? = nil,
        tools: [String]? = nil,
        model: String? = nil,
        cwd: String? = nil
    ) {
        self.sessionId = sessionId
        self.plugins = plugins
        self.slashCommands = slashCommands
        self.tools = tools
        self.model = model
        self.cwd = cwd
    }
}

// MARK: - Assistant Message

/// Assistant response message containing content blocks.
public struct AssistantMessage: Codable, Sendable {
    /// Message type (always "assistant").
    public let type: String
    /// Array of content blocks in the response.
    public let content: [ContentBlock]
    /// Unique message identifier.
    public let uuid: String?
    /// Session ID.
    public let sessionId: String?

    public init(type: String = "assistant", content: [ContentBlock], uuid: String? = nil, sessionId: String? = nil) {
        self.type = type
        self.content = content
        self.uuid = uuid
        self.sessionId = sessionId
    }
}

// MARK: - User Message

/// User message containing tool results from agent.
public struct UserMessage: Codable, Sendable {
    /// Message type (always "user").
    public let type: String
    /// Unique message identifier.
    public let uuid: String?
    /// Session ID.
    public let sessionId: String?
    /// Content blocks.
    public let content: [ContentBlock]
    /// Tool use result metadata.
    public let toolUseResult: ToolUseResultMeta?

    public init(
        type: String = "user",
        uuid: String? = nil,
        sessionId: String? = nil,
        content: [ContentBlock] = [],
        toolUseResult: ToolUseResultMeta? = nil
    ) {
        self.type = type
        self.uuid = uuid
        self.sessionId = sessionId
        self.content = content
        self.toolUseResult = toolUseResult
    }
}

/// Metadata about a tool use result.
public struct ToolUseResultMeta: Codable, Sendable {
    /// Files involved in the tool result.
    public let filenames: [String]?
    /// Duration in milliseconds.
    public let durationMs: Int?
    /// Number of files.
    public let numFiles: Int?
    /// Whether the result was truncated.
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

// MARK: - Stream Event Message

/// Stream event for character-by-character delivery.
public struct StreamEventMessage: Codable, Sendable {
    /// Message type (always "streamEvent").
    public let type: String
    /// Event type (e.g., "content_block_delta", "message_stop").
    public let eventType: String
    /// Content block index.
    public let index: Int?
    /// Delta payload.
    public let delta: StreamDelta?

    public init(
        type: String = "streamEvent",
        eventType: String,
        index: Int? = nil,
        delta: StreamDelta? = nil
    ) {
        self.type = type
        self.eventType = eventType
        self.index = index
        self.delta = delta
    }
}

/// Delta content for streaming events.
public enum StreamDelta: Codable, Sendable {
    case textDelta(String)
    case inputJsonDelta(String)
    case thinkingDelta(String)

    private enum CodingKeys: String, CodingKey {
        case type, text, partialJson, thinking
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text_delta", "textDelta":
            let text = try container.decode(String.self, forKey: .text)
            self = .textDelta(text)
        case "input_json_delta", "inputJsonDelta":
            let json = try container.decode(String.self, forKey: .partialJson)
            self = .inputJsonDelta(json)
        case "thinking_delta", "thinkingDelta":
            let thinking = try container.decode(String.self, forKey: .thinking)
            self = .thinkingDelta(thinking)
        default:
            self = .textDelta("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .textDelta(let text):
            try container.encode("textDelta", forKey: .type)
            try container.encode(text, forKey: .text)
        case .inputJsonDelta(let json):
            try container.encode("inputJsonDelta", forKey: .type)
            try container.encode(json, forKey: .partialJson)
        case .thinkingDelta(let thinking):
            try container.encode("thinkingDelta", forKey: .type)
            try container.encode(thinking, forKey: .thinking)
        }
    }
}

// MARK: - Result Message

/// Final result message with usage and cost information.
public struct ResultMessage: Codable, Sendable {
    /// Message type (always "result").
    public let type: String
    /// Result subtype (e.g., "success", "error").
    public let subtype: String
    /// Session ID.
    public let sessionId: String
    /// Total duration in milliseconds.
    public let durationMs: Int?
    /// API request duration in milliseconds.
    public let durationApiMs: Int?
    /// Whether the result represents an error.
    public let isError: Bool
    /// Number of turns in the conversation.
    public let numTurns: Int?
    /// Total cost in USD.
    public let totalCostUSD: Double?
    /// Token usage information.
    public let usage: UsageInfo?
    /// Final result text.
    public let result: String?
    /// Per-model usage breakdown.
    public let modelUsage: [String: ModelUsageEntry]?

    public init(
        type: String = "result",
        subtype: String = "success",
        sessionId: String,
        durationMs: Int? = nil,
        durationApiMs: Int? = nil,
        isError: Bool = false,
        numTurns: Int? = nil,
        totalCostUSD: Double? = nil,
        usage: UsageInfo? = nil,
        result: String? = nil,
        modelUsage: [String: ModelUsageEntry]? = nil
    ) {
        self.type = type
        self.subtype = subtype
        self.sessionId = sessionId
        self.durationMs = durationMs
        self.durationApiMs = durationApiMs
        self.isError = isError
        self.numTurns = numTurns
        self.totalCostUSD = totalCostUSD
        self.usage = usage
        self.result = result
        self.modelUsage = modelUsage
    }
}

/// Token usage information for a conversation turn.
public struct UsageInfo: Codable, Sendable {
    /// Number of input tokens.
    public let inputTokens: Int
    /// Number of output tokens.
    public let outputTokens: Int
    /// Cache read input tokens (prompt caching).
    public let cacheReadInputTokens: Int?
    /// Cache creation input tokens.
    public let cacheCreationInputTokens: Int?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheReadInputTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
    }
}

/// Per-model usage entry with cost information.
public struct ModelUsageEntry: Codable, Sendable {
    /// Number of input tokens.
    public let inputTokens: Int?
    /// Number of output tokens.
    public let outputTokens: Int?
    /// Cost in USD.
    public let costUSD: Double?
    /// Context window size.
    public let contextWindow: Int?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        costUSD: Double? = nil,
        contextWindow: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costUSD = costUSD
        self.contextWindow = contextWindow
    }
}

// MARK: - Permission Request

/// Permission request for tool execution.
public struct PermissionRequest: Codable, Sendable, Identifiable {
    public var id: String { requestId }
    /// Message type (always "permission").
    public let type: String
    /// Unique identifier for this permission request.
    public let requestId: String
    /// Name of the tool requiring permission.
    public let toolName: String
    /// Input parameters for the tool.
    public let toolInput: AnyCodable

    public init(type: String = "permission", requestId: String, toolName: String, toolInput: AnyCodable) {
        self.type = type
        self.requestId = requestId
        self.toolName = toolName
        self.toolInput = toolInput
    }
}

// MARK: - Stream Error

/// Error message from the streaming API.
public struct StreamError: Codable, Sendable {
    /// Message type (always "error").
    public let type: String
    /// Error code.
    public let code: String
    /// Human-readable error message.
    public let message: String

    public init(type: String = "error", code: String, message: String) {
        self.type = type
        self.code = code
        self.message = message
    }
}

