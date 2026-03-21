import SwiftUI
import ILSShared

// MARK: - ChatSheetDestination

/// Enum-based routing for all sheet and alert presentations in ``ChatView``.
///
/// Replaces the scattered `SheetState` boolean flags with a single optional destination value,
/// ensuring only one sheet or alert is active at a time and eliminating presentation conflicts.
///
/// ## Topics
/// ### Sheet Cases
/// - ``commandPalette`` - Command palette for inserting slash commands
/// - ``sessionInfo`` - Session metadata and configuration
/// - ``exportSheet`` - Export the conversation to Markdown or other formats
/// - ``advancedOptions`` - Advanced chat options (model, temperature, etc.)
/// - ``quickReplyTemplates`` - Browse and apply quick reply templates
/// - ``contextWindowDetail`` - Detailed context window token breakdown
/// - ``permissionRequest(_:)`` - Single tool-use permission request from Claude
/// - ``batchPermission`` - Batch review of multiple pending permission requests
/// - ``sessionMemory`` - In-session memory notes
/// - ``postCompactionRecovery`` - Recovery sheet after a context compaction event
/// - ``attachmentPicker`` - File and image attachment picker
///
/// ### Alert Cases
/// - ``errorAlert`` - Connection or streaming error
/// - ``forkAlert`` - Notification that a session was successfully forked
/// - ``deleteMessageConfirmation`` - Confirm deletion of a single message
/// - ``renameSession`` - Prompt to rename the current session
/// - ``deleteSession`` - Confirm deletion of the current session
///
/// ## See Also
/// ``ChatSheetCoordinator``
// SUIN-006 + UXF-001: Single sheet destination enum preventing simultaneous sheet conflicts.
enum ChatSheetDestination: Identifiable {
    // MARK: Sheets
    case commandPalette
    case sessionInfo
    case exportSheet
    case advancedOptions
    case quickReplyTemplates
    case contextWindowDetail
    case permissionRequest(PermissionRequest)
    case batchPermission
    case sessionMemory
    case postCompactionRecovery
    case attachmentPicker

    // MARK: Alerts
    case errorAlert
    case forkAlert
    case deleteMessageConfirmation
    case renameSession
    case deleteSession

    // MARK: Identifiable

    var id: String {
        switch self {
        case .commandPalette:           return "commandPalette"
        case .sessionInfo:              return "sessionInfo"
        case .exportSheet:              return "exportSheet"
        case .advancedOptions:          return "advancedOptions"
        case .quickReplyTemplates:      return "quickReplyTemplates"
        case .contextWindowDetail:      return "contextWindowDetail"
        case .permissionRequest(let r): return "permissionRequest-\(r.requestId)"
        case .batchPermission:          return "batchPermission"
        case .sessionMemory:            return "sessionMemory"
        case .postCompactionRecovery:   return "postCompactionRecovery"
        case .attachmentPicker:         return "attachmentPicker"
        case .errorAlert:               return "errorAlert"
        case .forkAlert:                return "forkAlert"
        case .deleteMessageConfirmation: return "deleteMessageConfirmation"
        case .renameSession:            return "renameSession"
        case .deleteSession:            return "deleteSession"
        }
    }

    /// Returns `true` if this destination should be presented as a sheet (not an alert).
    var isSheet: Bool {
        switch self {
        case .commandPalette, .sessionInfo, .exportSheet, .advancedOptions,
             .quickReplyTemplates, .contextWindowDetail, .permissionRequest,
             .batchPermission, .sessionMemory, .postCompactionRecovery, .attachmentPicker:
            return true
        case .errorAlert, .forkAlert, .deleteMessageConfirmation,
             .renameSession, .deleteSession:
            return false
        }
    }
}

// MARK: - ChatSheetContext

/// All data and callbacks required by ``ChatSheetCoordinator`` to render each sheet destination.
///
/// Passed by the parent view (``ChatView``) as a single struct so the coordinator's
/// initializer stays manageable as more sheets are added.
struct ChatSheetContext {
    let session: ChatSession

    // MARK: Sheet data / bindings

    /// Binding to the chat options configuration used by the advanced options sheet.
    var chatOptionsConfig: Binding<ChatOptionsConfig>
    /// Called with the selected command string when the user picks from the command palette.
    var onCommandSelected: (String) -> Void
    /// Called with the applied template when the user picks from the quick reply templates sheet.
    var onTemplateApplied: (QuickReplyTemplate) -> Void
    /// Called with newly added attachments from the attachment picker sheet.
    var onAttachmentsAdded: ([MessageAttachment]) -> Void

    // MARK: ContextWindowDetail

    var contextTokensUsed: Int?
    var contextWindowSize: Int?
    var contextInputTokens: Int?
    var contextOutputTokens: Int?
    var contextCacheReadTokens: Int?
    var contextCacheCreateTokens: Int?
    /// Called when the user taps "Fork Session" inside the context window detail sheet.
    var onForkFromContextDetail: () -> Void

    // MARK: PermissionRequest

