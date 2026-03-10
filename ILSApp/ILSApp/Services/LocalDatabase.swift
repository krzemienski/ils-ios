import Foundation
import GRDB
import ILSShared

// MARK: - Cached Record Types

/// Cached session record for GRDB persistence.
struct CachedSession: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "cached_sessions"

    let id: String // UUID as string
    var name: String?
    var model: String
    var status: String
    var messageCount: Int
    var totalCostUSD: Double?
    var source: String
    var projectName: String?
    var firstPrompt: String?
    var createdAt: Date
    var lastActiveAt: Date
    var cachedAt: Date

    init(from session: ChatSession) {
        self.id = session.id.uuidString
        self.name = session.name
        self.model = session.model
        self.status = session.status.rawValue
        self.messageCount = session.messageCount
        self.totalCostUSD = session.totalCostUSD
        self.source = session.source.rawValue
        self.projectName = session.projectName
        self.firstPrompt = session.firstPrompt
        self.createdAt = session.createdAt
        self.lastActiveAt = session.lastActiveAt
        self.cachedAt = Date()
    }

    func toChatSession() -> ChatSession? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return ChatSession(
            id: uuid,
            name: name,
            model: model,
            status: SessionStatus(rawValue: status) ?? .active,
            messageCount: messageCount,
            totalCostUSD: totalCostUSD,
            source: SessionSource(rawValue: source) ?? .ils,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt,
            firstPrompt: firstPrompt
        )
    }
}

/// Cached message record for GRDB persistence.
struct CachedMessage: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "cached_messages"

    let id: String
    var sessionId: String
    var role: String
    var content: String
    var createdAt: Date
    var cachedAt: Date

    init(from message: Message) {
        self.id = message.id.uuidString
        self.sessionId = message.sessionId.uuidString
        self.role = message.role.rawValue
        self.content = message.content
        self.createdAt = message.createdAt
        self.cachedAt = Date()
    }

    func toMessage() -> Message? {
        guard let uuid = UUID(uuidString: id),
              let sessUUID = UUID(uuidString: sessionId) else { return nil }
        return Message(
            id: uuid,
            sessionId: sessUUID,
            role: MessageRole(rawValue: role) ?? .user,
            content: content,
            createdAt: createdAt
        )
    }
}

/// Cached project record for GRDB persistence.
struct CachedProject: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "cached_projects"

    let id: String
    var name: String
    var path: String
    var description: String?
    var defaultModel: String
    var sessionCount: Int?
    var createdAt: Date
    var lastAccessedAt: Date
    var cachedAt: Date

    init(from project: Project) {
        self.id = project.id.uuidString
        self.name = project.name
        self.path = project.path
        self.description = project.description
        self.defaultModel = project.defaultModel
        self.sessionCount = project.sessionCount
        self.createdAt = project.createdAt
        self.lastAccessedAt = project.lastAccessedAt
        self.cachedAt = Date()
    }

    func toProject() -> Project? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return Project(
            id: uuid,
            name: name,
            path: path,
            defaultModel: defaultModel,
            description: description,
            createdAt: createdAt,
            lastAccessedAt: lastAccessedAt,
            sessionCount: sessionCount
        )
    }
}

/// Cached skill record for GRDB persistence.
struct CachedSkill: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "cached_skills"

    let id: String
    var name: String
    var source: String
    var description: String?
    var path: String
    var isActive: Bool
    var cachedAt: Date

    init(from skill: Skill) {
        self.id = skill.id.uuidString
        self.name = skill.name
        self.source = skill.source.rawValue
        self.description = skill.description
        self.path = skill.path
        self.isActive = skill.isActive
        self.cachedAt = Date()
    }

    func toSkill() -> Skill? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return Skill(
            id: uuid,
            name: name,
            description: description,
            isActive: isActive,
            path: path,
            source: SkillSource(rawValue: source) ?? .local
        )
    }
}

/// Cached MCP server record for GRDB persistence.
struct CachedMCPServer: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "cached_mcp_servers"

    let id: String
    var name: String
    var command: String
    var scope: String
    var status: String
    var cachedAt: Date

    init(from server: MCPServer) {
        self.id = server.id.uuidString
        self.name = server.name
        self.command = server.command
        self.scope = server.scope.rawValue
        self.status = server.status.rawValue
        self.cachedAt = Date()
    }

    func toMCPServer() -> MCPServer? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return MCPServer(
            id: uuid,
            name: name,
            command: command,
            scope: MCPScope(rawValue: scope) ?? .user,
            status: MCPStatus(rawValue: status) ?? .unknown
        )
    }
}

