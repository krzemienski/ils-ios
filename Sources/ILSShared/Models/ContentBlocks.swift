import Foundation

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
