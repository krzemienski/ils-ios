import Fluent

struct CreateSessionRecordings: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("session_recordings")
            .id()
            .field("session_id", .uuid, .required, .references("sessions", "id", onDelete: .cascade))
            .field("name", .string)
            .field("status", .string, .required)
            .field("started_at", .datetime)
            .field("stopped_at", .datetime)
            .field("event_count", .int, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("session_recordings").delete()
    }
}
