import Fluent

struct CreateRuleExecutionLogs: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("rule_execution_logs")
            .id()
            .field("rule_id", .uuid, .required)
            .field("rule_name", .string, .required)
            .field("session_id", .uuid, .required)
            .field("session_name", .string)
            .field("executed_at", .datetime)
            .field("status", .string, .required)
            .field("error_message", .string)
            .field("details", .string)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("rule_execution_logs").delete()
    }
}
