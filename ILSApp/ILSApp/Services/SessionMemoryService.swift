import Foundation
import GRDB

// MARK: - Model Types

/// A persistent note attached to a Claude Code session.
///
/// Notes survive context compaction events, providing users with a way
/// to preserve key decisions, file paths, and variable names across
/// the entire session lifecycle.
struct SessionMemoryNote: Identifiable, Codable {
    let id: String
    let sessionId: String
    var title: String
    var content: String
    var tags: [String]
    var createdAt: Date
}

/// A snapshot of context state captured before a potential compaction event.
///
/// Snapshots record how much context was used at a given moment and a
/// text summary of the conversation state, enabling post-compaction recovery.
struct ContextSnapshot: Identifiable, Codable {
    let id: String
    let sessionId: String
    var usedTokens: Int
    var contextWindowSize: Int
    var snapshotText: String
    var triggeredAt: Date
}

// MARK: - Private GRDB Record Types

private struct MemoryNoteRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "memory_notes"

    let id: String
    var sessionId: String
    var title: String
    var content: String
    var tags: String   // JSON-encoded [String]
    var createdAt: Date
    var cachedAt: Date

    func toNote() -> SessionMemoryNote {
        let decodedTags: [String]
        if let data = tags.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            decodedTags = decoded
        } else {
            decodedTags = []
        }
        return SessionMemoryNote(
            id: id,
            sessionId: sessionId,
            title: title,
            content: content,
            tags: decodedTags,
            createdAt: createdAt
        )
    }
}

private struct SnapshotRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "memory_snapshots"

    let id: String
    var sessionId: String
    var usedTokens: Int
    var contextWindowSize: Int
    var snapshotText: String
    var triggeredAt: Date
    var cachedAt: Date

    func toSnapshot() -> ContextSnapshot {
        ContextSnapshot(
            id: id,
            sessionId: sessionId,
            usedTokens: usedTokens,
            contextWindowSize: contextWindowSize,
            snapshotText: snapshotText,
            triggeredAt: triggeredAt
        )
    }
}

// MARK: - SessionMemoryService

/// Thread-safe service for persisting session memory notes and context snapshots.
///
/// Backed by a dedicated local SQLite database (`session_memory.sqlite`) that is
/// separate from the main cache so session memory is never evicted by cache TTL.
/// Call ``initialize()`` once at app launch before using any other methods.
actor SessionMemoryService {
    static let shared = SessionMemoryService()

    private var dbPool: DatabasePool?

    private init() {}

    // MARK: - Initialization

    /// Initialize the database, creating tables if needed.
    /// Must be called once at app launch before any CRUD operations.
    func initialize() throws {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw URLError(.fileDoesNotExist)
        }
        let dbDir = appSupport.appendingPathComponent("ILS", isDirectory: true)

        if !fileManager.fileExists(atPath: dbDir.path) {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        }

        let dbPath = dbDir.appendingPathComponent("session_memory.sqlite").path
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        dbPool = try DatabasePool(path: dbPath, configuration: config)

        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: dbPath
        )

        try runMigrations()
        AppLogger.shared.info("SessionMemoryService initialized at \(dbPath)", category: "sessionMemory")
    }

    // MARK: - Migrations

    private func runMigrations() throws {
        guard let dbPool else { return }

        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_create_tables") { db in
            try db.create(table: "memory_notes") { t in
                t.primaryKey("id", .text)
                t.column("sessionId", .text).notNull()
                t.column("title", .text).notNull()
                t.column("content", .text).notNull()
                t.column("tags", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("cachedAt", .datetime).notNull()
            }
            try db.create(
                index: "memory_notes_sessionId",
                on: "memory_notes",
                columns: ["sessionId"]
            )

            try db.create(table: "memory_snapshots") { t in
                t.primaryKey("id", .text)
                t.column("sessionId", .text).notNull()
                t.column("usedTokens", .integer).notNull()
                t.column("contextWindowSize", .integer).notNull()
                t.column("snapshotText", .text).notNull()
                t.column("triggeredAt", .datetime).notNull()
                t.column("cachedAt", .datetime).notNull()
            }
            try db.create(
                index: "memory_snapshots_sessionId",
                on: "memory_snapshots",
                columns: ["sessionId"]
            )
        }

        try migrator.migrate(dbPool)
    }

    // MARK: - Session Memory Notes

    /// Save a new memory note for the given session.
    /// - Parameters:
    ///   - sessionId: UUID of the session this note belongs to.
    ///   - title: Short title summarising the note.
    ///   - content: Full note content (decisions, paths, variable names, etc.).
    func saveNote(sessionId: UUID, title: String, content: String) throws {
        guard let dbPool else { return }
        let record = MemoryNoteRecord(
            id: UUID().uuidString,
            sessionId: sessionId.uuidString,
            title: title,
            content: content,
            tags: "[]",
            createdAt: Date(),
            cachedAt: Date()
        )
        try dbPool.write { db in
            try record.insert(db)
        }
    }

    /// Fetch all memory notes for a session, ordered by most recent first.
    /// - Parameter sessionId: UUID of the session to query.
    /// - Returns: Array of ``SessionMemoryNote`` values.
    func fetchNotes(forSession sessionId: UUID) throws -> [SessionMemoryNote] {
        guard let dbPool else { return [] }
        return try dbPool.read { db in
            let records = try MemoryNoteRecord
                .filter(Column("sessionId") == sessionId.uuidString)
                .order(Column("createdAt").desc)
                .fetchAll(db)
            return records.map { $0.toNote() }
        }
    }

    /// Delete a single memory note by its ID.
    /// - Parameter id: UUID string of the note to delete.
    func deleteNote(id: String) throws {
        guard let dbPool else { return }
        try dbPool.write { db in
            _ = try MemoryNoteRecord.deleteOne(db, key: id)
        }
    }

    // MARK: - Context Snapshots

    /// Save a context snapshot for the given session.
    /// - Parameters:
    ///   - sessionId: UUID of the session being snapshotted.
    ///   - usedTokens: Number of tokens used at snapshot time.
    ///   - windowSize: Total context window size in tokens.
    ///   - snapshotText: LLM-generated summary of current context.
    func saveSnapshot(sessionId: UUID, usedTokens: Int, windowSize: Int, snapshotText: String) throws {
        guard let dbPool else { return }
        let record = SnapshotRecord(
            id: UUID().uuidString,
            sessionId: sessionId.uuidString,
            usedTokens: usedTokens,
            contextWindowSize: windowSize,
            snapshotText: snapshotText,
            triggeredAt: Date(),
            cachedAt: Date()
        )
        try dbPool.write { db in
            try record.insert(db)
        }
    }

    /// Fetch all context snapshots for a session, ordered by most recent first.
    /// - Parameter sessionId: UUID of the session to query.
    /// - Returns: Array of ``ContextSnapshot`` values.
    func fetchSnapshots(forSession sessionId: UUID) throws -> [ContextSnapshot] {
        guard let dbPool else { return [] }
        return try dbPool.read { db in
            let records = try SnapshotRecord
                .filter(Column("sessionId") == sessionId.uuidString)
                .order(Column("triggeredAt").desc)
                .fetchAll(db)
            return records.map { $0.toSnapshot() }
        }
    }

    /// Delete a single context snapshot by its ID.
    /// - Parameter id: UUID string of the snapshot to delete.
    func deleteSnapshot(id: String) throws {
        guard let dbPool else { return }
        try dbPool.write { db in
            _ = try SnapshotRecord.deleteOne(db, key: id)
        }
    }
}
