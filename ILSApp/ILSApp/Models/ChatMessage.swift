import Foundation

// MARK: - Chat Message Models

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let isUser: Bool
    var text: String
    var toolCalls: [ToolCallDisplay] = []
    var toolResults: [ToolResultDisplay] = []
    var thinking: String?
    var cost: Double?
    var timestamp: Date?
    var isFromHistory: Bool = false
    var tokenCount: Int = 0
    var elapsedSeconds: Double = 0

    init(
        id: UUID = UUID(),
        isUser: Bool,
        text: String,
        toolCalls: [ToolCallDisplay] = [],
        toolResults: [ToolResultDisplay] = [],
        thinking: String? = nil,
        cost: Double? = nil,
        timestamp: Date? = nil,
        isFromHistory: Bool = false,
        tokenCount: Int = 0,
        elapsedSeconds: Double = 0
    ) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.toolCalls = toolCalls
        self.toolResults = toolResults
        self.thinking = thinking
        self.cost = cost
        self.timestamp = timestamp
        self.isFromHistory = isFromHistory
        self.tokenCount = tokenCount
        self.elapsedSeconds = elapsedSeconds
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.isUser == rhs.isUser &&
        lhs.text == rhs.text &&
        lhs.toolCalls == rhs.toolCalls &&
        lhs.toolResults == rhs.toolResults &&
        lhs.thinking == rhs.thinking &&
        lhs.cost == rhs.cost &&
        lhs.timestamp == rhs.timestamp &&
        lhs.isFromHistory == rhs.isFromHistory &&
        lhs.tokenCount == rhs.tokenCount &&
        lhs.elapsedSeconds == rhs.elapsedSeconds
    }
}

struct ToolCallDisplay: Identifiable, Equatable {
    let id: String
    let name: String
    let inputPreview: String?
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
