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
        sessions.get("projects", use: projectGroups)
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

    /// List all sessions (DB + external) with unified pagination, dedup, search, and sort.
    ///
    /// Query parameters:
    /// - `projectId`: Filter to sessions belonging to a specific project
    /// - `page`: Page number (1-based, default 1)
    /// - `limit`: Items per page (1-100, default 50)
    /// - `search`: Case-insensitive search across name, projectName, firstPrompt
    /// - `refresh`: If "true", bypasses the external sessions cache
    @Sendable
    func list(req: Request) async throws -> APIResponse<PaginatedResponse<ChatSession>> {
        let projectId = req.query[UUID.self, at: "projectId"]
        let projectName = req.query[String.self, at: "projectName"]
        let page = max(req.query[Int.self, at: "page"] ?? 1, 1)
        let limit = min(max(req.query[Int.self, at: "limit"] ?? 50, 1), 100)
        let offset = (page - 1) * limit
        let search = req.query[String.self, at: "search"]
        let refresh = req.query[String.self, at: "refresh"] == "true"

        // 1. Load all DB sessions (small set, ~51)
        var dbQuery = SessionModel.query(on: req.db).with(\.$project)
        if let projectId = projectId {
            dbQuery = dbQuery.filter(\.$project.$id == projectId)
        }
        let dbSessions = try await dbQuery.all()
        var merged: [ChatSession] = dbSessions.map { $0.toShared(projectName: $0.project?.name) }

        // 2. Load external sessions (cached, ~22K) — skip if filtering by projectId
        if projectId == nil {
            let externalSessions = try await fileSystem.listExternalSessionsAsChatSessions(bypassCache: refresh)

            // 3. Dedup: build set of DB claudeSessionIds, exclude external dupes
            let dbClaudeIds = Set(dbSessions.compactMap(\.claudeSessionId))
            let uniqueExternal = externalSessions.filter { ext in
                guard let claudeId = ext.claudeSessionId else { return true }
                return !dbClaudeIds.contains(claudeId)
            }
            merged.append(contentsOf: uniqueExternal)
        }

        // 3b. Filter by projectName if provided
        if let projectName = projectName, !projectName.isEmpty {
            let target = projectName == "Ungrouped" ? nil as String? : projectName
            merged = merged.filter { session in
                if target == nil {
                    return session.projectName == nil || session.projectName?.isEmpty == true
                }
                return session.projectName == target
            }
        }

        // 4. Search filter (case-insensitive across name, projectName, firstPrompt)
        if let search = search, !search.isEmpty {
            merged = merged.filter { session in
                (session.name?.localizedCaseInsensitiveContains(search) ?? false)
                    || (session.projectName?.localizedCaseInsensitiveContains(search) ?? false)
                    || (session.firstPrompt?.localizedCaseInsensitiveContains(search) ?? false)
            }
        }

        // 5. Sort by lastActiveAt descending
        merged.sort { $0.lastActiveAt > $1.lastActiveAt }

        // 6. Paginate
        let total = merged.count
        let start = min(offset, total)
        let end = min(start + limit, total)
        let page_items = Array(merged[start..<end])

        return APIResponse(
            success: true,
            data: PaginatedResponse(
                items: page_items,
                total: total,
                hasMore: end < total
            )
        )
    }

    /// Return all projects with their session counts, sorted by most recently active.
    ///
    /// This enables the sidebar to show all project groups without loading 22K+ individual sessions.
    @Sendable
    func projectGroups(req: Request) async throws -> APIResponse<[ProjectGroupInfo]> {
        let refresh = req.query[String.self, at: "refresh"] == "true"

        // 1. Load DB sessions
        let dbSessions = try await SessionModel.query(on: req.db).with(\.$project).all()
        var merged: [ChatSession] = dbSessions.map { $0.toShared(projectName: $0.project?.name) }

        // 2. Load external sessions
        let externalSessions = try await fileSystem.listExternalSessionsAsChatSessions(bypassCache: refresh)
        let dbClaudeIds = Set(dbSessions.compactMap(\.claudeSessionId))
        let uniqueExternal = externalSessions.filter { ext in
            guard let claudeId = ext.claudeSessionId else { return true }
            return !dbClaudeIds.contains(claudeId)
        }
        merged.append(contentsOf: uniqueExternal)

        // 3. Group by projectName
        var groups: [String: (count: Int, latest: Date)] = [:]
        for session in merged {
            let name = session.projectName ?? "Ungrouped"
            if let existing = groups[name] {
                groups[name] = (
                    count: existing.count + 1,
                    latest: max(existing.latest, session.lastActiveAt)
                )
            } else {
                groups[name] = (count: 1, latest: session.lastActiveAt)
            }
        }

        // 4. Sort by latest date descending
        let result = groups.map { name, info in
            ProjectGroupInfo(name: name, sessionCount: info.count, latestDate: info.latest)
        }.sorted { $0.latestDate > $1.latestDate }

        return APIResponse(success: true, data: result)
    }

    /// Create a new session.
    /// - Parameter req: Vapor Request with CreateSessionRequest body
    /// - Returns: APIResponse with created ChatSession
    @Sendable
    func create(req: Request) async throws -> APIResponse<ChatSession> {
        let input = try req.content.decode(CreateSessionRequest.self)

        // Validate input lengths
        try PathSanitizer.validateOptionalStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(input.model, maxLength: 64, fieldName: "model")
        try PathSanitizer.validateOptionalStringLength(input.systemPrompt, maxLength: 100_000, fieldName: "systemPrompt")

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

        // Validate input
        try PathSanitizer.validateStringLength(input.name, maxLength: 255, fieldName: "name")

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

        // Validate path components to prevent directory traversal
        try PathSanitizer.validateComponent(encodedProjectPath)
        try PathSanitizer.validateComponent(sessionId)

        let limit = min(max(req.query[Int.self, at: "limit"] ?? 200, 1), 1000)
        let offset = max(req.query[Int.self, at: "offset"] ?? 0, 0)

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
