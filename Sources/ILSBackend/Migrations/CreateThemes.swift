import Fluent

struct CreateThemes: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("themes")
            .id()
            .field("name", .string, .required)
            .field("description", .string)
            .field("author", .string)
            .field("version", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("colors", .json)
            .field("typography", .json)
            .field("spacing", .json)
            .field("corner_radius", .json)
            .field("shadows", .json)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("themes").delete()
    }
}
