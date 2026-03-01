import Foundation

// MARK: - Chat Message Models

/// SPERF-03: Copy Overhead Analysis
///
/// ChatMessage is a value type with 13 stored properties (~220 bytes per instance):
///   2 UUIDs, 3 Bools, 2 Strings, 2 small arrays, 3 optionals, 2 numbers.
///
/// During streaming, the ChatViewModel accumulates text into a local `inout ChatMessage`
/// variable and appends to the `messages` array only once at the end of streaming.
/// This means per-token struct copies do NOT occur during streaming -- only local
/// mutation of a stack-allocated value.
///
/// The String `text` property benefits from Swift's copy-on-write semantics, so
/// even when the final message is appended to the array, the String buffer is shared
/// until the next mutation. The `toolCalls` and `toolResults` arrays are typically
/// empty during text streaming, adding negligible copy cost.
///
/// Conclusion: The struct value type is appropriate here. The streaming path is already
/// optimal (inout mutation), and the final copy uses CoW for Strings and empty arrays.
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let isUser: Bool
    var isSystem: Bool = false
    var text: String
    var toolCalls: [ToolCallDisplay] = []
    var toolResults: [ToolResultDisplay] = []
    var thinking: String?
    var cost: Double?
    var timestamp: Date?
    var isFromHistory: Bool = false
    var tokenCount: Int = 0
    var elapsedSeconds: Double = 0
    /// True when this message represents a system-level event rather than user/assistant content.
    var isSystem: Bool = false
    /// Semantic classification of the system event. When nil, `SystemMessageView` falls back to `.generic`.
    var systemEventType: SystemEventType?

    /// Append text in-place, making intent explicit for streaming accumulation.
    @inline(__always)
    mutating func appendText(_ newText: String) {
        text += newText
    }

    init(
        id: UUID = UUID(),
        isUser: Bool,
        isSystem: Bool = false,
        text: String,
        toolCalls: [ToolCallDisplay] = [],
        toolResults: [ToolResultDisplay] = [],
        thinking: String? = nil,
        cost: Double? = nil,
        timestamp: Date? = nil,
        isFromHistory: Bool = false,
        tokenCount: Int = 0,
        elapsedSeconds: Double = 0,
        isSystem: Bool = false,
        systemEventType: SystemEventType? = nil
    ) {
        self.id = id
        self.isUser = isUser
        self.isSystem = isSystem
        self.text = text
        self.toolCalls = toolCalls
        self.toolResults = toolResults
        self.thinking = thinking
        self.cost = cost
        self.timestamp = timestamp
        self.isFromHistory = isFromHistory
        self.tokenCount = tokenCount
        self.elapsedSeconds = elapsedSeconds
        self.isSystem = isSystem
        self.systemEventType = systemEventType
    }

    /// Convenience factory for creating a system event message.
    ///
    /// - Parameters:
    ///   - text: The human-readable description of the event (e.g. "Session started").
    ///   - eventType: Semantic classification for icon and colour. Defaults to `nil` (`.generic` rendering).
    static func systemEvent(_ text: String, eventType: SystemEventType? = nil) -> ChatMessage {
        ChatMessage(
            isUser: false,
            text: text,
            isSystem: true,
            systemEventType: eventType
        )
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.isUser == rhs.isUser &&
        lhs.isSystem == rhs.isSystem &&
        lhs.text == rhs.text &&
        lhs.toolCalls == rhs.toolCalls &&
        lhs.toolResults == rhs.toolResults &&
        lhs.thinking == rhs.thinking &&
        lhs.cost == rhs.cost &&
        lhs.timestamp == rhs.timestamp &&
        lhs.isFromHistory == rhs.isFromHistory &&
        lhs.tokenCount == rhs.tokenCount &&
        lhs.elapsedSeconds == rhs.elapsedSeconds &&
        lhs.isSystem == rhs.isSystem &&
        lhs.systemEventType == rhs.systemEventType
    }
}

struct ToolCallDisplay: Identifiable, Equatable {
    let id: String
    let name: String
    var inputPreview: String?
    var inputPairs: [(key: String, value: String)] = []

    static func == (lhs: ToolCallDisplay, rhs: ToolCallDisplay) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.inputPreview == rhs.inputPreview &&
        lhs.inputPairs.count == rhs.inputPairs.count &&
        zip(lhs.inputPairs, rhs.inputPairs).allSatisfy { $0.key == $1.key && $0.value == $1.value }
    }
}

struct ToolResultDisplay: Equatable {
    let toolUseId: String
    let content: String
    let isError: Bool
}
