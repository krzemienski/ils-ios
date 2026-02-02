import Fluent

struct CreateSessions: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sessions")
            .id()
            .field("claude_session_id", .string)
            .field("name", .string)
            .field("project_id", .uuid, .references("projects", "id", onDelete: .setNull))
            .field("model", .string, .required)
            .field("permission_mode", .string, .required)
            .field("status", .string, .required)
            .field("message_count", .int, .required)
            .field("total_cost_usd", .double)
            .field("source", .string, .required)
            .field("forked_from", .uuid)
            .field("created_at", .datetime)
            .field("last_active_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("sessions").delete()
    }
}
