import SwiftUI
import ILSShared

struct ChatView: View {
    let session: ChatSession
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var showCommandPalette = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ILSTheme.spacingM) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.offset) { index, message in
                            MessageView(message: message)
                                .id(index)
                        }

                        if viewModel.isStreaming {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Claude is thinking...")
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(viewModel.messages.count - 1, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input bar
            ChatInputView(
                text: $inputText,
                isStreaming: viewModel.isStreaming,
                onSend: sendMessage,
                onCancel: { viewModel.cancel() },
                onCommandPalette: { showCommandPalette = true }
            )
            .focused($isInputFocused)
        }
        .navigationTitle(session.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
