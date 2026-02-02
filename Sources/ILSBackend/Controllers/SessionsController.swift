import Vapor
import Fluent
import ILSShared

struct SessionsController: RouteCollection {
    let fileSystem = FileSystemService()

    func boot(routes: RoutesBuilder) throws {
        let sessions = routes.grouped("sessions")

        sessions.get(use: list)
        sessions.post(use: create)
        sessions.get("scan", use: scan)
        sessions.get(":id", use: get)
        sessions.delete(":id", use: delete)
        sessions.post(":id", "fork", use: fork)
    }

    /// GET /sessions - List all sessions
    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<ChatSession>> {
        var query = SessionModel.query(on: req.db)

        // Optional project filter
        if let projectId = req.query[UUID.self, at: "projectId"] {
            query = query.filter(\.$project.$id == projectId)
        }

        let sessions = try await query
            .with(\.$project)
            .sort(\.$lastActiveAt, .descending)
            .all()

        let items = sessions.map { session in
            session.toShared(projectName: session.project?.name)
        }

        return APIResponse(
            success: true,
            data: ListResponse(items: items)
        )
    }

    /// POST /sessions - Create a new session
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

    /// GET /sessions/scan - Scan for external Claude Code sessions
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

    /// GET /sessions/:id - Get a single session
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

    /// DELETE /sessions/:id - Delete a session
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

    /// POST /sessions/:id/fork - Fork a session
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
}
