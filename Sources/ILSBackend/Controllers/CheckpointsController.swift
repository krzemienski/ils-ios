import Vapor
import Fluent
import ILSShared

/// Controller for checkpoint management operations.
///
/// Routes (nested under sessions, relative to the `/api/v1` prefix):
/// - `GET /sessions/:id/checkpoints`: List all checkpoints for a session (newest first)
/// - `POST /sessions/:id/checkpoints`: Create a new checkpoint (snapshots current message IDs)
/// - `DELETE /sessions/:id/checkpoints/:checkpointId`: Delete a specific checkpoint
/// - `POST /sessions/:id/checkpoints/:checkpointId/restore`: Restore session to a checkpoint
struct CheckpointsController: RouteCollection {
    /// Maximum number of auto-checkpoints retained per session before the oldest are pruned.
    private static let autoCheckpointRetentionLimit = 20

    func boot(routes: RoutesBuilder) throws {
        let sessionCheckpoints = routes.grouped("sessions", ":id", "checkpoints")

        sessionCheckpoints.get(use: list)
        sessionCheckpoints.post(use: create)
        sessionCheckpoints.delete(":checkpointId", use: delete)
        sessionCheckpoints.post(":checkpointId", "restore", use: restore)
    }

    // MARK: - List

    /// List all checkpoints for a session, ordered from newest to oldest.
    /// - Parameter req: Vapor Request with `id` path parameter (session UUID).
    /// - Returns: `APIResponse` containing an array of `Checkpoint` values.
    @Sendable
    func list(req: Request) async throws -> APIResponse<[Checkpoint]> {
        guard let sessionId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard try await SessionModel.find(sessionId, on: req.db) != nil else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let checkpoints = try await CheckpointModel.query(on: req.db)
            .filter(\.$session.$id == sessionId)
            .sort(\.$createdAt, .descending)
            .all()

        let shared = try checkpoints.map { try $0.toShared() }
        return APIResponse(success: true, data: shared)
    }

    // MARK: - Create

    /// Create a new checkpoint for a session.
    ///
    /// Snapshots the current set of message IDs (ordered by creation time) from the database.
    /// For auto-checkpoints, the oldest auto-checkpoints beyond the retention limit are pruned
    /// after the new checkpoint is saved.
    ///
    /// - Parameter req: Vapor Request with `id` path parameter and `CreateCheckpointRequest` body.
    /// - Returns: `APIResponse` containing the newly created `Checkpoint`.
    @Sendable
    func create(req: Request) async throws -> APIResponse<Checkpoint> {
        guard let sessionId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        let input = try req.content.decode(CreateCheckpointRequest.self)
        try PathSanitizer.validateOptionalStringLength(input.label, maxLength: 255, fieldName: "label")

        guard let session = try await SessionModel.find(sessionId, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        // Snapshot the current message IDs in insertion order.
        let messages = try await MessageModel.query(on: req.db)
            .filter(\.$session.$id == sessionId)
            .sort(\.$createdAt, .ascending)
            .all()
        let messageIds = messages.compactMap { $0.id }

        let checkpoint = try CheckpointModel(
            sessionId: sessionId,
            label: input.label,
            messageCount: messageIds.count,
            snapshotMessageIds: messageIds,
            isAuto: input.isAuto
        )
        try await checkpoint.save(on: req.db)

        // Enforce auto-checkpoint retention limit.
        if input.isAuto {
            let retentionLimit = input.maxRetained ?? Self.autoCheckpointRetentionLimit
            let autoCheckpoints = try await CheckpointModel.query(on: req.db)
                .filter(\.$session.$id == sessionId)
                .filter(\.$isAuto == true)
                .sort(\.$createdAt, .descending)
                .all()

            if autoCheckpoints.count > retentionLimit {
                let toDelete = Array(autoCheckpoints.dropFirst(retentionLimit))
                for old in toDelete {
                    try await old.delete(on: req.db)
                }
            }
        }

        // Keep the session message count in sync.
        session.messageCount = messageIds.count
        try await session.save(on: req.db)

        return APIResponse(success: true, data: try checkpoint.toShared())
    }

    // MARK: - Delete

    /// Delete a specific checkpoint.
    /// - Parameter req: Vapor Request with `id` (session UUID) and `checkpointId` path parameters.
    /// - Returns: `APIResponse` confirming deletion.
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let sessionId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }
        guard let checkpointId = req.parameters.get("checkpointId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid checkpoint ID")
        }

        guard let checkpoint = try await CheckpointModel.query(on: req.db)
            .filter(\.$id == checkpointId)
            .filter(\.$session.$id == sessionId)
            .first() else {
            throw Abort(.notFound, reason: "Checkpoint not found")
        }

        try await checkpoint.delete(on: req.db)
        return APIResponse(success: true, data: DeletedResponse(deleted: true))
    }

    // MARK: - Restore

    /// Restore a session to the message state captured in a checkpoint.
    ///
    /// Deletes all messages whose IDs are not present in the checkpoint's snapshot,
    /// then updates the session's message count to reflect the restored state.
    ///
    /// - Parameter req: Vapor Request with `id` (session UUID) and `checkpointId` path parameters.
    /// - Returns: `APIResponse` containing a `RestoreCheckpointResponse` with the restored count.
    @Sendable
    func restore(req: Request) async throws -> APIResponse<RestoreCheckpointResponse> {
        guard let sessionId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }
        guard let checkpointId = req.parameters.get("checkpointId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid checkpoint ID")
        }

        guard let session = try await SessionModel.find(sessionId, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        guard let checkpoint = try await CheckpointModel.query(on: req.db)
            .filter(\.$id == checkpointId)
            .filter(\.$session.$id == sessionId)
            .first() else {
            throw Abort(.notFound, reason: "Checkpoint not found")
        }

        let snapshotIds = try checkpoint.decodeMessageIds()
        let snapshotIdSet = Set(snapshotIds)

        // Delete messages that are not part of the checkpoint snapshot.
        let allMessages = try await MessageModel.query(on: req.db)
            .filter(\.$session.$id == sessionId)
            .all()

        let messagesToDelete = allMessages.filter { msg in
            guard let msgId = msg.id else { return false }
            return !snapshotIdSet.contains(msgId)
        }
        for msg in messagesToDelete {
            try await msg.delete(on: req.db)
        }

        // Update session message count to reflect restored state.
        let restoredCount = snapshotIds.count
        session.messageCount = restoredCount
        try await session.save(on: req.db)

        return APIResponse(success: true, data: RestoreCheckpointResponse(restoredMessageCount: restoredCount))
    }
}
