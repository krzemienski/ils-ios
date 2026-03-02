import SwiftUI
import ILSShared

/// Primary chat interface for interacting with Claude Code within a session.
///
/// Displays the full conversation history, handles real-time message streaming,
/// and provides controls for sending messages, managing the session, and viewing session info.
/// Coordinates with ``ChatViewModel`` for message state, ``SSEClient`` for live streaming,
/// and ``ChatMessageList`` for rendering the conversation.
///
/// ## Topics
/// ### State
/// - ``session`` - The chat session being displayed
/// - ``viewModel`` - View model managing chat messages and streaming
/// - ``sheets`` - Sheet and alert presentation state
/// - ``actions`` - Transient state for in-flight user actions
///
/// ### View Components
/// - ``mainContent`` - Top-level layout container
/// - ``statusBanner`` - Connection and streaming status indicator
/// - ``messageList`` - Scrollable message history with gesture support
/// - ``bottomBar`` - Input bar for composing and sending messages
///
/// ### Actions
/// - ``sendMessage()`` - Send the current input text to Claude
/// - ``retryLastMessage()`` - Resend the most recent user message
/// - ``exportSession()`` - Export the conversation as Markdown
struct ChatView: View {
    /// The chat session this view is presenting.
    let session: ChatSession
    /// Optional closure invoked when the user taps the back button. When non-nil a back
    /// button replaces the hamburger menu in the toolbar leading position.
    var onBack: (() -> Void)? = nil
    @Environment(AppState.self) var appState
    /// View model managing chat messages, streaming state, and session connectivity.
    @State private var viewModel = ChatViewModel()

    // MARK: - Grouped State

    /// Sheet and alert presentation state — all booleans that control modal visibility.
    struct SheetState {
        var showCommandPalette = false
        var showSessionInfo = false
        var showErrorAlert = false
        var showForkAlert = false
        var showDeleteConfirmation = false
        var showExportSheet = false
        var showDeleteSessionConfirmation = false
        var showAdvancedOptions = false
        var isRenaming = false
        var showSearch = false
        var showContextWindowDetail = false
        var showQuickReplyTemplates = false
    }

    /// Transient action state — data associated with in-flight user actions.
    struct ActionState {
        var errorId: UUID?
        var forkedSession: ChatSession?
        var navigateToForked: ChatSession?
        var navigateToRelated: ChatSession?
        var messageToDelete: ChatMessage?
        var renameText = ""
        var exportMarkdown = ""
        var isExporting = false
    }

    /// State controlling sheet and alert presentation.
    @State private var sheets = SheetState()
    /// State for transient in-flight user actions such as forking, deleting, and renaming.
    @State private var actions = ActionState()
    /// The current text in the message input field.
    @State private var inputText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    /// Whether the user has manually scrolled up from the bottom of the message list.
    @State private var isUserScrolledUp = false
    /// Whether the "jump to bottom" button is currently visible.
    @State private var showJumpToBottom = false
    /// Configuration for advanced chat options applied to the next outgoing message.
    @State private var chatOptionsConfig = ChatOptionsConfig()
    /// Debounced task for persisting draft text to UserDefaults (DATA-05).
    @State private var draftPersistTask: Task<Void, Never>?
    @FocusState private var isInputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showContextWindowBar") private var showContextWindowBar: Bool = true

    // MARK: - Body

