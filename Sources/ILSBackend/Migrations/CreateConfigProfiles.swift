import Fluent

struct CreateConfigProfiles: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("config_profiles")
            .id()
            .field("name", .string, .required)
            .field("is_default", .bool)
            .field("is_active", .bool)
            .field("model", .string)
            .field("permissions_json", .string)
            .field("mcp_server_names_json", .string)
            .field("custom_instructions", .string)
            .field("linked_project_paths_json", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("config_profiles").delete()
    }
}
