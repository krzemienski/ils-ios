import Fluent
import SQLKit

/// Adds database indexes on frequently queried columns for performance.
///
/// Indexes added:
/// - `sessions.last_active_at` — sorted queries (most recent sessions)
/// - `sessions.project_id` — group-by and filter queries
/// - `sessions.model` — filter queries
/// - `sessions.status` — filter queries
/// - `cached_results.query` + `expires_at` — compound lookup + cleanup
struct AddDatabaseIndexes: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            database.logger.warning("AddDatabaseIndexes: skipping — database is not SQL-compatible")
            return
        }

        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_sessions_last_active ON sessions(last_active_at)").run()
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project_id)").run()
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_sessions_model ON sessions(model)").run()
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status)").run()
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_cached_results_query ON cached_results(query, expires_at)").run()
    }

    func revert(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else { return }

        try await sql.raw("DROP INDEX IF EXISTS idx_sessions_last_active").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_sessions_project").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_sessions_model").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_sessions_status").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_cached_results_query").run()
    }
}
