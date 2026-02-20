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

// MARK: - LocalDatabase

/// Thread-safe local SQLite database for offline caching.
///
/// Uses GRDB with WAL mode for concurrent read/write access.
/// All tables store flattened versions of ILSShared model types.
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

        let dbPath = dbDir.appendingPathComponent("cache.sqlite").path
        var config = Configuration()
        config.prepareDatabase { db in
            // Enable WAL mode for better concurrent access
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }

        dbPool = try DatabasePool(path: dbPath, configuration: config)

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

        try migrator.migrate(dbPool)
    }

    // MARK: - Sessions

    func saveSessions(_ sessions: [ChatSession]) throws {
        guard let dbPool else { return }
        let records = sessions.map { CachedSession(from: $0) }
        try dbPool.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }

    func fetchSessions(olderThan maxAge: TimeInterval? = nil) throws -> [ChatSession] {
        guard let dbPool else { return [] }
        return try dbPool.read { db in
            var request = CachedSession.order(Column("lastActiveAt").desc)
            if let maxAge {
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
        }
        AppLogger.shared.info("All cached data cleared", category: "cache")
    }
}
