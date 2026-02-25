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
    }

    /// Transient action state — data associated with in-flight user actions.
    struct ActionState {
        var errorId: UUID?
        var forkedSession: ChatSession?
        var navigateToForked: ChatSession?
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
    /// Whether the user has manually scrolled up from the bottom of the message list.
    @State private var isUserScrolledUp = false
    /// Whether the "jump to bottom" button is currently visible.
    @State private var showJumpToBottom = false
    /// Configuration for advanced chat options applied to the next outgoing message.
    @State private var chatOptionsConfig = ChatOptionsConfig()
    @FocusState private var isInputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

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
    }

    // MARK: - View Components

    /// Top-level layout stacking the status banner, message list, divider, and input bar.
    private var mainContent: some View {
        VStack(spacing: 0) {
            statusBanner

            messageList

            theme.divider.frame(height: 0.5)

            bottomBar
        }
    }

    /// Conditionally shows a streaming or connection status indicator at the top of the view.
    @ViewBuilder
    private var statusBanner: some View {
        if let statusText = viewModel.statusText {
            StreamingStatusBanner(
                statusText: statusText,
                connectionState: viewModel.connectionState,
                tokenCount: viewModel.streamTokenCount,
                elapsedSeconds: viewModel.streamElapsedSeconds
            )
            .transition(.move(edge: .top).combined(with: .opacity))
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
            onAdvancedOptions: { sheets.showAdvancedOptions = true }
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

        viewModel.addUserMessage(prompt)
        viewModel.sendMessage(prompt: prompt, projectId: session.projectId, options: chatOptionsConfig.toChatOptions())
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

// MARK: - Streaming Status Banner

/// A banner displayed at the top of the chat view showing real-time streaming status.
///
/// Adapts its icon and color to reflect the current SSE connection state, and optionally
/// shows token count and elapsed time when a stream is actively receiving tokens.
struct StreamingStatusBanner: View {
    /// The human-readable status string describing the current connection or streaming state.
    let statusText: String
    /// The current SSE connection state, used to select the appropriate icon and color.
    let connectionState: SSEClient.ConnectionState
    /// Number of tokens received in the current stream. Shown when greater than zero.
    var tokenCount: Int = 0
    /// Elapsed time in seconds for the current stream. Shown alongside token count.
    var elapsedSeconds: Double = 0

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            Group {
                switch connectionState {
                case .connecting, .connected:
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(theme.accent)
                        .accessibilityIdentifier("streaming-indicator")
                case .reconnecting:
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(theme.warning)
                case .disconnected:
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(theme.error)
                }
            }
            .frame(width: 16, height: 16)

            Text(statusText)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .accessibilityIdentifier("streaming-status-text")

            Spacer()

            if tokenCount > 0 {
                Text("~\(tokenCount) tokens \u{2022} \(String(format: "%.1f", elapsedSeconds))s")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign).leading(.tight))
                    .foregroundStyle(theme.textTertiary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .accessibilityIdentifier("streaming-stats-text")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgSecondary)
        .accessibilityIdentifier("streaming-status-banner")
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