    /// Called when the user approves or denies a single permission request.
    /// Receives the request ID and decision string (`"allow"` or `"deny"`).
    var onPermissionDecision: (String, String) -> Void

    // MARK: BatchPermission

    /// All pending permission requests for batch review.
    var pendingPermissionRequests: [PermissionRequest]
    /// Binding controlling whether the batch permission modal is presented.
    var showBatchPermissionModal: Binding<Bool>
    /// Called with the selected request IDs and decision string when the batch modal resolves.
    var onBatchPermissionDecision: ([String], String) -> Void

    // MARK: PostCompactionRecovery

    var compactionTokensBefore: Int
    var compactionTokensAfter: Int
    var compactionSnapshot: ContextSnapshot?
    /// Called when the user taps "Paste as Message" with the snapshot text.
    var onPasteSnapshot: (String) -> Void
    /// Called when the user dismisses the post-compaction recovery sheet.
    var onDismissCompaction: () -> Void

    // MARK: Alert data

    /// The error message to display in the connection error alert.
    var errorMessage: String
    /// Called when the user taps "Retry" on the connection error alert.
    var onRetryLastMessage: () -> Void
    /// The session that was forked, shown in the fork-alert message body.
    var forkedSession: ChatSession?
    /// Called when the user taps "Open Fork" on the fork alert.
    var onOpenFork: () -> Void
    /// Called when the user confirms deletion of the message in the delete-message alert.
    var onConfirmDeleteMessage: () -> Void
    /// Binding to the rename text field value.
    var renameText: Binding<String>
    /// Called when the user taps "Rename" on the rename-session alert.
    var onConfirmRename: () -> Void
    /// Called when the user confirms deletion of the session. Return `true` to dismiss the view.
    var onConfirmDeleteSession: () async -> Bool
}

// MARK: - ChatSheetCoordinator

