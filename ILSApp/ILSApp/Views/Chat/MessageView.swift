import SwiftUI
import ILSShared

struct MessageView: View {
    let message: ChatMessage
    var onRetry: ((ChatMessage) -> Void)?
    var onDelete: ((ChatMessage) -> Void)?
    @State private var showCopyConfirmation = false
    @State private var expandAllToolCalls: Bool? = nil

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

    // MARK: - Bubble Colors

    /// User bubble gradient: #007AFF to #0056B3
    private let userGradientStart = Color(red: 0, green: 122.0/255.0, blue: 255.0/255.0)
    private let userGradientEnd = Color(red: 0, green: 86.0/255.0, blue: 179.0/255.0)

    /// Assistant bubble background: #111827
    private let assistantBg = Color(red: 17.0/255.0, green: 24.0/255.0, blue: 39.0/255.0)
    /// Assistant bubble border: white at 6% opacity
    private let assistantBorder = Color.white.opacity(0.06)


    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: ILSTheme.spacingXS) {
            HStack {
                if message.isUser { Spacer() }

                VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
                    // Text content
                    if !message.text.isEmpty {
                        if message.isUser {
                            Text(message.text)
                                .font(ILSTheme.bodyFont)
                                .foregroundColor(.white)
                                .textSelection(.enabled)
                                .accessibilityIdentifier("user-message-text")
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = message.text
                                        HapticManager.notification(.success)
                                        showCopyConfirmation = true
                                        Task {
                                            try? await Task.sleep(for: .seconds(2))
                                            showCopyConfirmation = false
                                        }
                                    }) {
                                        Label("Copy Markdown", systemImage: "doc.on.doc")
                                    }

                                    Button(role: .destructive, action: { onDelete?(message) }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        } else {
                            MarkdownTextView(text: message.text)
                                .foregroundColor(ILSTheme.textPrimary)
                                .accessibilityIdentifier("assistant-message-text")
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = message.text
                                        HapticManager.notification(.success)
                                        showCopyConfirmation = true
                                        Task {
                                            try? await Task.sleep(for: .seconds(2))
                                            showCopyConfirmation = false
                                        }
                                    }) {
                                        Label("Copy Markdown", systemImage: "doc.on.doc")
                                    }

                                    Button(action: { onRetry?(message) }) {
                                        Label("Retry", systemImage: "arrow.counterclockwise")
                                    }

                                    Button(role: .destructive, action: { onDelete?(message) }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }

                    // Tool calls
                    if message.toolCalls.count >= 2 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandAllToolCalls = (expandAllToolCalls == true) ? false : true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: expandAllToolCalls == true ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                                    .font(.caption2)
                                Text(expandAllToolCalls == true ? "Collapse All" : "Expand All")
                                    .font(.system(.caption2, weight: .medium))
                            }
                            .foregroundColor(ILSTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(message.toolCalls, id: \.id) { toolCall in
                        ToolCallAccordion(
                            toolName: toolCall.name,
                            input: toolCall.inputPreview,
                            inputPairs: toolCall.inputPairs,
                            output: nil,
                            expandAll: $expandAllToolCalls
                        )
                    }

                    // Tool results
                    ForEach(message.toolResults, id: \.toolUseId) { result in
                        ToolCallAccordion(
                            toolName: "Result",
                            output: result.content,
                            isError: result.isError
                        )
                    }

                    // Thinking
                    if let thinking = message.thinking {
                        ThinkingSection(thinking: thinking, isActive: false)
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
                        .cornerRadius(ILSTheme.cornerRadiusXS)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding()
                .background(bubbleBackground)
                .clipShape(bubbleShape)
                .overlay(
                    Group {
                        if !message.isUser {
                            bubbleShape.strokeBorder(assistantBorder, lineWidth: 1)
                        }
                    }
                )
                .overlay(
                    // Visual indicator for historical messages
                    message.isFromHistory ?
                        bubbleShape
                            .strokeBorder(ILSTheme.tertiaryText.opacity(0.3), lineWidth: 1)
                        : nil
                )
                .accessibilityIdentifier(message.isUser ? "user-message-bubble" : "assistant-message-bubble")
                .accessibilityCustomContent("Actions", "Copy, Retry, Delete")

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
                        Text("\u{2022}")
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

    // MARK: - Bubble Styling

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.isUser {
            LinearGradient(
                colors: [userGradientStart, userGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            assistantBg
                .background(.ultraThinMaterial)
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if message.isUser {
            // User: 16pt radius, 4pt bottom-right
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 4,
                topTrailingRadius: 16
            )
        } else {
            // Assistant: 16pt radius, 4pt bottom-left
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 16,
                topTrailingRadius: 16
            )
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

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            MessageView(message: ChatMessage(
                isUser: true,
                text: "Hello, can you help me with my code?"
            ))

            MessageView(message: ChatMessage(
                isUser: false,
                text: "Here's the analysis:\n\n```swift\nfunc greet() -> String {\n    return \"Hello!\"\n}\n```",
                toolCalls: [
                    ToolCallDisplay(id: "1", name: "Read", inputPreview: "file_path: /src/main.swift"),
                    ToolCallDisplay(id: "2", name: "Grep", inputPreview: "pattern: greet")
                ],
                thinking: "Let me analyze the code structure..."
            ), onRetry: { _ in }, onDelete: { _ in })
        }
        .padding()
    }
    .background(Color.black)
}
