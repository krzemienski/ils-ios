import SwiftUI

/// Borderless AI assistant message card — text directly on black background.
/// Thin leading accent bar provides visual anchor. No glass effect.
struct AssistantCard: View {
    let message: ChatMessage
    var onRetry: ((ChatMessage) -> Void)?
    var onDelete: ((ChatMessage) -> Void)?

    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCopyConfirmation = false
    @State private var expandAllToolCalls: Bool?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Leading accent bar
            RoundedRectangle(cornerRadius: 1)
                .fill(theme.accent)
                .frame(width: 2)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                // Role indicator + metadata
                HStack(spacing: theme.spacingXS) {
                    Text("Claude")
                        .font(.system(size: 10, weight: .semibold).leading(.tight))
                        .foregroundStyle(theme.accent)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
            .padding(.leading, 10)
        }
        .contextMenu {
            Button {
                #if os(iOS)
                UIPasteboard.general.string = message.text
                #else
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.text, forType: .string)
                #endif
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
                    .font(.system(size: 10, design: .monospaced).leading(.tight))
                    .foregroundStyle(theme.textTertiary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }

            if let cost = message.cost {
                Text("\u{00B7}")
                    .foregroundStyle(theme.textTertiary)
                Text("$\(cost, specifier: "%.4f")")
                    .font(.system(size: 10, design: .monospaced).leading(.tight))
                    .foregroundStyle(theme.textTertiary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }

            if message.tokenCount > 0 {
                Text("\u{00B7}")
                    .foregroundStyle(theme.textTertiary)
                Text("\(message.tokenCount)t")
                    .font(.system(size: 10, design: .monospaced).leading(.tight))
                    .foregroundStyle(theme.textTertiary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
    }

    // MARK: - Tool Calls

    private var toolCallsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            if message.toolCalls.count >= 2 {
                Button {
                    let newValue = (expandAllToolCalls == true) ? false : true
                    if reduceMotion {
                        expandAllToolCalls = newValue
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandAllToolCalls = newValue
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: expandAllToolCalls == true ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                            .font(.system(size: 10).leading(.tight))
                        Text(expandAllToolCalls == true ? "Collapse All" : "Expand All")
                            .font(.system(size: theme.fontCaption, weight: .medium).leading(.tight))
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
