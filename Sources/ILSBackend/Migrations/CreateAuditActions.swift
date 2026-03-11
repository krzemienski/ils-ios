import Fluent

struct CreateAuditActions: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("audit_actions")
            .id()
            .field("session_id", .string, .required)
            .field("session_name", .string)
            .field("action_type", .string, .required)
            .field("description", .string, .required)
            .field("file_path", .string)
            .field("command", .string)
            .field("tool_name", .string)
            .field("before_content", .string)
            .field("after_content", .string)
            .field("metadata", .string)
            .field("is_rollbackable", .bool, .required)
            .field("rollback_status", .string, .required)
            .field("rolled_back_at", .datetime)
            .field("rollback_audit_id", .uuid)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("audit_actions").delete()
    }
}
