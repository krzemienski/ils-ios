import Foundation
import UserNotifications
import ILSShared

// MARK: - UserDefaults Keys

private enum PermissionServiceKeys {
    static let autoApproveRules = "autoApproveRules"
    static let notifPermissionAlerts = "notif_permissionAlerts"
    static let permissionCategory = "PERMISSION_REQUEST"
    static let allowAction = "ALLOW_PERMISSION"
    static let denyAction = "DENY_PERMISSION"
}

// MARK: - PermissionService

/// Polls the backend for pending Claude Code tool-use permission requests,
/// fires local notifications on new arrivals, and auto-approves matching rules.
///
/// ## Polling Lifecycle
/// Call ``startPolling(apiClient:)`` when the app becomes active and is connected.
/// Call ``stopPolling()`` when backgrounding or disconnecting.
/// The service detects new arrivals by tracking ``knownRequestIds`` so that
/// only genuinely new requests trigger notifications.
///
/// ## Auto-Approve Rules
/// Rules are persisted in `UserDefaults` as JSON and evaluated on each poll cycle.
/// A rule matches when ``AutoApproveRule/toolPattern`` is contained in the
/// tool name (case-insensitive) and the request's risk level does not exceed
/// the rule's ``AutoApproveRule/maxRiskLevel``.
@MainActor
@Observable
final class PermissionService {

    // MARK: - Published State

    /// Currently pending permission requests awaiting a decision.
    var pendingPermissions: [PermissionRecord] = []

    /// Resolved permission records (approved, denied, auto-approved, expired).
    var permissionHistory: [PermissionRecord] = []

    /// Auto-approve rules loaded from `UserDefaults`.
    var autoApproveRules: [AutoApproveRule] = []

    /// Whether the polling loop is currently running.
    var isPolling: Bool = false

    // MARK: - Private State

    private var pollingTask: Task<Void, Never>?

    /// Tracks request IDs seen in previous poll cycles to detect new arrivals.
    private var knownRequestIds: Set<String> = []

    // MARK: - Init

    init() {
        loadAutoApproveRules()
    }

    // MARK: - Polling

