import Foundation

// MARK: - Execution Status

/// Result status of a rule execution attempt.
public enum RuleExecutionStatus: String, Codable, Sendable {
    /// Execution completed successfully.
    case success = "success"
    /// Execution failed due to an error.
    case failed = "failed"
    /// Execution was skipped (conditions not met).
    case skipped = "skipped"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized RuleExecutionStatus: '\(raw)'. Expected: success, failed, skipped"
                )
            )
        }
        self = value
    }
}

// MARK: - Rule Execution Log

/// Log entry for a single execution of an automation rule.
///
/// Captures when a rule was evaluated, whether it fired, and what the outcome was.
/// Used for debugging, auditing, and displaying rule execution history to users.
public struct RuleExecutionLog: Codable, Identifiable, Sendable, Hashable {
    /// Unique identifier for this execution log entry.
    public let id: UUID
    /// ID of the rule that was executed.
    public let ruleId: UUID
    /// Name of the rule at the time of execution.
    public let ruleName: String
    /// ID of the session that triggered the rule.
    public let sessionId: UUID
    /// Name of the session at the time of execution.
    public let sessionName: String?
    /// When the rule was triggered and evaluated.
    public let executedAt: Date
    /// Result of the execution.
    public let status: RuleExecutionStatus
    /// Optional error message if execution failed.
    public let errorMessage: String?
    /// Optional details about the execution (e.g., "Sent notification to user", "Exported to /path/to/file").
    public let details: String?

    public init(
        id: UUID = UUID(),
        ruleId: UUID,
        ruleName: String,
        sessionId: UUID,
        sessionName: String? = nil,
        executedAt: Date = Date(),
        status: RuleExecutionStatus,
        errorMessage: String? = nil,
        details: String? = nil
    ) {
        precondition(!ruleName.isEmpty, "RuleExecutionLog ruleName must not be empty")
        self.id = id
        self.ruleId = ruleId
        self.ruleName = ruleName
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.executedAt = executedAt
        self.status = status
        self.errorMessage = errorMessage
        self.details = details
    }
}
