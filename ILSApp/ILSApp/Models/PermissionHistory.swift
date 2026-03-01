import Foundation
import GRDB

// MARK: - PermissionHistoryEntry

/// GRDB-backed record for storing the history of permission decisions made by the user.
struct PermissionHistoryEntry: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "permission_history"

    /// UUID as string — primary key.
    let id: String
    /// UUID string of the chat session in which this decision was made.
    var sessionId: String
    /// The tool name that requested permission (e.g. "Bash", "Read", "Write").
    var toolName: String
    /// First 200 characters of the formatted tool input for display purposes.
    var toolInputSummary: String
    /// The decision made: "allow" or "deny".
    var decision: String
    /// Whether this decision was made automatically by an auto-approve rule.
    var isAutoApproved: Bool
    /// When the decision was recorded.
    var timestamp: Date

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        toolName: String,
        toolInputSummary: String,
        decision: String,
        isAutoApproved: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.toolName = toolName
        self.toolInputSummary = String(toolInputSummary.prefix(200))
        self.decision = decision
        self.isAutoApproved = isAutoApproved
        self.timestamp = timestamp
    }
}
