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

    /// Maximum number of resolved records retained in memory.
    private let resolvedCapacity = 500

    /// Pending requests keyed by `requestId` for O(1) lookup during resolution.
    private var pendingRequests: [String: PermissionRecord] = [:]

    /// Resolved records in insertion order (oldest first).
    /// Bounded to `resolvedCapacity`; oldest entries are evicted when the limit is reached.
    private var resolvedRecords: [PermissionRecord] = []

    // MARK: - Public API

    /// Create and store a new pending permission request, optionally evaluating policies.
    ///
    /// Infers the risk level from the tool name using a simple heuristic:
    /// - `bash` / `computer` → `.critical`
    /// - write/edit/create/delete/move/rename → `.high`
    /// - read/glob/grep/search/ls/find → `.low`
    /// - everything else → `.medium`
    ///
    /// When `db` is supplied, the policy engine is evaluated immediately. If a matching
    /// policy is found, the record is auto-resolved (approved or denied) and persisted to
    /// the database with the `matched_policy_id` field set.
    ///
    /// - Parameters:
    ///   - requestId: Unique identifier emitted by Claude (e.g. the tool-use block ID).
    ///   - sessionId: UUID string of the session that triggered the request.
    ///   - toolName: Name of the tool Claude wants to use (e.g. "Bash", "Write").
    ///   - toolInput: Arbitrary tool input parameters as `AnyCodable`.
    ///   - sessionName: Human-readable session name for display, if available.
    ///   - projectName: Project name associated with the session, if available.
    ///   - db: Optional database connection for policy evaluation and auto-resolution persistence.
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
        let record = PermissionRecord(
            id: UUID().uuidString,
            requestId: requestId,
            sessionId: sessionId,
            sessionName: sessionName,
            projectName: projectName,
            toolName: toolName,
            toolInput: toolInput,
            status: .pending,
            riskLevel: Self.inferRiskLevel(from: toolName),
            requestedAt: Date()
        )
        pendingRequests[requestId] = record
        Self.logger.info("Permission pending: \(requestId) tool=\(toolName) session=\(sessionId)")

        // Evaluate configured policies immediately when a database connection is available.
        // If a policy matches, auto-resolve the record without requiring user interaction.
        if let database = db {
            if let (action, matchedPolicy) = try? await PolicyEvaluationService.shared.evaluate(
                request: record,
                db: database
            ), let policy = matchedPolicy {
                let autoStatus: PermissionStatus = action == .allow ? .autoApproved : .denied
                if let resolved = resolve(
                    requestId: requestId,
                    status: autoStatus,
                    reason: nil,
                    matchedPolicyId: policy.id
                ) {
                    // Persist the auto-resolved record to the database for audit trail.
                    let model = PermissionModel.from(resolved)
                    try? await model.save(on: database)
                    Self.logger.info(
                        "Permission auto-resolved by policy '\(policy.name)': \(requestId) status=\(autoStatus.rawValue)"
                    )
                    return resolved
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
    ///   - matchedPolicyId: UUID of the policy that triggered this resolution, if auto-resolved.
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