    var body: some View {
        mainContent
            .background(theme.bgPrimary)
            .navigationTitle(session.displayName)
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar { toolbarContent }
        .sheet(isPresented: $sheets.showCommandPalette) {
            CommandPaletteView { command in
                inputText = command
                sheets.showCommandPalette = false
                isInputFocused = true
            }
            .presentationBackground(theme.bgPrimary)
        }
        .sheet(isPresented: $sheets.showSessionInfo) {
            SessionInfoView(session: session)
                .environment(appState)
                .presentationBackground(theme.bgPrimary)
        }
        .task {
            await setupChatView()
        }
        .alert("Connection Error", isPresented: $sheets.showErrorAlert) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                retryLastMessage()
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred while connecting to Claude.")
        }
        .alert("Session Forked", isPresented: $sheets.showForkAlert) {
            Button("Open Fork") {
                actions.navigateToForked = actions.forkedSession
            }
            Button("Stay Here", role: .cancel) {}
        } message: {
            if let forked = actions.forkedSession {
                Text("Created new session: \(forked.name ?? "Unnamed")")
            }
        }
        .alert("Delete Message", isPresented: $sheets.showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let msg = actions.messageToDelete {
                    viewModel.deleteMessage(msg)
                    actions.messageToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                actions.messageToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this message?")
        }
        .alert("Rename Session", isPresented: $sheets.isRenaming) {
            TextField("Session name", text: $actions.renameText)
            Button("Rename") {
                Task {
                    await viewModel.renameSession(name: actions.renameText)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a new name for this session")
        }
        .alert("Delete Session", isPresented: $sheets.showDeleteSessionConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deleteSession() {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this session and all its messages.")
        }
        .sheet(isPresented: $sheets.showExportSheet) {
            ShareSheet(text: actions.exportMarkdown, fileName: "\(session.name ?? "session").md")
        }
        .sheet(isPresented: $sheets.showAdvancedOptions) {
            AdvancedOptionsSheet(config: $chatOptionsConfig)
                .presentationDetents([.large])
                .presentationBackground(theme.bgPrimary)
        }
        .sheet(isPresented: $sheets.showQuickReplyTemplates) {
            NavigationStack {
                QuickReplyTemplatesSheet { template in
                    applyTemplate(template)
                }
            }
            .presentationBackground(theme.bgPrimary)
        }
        .sheet(isPresented: $sheets.showContextWindowDetail) {
            if let usedTokens = viewModel.contextTokensUsed,
               let windowSize = viewModel.contextWindowSize {
                ContextWindowDetailSheet(
                    usedTokens: usedTokens,
                    contextWindowSize: windowSize,
                    inputTokens: viewModel.contextInputTokens,
                    outputTokens: viewModel.contextOutputTokens,
                    cacheReadTokens: viewModel.contextCacheReadTokens,
                    cacheCreateTokens: viewModel.contextCacheCreateTokens,
                    onForkSession: {
                        sheets.showContextWindowDetail = false
                        Task {
                            if let forked = await viewModel.forkSession() {
                                actions.forkedSession = forked
                                sheets.showForkAlert = true
                            }
                        }
                    },
                    onDismiss: { sheets.showContextWindowDetail = false }
                )
            }
        }
        .sheet(item: $viewModel.pendingPermissionRequest) { request in
            PermissionRequestModal(request: request) { decision in
                viewModel.respondToPermission(requestId: request.requestId, decision: decision)
            }
            .presentationDetents([.medium])
            .presentationBackground(theme.bgPrimary)
        }
        .navigationDestination(item: $actions.navigateToForked) { session in
            ChatView(session: session)
        }
        .navigationDestination(item: $actions.navigateToRelated) { session in
            ChatView(session: session)
        }
        .onChange(of: viewModel.error?.localizedDescription) { _, newValue in
            if newValue != nil {
                actions.errorId = UUID()
                sheets.showErrorAlert = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await viewModel.refreshMessages()
                }
            }
        }
        .onChange(of: appState.serverURL) { _, _ in
            viewModel.configure(client: appState.apiClient, sseClient: appState.sseClient)
        }
        .onChange(of: appState.isConnected) { _, connected in
            viewModel.isConnected = connected
        }
        .onChange(of: inputText) { _, newValue in
            // Persist draft to UserDefaults with 500ms debounce (DATA-05)
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
        .onDisappear {
            draftPersistTask?.cancel()
        }
        .onChange(of: viewModel.searchQuery) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await viewModel.searchMessages(query: newValue)
            }
        }
    }

    // MARK: - View Components

    /// Top-level layout stacking the status banner, context window bar, related-sessions panel, message list, divider, and input bar.
    private var mainContent: some View {
        VStack(spacing: 0) {
            if sheets.showSearch {
                inlineSearchBar

                theme.divider.frame(height: 0.5)

                searchResultsView
            } else {
                statusBanner

                contextWindowBar

                relatedSessionsPanel

                messageList

                theme.divider.frame(height: 0.5)

                quickReplyToolbar

                bottomBar
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
        .simultaneousGesture(
            DragGesture().onChanged { _ in
                isInputFocused = false
            }
        )
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
    private var bottomBar: some View {
        ChatInputBar(
            text: $inputText,
            isStreaming: viewModel.isStreaming,
            isDisabled: viewModel.isLoadingHistory,
            hasCustomOptions: chatOptionsConfig.hasCustomOptions,
            onSend: sendMessage,
            onCancel: { viewModel.cancel() },
            onCommandPalette: { sheets.showCommandPalette = true },
            onAdvancedOptions: { sheets.showAdvancedOptions = true },
            pendingCount: MessageQueueService.shared.pendingCount
        )
        .focused($isInputFocused)
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
                    Task { await exportSession() }
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

        await viewModel.loadMessageHistory()
    }

    // MARK: - Actions

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
        inputText = ""

        // Clear persisted draft on send (DATA-05)
        UserDefaults.standard.removeObject(forKey: "chatDraft_\(session.id.uuidString)")
        draftPersistTask?.cancel()

        viewModel.addUserMessage(prompt)
        viewModel.sendMessage(prompt: prompt, projectId: session.projectId, options: chatOptionsConfig.toChatOptions())
    }

    /// Insert a quick reply template's resolved content into the input field.
    ///
    /// Resolves template variables using their default values and any project-specific overrides,
    /// then appends the content to the current input text (preceded by a space if non-empty).
    /// Focuses the input field so the user can refine or send immediately.
    private func applyTemplate(_ template: QuickReplyTemplate) {
        let resolved = template.resolvedContent(for: session.projectId?.uuidString)
        if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            inputText = resolved
        } else {
            inputText += " " + resolved
        }
        isInputFocused = true
    }

    /// Export the full conversation as a Markdown file for sharing.
    private func exportSession() async {
        actions.isExporting = true
        actions.exportMarkdown = SessionExportService.exportMarkdown(
            session: session,
            messages: viewModel.messages
        )
        actions.isExporting = false
        sheets.showExportSheet = true
    }
}

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
}
