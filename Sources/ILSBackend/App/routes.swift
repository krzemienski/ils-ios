import Vapor

func routes(_ app: Application) throws {
    // Health check endpoints (registered at root, outside /api/v1)
    try app.register(collection: HealthController())

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
    try api.register(collection: SystemController())
    try api.register(collection: TeamsController(fileService: TeamsFileService(), executorService: TeamsExecutorService()))
    try api.register(collection: TunnelController())
}
