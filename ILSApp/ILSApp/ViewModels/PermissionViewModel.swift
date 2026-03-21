import Foundation
import Observation
import ILSShared

// MARK: - PermissionViewModel

/// Manages permission request state and decision forwarding for Claude tool-use permission prompts.
///
/// Extracted from `ChatViewModel` to isolate permission logic and improve testability.
/// `ChatViewModel` holds an instance and delegates all permission-related operations here.
///
/// ## Topics
/// ### State
/// - ``pendingPermissionRequests`` - All queued permission requests awaiting user decision
/// - ``showBatchPermissionModal`` - Whether the batch permission modal is presented
/// - ``projectId`` - Project scope for auto-approve rule lookups
///
/// ### Methods
/// - ``configure(apiClient:sessionId:)`` - Inject dependencies
/// - ``respondToPermission(requestId:decision:)`` - Handle a single permission decision
/// - ``respondToBatchPermissions(requestIds:decision:)`` - Handle batch decisions
@MainActor
@Observable
class PermissionViewModel {

    // MARK: - State

    /// All queued permission requests waiting for a user decision.
    var pendingPermissionRequests: [PermissionRequest] = []
    /// Whether the batch permission modal should be shown.
    var showBatchPermissionModal: Bool = false
    /// Project ID used for scoping auto-approve rule lookups.
    var projectId: UUID?

    /// Pending permission request from Claude (first in queue, for backward compatibility).
    var pendingPermissionRequest: PermissionRequest? {
        get { pendingPermissionRequests.first }
        set {
            if let v = newValue {
                pendingPermissionRequests = [v]
            } else {
                pendingPermissionRequests = []
            }
        }
    }

    // MARK: - Private State

    private var apiClient: APIClient?
    private var sessionId: UUID?

    // MARK: - Init

    init() {}

    // MARK: - Configuration

    /// Inject the API client and current session ID.
    func configure(apiClient: APIClient, sessionId: UUID?) {
        self.apiClient = apiClient
        self.sessionId = sessionId
    }

    /// Update the active session ID when it changes.
    func updateSessionId(_ sessionId: UUID?) {
        self.sessionId = sessionId
    }

    // MARK: - Permission Responses

    /// Respond to a pending permission request (allow/deny).
    ///
    /// Sends the decision to the backend which forwards it to the Claude CLI process via stdin.
    /// Route: POST /chat/permission/{sessionId}/{requestId}
    func respondToPermission(requestId: String, decision: String) {
        let matchingRequest = pendingPermissionRequests.first(where: { $0.requestId == requestId })
        let toolName = matchingRequest?.toolName ?? ""
        let toolInputSummary = matchingRequest.map { Self.formatToolInput($0.toolInput) } ?? ""

        pendingPermissionRequests.removeAll { $0.requestId == requestId }
        if pendingPermissionRequests.isEmpty {
            showBatchPermissionModal = false
        }

        respondToPermissionAndRecord(
            requestId: requestId,
            decision: decision,
            isAutoApproved: false,
            toolName: toolName,
            toolInputSummary: toolInputSummary
        )
    }

    /// Respond to multiple pending permission requests at once.
    ///
    /// Records each decision to history and removes the requests from the queue.
    func respondToBatchPermissions(requestIds: [String], decision: String) {
        for requestId in requestIds {
            let matchingRequest = pendingPermissionRequests.first(where: { $0.requestId == requestId })
            let toolName = matchingRequest?.toolName ?? ""
            let toolInputSummary = matchingRequest.map { Self.formatToolInput($0.toolInput) } ?? ""
            respondToPermissionAndRecord(
                requestId: requestId,
                decision: decision,
                isAutoApproved: false,
                toolName: toolName,
                toolInputSummary: toolInputSummary
            )
        }
        pendingPermissionRequests.removeAll { requestIds.contains($0.requestId) }
        if pendingPermissionRequests.isEmpty {
            showBatchPermissionModal = false
        }
    }

    /// Core permission response logic: sends decision to backend and records to history.
    func respondToPermissionAndRecord(
        requestId: String,
        decision: String,
        isAutoApproved: Bool = false,
        toolName: String = "",
        toolInputSummary: String = ""
    ) {
        guard let apiClient, let sessionId else { return }
        let sessionIdString = sessionId.uuidString
        let entry = PermissionHistoryEntry(
            sessionId: sessionIdString,
            toolName: toolName,
            toolInputSummary: String(toolInputSummary.prefix(200)),
            decision: decision,
            isAutoApproved: isAutoApproved
        )

        Task { [weak self] in
            _ = self  // prevent unused capture warning
            do {
                let body = PermissionDecision(decision: decision)
                let _: APIResponse<AcknowledgedResponse> = try await apiClient.post(
                    "/chat/permission/\(sessionIdString)/\(requestId)",
                    body: body
                )
            } catch {
                AppLogger.shared.warning("Permission response failed (non-fatal): \(error)", category: "chat")
            }
            try? await PermissionHistoryService.shared.record(entry)
        }
    }

    // MARK: - Helpers

    /// Format an AnyCodable tool input into a searchable plain-text string.
    static func formatToolInput(_ toolInput: AnyCodable) -> String {
        if let data = try? JSONEncoder().encode(toolInput),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return ""
    }
}
