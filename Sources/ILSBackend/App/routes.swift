import Vapor

func routes(_ app: Application) throws {
    // Health check
    app.get("health") { req -> String in
        return "OK"
    }

    // API v1 routes
    let api = app.grouped("api", "v1")

    // Shared services
    let fileSystem = FileSystemService()

    // Register controllers
    try api.register(collection: ProjectsController(fileSystem: fileSystem))
    try api.register(collection: SessionsController(fileSystem: fileSystem))
    try api.register(collection: ChatController())
    try api.register(collection: SkillsController(fileSystem: fileSystem))
    try api.register(collection: MCPController(fileSystem: fileSystem))
    try api.register(collection: PluginsController(fileSystem: fileSystem))
    try api.register(collection: ConfigController(fileSystem: fileSystem))
    try api.register(collection: StatsController(fileSystem: fileSystem))
    try api.register(collection: ThemesController())
}
