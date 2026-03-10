import Foundation
import Observation
import ILSShared

/// View model for the AI action audit trail with one-tap rollback.
///
/// Handles loading, filtering, logging, and rolling back `AuditAction` entries
/// from the backend `/audit-actions` REST API.
///
/// ## Topics
/// ### State
/// - ``actions`` - All loaded audit actions (newest first)
/// - ``totalCount`` - Total number of matching actions on the server
/// - ``hasMore`` - Whether additional pages are available
/// - ``isRollingBack`` - Whether a rollback operation is in progress
/// - ``rollbackError`` - Error from the most recent rollback, if any
/// - ``searchText`` - Local search filter applied to displayed actions
/// - ``selectedActionType`` - Optional type filter applied server-side on load
/// - ``selectedSessionId`` - Optional session filter applied server-side on load
/// - ``showRollbackConfirmation`` - Controls the rollback confirmation alert
/// - ``pendingRollbackAction`` - The action staged for rollback
///
/// ### Operations
/// - ``loadActions(sessionId:)`` - Fetch the first page of audit actions
/// - ``loadMoreActions()`` - Fetch the next page of audit actions
/// - ``logAction(request:)`` - Create a new audit action entry on the server
/// - ``rollbackAction(actionId:)`` - Execute a rollback for the given action ID
/// - ``requestRollback(action:)`` - Stage an action for rollback (shows confirmation)
/// - ``cancelRollback()`` - Cancel a pending rollback
/// - ``executeRollback()`` - Confirm and execute the staged rollback
@Observable
@MainActor
class AuditTrailViewModel: BaseViewModel {

    // MARK: - Constants

    private static let pageSize = 50

    // MARK: - State

    /// All loaded audit actions, sorted newest first.
    var actions: [AuditAction] = []

    /// Total number of matching actions available on the server.
    var totalCount: Int = 0

    /// Whether additional pages of results are available.
    var hasMore: Bool = false

    /// Whether a rollback operation is currently in progress.
    var isRollingBack: Bool = false

    /// Error from the most recent rollback attempt, if any.
    var rollbackError: Error?

    /// Local search text applied to ``filteredActions``.
    var searchText: String = ""

    /// Optional action type filter; `nil` means all types.
    var selectedActionType: AuditActionType? = nil

    /// Optional session ID filter applied on load.
    var selectedSessionId: String? = nil

    /// Controls visibility of the rollback confirmation alert.
    var showRollbackConfirmation: Bool = false

    /// The audit action staged for rollback, pending user confirmation.
    var pendingRollbackAction: AuditAction? = nil

    // MARK: - Computed

    /// Actions filtered by the local ``searchText``.
    ///
    /// When ``searchText`` is empty, returns all ``actions``.
    /// Matches are case-insensitive against description, file path, command, and tool name.
    var filteredActions: [AuditAction] {
        guard !searchText.isEmpty else { return actions }
        let query = searchText.lowercased()
        return actions.filter { action in
            action.description.lowercased().contains(query)
                || (action.filePath?.lowercased().contains(query) ?? false)
                || (action.command?.lowercased().contains(query) ?? false)
                || (action.toolName?.lowercased().contains(query) ?? false)
        }
    }

    // MARK: - Init

    override init() {
        super.init()
    }

    // MARK: - API Operations

    /// Load the first page of audit actions, replacing any existing data.
    ///
    /// Applies ``selectedActionType`` and the provided `sessionId` (or
    /// ``selectedSessionId``) as server-side filters.
    ///
    /// - Parameter sessionId: Session to filter by; overrides ``selectedSessionId`` when provided.
    func loadActions(sessionId: String? = nil) async {
        guard let client else { return }
        isLoading = true
        error = nil

        let effectiveSessionId = sessionId ?? selectedSessionId
        if let sessionId { selectedSessionId = sessionId }

        let path = buildQueryPath(offset: 0, sessionId: effectiveSessionId)

        do {
            let response: APIResponse<AuditActionListResponse> = try await client.get(path)
            if let data = response.data {
                actions = data.actions
                totalCount = data.totalCount
                hasMore = data.hasMore
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to load audit actions: \(error.localizedDescription)",
                category: "audit"
            )
        }

        isLoading = false
    }

