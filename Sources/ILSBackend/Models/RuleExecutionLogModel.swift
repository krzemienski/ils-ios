import Fluent
import Vapor
import ILSShared

/// Fluent model for RuleExecutionLog
final class RuleExecutionLogModel: Model, Content, @unchecked Sendable {
    static let schema = "rule_execution_logs"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "rule_id")
    var ruleId: UUID

    @Field(key: "rule_name")
    var ruleName: String

    @Field(key: "session_id")
    var sessionId: UUID

    @OptionalField(key: "session_name")
    var sessionName: String?

    @Timestamp(key: "executed_at", on: .create)
    var executedAt: Date?

    @Field(key: "status")
    var status: String

    @OptionalField(key: "error_message")
    var errorMessage: String?

    @OptionalField(key: "details")
    var details: String?

    init() {}

    init(
        id: UUID? = nil,
        ruleId: UUID,
        ruleName: String,
        sessionId: UUID,
        sessionName: String? = nil,
        status: RuleExecutionStatus,
        errorMessage: String? = nil,
        details: String? = nil
    ) {
        self.id = id
        self.ruleId = ruleId
        self.ruleName = ruleName
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.status = status.rawValue
        self.errorMessage = errorMessage
        self.details = details
    }

    /// Convert to shared RuleExecutionLog type
    func toShared() throws -> RuleExecutionLog {
        guard let id = id else {
            throw Abort(.internalServerError, reason: "RuleExecutionLog missing ID")
        }

        let statusEnum = RuleExecutionStatus(rawValue: status) ?? .failed

        return RuleExecutionLog(
            id: id,
            ruleId: ruleId,
            ruleName: ruleName,
            sessionId: sessionId,
            sessionName: sessionName,
            executedAt: executedAt ?? Date(),
            status: statusEnum,
            errorMessage: errorMessage,
            details: details
        )
    }

    /// Create from shared RuleExecutionLog type
    static func from(_ log: RuleExecutionLog) -> RuleExecutionLogModel {
        RuleExecutionLogModel(
            id: log.id,
            ruleId: log.ruleId,
            ruleName: log.ruleName,
            sessionId: log.sessionId,
            sessionName: log.sessionName,
            status: log.status,
            errorMessage: log.errorMessage,
            details: log.details
        )
    }
}
