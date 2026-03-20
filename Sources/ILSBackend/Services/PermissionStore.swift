import Foundation
import Fluent
import ILSShared
import Logging

/// In-memory store for pending and recently-resolved Claude Code permission requests.
///
/// ## Architecture
///
/// Acts as the central authority for the permission request lifecycle:
/// 1. When Claude emits a `permission` stream event, `addPending` captures it.
/// 2. The iOS client polls `/permissions/pending` and presents the request to the user.
/// 3. On user decision, `resolve` moves the record from pending → resolved and records the outcome.
/// 4. `history` exposes the resolved ring-buffer for the audit trail UI.
///
/// The resolved history is bounded to 500 entries (FIFO eviction) to avoid unbounded growth
/// over long-running server sessions. Pending requests are evicted when a session ends via
/// `clearPending(sessionId:)`.
///
/// ## Concurrency
///
/// Declared as an `actor` so all mutations are automatically serialised — no explicit locking
/// required. Callers must `await` every mutating method.
actor PermissionStore {
    /// Shared singleton accessible throughout the backend without dependency injection.
    static let shared = PermissionStore()

    /// Structured logger for PermissionStore operations.
    private static let logger = Logger(label: "ils.permission-store")

    /// Optional Fluent database handle for persisting audit trail entries.
    /// Set via `configure(database:)` during server startup.
    private var database: (any Database)?

    /// Maximum number of resolved records retained in memory.
    private let resolvedCapacity = 500

    /// Pending requests keyed by `requestId` for O(1) lookup during resolution.
    private var pendingRequests: [String: PermissionRecord] = [:]

    /// Resolved records in insertion order (oldest first).
    /// Bounded to `resolvedCapacity`; oldest entries are evicted when the limit is reached.
    private var resolvedRecords: [PermissionRecord] = []

    // MARK: - Public API

    /// Configure the database handle for audit trail persistence.
    ///
    /// Call this once during server startup (from `configure.swift`) so that
    /// policy-driven auto-approve and auto-deny decisions are logged to the
    /// `AuditActionModel` table.
    ///
    /// - Parameter database: Fluent `Database` handle to use for audit writes.
    func configure(database: any Database) {
        self.database = database
    }

    /// Create and store a new pending permission request, evaluating it against configured policies.
    ///
    /// Infers the risk level from the tool name using a simple heuristic:
    /// - `bash` / `computer` → `.critical`
    /// - write/edit/create/delete/move/rename → `.high`
    /// - read/glob/grep/search/ls/find → `.low`
    /// - everything else → `.medium`
    ///
    /// Evaluation proceeds in two stages:
    ///
    /// 1. **Approval guardrails** (in-memory, fast): Evaluates against `ApprovalPolicyStore`
    ///    templates. If autoApprove/autoDeny → immediately resolves with reason code.
    ///    If alwaysAsk/requireConfirmation → falls through to next stage.
    ///
    /// 2. **Permission policies** (DB-based): When `db` is supplied, evaluates against
    ///    `PermissionPolicy` models. If a matching policy is found, the record is
    ///    auto-resolved and persisted to the database.
    ///
    /// - Parameters:
    ///   - requestId: Unique identifier emitted by Claude (e.g. the tool-use block ID).
    ///   - sessionId: UUID string of the session that triggered the request.
    ///   - toolName: Name of the tool Claude wants to use (e.g. "Bash", "Write").
    ///   - toolInput: Arbitrary tool input parameters as `AnyCodable`.
    ///   - sessionName: Human-readable session name for display, if available.
    ///   - projectName: Project name associated with the session, if available.
    ///   - db: Optional database connection for permission policy evaluation and persistence.
    /// - Returns: The newly created `PermissionRecord` (status may be `.autoApproved` or
    ///   `.denied` if a policy matched, otherwise `.pending`).
    @discardableResult
    func addPending(
        requestId: String,
        sessionId: String,
        toolName: String,
        toolInput: AnyCodable,
        sessionName: String?,
        projectName: String?,
        db: Database? = nil
    ) async -> PermissionRecord {
        let riskLevel = Self.inferRiskLevel(from: toolName)

        // Stage 1: Evaluate against approval guardrails (in-memory, fast).
        let approvalEval = await PolicyEvaluationService.shared.evaluateApprovalPolicy(
            toolName: toolName,
            toolInput: toolInput,
            riskLevel: riskLevel,
            projectId: projectName
        )

        let policyIdString = approvalEval.policyId?.uuidString
        let reasonCodeString = approvalEval.reasonCode?.rawValue
        let policyActionString = approvalEval.action.rawValue

        switch approvalEval.action {
        case .autoApprove:
            // Approval policy says auto-approve: create record and immediately resolve it.
            let record = PermissionRecord(
                id: UUID().uuidString,
                requestId: requestId,
                sessionId: sessionId,
                sessionName: sessionName,
                projectName: projectName,
                toolName: toolName,
                toolInput: toolInput,
                status: .autoApproved,
                riskLevel: riskLevel,
                requestedAt: Date(),
                resolvedAt: Date(),
                resolvedBy: "policy",
                policyId: policyIdString,
                reasonCode: reasonCodeString,
                policyAction: policyActionString
            )

            // Store directly in resolved history (skip pending).
            if resolvedRecords.count >= resolvedCapacity {
                resolvedRecords.removeFirst()
            }
            resolvedRecords.append(record)

            Self.logger.info("Permission auto-approved by approval policy: \(requestId) tool=\(toolName) policy=\(policyIdString ?? "none")")
            await logAuditEntry(record: record, evaluation: approvalEval)
            return record

        case .autoDeny:
            // Approval policy says auto-deny: create record and immediately resolve as denied.
            let record = PermissionRecord(
                id: UUID().uuidString,
                requestId: requestId,
                sessionId: sessionId,
                sessionName: sessionName,
                projectName: projectName,
                toolName: toolName,
                toolInput: toolInput,
                status: .denied,
                riskLevel: riskLevel,
                requestedAt: Date(),
                resolvedAt: Date(),
                resolvedBy: "policy",
                denyReason: approvalEval.explanation,
                policyId: policyIdString,
                reasonCode: reasonCodeString,
                policyAction: policyActionString
            )

            // Store directly in resolved history (skip pending).
            if resolvedRecords.count >= resolvedCapacity {
                resolvedRecords.removeFirst()
            }
            resolvedRecords.append(record)

            Self.logger.info("Permission auto-denied by approval policy: \(requestId) tool=\(toolName) reason=\(reasonCodeString ?? "none")")
            await logAuditEntry(record: record, evaluation: approvalEval)
            return record

        case .alwaysAsk, .requireConfirmation:
            // Approval policy says manual review required — fall through to permission policies.
            break
        }

        // Stage 2: Create record in pending state with approval policy context.
        let record = PermissionRecord(
            id: UUID().uuidString,
            requestId: requestId,
            sessionId: sessionId,
            sessionName: sessionName,
            projectName: projectName,
            toolName: toolName,
            toolInput: toolInput,
            status: .pending,
            riskLevel: riskLevel,
            requestedAt: Date(),
            policyId: policyIdString,
            reasonCode: reasonCodeString,
            policyAction: policyActionString
        )
        pendingRequests[requestId] = record
        Self.logger.info("Permission pending: \(requestId) tool=\(toolName) session=\(sessionId) policyAction=\(policyActionString)")

        // Stage 3: Evaluate against permission policies (DB-based) if database is available.
        if let database = db {
            if let (action, matchedPolicy) = try? await PolicyEvaluationService.shared.evaluate(
                request: record,
                db: database
            ) {
                // Auto-resolve when: a named policy matched, OR default-deny triggered (deny + no policy).
                if matchedPolicy != nil || action == .deny {
                    let autoStatus: PermissionStatus = action == .allow ? .autoApproved : .denied
                    let reason: String? = matchedPolicy == nil ? "Default deny mode active" : nil
                    if let resolved = resolve(
                        requestId: requestId,
                        status: autoStatus,
                        reason: reason,
                        matchedPolicyId: matchedPolicy?.id
                    ) {
                        // Persist the auto-resolved record to the database for audit trail.
                        let model = PermissionModel.from(resolved)
                        try? await model.save(on: database)
                        Self.logger.info(
                            "Permission auto-resolved by permission policy: \(requestId) status=\(autoStatus.rawValue) policy=\(matchedPolicy?.name ?? "default-deny")"
                        )
                        return resolved
                    }
                }
            }
        }

        return record
    }

    /// Resolve a pending permission request with a user or policy decision.
    ///
    /// Moves the record from `pendingRequests` to `resolvedRecords`, updating its status,
    /// `resolvedAt` timestamp, and optional deny reason. If the `resolvedRecords` buffer
    /// is at capacity, the oldest entry is evicted.
    ///
    /// - Parameters:
    ///   - requestId: The `requestId` of the pending record to resolve.
    ///   - status: Final status — `.approved`, `.denied`, `.autoApproved`, or `.expired`.
    ///   - reason: Optional denial reason or resolution note.
    ///   - matchedPolicyId: UUID of the permission policy that triggered this resolution, if auto-resolved.
    /// - Returns: The updated `PermissionRecord`, or `nil` if `requestId` was not found.
    @discardableResult
    func resolve(
        requestId: String,
        status: PermissionStatus,
        reason: String?,
        matchedPolicyId: UUID? = nil
    ) -> PermissionRecord? {
        guard let existing = pendingRequests.removeValue(forKey: requestId) else {
            Self.logger.warning("Resolve called for unknown requestId: \(requestId)")
            return nil
        }

        let resolvedBy: String
        switch status {
        case .autoApproved: resolvedBy = "auto"
        case .expired:      resolvedBy = "timeout"
        default:            resolvedBy = "user"
        }

        let resolved = PermissionRecord(
            id: existing.id,
            requestId: existing.requestId,
            sessionId: existing.sessionId,
            sessionName: existing.sessionName,
            projectName: existing.projectName,
            toolName: existing.toolName,
            toolInput: existing.toolInput,
            status: status,
            riskLevel: existing.riskLevel,
            requestedAt: existing.requestedAt,
            resolvedAt: Date(),
            resolvedBy: resolvedBy,
            denyReason: reason,
            isSessionApproval: existing.isSessionApproval,
            policyId: existing.policyId,
            reasonCode: existing.reasonCode,
            policyAction: existing.policyAction,
            matchedPolicyId: matchedPolicyId
        )

        // Evict oldest entry if at capacity (FIFO)
        if resolvedRecords.count >= resolvedCapacity {
            resolvedRecords.removeFirst()
        }
        resolvedRecords.append(resolved)

        Self.logger.info("Permission resolved: \(requestId) status=\(status.rawValue)")
        return resolved
    }

    /// Return all pending requests sorted newest-first.
    func allPending() -> [PermissionRecord] {
        pendingRequests.values.sorted { $0.requestedAt > $1.requestedAt }
    }

    /// Return resolved records newest-first, up to `limit` entries.
    ///
    /// - Parameter limit: Maximum number of records to return (default 50, capped at 500).
    func history(limit: Int = 50) -> [PermissionRecord] {
        let capped = min(limit, resolvedCapacity)
        return resolvedRecords.suffix(capped).reversed()
    }

    /// Remove all pending requests associated with a session.
    ///
    /// Call this when a session ends or errors out so stale requests don't accumulate.
    ///
    /// - Parameter sessionId: UUID string of the session whose pending requests should be removed.
    func clearPending(sessionId: String) {
        let before = pendingRequests.count
        pendingRequests = pendingRequests.filter { $0.value.sessionId != sessionId }
        let removed = before - pendingRequests.count
        if removed > 0 {
            Self.logger.info("Cleared \(removed) pending permission(s) for session \(sessionId)")
        }
    }

    // MARK: - Private Helpers

    /// Log a policy-driven permission decision to the audit trail.
    ///
    /// Creates an `AuditActionModel` entry with `actionType = .permissionDecision` so that
    /// deterministic auto-approve and auto-deny actions appear in the activity history alongside
    /// manual user decisions.
    ///
    /// Failures are logged but do not propagate — audit logging must never block the permission flow.
    ///
    /// - Parameters:
    ///   - record: The resolved `PermissionRecord` (auto-approved or denied).
    ///   - evaluation: The `PolicyEvaluationResult` that drove the decision.
    private func logAuditEntry(record: PermissionRecord, evaluation: ILSShared.PolicyEvaluationResult) async {
        guard let db = database else {
            Self.logger.debug("Audit logging skipped — no database configured")
            return
        }

        let statusLabel = record.status == .autoApproved ? "auto-approved" : "denied"
        let description = "Permission \(statusLabel) by policy for tool '\(record.toolName)'"

        // Encode policy context as JSON metadata for queryability.
        var metadataDict: [String: String] = [
            "requestId": record.requestId,
            "policyAction": evaluation.action.rawValue,
            "explanation": evaluation.explanation,
            "riskLevel": record.riskLevel.rawValue
        ]
        if let policyId = evaluation.policyId {
            metadataDict["policyId"] = policyId.uuidString
        }
        if let reasonCode = evaluation.reasonCode {
            metadataDict["reasonCode"] = reasonCode.rawValue
        }

        let metadataJSON: String?
        if let data = try? JSONEncoder().encode(metadataDict) {
            metadataJSON = String(data: data, encoding: .utf8)
        } else {
            metadataJSON = nil
        }

        let auditModel = AuditActionModel(
            sessionId: record.sessionId,
            sessionName: record.sessionName,
            actionType: .permissionDecision,
            description: description,
            toolName: record.toolName,
            metadata: metadataJSON,
            isRollbackable: false
        )

        do {
            try await auditModel.save(on: db)
            Self.logger.debug("Audit entry logged for permission \(statusLabel): \(record.requestId)")
        } catch {
            Self.logger.warning("Failed to log audit entry for permission \(record.requestId): \(error)")
        }
    }

    /// Infer a risk level from a tool name using lightweight pattern matching.
    private static func inferRiskLevel(from toolName: String) -> PermissionRiskLevel {
        let lower = toolName.lowercased()

        // Critical: arbitrary code execution or system control
        if lower == "bash" || lower.contains("computer") || lower.contains("execute") {
            return .critical
        }

        // High: write operations that can modify or destroy data
        let highKeywords = ["write", "edit", "create", "delete", "move", "rename", "patch", "overwrite", "rm", "remove"]
        if highKeywords.contains(where: { lower.contains($0) }) {
            return .high
        }

        // Low: read-only operations
        let lowKeywords = ["read", "glob", "grep", "search", "ls", "find", "cat", "list", "view", "fetch", "get"]
        if lowKeywords.contains(where: { lower.contains($0) }) {
            return .low
        }

        return .medium
    }
}
