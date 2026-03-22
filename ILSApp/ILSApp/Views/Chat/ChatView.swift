import SwiftUI
import ILSShared

/// Primary chat interface for interacting with Claude Code within a session.
///
/// Coordinates with ``ChatViewModel`` for message state, ``SSEClient`` for live streaming,
/// ``ChatSheetCoordinator`` for modal presentation, and ``ChatToolbar`` for navigation actions.
/// View components live in `ChatView+Components.swift`; actions in `ChatView+Actions.swift`.
struct ChatView: View {

    // MARK: - Inputs

    let session: ChatSession
    var onBack: (() -> Void)? = nil
    var onSessionSwitch: ((ChatSession) -> Void)? = nil

    // MARK: - Environment

    @Environment(AppState.self) var appState
    @Environment(MultiSessionViewModel.self) var multiSessionVM
    @Environment(SessionsViewModel.self) var sessionsVM
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.theme) var theme: ThemeSnapshot
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - State

    @State var viewModel = ChatViewModel()
    @State var checkpointViewModel = CheckpointViewModel()
    @State var promptSuggestionRefreshToken: Int = 0
    /// Single active sheet or alert destination — drives ``ChatSheetCoordinator``.
    @State var sheetDestination: ChatSheetDestination?
    @State var inputText = ""
    @State var searchDebounceTask: Task<Void, Never>?
    @State var pendingAttachments: [MessageAttachment] = []
    @State var isUserScrolledUp = false
    @State var showJumpToBottom = false
    @State var chatOptionsConfig = ChatOptionsConfig()
    @State var draftPersistTask: Task<Void, Never>?
    @State var showSearch = false
    #if os(iOS)
    @State var speechService = SpeechRecognitionService()
    @State var voiceCommandInterpreter = VoiceCommandInterpreter()
    @State var voiceCommandExecutor = VoiceCommandExecutor()
    @State var isVoiceCommandMode = false
    @State var voiceCommandMatchResult: VoiceCommandMatch?
    @State var showVoiceCommandOverlay = false
    #endif
    @FocusState var isInputFocused: Bool
    #if os(iOS)
    @AppStorage("voiceCommandsEnabled") var voiceCommandsEnabled: Bool = true
    #endif
    @AppStorage("showContextWindowBar") var showContextWindowBar: Bool = true
    @AppStorage("notif_contextCompactionAlerts") var notifContextCompactionAlerts: Bool = true

    // MARK: - Transient Action State

    struct ActionState {
        var forkedSession: ChatSession?
        var navigateToForked: ChatSession?
        var navigateToRelated: ChatSession?
        var navigateToForkTree: ChatSession?
        var messageToDelete: ChatMessage?
        var renameText = ""
    }

    @State var actions = ActionState()

    // MARK: - Body

    var body: some View {
        mainContent
            .background(theme.bgPrimary)
            .navigationTitle(session.displayName)
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar { chatToolbar }
            .chatSheets(destination: $sheetDestination, context: sheetContext)
            .navigationDestination(item: $actions.navigateToForked) { ChatView(session: $0) }
            .navigationDestination(item: $actions.navigateToRelated) { ChatView(session: $0) }
            .navigationDestination(item: $actions.navigateToForkTree) { sess in
                SessionForkTreeView(initialSession: sess) { actions.navigateToRelated = $0 }
                    .environment(appState)
            }
            .onChangeHandlers(for: self)
            .onDisappear(perform: handleDisappear)
            .overlay { keyboardShortcutsOverlay }
            .task { await setupChatView() }
    }
}

// MARK: - Change Handlers Modifiers (split to avoid type-checker complexity)

private struct ChatViewChangeHandlersA: ViewModifier {
    let view: ChatView
    func body(content: Content) -> some View {
        content
            .onChange(of: view.viewModel.forkResult) { _, forked in
                if let forked {
                    view.actions.forkedSession = forked
                    view.sheetDestination = .forkAlert
                    view.viewModel.forkResult = nil
                }
            }
            .onChange(of: view.viewModel.error?.localizedDescription) { _, val in
                if val != nil { view.sheetDestination = .errorAlert }
            }
            .onChange(of: view.scenePhase) { _, phase in
                view.handleScenePhaseChange(phase)
            }
            .onChange(of: view.appState.serverURL) { _, _ in
                view.viewModel.configure(
                    client: view.appState.apiClient,
                    sseClient: view.appState.sseClient
                )
            }
            .onChange(of: view.viewModel.isStreaming) { was, isNow in
                if was && !isNow { view.promptSuggestionRefreshToken += 1 }
                #if os(iOS)
                view.handleStreamingStateChange(was: was, isNow: isNow)
                #endif
            }
    }
}

private struct ChatViewChangeHandlersB: ViewModifier {
    let view: ChatView
    func body(content: Content) -> some View {
        content
            .onChange(of: view.inputText) { _, val in
                view.persistDraft(val)
            }
            .onChange(of: view.viewModel.showPostCompactionRecovery) { _, show in
                if show { view.sheetDestination = .postCompactionRecovery }
            }
            .onChange(of: view.viewModel.pendingPermissionRequest?.requestId) { _, reqId in
                if reqId != nil, let req = view.viewModel.pendingPermissionRequest {
                    view.sheetDestination = .permissionRequest(req)
                }
            }
            .onChange(of: view.viewModel.showBatchPermissionModal) { _, show in
                if show { view.sheetDestination = .batchPermission }
            }
            .onChange(of: view.viewModel.searchQuery) { _, query in
                view.debounceSearch(query)
            }
    }
}

private extension View {
    func onChangeHandlers(for chatView: ChatView) -> some View {
        modifier(ChatViewChangeHandlersA(view: chatView))
            .modifier(ChatViewChangeHandlersB(view: chatView))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatView(session: ChatSession(
            id: UUID(),
            name: "Test Session",
            model: "sonnet",
            permissionMode: .default,
            status: .active,
            messageCount: 0,
            source: .ils,
            createdAt: Date(),
            lastActiveAt: Date()
        ))
    }
    .environment(MultiSessionViewModel())
    .environment(SessionsViewModel())
}
