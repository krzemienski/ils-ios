import Vapor
import Fluent
import ILSShared

/// Controller for session management operations.
///
/// Routes:
/// - `GET /sessions`: List all sessions with optional project filter
/// - `POST /sessions`: Create a new session
/// - `GET /sessions/scan`: Scan for external Claude Code sessions
/// - `GET /sessions/:id`: Get a specific session
/// - `DELETE /sessions/:id`: Delete a session
/// - `POST /sessions/:id/fork`: Fork a session
/// - `GET /sessions/:id/messages`: Get session messages with pagination
/// - `GET /sessions/transcript/:encodedProjectPath/:sessionId`: Read external session transcript
struct SessionsController: RouteCollection {
    let fileSystem: FileSystemService

    init(fileSystem: FileSystemService) {
        self.fileSystem = fileSystem
    }

    func boot(routes: RoutesBuilder) throws {
        let sessions = routes.grouped("sessions")

        sessions.get(use: list)
        sessions.post(use: create)
        sessions.get("scan", use: scan)
        sessions.get(":id", use: get)
        sessions.put(":id", use: self.rename)
        sessions.delete(":id", use: delete)
        sessions.post(":id", "fork", use: fork)
        sessions.get(":id", "messages", use: messages)

        let transcriptGroup = sessions.grouped("transcript")
        transcriptGroup.get(":encodedProjectPath", ":sessionId", use: transcript)
    }

    /// List all sessions with optional project filter and pagination.
    /// - Parameter req: Vapor Request with optional projectId, page, and limit query parameters
    /// - Returns: APIResponse with paginated ChatSession objects
    @Sendable
    func list(req: Request) async throws -> APIResponse<PaginatedResponse<ChatSession>> {
        // Optional project filter
        let projectId = req.query[UUID.self, at: "projectId"]

        // Pagination parameters
        let page = max(req.query[Int.self, at: "page"] ?? 1, 1)
        let limit = min(max(req.query[Int.self, at: "limit"] ?? 50, 1), 100)
        let offset = (page - 1) * limit

        // Build count query
        var countQuery = SessionModel.query(on: req.db)
        if let projectId = projectId {
            countQuery = countQuery.filter(\.$project.$id == projectId)
        }
        let total = try await countQuery.count()

        // Build paginated query
        var listQuery = SessionModel.query(on: req.db)
        if let projectId = projectId {
            listQuery = listQuery.filter(\.$project.$id == projectId)
        }
        let sessions = try await listQuery
            .with(\.$project)
            .sort(\.$lastActiveAt, .descending)
            .offset(offset)
            .limit(limit)
            .all()

        let items = sessions.map { session in
            session.toShared(projectName: session.project?.name)
        }

        return APIResponse(
            success: true,
            data: PaginatedResponse(items: items, total: total, hasMore: offset + items.count < total)
        )
    }

    /// Create a new session.
    /// - Parameter req: Vapor Request with CreateSessionRequest body
    /// - Returns: APIResponse with created ChatSession
    @Sendable
    func create(req: Request) async throws -> APIResponse<ChatSession> {
        let input = try req.content.decode(CreateSessionRequest.self)

        var projectName: String?
        if let projectId = input.projectId {
            if let project = try await ProjectModel.find(projectId, on: req.db) {
                projectName = project.name
            }
        }

        let session = SessionModel(
            name: input.name,
            projectId: input.projectId,
            model: input.model ?? "sonnet",
            permissionMode: input.permissionMode ?? .default
        )

        try await session.save(on: req.db)

        return APIResponse(
            success: true,
            data: session.toShared(projectName: projectName)
        )
    }

    /// Rename a session.
    /// - Parameter req: Vapor Request with id parameter and RenameSessionRequest body
    /// - Returns: APIResponse with updated ChatSession
    @Sendable
    func rename(req: Request) async throws -> APIResponse<ChatSession> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        let input = try req.content.decode(RenameSessionRequest.self)

