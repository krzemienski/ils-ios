#if os(iOS)
import Foundation
import Observation
import ILSShared

// MARK: - VoiceCommandExecutionState

/// Represents the current state of the voice command executor.
enum VoiceCommandExecutionState: Sendable {
    /// No command is being processed.
    case idle
    /// A destructive command is awaiting user confirmation.
    case confirming(VoiceCommand)
    /// A command is actively executing.
    case executing(VoiceCommand)
    /// A command completed successfully with a result message.
    case completed(VoiceCommand, String)
    /// A command failed with an error message.
    case failed(VoiceCommand, String)
}

// MARK: - VoiceCommandExecutionContext

/// Context provided to the executor for command dispatch.
///
/// Contains weak references to view models and app state to avoid retain cycles.
/// The executor uses this context to route commands to the appropriate handlers.
struct VoiceCommandExecutionContext {
    /// The active session ID, if any.
    weak var chatViewModel: ChatViewModel?
    /// Global app state for navigation.
    weak var appState: AppState?
    /// API client for network requests (status summary, etc.).
    var apiClient: APIClient?
    /// The current session ID for session-scoped operations.
    var sessionId: UUID?
}

// MARK: - VoiceCommandExecutor

/// Executes voice commands by dispatching actions to the appropriate app subsystems.
///
/// Manages the full lifecycle of command execution: validation, optional confirmation
/// for destructive actions, dispatch, and result reporting. Provides haptic feedback
/// and logs all executions via `AppLogger`.
///
/// ## Topics
/// ### Execution
/// - ``execute(_:context:)`` - Execute a voice command.
/// - ``confirm()`` - Confirm a pending destructive command.
/// - ``cancel()`` - Cancel a pending confirmation.
///
/// ### State
/// - ``executionState`` - The current execution state.
/// - ``lastResult`` - The result message from the last completed command.
@Observable
@MainActor
final class VoiceCommandExecutor {

    // MARK: - Published State

    /// Current execution state, observed by the UI overlay.
    var executionState: VoiceCommandExecutionState = .idle

    /// Result message from the most recent successful execution.
    var lastResult: String?

    // MARK: - Private State

    /// Stored context for confirming a destructive command after the initial `execute` call.
    private var pendingContext: VoiceCommandExecutionContext?

    /// Execution log for debugging; capped at 50 entries.
    private(set) var executionLog: [(date: Date, command: VoiceCommand, success: Bool)] = []

    /// Maximum entries retained in the execution log.
    private let maxLogEntries = 50

    // MARK: - Execution

    /// Execute a voice command.
    ///
    /// If the command requires confirmation (destructive actions), the executor transitions
    /// to `.confirming` state and waits for ``confirm()`` or ``cancel()``.
    /// Non-destructive commands are dispatched immediately.
    ///
    /// - Parameters:
    ///   - command: The voice command to execute.
    ///   - context: Execution context containing view model and app state references.
    func execute(_ command: VoiceCommand, context: VoiceCommandExecutionContext) async {
        AppLogger.shared.info(
            "Voice command received: \(command.id) (\(command.displayName))",
            category: "voice-commands"
        )

        // Check user preference for always-confirm
        let alwaysConfirm = UserDefaults.standard.bool(forKey: "voiceCommandAlwaysConfirm")

        if command.requiresConfirmation || command.isDestructive || alwaysConfirm {
            executionState = .confirming(command)
            pendingContext = context
            HapticManager.notification(.warning)
            AppLogger.shared.info(
                "Awaiting confirmation for: \(command.id)",
                category: "voice-commands"
            )
            return
        }

        await dispatch(command, context: context)
    }

    /// Confirm and execute the pending destructive command.
    ///
    /// No-op if there is no command in the `.confirming` state.
    func confirm() async {
        guard case .confirming(let command) = executionState,
              let context = pendingContext else {
            return
        }
        pendingContext = nil
        await dispatch(command, context: context)
    }

    /// Cancel the pending confirmation and return to idle.
    func cancel() {
        guard case .confirming = executionState else { return }
        executionState = .idle
        pendingContext = nil
        HapticManager.selection()
        AppLogger.shared.info("Voice command confirmation cancelled", category: "voice-commands")
    }

    /// Reset the executor back to idle state.
    ///
    /// Called after the UI has consumed the `.completed` or `.failed` state.
    func reset() {
        executionState = .idle
    }

    // MARK: - Dispatch

    /// Routes a command to the appropriate handler based on its action type.
    private func dispatch(_ command: VoiceCommand, context: VoiceCommandExecutionContext) async {
        executionState = .executing(command)

        do {
            let result: String
            switch command.action {
            case .approve:
                result = try await handleApprove(context: context)
            case .deny:
                result = try await handleDeny(context: context)
            case .approveAll:
                result = try await handleApproveAll(context: context)
            case .denyAll:
                result = try await handleDenyAll(context: context)
            case .newSession:
                result = handleNewSession()
            case .deleteSession:
                result = try await handleDeleteSession(context: context)
            case .openSession:
                result = handleOpenSession(context: context)
            case .summarizeStatus:
                result = try await handleSummarizeStatus(context: context)
            case .triggerWorkflow:
                result = handleTriggerWorkflow()
            case .navigate(let screen):
                result = handleNavigate(to: screen, context: context)
            case .custom(let action):
                result = handleCustomAction(action, context: context)
            }

            lastResult = result
            executionState = .completed(command, result)
            HapticManager.notification(.success)
            recordLog(command: command, success: true)
            AppLogger.shared.info(
                "Voice command completed: \(command.id) — \(result)",
                category: "voice-commands"
            )

        } catch {
            let message = error.localizedDescription
            executionState = .failed(command, message)
            HapticManager.notification(.error)
            recordLog(command: command, success: false)
            AppLogger.shared.error(
                "Voice command failed: \(command.id) — \(message)",
                category: "voice-commands"
            )
        }
    }

