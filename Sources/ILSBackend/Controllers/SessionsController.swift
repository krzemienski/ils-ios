import Vapor
import Fluent
import ILSShared

/// Controller for session management operations.
///
/// Routes:
/// - `GET /sessions`: List all sessions with optional project filter
/// - `POST /sessions`: Create a new session
/// - `GET /sessions/scan`: Scan for external Claude Code sessions
/// - `GET /sessions/search?q=`: Search across all session messages
/// - `GET /sessions/:id`: Get a specific session
/// - `PUT /sessions/:id`: Rename a session
/// - `DELETE /sessions/:id`: Delete a session
/// - `POST /sessions/bulk-delete`: Bulk-delete sessions by ID array
/// - `POST /sessions/:id/fork`: Fork a session (duplicates session + all messages)
/// - `GET /sessions/:id/messages`: Get session messages with pagination
/// - `GET /sessions/:id/messages/search?q=`: Search within a session's messages
/// - `GET /sessions/:id/export?format=`: Export session as JSON, Markdown, or plain text
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
        sessions.get("search", use: searchAll)
        sessions.get(":id", use: get)
        sessions.put(":id", use: self.rename)
        sessions.delete(":id", use: delete)
        sessions.post("bulk-delete", use: bulkDelete)
        sessions.post(":id", "fork", use: fork)
        sessions.get(":id", "messages", use: messages)
        sessions.get(":id", "messages", "search", use: searchSession)
        sessions.get(":id", "export", use: exportSession)

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

    /// Bulk-delete sessions by an array of IDs.
    /// - Parameter req: Vapor Request with BulkDeleteSessionsRequest body
    /// - Returns: APIResponse with DeletedResponse
    @Sendable
    func bulkDelete(req: Request) async throws -> APIResponse<DeletedResponse> {
        let input = try req.content.decode(BulkDeleteSessionsRequest.self)

        guard !input.ids.isEmpty else {
            throw Abort(.badRequest, reason: "ids array must not be empty")
        }

        guard input.ids.count <= 100 else {
            throw Abort(.badRequest, reason: "Cannot delete more than 100 sessions at once")
        }

        try await SessionModel.query(on: req.db)
            .filter(\.$id ~~ input.ids)
            .delete()

        return APIResponse(
            success: true,
            data: DeletedResponse()
        )
    }

    /// Fork a session, duplicating session settings and all message history.
    ///
    /// Creates a new session named "[Original Name] (Fork)" with a copy of every message
    /// from the original session. The new session has its own independent message history.
    ///
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

        // Create the forked session
        let forked = SessionModel(
            claudeSessionId: nil,
            name: original.name.map { "\($0) (Fork)" } ?? "Untitled (Fork)",
            projectId: original.$project.id,
            model: original.model,
            permissionMode: PermissionMode(rawValue: original.permissionMode) ?? .default,
            forkedFrom: original.id
        )

        try await forked.save(on: req.db)

        guard let forkedId = forked.id else {
            throw Abort(.internalServerError, reason: "Failed to create forked session")
        }

        // Copy all messages from original to forked session
        let originalMessages = try await MessageModel.query(on: req.db)
            .filter(\.$session.$id == id)
            .sort(\.$createdAt, .ascending)
            .all()

        for originalMessage in originalMessages {
            let copiedMessage = MessageModel(
                sessionId: forkedId,
                role: MessageRole(rawValue: originalMessage.role) ?? .user,
                content: originalMessage.content,
                toolCalls: originalMessage.toolCalls,
                toolResults: originalMessage.toolResults
            )
            try await copiedMessage.save(on: req.db)
        }

        // Update message count on forked session
        forked.messageCount = originalMessages.count
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

    // MARK: - Message Search

    /// Search across all session messages.
    ///
    /// Query parameters:
    /// - `q`: Search query (required, case-insensitive LIKE match on message content)
    /// - `limit`: Maximum results (1-100, default 50)
    /// - `offset`: Pagination offset (default 0)
    ///
    /// - Parameter req: Vapor Request with search query params
    /// - Returns: APIResponse with list of MessageSearchResult
    @Sendable
    func searchAll(req: Request) async throws -> APIResponse<ListResponse<MessageSearchResult>> {
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            throw Abort(.badRequest, reason: "Search query parameter 'q' is required")
        }

        try PathSanitizer.validateStringLength(query, maxLength: 500, fieldName: "q")

        let limit = min(max(req.query[Int.self, at: "limit"] ?? 50, 1), 100)
        let offset = max(req.query[Int.self, at: "offset"] ?? 0, 0)

        let searchPattern = "%\(query)%"

        // Query messages matching search across all sessions, joined with session data
        let matchingMessages = try await MessageModel.query(on: req.db)
            .filter(\.$content, .custom("LIKE"), searchPattern)
            .sort(\.$createdAt, .descending)
            .with(\.$session) {
                $0.with(\.$project)
            }
            .offset(offset)
            .limit(limit)
            .all()

        let results = matchingMessages.map { msg in
            MessageSearchResult(
                id: msg.id ?? UUID(),
                sessionId: msg.$session.id,
                sessionName: msg.session.name,
                sessionModel: msg.session.model,
                role: MessageRole(rawValue: msg.role) ?? .user,
                content: msg.content,
                createdAt: msg.createdAt ?? Date()
            )
        }

        // Get total count for pagination
        let total = try await MessageModel.query(on: req.db)
            .filter(\.$content, .custom("LIKE"), searchPattern)
            .count()

        return APIResponse(
            success: true,
            data: ListResponse(items: results, total: total)
        )
    }

    /// Search within a specific session's messages.
    ///
    /// Query parameters:
    /// - `q`: Search query (required, case-insensitive LIKE match on message content)
    /// - `limit`: Maximum results (1-100, default 50)
    /// - `offset`: Pagination offset (default 0)
    ///
    /// - Parameter req: Vapor Request with session id and search query params
    /// - Returns: APIResponse with list of MessageSearchResult
    @Sendable
    func searchSession(req: Request) async throws -> APIResponse<ListResponse<MessageSearchResult>> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            throw Abort(.badRequest, reason: "Search query parameter 'q' is required")
        }

        try PathSanitizer.validateStringLength(query, maxLength: 500, fieldName: "q")

        // Verify session exists and load its details
        guard let session = try await SessionModel.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let limit = min(max(req.query[Int.self, at: "limit"] ?? 50, 1), 100)
        let offset = max(req.query[Int.self, at: "offset"] ?? 0, 0)

        let searchPattern = "%\(query)%"

        let matchingMessages = try await MessageModel.query(on: req.db)
            .filter(\.$session.$id == id)
            .filter(\.$content, .custom("LIKE"), searchPattern)
            .sort(\.$createdAt, .ascending)
            .offset(offset)
            .limit(limit)
            .all()

        let results = matchingMessages.map { msg in
            MessageSearchResult(
                id: msg.id ?? UUID(),
                sessionId: msg.$session.id,
                sessionName: session.name,
                sessionModel: session.model,
                role: MessageRole(rawValue: msg.role) ?? .user,
                content: msg.content,
                createdAt: msg.createdAt ?? Date()
            )
        }

        let total = try await MessageModel.query(on: req.db)
            .filter(\.$session.$id == id)
            .filter(\.$content, .custom("LIKE"), searchPattern)
            .count()

        return APIResponse(
            success: true,
            data: ListResponse(items: results, total: total)
        )
    }

    // MARK: - Chat Export

    /// Export a session's chat history in the requested format.
    ///
    /// Query parameters:
    /// - `format`: Export format — "json" (default), "markdown", or "text"
    ///
    /// Sets appropriate Content-Type and Content-Disposition headers for file downloads.
    ///
    /// - Parameter req: Vapor Request with session id and format query param
    /// - Returns: Response with exported content
    @Sendable
    func exportSession(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        let formatString = req.query[String.self, at: "format"] ?? "json"
        guard let format = ExportFormat(rawValue: formatString) else {
            throw Abort(.badRequest, reason: "Invalid format. Use 'json', 'markdown', or 'text'")
        }

        // Load session with project
        guard let session = try await SessionModel.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        // Load all messages
        let messageModels = try await MessageModel.query(on: req.db)
            .filter(\.$session.$id == id)
            .sort(\.$createdAt, .ascending)
            .all()

        let sessionName = session.name ?? "Untitled"
        let safeFilename = sessionName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "\"", with: "")
            .prefix(100)

        switch format {
        case .json:
            return try buildJSONExport(
                session: session,
                messages: messageModels,
                filename: String(safeFilename),
                on: req
            )
        case .markdown:
            return buildMarkdownExport(
                session: session,
                messages: messageModels,
                filename: String(safeFilename),
                on: req
            )
        case .text:
            return buildTextExport(
                session: session,
                messages: messageModels,
                filename: String(safeFilename),
                on: req
            )
        }
    }

    // MARK: - Export Helpers

    private func buildJSONExport(
        session: SessionModel,
        messages: [MessageModel],
        filename: String,
        on req: Request
    ) throws -> Response {
        let exportSession = ChatExportSession(
            id: session.id ?? UUID(),
            name: session.name,
            model: session.model,
            createdAt: session.createdAt ?? Date(),
            lastActiveAt: session.lastActiveAt ?? Date(),
            messageCount: session.messageCount,
            totalCostUSD: session.totalCostUSD,
            projectName: session.project?.name
        )

        let exportMessages = messages.map { msg in
            ChatExportMessage(
                role: MessageRole(rawValue: msg.role) ?? .user,
                content: msg.content,
                createdAt: msg.createdAt ?? Date()
            )
        }

        let export = ChatExport(
            session: exportSession,
            messages: exportMessages
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)

        let response = Response(status: .ok, body: .init(data: data))
        response.headers.contentType = .json
        response.headers.add(name: .contentDisposition, value: "attachment; filename=\"\(filename).json\"")
        return response
    }

    private func buildMarkdownExport(
        session: SessionModel,
        messages: [MessageModel],
        filename: String,
        on req: Request
    ) -> Response {
        let dateFormatter = ISO8601DateFormatter()

        var md = "# \(session.name ?? "Untitled Session")\n\n"
        md += "| Field | Value |\n|-------|-------|\n"
        md += "| Model | \(session.model) |\n"
        md += "| Created | \(dateFormatter.string(from: session.createdAt ?? Date())) |\n"
        md += "| Last Active | \(dateFormatter.string(from: session.lastActiveAt ?? Date())) |\n"
        md += "| Messages | \(session.messageCount) |\n"
        if let cost = session.totalCostUSD {
            md += "| Cost | $\(String(format: "%.4f", cost)) |\n"
        }
        if let projectName = session.project?.name {
            md += "| Project | \(projectName) |\n"
        }
        md += "\n---\n\n"

        for msg in messages {
            let role = msg.role.capitalized
            let timestamp = dateFormatter.string(from: msg.createdAt ?? Date())
            md += "### \(role) — \(timestamp)\n\n"
            md += msg.content
            md += "\n\n---\n\n"
        }

        let response = Response(status: .ok, body: .init(string: md))
        response.headers.contentType = HTTPMediaType(type: "text", subType: "markdown", parameters: ["charset": "utf-8"])
        response.headers.add(name: .contentDisposition, value: "attachment; filename=\"\(filename).md\"")
        return response
    }

    private func buildTextExport(
        session: SessionModel,
        messages: [MessageModel],
        filename: String,
        on req: Request
    ) -> Response {
        let dateFormatter = ISO8601DateFormatter()

        var text = "Session: \(session.name ?? "Untitled Session")\n"
        text += "Model: \(session.model)\n"
        text += "Created: \(dateFormatter.string(from: session.createdAt ?? Date()))\n"
        text += "Last Active: \(dateFormatter.string(from: session.lastActiveAt ?? Date()))\n"
        text += "Messages: \(session.messageCount)\n"
        if let cost = session.totalCostUSD {
            text += "Cost: $\(String(format: "%.4f", cost))\n"
        }
        if let projectName = session.project?.name {
            text += "Project: \(projectName)\n"
        }
        text += "\n" + String(repeating: "=", count: 60) + "\n\n"

        for msg in messages {
            let role = msg.role.uppercased()
            let timestamp = dateFormatter.string(from: msg.createdAt ?? Date())
            text += "[\(role)] \(timestamp)\n"
            text += msg.content
            text += "\n\n" + String(repeating: "-", count: 40) + "\n\n"
        }

        let response = Response(status: .ok, body: .init(string: text))
        response.headers.contentType = .plainText
        response.headers.add(name: .contentDisposition, value: "attachment; filename=\"\(filename).txt\"")
        return response
    }
}
