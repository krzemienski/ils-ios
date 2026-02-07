import SwiftUI
import ILSShared
import Combine

struct ChatView: View {
    let session: ChatSession
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ChatViewModel()
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
    @State private var exportMarkdown = ""
    @State private var isExporting = false
    @State private var showDeleteSessionConfirmation = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.dismiss) private var dismiss

    /// Whether this is an external (read-only) session
    private var isExternalSession: Bool {
        session.source == .external && session.encodedProjectPath != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            statusBanner
            messagesScrollView
            Divider().overlay(theme.divider)
            if isExternalSession {
                externalSessionBanner
            } else {
                inputBar
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle(session.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(theme.bgPrimary, for: .navigationBar)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView { command in
                inputText = command
                showCommandPalette = false
                isInputFocused = true
            }
            .presentationBackground(theme.bgPrimary)
        }
        .sheet(isPresented: $showSessionInfo) {
            SessionInfoView(session: session)
                .environmentObject(appState)
                .presentationBackground(theme.bgPrimary)
        }
        .task {
            viewModel.configure(client: appState.apiClient, sseClient: appState.sseClient)
            viewModel.sessionId = session.id
            viewModel.encodedProjectPath = session.encodedProjectPath
            viewModel.claudeSessionId = session.claudeSessionId

            // Run error monitor and history loading as child tasks
            // so both are cancelled when the view disappears
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    for await _ in viewModel.$error.values {
                        guard !Task.isCancelled else { return }
                        if viewModel.error != nil {
                            errorId = UUID()
                            showErrorAlert = true
                        }
                    }
                }

                group.addTask { @MainActor in
                    await viewModel.loadMessageHistory()
                }
            }
        }
        .alert("Connection Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
            if !isExternalSession {
                Button("Retry") {
                    retryLastMessage()
                }
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred while connecting to Claude.")
        }
        .alert("Session Forked", isPresented: $showForkAlert) {
            Button("Open Fork") {
                navigateToForked = forkedSession
            }
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
            Button("Cancel", role: .cancel) {
                messageToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this message?")
        }
        .alert("Rename Session", isPresented: $isRenaming) {
            TextField("Session name", text: $renameText)
            Button("Rename") {
                Task {
                    let _: APIResponse<ChatSession> = try await appState.apiClient.renameSession(id: session.id, name: renameText)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a new name for this session")
        }
        .alert("Delete Session", isPresented: $showDeleteSessionConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    let _: APIResponse<String> = try await appState.apiClient.delete("/sessions/\(session.id.uuidString)")
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this session and all its messages.")
        }
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(text: exportMarkdown, fileName: "\(session.name ?? "session").md")
        }
        .navigationDestination(item: $navigateToForked) { session in
            ChatView(session: session)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await viewModel.refreshMessages()
                }
            }
        }
    }

    // MARK: - View Components

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

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                messagesContent
            }
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                let isNewMessage = oldCount > 0 && newCount == oldCount + 1
                if isNewMessage && !isUserScrolledUp {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: viewModel.isStreaming) { _, isStreaming in
                if isStreaming && !isUserScrolledUp {
                    scrollToBottom(proxy: proxy)
                }
                if !isStreaming {
                    withAnimation { showJumpToBottom = false }
                }
            }
            .onChange(of: viewModel.isLoadingHistory) { wasLoading, isLoading in
                if wasLoading && !isLoading && !viewModel.messages.isEmpty {
                    scrollToBottom(proxy: proxy)
                }
            }
            .simultaneousGesture(
                DragGesture().onChanged { gesture in
                    isInputFocused = false
                    if gesture.translation.height > 10 {
                        isUserScrolledUp = true
                        if viewModel.isStreaming {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showJumpToBottom = true
                            }
                        }
                    }
                }
            )
            .overlay(alignment: .bottomTrailing) {
                if showJumpToBottom {
                    Button {
                        isUserScrolledUp = false
                        withAnimation { showJumpToBottom = false }
                        scrollToBottom(proxy: proxy)
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(theme.accent)
                            .background(Circle().fill(theme.bgSecondary))
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    }
                    .padding(.trailing, theme.spacingMD)
                    .padding(.bottom, theme.spacingMD)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Jump to bottom")
                }
            }
        }
    }

    private var messagesContent: some View {
        LazyVStack(alignment: .leading, spacing: theme.spacingMD) {
            ForEach(viewModel.messages) { message in
                if message.isUser {
                    UserMessageCard(
                        message: message,
                        onDelete: { msg in
                            messageToDelete = msg
                            showDeleteConfirmation = true
                        }
                    )
                } else {
                    AssistantCard(
                        message: message,
                        onRetry: { msg in
                            viewModel.retryMessage(msg, projectId: session.projectId)
                        },
                        onDelete: { msg in
                            messageToDelete = msg
                            showDeleteConfirmation = true
                        }
                    )
                }
            }

            if shouldShowTypingIndicator() {
                StreamingIndicatorView(
                    statusText: viewModel.statusText
                )
                .id("typing-indicator")
            }

            Color.clear
                .frame(height: 1)
                .id("bottom")
        }
        .padding()
    }

    private func shouldShowTypingIndicator() -> Bool {
        viewModel.isStreaming && (viewModel.currentStreamingMessage?.text.isEmpty ?? true)
    }

    private var inputBar: some View {
        ChatInputBar(
            text: $inputText,
            isStreaming: viewModel.isStreaming,
            isDisabled: viewModel.isLoadingHistory,
            onSend: sendMessage,
            onCancel: { viewModel.cancel() },
            onCommandPalette: { showCommandPalette = true }
        )
        .focused($isInputFocused)
    }

    /// Banner shown for external (read-only) sessions
    private var externalSessionBanner: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "terminal")
                .foregroundStyle(theme.accent)
            Text("Read-only Claude Code session")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            if let count = session.messageCount as Int?, count > 0 {
                Text("\(count) messages")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding()
        .background(theme.bgSecondary)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if !isExternalSession {
                    Button {
                        renameText = session.name ?? ""
                        isRenaming = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

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
                    .accessibilityIdentifier("fork-session-button")
                }

                Button {
                    Task { await exportSession() }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Button(action: { showSessionInfo = true }) {
                    Label("Session Info", systemImage: "info.circle")
                }
                .accessibilityIdentifier("session-info-button")

                Divider()
                if let cost = session.totalCostUSD {
                    Text("Cost: $\(cost, specifier: "%.4f")")
                }
                Text("Model: \(session.model)")

                if isExternalSession {
                    Divider()
                    if let projectName = session.projectName {
                        Text("Project: \(projectName)")
                    }
                    Text("Source: Claude Code")
                }

                if !isExternalSession {
                    Divider()
                    Button(role: .destructive) {
                        showDeleteSessionConfirmation = true
                    } label: {
                        Label("Delete Session", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityIdentifier("chat-menu-button")
            .accessibilityLabel("Chat options menu")
        }
    }

    // MARK: - Actions

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func retryLastMessage() {
        if let lastUserMessage = viewModel.messages.last(where: { $0.isUser }) {
            viewModel.sendMessage(prompt: lastUserMessage.text, projectId: session.projectId)
        }
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let prompt = inputText
        inputText = ""

        viewModel.addUserMessage(prompt)
        viewModel.sendMessage(prompt: prompt, projectId: session.projectId)
    }

    private func exportSession() async {
        isExporting = true
        var md = "# Session: \(session.name ?? "Unnamed")\n\n"
        md += "Model: \(session.model.capitalized)\n"
        md += "Status: \(session.status.rawValue.capitalized)\n"
        md += "Created: \(session.createdAt.formatted())\n"
        md += "Last Active: \(session.lastActiveAt.formatted())\n"
        if let cost = session.totalCostUSD {
            md += "Cost: $\(String(format: "%.4f", cost))\n"
        }
        md += "\n---\n\n"

        for message in viewModel.messages {
            let role = message.isUser ? "User" : "Assistant"
            md += "## \(role)\n\n\(message.text)\n\n"
        }

        exportMarkdown = md
        isExporting = false
        showExportSheet = true
    }
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    var isDisabled: Bool = false
    let onSend: () -> Void
    let onCancel: () -> Void
    let onCommandPalette: () -> Void
    @State private var sendButtonPressed = false
    @State private var resetTask: Task<Void, Never>?

    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            Button(action: onCommandPalette) {
                Image(systemName: "command")
                    .foregroundStyle(isDisabled ? theme.textTertiary : theme.accent)
            }
            .disabled(isDisabled)

            TextField("Message Claude...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .disabled(isDisabled)
                .accessibilityIdentifier("chat-input-field")
                .onSubmit {
                    if !text.isEmpty && !isDisabled {
                        onSend()
                    }
                }

            if isStreaming {
                Button(action: onCancel) {
                    Image(systemName: "stop.circle.fill")
                        .foregroundStyle(theme.error)
                }
                .accessibilityIdentifier("cancel-button")
            } else {
                Button {
                    HapticManager.notification(.success)

                    if !reduceMotion {
                        sendButtonPressed = true
                    }
                    onSend()

                    if !reduceMotion {
                        resetTask?.cancel()
                        resetTask = Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }
                            sendButtonPressed = false
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(text.isEmpty || isDisabled ? theme.textTertiary : theme.accent)
                        .scaleEffect(sendButtonPressed ? 0.85 : 1.0)
                        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: sendButtonPressed)
                }
                .disabled(text.isEmpty || isDisabled)
                .accessibilityIdentifier("send-button")
            }
        }
        .padding()
        .background(theme.bgSecondary)
        .accessibilityIdentifier("chat-input-bar")
        .onDisappear { resetTask?.cancel() }
    }
}

// MARK: - Streaming Status Banner

struct StreamingStatusBanner: View {
    let statusText: String
    let connectionState: SSEClient.ConnectionState
    var tokenCount: Int = 0
    var elapsedSeconds: Double = 0

    @Environment(\.theme) private var theme: any AppTheme

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
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textSecondary)
                .accessibilityIdentifier("streaming-status-text")

            Spacer()

            if tokenCount > 0 {
                Text("\(tokenCount) tokens \u{2022} \(String(format: "%.1f", elapsedSeconds))s")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
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
