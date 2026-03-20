import Vapor
import Fluent
import ILSShared

/// Controller for session checkpoint (backup) operations.
///
/// Routes:
/// - `GET /sessions/:id/checkpoints`: List all checkpoints for a session
/// - `POST /sessions/:id/checkpoints`: Create a named checkpoint for a session
/// - `DELETE /sessions/checkpoints/:checkpointId`: Delete a checkpoint
/// - `POST /sessions/checkpoints/:checkpointId/restore`: Fork session up to checkpoint messageCount
struct SessionBackupController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let sessions = routes.grouped("sessions")

        sessions.get("recoverable", use: listRecoverableSessions)
        sessions.get(":id", "checkpoints", use: listCheckpoints)
        sessions.post(":id", "checkpoints", use: createCheckpoint)
        sessions.delete("checkpoints", ":checkpointId", use: deleteCheckpoint)
        sessions.post("checkpoints", ":checkpointId", "restore", use: restoreCheckpoint)
    }

    // MARK: - Recoverable Sessions

    /// List sessions that terminated with an error and have at least one checkpoint,
    /// ordered by lastActiveAt descending (most recently interrupted first).
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with list of ChatSession objects eligible for recovery
    @Sendable
    func listRecoverableSessions(req: Request) async throws -> APIResponse<ListResponse<ChatSession>> {
        // Fetch all session IDs that have at least one checkpoint
        let checkpointedSessionIds = try await SessionCheckpointModel.query(on: req.db)
            .field(\.$session.$id)
            .unique()
            .all()
            .compactMap { $0.$session.id }

        guard !checkpointedSessionIds.isEmpty else {
            return APIResponse(success: true, data: ListResponse(items: [], total: 0))
        }

        let errorStatus = SessionStatus.error.rawValue

        let sessions = try await SessionModel.query(on: req.db)
            .filter(\.$status == errorStatus)
            .filter(\.$id ~~ checkpointedSessionIds)
            .sort(\.$lastActiveAt, .descending)
            .all()

        let shared = sessions.map { $0.toShared(projectName: nil) }
        return APIResponse(
            success: true,
            data: ListResponse(items: shared, total: shared.count)
        )
    }

    // MARK: - Checkpoint CRUD

    /// List all checkpoints for a session, sorted by creation date descending.
    ///
    /// - Parameter req: Vapor Request with `id` parameter (session UUID)
    /// - Returns: APIResponse with list of SessionCheckpoint objects
    @Sendable
    func listCheckpoints(req: Request) async throws -> APIResponse<ListResponse<SessionCheckpoint>> {
        guard let sessionId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let _ = try await SessionModel.find(sessionId, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let checkpoints = try await SessionCheckpointModel.query(on: req.db)
            .filter(\.$session.$id == sessionId)
            .sort(\.$createdAt, .descending)
            .all()

        let shared = checkpoints.map { $0.toShared() }
        return APIResponse(
            success: true,
            data: ListResponse(items: shared, total: shared.count)
        )
    }

    /// Create a named checkpoint for a session at the current message count.
    ///
    /// - Parameter req: Vapor Request with `id` parameter and CreateCheckpointRequest body
    /// - Returns: APIResponse with created SessionCheckpoint
    @Sendable
    func createCheckpoint(req: Request) async throws -> APIResponse<SessionCheckpoint> {
        guard let sessionId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        let input = try req.content.decode(CreateCheckpointRequest.self)

        let name = (input.label ?? "Checkpoint").trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            throw Abort(.badRequest, reason: "Checkpoint name must not be empty")
        }

        guard let session = try await SessionModel.find(sessionId, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let checkpoint = SessionCheckpointModel(
            sessionId: sessionId,
            name: name,
            messageCount: session.messageCount,
            isAutomatic: input.isAuto
        )

        try await checkpoint.save(on: req.db)

        return APIResponse(success: true, data: checkpoint.toShared())
    }

    /// Delete a checkpoint by ID.
    ///
    /// - Parameter req: Vapor Request with `checkpointId` parameter
    /// - Returns: APIResponse confirming deletion
    @Sendable
    func deleteCheckpoint(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let checkpointId = req.parameters.get("checkpointId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid checkpoint ID")
        }

        guard let checkpoint = try await SessionCheckpointModel.find(checkpointId, on: req.db) else {
            throw Abort(.notFound, reason: "Checkpoint not found")
        }

        try await checkpoint.delete(on: req.db)

        return APIResponse(success: true, data: DeletedResponse())
    }

    /// Restore a checkpoint by forking the session up to the checkpoint's message count.
    ///
    /// Creates a new session containing all messages up to (and including) the
    /// checkpoint's `messageCount`, allowing the user to resume from that point.
    ///
    /// - Parameter req: Vapor Request with `checkpointId` parameter
    /// - Returns: APIResponse with newly forked ChatSession
    @Sendable
    func restoreCheckpoint(req: Request) async throws -> APIResponse<ChatSession> {
        guard let checkpointId = req.parameters.get("checkpointId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid checkpoint ID")
        }

        guard let checkpoint = try await SessionCheckpointModel.query(on: req.db)
            .filter(\.$id == checkpointId)
            .with(\.$session)
            .first() else {
            throw Abort(.notFound, reason: "Checkpoint not found")
        }

        let original = checkpoint.session
        guard let originalId = original.id else {
            throw Abort(.internalServerError, reason: "Invalid session reference")
        }

        let messageLimit = checkpoint.messageCount
        let checkpointName = checkpoint.name

        // Wrap fork in a transaction so session + messages are created atomically
        let forked = try await req.db.transaction { db in
            let forked = SessionModel(
                claudeSessionId: nil,
                name: (original.name ?? "Untitled") + " (Restored: \(checkpointName))",
                projectId: original.$project.id,
                model: original.model,
                permissionMode: PermissionMode(rawValue: original.permissionMode) ?? .default,
                forkedFrom: originalId
            )

            try await forked.save(on: db)

            guard let forkedId = forked.id else {
                throw Abort(.internalServerError, reason: "Failed to create forked session")
            }

            // Copy messages up to the checkpoint's messageCount (in creation order)
            let originalMessages = try await MessageModel.query(on: db)
                .filter(\.$session.$id == originalId)
                .sort(\.$createdAt, .ascending)
                .range(..<messageLimit)
                .all()

            for originalMessage in originalMessages {
                let copiedMessage = MessageModel(
                    sessionId: forkedId,
                    role: MessageRole(rawValue: originalMessage.role) ?? .user,
                    content: originalMessage.content,
                    toolCalls: originalMessage.toolCalls,
                    toolResults: originalMessage.toolResults
                )
                try await copiedMessage.save(on: db)
            }

            forked.messageCount = originalMessages.count
            try await forked.save(on: db)

            return forked
        }

        // Load project for name
        let projectName: String?
        if let projectId = original.$project.id {
            let project = try await ProjectModel.find(projectId, on: req.db)
            projectName = project?.name
        } else {
            projectName = nil
        }

        return APIResponse(
            success: true,
            data: forked.toShared(projectName: projectName)
        )
    }

    // MARK: - Auto-Checkpoint Helper

    /// Create an automatic checkpoint for a session if the message count is divisible
    /// by the configured interval.
    ///
    /// Call this after persisting a new message to trigger periodic auto-checkpoints.
    ///
    /// - Parameters:
    ///   - sessionId: The session that received a new message.
    ///   - messageCount: The updated message count after saving the new message.
    ///   - interval: Auto-checkpoint interval (default 10 messages).
    ///   - db: The database connection to use.
    static func createAutoCheckpointIfNeeded(
        sessionId: UUID,
        messageCount: Int,
        interval: Int = 10,
        db: Database
    ) async throws {
        guard interval > 0, messageCount > 0, messageCount.isMultiple(of: interval) else { return }

        let checkpoint = SessionCheckpointModel(
            sessionId: sessionId,
            name: "Auto-checkpoint at \(messageCount) messages",
            messageCount: messageCount,
            isAutomatic: true
        )
        try await checkpoint.save(on: db)
    }
}
