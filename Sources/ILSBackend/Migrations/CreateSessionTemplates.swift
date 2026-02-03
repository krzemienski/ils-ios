import Fluent

struct CreateSessionTemplates: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("session_templates")
            .id()
            .field("name", .string, .required)
            .field("description", .string)
            .field("initial_prompt", .string)
            .field("model", .string, .required)
            .field("permission_mode", .string, .required)
            .field("is_favorite", .bool, .required)
            .field("is_default", .bool, .required)
            .field("tags", .array(of: .string), .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("session_templates").delete()
    }
}
