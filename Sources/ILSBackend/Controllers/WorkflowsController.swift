import Vapor
import ILSShared

/// Controller for workflow automation management operations.
///
/// Routes:
/// - `GET /workflows`: List all workflows
/// - `POST /workflows`: Create a new workflow
/// - `GET /workflows/:id`: Get a specific workflow
/// - `PUT /workflows/:id`: Update an existing workflow
/// - `DELETE /workflows/:id`: Delete a workflow
/// - `POST /workflows/:id/execute`: Execute a workflow
/// - `POST /workflows/:id/pause`: Pause a running workflow
/// - `POST /workflows/:id/cancel`: Cancel a workflow execution
/// - `GET /workflows/:id/executions/latest`: Stream execution progress via SSE
/// - `POST /workflows/:id/schedules`: Create a schedule for a workflow
/// - `GET /workflows/:id/schedules`: List schedules for a workflow
/// - `GET /workflows/:id/schedules/:scheduleId`: Get a specific schedule
/// - `PUT /workflows/:id/schedules/:scheduleId`: Update a schedule
/// - `DELETE /workflows/:id/schedules/:scheduleId`: Delete a schedule
struct WorkflowsController: RouteCollection {
    let fileService: WorkflowFileService
    let executionEngine: WorkflowExecutionEngine
    let scheduler: WorkflowScheduler

    init(fileService: WorkflowFileService, executionEngine: WorkflowExecutionEngine, scheduler: WorkflowScheduler) {
        self.fileService = fileService
        self.executionEngine = executionEngine
        self.scheduler = scheduler
    }

    func boot(routes: RoutesBuilder) throws {
        let workflows = routes.grouped("workflows")
        workflows.get(use: list)
        workflows.post(use: create)
        workflows.get(":id", use: detail)
        workflows.put(":id", use: update)
        workflows.delete(":id", use: remove)
        workflows.post(":id", "execute", use: execute)
        workflows.post(":id", "pause", use: pause)
        workflows.post(":id", "cancel", use: cancel)
        workflows.get(":id", "executions", "latest", use: streamLatestExecution)

        // Schedule routes
        workflows.post(":id", "schedules", use: createSchedule)
        workflows.get(":id", "schedules", use: listSchedules)
        workflows.get(":id", "schedules", ":scheduleId", use: getSchedule)
        workflows.put(":id", "schedules", ":scheduleId", use: updateSchedule)
        workflows.delete(":id", "schedules", ":scheduleId", use: deleteSchedule)
    }

    // MARK: - Workflow Management

    /// List all workflows, sorted by most recently updated.
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with array of Workflow objects
    @Sendable
    func list(req: Request) async throws -> APIResponse<[Workflow]> {
        let workflows = try await fileService.listWorkflows()
        return APIResponse(success: true, data: workflows)
    }

    /// Create a new workflow with the given name and optional description.
    ///
    /// - Parameter req: Vapor Request with CreateWorkflowRequest body (name, description, nodes, connections)
    /// - Returns: APIResponse with the newly created Workflow
    @Sendable
    func create(req: Request) async throws -> APIResponse<Workflow> {
        let request = try req.content.decode(CreateWorkflowRequest.self)

        // Validate input lengths
        try PathSanitizer.validateStringLength(request.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(request.description, maxLength: 1000, fieldName: "description")

        let workflow = try await fileService.createWorkflow(
            name: request.name,
            description: request.description,
            nodes: request.nodes ?? [],
            connections: request.connections ?? []
        )

        return APIResponse(success: true, data: workflow)
    }

    /// Get a specific workflow by ID.
    ///
    /// - Parameter req: Vapor Request with id route parameter
    /// - Returns: APIResponse with the Workflow
    @Sendable
    func detail(req: Request) async throws -> APIResponse<Workflow> {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Workflow id is required")
        }

        guard let workflow = try await fileService.getWorkflow(id: id) else {
            throw Abort(.notFound, reason: "Workflow '\(id)' not found")
        }

        return APIResponse(success: true, data: workflow)
    }

