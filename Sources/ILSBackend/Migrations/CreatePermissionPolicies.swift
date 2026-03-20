import Fluent

struct CreatePermissionPolicies: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("permission_policies")
            .id()
            .field("name", .string, .required)
            .field("tool_name", .string)
            .field("path_glob", .string)
            .field("command_prefix", .string)
            .field("mcp_server", .string)
            .field("action", .string, .required)
            .field("project_id", .uuid)
            .field("is_enabled", .bool, .required)
            .field("priority", .int, .required)
            .field("note", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("permission_policies").delete()
    }
}
