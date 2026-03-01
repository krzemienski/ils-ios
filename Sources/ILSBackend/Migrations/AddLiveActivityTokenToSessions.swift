import Fluent

/// v5.0 — Live Activity push token support.
///
/// Adds `live_activity_push_token` (nullable text) to the sessions table.
/// Stores the APNs hex push token registered by the iOS client when a Live Activity
/// is started with `pushType: .token`. Used by the backend to push content-state
/// updates when the SSE connection is unavailable (app backgrounded).
struct AddLiveActivityTokenToSessions: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sessions")
            .field("live_activity_push_token", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("sessions")
            .deleteField("live_activity_push_token")
            .update()
    }
}
