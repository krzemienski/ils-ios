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

    // Read-only routes (require at least read-level authorization)
    let readRoutes = api.grouped(AuthorizationMiddleware(minimumLevel: .read))
    try readRoutes.register(collection: StatsController(fileSystem: fileSystem))
    try readRoutes.register(collection: SessionHealthController(fileSystem: fileSystem))
    try readRoutes.register(collection: UsageController())
    try readRoutes.register(collection: ConsumptionController())
    try readRoutes.register(collection: ActivityFeedController())
    try readRoutes.register(collection: AnalyticsController(fileSystem: fileSystem))
    try readRoutes.register(collection: ErrorPatternsController())

    // Write routes (require at least write-level authorization for mutations)
    let writeRoutes = api.grouped(AuthorizationMiddleware(minimumLevel: .write))
    try writeRoutes.register(collection: RecordingController())
    try writeRoutes.register(collection: ProjectsController(fileSystem: fileSystem))
    try writeRoutes.register(collection: SessionsController(fileSystem: fileSystem))
    try writeRoutes.register(collection: ChatController())
    try writeRoutes.register(collection: SkillsController(fileSystem: fileSystem))
    try writeRoutes.register(collection: MCPController(fileSystem: fileSystem))
    try writeRoutes.register(collection: PluginsController(fileSystem: fileSystem))
    try writeRoutes.register(collection: SessionBackupController())
    try writeRoutes.register(collection: ThemesController())
    try writeRoutes.register(collection: TeamsController(fileService: TeamsFileService(), executorService: TeamsExecutorService()))
    try writeRoutes.register(collection: CheckpointsController())
    try writeRoutes.register(collection: TemplatesController())
    try writeRoutes.register(collection: SuggestionsController(fileSystem: fileSystem))
    try writeRoutes.register(collection: SSHController())
    try writeRoutes.register(collection: TerminalController())
    try writeRoutes.register(collection: AgentQueueController(queueService: AgentQueueService(db: app.db, executor: ClaudeExecutorService())))
    try writeRoutes.register(collection: PermissionsController(executor: executor))
    try writeRoutes.register(collection: AutomationRulesController())
    try writeRoutes.register(collection: PermissionPoliciesController())
    try writeRoutes.register(collection: ApprovalPoliciesController())
    try writeRoutes.register(collection: FeedbackController())
    try writeRoutes.register(collection: AuditController())
    let workflowExecutionEngine = WorkflowExecutionEngine()
    let workflowScheduler = WorkflowScheduler(executionEngine: workflowExecutionEngine)
    try writeRoutes.register(collection: WorkflowsController(fileService: WorkflowFileService(), executionEngine: workflowExecutionEngine, scheduler: workflowScheduler))

    // Admin-protected routes (require admin-level authorization + X-Admin-Token)
    let admin = api.grouped(AdminMiddleware(), AuthorizationMiddleware(minimumLevel: .admin))
    try admin.register(collection: ConfigController(fileSystem: fileSystem))
    try admin.register(collection: SystemController())
    try admin.register(collection: HostProfileController())
    try admin.register(collection: TunnelController())
    try admin.register(collection: DataErasureController())
    try admin.register(collection: PairingController())
    try admin.register(collection: AuthController())

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
