import Foundation

// MARK: - Main Stream Message Types

/// Top-level streaming message from Claude Code.
public enum StreamMessage: Codable, Sendable {
    /// System initialization or control message.
    case system(SystemMessage)
    /// Assistant response with content blocks.
    case assistant(AssistantMessage)
    /// Final result message with usage and cost information.
    case result(ResultMessage)
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
        case "result":
            self = .result(try ResultMessage(from: decoder))
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
        case .result(let msg):
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

    public init(type: String = "system", subtype: String = "init", data: SystemData) {
        self.type = type
        self.subtype = subtype
        self.data = data
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

    public init(
        sessionId: String,
        plugins: [String]? = nil,
        slashCommands: [String]? = nil,
        tools: [String]? = nil
    ) {
        self.sessionId = sessionId
        self.plugins = plugins
        self.slashCommands = slashCommands
        self.tools = tools
    }
}

// MARK: - Assistant Message

/// Assistant response message containing content blocks.
public struct AssistantMessage: Codable, Sendable {
    /// Message type (always "assistant").
    public let type: String
    /// Array of content blocks in the response.
    public let content: [ContentBlock]

    public init(type: String = "assistant", content: [ContentBlock]) {
        self.type = type
        self.content = content
    }
}

// MARK: - Content Blocks

/// Content block within an assistant message.
public enum ContentBlock: Codable, Sendable {
    /// Plain text response.
    case text(TextBlock)
    /// Tool invocation request.
    case toolUse(ToolUseBlock)
    /// Result from a tool execution.
    case toolResult(ToolResultBlock)
    /// Extended thinking content.
    case thinking(ThinkingBlock)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = .text(try TextBlock(from: decoder))
        case "toolUse", "tool_use":
            self = .toolUse(try ToolUseBlock(from: decoder))
        case "toolResult", "tool_result":
            self = .toolResult(try ToolResultBlock(from: decoder))
        case "thinking":
            self = .thinking(try ThinkingBlock(from: decoder))
        default:
            // Default to text for unknown types
            self = .text(TextBlock(text: ""))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let block):
            try block.encode(to: encoder)
        case .toolUse(let block):
            try block.encode(to: encoder)
        case .toolResult(let block):
            try block.encode(to: encoder)
        case .thinking(let block):
            try block.encode(to: encoder)
        }
    }
}

/// Plain text content block.
public struct TextBlock: Codable, Sendable {
    /// Block type (always "text").
    public let type: String
    /// The text content.
    public let text: String

    public init(type: String = "text", text: String) {
        self.type = type
        self.text = text
    }
}

/// Tool invocation block requesting execution.
public struct ToolUseBlock: Codable, Sendable {
    /// Block type (always "toolUse").
    public let type: String
    /// Unique identifier for this tool use.
    public let id: String
    /// Name of the tool to invoke.
    public let name: String
    /// Tool input parameters.
    public let input: AnyCodable

    public init(type: String = "toolUse", id: String, name: String, input: AnyCodable) {
        self.type = type
        self.id = id
        self.name = name
        self.input = input
    }
}

/// Result from a tool execution.
public struct ToolResultBlock: Codable, Sendable {
    /// Block type (always "toolResult").
    public let type: String
    /// ID of the tool use this result corresponds to.
    public let toolUseId: String
    /// Result content or error message.
    public let content: String
    /// Whether this result represents an error.
    public let isError: Bool

    public init(type: String = "toolResult", toolUseId: String, content: String, isError: Bool = false) {
        self.type = type
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
}

/// Extended thinking content block.
public struct ThinkingBlock: Codable, Sendable {
    /// Block type (always "thinking").
    public let type: String
    /// The thinking content.
    public let thinking: String

    public init(type: String = "thinking", thinking: String) {
        self.type = type
        self.thinking = thinking
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

    public init(
        type: String = "result",
        subtype: String = "success",
        sessionId: String,
        durationMs: Int? = nil,
        durationApiMs: Int? = nil,
        isError: Bool = false,
        numTurns: Int? = nil,
        totalCostUSD: Double? = nil,
        usage: UsageInfo? = nil
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

// MARK: - Permission Request

/// Permission request for tool execution.
public struct PermissionRequest: Codable, Sendable {
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

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for dynamic JSON content.
///
/// Note: @unchecked Sendable because `Any` is non-Sendable but our actual values
/// (Bool, Int, Double, String, Array, Dictionary) are all Sendable primitives.
public struct AnyCodable: Codable, @unchecked Sendable {
    /// The wrapped value (must be a Codable primitive type)
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable cannot encode value")
            throw EncodingError.invalidValue(value, context)
        }
    }
}
