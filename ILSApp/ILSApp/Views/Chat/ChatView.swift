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
    @FocusState private var isInputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    /// Whether this is an external (read-only) session
    private var isExternalSession: Bool {
        session.source == .external && session.encodedProjectPath != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            statusBanner
            messagesScrollView
            Divider()
            if isExternalSession {
                externalSessionBanner
            } else {
                inputBar
            }
        }
        .background(ILSTheme.background)
        .navigationTitle(session.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView { command in
                inputText = command
                showCommandPalette = false
                isInputFocused = true
            }
            .presentationBackground(Color.black)
        }
        .sheet(isPresented: $showSessionInfo) {
            SessionInfoView(session: session)
                .environmentObject(appState)
                .presentationBackground(Color.black)
        }
        .task {
            viewModel.configure(client: appState.apiClient, sseClient: appState.sseClient)
            viewModel.sessionId = session.id
            viewModel.encodedProjectPath = session.encodedProjectPath
            viewModel.claudeSessionId = session.claudeSessionId

            // Monitor error changes
            Task { @MainActor in
                for await _ in viewModel.$error.values {
                    if viewModel.error != nil {
                        errorId = UUID()
                        showErrorAlert = true
                    }
                }
            }

            await viewModel.loadMessageHistory()
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
            StreamingStatusView(statusText: statusText, connectionState: viewModel.connectionState)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                messagesContent
            }
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                // Only auto-scroll for new messages, not when loading history
                // History loading replaces messages (goes from 0 to N), new messages append (increment by 1)
                let isNewMessage = oldCount > 0 && newCount == oldCount + 1
                if isNewMessage {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: viewModel.isStreaming) { _, isStreaming in
                if isStreaming {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: viewModel.isLoadingHistory) { wasLoading, isLoading in
                // Scroll to bottom after history finishes loading
                if wasLoading && !isLoading && !viewModel.messages.isEmpty {
                    scrollToBottom(proxy: proxy)
                }
            }
            .simultaneousGesture(
                // Dismiss keyboard on scroll
                DragGesture().onChanged { _ in
                    isInputFocused = false
                }
            )
        }
    }

    private var messagesContent: some View {
        LazyVStack(alignment: .leading, spacing: ILSTheme.spacingM) {
            ForEach(viewModel.messages) { message in
                MessageView(message: message)
                    .id(message.id)
            }

            if shouldShowTypingIndicator {
                TypingIndicatorView()
                    .id("typing-indicator")
            }

            Color.clear
                .frame(height: 1)
                .id("bottom")
        }
        .padding()
    }

    private var shouldShowTypingIndicator: Bool {
        viewModel.isStreaming && (viewModel.currentStreamingMessage?.text.isEmpty ?? true)
    }

    private var inputBar: some View {
        ChatInputView(
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
        HStack(spacing: ILSTheme.spacingS) {
            Image(systemName: "terminal")
                .foregroundColor(ILSTheme.accent)
            Text("Read-only Claude Code session")
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.secondaryText)
            Spacer()
            if let count = session.messageCount as Int?, count > 0 {
                Text("\(count) messages")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
            }
        }
        .padding()
        .background(ILSTheme.secondaryBackground)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if !isExternalSession {
                    Button(action: {
                        Task {
                            if let forked = await viewModel.forkSession() {
                                forkedSession = forked
                                showForkAlert = true
                            }
                        }
                    }) {
                        Label("Fork Session", systemImage: "arrow.branch")
                    }
                    .accessibilityIdentifier("fork-session-button")
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

        // Add user message locally
        viewModel.addUserMessage(prompt)

        // Send to backend
        viewModel.sendMessage(prompt: prompt, projectId: session.projectId)
    }
}

struct ChatInputView: View {
    @Binding var text: String
    let isStreaming: Bool
    var isDisabled: Bool = false
    let onSend: () -> Void
    let onCancel: () -> Void
    let onCommandPalette: () -> Void
    @State private var sendButtonPressed = false

    var body: some View {
        HStack(spacing: ILSTheme.spacingS) {
            Button(action: onCommandPalette) {
                Image(systemName: "command")
                    .foregroundColor(isDisabled ? ILSTheme.tertiaryText : ILSTheme.accent)
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
                        .foregroundColor(ILSTheme.error)
                }
                .accessibilityIdentifier("cancel-button")
            } else {
                Button(action: {
                    // Haptic feedback on send
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()

                    // Spring animation (respects reduce motion)
                    if !UIAccessibility.isReduceMotionEnabled {
                        sendButtonPressed = true
                    }
                    onSend()

                    // Reset after animation
                    if !UIAccessibility.isReduceMotionEnabled {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            sendButtonPressed = false
                        }
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(text.isEmpty || isDisabled ? ILSTheme.tertiaryText : Color(red: 0, green: 122.0/255.0, blue: 255.0/255.0))
                        .scaleEffect(sendButtonPressed ? 0.85 : 1.0)
                        .animation(UIAccessibility.isReduceMotionEnabled ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: sendButtonPressed)
                }
                .disabled(text.isEmpty || isDisabled)
                .accessibilityIdentifier("send-button")
            }
        }
        .padding()
        .background(ILSTheme.secondaryBackground)
        .accessibilityIdentifier("chat-input-bar")
    }
}

// MARK: - Streaming Status View

struct StreamingStatusView: View {
    let statusText: String
    let connectionState: SSEClient.ConnectionState

    var body: some View {
        HStack(spacing: ILSTheme.spacingS) {
            Group {
                switch connectionState {
                case .connecting, .connected:
                    ProgressView()
                        .scaleEffect(0.7)
                        .accessibilityIdentifier("streaming-indicator")
                case .reconnecting:
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(ILSTheme.warning)
                case .disconnected:
                    Image(systemName: "wifi.slash")
                        .foregroundColor(ILSTheme.error)
                }
            }
            .frame(width: 16, height: 16)

            Text(statusText)
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.secondaryText)
                .accessibilityIdentifier("streaming-status-text")

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, ILSTheme.spacingXS)
        .background(ILSTheme.secondaryBackground)
        .accessibilityIdentifier("streaming-status-banner")
    }
}

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    @State private var animationPhase = 0

    private var shouldAnimate: Bool {
        !UIAccessibility.isReduceMotionEnabled
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(ILSTheme.tertiaryText)
                        .frame(width: 8, height: 8)
                        .scaleEffect(shouldAnimate ? (animationPhase == index ? 1.2 : 0.8) : 1.0)
                        .opacity(shouldAnimate ? (animationPhase == index ? 1.0 : 0.5) : 0.7)
                }
            }
            .padding(.horizontal, ILSTheme.spacingM)
            .padding(.vertical, ILSTheme.spacingS)
            .background(ILSTheme.assistantBubble)
            .cornerRadius(ILSTheme.cornerRadiusMedium)

            Spacer()
        }
        .accessibilityIdentifier("typing-indicator")
        .task {
            guard shouldAnimate else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.3)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
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
