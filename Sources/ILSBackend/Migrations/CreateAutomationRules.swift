import Fluent

struct CreateAutomationRules: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("automation_rules")
            .id()
            .field("name", .string, .required)
            .field("description", .string)
            .field("trigger_type", .string, .required)
            .field("conditions", .string, .required)
            .field("action_type", .string, .required)
            .field("action_config", .string, .required)
            .field("is_enabled", .bool, .required)
            .field("session_id", .uuid)
            .field("project_name", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("automation_rules").delete()
    }
}
