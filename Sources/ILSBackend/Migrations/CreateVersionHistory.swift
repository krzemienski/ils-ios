import Fluent

struct CreateVersionHistory: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("version_history")
            .id()
            .field("version", .string, .required)
            .field("install_method", .string, .required)
            .field("detected_at", .datetime)
            .field("was_auto_detected", .bool, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("version_history").delete()
    }
}
