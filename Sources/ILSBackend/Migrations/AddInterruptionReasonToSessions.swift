import Fluent

/// v6.4 — Session interruption tracking for auto-recovery.
///
/// Adds `interruption_reason` (nullable text) to the sessions table.
/// Stores the reason a session was interrupted (e.g. "app_backgrounded",
/// "network_loss", "crash") to enable targeted recovery flows on resume.
struct AddInterruptionReasonToSessions: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sessions")
            .field("interruption_reason", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("sessions")
            .deleteField("interruption_reason")
            .update()
    }
}