/// Cached plugin record for GRDB persistence.
struct CachedPlugin: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "cached_plugins"

    let id: String
    var name: String
    var description: String?
    var isInstalled: Bool
    var isEnabled: Bool
    var version: String?
    var cachedAt: Date

    init(from plugin: Plugin) {
        self.id = plugin.id.uuidString
        self.name = plugin.name
        self.description = plugin.description
        self.isInstalled = plugin.isInstalled
        self.isEnabled = plugin.isEnabled
        self.version = plugin.version
        self.cachedAt = Date()
    }

    func toPlugin() -> Plugin? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return Plugin(
            id: uuid,
            name: name,
            description: description,
            isInstalled: isInstalled,
            isEnabled: isEnabled,
            version: version
        )
    }
}

/// Cached session memory note for GRDB persistence.
struct CachedSessionMemoryNote: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "session_memory_notes"

    let id: String
    var sessionId: String
    var title: String
    var content: String
    var tags: String // JSON-encoded [String]
    var createdAt: Date
    var cachedAt: Date
}

/// Cached context snapshot for GRDB persistence.
struct CachedContextSnapshot: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "context_snapshots"

    let id: String
    var sessionId: String
    var usedTokens: Int
    var contextWindowSize: Int
    var snapshotText: String
    var triggeredAt: Date
    var cachedAt: Date
}

/// Cached SSH server connection profile for GRDB persistence.
///
/// Intentionally omits sensitive fields (credentials, private keys, passwords).
/// Credentials are stored separately in the system Keychain, keyed by connection ID.
struct CachedServerConnection: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "cached_server_connections"

    /// UUID of the connection profile (as string).
    let id: String
    /// Hostname or IP address of the remote server.
    var host: String
    /// SSH port number.
    var port: Int
    /// SSH username for authentication.
    var username: String
    /// Authentication method identifier ("password" or "privateKey").
    var authMethod: String
    /// Optional human-readable label for the profile.
    var label: String?
    /// Timestamp of the last successful connection, if any.
    var lastConnected: Date?
    /// Timestamp when this record was cached.
    var cachedAt: Date
}

/// Cached team record for GRDB persistence.
struct CachedTeam: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "cached_teams"

    // PERF-007: Static shared encoder/decoder avoids per-instance allocation.
    private static let memberEncoder = JSONEncoder()
    private static let memberDecoder = JSONDecoder()

    let id: String // team name
    var name: String
    var description: String?
    var membersData: Data // JSON-encoded [TeamMember]
    var createdAt: Date?
    var cachedAt: Date

    init(from team: AgentTeam) {
        self.id = team.name
        self.name = team.name
        self.description = team.description
        // COD-001: Log encoding failures instead of silently dropping member data.
        do {
            self.membersData = try Self.memberEncoder.encode(team.members)
        } catch {
            AppLogger.shared.error("Failed to encode team members for '\(team.name)': \(error)", category: "database")
            self.membersData = Data()
        }
        self.createdAt = team.createdAt
        self.cachedAt = Date()
    }

    func toAgentTeam() -> AgentTeam {
        // COD-001: Log decoding failures instead of silently returning empty members.
        let members: [TeamMember]
        do {
            members = try Self.memberDecoder.decode([TeamMember].self, from: membersData)
        } catch {
            AppLogger.shared.error("Failed to decode team members for '\(name)': \(error)", category: "database")
            members = []
        }
        return AgentTeam(
            name: name,
            description: description,
            members: members,
            createdAt: createdAt
        )
    }
}

// MARK: - LocalDatabase

