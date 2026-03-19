import Vapor
import Fluent
import ILSShared

/// In-memory tracker for concurrent streaming sessions per client IP.
///
/// NET-007: Limits each IP to 1 active SSE stream at a time to prevent resource exhaustion.
/// Thread-safe via Swift actor isolation.
actor StreamingSessionTracker {
    private var activeSessions: [String: Int] = [:]

    /// Attempt to register a new streaming session for `ip`.
    /// Returns `true` if allowed (count was 0), `false` if already streaming.
    func tryAcquire(ip: String) -> Bool {
        let current = activeSessions[ip] ?? 0
        guard current == 0 else { return false }
        activeSessions[ip] = 1
        return true
    }

    /// Release the streaming slot for `ip` when the stream ends.
    func release(ip: String) {
        activeSessions[ip] = nil
    }
}

/// Controller for chat operations including streaming responses and WebSocket connections.
///
/// Routes:
/// - `POST /chat/stream`: Stream Claude CLI responses via Server-Sent Events
/// - `WS /chat/ws/:sessionId`: WebSocket connection for bidirectional chat
/// - `POST /chat/permission/:requestId`: Submit permission decisions
/// - `POST /chat/cancel/:sessionId`: Cancel active chat execution
///
/// NET-007: Per-IP rate limiting (10 req/min) is enforced by `RateLimitMiddleware` registered
/// in `configure.swift`. Concurrent stream limiting (1 active stream per IP) is enforced here
/// via `StreamingSessionTracker` because `RateLimitMiddleware` cannot track long-lived SSE
/// connections — it operates at request-start time, not connection-lifetime.
struct ChatController: RouteCollection {
    let executor = ClaudeExecutorService()
    // NET-007: Shared across all requests handled by this controller instance.
    // A new ChatController is created per app lifecycle so this is effectively app-scoped.
    private let streamingTracker = StreamingSessionTracker()

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

        // Validate input lengths (1MB max for prompt)
        try PathSanitizer.validateStringLength(input.prompt, maxLength: 1_000_000, fieldName: "prompt")
        try PathSanitizer.validateOptionalStringLength(input.options?.systemPrompt, maxLength: 100_000, fieldName: "systemPrompt")
        try PathSanitizer.validateOptionalStringLength(input.options?.appendSystemPrompt, maxLength: 100_000, fieldName: "appendSystemPrompt")
        try PathSanitizer.validateOptionalStringLength(input.options?.model, maxLength: 64, fieldName: "model")
        try PathSanitizer.validateOptionalStringLength(input.options?.resume, maxLength: 255, fieldName: "resume")

        req.logger.debug("[STREAM] Received stream request, prompt: \(input.prompt.prefix(50))")

        // Check if Claude CLI is available
        let claudeAvailable = await executor.isAvailable()
        req.logger.debug("[STREAM] Claude available: \(claudeAvailable)")

        // If Claude CLI is not available, return an error (NO MOCKING)
        guard claudeAvailable else {
            throw Abort(.serviceUnavailable, reason: "Claude CLI is not available. Please ensure 'claude' is installed and in PATH.")
        }

        // NET-007: Limit to 1 concurrent streaming session per client IP.
        // X-Forwarded-For is preferred when behind a reverse proxy (same logic as RateLimitMiddleware).
        let clientIP: String
        if let xff = req.headers.first(name: .xForwardedFor) {
            clientIP = xff.split(separator: ",").first
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                ?? req.peerAddress?.ipAddress
                ?? "unknown"
        } else {
            clientIP = req.peerAddress?.ipAddress ?? req.remoteAddress?.ipAddress ?? "unknown"
        }

        let streamAllowed = await streamingTracker.tryAcquire(ip: clientIP)
        guard streamAllowed else {
            throw Abort(.tooManyRequests, reason: "A streaming session is already active for this client. Wait for it to complete before starting a new one.")
        }

