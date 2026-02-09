import Vapor
import Fluent
import ILSShared

/// Controller for chat operations including streaming responses and WebSocket connections.
///
/// Routes:
/// - `POST /chat/stream`: Stream Claude CLI responses via Server-Sent Events
/// - `WS /chat/ws/:sessionId`: WebSocket connection for bidirectional chat
/// - `POST /chat/permission/:requestId`: Submit permission decisions
/// - `POST /chat/cancel/:sessionId`: Cancel active chat execution
struct ChatController: RouteCollection {
    let executor = ClaudeExecutorService()

    func boot(routes: RoutesBuilder) throws {
        let chat = routes.grouped("chat")

        chat.post("stream", use: stream)
        chat.webSocket("ws", ":sessionId", onUpgrade: handleWebSocket)
        chat.post("permission", ":sessionId", ":requestId", use: permission)
        chat.post("cancel", ":sessionId", use: cancel)
    }

    /// Stream chat response via Server-Sent Events.
    ///
    /// Executes Claude CLI with the provided prompt and streams responses as SSE events.
    /// Automatically persists messages to database on completion.
    ///
    /// - Parameter req: Vapor Request containing ChatStreamRequest body
    /// - Returns: SSE Response with streaming events
    @Sendable
    func stream(req: Request) async throws -> Response {
        let input = try req.content.decode(ChatStreamRequest.self)

        guard !input.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.unprocessableEntity, reason: "Prompt cannot be empty")
        }

        req.logger.debug("[STREAM] Received stream request, prompt: \(input.prompt.prefix(50))")

        // Check if Claude CLI is available
        let claudeAvailable = await executor.isAvailable()
        req.logger.debug("[STREAM] Claude available: \(claudeAvailable)")

        // If Claude CLI is not available, return an error (NO MOCKING)
        guard claudeAvailable else {
            throw Abort(.serviceUnavailable, reason: "Claude CLI is not available. Please ensure 'claude' is installed and in PATH.")
        }

        // Get or create session — if a sessionId is provided but doesn't exist in DB
        // (e.g. client-generated UUID for "New Session"), create it on the fly.
        let sessionId: UUID
        if let existingSessionId = input.sessionId {
            if try await SessionModel.find(existingSessionId, on: req.db) != nil {
                sessionId = existingSessionId
            } else {
                let newSession = SessionModel(
                    id: existingSessionId,
                    projectId: input.projectId,
                    model: input.options?.model ?? "sonnet",
                    permissionMode: input.options?.permissionMode ?? .default
                )
                try await newSession.save(on: req.db)
                sessionId = existingSessionId
            }
        } else {
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
                req.logger.debug("[STREAM] Resume session: \(session.claudeSessionId ?? "nil")")
            }
        }

        req.logger.debug("[STREAM] Calling executor.execute()")

        // Execute Claude CLI
        let stream = executor.execute(
            prompt: input.prompt,
            workingDirectory: projectPath,
            options: options
        )

        req.logger.debug("[STREAM] executor.execute() returned stream, creating SSE response")

        // Return SSE response with message persistence
        return StreamingService.createSSEResponseWithPersistence(
            from: stream,
            sessionId: sessionId,
            userMessageId: userMessageId,
            on: req
        )
    }

    /// Handle WebSocket connection for bidirectional chat.
    /// - Parameters:
    ///   - req: Vapor Request with sessionId parameter
    ///   - ws: WebSocket connection
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

    /// Submit permission decision for a pending request.
    ///
    /// Forwards the decision to the running Claude CLI process via stdin.
    /// The process must be alive and in `delegate` permission mode for this to work.
    ///
    /// - Parameter req: Vapor Request with sessionId and requestId parameters, PermissionDecision body
    /// - Returns: APIResponse with acknowledgment
    @Sendable
    func permission(req: Request) async throws -> APIResponse<AcknowledgedResponse> {
        guard let sessionId = req.parameters.get("sessionId") else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }
        guard let requestId = req.parameters.get("requestId") else {
            throw Abort(.badRequest, reason: "Invalid request ID")
        }

        let input = try req.content.decode(PermissionDecision.self)
        req.logger.info("Permission decision for \(requestId) (session \(sessionId)): \(input.decision)")

        let sent = await executor.sendPermissionResponse(
            sessionId: sessionId,
            requestId: requestId,
            decision: input.decision
        )

        guard sent else {
            throw Abort(.gone, reason: "No active process for session \(sessionId) — it may have already exited")
        }

        return APIResponse(
            success: true,
            data: AcknowledgedResponse()
        )
    }

    /// Cancel an active chat session's Claude CLI process.
    /// - Parameter req: Vapor Request with sessionId parameter
    /// - Returns: APIResponse with cancellation confirmation
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
