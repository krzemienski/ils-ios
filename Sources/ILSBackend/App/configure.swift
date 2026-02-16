import Vapor
import Fluent
import FluentSQLiteDriver

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
            .init("X-Session-ID"), .init("X-Project-ID")
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

    // Request size limits
    app.routes.defaultMaxBodySize = "10mb"

    // Database configuration
    let dbPath = app.directory.workingDirectory + "ils.sqlite"
    app.databases.use(.sqlite(.file(dbPath)), as: .sqlite)

    // Register migrations
    app.migrations.add(CreateProjects())
    app.migrations.add(CreateSessions())
    app.migrations.add(CreateMessages())
    app.migrations.add(CreateThemes())
    app.migrations.add(CreateCachedResults())
    app.migrations.add(CreateFleetHosts())
    app.migrations.add(AddDatabaseIndexes())

    // Run migrations
    try await app.autoMigrate()

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