    // MARK: - Action Handlers

    private func handleApprove(context: VoiceCommandExecutionContext) throws -> String {
        guard let chatViewModel = context.chatViewModel else {
            throw VoiceCommandError.noActiveSession
        }
        guard let request = chatViewModel.pendingPermissionRequests.first else {
            throw VoiceCommandError.noPendingPermission
        }
        chatViewModel.respondToPermission(requestId: request.requestId, decision: "allow")
        return "Permission approved"
    }

    private func handleDeny(context: VoiceCommandExecutionContext) throws -> String {
        guard let chatViewModel = context.chatViewModel else {
            throw VoiceCommandError.noActiveSession
        }
        guard let request = chatViewModel.pendingPermissionRequests.first else {
            throw VoiceCommandError.noPendingPermission
        }
        chatViewModel.respondToPermission(requestId: request.requestId, decision: "deny")
        return "Permission denied"
    }

    private func handleApproveAll(context: VoiceCommandExecutionContext) throws -> String {
        guard let chatViewModel = context.chatViewModel else {
            throw VoiceCommandError.noActiveSession
        }
        let requests = chatViewModel.pendingPermissionRequests
        guard !requests.isEmpty else {
            throw VoiceCommandError.noPendingPermission
        }
        let ids = requests.map(\.requestId)
        chatViewModel.respondToBatchPermissions(requestIds: ids, decision: "allow")
        return "All \(ids.count) permissions approved"
    }

    private func handleDenyAll(context: VoiceCommandExecutionContext) throws -> String {
        guard let chatViewModel = context.chatViewModel else {
            throw VoiceCommandError.noActiveSession
        }
        let requests = chatViewModel.pendingPermissionRequests
        guard !requests.isEmpty else {
            throw VoiceCommandError.noPendingPermission
        }
        let ids = requests.map(\.requestId)
        chatViewModel.respondToBatchPermissions(requestIds: ids, decision: "deny")
        return "All \(ids.count) permissions denied"
    }

    private func handleNewSession() -> String {
        NotificationCenter.default.post(name: .ilsCreateNewSession, object: nil)
        return "Creating new session"
    }

    private func handleDeleteSession(context: VoiceCommandExecutionContext) async throws -> String {
        guard context.chatViewModel != nil else {
            throw VoiceCommandError.noActiveSession
        }
        guard let sessionId = context.sessionId else {
            throw VoiceCommandError.noActiveSession
        }
        guard let apiClient = context.apiClient else {
            throw VoiceCommandError.noConnection
        }
        try await apiClient.rawRequest(
            method: "DELETE",
            endpoint: "/sessions/\(sessionId.uuidString)",
            body: nil
        )
        AppLogger.shared.info(
            "Session deleted via voice command: \(sessionId)",
            category: "voice-commands"
        )
        return "Session deleted"
    }

    private func handleOpenSession(context: VoiceCommandExecutionContext) -> String {
        // Open session is context-dependent; fall back to navigating home.
        context.appState?.navigationIntent = .home
        return "Opening sessions"
    }

    private func handleSummarizeStatus(context: VoiceCommandExecutionContext) async throws -> String {
        guard let apiClient = context.apiClient else {
            throw VoiceCommandError.noConnection
        }
        let sessions: [ChatSession] = try await apiClient.get("/sessions")
        let active = sessions.filter { $0.status == .active }
        let total = sessions.count

        if active.isEmpty {
            return "\(total) session\(total == 1 ? "" : "s") total, none active"
        }
        let names = active.prefix(3).map { $0.name ?? "Untitled" }.joined(separator: ", ")
        let suffix = active.count > 3 ? " and \(active.count - 3) more" : ""
        return "\(total) session\(total == 1 ? "" : "s"), \(active.count) active: \(names)\(suffix)"
    }

    private func handleTriggerWorkflow() -> String {
        NotificationCenter.default.post(
            name: NSNotification.Name("ILSTriggerWorkflow"),
            object: nil
        )
        return "Workflow triggered"
    }

    private func handleNavigate(to screen: ActiveScreen, context: VoiceCommandExecutionContext) -> String {
        context.appState?.navigationIntent = screen
        let screenName: String
        switch screen {
        case .home: screenName = "Home"
        case .settings: screenName = "Settings"
        case .system: screenName = "System"
        case .agentQueue: screenName = "Workflows"
        case .browser: screenName = "Browser"
        case .teams: screenName = "Teams"
        default: screenName = "screen"
        }
        return "Navigating to \(screenName)"
    }

    private func handleCustomAction(_ action: String, context: VoiceCommandExecutionContext) -> String {
        NotificationCenter.default.post(
            name: NSNotification.Name("ILSCustomVoiceAction"),
            object: action
        )
        return "Action dispatched: \(action)"
    }

    // MARK: - Logging

    private func recordLog(command: VoiceCommand, success: Bool) {
        executionLog.append((date: Date(), command: command, success: success))
        if executionLog.count > maxLogEntries {
            executionLog.removeFirst(executionLog.count - maxLogEntries)
        }
    }
}

// MARK: - VoiceCommandError

/// Errors specific to voice command execution.
enum VoiceCommandError: LocalizedError {
    /// No active chat session to operate on.
    case noActiveSession
    /// No pending permission request to approve or deny.
    case noPendingPermission
    /// No network connection available for the requested action.
    case noConnection

    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active session. Open a session first."
        case .noPendingPermission:
            return "No pending permission requests."
        case .noConnection:
            return "Not connected to server."
        }
    }
}
#endif
