import SwiftUI

/// Full-width AI assistant message card with glass effect.
/// Renders child content slots: markdown text, tool calls, thinking, code blocks.
struct AssistantCard: View {
    let message: ChatMessage
    var onRetry: ((ChatMessage) -> Void)?
    var onDelete: ((ChatMessage) -> Void)?

    @Environment(\.theme) private var theme: any AppTheme
    @State private var showCopyConfirmation = false
    @State private var expandAllToolCalls: Bool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Role indicator + metadata
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.entitySession)
                Text("Assistant")
                    .font(.system(size: theme.fontCaption, weight: .semibold))
                    .foregroundStyle(theme.entitySession)
                Spacer()
                metadataRow
            }

            // Thinking section
            if let thinking = message.thinking {
                ThinkingSection(thinking: thinking, isActive: false)
            }

            // Main text content
            if !message.text.isEmpty {
                MarkdownTextView(text: message.text)
                    .textSelection(.enabled)
            }

            // Tool calls
            if !message.toolCalls.isEmpty {
                toolCallsSection
            }

            // Tool results
            ForEach(message.toolResults, id: \.toolUseId) { result in
                ToolCallAccordion(
                    toolName: "Result",
                    output: result.content,
                    isError: result.isError
                )
            }
        }
        .padding(theme.spacingMD)
        .glassCard()
        .overlay(
            Group {
                if message.isFromHistory {
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .strokeBorder(theme.textTertiary.opacity(0.2), lineWidth: 0.5)
                }
            }
        )
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.text
                showCopyConfirmation = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showCopyConfirmation = false
                }
            } label: {
                Label("Copy Markdown", systemImage: "doc.on.doc")
            }

            if let onRetry {
                Button {
                    onRetry(message)
                } label: {
                    Label("Retry", systemImage: "arrow.counterclockwise")
                }
            }

            if let onDelete {
                Button(role: .destructive) {
                    onDelete(message)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showCopyConfirmation {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.success)
                    Text("Copied")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.success)
                }
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, theme.spacingXS)
                .background(theme.success.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .padding(theme.spacingSM)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityLabel("Assistant said: \(message.text.prefix(100))")
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: theme.spacingXS) {
            if let timestamp = message.timestamp {
                Text(formattedTimestamp(timestamp))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }

            if let cost = message.cost {
                Text("·")
                    .foregroundStyle(theme.textTertiary)
                Text("$\(cost, specifier: "%.4f")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }

            if message.tokenCount > 0 {
                Text("·")
                    .foregroundStyle(theme.textTertiary)
                Text("\(message.tokenCount)t")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    // MARK: - Tool Calls

    private var toolCallsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            if message.toolCalls.count >= 2 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandAllToolCalls = (expandAllToolCalls == true) ? false : true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: expandAllToolCalls == true ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                            .font(.system(size: 10))
                        Text(expandAllToolCalls == true ? "Collapse All" : "Expand All")
                            .font(.system(size: theme.fontCaption, weight: .medium))
                    }
                    .foregroundStyle(theme.accent)
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
        }
    }

    private func formattedTimestamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return DateFormatters.time.string(from: date)
        } else {
            return DateFormatters.dateTime.string(from: date)
        }
    }
}
