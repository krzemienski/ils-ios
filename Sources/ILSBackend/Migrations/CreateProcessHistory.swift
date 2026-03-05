import Fluent

struct CreateProcessHistory: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("process_history")
            .id()
            .field("pid", .int, .required)
            .field("name", .string, .required)
            .field("session_id", .string)
            .field("start_time", .datetime)
            .field("end_time", .datetime)
            .field("duration", .double)
            .field("peak_cpu_percent", .double, .required)
            .field("peak_memory_mb", .double, .required)
            .field("command", .string)
            .create()
    }

    func revert(on database: Database) async throws {
        // DB-02: Revert is intentionally a no-op in production.
        // Dropping tables would permanently destroy user data.
        // For development reset, use: database.schema("process_history").delete()
    }
}
