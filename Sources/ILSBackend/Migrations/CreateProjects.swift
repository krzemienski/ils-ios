import Fluent

struct CreateProjects: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("projects")
            .id()
            .field("name", .string, .required)
            .field("path", .string, .required)
            .field("default_model", .string, .required)
            .field("description", .string)
            .field("created_at", .datetime)
            .field("last_accessed_at", .datetime)
            .unique(on: "path")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("projects").delete()
    }
}
