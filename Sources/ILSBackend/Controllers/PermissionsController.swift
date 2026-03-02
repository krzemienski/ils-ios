import Vapor
import ILSShared

/// Controller managing Claude Code tool-use permission requests.
///
/// Routes:
/// - `GET /permissions/pending`: List all pending permission requests
/// - `GET /permissions/history`: List resolved permission history
/// - `POST /permissions/:requestId/decide`: Submit allow/deny decision for a pending request
/// - `DELETE /permissions/pending`: Clear pending requests (optionally scoped to a session)
struct PermissionsController: RouteCollection {

    /// Executor used to forward permission decisions to active Claude processes via stdin.
    let executor: ClaudeExecutorService

    init(executor: ClaudeExecutorService) {
        self.executor = executor
    }

    func boot(routes: RoutesBuilder) throws {
        let permissions = routes.grouped("permissions")
        permissions.get("pending", use: listPending)
        permissions.get("history", use: listHistory)
        permissions.post(":requestId", "decide", use: decide)
        permissions.delete("pending", use: clearPending)
    }

    // MARK: - List Pending

    /// GET /permissions/pending
    ///
    /// Returns all pending permission requests sorted newest-first.
    ///
    /// Query parameters:
    /// - `sessionId`: Optional UUID string — restrict results to a single session
    @Sendable
    func listPending(req: Request) async throws -> APIResponse<PermissionListResponse> {
        let sessionIdFilter: String? = req.query["sessionId"]

        var pending = await PermissionStore.shared.allPending()

        if let sid = sessionIdFilter {
            pending = pending.filter { $0.sessionId == sid }
        }

        return APIResponse(
            success: true,
            data: PermissionListResponse(
                items: pending,
                total: pending.count,
                pendingCount: pending.count
            )
        )
    }

    // MARK: - List History

    /// GET /permissions/history
    ///
    /// Returns resolved permission records sorted newest-first.
    ///
    /// Query parameters:
    /// - `limit`: Maximum records to return (default: 50, max: 500)
    /// - `sessionId`: Optional UUID string — restrict results to a single session
    @Sendable
    func listHistory(req: Request) async throws -> APIResponse<PermissionListResponse> {
        let limit = min((req.query["limit"] as Int?) ?? 50, 500)
        let sessionIdFilter: String? = req.query["sessionId"]

        var records = await PermissionStore.shared.history(limit: limit)

        if let sid = sessionIdFilter {
            records = records.filter { $0.sessionId == sid }
        }

        let pendingCount = await PermissionStore.shared.allPending().count

        return APIResponse(
            success: true,
            data: PermissionListResponse(
                items: records,
                total: records.count,
                pendingCount: pendingCount
            )
        )
    }

    // MARK: - Submit Decision

    /// POST /permissions/:requestId/decide
    ///
    /// Submits an allow or deny decision for a pending permission request.
    /// Resolves the record in `PermissionStore` and forwards the decision
    /// to the active Claude CLI process via stdin.
    ///
    /// Request body: `PermissionDecision` with `decision` ("allow" or "deny") and optional `reason`.
    ///
    /// - Parameter req: Vapor Request with requestId path parameter and PermissionDecision body
    /// - Returns: APIResponse with acknowledgment
    @Sendable
    func decide(req: Request) async throws -> APIResponse<AcknowledgedResponse> {
        guard let requestId = req.parameters.get("requestId") else {
            throw Abort(.badRequest, reason: "Missing requestId parameter")
        }

        let input = try req.content.decode(PermissionDecision.self)

        let status: PermissionStatus = input.decision == "allow" ? .approved : .denied

        guard let record = await PermissionStore.shared.resolve(
            requestId: requestId,
            status: status,
            reason: input.reason
        ) else {
            throw Abort(.notFound, reason: "Permission request '\(requestId)' not found or already resolved")
        }

        // Forward decision to the active Claude process via stdin.
        // Logs a warning but does not fail if the process has already exited.
        let sent = await executor.sendPermissionResponse(
            sessionId: record.sessionId,
            requestId: requestId,
            decision: input.decision
        )

        if !sent {
            req.logger.warning(
                "Permission decision '\(input.decision)' recorded but no active process for session \(record.sessionId)"
            )
        }

        req.logger.info(
            "Permission \(input.decision) for requestId=\(requestId) session=\(record.sessionId)"
        )

        return APIResponse(success: true, data: AcknowledgedResponse())
    }

    // MARK: - Clear Pending

    /// DELETE /permissions/pending
    ///
    /// Removes pending permission requests from the store.
    /// When `sessionId` is provided only that session's requests are cleared;
    /// otherwise all pending requests across every session are removed.
    ///
    /// Query parameters:
    /// - `sessionId`: Optional UUID string — restrict clearing to a single session
    @Sendable
    func clearPending(req: Request) async throws -> APIResponse<AcknowledgedResponse> {
        let sessionIdFilter: String? = req.query["sessionId"]

        if let sid = sessionIdFilter {
            await PermissionStore.shared.clearPending(sessionId: sid)
            req.logger.info("Cleared pending permissions for session \(sid)")
        } else {
            // Collect unique session IDs from all pending requests then clear each.
            let pending = await PermissionStore.shared.allPending()
            let sessionIds = Set(pending.map(\.sessionId))
            for sid in sessionIds {
                await PermissionStore.shared.clearPending(sessionId: sid)
            }
            req.logger.info("Cleared all pending permissions (\(pending.count) requests)")
        }

        return APIResponse(success: true, data: AcknowledgedResponse())
    }
}