    /// Append the next page of audit actions to the existing ``actions`` list.
    ///
    /// Does nothing if ``hasMore`` is `false` or a load is already in progress.
    func loadMoreActions() async {
        guard let client, hasMore, !isLoading else { return }
        isLoading = true

        let path = buildQueryPath(offset: actions.count, sessionId: selectedSessionId)

        do {
            let response: APIResponse<AuditActionListResponse> = try await client.get(path)
            if let data = response.data {
                actions.append(contentsOf: data.actions)
                totalCount = data.totalCount
                hasMore = data.hasMore
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to load more audit actions: \(error.localizedDescription)",
                category: "audit"
            )
        }

        isLoading = false
    }

    /// Create a new audit action entry on the server.
    ///
    /// On success, inserts the new action at the front of ``actions``.
    ///
    /// - Parameter request: The action details to log.
    /// - Returns: The created `AuditAction`, or `nil` on failure.
    @discardableResult
    func logAction(request: LogAuditActionRequest) async -> AuditAction? {
        guard let client else { return nil }

        do {
            let response: APIResponse<AuditAction> = try await client.post(
                "/audit-actions",
                body: request
            )
            if let action = response.data {
                actions.insert(action, at: 0)
                totalCount += 1
                return action
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to log audit action: \(error.localizedDescription)",
                category: "audit"
            )
        }
        return nil
    }

    /// Execute a rollback for the given audit action ID.
    ///
    /// On success, updates the affected action in ``actions`` to reflect its
    /// new `rolled_back` status, and prepends any rollback audit entry returned
    /// by the server.
    ///
    /// - Parameter actionId: The ID of the action to roll back.
    /// - Returns: `true` if the rollback succeeded, `false` otherwise.
    @discardableResult
    func rollbackAction(actionId: UUID) async -> Bool {
        guard let client else { return false }
        isRollingBack = true
        rollbackError = nil

        do {
            let path = "/audit-actions/\(actionId.uuidString.lowercased())/rollback"
            let response: APIResponse<RollbackResultItem> = try await client.post(
                path,
                body: EmptyBody()
            )
            isRollingBack = false

            guard let result = response.data, result.succeeded else {
                let msg = response.data?.errorMessage ?? "Rollback failed"
                rollbackError = RollbackError.failed(msg)
                AppLogger.shared.error(
                    "Rollback failed: \(msg)",
                    category: "audit"
                )
                return false
            }

            // Update the original action's rollback status in the local list
            if let idx = actions.firstIndex(where: { $0.id == actionId }) {
                var updated = actions[idx]
                updated.rollbackStatus = .rolledBack
                updated.rolledBackAt = Date()
                updated.rollbackAuditId = result.rollbackAuditAction?.id
                actions[idx] = updated
            }

            // Prepend the rollback audit entry if returned
            if let rollbackEntry = result.rollbackAuditAction {
                actions.insert(rollbackEntry, at: 0)
                totalCount += 1
            }

            return true
        } catch {
            rollbackError = error
            AppLogger.shared.error(
                "Failed to rollback action \(actionId): \(error.localizedDescription)",
                category: "audit"
            )
        }

        isRollingBack = false
        return false
    }

    // MARK: - Confirmation Helpers

    /// Stage an action for rollback, triggering the confirmation alert.
    /// - Parameter action: The action the user wants to roll back.
    func requestRollback(action: AuditAction) {
        pendingRollbackAction = action
        showRollbackConfirmation = true
    }

    /// Cancel a pending rollback, dismissing the confirmation alert.
    func cancelRollback() {
        pendingRollbackAction = nil
        showRollbackConfirmation = false
    }

    /// Confirm and execute the staged rollback for ``pendingRollbackAction``.
    ///
    /// Dismisses the confirmation alert and invokes ``rollbackAction(actionId:)``.
    func executeRollback() async {
        guard let action = pendingRollbackAction else { return }
        showRollbackConfirmation = false
        pendingRollbackAction = nil
        await rollbackAction(actionId: action.id)
    }

    // MARK: - Private Helpers

    private func buildQueryPath(offset: Int, sessionId: String?) -> String {
        var components = URLComponents()
        var items: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(Self.pageSize)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        if let sessionId {
            items.append(URLQueryItem(name: "sessionId", value: sessionId))
        }
        if let type = selectedActionType {
            items.append(URLQueryItem(name: "actionType", value: type.rawValue))
        }
        components.queryItems = items
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return "/audit-actions\(query)"
    }
}

// MARK: - Supporting Types

private enum RollbackError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let msg): return msg
        }
    }
}
