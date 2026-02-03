import SwiftUI
import ILSShared

struct ChatView: View {
    let session: ChatSession
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var showCommandPalette = false
    @State private var showErrorAlert = false
    @State private var showSaveAsTemplate = false
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
        .sheet(isPresented: $showSaveAsTemplate) {
            SaveAsTemplateView(session: session, messages: viewModel.messages)
        }
        .onAppear {
            viewModel.sessionId = session.id
            Task {
                await viewModel.loadMessageHistory()
            }
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
            isDisabled: viewModel.isLoadingHistory,
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
                Button(action: { showSaveAsTemplate = true }) {
                    Label("Save as Template", systemImage: "doc.badge.plus")
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

                    // Spring animation
                    sendButtonPressed = true
                    onSend()

                    // Reset after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        sendButtonPressed = false
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(text.isEmpty || isDisabled ? ILSTheme.tertiaryText : ILSTheme.accent)
                        .scaleEffect(sendButtonPressed ? 0.85 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: sendButtonPressed)
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
        .accessibilityIdentifier("typing-indicator")
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

// MARK: - Save as Template View

struct SaveAsTemplateView: View {
    let session: ChatSession
    let messages: [ChatMessage]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TemplatesViewModel()
    @State private var templateName: String
    @State private var description = ""
    @State private var initialPrompt: String
    @State private var selectedModel: String
    @State private var permissionMode: PermissionMode
    @State private var tagsInput = ""
    @State private var isFavorite = false
    @State private var isCreating = false

    private let models = ["sonnet", "opus", "haiku"]

    init(session: ChatSession, messages: [ChatMessage]) {
        self.session = session
        self.messages = messages

        // Pre-fill form with session data
        _templateName = State(initialValue: session.name ?? "Untitled Template")
        _selectedModel = State(initialValue: session.model)
        _permissionMode = State(initialValue: session.permissionMode)

        // Use first user message as initial prompt if available
        let firstUserMessage = messages.first(where: { $0.isUser })
        _initialPrompt = State(initialValue: firstUserMessage?.text ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                templateDetailsSection
                initialPromptSection
                modelSection
                permissionsSection
                permissionDescriptionSection
                tagsSection
                favoriteSection
            }
            .navigationTitle("Save as Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
    }

    // MARK: - Form Sections

    private var templateDetailsSection: some View {
        Section("Template Details") {
            TextField("Template Name", text: $templateName)
                .accessibilityIdentifier("template-name-field")

            TextField("Description (optional)", text: $description)
                .accessibilityIdentifier("template-description-field")
        }
    }

    private var initialPromptSection: some View {
        Section("Initial Prompt") {
            TextEditor(text: $initialPrompt)
                .frame(minHeight: 100)
                .accessibilityIdentifier("template-initial-prompt-field")
        }
        .help("The default prompt that will be used when creating a session from this template")
    }

    private var modelSection: some View {
        Section("Model") {
            Picker("Model", selection: $selectedModel) {
                ForEach(models, id: \.self) { model in
                    Text(model.capitalized).tag(model)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("template-model-picker")
        }
    }

    private var permissionsSection: some View {
        Section("Permissions") {
            Picker("Permission Mode", selection: $permissionMode) {
                Text("Default").tag(PermissionMode.default)
                Text("Accept Edits").tag(PermissionMode.acceptEdits)
                Text("Plan Mode").tag(PermissionMode.plan)
                Text("Bypass All").tag(PermissionMode.bypassPermissions)
            }
            .accessibilityIdentifier("template-permission-picker")
        }
    }

    private var permissionDescriptionSection: some View {
        Section {
            Text(permissionDescription)
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.secondaryText)
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            TextField("Tags (comma-separated)", text: $tagsInput)
                .accessibilityIdentifier("template-tags-field")

            if !parsedTags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(parsedTags, id: \.self) { tag in
                        Text(tag)
                            .font(ILSTheme.captionFont)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ILSTheme.accent.opacity(0.1))
                            .foregroundColor(ILSTheme.accent)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .help("Add tags to help organize and search for this template")
    }

    private var favoriteSection: some View {
        Section {
            Toggle("Mark as Favorite", isOn: $isFavorite)
                .accessibilityIdentifier("template-favorite-toggle")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .accessibilityIdentifier("cancel-save-template-button")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                saveTemplate()
            }
            .disabled(isCreating || templateName.isEmpty)
            .accessibilityIdentifier("save-template-button")
        }
    }

    private var parsedTags: [String] {
        tagsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var permissionDescription: String {
        switch permissionMode {
        case .default:
            return "Standard permission behavior - Claude will ask before executing tools."
        case .acceptEdits:
            return "Automatically approve file edits without prompting."
        case .plan:
            return "Planning mode - Claude will plan but not execute changes."
        case .bypassPermissions:
            return "Skip all permission checks. Use with caution."
        }
    }

    private func saveTemplate() {
        isCreating = true

        Task {
            let template = await viewModel.createTemplate(
                name: templateName,
                description: description.isEmpty ? nil : description,
                initialPrompt: initialPrompt.isEmpty ? nil : initialPrompt,
                model: selectedModel,
                permissionMode: permissionMode,
                tags: parsedTags.isEmpty ? nil : parsedTags
            )

            await MainActor.run {
                isCreating = false
                if let template = template {
                    // Update favorite status if needed
                    if isFavorite && !template.isFavorite {
                        Task {
                            await viewModel.toggleFavorite(template)
                            dismiss()
                        }
                    } else {
                        dismiss()
                    }
                } else if let error = viewModel.error {
                    print("Failed to save template: \(error)")
                }
            }
        }
    }
}

// MARK: - FlowLayout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)

        let height = rows.reduce(0) { $0 + $1.maxHeight } + CGFloat(max(0, rows.count - 1)) * spacing
        let width = proposal.width ?? 0

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)

        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.subviewIndices {
                let subview = subviews[index]
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.maxHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && !currentRow.subviewIndices.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
                x = 0
            }

            currentRow.subviewIndices.append(index)
            currentRow.maxHeight = max(currentRow.maxHeight, size.height)
            x += size.width + spacing
        }

        if !currentRow.subviewIndices.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    private struct Row {
        var subviewIndices: [Int] = []
        var maxHeight: CGFloat = 0
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
