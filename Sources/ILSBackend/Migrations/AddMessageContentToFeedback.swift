import Fluent

/// Adds the `message_content` TEXT column to `response_feedback`.
///
/// This column stores the full AI response text at feedback-submission time so that
/// the Best-Of collection can display response previews without joining the messages table.
struct AddMessageContentToFeedback: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("response_feedback")
            .field("message_content", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        // No-op: dropping a column would destroy stored message content.
        // For dev reset, recreate the database from scratch.
    }
}
