import Vapor
import Fluent
import FluentSQLiteDriver
import SQLKit

func configure(_ app: Application) async throws {
    // CORS middleware — restrict to configured origins (default: localhost only)
    // Set ILS_CORS_ORIGINS env var to comma-separated list for production
    let allowedOrigin: CORSMiddleware.AllowOriginSetting
    if let originsEnv = Environment.get("ILS_CORS_ORIGINS"), !originsEnv.isEmpty {
        let origins = originsEnv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if origins.count == 1 {
            allowedOrigin = .custom(origins[0])
        } else {
            allowedOrigin = .any(origins)
        }
    } else {
        // Default: localhost development origins only
        allowedOrigin = .any([
            "http://localhost:3000",
            "http://localhost:8080",
            "http://localhost:9999",
            "http://127.0.0.1:3000",
            "http://127.0.0.1:8080",
            "http://127.0.0.1:9999"
        ])
    }

    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: allowedOrigin,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
        allowedHeaders: [
            .accept, .authorization, .contentType, .origin, .xRequestedWith,
            .init("X-Session-ID"), .init("X-Project-ID"), .init("X-Admin-Token")
        ],
        allowCredentials: true
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)

    // Request logging middleware (logs method, path, status, duration)
    app.middleware.use(RequestLoggingMiddleware())

    // HTTP caching middleware (ETag, Cache-Control, 304 Not Modified for GET responses)
    app.middleware.use(HTTPCachingMiddleware())

    // Structured error middleware (replaces Vapor's default ErrorMiddleware)
    app.middleware.use(ILSErrorMiddleware())

    // API key authentication middleware (opt-in via ILS_API_KEY env var)
    app.middleware.use(APIKeyMiddleware())

    // Rate limiting middleware
    let rateLimitStorage = RateLimitStorage()
    app.middleware.use(RateLimitMiddleware(storage: rateLimitStorage))

    // Request size limits (configurable via ILS_MAX_BODY_MB env var, default: 10)
    let maxBodyMB = Int(Environment.get("ILS_MAX_BODY_MB") ?? "10") ?? 10
    app.routes.defaultMaxBodySize = .init(integerLiteral: maxBodyMB * 1_048_576)

    // Database configuration
    // SQLiteConfiguration.enableForeignKeys defaults to true, which issues
    // PRAGMA foreign_keys = ON on every pooled connection via SQLiteKit's
    // SQLiteConnectionSource. This ensures FK constraints are enforced
    // across all connections, not just the first one.
    let dbPath = app.directory.workingDirectory + "ils.sqlite"
    let sqliteConfig = SQLiteConfiguration(storage: .file(path: dbPath), enableForeignKeys: true)
    app.databases.use(.sqlite(sqliteConfig), as: .sqlite)

    // SEC-006: Restrict SQLite file permissions (owner read/write only)
    let fm = FileManager.default
    if fm.fileExists(atPath: dbPath) {
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dbPath)
    }

    // ENRG-LOW-02: Enable WAL mode for reduced disk I/O and better concurrent reads.
    // WAL (Write-Ahead Logging) avoids blocking readers during writes and batches
    // disk syncs, significantly reducing energy impact on mobile backends.
    if let sql = app.db as? SQLDatabase {
        _ = try await sql.raw("PRAGMA journal_mode=WAL").all()
        _ = try await sql.raw("PRAGMA synchronous = NORMAL").all()
    }

    // DB-MED-2: Migration versioning strategy.
    // Fluent runs migrations in registration order. Each migration is idempotent
    // (CREATE TABLE IF NOT EXISTS). Reverts are no-ops (Phase 22 decision).
    // New migrations MUST be appended — never reorder or insert.
    //
    // v1.0 — Core tables
    app.migrations.add(CreateProjects())
    app.migrations.add(CreateSessions())
    app.migrations.add(CreateMessages())
    app.migrations.add(CreateThemes())
    app.migrations.add(CreateCachedResults())
    // v2.0 — Fleet management
    app.migrations.add(CreateFleetHosts())
    // v3.0 — Performance indexes
    app.migrations.add(AddDatabaseIndexes())
    // v4.0 — Ecosystem polish
    app.migrations.add(AddMeshGradientToThemes())
    // v5.0 — Session checkpoint & crash recovery
    app.migrations.add(CreateCheckpoints())
    // v5.1 — Session templates
    app.migrations.add(CreateTemplates())
    // v5.2 — Live Activity push token support
    app.migrations.add(AddLiveActivityTokenToSessions())
    // v5.3 — Session health scoring (on-demand computation; no caching table)
    // DB-NOTE: A session_health_scores caching table was originally planned
    // but deferred — scores are computed on-demand instead.
    // v5.4 — Session recordings
    app.migrations.add(CreateSessionRecordings())
    // v5.5 — Full-text search
    app.migrations.add(AddMessagesFTS5())
    // v5.6 — Search history
    app.migrations.add(CreateSearchHistory())
    // v5.7 — Enhanced checkpoint system (export/backup)
    app.migrations.add(CreateSessionCheckpoints())
    // v5.8 — Agent queue & batch task management
    app.migrations.add(CreateAgentQueueItems())
    // v5.9 — Permission history
    app.migrations.add(CreatePermissions())
    // v5.10 — Session Automation rules
    app.migrations.add(CreateAutomationRules())
    app.migrations.add(CreateRuleExecutionLogs())
    // v6.0 — Claude Code CLI version history tracking
    app.migrations.add(CreateVersionHistory())
    // v6.1 — Configuration profiles
    app.migrations.add(CreateConfigProfiles())
    // v6.2 — Process monitoring
    app.migrations.add(CreateProcessHistory())
    // v6.3 — AI response quality feedback & audit trail
    app.migrations.add(CreateResponseFeedback())
    app.migrations.add(AddMessageContentToFeedback())
    // v6.4 — Interactive permission policy engine
    app.migrations.add(CreatePermissionPolicies())
    app.migrations.add(CreatePermissionPolicySettings())
    // v6.5 — Permission policy tracking (matched_policy_id on permissions)
    app.migrations.add(AddPolicyIdToPermissions())
    // v6.6 — AI action audit trail & one-tap rollback
    app.migrations.add(CreateAuditActions())

    // Run migrations
    try await app.autoMigrate()

    #if DEBUG
    // DB-03: Validate existing data satisfies FK constraints after migration.
    // PRAGMA foreign_key_check returns rows for any FK violations found in the database.
    // Runs only in DEBUG builds to catch data integrity issues during development.
    if let sql = app.db as? SQLDatabase {
        let violations = try await sql.raw("PRAGMA foreign_key_check").all()
        if !violations.isEmpty {
            app.logger.warning("DB-03: FK constraint violations found: \(violations.count) rows affected")
        }
    }
    #endif

    // Register routes
    try routes(app)

    // Server configuration
    let port = Int(Environment.get("PORT") ?? "9999") ?? 9999
    // SEC-002: Network binding security.
    // Default: 127.0.0.1 (localhost only — no external access).
    // Set ILS_LAN_ENABLED=true to bind 0.0.0.0 for LAN/fleet/remote access.
    // When LAN-enabled, access control relies on:
    //   - RateLimitMiddleware (per-IP request throttling)
    //   - APIKeyMiddleware (opt-in via ILS_API_KEY env var)
    //   - Cloudflare tunnel for internet-facing scenarios
    // Do NOT remove the default localhost binding — it protects dev environments.
    let hostname = Environment.get("ILS_LAN_ENABLED") == "true" ? "0.0.0.0" : "127.0.0.1"
    app.http.server.configuration.hostname = hostname
    app.http.server.configuration.port = port

    // Enable gzip response compression for JSON/text responses
    app.http.server.configuration.responseCompression = .enabled

    app.logger.info("ILS Backend starting on http://\(hostname):\(port)")

    // Bonjour/mDNS auto-discovery — publish _ils._tcp so iOS clients can find the backend
    // BonjourPublisherService is @MainActor so NetService runs on the main RunLoop.
    let bonjour = await MainActor.run {
        let service = BonjourPublisherService()
        service.start(port: port)
        return service
    }
    app.storage[BonjourPublisherKey.self] = bonjour
}

// MARK: - Bonjour Storage Key

private struct BonjourPublisherKey: StorageKey {
    typealias Value = BonjourPublisherService
}
