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
    #endif
    @FocusState var isInputFocused: Bool
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

    /// State controlling sheet and alert presentation.
    @State private var sheets = SheetState()
    /// State for transient in-flight user actions such as forking, deleting, and renaming.
    @State private var actions = ActionState()
    /// The current text in the message input field.
    @State private var inputText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    /// Pending attachments to be sent with the next message.
    @State private var pendingAttachments: [MessageAttachment] = []
    /// Whether the user has manually scrolled up from the bottom of the message list.
    @State private var isUserScrolledUp = false
    /// Whether the "jump to bottom" button is currently visible.
    @State private var showJumpToBottom = false
    /// Configuration for advanced chat options applied to the next outgoing message.
    @State private var chatOptionsConfig = ChatOptionsConfig()
    /// Debounced task for persisting draft text to UserDefaults (DATA-05).
    @State private var draftPersistTask: Task<Void, Never>?
    /// Service managing speech recognition for voice input (iOS only).
    #if os(iOS)
    @State private var speechService = SpeechRecognitionService()
    /// Interpreter for matching voice transcriptions to predefined commands.
    @State private var voiceCommandInterpreter = VoiceCommandInterpreter()
    /// Executor for running matched voice commands with confirmation flows.
    @State private var voiceCommandExecutor = VoiceCommandExecutor()
    /// Whether voice input is in command mode (true) or dictation mode (false).
    @State private var isVoiceCommandMode = false
    /// The most recent voice command match result from the interpreter.
    @State private var voiceCommandMatchResult: VoiceCommandMatch?
    /// Whether the voice command overlay is currently visible.
    @State private var showVoiceCommandOverlay = false
    #endif
    @FocusState private var isInputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    /// Master toggle — when false, the voice command mode button is hidden and command mode is disabled.
    @AppStorage("voiceCommandsEnabled") private var voiceCommandsEnabled: Bool = true
    #endif
    @AppStorage("showContextWindowBar") private var showContextWindowBar: Bool = true
    @AppStorage("notif_contextCompactionAlerts") private var notifContextCompactionAlerts: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    /// Connection and streaming lifecycle modifiers split from chatContentWithNavigation for type-checker.
    private var chatContentWithLifecycle: some View {
        chatContentWithNavigation
            .onChange(of: appState.serverURL) { _, _ in
                viewModel.configure(client: appState.apiClient, sseClient: appState.sseClient)
            }
            #if os(iOS)
            .onChange(of: viewModel.isStreaming) { wasStreaming, isNowStreaming in
                guard wasStreaming && !isNowStreaming else { return }
                SessionMonitorService.shared.removeSession(session.id)
                let sessionId = session.id
                let sessionName = session.displayName
                if let error = viewModel.error {
                    Task {
                        await NotificationService.shared.postSessionErrorNotification(
                            sessionId: sessionId,
                            sessionName: sessionName,
                            errorMessage: error.localizedDescription
                        )
                    }
                } else {
                    Task {
                        await NotificationService.shared.postStreamingCompleteNotification(
                            sessionId: sessionId,
                            sessionName: sessionName
                        )
                    }
                }
            }
            #endif
    }

    /// Additional modifiers split out to help the Swift type-checker with the long modifier chain.
    private var chatContentFinal: some View {
        chatContentWithLifecycle
            .onChange(of: inputText) { _, newValue in
                draftPersistTask?.cancel()
                draftPersistTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled else { return }
                    let key = "chatDraft_\(session.id.uuidString)"
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        UserDefaults.standard.removeObject(forKey: key)
                    } else {
                        UserDefaults.standard.set(newValue, forKey: key)
                    }
                }
            }
            .sheet(isPresented: $sheets.showSessionMemory) {
                SessionMemoryView(sessionId: session.id)
            }
            .sheet(isPresented: $sheets.showPostCompactionRecovery, onDismiss: dismissPostCompactionSheet) {
                postCompactionRecoverySheet
            }
            .sheet(isPresented: $viewModel.showBatchPermissionModal) {
                BatchPermissionRequestModal(requests: viewModel.pendingPermissionRequests) { requestIds, decision in
                    viewModel.respondToBatchPermissions(requestIds: requestIds, decision: decision)
                }
                .presentationDetents(viewModel.pendingPermissionRequests.count > 3 ? [.large] : [.medium, .large])
                .presentationBackground(theme.bgPrimary)
            }
            .sheet(isPresented: $sheets.showAttachmentPicker) {
                AttachmentPickerSheet(
                    onAttach: { attachments in
                        pendingAttachments.append(contentsOf: attachments)
                    },
                    onDismiss: { sheets.showAttachmentPicker = false }
                )
                .presentationBackground(theme.bgPrimary)
            }
            .onChange(of: viewModel.showPostCompactionRecovery) { _, newValue in
                if newValue {
                    sheets.showPostCompactionRecovery = true
                }
            }
            .onChange(of: viewModel.searchQuery) { _, newValue in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await viewModel.searchMessages(query: newValue)
                }
            }
            .onDisappear {
                draftPersistTask?.cancel()
                // STOR-002: Remove the draft key when the view disappears with an empty draft
                // to prevent unbounded key accumulation in UserDefaults.
                let key = "chatDraft_\(session.id.uuidString)"
                if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    UserDefaults.standard.removeObject(forKey: key)
                }
                ChatView.trimDraftKeys()
            }
            .overlay {
                ZStack {
                    Button("Open Command Palette") {
                        sheets.showCommandPalette = true
                    }
                    .keyboardShortcut("k", modifiers: .command)

                    Button("Cancel Streaming") {
                        viewModel.cancel()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
            }
            .onChange(of: viewModel.isStreaming) { oldValue, newValue in
                // When streaming stops, increment the refresh token so suggestion chips reload
                if oldValue == true && newValue == false {
                    promptSuggestionRefreshToken += 1
                }
            }
    }

    // MARK: - View Components

    /// Top-level layout stacking the status banner, offline banner, context window bar, related-sessions panel, message list, divider, and input bar.
    private var mainContent: some View {
        VStack(spacing: 0) {
            if sheets.showSearch {
                inlineSearchBar

                theme.divider.frame(height: 0.5)

                searchResultsView
            } else {
                statusBanner

                compactionAlertBanner

                OfflineIndicator(isOffline: viewModel.isOffline)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.3),
                        value: viewModel.isOffline
                    )

                contextWindowBar

                relatedSessionsPanel

                messageList

                theme.divider.frame(height: 0.5)

            #if os(iOS)
            if speechService.isRecording {
                VoiceInputOverlay(
                    transcribedText: .init(
                        get: { speechService.transcribedText },
                        set: { _ in }
                    ),
                    audioLevel: CGFloat(speechService.audioLevel),
                    onDone: { text in
                        speechService.stopRecording()
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        if isVoiceCommandMode {
                            processVoiceCommand(trimmed)
                        } else {
                            if inputText.isEmpty {
                                inputText = text
                            } else {
                                inputText += " " + text
                            }
                            isInputFocused = true
                        }
                    },
                    onCancel: {
                        speechService.cancelRecording()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            #endif

            #if os(iOS)
            if showVoiceCommandOverlay {
                VoiceCommandOverlay(
                    executionState: voiceCommandExecutor.executionState,
                    matchResult: voiceCommandMatchResult,
                    onConfirm: {
                        Task { await voiceCommandExecutor.confirm() }
                    },
                    onCancel: {
                        voiceCommandExecutor.cancel()
                        dismissVoiceCommandOverlay()
                    },
                    onDismiss: {
                        dismissVoiceCommandOverlay()
                    },
                    onSelectCommand: { command in
                        voiceCommandMatchResult = nil
                        Task { await executeVoiceCommand(command) }
                    },
                    onRetry: { command in
                        Task { await retryVoiceCommand(command) }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            #endif

                quickReplyToolbar

                bottomBar
            }
        }
        #if os(iOS)
        .animation(.easeInOut(duration: 0.25), value: speechService.isRecording)
        .animation(.easeInOut(duration: 0.25), value: showVoiceCommandOverlay)
        #endif
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if horizontalSizeClass == .compact {
                let pinned = multiSessionVM.pinnedSessions(from: sessionsVM.sessions)
                PersistentSessionStatusBar(
                    pinnedSessions: pinned,
                    onSessionSelected: { selected in
                        onSessionSwitch?(selected)
                    }
                )
            }
        }
    }

    /// Conditionally shows a streaming or connection status indicator at the top of the view.
    @ViewBuilder
    private var statusBanner: some View {
        if let statusText = viewModel.statusText {
            AsyncOperationBanner(
                message: statusText,
                state: viewModel.connectionState.asAsyncOperationState,
                tokenCount: viewModel.streamTokenCount,
                elapsedSeconds: viewModel.streamElapsedSeconds
            )
            .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
        }
    }

    /// In-app alert banner shown when context window usage crosses the 85%, 90%, or 95%
    /// compaction threshold and the "Context Compaction Alerts" notification preference is enabled.
    @ViewBuilder
    private var compactionAlertBanner: some View {
        if notifContextCompactionAlerts,
           viewModel.showCompactionAlert,
           let usedTokens = viewModel.contextTokensUsed,
           let windowSize = viewModel.contextWindowSize,
           windowSize > 0 {
            ContextCompactionAlertBanner(
                usedTokens: usedTokens,
                contextWindowSize: windowSize,
                onForkSession: {
                    viewModel.showCompactionAlert = false
                    Task {
                        if let forked = await viewModel.forkSession() {
                            actions.forkedSession = forked
                            sheets.showForkAlert = true
                        }
                    }
                },
                onSaveSnapshot: {
                    viewModel.showCompactionAlert = false
                    Task {
                        await viewModel.generateContextSnapshot()
                    }
                },
                onDismiss: {
                    viewModel.showCompactionAlert = false
                },
                onAutoForkSettings: {
                    appState.navigationIntent = .settings
                }
            )
            .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Compact context window usage bar shown when token data is available and the
    /// "Show context usage bar" preference is enabled in Settings.
    @ViewBuilder
    private var contextWindowBar: some View {
        if showContextWindowBar,
           let usedTokens = viewModel.contextTokensUsed,
           let windowSize = viewModel.contextWindowSize,
           windowSize > 0 {
            ContextWindowBar(
                usedTokens: usedTokens,
                contextWindowSize: windowSize
            ) {
                sheets.showContextWindowDetail = true
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Shows related past sessions at the top of a brand-new chat (no messages yet).
    ///
    /// Only rendered when the session has no messages and is not currently loading history,
    /// giving the user quick access to relevant past work before they start typing.
    @ViewBuilder
    private var relatedSessionsPanel: some View {
        if viewModel.displayMessages.isEmpty && !viewModel.isLoadingHistory {
            RelatedSessionsPanel(
                session: session,
                apiClient: appState.apiClient,
                onNavigate: { related in
                    actions.navigateToRelated = related
                }
            )
        }
    }

    /// Scrollable list of chat messages with delete and retry gesture support.
    private var messageList: some View {
        ChatMessageList(
            messages: viewModel.displayMessages,
            isStreaming: viewModel.isStreaming,
            isLoadingHistory: viewModel.isLoadingHistory,
            statusText: viewModel.statusText,
            currentStreamingMessage: viewModel.currentStreamingMessage,
            isUserScrolledUp: $isUserScrolledUp,
            showJumpToBottom: $showJumpToBottom,
            onDeleteMessage: { msg in
                actions.messageToDelete = msg
                sheets.showDeleteConfirmation = true
            },
            onRetryMessage: { msg in
                viewModel.retryMessage(msg, projectId: session.projectId)
            },
            canLoadMore: viewModel.canLoadOlderMessages,
            isLoadingMore: viewModel.isLoadingOlderMessages,
            onLoadMore: {
                Task { await viewModel.loadOlderMessages() }
            },
            sessionProjectId: session.projectId?.uuidString
        )
        // Keyboard dismissal handled by .scrollDismissesKeyboard(.interactively)
        // on ChatMessageList's ScrollView — no DragGesture needed here, which
        // previously blocked the sidebar edge-swipe gesture.
        .simultaneousGesture(
            sessionSwipeGesture,
            isEnabled: horizontalSizeClass == .compact && onSessionSwitch != nil
        )
        // ACC-003: Expose swipe-to-switch as named VoiceOver actions so assistive technology
        // users can switch pinned sessions without performing a physical swipe gesture.
        .accessibilityAction(named: "Next Session") {
            let pinned = multiSessionVM.pinnedSessions(from: sessionsVM.sessions)
            guard pinned.count >= 2,
                  let currentIndex = pinned.firstIndex(where: { $0.id == session.id }) else { return }
            let next = pinned[(currentIndex + 1) % pinned.count]
            HapticManager.impact(.light)
            onSessionSwitch?(next)
        }
        .accessibilityAction(named: "Previous Session") {
            let pinned = multiSessionVM.pinnedSessions(from: sessionsVM.sessions)
            guard pinned.count >= 2,
                  let currentIndex = pinned.firstIndex(where: { $0.id == session.id }) else { return }
            let prev = pinned[(currentIndex - 1 + pinned.count) % pinned.count]
            HapticManager.impact(.light)
            onSessionSwitch?(prev)
        }
        // UX-005: Inform VoiceOver users about the swipe gesture when pinned sessions exist.
        .accessibilityHint({
            let pinned = multiSessionVM.pinnedSessions(from: sessionsVM.sessions)
            return pinned.count >= 2 ? "Swipe left or right to switch between pinned sessions" : ""
        }())
    }

    // MARK: - Session Swipe Navigation

    /// Horizontal drag gesture for cycling through pinned sessions on iPhone.
    ///
    /// Activates only when the gesture begins past x=50 to avoid conflicting with
    /// the sidebar reveal gesture. Swipe left advances to the next pinned session;
    /// swipe right retreats to the previous one. Fires a light haptic on completion.
    private var sessionSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard value.startLocation.x > 50 else { return }
                let translation = value.translation.width
                guard abs(translation) > 60 else { return }

                let pinned = multiSessionVM.pinnedSessions(from: sessionsVM.sessions)
                guard pinned.count >= 2 else { return }
                guard let currentIndex = pinned.firstIndex(where: { $0.id == session.id }) else { return }

                let target: ChatSession
                if translation < 0 {
                    // Swipe left → next session
                    let nextIndex = (currentIndex + 1) % pinned.count
                    target = pinned[nextIndex]
                } else {
                    // Swipe right → previous session
                    let prevIndex = (currentIndex - 1 + pinned.count) % pinned.count
                    target = pinned[prevIndex]
                }

                HapticManager.impact(.light)
                onSessionSwitch?(target)
            }
    }

    // MARK: - Search UI

    private var inlineSearchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))

            TextField("Search messages...", text: $viewModel.searchQuery)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear search")
            }

            Button("Cancel") {
                searchDebounceTask?.cancel()
                searchDebounceTask = nil
                viewModel.cancelSearch()
                sheets.showSearch = false
            }
            .font(.system(size: theme.fontBody, design: theme.fontDesign))
            .foregroundStyle(theme.accent)
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
        .background(theme.bgSecondary)
    }

    @ViewBuilder
    private var searchResultsView: some View {
        if viewModel.isSearchLoading {
            VStack {
                Spacer()
                ProgressView()
                    .tint(theme.accent)
                Spacer()
            }
            .background(theme.bgPrimary)
        } else if viewModel.searchQuery.isEmpty {
            VStack {
                Spacer()
                Text("Type to search messages")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            }
            .background(theme.bgPrimary)
        } else if viewModel.searchResults.isEmpty {
            VStack {
                Spacer()
                Text("No results for \"\(viewModel.searchQuery)\"")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingLG)
                Spacer()
            }
            .background(theme.bgPrimary)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.searchResults) { result in
                        MessageSearchResultRow(result: result)
                            .padding(.horizontal, theme.spacingMD)

                        theme.divider
                            .frame(height: 0.5)
                            .padding(.leading, theme.spacingMD)
                    }
                }
            }
            .background(theme.bgPrimary)
        }
    }

    /// Compact horizontal chip bar surfacing pinned and most-used quick reply templates.
    ///
    /// Pinned templates appear first, followed by the top-5 most-used (duplicates removed).
    /// A trailing "+" chip opens the full ``QuickReplyTemplatesSheet``.
    private var quickReplyToolbar: some View {
        QuickReplyToolbar(
            templates: quickReplyToolbarTemplates,
            onSelect: { template in
                QuickReplyTemplateManager.shared.recordUsage(
                    id: template.id,
                    projectId: session.projectId?.uuidString
                )
                applyTemplate(template)
            },
            onShowAll: { sheets.showQuickReplyTemplates = true }
        )
    }

    /// Ordered list of templates shown in the quick reply toolbar.
    ///
    /// Pinned (favourite) templates are listed first, followed by the top-5 most-used
    /// custom templates. Duplicates are removed by ID so a pinned template that is also
    /// frequently used only appears once.
    private var quickReplyToolbarTemplates: [QuickReplyTemplate] {
        let manager = QuickReplyTemplateManager.shared
        var seen = Set<UUID>()
        var combined: [QuickReplyTemplate] = []
        for template in manager.pinnedTemplates() + manager.mostUsedTemplates(limit: 5) {
            if seen.insert(template.id).inserted {
                combined.append(template)
            }
        }
        return combined
    }

    /// Chat input bar for composing and sending messages to Claude.
    ///
    /// When offline, the send button is disabled and a queued-message count indicator
    /// is shown above the input row if any messages are waiting to be sent.
    private var bottomBar: some View {
        VStack(spacing: 0) {
            if viewModel.isOffline && viewModel.queuedMessageCount > 0 {
                offlineQueueIndicator
            }
            chatInputBar
                .focused($isInputFocused)
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.25),
            value: viewModel.isOffline && viewModel.queuedMessageCount > 0
        )
    }

    @ViewBuilder
    private var chatInputBar: some View {
        #if os(iOS)
        ChatInputBar(
            text: $inputText,
            isStreaming: viewModel.isStreaming,
            isDisabled: viewModel.isLoadingHistory || viewModel.isOffline,
            hasCustomOptions: chatOptionsConfig.hasCustomOptions,
            onSend: sendMessage,
            onCancel: { viewModel.cancel() },
            onCommandPalette: { sheets.showCommandPalette = true },
            onAdvancedOptions: { sheets.showAdvancedOptions = true },
            onVoiceInput: { toggleVoiceInput() },
            isRecording: speechService.isRecording,
            onVoiceCommandToggle: voiceCommandsEnabled ? { toggleVoiceCommandMode() } : nil,
            isVoiceCommandMode: voiceCommandsEnabled && isVoiceCommandMode,
            attachments: $pendingAttachments,
            onAttachmentTap: { sheets.showAttachmentPicker = true },
            session: session,
            apiClient: appState.apiClient,
            onSuggestionTap: { suggestion in
                inputText = suggestion
                isInputFocused = true
            },
            promptSuggestionRefreshToken: promptSuggestionRefreshToken
        )
        #else
        ChatInputBar(
            text: $inputText,
            isStreaming: viewModel.isStreaming,
            isDisabled: viewModel.isLoadingHistory || viewModel.isOffline,
            hasCustomOptions: chatOptionsConfig.hasCustomOptions,
            onSend: sendMessage,
            onCancel: { viewModel.cancel() },
            onCommandPalette: { sheets.showCommandPalette = true },
            onAdvancedOptions: { sheets.showAdvancedOptions = true },
            pendingCount: MessageQueueService.shared.pendingCount,
            session: session,
            apiClient: appState.apiClient,
            onSuggestionTap: { suggestion in
                inputText = suggestion
                isInputFocused = true
            },
            promptSuggestionRefreshToken: promptSuggestionRefreshToken
        )
        #endif
    }

    /// Thin strip above the input bar showing how many messages are queued offline.
    @ViewBuilder
    private var offlineQueueIndicator: some View {
        let count = viewModel.queuedMessageCount
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.system(size: theme.fontCaption, weight: .semibold))
            Text("\(count) message\(count == 1 ? "" : "s") queued — will send when online")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
        }
        .foregroundStyle(theme.warning)
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingXS)
        .frame(maxWidth: .infinity)
        .background(
            theme.warning.opacity(0.15)
                .overlay(
                    Rectangle()
                        .stroke(theme.warning.opacity(0.3), lineWidth: 0.5)
                )
        )
        .transition(
            reduceMotion
                ? .opacity
                : .move(edge: .bottom).combined(with: .opacity)
        )
        .accessibilityLabel("\(count) message\(count == 1 ? "" : "s") queued. Will send when back online.")
    }

        /// Toolbar items providing session management actions: rename, fork, export, info, and delete.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        if let onBack {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundStyle(theme.accent)
                }
                .accessibilityLabel("Go back")
            }
        }
        #endif
        // Connection quality indicator — only visible when connected (offline state shown by OfflineIndicator)
        ToolbarItem(placement: .automatic) {
            if ConnectionQualityService.shared.quality != .offline {
                ConnectionQualityIndicator(
                    quality: ConnectionQualityService.shared.quality,
                    latencyMs: ConnectionQualityService.shared.latencyMs
                )
                .accessibilityIdentifier("connection-quality-indicator")
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                viewModel.isSearchActive = true
                sheets.showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
            }
            .accessibilityLabel("Search messages")
            .accessibilityIdentifier("search-messages-button")
        }

        // Pin/Unpin button — iPad and Mac only (regular horizontal size class).
        if horizontalSizeClass == .regular {
            ToolbarItem(placement: .navigationBarTrailing) {
                let isPinned = multiSessionVM.isPinned(session)
                Button {
                    if isPinned {
                        multiSessionVM.unpinSession(session)
                    } else {
                        multiSessionVM.pinSession(session)
                    }
                    HapticManager.selection()
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(isPinned ? theme.accent : theme.textSecondary)
                }
                .accessibilityLabel(isPinned ? "Unpin from Split View" : "Pin to Split View")
                .accessibilityIdentifier("pin-session-button")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    actions.renameText = session.name ?? ""
                    sheets.isRenaming = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button {
                    Task {
                        if let forked = await viewModel.forkSession() {
                            actions.forkedSession = forked
                            sheets.showForkAlert = true
                        }
                    }
                } label: {
                    Label("Fork Session", systemImage: "arrow.branch")
                }
                .accessibilityIdentifier("fork-session-button")

                Button {
                    actions.navigateToForkTree = session
                } label: {
                    Label("Fork Tree", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .accessibilityIdentifier("fork-tree-button")

                Button {
                    sheets.showSessionMemory = true
                } label: {
                    Label("Session Memory", systemImage: "note.text")
                }
                .accessibilityIdentifier("session-memory-button")

                Button {
                    exportSession()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Button(action: { sheets.showSessionInfo = true }) {
                    Label("Session Info", systemImage: "info.circle")
                }
                .accessibilityIdentifier("session-info-button")

                Divider()
                if let cost = session.totalCostUSD {
                    Text("Cost: $\(cost, specifier: "%.4f")")
                }
                Text("Model: \(session.model)")

                if let projectName = session.projectName {
                    Text("Project: \(projectName)")
                }
                if session.source == .external {
                    Text("Source: Claude Code")
                }

                Divider()
                Button(role: .destructive) {
                    sheets.showDeleteSessionConfirmation = true
                } label: {
                    Label("Delete Session", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityIdentifier("chat-menu-button")
            .accessibilityLabel("Chat options menu")
            .accessibilityHint("Shows rename, fork, export, and other session options")
        }
    }

    // MARK: - Setup

    /// Configure the view model and load message history.
    private func setupChatView() async {
        // Restore draft from UserDefaults (DATA-05)
        let draftKey = "chatDraft_\(session.id.uuidString)"
        if let saved = UserDefaults.standard.string(forKey: draftKey), !saved.isEmpty {
            inputText = saved
        }

        viewModel.configure(client: appState.apiClient, sseClient: appState.sseClient)
        viewModel.sessionId = session.id
        viewModel.encodedProjectPath = session.encodedProjectPath
        viewModel.claudeSessionId = session.claudeSessionId

        // Inject checkpoint support for ILS-managed sessions only
        if session.source == .ils {
            checkpointViewModel.configure(client: appState.apiClient)
            viewModel.checkpointViewModel = checkpointViewModel
            checkpointViewModel.onRestoreCompleted = { [weak viewModel] in
                Task { await viewModel?.refreshMessages() }
            }
        }

        await viewModel.loadMessageHistory()
    }

    // MARK: - Actions

    #if os(iOS)
    /// Toggle voice input recording on or off.
    private func toggleVoiceInput() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task {
                let granted = await speechService.requestPermissions()
                guard granted else { return }
                try? await speechService.startRecording()
            }
        }
    }

    /// Toggle voice command mode on or off.
    ///
    /// When enabled, voice transcriptions are routed through the ``VoiceCommandInterpreter``
    /// instead of being inserted as text into the input field.
    /// Respects the ``voiceCommandsEnabled`` master toggle.
    private func toggleVoiceCommandMode() {
        guard voiceCommandsEnabled else { return }
        isVoiceCommandMode.toggle()
        if !isVoiceCommandMode {
            // Reset voice command state when exiting command mode
            dismissVoiceCommandOverlay()
        }
    }

    /// Process a voice transcription as a command by routing it through the interpreter.
    ///
    /// Confidence-based routing:
    /// - **Exact match** with confidence ≥ high threshold → auto-execute.
    /// - **Exact match** with confidence < high threshold → confirm before executing.
    /// - **Fuzzy match** with confidence ≥ high threshold → auto-execute.
    /// - **Fuzzy match** with confidence < high threshold → confirm before executing.
    /// - **Ambiguous** → show disambiguation UI.
    /// - **No match** → show suggestions.
    private func processVoiceCommand(_ transcription: String) {
        let context = VoiceCommandContext(
            hasPendingPermissions: viewModel.pendingPermissionRequests.count > 0,
            pendingPermissionCount: viewModel.pendingPermissionRequests.count,
            activeScreen: .chat(session)
        )
        let match = voiceCommandInterpreter.interpret(transcription, context: context)
        voiceCommandMatchResult = match

        let highThreshold = voiceCommandInterpreter.highConfidenceThreshold

        switch match {
        case .exact(let command, let confidence):
            // Exact matches below high confidence still get confirmation
            let needsConfirmation = confidence < highThreshold
            Task { await executeVoiceCommand(command, forceConfirmation: needsConfirmation) }
        case .fuzzy(let command, let confidence):
            // Fuzzy matches below high confidence always require confirmation
            let needsConfirmation = confidence < highThreshold
            Task { await executeVoiceCommand(command, forceConfirmation: needsConfirmation) }
        case .ambiguous, .noMatch:
            // Show overlay with disambiguation or suggestions
            showVoiceCommandOverlay = true
        }
    }

    /// Execute a matched voice command through the executor.
    ///
    /// - Parameters:
    ///   - command: The voice command to execute.
    ///   - forceConfirmation: When true, the executor will prompt for confirmation
    ///     even for non-destructive commands (used for medium-confidence matches).
    private func executeVoiceCommand(_ command: VoiceCommand, forceConfirmation: Bool = false) async {
        let context = VoiceCommandExecutionContext(
            chatViewModel: viewModel,
            appState: appState,
            apiClient: appState.apiClient,
            sessionId: session.id
        )
        showVoiceCommandOverlay = true
        await voiceCommandExecutor.execute(command, context: context, forceConfirmation: forceConfirmation)

        // Auto-dismiss on completion after the overlay handles its own timing
        if case .completed = voiceCommandExecutor.executionState {
            // The overlay auto-dismisses via its own timer
        }
    }

    /// Dismiss the voice command overlay and reset match state.
    private func dismissVoiceCommandOverlay() {
        showVoiceCommandOverlay = false
        voiceCommandMatchResult = nil
        voiceCommandExecutor.reset()
    }

    /// Retry a previously failed voice command.
    private func retryVoiceCommand(_ command: VoiceCommand) async {
        let context = VoiceCommandExecutionContext(
            chatViewModel: viewModel,
            appState: appState,
            apiClient: viewModel.apiClient,
            sessionId: session.id
        )
        await voiceCommandExecutor.retry(command, context: context)
    }
    #endif

    // MARK: - Post-Compaction Recovery

    /// Sheet content for the post-compaction recovery experience.
    private var postCompactionRecoverySheet: some View {
        PostCompactionRecoverySheet(
            tokensBeforeCompaction: viewModel.compactionTokensBefore ?? 0,
            tokensAfterCompaction: viewModel.contextTokensUsed ?? 0,
            snapshot: viewModel.compactionSnapshot,
            onPasteAsMessage: pasteSnapshotAsMessage,
            onDismiss: dismissPostCompactionSheet
        )
    }

    /// Pastes the snapshot text into the chat input with a recovery context prefix.
    private func pasteSnapshotAsMessage(_ snapshotText: String) {
        let prefix = "The following is a context snapshot captured before this session was compacted. Please use it to restore our working context:\n\n"
        inputText = prefix + snapshotText
        sheets.showPostCompactionRecovery = false
        viewModel.showPostCompactionRecovery = false
        isInputFocused = true
    }

    /// Dismisses the post-compaction recovery sheet and resets the view model flag.
    private func dismissPostCompactionSheet() {
        sheets.showPostCompactionRecovery = false
        viewModel.showPostCompactionRecovery = false
    }

    /// Resend the most recent user message after a connection error.
    private func retryLastMessage() {
        if let lastUserMessage = viewModel.messages.last(where: { $0.isUser }) {
            viewModel.sendMessage(prompt: lastUserMessage.text, projectId: session.projectId)
        }
    }

    /// Send the current input text as a user message to Claude.
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let prompt = inputText
        let attachments = pendingAttachments
        inputText = ""
        pendingAttachments = []

        // Clear persisted draft on send (DATA-05)
        UserDefaults.standard.removeObject(forKey: "chatDraft_\(session.id.uuidString)")
        draftPersistTask?.cancel()

        viewModel.addUserMessage(prompt, attachments: attachments)
        viewModel.sendMessage(
            prompt: prompt,
            projectId: session.projectId,
            options: chatOptionsConfig.toChatOptions(),
            attachments: attachments
        )
    }

    /// Insert a quick reply template's resolved content into the input field.
    private func applyTemplate(_ template: QuickReplyTemplate) {
        let resolved = template.resolvedContent(for: session.projectId?.uuidString)
        if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            inputText = resolved
        } else {
            inputText += " " + resolved
        }
        isInputFocused = true
    }

    /// Present the export format picker for sharing the session.
    private func exportSession() {
        sheets.showExportSheet = true
    }

    // MARK: - Draft Key Maintenance

    /// STOR-002: Caps the number of persisted chat draft keys in UserDefaults to 50.
    ///
    /// Scans all keys with the `chatDraft_` prefix and removes the oldest excess entries
    /// (by UUID string lexicographic order, which is stable but not time-based — sufficient
    /// since the goal is to bound total key count, not prioritise recency precisely).
    static func trimDraftKeys(maxCount: Int = 50) {
        let defaults = UserDefaults.standard
        let prefix = "chatDraft_"
        let draftKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        guard draftKeys.count > maxCount else { return }
        let sorted = draftKeys.sorted()
        let toRemove = sorted.prefix(draftKeys.count - maxCount)
        for key in toRemove {
            defaults.removeObject(forKey: key)
        }
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
