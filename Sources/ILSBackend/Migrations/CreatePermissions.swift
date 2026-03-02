import Fluent

struct CreatePermissions: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("permissions")
            .id()
            .field("request_id", .string, .required)
            .field("session_id", .string, .required)
            .field("session_name", .string)
            .field("project_name", .string)
            .field("tool_name", .string, .required)
            .field("tool_input", .string, .required)
            .field("status", .string, .required)
            .field("risk_level", .string, .required)
            .field("requested_at", .datetime, .required)
            .field("resolved_at", .datetime)
            .field("resolved_by", .string)
            .field("deny_reason", .string)
            .field("is_session_approval", .bool, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("permissions").delete()
    }
}
