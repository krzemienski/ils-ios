import Fluent

struct CreateApprovalPolicies: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("approval_policies")
            .id()
            .field("name", .string, .required)
            .field("template_id", .string)
            .field("action_type", .string, .required)
            .field("tool_names", .string, .required)
            .field("path_globs", .string, .required)
            .field("risk_levels", .string, .required)
            .field("project_id", .string)
            .field("is_enabled", .bool, .required)
            .field("priority", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("approval_policies").delete()
    }
}
