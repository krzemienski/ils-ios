import Vapor
import ILSShared

func routes(_ app: Application) throws {
    // Health check endpoints (registered at root, outside /api/v1)
    try app.register(collection: HealthController())

    // API v1 routes
    let api = app.grouped("api", "v1")

    // Shared services
    let fileSystem = FileSystemService()
    let executor = ClaudeExecutorService()

    // Standard routes (require API key only via global middleware)
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
    try api.register(collection: ActivityFeedController())
    try api.register(collection: RecordingController())
    try api.register(collection: AnalyticsController(fileSystem: fileSystem))
    try api.register(collection: FeedbackController())
    try api.register(collection: AuditController())
    let workflowExecutionEngine = WorkflowExecutionEngine()
    let workflowScheduler = WorkflowScheduler(executionEngine: workflowExecutionEngine)
    try api.register(collection: WorkflowsController(fileService: WorkflowFileService(), executionEngine: workflowExecutionEngine, scheduler: workflowScheduler))

    // Elevated routes (require auth when network-exposed via SecurityPolicyMiddleware)
    let elevated = api.grouped(SecurityPolicyMiddleware())
    try elevated.register(collection: SSHController())
    try elevated.register(collection: TerminalController())
    try elevated.register(collection: PermissionsController(executor: executor))
    try elevated.register(collection: AutomationRulesController())
    try elevated.register(collection: AgentQueueController(queueService: AgentQueueService(db: app.db, executor: ClaudeExecutorService())))

    // Admin-protected routes (require X-Admin-Token when ILS_ADMIN_KEY is set)
    let admin = api.grouped(AdminMiddleware())
    try admin.register(collection: ConfigController(fileSystem: fileSystem))
    try admin.register(collection: SystemController())
    try admin.register(collection: HostProfileController())
    try admin.register(collection: TunnelController())
    try admin.register(collection: DataErasureController())
    try admin.register(collection: PairingController())

    // Security abuse log endpoint (admin-only)
    admin.get("security", "abuse-log") { req async throws -> Response in
        guard let abuseService = req.application.storage[AbuseDetectionServiceKey.self] else {
            let empty = SecurityAuditEventsResponse(items: [], total: 0)
            let response = Response(status: .ok)
            try response.content.encode(empty, as: .json)
            return response
        }

        let limit = req.query[Int.self, at: "limit"] ?? 100
        let categoryRaw = req.query[String.self, at: "category"]
        let category = categoryRaw.flatMap { SecurityAuditCategory(rawValue: $0) }

        let result = await abuseService.recentEvents(limit: limit, category: category)
        let response = Response(status: .ok)
        try response.content.encode(result, as: .json)
        return response
    }
}
