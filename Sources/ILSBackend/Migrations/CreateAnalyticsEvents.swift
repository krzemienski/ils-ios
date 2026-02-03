import Fluent

struct CreateAnalyticsEvents: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("analytics_events")
            .id()
            .field("event_name", .string, .required)
            .field("event_data", .string, .required)
            .field("device_id", .string)
            .field("user_id", .uuid)
            .field("session_id", .string)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("analytics_events").delete()
    }
}
