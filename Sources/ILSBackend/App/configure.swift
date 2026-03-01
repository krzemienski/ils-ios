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
    // v5.0 — Checkpoint system
    app.migrations.add(CreateSessionCheckpoints())

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
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = port

    // Enable gzip response compression for JSON/text responses
    app.http.server.configuration.responseCompression = .enabled

    app.logger.info("ILS Backend starting on http://0.0.0.0:\(port)")
}
