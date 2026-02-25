import Fluent

struct CreateTemplates: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("templates")
            .id()
            .field("name", .string, .required)
            .field("description", .string, .required)
            .field("model", .string, .required)
            .field("permission_mode", .string, .required)
            .field("system_prompt", .string, .required)
            .field("max_budget_usd", .double)
            .field("max_turns", .int)
            .field("is_favorite", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("templates").delete()
    }
}
