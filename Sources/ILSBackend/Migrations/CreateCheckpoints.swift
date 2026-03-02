import Fluent

struct CreateCheckpoints: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("checkpoints")
            .id()
            .field("session_id", .uuid, .required, .references("sessions", "id", onDelete: .cascade))
            .field("label", .string)
            .field("message_count", .int, .required)
            .field("snapshot_message_ids", .string, .required)
            .field("is_auto", .bool, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("checkpoints").delete()
    }
}
