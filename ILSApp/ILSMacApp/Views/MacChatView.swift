import SwiftUI
import ILSShared
import UniformTypeIdentifiers
struct MacChatView: View {
    let session: ChatSession
    @Environment(AppState.self) var appState
    @State private var viewModel = ChatViewModel()
    @State private var promptSuggestionRefreshToken: Int = 0
    @State private var inputText = ""
    @State private var showCommandPalette = false
    @State private var showSessionInfo = false
    @State private var showErrorAlert = false
    @State private var errorId: UUID?
    @State private var showForkAlert = false
    @State private var forkedSession: ChatSession?
    @State private var navigateToForked: ChatSession?
    @State private var showDeleteConfirmation = false
    @State private var messageToDelete: ChatMessage?
    @State private var isUserScrolledUp = false
    @State private var showJumpToBottom = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showExportSheet = false
    @State private var showDeleteSessionConfirmation = false
    @State private var showAdvancedOptions = false
    @State private var showSearch = false
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var chatOptionsConfig = ChatOptionsConfig()
    @State private var showContextWindowDetail = false
    @State private var pendingAttachments: [MessageAttachment] = []
    @State private var showAttachmentPicker = false
    @State private var isDragTargeted = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        chatWithAlerts
    }

    // MARK: - Body Sub-Expressions (split to help type checker)

    @ViewBuilder
    private var chatWithAlerts: some View {
        contentWithKeyHandlers
            .alert("Connection Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
                Button("Retry") { retryLastMessage() }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An error occurred while connecting to Claude.")
            }
            .alert("Session Forked", isPresented: $showForkAlert) {
                Button("Open Fork") { navigateToForked = forkedSession }
                Button("Stay Here", role: .cancel) {}
            } message: {
                if let forked = forkedSession {
                    Text("Created new session: \(forked.name ?? "Unnamed")")
                }
            }
            .alert("Delete Message", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let msg = messageToDelete {
                        viewModel.deleteMessage(msg)
                        messageToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { messageToDelete = nil }
            } message: {
                Text("Are you sure you want to delete this message?")
            }
            .alert("Rename Session", isPresented: $isRenaming) {
                TextField("Session name", text: $renameText)
                Button("Rename") {
                    Task { await viewModel.renameSession(name: renameText) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a new name for this session")
            }
            .alert("Delete Session", isPresented: $showDeleteSessionConfirmation) {
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
    }

    @ViewBuilder
    private var contentWithKeyHandlers: some View {
        styledContent
            .navigationDestination(item: $navigateToForked) { session in
                MacChatView(session: session)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await viewModel.refreshMessages()
                    }
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
            .onKeyPress("k", phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                NotificationCenter.default.post(name: .ilsOpenCommandPalette, object: nil)
                return .handled
            }
            .onKeyPress("e", phases: .down) { press in
                guard press.modifiers.contains(.command) && press.modifiers.contains(.option) else { return .ignored }
                NotificationCenter.default.post(name: .ilsToggleExpandAllToolCalls, object: nil)
                return .handled
            }
            .onKeyPress("s", phases: .down) { press in
                guard press.modifiers.contains(.command) && press.modifiers.contains(.shift) else { return .ignored }
                captureScreenshot()
                return .handled
            }
            .onKeyPress(.return, phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isStreaming {
                    sendMessage()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.escape) {
                if showSearch {
                    searchDebounceTask?.cancel()
                    searchDebounceTask = nil
                    viewModel.cancelSearch()
                    showSearch = false
                    return .handled
                }
                if showCommandPalette {
                    showCommandPalette = false
                    return .handled
                }
                if showSessionInfo {
                    showSessionInfo = false
                    return .handled
                }
                if showAdvancedOptions {
                    showAdvancedOptions = false
                    return .handled
                }
                return .ignored
            }
    }

    @ViewBuilder
    private var styledContent: some View {
        @Bindable var viewModel = viewModel
        mainContent
            .background(theme.bgPrimary)
            .navigationTitle(session.name ?? "Chat")
            .navigationSubtitle(sessionSubtitle)
            .toolbar { toolbarContent }
            #if os(macOS)
            .chatTouchBar(
                inputText: inputText,
                isStreaming: viewModel.isStreaming,
                isDisabled: viewModel.isLoadingHistory,
                onSend: sendMessage,
                onCommandPalette: { showCommandPalette = true },
                onSessionInfo: { showSessionInfo = true },
                onNewSession: createNewSession
            )
            #endif
            .sheet(isPresented: $showCommandPalette) {
                CommandPaletteView { command in
                    inputText = command
                    showCommandPalette = false
                    isInputFocused = true
                }
                .frame(minWidth: 600, minHeight: 400)
                .presentationBackground(theme.bgPrimary)
            }
            .sheet(isPresented: $showSessionInfo) {
                SessionInfoView(session: session)
                    .environment(appState)
                    .frame(minWidth: 500, minHeight: 400)
                    .presentationBackground(theme.bgPrimary)
            }
            .sheet(isPresented: $showAdvancedOptions) {
                AdvancedOptionsSheet(config: $chatOptionsConfig)
                    .frame(minWidth: 500, minHeight: 600)
                    .presentationBackground(theme.bgPrimary)
            }
            .sheet(isPresented: $showAttachmentPicker) {
                AttachmentPickerSheet(
                    onAttach: { attachments in pendingAttachments.append(contentsOf: attachments) },
                    onDismiss: { showAttachmentPicker = false }
                )
                .frame(minWidth: 400, minHeight: 300)
                .presentationBackground(theme.bgPrimary)
            }
            .sheet(isPresented: $showExportSheet) {
                MacSessionExportSheet(session: session, messages: viewModel.messages)
                    .environment(appState)
                    .frame(minWidth: 500, minHeight: 400)
                    .presentationBackground(theme.bgPrimary)
            }
            .sheet(item: $viewModel.pendingPermissionRequest) { request in
                PermissionRequestModal(request: request) { decision in
                    viewModel.respondToPermission(requestId: request.requestId, decision: decision)
                }
                .frame(minWidth: 500, minHeight: 300)
                .presentationBackground(theme.bgPrimary)
            }
            .sheet(isPresented: $showContextWindowDetail) {
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
                            showContextWindowDetail = false
                            Task {
                                if let forked = await viewModel.forkSession() {
                                    forkedSession = forked
                                    showForkAlert = true
                                }
                            }
                        },
                        onDismiss: { showContextWindowDetail = false }
                    )
                    .frame(minWidth: 500, minHeight: 500)
                    .presentationBackground(theme.bgPrimary)
                }
            }
            .task {
                viewModel.configure(client: appState.apiClient, sseClient: appState.sseClient)
                viewModel.sessionId = session.id
                viewModel.encodedProjectPath = session.encodedProjectPath
                viewModel.claudeSessionId = session.claudeSessionId

                await viewModel.loadMessageHistory()
            }
            .onChange(of: viewModel.error?.localizedDescription) { _, newValue in
                if newValue != nil {
                    errorId = UUID()
                    showErrorAlert = true
                }
            }
            .onChange(of: viewModel.isStreaming) { wasStreaming, isNowStreaming in
                if wasStreaming && !isNowStreaming {
                    Task {
                        await NotificationManager.shared.postStreamingCompleteNotification(
                            sessionId: session.id,
                            sessionName: session.name ?? "Chat"
                        )
                    }
                    promptSuggestionRefreshToken += 1
                }
            }
    }

    // MARK: - View Components

    private var sessionSubtitle: String {
        var parts: [String] = []
        parts.append("Model: \(session.model)")
        if let projectName = session.projectName {
            parts.append("Project: \(projectName)")
        }
        if let cost = session.totalCostUSD {
            parts.append("Cost: $\(String(format: "%.4f", cost))")
        }
        return parts.joined(separator: " • ")
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if showSearch {
                inlineSearchBar

                theme.divider.frame(height: 0.5)

                searchResultsView
            } else {
                statusBanner

                contextWindowBar

                messageList

                theme.divider.frame(height: 0.5)

                bottomBar
            }
        }
        .overlay {
            if isDragTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.accent, lineWidth: 2)
                    .background(theme.accent.opacity(0.05))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 36))
                                .foregroundStyle(theme.accent)
                            Text("Drop to attach")
                                .font(.headline)
                                .foregroundStyle(theme.accent)
                        }
                    }
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.image], isTargeted: $isDragTargeted) { providers in
            for provider in providers {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data,
                          let attachment = makeAttachment(from: data, mimeType: "image/jpeg", filename: nil) else { return }
                    DispatchQueue.main.async {
                        pendingAttachments.append(attachment)
                    }
                }
            }
            return true
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let statusText = viewModel.statusText {
            AsyncOperationBanner(
                message: statusText,
                state: viewModel.connectionState.asAsyncOperationState,
                tokenCount: viewModel.streamTokenCount,
                elapsedSeconds: viewModel.streamElapsedSeconds
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var contextWindowBar: some View {
        if let usedTokens = viewModel.contextTokensUsed,
           let windowSize = viewModel.contextWindowSize,
           windowSize > 0 {
            ContextWindowBar(
                usedTokens: usedTokens,
                contextWindowSize: windowSize
            ) {
                showContextWindowDetail = true
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

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
                messageToDelete = msg
                showDeleteConfirmation = true
            },
            onRetryMessage: { msg in
                viewModel.retryMessage(msg, projectId: session.projectId)
            },
            canLoadMore: viewModel.canLoadOlderMessages,
            isLoadingMore: viewModel.isLoadingOlderMessages,
            onLoadMore: {
                Task { await viewModel.loadOlderMessages() }
            },
            sessionProjectId: session.projectId?.uuidString,
            sessionId: session.id,
            sessionName: session.name
        )
        .simultaneousGesture(
            DragGesture().onChanged { _ in
                isInputFocused = false
            }
        )
    }

    private var bottomBar: some View {
        ChatInputBar(
            text: $inputText,
            isStreaming: viewModel.isStreaming,
            isDisabled: viewModel.isLoadingHistory,
            hasCustomOptions: chatOptionsConfig.hasCustomOptions,
            onSend: sendMessage,
            onCancel: { viewModel.cancel() },
            onCommandPalette: { showCommandPalette = true },
            onAdvancedOptions: { showAdvancedOptions = true },
            attachments: $pendingAttachments,
            onAttachmentTap: { showAttachmentPicker = true },
            session: session,
            apiClient: appState.apiClient,
            onSuggestionTap: { suggestion in
                inputText = suggestion
                isInputFocused = true
            },
            promptSuggestionRefreshToken: promptSuggestionRefreshToken
        )
        .focused($isInputFocused)
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
                .buttonStyle(.plain)
            }

            Button("Cancel") {
                searchDebounceTask?.cancel()
                searchDebounceTask = nil
                viewModel.cancelSearch()
                showSearch = false
            }
            .font(.system(size: theme.fontBody, design: theme.fontDesign))
            .foregroundStyle(theme.accent)
            .buttonStyle(.plain)
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Search button
            Button {
                viewModel.isSearchActive = true
                showSearch = true
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .help("Search messages")
            .keyboardShortcut("f", modifiers: [.command])
            .accessibilityLabel("Search messages")
            .accessibilityIdentifier("search-messages-button")

            // Export button with format picker sheet
            Button {
                showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export session")
            .keyboardShortcut("e", modifiers: [.command])

            // Session info button
            Button {
                showSessionInfo = true
            } label: {
                Label("Info", systemImage: "info.circle")
            }
            .help("Show session information")
            .keyboardShortcut("i", modifiers: [.command])
            .accessibilityIdentifier("session-info-button")

            // Menu with additional actions
            Menu {
                Button {
                    renameText = session.name ?? ""
                    isRenaming = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button {
                    Task {
                        if let forked = await viewModel.forkSession() {
                            forkedSession = forked
                            showForkAlert = true
                        }
                    }
                } label: {
                    Label("Fork Session", systemImage: "arrow.branch")
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .accessibilityIdentifier("fork-session-button")

                Divider()

                if session.source == .external {
                    Text("Source: Claude Code")
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteSessionConfirmation = true
                } label: {
                    Label("Delete Session", systemImage: "trash")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .help("More options")
            .accessibilityIdentifier("chat-menu-button")
            .accessibilityLabel("Chat options menu")
        }
    }

    // MARK: - Actions

    private func createNewSession() {
        // Post notification for creating a new session
        // This is handled by the main content view or app delegate
        NotificationCenter.default.post(name: Notification.Name("NewSession"), object: nil)
    }

    private func retryLastMessage() {
        if let lastUserMessage = viewModel.messages.last(where: { $0.isUser }) {
            viewModel.sendMessage(prompt: lastUserMessage.text, projectId: session.projectId)
        }
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let prompt = inputText
        let attachments = pendingAttachments
        inputText = ""
        pendingAttachments = []

        viewModel.addUserMessage(prompt, attachments: attachments)
        viewModel.sendMessage(prompt: prompt, projectId: session.projectId, options: chatOptionsConfig.toChatOptions(), attachments: attachments)
    }

    /// Compress image data into a `MessageAttachment`, or nil on failure.
    private func makeAttachment(from data: Data, mimeType: String, filename: String?) -> MessageAttachment? {
        guard let compressed = ImageCompressionService.compress(data: data, mimeType: mimeType) else { return nil }
        return MessageAttachment(
            mimeType: compressed.mimeType,
            filename: filename,
            data: compressed.data.base64EncodedString(),
            width: compressed.width,
            height: compressed.height
        )
    }

    /// Capture the main screen and add it as a pending attachment (Cmd+Shift+S).
    private func captureScreenshot() {
        guard let screen = NSScreen.main else { return }
        let screenBounds = CGRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y,
            width: screen.frame.width,
            height: screen.frame.height
        )
        guard let cgImage = CGWindowListCreateImage(
            screenBounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else { return }
        let nsImage = NSImage(cgImage: cgImage, size: screenBounds.size)
        guard let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }
        if let attachment = makeAttachment(from: data, mimeType: "image/jpeg", filename: "screenshot.jpg") {
            pendingAttachments.append(attachment)
        }
    }

    private func exportSession() {
        showExportSheet = true
    }

}

#Preview {
    NavigationStack {
        MacChatView(session: ChatSession(
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
