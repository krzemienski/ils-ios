import Fluent

struct CreateResponseFeedback: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("response_feedback")
            .id()
            .field("message_id", .uuid)
            .field("session_id", .string, .required)
            .field("project_id", .string)
            .field("rating", .string, .required)
            .field("comment", .string)
            .field("model", .string)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("response_feedback").delete()
    }
}
