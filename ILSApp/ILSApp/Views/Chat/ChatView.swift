import SwiftUI
import ILSShared

struct ChatView: View {
    let session: ChatSession
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var showCommandPalette = false
    @State private var showErrorAlert = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            statusBanner
            messagesScrollView
            Divider()
            inputBar
        }
        .navigationTitle(session.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView { command in
                inputText = command
                showCommandPalette = false
                isInputFocused = true
            }
        }
        .onAppear {
            viewModel.sessionId = session.id
        }
        .alert("Connection Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                retryLastMessage()
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred while connecting to Claude.")
        }
        .onReceive(viewModel.$error) { error in
            if error != nil {
                showErrorAlert = true
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
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isStreaming) { _, isStreaming in
                if isStreaming {
                    scrollToBottom(proxy: proxy)
                }
            }
        }
    }

    private var messagesContent: some View {
        LazyVStack(alignment: .leading, spacing: ILSTheme.spacingM) {
            ForEach(Array(viewModel.messages.enumerated()), id: \.offset) { index, message in
                MessageView(message: message)
                    .id(index)
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
            onSend: sendMessage,
            onCancel: { viewModel.cancel() },
            onCommandPalette: { showCommandPalette = true }
        )
        .focused($isInputFocused)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(action: {}) {
                    Label("Fork Session", systemImage: "arrow.branch")
                }
                Button(action: {}) {
                    Label("Session Info", systemImage: "info.circle")
                }
                Divider()
                if let cost = session.totalCostUSD {
                    Text("Cost: $\(cost, specifier: "%.4f")")
                }
                Text("Model: \(session.model)")
            } label: {
                Image(systemName: "ellipsis.circle")
            }
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
    let onSend: () -> Void
    let onCancel: () -> Void
    let onCommandPalette: () -> Void

    var body: some View {
        HStack(spacing: ILSTheme.spacingS) {
            Button(action: onCommandPalette) {
                Image(systemName: "command")
                    .foregroundColor(ILSTheme.accent)
            }

            TextField("Message Claude...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .onSubmit {
                    if !text.isEmpty {
                        onSend()
                    }
                }

            if isStreaming {
                Button(action: onCancel) {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(ILSTheme.error)
                }
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(text.isEmpty ? ILSTheme.tertiaryText : ILSTheme.accent)
                }
                .disabled(text.isEmpty)
            }
        }
        .padding()
        .background(ILSTheme.secondaryBackground)
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

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, ILSTheme.spacingXS)
        .background(ILSTheme.secondaryBackground)
    }
}

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(ILSTheme.tertiaryText)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .opacity(animationPhase == index ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal, ILSTheme.spacingM)
            .padding(.vertical, ILSTheme.spacingS)
            .background(ILSTheme.assistantBubble)
            .cornerRadius(ILSTheme.cornerRadiusL)

            Spacer()
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                animationPhase = (animationPhase + 1) % 3
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
