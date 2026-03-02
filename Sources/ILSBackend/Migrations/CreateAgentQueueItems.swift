import Fluent

struct CreateAgentQueueItems: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("agent_queue_items")
            .id()
            .field("title", .string, .required)
            .field("prompt", .string)
            .field("project_id", .uuid, .references("projects", "id", onDelete: .setNull))
            .field("priority", .int, .required)
            .field("position", .int, .required)
            .field("status", .string, .required)
            .field("execution_mode", .string, .required)
            .field("session_id", .uuid)
            .field("error_message", .string)
            .field("depends_on", .string)
            .field("created_at", .datetime)
            .field("started_at", .datetime)
            .field("completed_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("agent_queue_items").delete()
    }
}