    /// Starts polling `/permissions/pending` every 2 seconds.
    ///
    /// - Parameter apiClient: The API client used to fetch permission data.
    ///
    /// **Energy policy (ENRG-PERM):** Interval doubles in Low Power Mode.
    func startPolling(apiClient: APIClient) {
        guard pollingTask == nil else { return }
        isPolling = true
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                await self.fetchPending(apiClient: apiClient)
                let interval: UInt64 = LowPowerModeMonitor.shared.isLowPowerModeEnabled
                    ? 10_000_000_000  // 10s in LPM (ENERGY-001)
                    : 5_000_000_000   // 5s normal (ENERGY-001)
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    /// Cancels the polling loop.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }

    // MARK: - Fetch Pending

    private func fetchPending(apiClient: APIClient) async {
        do {
            let response: APIResponse<PermissionListResponse> = try await apiClient.get("/permissions/pending")
            guard let listResponse = response.data else { return }

            let fetched = listResponse.items
            let fetchedIds = Set(fetched.map(\.requestId))

            // Detect genuinely new arrivals (not seen in prior poll cycles).
            let newIds = fetchedIds.subtracting(knownRequestIds)
            let newRecords = fetched.filter { newIds.contains($0.requestId) }

            // Update state on main actor (already @MainActor).
            pendingPermissions = fetched
            knownRequestIds = fetchedIds

            // Fire notifications and check auto-approve for new arrivals.
            for record in newRecords {
                // Log policy-driven context to local history if the backend provided it.
                await logPolicyDecisionIfNeeded(record: record)

                await checkAutoApprove(record: record, apiClient: apiClient)
                fireNotification(for: record)
            }
        } catch {
            // Network errors are expected when disconnected; suppress silently.
        }
    }

    // MARK: - Decisions

    /// Submits an allow or deny decision for a single permission request.
    ///
    /// On success the record is removed from ``pendingPermissions``
    /// and added to ``permissionHistory``.
    ///
    /// - Parameters:
    ///   - requestId: The request identifier to resolve.
    ///   - decision: Either `"allow"` or `"deny"`.
    ///   - reason: Optional reason shown in the audit trail.
    ///   - apiClient: The API client used to POST the decision.
    func submitDecision(
        requestId: String,
        decision: String,
        reason: String? = nil,
        apiClient: APIClient
    ) async throws {
        // Auto-checkpoint before high-risk approvals for reversibility.
        if decision == "allow",
           let record = pendingPermissions.first(where: { $0.requestId == requestId }),
           record.riskLevel == .high || record.riskLevel == .critical,
           let sessionUUID = UUID(uuidString: record.sessionId) {
            await createPreApprovalCheckpoint(
                sessionId: sessionUUID,
                toolName: record.toolName,
                apiClient: apiClient
            )
        }

        let body = PermissionDecision(decision: decision, reason: reason)
        let _: APIResponse<AcknowledgedResponse> = try await apiClient.post(
            "/permissions/\(requestId)/decide",
            body: body
        )
        // Remove from pending; the next poll cycle will update history.
        pendingPermissions.removeAll { $0.requestId == requestId }
        knownRequestIds.remove(requestId)
    }

    /// Batch-approves or batch-denies multiple permission requests.
    ///
    /// Individual failures are silently ignored so the batch continues.
    ///
    /// - Parameters:
    ///   - requestIds: The request identifiers to resolve.
    ///   - decision: Either `"allow"` or `"deny"`.
    ///   - reason: Optional reason shown in the audit trail.
    ///   - apiClient: The API client used to POST each decision.
    func batchDecide(
        requestIds: [String],
        decision: String,
        reason: String? = nil,
        apiClient: APIClient
    ) async {
        for requestId in requestIds {
            try? await submitDecision(
                requestId: requestId,
                decision: decision,
                reason: reason,
                apiClient: apiClient
            )
        }
    }

    // MARK: - History

    /// Fetches resolved permission records from the backend history endpoint.
    ///
    /// - Parameter apiClient: The API client used to GET the history.
    func loadHistory(apiClient: APIClient) async {
        do {
            let response: APIResponse<PermissionListResponse> = try await apiClient.get(
                "/permissions/history?limit=50"
            )
            if let items = response.data?.items {
                permissionHistory = items
            }
        } catch {
            // Network errors are expected when disconnected; suppress silently.
        }
    }

    // MARK: - Auto-Approve Rules

    /// Checks all enabled auto-approve rules against `record`.
    ///
    /// Evaluation order:
    /// 1. If the backend already resolved this request (server-side auto-resolve, status ≠ pending),
    ///    client-side rule evaluation is skipped entirely.
    /// 2. Client-side rules are evaluated in priority order (lower number = higher priority).
    ///    The first matching rule determines the outcome — `allow` or `deny`.
    ///
    /// - Parameters:
    ///   - record: The incoming permission request to evaluate.
    ///   - apiClient: Used to submit the auto-approve or auto-deny decision.
    func checkAutoApprove(record: PermissionRecord, apiClient: APIClient) async {
        // If the backend already resolved this request (server-side auto-resolve), skip client evaluation.
        guard record.status == .pending else { return }

        // Evaluate rules in priority order (lower number = higher priority).
        let sortedRules = autoApproveRules.filter(\.isEnabled).sorted { $0.priority < $1.priority }

        for rule in sortedRules {
            let toolInput = (record.toolInput.value as? String) ?? ""
            if rule.matches(toolName: record.toolName, toolInput: toolInput) {
                let decision = rule.action == .deny ? "deny" : "allow"
                let actionLabel = rule.action == .deny ? "Auto-denied" : "Auto-approved"
                try? await submitDecision(
                    requestId: record.requestId,
                    decision: decision,
                    reason: "\(actionLabel) by rule: \(rule.toolName ?? "*")",
                    apiClient: apiClient
                )
                return
            }
        }
    }

    /// Loads auto-approve rules from `UserDefaults`.
    ///
    /// Decodes JSON-serialized rule list. On decode failure, defaults to empty array
    /// so app continues without auto-approve functionality (graceful degradation).
    private func loadAutoApproveRules() {
        guard let data = UserDefaults.standard.data(forKey: PermissionServiceKeys.autoApproveRules) else {
            autoApproveRules = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            autoApproveRules = try decoder.decode([AutoApproveRule].self, from: data)
        } catch {
            AppLogger.shared.error("Failed to decode auto-approve rules: \(error.localizedDescription)", category: "permissions")
            autoApproveRules = []
        }
    }

    /// Persists current auto-approve rules to `UserDefaults`.
    ///
    /// Encodes rules as JSON and stores under `autoApproveRules` key.
    /// On encode failure, logs the error (rules remain in memory until app restart).
    private func saveAutoApproveRules() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(autoApproveRules)
            UserDefaults.standard.set(data, forKey: PermissionServiceKeys.autoApproveRules)
        } catch {
            AppLogger.shared.error("Failed to encode auto-approve rules: \(error.localizedDescription)", category: "permissions")
        }
    }

    /// Adds a new auto-approve rule and persists the updated list.
    ///
    /// - Parameter rule: The rule to add.
    func addAutoApproveRule(_ rule: AutoApproveRule) {
        autoApproveRules.append(rule)
        saveAutoApproveRules()
    }

    /// Removes an auto-approve rule by its identifier and persists the updated list.
    ///
    /// - Parameter id: The string identifier of the rule to remove.
    func removeAutoApproveRule(id: UUID) {
        autoApproveRules.removeAll { $0.id == id }
        saveAutoApproveRules()
    }

    // MARK: - Notifications

    /// Registers the `PERMISSION_REQUEST` notification category with
    /// `ALLOW_PERMISSION` and `DENY_PERMISSION` action identifiers.
    ///
    /// Call once at app launch (e.g., from `ILSAppApp.init()`).
    static func registerNotificationCategory() {
        let allowAction = UNNotificationAction(
            identifier: PermissionServiceKeys.allowAction,
            title: "Allow",
            options: [.foreground]
        )
        let denyAction = UNNotificationAction(
            identifier: PermissionServiceKeys.denyAction,
            title: "Deny",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: PermissionServiceKeys.permissionCategory,
            actions: [allowAction, denyAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Private Helpers

    /// Fires a local notification for a new permission request, if enabled.
    private func fireNotification(for record: PermissionRecord) {
        guard UserDefaults.standard.bool(forKey: PermissionServiceKeys.notifPermissionAlerts) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Claude Permission Request"
        let sessionSuffix = record.sessionName.map { " in \($0)" } ?? ""
        content.body = "Claude wants to use \(record.toolName)\(sessionSuffix)"
        content.categoryIdentifier = PermissionServiceKeys.permissionCategory
        content.sound = .default
        content.userInfo = [
            "requestId": record.requestId,
            "sessionId": record.sessionId,
            "toolName": record.toolName
        ]

        let request = UNNotificationRequest(
            identifier: record.requestId,
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Returns whether `toolName` matches `pattern` (case-insensitive).
    ///
    /// Matching strategy:
    /// - If `pattern` ends with `*`, performs a prefix match (strip the `*`).
    /// - Otherwise, checks whether `toolName` contains `pattern`.
    private func matches(toolName: String, pattern: String) -> Bool {
        let lowerTool = toolName.lowercased()
        if pattern.hasSuffix("*") {
            let prefix = pattern.dropLast().lowercased()
            return lowerTool.hasPrefix(prefix)
        }
        return lowerTool.contains(pattern.lowercased())
    }

    /// Creates an auto-checkpoint before a high-risk permission approval.
    ///
    /// Checkpoint failures are logged but do not block the approval — the decision
    /// flow is more important than the safety-net checkpoint.
    ///
    /// - Parameters:
    ///   - sessionId: The session to checkpoint.
    ///   - toolName: The tool being approved (used in the checkpoint label).
    ///   - apiClient: The API client used to POST the checkpoint.
    private func createPreApprovalCheckpoint(
        sessionId: UUID,
        toolName: String,
        apiClient: APIClient
    ) async {
        let request = CreateCheckpointRequest(
            label: "Pre-approval: \(toolName)",
            isAuto: true,
            maxRetained: nil
        )
        do {
            let _: APIResponse<Checkpoint> = try await apiClient.post(
                "/sessions/\(sessionId.uuidString.lowercased())/checkpoints",
                body: request
            )
            AppLogger.shared.info(
                "Created pre-approval checkpoint for \(toolName) in session \(sessionId)",
                category: "permissions"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to create pre-approval checkpoint: \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    // MARK: - Policy Context

    /// Returns the ``PermissionReasonCode``-based policy badge label for a record,
    /// or `nil` if no policy context was provided by the backend.
    ///
    /// Use this to render a badge in the permission inbox (e.g., "Auto-Approved" or "High Risk Blocked").
    func policyBadgeLabel(for record: PermissionRecord) -> String? {
        guard record.policyAction != nil || record.reasonCode != nil else { return nil }
        let code = PermissionReasonCode(rawString: record.reasonCode)
        return code.displayLabel
    }

    /// Returns the SF Symbol icon name for the policy badge, if applicable.
    func policyBadgeIcon(for record: PermissionRecord) -> String? {
        guard record.policyAction != nil || record.reasonCode != nil else { return nil }
        let code = PermissionReasonCode(rawString: record.reasonCode)
        return code.iconName
    }

    /// Returns a pre-populated deny reason when the backend policy suggests
    /// ``requireConfirmation``, helping the user understand *why* the policy
    /// flagged this request.
    ///
    /// Returns `nil` if no policy suggestion applies.
    func suggestedDenyReason(for record: PermissionRecord) -> String? {
        guard record.policyAction == PolicyAction.requireConfirmation.rawValue else { return nil }

        let code = PermissionReasonCode(rawString: record.reasonCode)
        switch code {
        case .highRiskBlocked:
            return "Policy requires confirmation: high-risk operation"
        case .policyViolation:
            return "Policy requires confirmation: policy rule violation"
        case .patternDenied:
            return "Policy requires confirmation: tool pattern restricted"
        default:
            return "Policy requires confirmation for this action"
        }
    }

    /// Logs a policy-driven decision to the local ``PermissionHistoryService``
    /// when the backend has attached policy context (``policyAction`` / ``reasonCode``).
    ///
    /// Only records entries that have meaningful policy metadata — records
    /// without ``policyAction`` are silently skipped.
    private func logPolicyDecisionIfNeeded(record: PermissionRecord) async {
        guard let policyAction = record.policyAction else { return }

        let decision: String
        let isAutoApproved: Bool
        switch policyAction {
        case PolicyAction.autoApprove.rawValue:
            decision = "allow"
            isAutoApproved = true
        case PolicyAction.autoDeny.rawValue:
            decision = "deny"
            isAutoApproved = false
        case PolicyAction.requireConfirmation.rawValue,
             PolicyAction.alwaysAsk.rawValue:
            // These are pending user action — don't log a final decision yet.
            return
        default:
            return
        }

        let toolInput = (record.toolInput.value as? String) ?? ""
        let entry = PermissionHistoryEntry(
            sessionId: record.sessionId,
            toolName: record.toolName,
            toolInputSummary: toolInput,
            decision: decision,
            isAutoApproved: isAutoApproved,
            reasonCode: record.reasonCode
        )

        do {
            try await PermissionHistoryService.shared.record(entry)
        } catch {
            AppLogger.shared.error(
                "Failed to log policy decision for \(record.requestId): \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    /// Risk levels ordered from lowest to highest risk.
    private static let riskOrder: [PermissionRiskLevel] = [.low, .medium, .high, .critical]

    /// Returns `true` when `level` is at or below `limit` in risk ordering.
    private func riskLevel(_ level: PermissionRiskLevel, isAtOrBelow limit: PermissionRiskLevel) -> Bool {
        let order = PermissionService.riskOrder
        guard let levelIdx = order.firstIndex(of: level),
              let limitIdx = order.firstIndex(of: limit) else {
            return false
        }
        return levelIdx <= limitIdx
    }
}