    /// Update an existing workflow.
    ///
    /// - Parameter req: Vapor Request with id route parameter and UpdateWorkflowRequest body
    /// - Returns: APIResponse with the updated Workflow
    @Sendable
    func update(req: Request) async throws -> APIResponse<Workflow> {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Workflow id is required")
        }

        let request = try req.content.decode(UpdateWorkflowRequest.self)

        // Validate input lengths
        try PathSanitizer.validateOptionalStringLength(request.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(request.description, maxLength: 1000, fieldName: "description")

        let workflow = try await fileService.updateWorkflow(
            id: id,
            name: request.name,
            description: request.description,
            status: request.status,
            nodes: request.nodes,
            connections: request.connections
        )

        return APIResponse(success: true, data: workflow)
    }

    /// Delete a workflow by ID.
    ///
    /// - Parameter req: Vapor Request with id route parameter
    /// - Returns: APIResponse with DeletedResponse confirming deletion
    @Sendable
    func remove(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Workflow id is required")
        }

        try await fileService.deleteWorkflow(id: id)

        return APIResponse(success: true, data: DeletedResponse(deleted: true))
    }

    // MARK: - Workflow Execution

    /// Execute a workflow.
    ///
    /// - Parameter req: Vapor Request with id route parameter and optional ExecuteWorkflowRequest body
    /// - Returns: APIResponse with the WorkflowExecution tracking execution state
    @Sendable
    func execute(req: Request) async throws -> APIResponse<WorkflowExecution> {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Workflow id is required")
        }

        guard let workflow = try await fileService.getWorkflow(id: id) else {
            throw Abort(.notFound, reason: "Workflow '\(id)' not found")
        }

        // Decode optional parameters
        let request = try? req.content.decode(ExecuteWorkflowRequest.self)

        // Start execution
        let execution = try await executionEngine.startExecution(
            workflow: workflow,
            parameters: request?.parameters
        )

        // Mark workflow as executed
        try await fileService.markExecuted(id: id)

        return APIResponse(success: true, data: execution)
    }

    /// Pause a running workflow execution.
    ///
    /// - Parameter req: Vapor Request with id route parameter
    /// - Returns: APIResponse with the updated WorkflowExecution
    @Sendable
    func pause(req: Request) async throws -> APIResponse<WorkflowExecution> {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Workflow id is required")
        }

        // Verify workflow exists
        guard try await fileService.getWorkflow(id: id) != nil else {
            throw Abort(.notFound, reason: "Workflow '\(id)' not found")
        }

        // Find the active execution for this workflow
        let executions = await executionEngine.listExecutions()
        guard let activeExecution = executions.first(where: { $0.workflowId == id && $0.status == .running }) else {
            throw Abort(.notFound, reason: "No running execution found for workflow '\(id)'")
        }

        let execution = try await executionEngine.pauseExecution(executionId: activeExecution.id)

        return APIResponse(success: true, data: execution)
    }

    /// Cancel a workflow execution.
    ///
    /// - Parameter req: Vapor Request with id route parameter
    /// - Returns: APIResponse with the updated WorkflowExecution
    @Sendable
    func cancel(req: Request) async throws -> APIResponse<WorkflowExecution> {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Workflow id is required")
        }

        // Verify workflow exists
        guard try await fileService.getWorkflow(id: id) != nil else {
            throw Abort(.notFound, reason: "Workflow '\(id)' not found")
        }

        // Find the active execution for this workflow
        let executions = await executionEngine.listExecutions()
        guard let activeExecution = executions.first(where: {
            $0.workflowId == id && ($0.status == .running || $0.status == .paused || $0.status == .pending)
        }) else {
            throw Abort(.notFound, reason: "No active execution found for workflow '\(id)'")
        }

        let execution = try await executionEngine.cancelExecution(executionId: activeExecution.id)

        return APIResponse(success: true, data: execution)
    }

    /// Stream execution progress for the latest execution of a workflow via Server-Sent Events.
    ///
    /// Polls the execution engine for state updates and streams progress events until
    /// the execution reaches a terminal state (completed, failed, cancelled).
    ///
    /// - Parameter req: Vapor Request with id route parameter
    /// - Returns: SSE Response with streaming execution progress events
    @Sendable
    func streamLatestExecution(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Workflow id is required")
        }

        // Verify workflow exists
        guard try await fileService.getWorkflow(id: id) != nil else {
            throw Abort(.notFound, reason: "Workflow '\(id)' not found")
        }

        // Find the latest execution for this workflow
        let executions = await executionEngine.listExecutions()
        guard let latestExecution = executions
            .filter({ $0.workflowId == id })
            .sorted(by: { ($0.startedAt ?? Date.distantPast) > ($1.startedAt ?? Date.distantPast) })
            .first else {
            throw Abort(.notFound, reason: "No execution found for workflow '\(id)'")
        }

        req.logger.debug("[WORKFLOW-STREAM] Streaming execution progress for workflow: \(id), execution: \(latestExecution.id)")

        // Create stream that polls execution state
        let stream = AsyncThrowingStream<StreamMessage, Error> { continuation in
            Task {
                let executionId = latestExecution.id
                var lastStatus: WorkflowExecutionStatus?
                var lastProgress: Double?
                var lastNodeId: String?

                // Poll execution state until terminal state reached
                while true {
                    // Get current execution state
                    guard let currentExecution = await self.executionEngine.getExecution(executionId: executionId) else {
                        continuation.finish(throwing: Abort(.gone, reason: "Execution '\(executionId)' no longer exists"))
                        return
                    }

                    // Send update if state changed
                    let statusChanged = lastStatus != currentExecution.status
                    let progressChanged = lastProgress != currentExecution.progress
                    let nodeChanged = lastNodeId != currentExecution.currentNodeId

                    if statusChanged || progressChanged || nodeChanged {
                        // Encode execution as JSON string for delta
                        let encoder = JSONEncoder()
                        encoder.dateEncodingStrategy = .iso8601

                        if let jsonData = try? encoder.encode(currentExecution),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            // Create execution progress event
                            let event = StreamMessage.streamEvent(StreamEventMessage(
                                eventType: "execution_progress",
                                delta: .textDelta(jsonString)
                            ))
                            continuation.yield(event)
                        }

                        lastStatus = currentExecution.status
                        lastProgress = currentExecution.progress
                        lastNodeId = currentExecution.currentNodeId

                        req.logger.debug("[WORKFLOW-STREAM] Progress update: status=\(currentExecution.status), progress=\(currentExecution.progress ?? 0.0), node=\(currentExecution.currentNodeId ?? "nil")")
                    }

                    // Check for terminal state
                    switch currentExecution.status {
                    case .completed, .failed, .cancelled:
                        req.logger.debug("[WORKFLOW-STREAM] Execution reached terminal state: \(currentExecution.status)")
                        continuation.finish()
                        return
                    case .pending, .running, .paused:
                        // Continue polling
                        break
                    }

                    // Poll interval: 500ms
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }

        // Return SSE response
        return StreamingService.createSSEResponse(from: stream, on: req)
    }

    // MARK: - Workflow Scheduling

    /// Create a schedule for a workflow.
    ///
    /// - Parameter req: Vapor Request with id route parameter and CreateScheduleRequest body
    /// - Returns: APIResponse with the created WorkflowSchedule (HTTP 201)
    @Sendable
    func createSchedule(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Workflow id is required")
        }

        // Verify workflow exists
        guard try await fileService.getWorkflow(id: id) != nil else {
            throw Abort(.notFound, reason: "Workflow '\(id)' not found")
        }

        let request = try req.content.decode(CreateScheduleRequest.self)

        // Validate cron expression length
        try PathSanitizer.validateStringLength(request.cron, maxLength: 100, fieldName: "cron")

        let schedule = try await scheduler.createSchedule(
            workflowId: id,
            cron: request.cron,
            enabled: request.enabled,
            timezone: request.timezone
        )

        // Create 201 Created response
        let response = try await APIResponse(success: true, data: schedule)
            .encodeResponse(status: .created, for: req)

        return response
    }

    /// List all schedules for a workflow.
    ///
    /// - Parameter req: Vapor Request with id route parameter
    /// - Returns: APIResponse with array of WorkflowSchedule objects
    @Sendable
    func listSchedules(req: Request) async throws -> APIResponse<[WorkflowSchedule]> {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Workflow id is required")
        }

        // Verify workflow exists
        guard try await fileService.getWorkflow(id: id) != nil else {
            throw Abort(.notFound, reason: "Workflow '\(id)' not found")
        }

        let schedules = await scheduler.listSchedules(workflowId: id)

        return APIResponse(success: true, data: schedules)
    }

    /// Get a specific schedule for a workflow.
    ///
    /// - Parameter req: Vapor Request with id and scheduleId route parameters
    /// - Returns: APIResponse with the WorkflowSchedule
    @Sendable
    func getSchedule(req: Request) async throws -> APIResponse<WorkflowSchedule> {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Workflow id is required")
        }

        guard let scheduleId = req.parameters.get("scheduleId") else {
            throw Abort(.badRequest, reason: "Schedule id is required")
        }

        // Verify workflow exists
        guard try await fileService.getWorkflow(id: id) != nil else {
            throw Abort(.notFound, reason: "Workflow '\(id)' not found")
        }

        guard let schedule = await scheduler.getSchedule(scheduleId: scheduleId) else {
            throw Abort(.notFound, reason: "Schedule '\(scheduleId)' not found")
        }

        // Verify schedule belongs to this workflow
        guard schedule.workflowId == id else {
            throw Abort(.notFound, reason: "Schedule '\(scheduleId)' does not belong to workflow '\(id)'")
        }

        return APIResponse(success: true, data: schedule)
    }

    /// Update a schedule for a workflow.
    ///
    /// - Parameter req: Vapor Request with id and scheduleId route parameters and UpdateScheduleRequest body
    /// - Returns: APIResponse with the updated WorkflowSchedule
    @Sendable
    func updateSchedule(req: Request) async throws -> APIResponse<WorkflowSchedule> {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Workflow id is required")
        }

        guard let scheduleId = req.parameters.get("scheduleId") else {
            throw Abort(.badRequest, reason: "Schedule id is required")
        }

        // Verify workflow exists
        guard try await fileService.getWorkflow(id: id) != nil else {
            throw Abort(.notFound, reason: "Workflow '\(id)' not found")
        }

        // Verify schedule exists and belongs to this workflow
        guard let existingSchedule = await scheduler.getSchedule(scheduleId: scheduleId) else {
            throw Abort(.notFound, reason: "Schedule '\(scheduleId)' not found")
        }

        guard existingSchedule.workflowId == id else {
            throw Abort(.notFound, reason: "Schedule '\(scheduleId)' does not belong to workflow '\(id)'")
        }

        let request = try req.content.decode(UpdateScheduleRequest.self)

        // Validate cron expression length if provided
        try PathSanitizer.validateOptionalStringLength(request.cron, maxLength: 100, fieldName: "cron")

        let schedule = try await scheduler.updateSchedule(
            scheduleId: scheduleId,
            cron: request.cron,
            enabled: request.enabled,
            timezone: request.timezone
        )

        return APIResponse(success: true, data: schedule)
    }

    /// Delete a schedule for a workflow.
    ///
    /// - Parameter req: Vapor Request with id and scheduleId route parameters
    /// - Returns: APIResponse with DeletedResponse confirming deletion
    @Sendable
    func deleteSchedule(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Workflow id is required")
        }

        guard let scheduleId = req.parameters.get("scheduleId") else {
            throw Abort(.badRequest, reason: "Schedule id is required")
        }

        // Verify workflow exists
        guard try await fileService.getWorkflow(id: id) != nil else {
            throw Abort(.notFound, reason: "Workflow '\(id)' not found")
        }

        // Verify schedule exists and belongs to this workflow
        guard let existingSchedule = await scheduler.getSchedule(scheduleId: scheduleId) else {
            throw Abort(.notFound, reason: "Schedule '\(scheduleId)' not found")
        }

        guard existingSchedule.workflowId == id else {
            throw Abort(.notFound, reason: "Schedule '\(scheduleId)' does not belong to workflow '\(id)'")
        }

        try await scheduler.deleteSchedule(scheduleId: scheduleId)

        return APIResponse(success: true, data: DeletedResponse(deleted: true))
    }
}
