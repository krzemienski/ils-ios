import Fluent

struct CreateSessionHealthScores: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("session_health_scores")
            .id()
            .field("session_id", .string, .required)
            .field("score", .double, .required)
            .field("level", .string, .required)
            .field("factors_json", .string, .required)
            .field("recommendation", .string)
            .field("computed_at", .datetime, .required)
            .unique(on: "session_id")
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("session_health_scores").delete()
    }
}
