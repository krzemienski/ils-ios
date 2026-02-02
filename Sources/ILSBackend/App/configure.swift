import Vapor
import Fluent
import FluentSQLiteDriver

func configure(_ app: Application) async throws {
    // CORS middleware for iOS app
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
        allowedHeaders: [
            .accept, .authorization, .contentType, .origin, .xRequestedWith,
            .init("X-Session-ID"), .init("X-Project-ID")
        ],
        allowCredentials: true
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)

    // Error middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // Database configuration
    let dbPath = app.directory.workingDirectory + "ils.sqlite"
    app.databases.use(.sqlite(.file(dbPath)), as: .sqlite)

    // Register migrations
    app.migrations.add(CreateProjects())
    app.migrations.add(CreateSessions())
    app.migrations.add(CreateMessages())

    // Run migrations
    try await app.autoMigrate()

    // Register routes
    try routes(app)

    // Server configuration
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 8080

    app.logger.info("ILS Backend starting on http://0.0.0.0:8080")
}
