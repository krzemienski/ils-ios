import Vapor
import Fluent
import ILSShared
import Foundation

/// Controller for the AI action audit trail.
///
/// Routes (relative to the `/api/v1` prefix):
/// - `GET /audit-actions`: List audit actions with optional filtering
/// - `POST /audit-actions`: Create a new audit action entry
/// - `POST /audit-actions/:id/rollback`: Roll back a specific audit action
struct AuditController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let auditActions = routes.grouped("audit-actions")

        auditActions.get(use: list)
        auditActions.post(use: create)
        auditActions.post(":id", "rollback", use: rollback)
    }

    // MARK: - List

    /// List audit actions with optional query-param filtering.
    ///
    /// Query parameters:
    /// - `sessionId`: Restrict to a single session
    /// - `actionType`: Restrict to one action type (raw value, e.g. "file_write")
    /// - `filePath`: Restrict to a specific file path (prefix match)
    /// - `since`: ISO 8601 date — include only actions at or after this time
    /// - `until`: ISO 8601 date — include only actions at or before this time
    /// - `limit`: Maximum results (default 50, max 500)
    /// - `offset`: Pagination offset (default 0)
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: `APIResponse` wrapping `AuditActionListResponse`
    @Sendable
    func list(req: Request) async throws -> APIResponse<AuditActionListResponse> {
        let sessionId: String? = req.query["sessionId"]
        let actionTypeRaw: String? = req.query["actionType"]
        let filePath: String? = req.query["filePath"]
        let sinceStr: String? = req.query["since"]
        let untilStr: String? = req.query["until"]
        let limit = min((req.query["limit"] as Int?) ?? 50, 500)
        let offset = max((req.query["offset"] as Int?) ?? 0, 0)

        var query = AuditActionModel.query(on: req.db)

        if let sessionId {
            query = query.filter(\.$sessionId == sessionId)
        }

        if let raw = actionTypeRaw, let actionType = AuditActionType(rawValue: raw) {
            query = query.filter(\.$actionType == actionType.rawValue)
        }

        if let filePath {
            query = query.filter(\.$filePath =~ filePath)
        }

        let isoFormatter = ISO8601DateFormatter()

        if let sinceStr, let since = isoFormatter.date(from: sinceStr) {
            query = query.filter(\.$createdAt >= since)
        }

        if let untilStr, let until = isoFormatter.date(from: untilStr) {
            query = query.filter(\.$createdAt <= until)
        }

        // Count before applying limit/offset for pagination metadata.
        let totalCount = try await query.count()

        let models = try await query
            .sort(\.$createdAt, .descending)
            .range(offset..<(offset + limit))
            .all()

        let actions = try models.map { try $0.toShared() }
        let hasMore = (offset + limit) < totalCount

        return APIResponse(
            success: true,
            data: AuditActionListResponse(
                actions: actions,
                totalCount: totalCount,
                hasMore: hasMore
            )
        )
    }

    // MARK: - Create

    /// Create a new audit action entry.
    ///
    /// The audit trail is append-only — entries cannot be updated or deleted
    /// after creation. Rollback is recorded as a separate audit entry.
    ///
    /// - Parameter req: Vapor Request with `LogAuditActionRequest` body.
    /// - Returns: `APIResponse` containing the newly created `AuditAction`.
    @Sendable
    func create(req: Request) async throws -> APIResponse<AuditAction> {
        let input = try req.content.decode(LogAuditActionRequest.self)

        let model = AuditActionModel(
            sessionId: input.sessionId,
            sessionName: input.sessionName,
            actionType: input.actionType,
            description: input.description,
            filePath: input.filePath,
            command: input.command,
            toolName: input.toolName,
            beforeContent: input.beforeContent,
            afterContent: input.afterContent,
            metadata: input.metadata,
            isRollbackable: input.isRollbackable
        )

        try await model.save(on: req.db)

        return APIResponse(success: true, data: try model.toShared())
    }

    // MARK: - Rollback

    /// Roll back a specific audit action.
    ///
    /// For file operations (`file_write`, `file_create`, `file_delete`),
    /// the `beforeContent` is written back to `filePath` on the local filesystem.
    /// The rollback itself is recorded as a new immutable audit entry,
    /// and the original action's `rollback_status` is updated to `rolled_back`.
    ///
    /// - Parameter req: Vapor Request with `id` path parameter (audit action UUID)
    ///   and optional `RollbackRequest` body.
    /// - Returns: `APIResponse` wrapping a `RollbackResponse`.
    @Sendable
    func rollback(req: Request) async throws -> APIResponse<RollbackResponse> {
        guard let actionId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid audit action ID")
        }

        guard let model = try await AuditActionModel.find(actionId, on: req.db) else {
            throw Abort(.notFound, reason: "Audit action not found")
        }

        guard model.isRollbackable else {
            throw Abort(.unprocessableEntity, reason: "Audit action is not rollbackable")
        }

        guard model.rollbackStatus == RollbackStatus.notRolledBack.rawValue else {
            throw Abort(.conflict, reason: "Audit action has already been rolled back")
        }

        let input = try? req.content.decode(RollbackRequest.self)
        let reason = input?.reason

        // Attempt to restore file content for file operations.
        var rollbackError: String?
        let actionType = AuditActionType(rawValue: model.actionType) ?? .toolUse

        let isFileOp = [AuditActionType.fileWrite, .fileCreate, .fileDelete].contains(actionType)

        if isFileOp {
            if let filePath = model.filePath, !filePath.isEmpty {
                do {
                    try restoreFileContent(
                        filePath: filePath,
                        beforeContent: model.beforeContent,
                        actionType: actionType,
                        req: req
                    )
                } catch {
                    rollbackError = error.localizedDescription
                    req.logger.warning("Rollback file restore failed for \(filePath): \(error)")
                }
            } else {
                rollbackError = "Cannot restore file: no file path recorded"
            }
        }

        let succeeded = rollbackError == nil

        // Create a rollback audit entry to record this operation.
        let rollbackDescription: String
        if let reason {
            rollbackDescription = "Rolled back: \(model.description). Reason: \(reason)"
        } else {
            rollbackDescription = "Rolled back: \(model.description)"
        }

        let rollbackModel = AuditActionModel(
            sessionId: model.sessionId,
            sessionName: model.sessionName,
            actionType: .rollback,
            description: rollbackDescription,
            filePath: model.filePath,
            command: nil,
            toolName: nil,
            beforeContent: nil,
            afterContent: model.beforeContent,
            metadata: model.metadata,
            isRollbackable: false,
            rollbackStatus: .notRolledBack
        )
        try await rollbackModel.save(on: req.db)

        // Update the original action to reflect rolled-back state.
        model.rollbackStatus = RollbackStatus.rolledBack.rawValue
        model.rolledBackAt = Date()
        model.rollbackAuditId = rollbackModel.id
        try await model.save(on: req.db)

        let rollbackShared = try rollbackModel.toShared()

        let resultItem = RollbackResultItem(
            actionId: actionId,
            succeeded: succeeded,
            errorMessage: rollbackError,
            rollbackAuditAction: rollbackShared
        )

        return APIResponse(
            success: true,
            data: RollbackResponse(results: [resultItem])
        )
    }

    // MARK: - Private Helpers

    /// Restores file content on the local filesystem to the pre-action state.
    ///
    /// - For `file_write`: Overwrites the file with `beforeContent`. If `beforeContent`
    ///   is `nil`, this is a no-op (no previous state recorded).
    /// - For `file_create`: Removes the file (it did not exist before Claude created it).
    /// - For `file_delete`: Recreates the file with `beforeContent`.
    private func restoreFileContent(
        filePath: String,
        beforeContent: String?,
        actionType: AuditActionType,
        req: Request
    ) throws {
        let fileManager = FileManager.default

        switch actionType {
        case .fileWrite:
            // Restore previous content. Skip if no before-state was captured.
            guard let content = beforeContent else { return }
            guard let data = content.data(using: .utf8) else {
                throw Abort(.internalServerError, reason: "Failed to encode before-content as UTF-8")
            }
            try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)

        case .fileCreate:
            // File did not exist before; remove it.
            if fileManager.fileExists(atPath: filePath) {
                try fileManager.removeItem(atPath: filePath)
            }

        case .fileDelete:
            // Recreate file with its original content.
            let content = beforeContent ?? ""
            guard let data = content.data(using: .utf8) else {
                throw Abort(.internalServerError, reason: "Failed to encode before-content as UTF-8")
            }
            // Ensure parent directory exists.
            let directory = (filePath as NSString).deletingLastPathComponent
            try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
            fileManager.createFile(atPath: filePath, contents: data)

        default:
            break
        }
    }
}