/// ViewModifier that attaches all sheet and alert presentations to a content view,
/// driven by a single ``ChatSheetDestination`` binding.
///
/// Apply this modifier to the root content of ``ChatView`` to separate the sheet/alert
/// wiring from the layout and business logic, following the SUIN-006 / UXF-001 refactor.
///
/// ```swift
/// contentView
///     .modifier(ChatSheetCoordinator(
///         destination: $sheetDestination,
///         context: sheetContext
///     ))
/// ```
///
/// ## See Also
/// ``ChatSheetDestination``, ``ChatSheetContext``
struct ChatSheetCoordinator: ViewModifier {
    /// The currently active sheet or alert destination. Set to `nil` to dismiss.
    @Binding var destination: ChatSheetDestination?
    /// Data and callbacks needed to render each destination.
    var context: ChatSheetContext

    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .sheet(item: sheetOnlyDestination, onDismiss: { destination = nil }) { dest in
                sheetView(for: dest)
            }
            .alert("Connection Error", isPresented: alertBinding(for: .errorAlert)) {
                Button("OK", role: .cancel) {}
                Button("Retry") { context.onRetryLastMessage() }
            } message: {
                Text(context.errorMessage.isEmpty
                     ? "An error occurred while connecting to Claude."
                     : context.errorMessage)
            }
            .alert("Session Forked", isPresented: alertBinding(for: .forkAlert)) {
                Button("Open Fork") { context.onOpenFork() }
                Button("Stay Here", role: .cancel) {}
            } message: {
                if let forked = context.forkedSession {
                    Text("Created new session: \(forked.name ?? "Unnamed")")
                }
            }
            .alert("Delete Message", isPresented: alertBinding(for: .deleteMessageConfirmation)) {
                Button("Delete", role: .destructive) { context.onConfirmDeleteMessage() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this message?")
            }
            .alert("Rename Session", isPresented: alertBinding(for: .renameSession)) {
                TextField("Session name", text: context.renameText)
                Button("Rename") { context.onConfirmRename() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a new name for this session")
            }
            .alert("Delete Session", isPresented: alertBinding(for: .deleteSession)) {
                Button("Delete", role: .destructive) {
                    Task {
                        if await context.onConfirmDeleteSession() {
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this session and all its messages.")
            }
    }

    // MARK: - Sheet Routing

    /// Filters the destination binding to only expose sheet-type cases, returning `nil` for alerts.
    /// This lets us use a single `sheet(item:)` modifier without it intercepting alert cases.
    private var sheetOnlyDestination: Binding<ChatSheetDestination?> {
        Binding(
            get: {
                guard let dest = destination, dest.isSheet else { return nil }
                return dest
            },
            set: { destination = $0 }
        )
    }

    /// Builds the sheet content for a given destination.
    ///
    /// Only called for cases where `destination.isSheet == true`.
    @ViewBuilder
    private func sheetView(for destination: ChatSheetDestination) -> some View {
        switch destination {
        case .commandPalette:
            CommandPaletteView { command in
                context.onCommandSelected(command)
                self.destination = nil
            }
            .presentationBackground(theme.bgPrimary)

        case .sessionInfo:
            SessionInfoView(session: context.session)
                .environment(appState)
                .presentationBackground(theme.bgPrimary)

        case .exportSheet:
            SessionExportPickerSheet(session: context.session)
                .environment(appState)

        case .advancedOptions:
            AdvancedOptionsSheet(config: context.chatOptionsConfig)
                .presentationDetents([.large])
                .presentationBackground(theme.bgPrimary)

        case .quickReplyTemplates:
            NavigationStack {
                QuickReplyTemplatesSheet { template in
                    context.onTemplateApplied(template)
                }
            }
            .presentationBackground(theme.bgPrimary)

        case .contextWindowDetail:
            if let usedTokens = context.contextTokensUsed,
               let windowSize = context.contextWindowSize {
                ContextWindowDetailSheet(
                    usedTokens: usedTokens,
                    contextWindowSize: windowSize,
                    inputTokens: context.contextInputTokens ?? 0,
                    outputTokens: context.contextOutputTokens ?? 0,
                    cacheReadTokens: context.contextCacheReadTokens ?? 0,
                    cacheCreateTokens: context.contextCacheCreateTokens ?? 0,
                    onForkSession: {
                        self.destination = nil
                        context.onForkFromContextDetail()
                    },
                    onDismiss: { self.destination = nil }
                )
            }

        case .permissionRequest(let request):
            PermissionRequestModal(request: request) { decision in
                context.onPermissionDecision(request.requestId, decision)
            }
            .presentationDetents([.medium])
            .presentationBackground(theme.bgPrimary)

        case .batchPermission:
            BatchPermissionRequestModal(requests: context.pendingPermissionRequests) { requestIds, decision in
                context.onBatchPermissionDecision(requestIds, decision)
            }
            .presentationDetents(context.pendingPermissionRequests.count > 3 ? [.large] : [.medium, .large])
            .presentationBackground(theme.bgPrimary)

        case .sessionMemory:
            SessionMemoryView(sessionId: context.session.id)

        case .postCompactionRecovery:
            PostCompactionRecoverySheet(
                tokensBeforeCompaction: context.compactionTokensBefore,
                tokensAfterCompaction: context.compactionTokensAfter,
                snapshot: context.compactionSnapshot,
                onPasteAsMessage: context.onPasteSnapshot,
                onDismiss: context.onDismissCompaction
            )

        case .attachmentPicker:
            AttachmentPickerSheet(
                onAttach: { attachments in
                    context.onAttachmentsAdded(attachments)
                },
                onDismiss: { self.destination = nil }
            )
            .presentationBackground(theme.bgPrimary)

        default:
            EmptyView()
        }
    }

    // MARK: - Alert Binding Helpers

    /// Creates a `Bool` binding that is `true` when the destination matches `alertCase`.
    ///
    /// Setting the binding to `false` dismisses the alert by clearing `destination`.
    private func alertBinding(for alertCase: ChatSheetDestination) -> Binding<Bool> {
        Binding(
            get: { destination?.id == alertCase.id },
            set: { isPresented in if !isPresented { destination = nil } }
        )
    }
}

// MARK: - View Extension

extension View {
    /// Attaches the ``ChatSheetCoordinator`` to this view.
    func chatSheets(
        destination: Binding<ChatSheetDestination?>,
        context: ChatSheetContext
    ) -> some View {
        modifier(ChatSheetCoordinator(destination: destination, context: context))
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var destination: ChatSheetDestination? = nil
    @Previewable @State var config = ChatOptionsConfig()
    @Previewable @State var showBatch = false
    @Previewable @State var renameText = ""
    let session = ChatSession(
        id: UUID(),
        name: "Preview Session",
        model: "claude-sonnet-4-5",
        permissionMode: .default,
        status: .active,
        messageCount: 3,
        source: .ils,
        createdAt: Date(),
        lastActiveAt: Date()
    )
    Text("Chat Content")
        .chatSheets(
            destination: $destination,
            context: ChatSheetContext(
                session: session,
                chatOptionsConfig: $config,
                onCommandSelected: { _ in },
                onTemplateApplied: { _ in },
                onAttachmentsAdded: { _ in },
                contextTokensUsed: nil,
                contextWindowSize: nil,
                contextInputTokens: nil,
                contextOutputTokens: nil,
                contextCacheReadTokens: nil,
                contextCacheCreateTokens: nil,
                onForkFromContextDetail: {},
                onPermissionDecision: { _, _ in },
                pendingPermissionRequests: [],
                showBatchPermissionModal: $showBatch,
                onBatchPermissionDecision: { _, _ in },
                compactionTokensBefore: 0,
                compactionTokensAfter: 0,
                compactionSnapshot: nil,
                onPasteSnapshot: { _ in },
                onDismissCompaction: {},
                errorMessage: "",
                onRetryLastMessage: {},
                forkedSession: nil,
                onOpenFork: {},
                onConfirmDeleteMessage: {},
                renameText: $renameText,
                onConfirmRename: {},
                onConfirmDeleteSession: { false }
            )
        )
}
