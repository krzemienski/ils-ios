import AppKit
import SwiftUI
import ILSShared

struct MacChatView: View {
    let session: ChatSession
    @Environment(AppState.self) var appState
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""
    // MARK: - Grouped State

    struct SheetState {
        var showCommandPalette = false
        var showSessionInfo = false
        var showDeleteConfirmation = false
        var showDeleteSessionConfirmation = false
        var showAdvancedOptions = false
        var isExporting = false
    }

    struct ActionState {
        var isRenaming = false
        var renameText = ""
        var messageToDelete: ChatMessage?
        var forkedSession: ChatSession?
        var navigateToForked: ChatSession?
    }

    @State private var sheets = SheetState()
    @State private var actions = ActionState()
    @State private var showErrorAlert = false
    @State private var errorId: UUID?
    @State private var showForkAlert = false
    @State private var isUserScrolledUp = false
    @State private var showJumpToBottom = false
    @State private var chatOptionsConfig = ChatOptionsConfig()
    @FocusState private var isInputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        chatWithSessionAlerts
    }

    // MARK: - Body Sub-Expressions (split to help type checker)

    @ViewBuilder
    private var chatWithAlerts: some View {
        styledContent
            .alert("Connection Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
                Button("Retry") {
                    retryLastMessage()
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An error occurred while connecting to Claude.")
            }
            .alert("Session Forked", isPresented: $showForkAlert) {
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
    }

    @ViewBuilder
    private var chatWithSessionAlerts: some View {
        Group { chatWithAlerts }
            .alert("Rename Session", isPresented: $actions.isRenaming) {
                TextField("Session name", text: $actions.renameText)
                Button("Rename") {
                    Task {
                        do {
                            let _: APIResponse<ChatSession> = try await appState.apiClient.renameSession(id: session.id, name: actions.renameText)
                        } catch {
                            viewModel.error = error
                            showErrorAlert = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a new name for this session")
            }
            .alert("Delete Session", isPresented: $sheets.showDeleteSessionConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            let _: APIResponse<String> = try await appState.apiClient.delete("/sessions/\(session.id.uuidString)")
                            dismiss()
                        } catch {
                            viewModel.error = error
                            showErrorAlert = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this session and all its messages.")
            }
            .navigationDestination(item: $actions.navigateToForked) { session in
                MacChatView(session: session)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await viewModel.refreshMessages()
                    }
                }
            }
            .onKeyPress("k", phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                sheets.showCommandPalette = true
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
                if sheets.showCommandPalette {
                    sheets.showCommandPalette = false
                    return .handled
                }
                if sheets.showSessionInfo {
                    sheets.showSessionInfo = false
                    return .handled
                }
                if sheets.showAdvancedOptions {
                    sheets.showAdvancedOptions = false
                    return .handled
                }
                return .ignored
            }
    }

    @ViewBuilder
    private var styledContent: some View {
        mainContent
            .background(theme.bgPrimary)
            .navigationTitle(session.name.cleanedSessionTitle() ?? "Chat")
            .navigationSubtitle(sessionSubtitle)
            .toolbar { toolbarContent }
            .sheet(isPresented: $sheets.showCommandPalette) {
                CommandPaletteView { command in
                    inputText = command
                    sheets.showCommandPalette = false
                    isInputFocused = true
                }
                .frame(minWidth: 600, minHeight: 400)
                .presentationBackground(theme.bgPrimary)
            }
            .sheet(isPresented: $sheets.showSessionInfo) {
                SessionInfoView(session: session)
                    .environment(appState)
                    .frame(minWidth: 500, minHeight: 400)
                    .presentationBackground(theme.bgPrimary)
            }
            .sheet(isPresented: $sheets.showAdvancedOptions) {
                AdvancedOptionsSheet(config: $chatOptionsConfig)
                    .frame(minWidth: 500, minHeight: 600)
                    .presentationBackground(theme.bgPrimary)
            }
            .sheet(item: $viewModel.pendingPermissionRequest) { request in
                PermissionRequestModal(request: request) { decision in
                    viewModel.respondToPermission(requestId: request.requestId, decision: decision)
                }
                .frame(minWidth: 500, minHeight: 300)
                .presentationBackground(theme.bgPrimary)
            }
            .task(id: session) {
                viewModel.configure(client: appState.apiClient, sseClient: appState.sseClient)
                viewModel.sessionId = session.id
                viewModel.encodedProjectPath = session.encodedProjectPath
                viewModel.claudeSessionId = session.claudeSessionId
                await viewModel.loadMessageHistory()
            }
            .onChange(of: viewModel.error?.localizedDescription) {
                if viewModel.error != nil {
                    errorId = UUID()
                    showErrorAlert = true
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
            statusBanner

            messageList

            theme.divider.frame(height: 0.5)

            bottomBar
        }
    }

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

    private var messageList: some View {
        ChatMessageList(
            messages: viewModel.messages,
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
            sessionProjectId: session.projectId?.uuidString
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
            onCommandPalette: { sheets.showCommandPalette = true },
            onAdvancedOptions: { sheets.showAdvancedOptions = true }
        )
        .focused($isInputFocused)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Export button with macOS save panel
            Button {
                Task { await exportSession() }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export session as Markdown")
            .keyboardShortcut("e", modifiers: [.command])

            // Session info button
            Button {
                sheets.showSessionInfo = true
            } label: {
                Label("Info", systemImage: "info.circle")
            }
            .help("Show session information")
            .keyboardShortcut("i", modifiers: [.command])
            .accessibilityIdentifier("session-info-button")

            // Menu with additional actions
            Menu {
                Button {
                    actions.renameText = session.name ?? ""
                    actions.isRenaming = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button {
                    Task {
                        if let forked = await viewModel.forkSession() {
                            actions.forkedSession = forked
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
                    sheets.showDeleteSessionConfirmation = true
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
        // Use typed notification name that MacContentView listens for via .ilsCreateNewSession
        NotificationCenter.default.post(name: .ilsCreateNewSession, object: nil)
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
        viewModel.sendMessage(prompt: prompt, projectId: session.projectId, options: chatOptionsConfig.toChatOptions())
    }

    private func exportSession() async {
        sheets.isExporting = true
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

        // Use NSSavePanel for macOS
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(session.name ?? "session").md"
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Export Session"
        savePanel.message = "Choose where to save the exported session"

        let response = await savePanel.begin()
        if response == .OK, let url = savePanel.url {
            do {
                try md.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                viewModel.error = error
                showErrorAlert = true
            }
        }

        sheets.isExporting = false
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
    .environment(AppState())
    .environment(ThemeManager())
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    .environment(WindowManager.shared)
    .environmentObject(NotificationManager.shared)
}
