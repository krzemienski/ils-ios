import Fluent

struct CreateSessionCheckpoints: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("session_checkpoints")
            .id()
            .field("session_id", .uuid, .required, .references("sessions", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("message_count", .int, .required)
            .field("is_automatic", .bool, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("session_checkpoints").delete()
    }
}
