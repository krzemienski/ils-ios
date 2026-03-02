import Fluent
import SQLKit

/// Adds FTS5 full-text search support for the `messages` table.
///
/// Creates an external-content FTS5 virtual table that indexes message content,
/// plus triggers to keep the index in sync with the base `messages` table.
///
/// FTS5 table: `messages_fts` (content='messages', content_rowid='rowid')
/// Triggers:
/// - `messages_ai` — after insert, indexes new content
/// - `messages_au` — after update, removes old entry and indexes new content
/// - `messages_ad` — after delete, removes content from index
struct AddMessagesFTS5: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            database.logger.warning("AddMessagesFTS5: skipping — database is not SQL-compatible")
            return
        }

        // Create the FTS5 virtual table pointing at the messages base table.
        // content='messages' makes this an external-content table (no data duplication).
        // content_rowid='rowid' tells FTS5 which column is the rowid in the base table.
        try await sql.raw("""
            CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts
            USING fts5(content, content='messages', content_rowid='rowid')
            """).run()

        // Populate the FTS index from all existing messages rows.
        try await sql.raw("""
            INSERT INTO messages_fts(rowid, content)
            SELECT rowid, content FROM messages
            """).run()

        // AFTER INSERT trigger — index new message content.
        try await sql.raw("""
            CREATE TRIGGER IF NOT EXISTS messages_ai
            AFTER INSERT ON messages BEGIN
                INSERT INTO messages_fts(rowid, content) VALUES (new.rowid, new.content);
            END
            """).run()

        // AFTER UPDATE trigger — remove stale FTS entry then re-index updated content.
        try await sql.raw("""
            CREATE TRIGGER IF NOT EXISTS messages_au
            AFTER UPDATE ON messages BEGIN
                INSERT INTO messages_fts(messages_fts, rowid, content) VALUES ('delete', old.rowid, old.content);
                INSERT INTO messages_fts(rowid, content) VALUES (new.rowid, new.content);
            END
            """).run()

        // AFTER DELETE trigger — remove deleted message from the FTS index.
        try await sql.raw("""
            CREATE TRIGGER IF NOT EXISTS messages_ad
            AFTER DELETE ON messages BEGIN
                INSERT INTO messages_fts(messages_fts, rowid, content) VALUES ('delete', old.rowid, old.content);
            END
            """).run()
    }

    func revert(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else { return }

        try await sql.raw("DROP TRIGGER IF EXISTS messages_ad").run()
        try await sql.raw("DROP TRIGGER IF EXISTS messages_au").run()
        try await sql.raw("DROP TRIGGER IF EXISTS messages_ai").run()
        try await sql.raw("DROP TABLE IF EXISTS messages_fts").run()
    }
}
