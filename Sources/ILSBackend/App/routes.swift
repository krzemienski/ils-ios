import Vapor

func routes(_ app: Application) throws {
    // Health check endpoints (registered at root, outside /api/v1)
    try app.register(collection: HealthController())

    // API v1 routes
    let api = app.grouped("api", "v1")

    // Shared services
    let fileSystem = FileSystemService()
    let executor = ClaudeExecutorService()

    // Public routes (require API key only via global middleware)
    try api.register(collection: ProjectsController(fileSystem: fileSystem))
    try api.register(collection: SessionsController(fileSystem: fileSystem))
    try api.register(collection: ChatController())
    try api.register(collection: SkillsController(fileSystem: fileSystem))
    try api.register(collection: MCPController(fileSystem: fileSystem))
    try api.register(collection: PluginsController(fileSystem: fileSystem))
    try api.register(collection: StatsController(fileSystem: fileSystem))
    try api.register(collection: SessionHealthController(fileSystem: fileSystem))
    try api.register(collection: SessionBackupController())
    try api.register(collection: UsageController())
    try api.register(collection: ThemesController())
    try api.register(collection: TeamsController(fileService: TeamsFileService(), executorService: TeamsExecutorService()))
    try api.register(collection: CheckpointsController())
    try api.register(collection: TemplatesController())
    try api.register(collection: SuggestionsController(fileSystem: fileSystem))
    try api.register(collection: SSHController())
    try api.register(collection: ActivityFeedController())
    try api.register(collection: TerminalController())
    try api.register(collection: RecordingController())
    try api.register(collection: AnalyticsController(fileSystem: fileSystem))
    try api.register(collection: AgentQueueController(queueService: AgentQueueService(db: app.db, executor: ClaudeExecutorService())))
    try api.register(collection: PermissionsController(executor: executor))
    try api.register(collection: AutomationRulesController())

    // Admin-protected routes (require X-Admin-Token when ILS_ADMIN_KEY is set)
    let admin = api.grouped(AdminMiddleware())
    try admin.register(collection: ConfigController(fileSystem: fileSystem))
    try admin.register(collection: SystemController())
    try admin.register(collection: HostProfileController())
    try admin.register(collection: TunnelController())
    try admin.register(collection: DataErasureController())
}
