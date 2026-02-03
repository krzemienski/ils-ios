import Vapor

func routes(_ app: Application) throws {
    // Health check
    app.get("health") { req -> String in
        return "OK"
    }

    // API v1 routes
    let api = app.grouped("api", "v1")

    // Register controllers
    try api.register(collection: ProjectsController())
    try api.register(collection: SessionsController())
    try api.register(collection: TemplatesController())
    try api.register(collection: ChatController())
    try api.register(collection: SkillsController())
    try api.register(collection: MCPController())
    try api.register(collection: PluginsController())
    try api.register(collection: ConfigController())
    try api.register(collection: StatsController())
}