/// Thread-safe local SQLite database for offline caching.
///
/// Uses GRDB with WAL mode for concurrent read/write access.
/// All tables store flattened versions of ILSShared model types.
/// SQLite cache for offline access to sessions, messages, projects, skills, MCP servers, and plugins.
///
/// Provides GRDB-backed persistence for cached API responses with per-entity TTL expiry.
/// Supports session count limiting and automatic cleanup of stale entries.
///
/// ## Usage
/// Call ``initialize()`` once at app launch. Then use cache-first methods like ``fetchSessions(newerThan:isOffline:)``,
/// ``saveSessions(_:)``, ``fetchMessages(forSession:)``, etc. to manage offline data.
///
/// ## Storage Location
/// SQLite database stored at `~/Library/Application Support/ILS/cache.sqlite` (excluded from iCloud backup).
///
/// ## Thread Safety
/// Actor-isolated for thread safety. All database operations are internally async/await based.
actor LocalDatabase {
    static let shared = LocalDatabase()

    private var dbPool: DatabasePool?

    private init() {}

    /// Initialize the database, creating tables if needed.
    func initialize() throws {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupport.appendingPathComponent("ILS", isDirectory: true)

        if !fileManager.fileExists(atPath: dbDir.path) {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        }

        // STOR-001: Exclude cache directory from iCloud backup.
        // Applied on every launch (not just creation) to survive backup restoration.
        var excludedDir = dbDir
        var backupValues = URLResourceValues()
        backupValues.isExcludedFromBackup = true
        try excludedDir.setResourceValues(backupValues)

        let dbPath = dbDir.appendingPathComponent("cache.sqlite").path
        var config = Configuration()
        config.prepareDatabase { db in
            // Enable WAL mode for better concurrent access
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            // Enforce referential integrity
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        dbPool = try DatabasePool(path: dbPath, configuration: config)

        // Apply file protection so the database is accessible after first unlock (background refresh, widgets)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: dbPath
        )
        // Also protect WAL and SHM journal files if they exist
        let walPath = dbPath + "-wal"
        let shmPath = dbPath + "-shm"
        // MOD-008: Log file protection errors instead of silently swallowing them.
        if fileManager.fileExists(atPath: walPath) {
            do {
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: walPath
                )
            } catch {
                AppLogger.shared.error("Failed to set WAL file protection: \(error)", category: "database")
            }
        }
        if fileManager.fileExists(atPath: shmPath) {
            do {
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: shmPath
                )
            } catch {
                AppLogger.shared.error("Failed to set SHM file protection: \(error)", category: "database")
            }
        }

        try runMigrations()
        AppLogger.shared.info("LocalDatabase initialized at \(dbPath)", category: "cache")
    }

    // MARK: - Migrations

    private func runMigrations() throws {
        guard let dbPool else { return }

        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_create_tables") { db in
            try db.create(table: "cached_sessions") { t in
                t.primaryKey("id", .text)
                t.column("name", .text)
                t.column("model", .text).notNull()
                t.column("status", .text).notNull()
                t.column("messageCount", .integer).notNull()
                t.column("totalCostUSD", .double)
                t.column("source", .text).notNull()
                t.column("projectName", .text)
                t.column("firstPrompt", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("lastActiveAt", .datetime).notNull()
                t.column("cachedAt", .datetime).notNull()
            }

            try db.create(table: "cached_messages") { t in
                t.primaryKey("id", .text)
                t.column("sessionId", .text).notNull()
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("cachedAt", .datetime).notNull()
            }
            try db.create(
                index: "cached_messages_sessionId",
                on: "cached_messages",
                columns: ["sessionId"]
            )

            try db.create(table: "cached_projects") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("path", .text).notNull()
                t.column("description", .text)
                t.column("defaultModel", .text).notNull()
                t.column("sessionCount", .integer)
                t.column("createdAt", .datetime).notNull()
                t.column("lastAccessedAt", .datetime).notNull()
                t.column("cachedAt", .datetime).notNull()
            }

            try db.create(table: "cached_skills") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("source", .text).notNull()
                t.column("description", .text)
                t.column("path", .text).notNull()
                t.column("isActive", .boolean).notNull()
                t.column("cachedAt", .datetime).notNull()
            }

            try db.create(table: "cached_mcp_servers") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("command", .text).notNull()
                t.column("scope", .text).notNull()
                t.column("status", .text).notNull()
                t.column("cachedAt", .datetime).notNull()
            }

            try db.create(table: "cached_plugins") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("isInstalled", .boolean).notNull()
                t.column("isEnabled", .boolean).notNull()
                t.column("version", .text)
                t.column("cachedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v2_add_server_connections") { db in
            try db.create(table: "cached_server_connections") { t in
                t.primaryKey("id", .text)
                t.column("host", .text).notNull()
                t.column("port", .integer).notNull()
                t.column("username", .text).notNull()
                t.column("authMethod", .text).notNull()
                t.column("label", .text)
                t.column("lastConnected", .datetime)
                t.column("cachedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v2_permission_history") { db in
            try db.create(table: "permission_history") { t in
                t.primaryKey("id", .text)
                t.column("sessionId", .text).notNull()
                t.column("toolName", .text).notNull()
                t.column("toolInputSummary", .text).notNull()
                t.column("decision", .text).notNull()
                t.column("isAutoApproved", .boolean).notNull().defaults(to: false)
                t.column("timestamp", .datetime).notNull()
            }
            try db.create(
                index: "permission_history_sessionId",
                on: "permission_history",
                columns: ["sessionId"]
            )
            try db.create(
                index: "permission_history_timestamp",
                on: "permission_history",
                columns: ["timestamp"]
            )
        }

        migrator.registerMigration("v3_add_teams_table") { db in
            try db.create(table: "cached_teams") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("membersData", .blob).notNull()
                t.column("createdAt", .datetime)
                t.column("cachedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v3_add_session_memory_tables") { db in
            try db.create(table: "session_memory_notes") { t in
                t.primaryKey("id", .text)
                t.column("sessionId", .text).notNull()
                t.column("title", .text).notNull()
                t.column("content", .text).notNull()
                t.column("tags", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("cachedAt", .datetime).notNull()
            }
            try db.create(
                index: "session_memory_notes_sessionId",
                on: "session_memory_notes",
                columns: ["sessionId"]
            )

            try db.create(table: "context_snapshots") { t in
                t.primaryKey("id", .text)
                t.column("sessionId", .text).notNull()
                t.column("usedTokens", .integer).notNull()
                t.column("contextWindowSize", .integer).notNull()
                t.column("snapshotText", .text).notNull()
                t.column("triggeredAt", .datetime).notNull()
                t.column("cachedAt", .datetime).notNull()
            }
            try db.create(
                index: "context_snapshots_sessionId",
                on: "context_snapshots",
                columns: ["sessionId"]
            )
        }

        try migrator.migrate(dbPool)
    }

    // MARK: - Sessions

    /// Save sessions to the cache database.
    ///
    /// PERF-001: Individual `record.save(db)` calls are wrapped in a single `dbPool.write`
    /// transaction, so all 22K+ rows are committed atomically in one SQLite transaction.
    /// GRDB's `save()` issues INSERT OR REPLACE which is efficient within a transaction.
    func saveSessions(_ sessions: [ChatSession]) throws {
        guard let dbPool else { return }
        let records = sessions.map { CachedSession(from: $0) }
        try dbPool.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }

    /// Fetch cached sessions.
    ///
    /// - Parameters:
    ///   - newerThan: Optional TTL window — only return sessions cached within this many seconds.
    ///                Ignored when `isOffline` is true so stale cache is still surfaced.
    ///   - isOffline: When `true`, skips TTL filtering and returns all cached sessions regardless of age.
    func fetchSessions(newerThan maxAge: TimeInterval? = nil, isOffline: Bool = false) throws -> [ChatSession] {
        guard let dbPool else { return [] }
        return try dbPool.read { db in
            var request = CachedSession.order(Column("lastActiveAt").desc)
            // Skip TTL filter when offline so users always see cached data
            if !isOffline, let maxAge {
                let cutoff = Date().addingTimeInterval(-maxAge)
                request = request.filter(Column("cachedAt") >= cutoff)
            }
            let records = try request.fetchAll(db)
            return records.compactMap { $0.toChatSession() }
        }
    }

    func deleteAllSessions() throws {
        guard let dbPool else { return }
        try dbPool.write { db in
            _ = try CachedSession.deleteAll(db)
        }
    }

    // MARK: - Messages

    func saveMessages(_ messages: [Message]) throws {
        guard let dbPool else { return }
        let records = messages.map { CachedMessage(from: $0) }
        try dbPool.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }

    func fetchMessages(forSession sessionId: UUID) throws -> [Message] {
        guard let dbPool else { return [] }
        return try dbPool.read { db in
            let records = try CachedMessage
                .filter(Column("sessionId") == sessionId.uuidString)
                .order(Column("createdAt").asc)
                .fetchAll(db)
            return records.compactMap { $0.toMessage() }
        }
    }

    func deleteMessages(forSession sessionId: UUID) throws {
        guard let dbPool else { return }
        try dbPool.write { db in
            _ = try CachedMessage
                .filter(Column("sessionId") == sessionId.uuidString)
                .deleteAll(db)
        }
    }

    // MARK: - Projects

    func saveProjects(_ projects: [Project]) throws {
        guard let dbPool else { return }
        let records = projects.map { CachedProject(from: $0) }
        try dbPool.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }

    func fetchProjects() throws -> [Project] {
        guard let dbPool else { return [] }
        return try dbPool.read { db in
            let records = try CachedProject
                .order(Column("lastAccessedAt").desc)
                .fetchAll(db)
            return records.compactMap { $0.toProject() }
        }
    }

    // MARK: - Skills

    func saveSkills(_ skills: [Skill]) throws {
        guard let dbPool else { return }
        let records = skills.map { CachedSkill(from: $0) }
        try dbPool.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }

    func fetchSkills() throws -> [Skill] {
        guard let dbPool else { return [] }
        return try dbPool.read { db in
            let records = try CachedSkill
                .order(Column("name").asc)
                .fetchAll(db)
            return records.compactMap { $0.toSkill() }
        }
    }

    // MARK: - MCP Servers

    func saveMCPServers(_ servers: [MCPServer]) throws {
        guard let dbPool else { return }
        let records = servers.map { CachedMCPServer(from: $0) }
        try dbPool.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }

    func fetchMCPServers() throws -> [MCPServer] {
        guard let dbPool else { return [] }
        return try dbPool.read { db in
            let records = try CachedMCPServer
                .order(Column("name").asc)
                .fetchAll(db)
            return records.compactMap { $0.toMCPServer() }
        }
    }

    // MARK: - Plugins

    func savePlugins(_ plugins: [Plugin]) throws {
        guard let dbPool else { return }
        let records = plugins.map { CachedPlugin(from: $0) }
        try dbPool.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }

    func fetchPlugins() throws -> [Plugin] {
        guard let dbPool else { return [] }
        return try dbPool.read { db in
            let records = try CachedPlugin
                .order(Column("name").asc)
                .fetchAll(db)
            return records.compactMap { $0.toPlugin() }
        }
    }

    // MARK: - Teams

    func saveTeams(_ teams: [AgentTeam]) throws {
        guard let dbPool else { return }
        let records = teams.map { CachedTeam(from: $0) }
        try dbPool.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }

    func fetchTeams() throws -> [AgentTeam] {
        guard let dbPool else { return [] }
        return try dbPool.read { db in
            let records = try CachedTeam
                .order(Column("name").asc)
                .fetchAll(db)
            return records.map { $0.toAgentTeam() }
        }
    }

    func deleteAllTeams() throws {
        guard let dbPool else { return }
        try dbPool.write { db in
            _ = try CachedTeam.deleteAll(db)
        }
    }

    // MARK: - Cleanup

    /// Delete all cached entries older than the specified age.
    func cleanupExpired(olderThan maxAge: TimeInterval) throws {
        guard let dbPool else { return }
        let cutoff = Date().addingTimeInterval(-maxAge)
        try dbPool.write { db in
            _ = try CachedSession.filter(Column("cachedAt") < cutoff).deleteAll(db)
            _ = try CachedMessage.filter(Column("cachedAt") < cutoff).deleteAll(db)
            _ = try CachedProject.filter(Column("cachedAt") < cutoff).deleteAll(db)
            _ = try CachedSkill.filter(Column("cachedAt") < cutoff).deleteAll(db)
            _ = try CachedMCPServer.filter(Column("cachedAt") < cutoff).deleteAll(db)
            _ = try CachedPlugin.filter(Column("cachedAt") < cutoff).deleteAll(db)
            _ = try CachedTeam.filter(Column("cachedAt") < cutoff).deleteAll(db)
        }
    }

    /// Delete all cached data.
    func clearAll() throws {
        guard let dbPool else { return }
        try dbPool.write { db in
            _ = try CachedSession.deleteAll(db)
            _ = try CachedMessage.deleteAll(db)
            _ = try CachedProject.deleteAll(db)
            _ = try CachedSkill.deleteAll(db)
            _ = try CachedMCPServer.deleteAll(db)
            _ = try CachedPlugin.deleteAll(db)
            _ = try CachedTeam.deleteAll(db)
            // STOR-005: Checkpoint WAL after truncating all tables to reclaim disk space.
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
        AppLogger.shared.info("All cached data cleared", category: "cache")
    }

    /// MEM-005: Checkpoint WAL to reclaim memory after memory warning.
    /// Moves pending WAL data into the main database file, reducing memory footprint.
    func checkpointWAL() throws {
        guard let dbPool else { return }
        try dbPool.write { db in
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
        AppLogger.shared.info("WAL checkpoint completed", category: "cache")
    }

    // MARK: - Server Connections (SSH Profiles)

    /// Saves or updates an SSH server connection profile.
    /// - Parameter connection: The profile to persist. Credentials must be stored separately in Keychain.
    func saveServerConnection(_ connection: CachedServerConnection) throws {
        guard let dbPool else { return }
        try dbPool.write { db in
            try connection.save(db)
        }
    }

    /// Fetches all saved SSH server connection profiles, ordered by most recently connected.
    func fetchServerConnections() throws -> [CachedServerConnection] {
        guard let dbPool else { return [] }
        return try dbPool.read { db in
            try CachedServerConnection
                .order(Column("lastConnected").desc, Column("cachedAt").desc)
                .fetchAll(db)
        }
    }

    /// Fetches a single SSH server connection profile by its UUID string.
    /// - Parameter id: UUID string of the profile to fetch.
    /// - Returns: The profile if found, or `nil`.
    func fetchServerConnection(byId id: String) throws -> CachedServerConnection? {
        guard let dbPool else { return nil }
        return try dbPool.read { db in
            try CachedServerConnection.fetchOne(db, key: id)
        }
    }

    /// Deletes an SSH server connection profile by its UUID string.
    /// - Parameter id: UUID string of the profile to delete.
    func deleteServerConnection(byId id: String) throws {
        guard let dbPool else { return }
        try dbPool.write { db in
            _ = try CachedServerConnection.deleteOne(db, key: id)
        }
    }

    // MARK: - Permission History

    /// Insert a permission decision record into local storage.
    func savePermissionEntry(_ entry: PermissionHistoryEntry) throws {
        guard let dbPool else { return }
        try dbPool.write { db in
            try entry.insert(db)
        }
    }

    /// Fetch permission history ordered by most recent first.
    func fetchPermissionHistory(limit: Int = 200) throws -> [PermissionHistoryEntry] {
        guard let dbPool else { return [] }
        return try dbPool.read { db in
            try PermissionHistoryEntry
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Aggregate permission statistics using SQL GROUP BY queries.
    func fetchPermissionStats() throws -> PermissionStats {
        guard let dbPool else {
            return PermissionStats(
                totalApproved: 0,
                totalDenied: 0,
                totalAutoApproved: 0,
                approvalRate: 0.0,
                topTools: [:]
            )
        }
        return try dbPool.read { db in
            // Decision + auto-approve breakdown
            let decisionRows = try Row.fetchAll(db, sql: """
                SELECT decision, isAutoApproved, COUNT(*) as cnt
                FROM permission_history
                GROUP BY decision, isAutoApproved
                """)

            var totalApproved = 0
            var totalDenied = 0
            var totalAutoApproved = 0

            for row in decisionRows {
                let decision: String = row["decision"]
                let isAutoApproved: Bool = row["isAutoApproved"]
                let count: Int = row["cnt"]
                if decision == "allow" {
                    totalApproved += count
                } else {
                    totalDenied += count
                }
                if isAutoApproved {
                    totalAutoApproved += count
                }
            }

            let total = totalApproved + totalDenied
            let approvalRate = total > 0 ? Double(totalApproved) / Double(total) : 0.0

            // Top 5 tools by usage frequency
            let toolRows = try Row.fetchAll(db, sql: """
                SELECT toolName, COUNT(*) as cnt
                FROM permission_history
                GROUP BY toolName
                ORDER BY cnt DESC
                LIMIT 5
                """)

            var topTools: [String: Int] = [:]
            for row in toolRows {
                let toolName: String = row["toolName"]
                let count: Int = row["cnt"]
                topTools[toolName] = count
            }

            return PermissionStats(
                totalApproved: totalApproved,
                totalDenied: totalDenied,
                totalAutoApproved: totalAutoApproved,
                approvalRate: approvalRate,
                topTools: topTools
            )
        }
    }

    /// Delete all permission history records.
    func clearPermissionHistory() throws {
        guard let dbPool else { return }
        try dbPool.write { db in
            _ = try PermissionHistoryEntry.deleteAll(db)
        }
    }

    // MARK: - Storage

    /// Returns the total disk usage in bytes for the SQLite cache files (main db, WAL, and SHM).
    func cacheStorageBytes() -> Int64 {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return 0
        }
        let dbPath = appSupport
            .appendingPathComponent("ILS", isDirectory: true)
            .appendingPathComponent("cache.sqlite")
            .path

        var totalBytes: Int64 = 0
        for path in [dbPath, dbPath + "-wal", dbPath + "-shm"] {
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                totalBytes += size
            }
        }
        return totalBytes
    }
}
