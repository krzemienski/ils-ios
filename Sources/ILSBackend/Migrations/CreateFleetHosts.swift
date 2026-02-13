import Fluent

struct CreateFleetHosts: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("fleet_hosts")
            .id()
            .field("name", .string, .required)
            .field("host", .string, .required)
            .field("port", .int, .required)
            .field("backend_port", .int, .required)
            .field("username", .string)
            .field("auth_method", .string)
            .field("is_active", .bool, .required)
            .field("health_status", .string, .required)
            .field("last_health_check", .datetime)
            .field("platform", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("fleet_hosts").delete()
    }
}
