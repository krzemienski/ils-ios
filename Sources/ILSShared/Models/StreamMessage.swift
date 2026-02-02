import Foundation

// MARK: - Main Stream Message Types

/// Top-level streaming message from Claude Code
public enum StreamMessage: Codable, Sendable {
    case system(SystemMessage)
    case assistant(AssistantMessage)
    case result(ResultMessage)
    case permission(PermissionRequest)
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

public struct SystemMessage: Codable, Sendable {
    public let type: String
    public let subtype: String
    public let data: SystemData

    public init(type: String = "system", subtype: String = "init", data: SystemData) {
        self.type = type
        self.subtype = subtype
        self.data = data
    }
}

public struct SystemData: Codable, Sendable {
    public let sessionId: String
    public let plugins: [String]?
    public let slashCommands: [String]?
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

public struct AssistantMessage: Codable, Sendable {
    public let type: String
    public let content: [ContentBlock]

    public init(type: String = "assistant", content: [ContentBlock]) {
        self.type = type
        self.content = content
    }
}

// MARK: - Content Blocks

public enum ContentBlock: Codable, Sendable {
    case text(TextBlock)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)
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

public struct TextBlock: Codable, Sendable {
    public let type: String
    public let text: String

    public init(type: String = "text", text: String) {
        self.type = type
        self.text = text
    }
}

public struct ToolUseBlock: Codable, Sendable {
    public let type: String
    public let id: String
    public let name: String
    public let input: AnyCodable

    public init(type: String = "toolUse", id: String, name: String, input: AnyCodable) {
        self.type = type
        self.id = id
        self.name = name
        self.input = input
    }
}

public struct ToolResultBlock: Codable, Sendable {
    public let type: String
    public let toolUseId: String
    public let content: String
    public let isError: Bool

    public init(type: String = "toolResult", toolUseId: String, content: String, isError: Bool = false) {
        self.type = type
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
}

public struct ThinkingBlock: Codable, Sendable {
    public let type: String
    public let thinking: String

    public init(type: String = "thinking", thinking: String) {
        self.type = type
        self.thinking = thinking
    }
}

// MARK: - Result Message

public struct ResultMessage: Codable, Sendable {
    public let type: String
    public let subtype: String
    public let sessionId: String
    public let durationMs: Int?
    public let durationApiMs: Int?
    public let isError: Bool
    public let numTurns: Int?
    public let totalCostUSD: Double?
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

public struct UsageInfo: Codable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadInputTokens: Int?
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

public struct PermissionRequest: Codable, Sendable {
    public let type: String
    public let requestId: String
    public let toolName: String
    public let toolInput: AnyCodable

    public init(type: String = "permission", requestId: String, toolName: String, toolInput: AnyCodable) {
        self.type = type
        self.requestId = requestId
        self.toolName = toolName
        self.toolInput = toolInput
    }
}

// MARK: - Stream Error

public struct StreamError: Codable, Sendable {
    public let type: String
    public let code: String
    public let message: String

    public init(type: String = "error", code: String, message: String) {
        self.type = type
        self.code = code
        self.message = message
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for dynamic JSON content
public struct AnyCodable: Codable, Sendable {
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
