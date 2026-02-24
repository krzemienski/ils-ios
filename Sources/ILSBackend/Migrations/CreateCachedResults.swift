import Fluent

struct CreateCachedResults: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("cached_results")
            .id()
            .field("query", .string, .required)
            .field("result_json", .string, .required)
            .field("created_at", .datetime, .required)
            .field("expires_at", .datetime, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("cached_results").delete()
    }
}
