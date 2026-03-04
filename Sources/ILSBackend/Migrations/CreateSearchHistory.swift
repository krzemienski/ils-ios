import Fluent

struct CreateSearchHistory: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("search_history")
            .id()
            .field("query", .string, .required)
            .field("result_count", .int, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("search_history").delete()
    }
}
