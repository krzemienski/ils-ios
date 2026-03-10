import Fluent

struct CreatePermissionPolicySettings: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("permission_policy_settings")
            .id()
            .field("project_id", .uuid)
            .field("default_deny", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("permission_policy_settings").delete()
    }
}