        // NET-007: Release the concurrent-stream slot on any early exit (DB errors, validation
        // failures, etc.) that occur between acquisition and stream-wrapper creation.
        do {
            return try await buildStreamResponse(
                req: req,
                input: input,
                clientIP: clientIP
            )
        } catch {
            await streamingTracker.release(ip: clientIP)
            throw error
        }
    }

    /// Builds the SSE response after a streaming slot has been acquired for `clientIP`.
    /// Separated from `stream()` so `streamingTracker.release` can be called on any early throw.
    private func buildStreamResponse(
        req: Request,
        input: ChatStreamRequest,
        clientIP: String
    ) async throws -> Response {
        // Get or create session — if a sessionId is provided but doesn't exist in DB
        // (e.g. client-generated UUID for "New Session"), create it on the fly.
        // If client provides options.resume (claudeSessionId), store it on the session.
        let sessionId: UUID
        if let existingSessionId = input.sessionId {
            if try await SessionModel.find(existingSessionId, on: req.db) != nil {
                sessionId = existingSessionId
            } else {
                let newSession = SessionModel(
                    id: existingSessionId,
                    claudeSessionId: input.options?.resume,
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

        // Process attachments from the request.
        // Image attachments → ExecutionImageAttachment (forwarded to Claude CLI).
        // Text attachments → prepend decoded file content to the prompt.
        var prompt = input.prompt
        if let attachments = input.attachments, !attachments.isEmpty {
            req.logger.debug("[STREAM] Processing \(attachments.count) attachment(s)")

            let imageAttachments = attachments.filter { $0.mimeType.hasPrefix("image/") }
            let textAttachments  = attachments.filter { $0.mimeType.hasPrefix("text/") }

            // Validate: at most 5 image attachments per message.
            guard imageAttachments.count <= 5 else {
                throw Abort(.unprocessableEntity, reason: "Maximum 5 image attachments allowed per message")
            }

            // Validate: combined raw data size must not exceed 20 MB.
            // Base64 encodes 3 bytes as 4 chars, so estimate raw bytes as count * 3 / 4.
            let combinedBytes = attachments.reduce(0) { $0 + ($1.data.count * 3 / 4) }
            guard combinedBytes <= 20 * 1024 * 1024 else {
                throw Abort(.unprocessableEntity, reason: "Combined attachment size exceeds 20 MB limit")
            }

            // Map image attachments → ExecutionImageAttachment.
            if !imageAttachments.isEmpty {
                options.images = imageAttachments.map {
                    ExecutionImageAttachment(mediaType: $0.mimeType, data: $0.data)
                }
            }

            // Prepend text file contents before the user's prompt.
            if !textAttachments.isEmpty {
                var textPrefix = ""
                for attachment in textAttachments {
                    if let decoded = Data(base64Encoded: attachment.data),
                       let content = String(data: decoded, encoding: .utf8) {
                        let name = attachment.filename ?? "attachment"
                        textPrefix += "--- \(name) ---\n\(content)\n\n"
                    }
                }
                if !textPrefix.isEmpty {
                    prompt = textPrefix + prompt
                }
            }
        }

        // If resuming a session, get the Claude session ID.
        // Prefer DB-stored claudeSessionId; fall back to client-provided resume.
        if let existingSessionId = input.sessionId {
            if let session = try await SessionModel.find(existingSessionId, on: req.db) {
                if let dbClaudeId = session.claudeSessionId {
                    options.resume = dbClaudeId
                }
                // else: keep options.resume from client (if provided via input.options)
                req.logger.debug("[STREAM] Resume session: \(options.resume ?? "nil")")
            }
        }

        req.logger.debug("[STREAM] Calling executor.execute()")

        // Execute Claude CLI
        let rawStream = executor.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            options: options
        )

        req.logger.debug("[STREAM] executor.execute() returned stream, creating SSE response")

        // NET-007: Wrap the raw stream so the concurrent-session slot is released
        // automatically when the stream finishes (whether normally, via error, or
        // via client disconnect). This is required because StreamingService runs the
        // stream body asynchronously inside Vapor's response writer — we cannot use
        // defer in this function to release the slot.
        let tracker = streamingTracker
        let stream = AsyncThrowingStream<StreamMessage, Error> { continuation in
            let task = Task {
                do {
                    for try await event in rawStream {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                await tracker.release(ip: clientIP)
            }
            continuation.onTermination = { _ in task.cancel() }
        }

        // Look up any registered Live Activity push token for this session.
        // The token is set by the iOS client after starting a Live Activity;
        // used to push content-state updates when the app is backgrounded.
        let liveActivityToken = try? await SessionModel.find(sessionId, on: req.db)?
            .liveActivityPushToken

        // Return SSE response with message persistence
        return StreamingService.createSSEResponseWithPersistence(
            from: stream,
            sessionId: sessionId,
            userMessageId: userMessageId,
            liveActivityPushToken: liveActivityToken,
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