        guard let session = try await SessionModel.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        session.name = input.name
        try await session.save(on: req.db)

        return APIResponse(
            success: true,
            data: session.toShared(projectName: session.project?.name)
        )
    }

    /// Scan for external Claude Code sessions from `~/.claude/projects/`.
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with SessionScanResponse containing external sessions
    @Sendable
    func scan(req: Request) async throws -> APIResponse<SessionScanResponse> {
        let externalSessions = try fileSystem.scanExternalSessions()

        return APIResponse(
            success: true,
            data: SessionScanResponse(
                items: externalSessions,
                scannedPaths: ["~/.claude/projects/"]
            )
        )
    }

    /// Get a specific session by ID.
    /// - Parameter req: Vapor Request with id parameter
    /// - Returns: APIResponse with ChatSession
    @Sendable
    func get(req: Request) async throws -> APIResponse<ChatSession> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let session = try await SessionModel.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        return APIResponse(
            success: true,
            data: session.toShared(projectName: session.project?.name)
        )
    }

    /// Delete a session and its messages.
    /// - Parameter req: Vapor Request with id parameter
    /// - Returns: APIResponse with deletion confirmation
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let session = try await SessionModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        try await session.delete(on: req.db)

        return APIResponse(
            success: true,
            data: DeletedResponse()
        )
    }

    /// Fork a session, creating a new session with the same settings.
    /// - Parameter req: Vapor Request with id parameter
    /// - Returns: APIResponse with forked ChatSession
    @Sendable
    func fork(req: Request) async throws -> APIResponse<ChatSession> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let original = try await SessionModel.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let forked = SessionModel(
            claudeSessionId: nil,
            name: original.name.map { "\($0) (fork)" },
            projectId: original.$project.id,
            model: original.model,
            permissionMode: PermissionMode(rawValue: original.permissionMode) ?? .default,
            forkedFrom: original.id
        )

        try await forked.save(on: req.db)

        return APIResponse(
            success: true,
            data: forked.toShared(projectName: original.project?.name)
        )
    }

    /// Get messages for a session with pagination.
    /// - Parameter req: Vapor Request with id parameter and optional limit/offset query params
    /// - Returns: APIResponse with paginated list of Message objects
    @Sendable
    func messages(req: Request) async throws -> APIResponse<ListResponse<Message>> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        // Verify session exists
        guard let _ = try await SessionModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        // Get pagination parameters
        let limit = req.query[Int.self, at: "limit"] ?? 100
        let offset = req.query[Int.self, at: "offset"] ?? 0

        // Query messages for this session
        let query = MessageModel.query(on: req.db)
            .filter(\.$session.$id == id)
            .sort(\.$createdAt, .ascending)

        // Get total count before pagination
        let total = try await query.count()

        // Apply pagination and fetch
        let messageModels = try await query
            .offset(offset)
            .limit(limit)
            .all()

        // Convert to shared Message type
        let messages = messageModels.map { $0.toShared() }

        return APIResponse(
            success: true,
            data: ListResponse(items: messages, total: total)
        )
    }

    /// Read messages from an external session's JSONL transcript file.
    /// - Parameter req: Vapor Request with encodedProjectPath and sessionId parameters, optional limit/offset query params
    /// - Returns: APIResponse with list of Message objects from transcript
    @Sendable
    func transcript(req: Request) async throws -> APIResponse<ListResponse<Message>> {
        guard let encodedProjectPath = req.parameters.get("encodedProjectPath"),
              let sessionId = req.parameters.get("sessionId") else {
            throw Abort(.badRequest, reason: "Missing project path or session ID")
        }

        let limit = req.query[Int.self, at: "limit"] ?? 200
        let offset = req.query[Int.self, at: "offset"] ?? 0

        let messages = try fileSystem.readTranscriptMessages(
            encodedProjectPath: encodedProjectPath,
            sessionId: sessionId,
            limit: limit,
            offset: offset
        )

        return APIResponse(
            success: true,
            data: ListResponse(items: messages)
        )
    }
}
