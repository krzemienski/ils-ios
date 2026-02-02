import SwiftUI
import ILSShared

struct MessageView: View {
    let message: ChatMessage
    @State private var showCopyConfirmation = false

    /// Formatter for displaying message timestamps
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    /// Formatter for displaying dates (for messages from previous days)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: ILSTheme.spacingXS) {
            HStack {
                if message.isUser { Spacer() }

                VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
                    // Text content
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(ILSTheme.bodyFont)
                            .textSelection(.enabled)
                            .accessibilityIdentifier(message.isUser ? "user-message-text" : "assistant-message-text")
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = message.text
                                    // Haptic feedback on copy
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                    showCopyConfirmation = true
                                    // Hide confirmation after 2 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showCopyConfirmation = false
                                    }
                                }) {
                                    Label("Copy Message", systemImage: "doc.on.doc")
                                }
                            }
                    }

                    // Tool calls
                    ForEach(message.toolCalls, id: \.id) { toolCall in
                        ToolCallView(toolCall: toolCall)
                    }

                    // Tool results
                    ForEach(message.toolResults, id: \.toolUseId) { result in
                        ToolResultView(result: result)
                    }

                    // Thinking
                    if let thinking = message.thinking {
                        ThinkingView(thinking: thinking)
                    }

                    // Copy confirmation overlay
                    if showCopyConfirmation {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(ILSTheme.success)
                            Text("Copied")
                                .font(ILSTheme.captionFont)
                                .foregroundColor(ILSTheme.success)
                        }
                        .padding(.horizontal, ILSTheme.spacingS)
                        .padding(.vertical, ILSTheme.spacingXS)
                        .background(ILSTheme.success.opacity(0.1))
                        .cornerRadius(ILSTheme.cornerRadiusS)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding()
                .background(message.isUser ? ILSTheme.userBubble : ILSTheme.assistantBubble)
                .cornerRadius(ILSTheme.cornerRadiusL)
                .overlay(
                    // Visual indicator for historical messages
                    message.isFromHistory ?
                        RoundedRectangle(cornerRadius: ILSTheme.cornerRadiusL)
                            .strokeBorder(ILSTheme.tertiaryText.opacity(0.3), lineWidth: 1)
                        : nil
                )
                .accessibilityIdentifier(message.isUser ? "user-message-bubble" : "assistant-message-bubble")

                if !message.isUser { Spacer() }
            }

            // Metadata row: timestamp and cost
            HStack(spacing: ILSTheme.spacingS) {
                if message.isUser { Spacer() }

                // Timestamp for historical messages
                if let timestamp = message.timestamp {
                    Text(formattedTimestamp(timestamp))
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                }

                // Cost display
                if let cost = message.cost {
                    if message.timestamp != nil {
                        Text("•")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.tertiaryText)
                    }
                    Text("$\(cost, specifier: "%.4f")")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                }

                if !message.isUser { Spacer() }
            }
        }
    }

    /// Format timestamp based on whether it's from today or an earlier date
    private func formattedTimestamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return Self.timeFormatter.string(from: date)
        } else {
            return Self.dateFormatter.string(from: date)
        }
    }
}

struct ToolCallView: View {
    let toolCall: ToolCall
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingXS) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                        .foregroundColor(ILSTheme.accent)
                    Text(toolCall.name)
                        .font(ILSTheme.headlineFont)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            if isExpanded, let input = toolCall.inputPreview {
                Text(input)
                    .font(ILSTheme.codeFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .padding(ILSTheme.spacingS)
                    .background(ILSTheme.tertiaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusS)
            }
        }
        .padding(ILSTheme.spacingS)
        .background(ILSTheme.tertiaryBackground.opacity(0.5))
        .cornerRadius(ILSTheme.cornerRadiusM)
    }
}

struct ToolResultView: View {
    let result: ToolResult
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingXS) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: result.isError ? "xmark.circle" : "checkmark.circle")
                        .foregroundColor(result.isError ? ILSTheme.error : ILSTheme.success)
                    Text("Result")
                        .font(ILSTheme.headlineFont)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(result.content)
                        .font(ILSTheme.codeFont)
                        .foregroundColor(result.isError ? ILSTheme.error : ILSTheme.primaryText)
                }
                .frame(maxHeight: 200)
                .padding(ILSTheme.spacingS)
                .background(ILSTheme.tertiaryBackground)
                .cornerRadius(ILSTheme.cornerRadiusS)
            }
        }
        .padding(ILSTheme.spacingS)
        .background(ILSTheme.tertiaryBackground.opacity(0.5))
        .cornerRadius(ILSTheme.cornerRadiusM)
    }
}

struct ThinkingView: View {
    let thinking: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingXS) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(ILSTheme.info)
                    Text("Thinking")
                        .font(ILSTheme.headlineFont)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(thinking)
                    .font(ILSTheme.bodyFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .padding(ILSTheme.spacingS)
                    .background(ILSTheme.tertiaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusS)
            }
        }
        .padding(ILSTheme.spacingS)
        .background(ILSTheme.info.opacity(0.1))
        .cornerRadius(ILSTheme.cornerRadiusM)
    }
}

// MARK: - Data Models

struct ChatMessage: Identifiable {
    let id: UUID
    let isUser: Bool
    var text: String
    var toolCalls: [ToolCall] = []
    var toolResults: [ToolResult] = []
    var thinking: String?
    var cost: Double?
    var timestamp: Date?
    var isFromHistory: Bool = false

    init(
        id: UUID = UUID(),
        isUser: Bool,
        text: String,
        toolCalls: [ToolCall] = [],
        toolResults: [ToolResult] = [],
        thinking: String? = nil,
        cost: Double? = nil,
        timestamp: Date? = nil,
        isFromHistory: Bool = false
    ) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.toolCalls = toolCalls
        self.toolResults = toolResults
        self.thinking = thinking
        self.cost = cost
        self.timestamp = timestamp
        self.isFromHistory = isFromHistory
    }
}

struct ToolCall: Identifiable {
    let id: String
    let name: String
    let inputPreview: String?
}

struct ToolResult {
    let toolUseId: String
    let content: String
    let isError: Bool
}

#Preview {
    VStack {
        MessageView(message: ChatMessage(
            isUser: true,
            text: "Hello, can you help me with my code?"
        ))

        MessageView(message: ChatMessage(
            isUser: false,
            text: "Of course! I'd be happy to help. What would you like me to do?",
            toolCalls: [
                ToolCall(id: "1", name: "Read", inputPreview: "file_path: /src/main.swift")
            ]
        ))
    }
    .padding()
}
