import Fluent

struct CreateSSHServers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("ssh_servers")
            .id()
            .field("name", .string, .required)
            .field("host", .string, .required)
            .field("port", .int, .required)
            .field("username", .string, .required)
            .field("auth_type", .string, .required)
            .field("description", .string)
            .field("created_at", .datetime)
            .field("last_connected_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("ssh_servers").delete()
    }
}
