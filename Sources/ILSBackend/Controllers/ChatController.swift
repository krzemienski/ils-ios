import Vapor
import Fluent
import ILSShared

struct ChatController: RouteCollection {
    let executor = ClaudeExecutorService()

    func boot(routes: RoutesBuilder) throws {
        let chat = routes.grouped("chat")

        chat.post("stream", use: stream)
        chat.webSocket("ws", ":sessionId", onUpgrade: handleWebSocket)
        chat.post("permission", ":requestId", use: permission)
        chat.post("cancel", ":sessionId", use: cancel)
    }

    /// POST /chat/stream - Stream chat response via SSE
    @Sendable
    func stream(req: Request) async throws -> Response {
        let input = try req.content.decode(ChatStreamRequest.self)

        // Check if Claude CLI is available
        let claudeAvailable = await executor.isAvailable()

        // If Claude CLI is not available, return an error (NO MOCKING)
        guard claudeAvailable else {
            throw Abort(.serviceUnavailable, reason: "Claude CLI is not available. Please ensure 'claude' is installed and in PATH.")
        }

        // Get or create session
        let sessionId: UUID
        if let existingSessionId = input.sessionId {
            sessionId = existingSessionId
        } else {
            // Create a new session if none provided
            let newSession = SessionModel(
                projectId: input.projectId,
                model: input.options?.model ?? "sonnet",
                permissionMode: input.options?.permissionMode ?? .default
            )
            try await newSession.save(on: req.db)
            sessionId = newSession.id!
        }

        // Save user message to database
        let userMessage = MessageModel(
            sessionId: sessionId,
            role: .user,
            content: input.prompt
        )
        try await userMessage.save(on: req.db)
        let userMessageId = userMessage.id!

        // Update session message count
        if let session = try await SessionModel.find(sessionId, on: req.db) {
            session.messageCount += 1
            try await session.save(on: req.db)
        }

        // Get project path if specified
        var projectPath: String?
        if let projectId = input.projectId {
            if let project = try await ProjectModel.find(projectId, on: req.db) {
                projectPath = project.path
            }
        }

        // Build execution options
        var options = ExecutionOptions(from: input.options)

        // If resuming a session, get the Claude session ID
        if let existingSessionId = input.sessionId {
            if let session = try await SessionModel.find(existingSessionId, on: req.db) {
                options.resume = session.claudeSessionId
            }
        }

        // Execute Claude CLI
        let stream = executor.execute(
            prompt: input.prompt,
            workingDirectory: projectPath,
            options: options
        )

        // Return SSE response with message persistence
        return StreamingService.createSSEResponseWithPersistence(
            from: stream,
            sessionId: sessionId,
            userMessageId: userMessageId,
            on: req
        )
    }

    /// WebSocket handler for /chat/ws/:sessionId
    @Sendable
    func handleWebSocket(req: Request, ws: WebSocket) async {
        guard let sessionIdString = req.parameters.get("sessionId"),
              let sessionId = UUID(uuidString: sessionIdString) else {
            try? await ws.close(code: .policyViolation)
            return
        }

        // Get project path for this session
        var projectPath: String?
        if let session = try? await SessionModel.query(on: req.db)
            .filter(\.$id == sessionId)
            .with(\.$project)
            .first() {
            projectPath = session.project?.path
        }

        let wsService = WebSocketService(executor: executor)
        await wsService.handleConnection(
            ws,
            sessionId: sessionIdString,
            projectPath: projectPath,
            on: req
        )
    }

    /// POST /chat/permission/:requestId - Submit permission decision
    @Sendable
    func permission(req: Request) async throws -> APIResponse<AcknowledgedResponse> {
        guard let requestId = req.parameters.get("requestId") else {
            throw Abort(.badRequest, reason: "Invalid request ID")
        }

        let input = try req.content.decode(PermissionDecision.self)

        // In a full implementation, this would communicate with the running Claude process
        req.logger.info("Permission decision for \(requestId): \(input.decision)")

        return APIResponse(
            success: true,
            data: AcknowledgedResponse()
        )
    }

    /// POST /chat/cancel/:sessionId - Cancel an active chat
    @Sendable
    func cancel(req: Request) async throws -> APIResponse<CancelledResponse> {
        guard let sessionId = req.parameters.get("sessionId") else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        await executor.cancel(sessionId: sessionId)

        return APIResponse(
            success: true,
            data: CancelledResponse()
        )
    }
}
