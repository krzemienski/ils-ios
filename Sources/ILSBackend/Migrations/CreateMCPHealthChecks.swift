import Fluent

struct CreateMCPHealthChecks: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("mcp_health_checks")
            .id()
            .field("server_name", .string, .required)
            .field("status", .string, .required)
            .field("checked_at", .datetime, .required)
            .field("response_time_ms", .int)
            .field("error_message", .string)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("mcp_health_checks").delete()
    }
}
