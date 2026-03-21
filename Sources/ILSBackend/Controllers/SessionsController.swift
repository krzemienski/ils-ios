import Vapor
import Fluent
import SQLKit
import ILSShared

// MARK: - Vapor Content Conformances

extension SessionFilesResponse: Content {}
extension SessionFileChange: Content {}

/// Controller for session management operations.
///
/// Routes:
/// - `GET /sessions`: List all sessions with optional project filter
/// - `POST /sessions`: Create a new session
/// - `GET /sessions/scan`: Scan for external Claude Code sessions
/// - `GET /sessions/search?q=`: Search across all session messages using FTS5
/// - `GET /sessions/search/history`: Get recent search history (last 20 unique queries)
/// - `DELETE /sessions/search/history`: Clear all search history
/// - `GET /sessions/model-stats`: Aggregate model usage statistics across all sessions
/// - `POST /sessions/suggest-model`: Smart model routing suggestion
/// - `GET /sessions/compare?a=id1&b=id2`: Compare two sessions side-by-side
/// - `GET /sessions/integrity-check`: Verify session messageCount integrity (optional ?fix=true)
/// - `GET /sessions/:id`: Get a specific session
/// - `PUT /sessions/:id`: Rename a session
/// - `DELETE /sessions/:id`: Delete a session
/// - `PATCH /sessions/:id/model`: Update the model of an existing session
/// - `POST /sessions/bulk-delete`: Bulk-delete sessions by ID array
/// - `POST /sessions/bulk-export`: Bulk-export multiple sessions as JSON
/// - `POST /sessions/import`: Import a previously exported session
/// - `POST /sessions/:id/fork`: Fork a session (duplicates session + all messages)
/// - `GET /sessions/:id/fork-tree`: Get the complete fork lineage for a session family
/// - `GET /sessions/:id/messages`: Get session messages with pagination
/// - `GET /sessions/:id/messages/search?q=`: Search within a session's messages
/// - `GET /sessions/:id/export?format=`: Export session as JSON, Markdown, or plain text
/// - `GET /sessions/transcript/:encodedProjectPath/:sessionId`: Read external session transcript
/// - `GET /sessions/transcript/:encodedProjectPath/:sessionId/files`: List files changed in session
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
        sessions.get("search", "history", use: getSearchHistory)
        sessions.delete("search", "history", use: clearSearchHistory)
        sessions.get("model-stats", use: modelStats)
        sessions.post("suggest-model", use: suggestModel)
        sessions.get("compare", use: compare)
        sessions.get("integrity-check", use: integrityCheck)
        sessions.get(":id", use: get)
        sessions.put(":id", use: self.rename)
        sessions.delete(":id", use: delete)
        sessions.patch(":id", "model", use: updateModel)
        sessions.post("bulk-delete", use: bulkDelete)
        sessions.post("bulk-export", use: bulkExport)
        sessions.post("import", use: importSession)
        sessions.post(":id", "fork", use: fork)
        sessions.get(":id", "fork-tree", use: forkTree)
        sessions.get(":id", "messages", use: messages)
        sessions.get(":id", "messages", "search", use: searchSession)
        sessions.get(":id", "export", use: exportSession)
        sessions.post(":id", "live-activity-token", use: registerLiveActivityToken)

        let transcriptGroup = sessions.grouped("transcript")
        transcriptGroup.get(":encodedProjectPath", ":sessionId", use: transcript)
        transcriptGroup.get(":encodedProjectPath", ":sessionId", "files", use: transcriptFiles)
    }

    /// List all sessions (DB + external) with unified pagination, dedup, search, and sort.
    ///
    /// Query parameters:
    /// - `projectId`: Filter to sessions belonging to a specific project
    /// - `cursor`: Opaque cursor for cursor-based pagination (ISO8601 date of last seen item).
    ///             When provided, returns items with `lastActiveAt` strictly before the cursor date.
    ///             Takes precedence over `page`.
    /// - `page`: Page number (1-based, default 1) — ignored when `cursor` is provided
    /// - `limit`: Items per page (1-200, default 50)
    /// - `search`: Case-insensitive search across name, projectName, firstPrompt
    /// - `refresh`: If "true", bypasses the external sessions cache
    ///
    /// Response headers:
    /// - `X-Total-Count`: Total number of matching sessions (ignores cursor position)
    /// - `X-Has-More`: "true" if additional pages exist
    /// - `X-Next-Cursor`: ISO8601 cursor for fetching the next page (omitted when no more pages)
    @Sendable
    func list(req: Request) async throws -> Response {
        let projectId = req.query[UUID.self, at: "projectId"]
        let projectName = req.query[String.self, at: "projectName"]
        let cursorParam = req.query[String.self, at: "cursor"]
        let page = max(req.query[Int.self, at: "page"] ?? 1, 1)
        let limit = min(max(req.query[Int.self, at: "limit"] ?? 50, 1), 200)
        let search = req.query[String.self, at: "search"]
        let refresh = req.query[String.self, at: "refresh"] == "true"

        // Parse cursor into a date threshold: return items with lastActiveAt < cursorDate
        let iso8601 = ISO8601DateFormatter()
        let cursorDate: Date? = cursorParam.flatMap { iso8601.date(from: $0) }

        // 1. Load all DB sessions (small set, ~51), pre-sorted by lastActiveAt descending
        var dbQuery = SessionModel.query(on: req.db)
            .with(\.$project)
            .sort(\.$lastActiveAt, .descending)
        if let projectId = projectId {
            dbQuery = dbQuery.filter(\.$project.$id == projectId)
        }
        let dbSessions = try await dbQuery.all()
        let dbConverted: [ChatSession] = dbSessions.map { $0.toShared(projectName: $0.project?.name) }

        // 2. Load external sessions (cached, ~22K, pre-sorted) — skip if filtering by projectId
        var uniqueExternal: [ChatSession] = []
        if projectId == nil {
            let externalSessions = try await fileSystem.listExternalSessionsAsChatSessions(bypassCache: refresh)

            // 3. Dedup: build set of DB claudeSessionIds, exclude external dupes
            let dbClaudeIds = Set(dbSessions.compactMap(\.claudeSessionId))
            uniqueExternal = externalSessions.filter { ext in
                guard let claudeId = ext.claudeSessionId else { return true }
                return !dbClaudeIds.contains(claudeId)
            }
        }

        // 3b. Filter by projectName if provided
        var filteredDB = dbConverted
        if let projectName = projectName, !projectName.isEmpty {
            let target = projectName == "Ungrouped" ? nil as String? : projectName
            let nameFilter: (ChatSession) -> Bool = { session in
                if target == nil {
                    return session.projectName == nil || session.projectName?.isEmpty == true
                }
                return session.projectName == target
            }
            filteredDB = filteredDB.filter(nameFilter)
            uniqueExternal = uniqueExternal.filter(nameFilter)
        }

        // 4. Search filter (case-insensitive across name, projectName, firstPrompt)
        if let search = search, !search.isEmpty {
            let searchFilter: (ChatSession) -> Bool = { session in
                (session.name?.localizedCaseInsensitiveContains(search) ?? false)
                    || (session.projectName?.localizedCaseInsensitiveContains(search) ?? false)
                    || (session.firstPrompt?.localizedCaseInsensitiveContains(search) ?? false)
            }
            filteredDB = filteredDB.filter(searchFilter)
            uniqueExternal = uniqueExternal.filter(searchFilter)
        }

        // 5. Compute total across all matching items (before cursor filtering) for X-Total-Count header.
        let total = filteredDB.count + uniqueExternal.count

        // 6. Apply cursor filter: when cursor provided, only consider items strictly older than cursor.
        //    Both arrays are already sorted descending so this trims the leading (newer) portion.
        var cursorDB = filteredDB
        var cursorExternal = uniqueExternal
        let offset: Int
        if let cursorDate = cursorDate {
            cursorDB = cursorDB.filter { $0.lastActiveAt < cursorDate }
            cursorExternal = cursorExternal.filter { $0.lastActiveAt < cursorDate }
            offset = 0
        } else {
            offset = (page - 1) * limit
        }
        let cursorTotal = cursorDB.count + cursorExternal.count

        // 7. Merge the two pre-sorted arrays (both sorted by lastActiveAt descending).
        //    Early exit: only merge up to (offset + limit) items.
        let needed = min(offset + limit, cursorTotal)
        var merged: [ChatSession] = []
        merged.reserveCapacity(needed)
        var i = 0, j = 0
        while merged.count < needed && (i < cursorDB.count || j < cursorExternal.count) {
            if i >= cursorDB.count {
                merged.append(cursorExternal[j]); j += 1
            } else if j >= cursorExternal.count {
                merged.append(cursorDB[i]); i += 1
            } else if cursorDB[i].lastActiveAt >= cursorExternal[j].lastActiveAt {
                merged.append(cursorDB[i]); i += 1
            } else {
                merged.append(cursorExternal[j]); j += 1
            }
        }

        // 8. Paginate from merged result
        let start = min(offset, merged.count)
        let end = min(start + limit, merged.count)
        let pageItems = Array(merged[start..<end])
        let hasMore = end < cursorTotal

        // 9. Compute next cursor from the lastActiveAt of the last returned item
        let nextCursor: String? = hasMore ? pageItems.last.map { iso8601.string(from: $0.lastActiveAt) } : nil

        // 10. Build response with pagination headers
        let payload = APIResponse(
            success: true,
            data: PaginatedResponse(
                items: pageItems,
                total: total,
                hasMore: end < total,
                page: page,
                limit: limit,
                nextCursor: end < total ? pageItems.last?.id.uuidString : nil
            )
        )
        let response = Response(status: .ok)
        try response.content.encode(payload, using: JSONEncoder())
        response.headers.contentType = .json
        response.headers.replaceOrAdd(name: "X-Total-Count", value: "\(total)")
        response.headers.replaceOrAdd(name: "X-Has-More", value: hasMore ? "true" : "false")
        if let nextCursor = nextCursor {
            response.headers.replaceOrAdd(name: "X-Next-Cursor", value: nextCursor)
        }
        return response
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
    /// Query parameters:
    /// - `upToMessageId`: Optional UUID — when provided, only copies messages up to and including
    ///   the specified message ID for point-in-time forking.
    ///
    /// - Parameter req: Vapor Request with id parameter
    /// - Returns: APIResponse with forked ChatSession
    @Sendable
    func fork(req: Request) async throws -> APIResponse<ChatSession> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        let upToMessageId = req.query[UUID.self, at: "upToMessageId"]

        guard let original = try await SessionModel.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        // Wrap fork in a transaction so session + messages are created atomically
        let forked = try await req.db.transaction { db in
            let forked = SessionModel(
                claudeSessionId: nil,
                name: original.name.map { "\($0) (Fork)" } ?? "Untitled (Fork)",
                projectId: original.$project.id,
                model: original.model,
                permissionMode: PermissionMode(rawValue: original.permissionMode) ?? .default,
                forkedFrom: original.id
            )

            try await forked.save(on: db)

            guard let forkedId = forked.id else {
                throw Abort(.internalServerError, reason: "Failed to create forked session")
            }

            // Load all messages sorted by creation order
            let allMessages = try await MessageModel.query(on: db)
                .filter(\.$session.$id == id)
                .sort(\.$createdAt, .ascending)
                .all()

            // If upToMessageId is specified, truncate the list at that message
            let messagesToCopy: [MessageModel]
            if let upToMessageId = upToMessageId {
                guard let cutoffIndex = allMessages.firstIndex(where: { $0.id == upToMessageId }) else {
                    throw Abort(.badRequest, reason: "Message ID not found in session")
                }
                messagesToCopy = Array(allMessages[...cutoffIndex])
            } else {
                messagesToCopy = allMessages
            }

            for originalMessage in messagesToCopy {
                let copiedMessage = MessageModel(
                    sessionId: forkedId,
                    role: MessageRole(rawValue: originalMessage.role) ?? .user,
                    content: originalMessage.content,
                    toolCalls: originalMessage.toolCalls,
                    toolResults: originalMessage.toolResults
                )
                try await copiedMessage.save(on: db)
            }

            // Update message count on forked session
            forked.messageCount = messagesToCopy.count
            try await forked.save(on: db)

            return forked
        }

        return APIResponse(
            success: true,
            data: forked.toShared(projectName: original.project?.name)
        )
    }

    /// Get the complete fork tree for a session family.
    ///
    /// Walks up the `forkedFrom` chain to find the root session, then performs a
    /// breadth-first traversal downward to collect all sessions in the same lineage.
    ///
    /// - Parameter req: Vapor Request with id parameter
    /// - Returns: APIResponse with SessionForkTreeResponse containing all family sessions and the root ID
    @Sendable
    func forkTree(req: Request) async throws -> APIResponse<SessionForkTreeResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let _ = try await SessionModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        // Load all DB sessions — fork families are small, so loading all is acceptable
        let allSessions = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .all()

        let sessionMap: [UUID: SessionModel] = Dictionary(uniqueKeysWithValues: allSessions.compactMap { s in
            guard let sid = s.id else { return nil }
            return (sid, s)
        })

        // Walk up from the requested session to find the root (no forkedFrom ancestor)
        var rootId = id
        var visited: Set<UUID> = [id]
        while let current = sessionMap[rootId], let parentId = current.forkedFrom {
            guard !visited.contains(parentId) else { break } // Cycle guard
            visited.insert(parentId)
            rootId = parentId
        }

        // BFS from root to collect all sessions in the fork family
        var familyIds: Set<UUID> = []
        var queue: [UUID] = [rootId]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            guard !familyIds.contains(current) else { continue }
            familyIds.insert(current)
            for session in allSessions {
                guard let sid = session.id, let parent = session.forkedFrom,
                      parent == current, !familyIds.contains(sid) else { continue }
                queue.append(sid)
            }
        }

        // Return sessions sorted by creation date (preserves fork order)
        let familySessions = allSessions
            .filter { $0.id.map { familyIds.contains($0) } ?? false }
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            .map { $0.toShared(projectName: $0.project?.name) }

        return APIResponse(
            success: true,
            data: SessionForkTreeResponse(sessions: familySessions, rootId: rootId)
        )
    }

    /// Get messages for a session with pagination.
    /// - Parameter req: Vapor Request with id parameter and optional page/limit query params
    /// - Returns: APIResponse with paginated list of Message objects
    @Sendable
    func messages(req: Request) async throws -> APIResponse<PaginatedResponse<Message>> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        // Verify session exists
        guard let _ = try await SessionModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        // Get pagination parameters
        let page = max(req.query[Int.self, at: "page"] ?? 1, 1)
        let limit = min(max(req.query[Int.self, at: "limit"] ?? 100, 1), 1000)
        let offset = (page - 1) * limit

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
            data: PaginatedResponse(
                items: messages,
                total: total,
                hasMore: offset + messages.count < total,
                page: page,
                limit: limit
            )
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

        let result = try fileSystem.readTranscriptMessages(
            encodedProjectPath: encodedProjectPath,
            sessionId: sessionId,
            limit: limit,
            offset: offset
        )

        return APIResponse(
            success: true,
            data: ListResponse(items: result.messages, total: result.total)
        )
    }

    /// List all files created, modified, or deleted in an external session's transcript.
    /// - Parameter req: Vapor Request with encodedProjectPath and sessionId parameters
    /// - Returns: APIResponse with SessionFilesResponse listing all touched files
    @Sendable
    func transcriptFiles(req: Request) async throws -> APIResponse<SessionFilesResponse> {
        guard let encodedProjectPath = req.parameters.get("encodedProjectPath"),
              let sessionId = req.parameters.get("sessionId") else {
            throw Abort(.badRequest, reason: "Missing project path or session ID")
        }

        try PathSanitizer.validateComponent(encodedProjectPath)
        try PathSanitizer.validateComponent(sessionId)

        let result = try fileSystem.extractFileChanges(
            encodedProjectPath: encodedProjectPath,
            sessionId: sessionId
        )

        return APIResponse(success: true, data: result)
    }

    // MARK: - Import / Bulk Export

    /// Import a previously exported session.
    ///
    /// Accepts an `ImportSessionRequest` containing a `ChatExport` JSON payload. Creates a new
    /// session named "[Original Name] (Imported)" and re-inserts all messages from the export,
    /// preserving roles and content. Returns the newly created `ChatSession`.
    ///
    /// - Parameter req: Vapor Request with ImportSessionRequest body
    /// - Returns: APIResponse with created ChatSession
    @Sendable
    func importSession(req: Request) async throws -> APIResponse<ChatSession> {
        let input = try req.content.decode(ImportSessionRequest.self)
        let export = input.export

        let originalName = export.session.name ?? "Untitled"
        let importedName = "\(originalName) (Imported)"

        let imported = try await req.db.transaction { db in
            let session = SessionModel(
                name: importedName,
                projectId: input.projectId,
                model: export.session.model,
                permissionMode: .default,
                messageCount: 0,
                totalCostUSD: export.session.totalCostUSD
            )
            try await session.save(on: db)

            guard let sessionId = session.id else {
                throw Abort(.internalServerError, reason: "Failed to create imported session")
            }

            for exportMsg in export.messages {
                let message = MessageModel(
                    sessionId: sessionId,
                    role: exportMsg.role,
                    content: exportMsg.content
                )
                try await message.save(on: db)
            }

            session.messageCount = export.messages.count
            try await session.save(on: db)

            return session
        }

        var projectName: String?
        if let projectId = input.projectId,
           let project = try await ProjectModel.find(projectId, on: req.db) {
            projectName = project.name
        }

        return APIResponse(
            success: true,
            data: imported.toShared(projectName: projectName)
        )
    }

    /// Bulk-export multiple sessions as a JSON array of ChatExport objects.
    ///
    /// Accepts a `BulkExportRequest` with an array of session UUIDs. For each session found in the
    /// database, builds a `ChatExport` containing the session metadata and all messages in
    /// chronological order. Sessions not found in the database are silently skipped.
    ///
    /// - Parameter req: Vapor Request with BulkExportRequest body
    /// - Returns: APIResponse with array of ChatExport objects
    @Sendable
    func bulkExport(req: Request) async throws -> APIResponse<[ChatExport]> {
        let input = try req.content.decode(BulkExportRequest.self)

        guard !input.sessionIds.isEmpty else {
            throw Abort(.badRequest, reason: "sessionIds array must not be empty")
        }

        guard input.sessionIds.count <= 50 else {
            throw Abort(.badRequest, reason: "Cannot export more than 50 sessions at once")
        }

        var exports: [ChatExport] = []

        for sessionId in input.sessionIds {
            guard let session = try await SessionModel.query(on: req.db)
                .filter(\.$id == sessionId)
                .with(\.$project)
                .first() else {
                continue
            }

            let messageModels = try await MessageModel.query(on: req.db)
                .filter(\.$session.$id == sessionId)
                .sort(\.$createdAt, .ascending)
                .all()

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

            let exportMessages = messageModels.map { msg in
                ChatExportMessage(
                    role: MessageRole(rawValue: msg.role) ?? .user,
                    content: msg.content,
                    createdAt: msg.createdAt ?? Date()
                )
            }

            exports.append(ChatExport(session: exportSession, messages: exportMessages))
        }

        return APIResponse(success: true, data: exports)
    }

    // MARK: - Message Search

    /// Search across all session messages using FTS5 full-text search.
    ///
    /// Query parameters:
    /// - `q`: Search query (required)
    /// - `limit`: Maximum results per page (1-100, default 50)
    /// - `offset`: Pagination offset (default 0)
    /// - `role`: Message role filter (`user`, `assistant`, or `system`)
    /// - `from` / `dateFrom`: ISO8601 date — include only messages created on or after this date
    /// - `to` / `dateTo`: ISO8601 date — include only messages created on or before this date
    /// - `projectId`: UUID — restrict to sessions belonging to this project
    /// - `projectName`: Filter by project name ("Ungrouped" for sessions with no project)
    /// - `codeOnly`: If `"true"`, restrict to messages containing code blocks (```)
    ///
    /// Results are ranked by FTS5 relevance. The search query is treated as a phrase
    /// match, and snippets with `<mark>` highlighting are returned alongside each result.
    ///
    /// Each search query is saved to `search_history` (last 20 unique queries kept).
    ///
    /// - Parameter req: Vapor Request with search query params
    /// - Returns: APIResponse with list of MessageSearchResult (with snippets)
    @Sendable
    func searchAll(req: Request) async throws -> APIResponse<ListResponse<MessageSearchResult>> {
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            throw Abort(.badRequest, reason: "Search query parameter 'q' is required")
        }

        try PathSanitizer.validateStringLength(query, maxLength: 500, fieldName: "q")

        let limit = min(max(req.query[Int.self, at: "limit"] ?? 50, 1), 100)
        let offset = max(req.query[Int.self, at: "offset"] ?? 0, 0)
        let roleFilter = req.query[String.self, at: "role"]
        let projectNameFilter = req.query[String.self, at: "projectName"]

        // Support both "dateFrom"/"dateTo" and "from"/"to" parameter names
        let isoFormatter = ISO8601DateFormatter()
        let dateFrom: Date? = (req.query[String.self, at: "dateFrom"] ?? req.query[String.self, at: "from"]).flatMap { isoFormatter.date(from: $0) }
        let dateTo: Date? = (req.query[String.self, at: "dateTo"] ?? req.query[String.self, at: "to"]).flatMap { isoFormatter.date(from: $0) }
        let projectIdFilter = req.query[UUID.self, at: "projectId"]
        let codeOnly = req.query[String.self, at: "codeOnly"] == "true"

        // Wrap user query in double-quotes for FTS5 phrase matching.
        // Internal double-quotes are escaped by doubling them ("" → literal ").
        let escapedQuery = "\"" + query.replacingOccurrences(of: "\"", with: "\"\"") + "\""

        // Phase 1: FTS5 search — get ordered message IDs and snippets by relevance rank.
        guard let sql = req.db as? SQLDatabase else {
            throw Abort(.internalServerError, reason: "FTS5 search requires SQLite database")
        }

        let ftsSQL: SQLQueryString = """
            SELECT m.id AS message_id,
                   snippet(messages_fts, 0, '<mark>', '</mark>', '...', 32) AS snippet
            FROM messages_fts
            JOIN messages m ON m.rowid = messages_fts.rowid
            WHERE messages_fts MATCH \(bind: escapedQuery)
            ORDER BY rank
            LIMIT 1000
            """
        let ftsRows = try await sql.raw(ftsSQL).all()

        // Extract IDs and snippets from FTS5 results (preserving rank order)
        var snippetMap: [String: String] = [:]
        var orderedIdStrings: [String] = []
        for row in ftsRows {
            guard let idStr = try? row.decode(column: "message_id", as: String.self) else { continue }
            let normalizedId = idStr.lowercased()
            orderedIdStrings.append(normalizedId)
            if let snip = try? row.decode(column: "snippet", as: String.self) {
                snippetMap[normalizedId] = snip
            }
        }

        // Return empty results immediately if FTS5 found nothing
        guard !orderedIdStrings.isEmpty else {
            try? await SearchHistoryModel(query: query, resultCount: 0).save(on: req.db)
            try? await pruneSearchHistory(on: req.db)
            return APIResponse(success: true, data: ListResponse(items: [], total: 0))
        }

        let orderedUUIDs = orderedIdStrings.compactMap { UUID(uuidString: $0) }

        // Phase 2: Load full message data via Fluent ORM (handles type safety for UUID/Date)
        var msgQuery = MessageModel.query(on: req.db)
            .filter(\.$id ~~ orderedUUIDs)
            .with(\.$session) { $0.with(\.$project) }

        // Apply date and role filters in the database query
        if let dateFrom = dateFrom {
            msgQuery = msgQuery.filter(\.$createdAt >= dateFrom)
        }
        if let dateTo = dateTo {
            msgQuery = msgQuery.filter(\.$createdAt <= dateTo)
        }
        if let role = roleFilter, !role.isEmpty {
            msgQuery = msgQuery.filter(\.$role == role)
        }

        var loadedMessages = try await msgQuery.all()

        // Apply post-load filters that require joined data
        if let projectId = projectIdFilter {
            loadedMessages = loadedMessages.filter { $0.session.$project.id == projectId }
        }
        if codeOnly {
            loadedMessages = loadedMessages.filter { $0.content.contains("```") }
        }

        // Sort by FTS5 rank order (Phase 1 relevance ordering)
        let idToRank = Dictionary(uniqueKeysWithValues: orderedIdStrings.enumerated().map { ($1, $0) })
        loadedMessages.sort { a, b in
            let aKey = a.id?.uuidString.lowercased() ?? ""
            let bKey = b.id?.uuidString.lowercased() ?? ""
            return (idToRank[aKey] ?? Int.max) < (idToRank[bKey] ?? Int.max)
        }

        let total = loadedMessages.count
        let pageItems = Array(loadedMessages.dropFirst(offset).prefix(limit))

        let results = pageItems.map { msg -> MessageSearchResult in
            let idKey = msg.id?.uuidString.lowercased() ?? ""
            return MessageSearchResult(
                id: msg.id ?? UUID(),
                sessionId: msg.$session.id,
                sessionName: msg.session.name,
                sessionModel: msg.session.model,
                role: MessageRole(rawValue: msg.role) ?? .user,
                content: msg.content,
                createdAt: msg.createdAt ?? Date(),
                snippet: snippetMap[idKey],
                projectName: msg.session.project?.name,
                projectId: msg.session.$project.id
            )
        }

        // Persist this query to search history (non-critical — ignore save errors)
        try? await SearchHistoryModel(query: query, resultCount: total).save(on: req.db)
        try? await pruneSearchHistory(on: req.db)

        return APIResponse(
            success: true,
            data: ListResponse(items: results, total: total)
        )
    }

    /// Extract a short snippet of text surrounding the first occurrence of `query` in `content`.
    ///
    /// Returns up to `contextRadius` characters before and after the match, with leading/trailing
    /// ellipsis characters when the content was trimmed. Returns `nil` if no match is found.
    private func extractMatchContext(from content: String, query: String, contextRadius: Int = 60) -> String? {
        let lowercasedContent = content.lowercased()
        let lowercasedQuery = query.lowercased()
        guard let matchRange = lowercasedContent.range(of: lowercasedQuery) else { return nil }

        let matchStart = content.distance(from: content.startIndex, to: matchRange.lowerBound)
        let matchEnd = content.distance(from: content.startIndex, to: matchRange.upperBound)

        let contextStart = max(0, matchStart - contextRadius)
        let contextEnd = min(content.count, matchEnd + contextRadius)

        let startIndex = content.index(content.startIndex, offsetBy: contextStart)
        let endIndex = content.index(content.startIndex, offsetBy: contextEnd)

        var snippet = String(content[startIndex..<endIndex])

        if contextStart > 0 { snippet = "…" + snippet }
        if contextEnd < content.count { snippet = snippet + "…" }

        return snippet
    }

    /// Compare two sessions side-by-side, returning full metadata and message histories.
    ///
    /// Query parameters:
    /// - `a`: UUID of the first session (required)
    /// - `b`: UUID of the second session (required)
    ///
    /// - Parameter req: Vapor Request with `a` and `b` query params
    /// - Returns: APIResponse with SessionComparisonResult containing both sessions and their messages
    @Sendable
    func compare(req: Request) async throws -> APIResponse<SessionComparisonResult> {
        guard let idA = req.query[UUID.self, at: "a"] else {
            throw Abort(.badRequest, reason: "Query parameter 'a' (session ID) is required")
        }
        guard let idB = req.query[UUID.self, at: "b"] else {
            throw Abort(.badRequest, reason: "Query parameter 'b' (session ID) is required")
        }

        guard let sessionA = try await SessionModel.query(on: req.db)
            .filter(\.$id == idA)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session A not found")
        }

        guard let sessionB = try await SessionModel.query(on: req.db)
            .filter(\.$id == idB)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session B not found")
        }

        let messagesA = try await MessageModel.query(on: req.db)
            .filter(\.$session.$id == idA)
            .sort(\.$createdAt, .ascending)
            .all()

        let messagesB = try await MessageModel.query(on: req.db)
            .filter(\.$session.$id == idB)
            .sort(\.$createdAt, .ascending)
            .all()

        return APIResponse(
            success: true,
            data: SessionComparisonResult(
                sessionA: sessionA.toShared(projectName: sessionA.project?.name),
                sessionB: sessionB.toShared(projectName: sessionB.project?.name),
                messagesA: messagesA.map { $0.toShared() },
                messagesB: messagesB.map { $0.toShared() }
            )
        )
    }

    /// Get recent search history, most recent first (up to 20 unique queries).
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with list of SearchHistoryEntry
    @Sendable
    func getSearchHistory(req: Request) async throws -> APIResponse<[SearchHistoryEntry]> {
        let histories = try await SearchHistoryModel.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .limit(20)
            .all()

        let entries = histories.compactMap { model -> SearchHistoryEntry? in
            guard let id = model.id, let createdAt = model.createdAt else { return nil }
            return SearchHistoryEntry(
                id: id,
                query: model.query,
                resultCount: model.resultCount,
                createdAt: createdAt
            )
        }

        return APIResponse(success: true, data: entries)
    }

    /// Clear all search history entries.
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with deletion confirmation
    @Sendable
    func clearSearchHistory(req: Request) async throws -> APIResponse<DeletedResponse> {
        try await SearchHistoryModel.query(on: req.db).delete()
        return APIResponse(success: true, data: DeletedResponse())
    }

    /// Prune search history to keep only the 20 most recent unique queries.
    ///
    /// Removes older duplicates when the same query has been run multiple times,
    /// then trims the total to 20 entries.
    private func pruneSearchHistory(on db: Database) async throws {
        let all = try await SearchHistoryModel.query(on: db)
            .sort(\.$createdAt, .descending)
            .all()

        var seen = Set<String>()
        var toDelete: [UUID] = []

        for entry in all {
            guard let id = entry.id else { continue }
            if seen.contains(entry.query) || seen.count >= 20 {
                toDelete.append(id)
            } else {
                seen.insert(entry.query)
            }
        }

        if !toDelete.isEmpty {
            try await SearchHistoryModel.query(on: db)
                .filter(\.$id ~~ toDelete)
                .delete()
        }
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

    // MARK: - Model Stats

    /// Return aggregated model usage statistics across all DB sessions.
    ///
    /// Groups `SessionModel` records by their `model` field, computes session
    /// counts and cumulative costs, and returns a `ModelStatsResponse`.
    ///
    /// - Parameter req: Vapor Request (no query params required)
    /// - Returns: APIResponse with ModelStatsResponse
    // PERF-005: Field projection — only fetch columns needed for aggregation (model, totalCostUSD).
    // Avoids loading large text fields (name, claudeSessionId, etc.) that aren't used here.
    @Sendable
    func modelStats(req: Request) async throws -> APIResponse<ModelStatsResponse> {
        let sessions = try await SessionModel.query(on: req.db)
            .field(\.$id)
            .field(\.$model)
            .field(\.$totalCostUSD)
            .all()

        let total = sessions.count

        // Group by model string, accumulating session counts and costs
        var counts: [String: Int] = [:]
        var costs: [String: Double] = [:]
        for session in sessions {
            let model = session.model
            counts[model, default: 0] += 1
            if let cost = session.totalCostUSD {
                costs[model, default: 0.0] += cost
            }
        }

        // Build per-model stats, sorted by session count descending
        let stats = counts.map { model, count in
            ModelUsageStat(
                model: model,
                sessionCount: count,
                totalCostUSD: costs[model],
                percentage: total > 0 ? Double(count) / Double(total) : 0.0
            )
        }.sorted { $0.sessionCount > $1.sessionCount }

        let dominantModel = stats.first?.model

        return APIResponse(
            success: true,
            data: ModelStatsResponse(
                stats: stats,
                totalSessions: total,
                dominantModel: dominantModel
            )
        )
    }

    // MARK: - Model Routing

    /// Suggest the optimal Claude model for a given prompt and budget.
    ///
    /// Decodes a `ModelRoutingRequest`, applies `ModelRoutingService` heuristics,
    /// and returns a `ModelRoutingResponse` with the recommended model and reasoning.
    ///
    /// - Parameter req: Vapor Request with ModelRoutingRequest body
    /// - Returns: APIResponse with ModelRoutingResponse
    @Sendable
    func suggestModel(req: Request) async throws -> APIResponse<ModelRoutingResponse> {
        let input = try req.content.decode(ModelRoutingRequest.self)

        try PathSanitizer.validateStringLength(input.prompt, maxLength: 10_000, fieldName: "prompt")

        let routing = ModelRoutingService()
        let response = routing.suggestModel(
            prompt: input.prompt,
            maxBudgetUSD: input.maxBudgetUSD,
            preferSpeed: input.preferSpeed
        )

        return APIResponse(success: true, data: response)
    }

    // MARK: - Update Session Model

    /// Update the Claude model of an existing session.
    ///
    /// Validates that the provided model string is a known Claude model identifier
    /// (haiku, sonnet, opus, or a `claude-` prefixed string), then persists the change.
    ///
    /// - Parameter req: Vapor Request with id parameter and UpdateSessionModelRequest body
    /// - Returns: APIResponse with updated ChatSession
    @Sendable
    func updateModel(req: Request) async throws -> APIResponse<ChatSession> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        let input = try req.content.decode(UpdateSessionModelRequest.self)

        // Validate model string — must be a known short name or claude- prefixed identifier
        try PathSanitizer.validateStringLength(input.model, maxLength: 128, fieldName: "model")
        let validShortNames = Set(["haiku", "sonnet", "opus"])
        guard validShortNames.contains(input.model.lowercased()) || input.model.lowercased().hasPrefix("claude-") else {
            throw Abort(.badRequest, reason: "Invalid model '\(input.model)'. Must be 'haiku', 'sonnet', 'opus', or a 'claude-' prefixed identifier.")
        }

        guard let session = try await SessionModel.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        session.model = input.model
        try await session.save(on: req.db)

        return APIResponse(
            success: true,
            data: session.toShared(projectName: session.project?.name)
        )
    }

    // MARK: - Integrity Check

    /// Verify the integrity of all DB sessions by comparing stored messageCount against the
    /// actual number of MessageModel rows.
    ///
    /// Query parameters:
    /// - `fix`: If "true", automatically updates sessions whose stored count diverges from actual.
    ///
    /// - Parameter req: Vapor Request with optional `fix` query param
    /// - Returns: APIResponse with list of IntegrityCheckResult for every session checked
    @Sendable
    func integrityCheck(req: Request) async throws -> APIResponse<[IntegrityCheckResult]> {
        let fix = req.query[String.self, at: "fix"] == "true"

        // PERF-005: Field projection — only fetch id and messageCount for integrity comparison.
        let sessions = try await SessionModel.query(on: req.db)
            .field(\.$id)
            .field(\.$messageCount)
            .all()
        var results: [IntegrityCheckResult] = []
        results.reserveCapacity(sessions.count)

        for session in sessions {
            guard let sessionId = session.id else { continue }

            let actualCount = try await MessageModel.query(on: req.db)
                .filter(\.$session.$id == sessionId)
                .count()

            var issues: [String] = []

            if session.messageCount != actualCount {
                issues.append("messageCount mismatch: stored \(session.messageCount), actual \(actualCount)")

                if fix {
                    session.messageCount = actualCount
                    try await session.save(on: req.db)
                }
            }

            results.append(IntegrityCheckResult(
                sessionId: sessionId,
                passed: issues.isEmpty,
                issues: issues,
                checkedAt: Date()
            ))
        }

        return APIResponse(success: true, data: results)
    }

    // MARK: - Chat Export

    /// Export a session's chat history in the requested format.
    ///
    /// Query parameters:
    /// - `format`: Export format — "json" (default), "markdown", or "text"
    /// Register an APNs push token for Live Activity updates on a session.
    ///
    /// Called by the iOS app immediately after a Live Activity is started with
    /// `pushType: .token`. The token is stored on the session record and used by
    /// the backend to deliver content-state pushes when the SSE connection is
    /// unavailable (app backgrounded).
    ///
    /// - Route: `POST /sessions/:id/live-activity-token`
    /// - Body: `{"pushToken": "<hex-encoded token>"}`
    /// - Returns: APIResponse with acknowledgment
    @Sendable
    func registerLiveActivityToken(req: Request) async throws -> APIResponse<AcknowledgedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        struct TokenBody: Content {
            let pushToken: String
        }

        let body = try req.content.decode(TokenBody.self)
        guard !body.pushToken.isEmpty else {
            throw Abort(.badRequest, reason: "pushToken must not be empty")
        }

        guard let session = try await SessionModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        session.liveActivityPushToken = body.pushToken
        try await session.save(on: req.db)

        req.logger.info("[LiveActivity] Registered push token for session \(id.uuidString)")
        return APIResponse(success: true, data: AcknowledgedResponse(acknowledged: true))
    }

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
        let createdAt = session.createdAt ?? Date()
        let lastActiveAt = session.lastActiveAt ?? Date()
        let durationSeconds = lastActiveAt.timeIntervalSince(createdAt)

        let exportSession = ChatExportSession(
            id: session.id ?? UUID(),
            name: session.name,
            model: session.model,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt,
            messageCount: session.messageCount,
            totalCostUSD: session.totalCostUSD,
            projectName: session.project?.name,
            durationSeconds: durationSeconds > 0 ? durationSeconds : nil
        )

        let exportMessages = messages.map { msg in
            ChatExportMessage(
                role: MessageRole(rawValue: msg.role) ?? .user,
                content: msg.content,
                toolCalls: msg.toolCalls,
                toolResults: msg.toolResults,
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
