import Fluent

struct AddMeshGradientToThemes: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("themes")
            .field("mesh_gradient", .json)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("themes")
            .deleteField("mesh_gradient")
            .update()
    }
}
