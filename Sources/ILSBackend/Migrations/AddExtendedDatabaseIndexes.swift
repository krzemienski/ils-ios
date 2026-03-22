import Fluent
import SQLKit

/// Adds extended database indexes on frequently queried columns for performance.
///
/// Indexes added:
/// - `sessions.created_at` — sorted queries (oldest/newest sessions)
/// - `projects.name` — filter and search queries by project name
/// - `projects.path` — filter and lookup queries by project path
/// - `skills.name` — filter and search queries by skill name
struct AddExtendedDatabaseIndexes: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            database.logger.warning("AddExtendedDatabaseIndexes: skipping — database is not SQL-compatible")
            return
        }

        // Each index is wrapped in do/catch because the table may not exist yet
        // (sessions/projects are created by external Claude Code data, not by ILS migrations).
        for statement in [
            "CREATE INDEX IF NOT EXISTS idx_sessions_created_at ON sessions(created_at)",
            "CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(name)",
            "CREATE INDEX IF NOT EXISTS idx_projects_path ON projects(path)",
            "CREATE INDEX IF NOT EXISTS idx_skills_name ON skills(name)",
        ] {
            do {
                try await sql.raw(SQLQueryString(statement)).run()
            } catch {
                database.logger.info("AddExtendedDatabaseIndexes: skipping index — \(error.localizedDescription)")
            }
        }
    }

    func revert(on database: Database) async throws {
        // DB-02: Index drops are safe — indexes are fully reconstructable from data.
        guard let sql = database as? SQLDatabase else { return }

        try await sql.raw("DROP INDEX IF EXISTS idx_sessions_created_at").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_projects_name").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_projects_path").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_skills_name").run()
    }
}
