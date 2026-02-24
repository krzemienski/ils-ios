import SwiftUI
import ILSShared

struct MessageView: View {
    let message: ChatMessage
    @State private var showCopyConfirmation = false
    @Environment(\.theme) private var theme: ThemeSnapshot

    // Date formatters centralized in DateFormatters.swift
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: theme.spacingXS) {
            HStack {
                if message.isUser { Spacer() }

                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    // Text content with code block parsing
                    if !message.text.isEmpty {
                        MessageContentView(
                            text: message.text,
                            isUser: message.isUser,
                            showCopyConfirmation: $showCopyConfirmation
                        )
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
                }
                .padding()
                .background(message.isUser ? theme.accent.opacity(0.15) : theme.bgSecondary)
                .cornerRadius(theme.cornerRadiusLarge)
                .overlay(
                    // Visual indicator for historical messages
                    message.isFromHistory ?
                        RoundedRectangle(cornerRadius: theme.cornerRadiusLarge)
                            .strokeBorder(theme.textTertiary.opacity(0.3), lineWidth: 1)
                        : nil
                )
                .accessibilityIdentifier(message.isUser ? "user-message-bubble" : "assistant-message-bubble")

                if !message.isUser { Spacer() }
            }

            // Metadata row: timestamp and cost
            HStack(spacing: theme.spacingSM) {
                if message.isUser { Spacer() }

                // Timestamp for historical messages
                if let timestamp = message.timestamp {
                    Text(formattedTimestamp(timestamp))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundColor(theme.textTertiary)
                }

                // Cost display
                if let cost = message.cost {
                    if message.timestamp != nil {
                        Text("\u{2022}")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundColor(theme.textTertiary)
                    }
                    Text("$\(cost, specifier: "%.4f")")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundColor(theme.textTertiary)
                }

                if !message.isUser { Spacer() }
            }
        }
        .toast(isPresented: $showCopyConfirmation, message: "Copied")
    }

    /// Format timestamp based on whether it's from today or an earlier date
    private func formattedTimestamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return DateFormatters.time.string(from: date)
        } else {
            return DateFormatters.dateTime.string(from: date)
        }
    }
}

struct ToolCallView: View {
    let toolCall: ToolCallDisplay
    @State private var isExpanded = false
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                        .foregroundColor(theme.accent)
                    Text(toolCall.name)
                        .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(theme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded, let input = toolCall.inputPreview {
                Text(input)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundColor(theme.textSecondary)
                    .padding(theme.spacingSM)
                    .background(theme.bgTertiary)
                    .cornerRadius(theme.cornerRadiusSmall)
            }
        }
        .padding(theme.spacingSM)
        .background(theme.bgTertiary.opacity(0.5))
        .cornerRadius(theme.cornerRadius)
    }
}

struct ToolResultView: View {
    let result: ToolResultDisplay
    @State private var isExpanded = false
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: result.isError ? "xmark.circle" : "checkmark.circle")
                        .foregroundColor(result.isError ? theme.error : theme.success)
                    Text("Result")
                        .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(theme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(result.content)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundColor(result.isError ? theme.error : theme.textPrimary)
                }
                .frame(maxHeight: 200)
                .padding(theme.spacingSM)
                .background(theme.bgTertiary)
                .cornerRadius(theme.cornerRadiusSmall)
            }
        }
        .padding(theme.spacingSM)
        .background(theme.bgTertiary.opacity(0.5))
        .cornerRadius(theme.cornerRadius)
    }
}

struct ThinkingView: View {
    let thinking: String
    @State private var isExpanded = false
    @State private var pulseScale: CGFloat = 1.0
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Button(action: {
                if reduceMotion {
                    isExpanded.toggle()
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "brain")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.entityPlugin)
                        .scaleEffect(pulseScale)
                        .frame(width: 20)
                    Text("Thinking")
                        .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, design: theme.fontDesign).leading(.tight))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(thinking)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign).italic())
                    .foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(theme.spacingSM)
                    .background(theme.bgTertiary)
                    .cornerRadius(theme.cornerRadiusSmall)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(theme.spacingSM)
        .background(
            LinearGradient(
                colors: [theme.entityPlugin.opacity(0.12), theme.info.opacity(0.06)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .strokeBorder(theme.entityPlugin.opacity(0.3), lineWidth: 0.5)
        )
        .onAppear {
            if !reduceMotion {
                startPulsing()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if !reduceMotion {
                    startPulsing()
                }
            } else {
                withAnimation(.default) {
                    pulseScale = 1.0
                }
            }
        }
    }

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
    }
}

// MARK: - Message Content View with Code Block Support

struct MessageContentView: View {
    let text: String
    let isUser: Bool
    @Binding var showCopyConfirmation: Bool
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Cached parsed segments — only recomputed when `text` changes,
    /// NOT on every view body evaluation (avoids regex per streaming tick).
    @State private var segments: [MarkdownParser.TextSegment] = []

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // SPERF-MED-6: Use indices for stable ForEach identity.
            ForEach(segments.indices, id: \.self) { index in
                let segment = segments[index]
                switch segment {
                case .plainText(let plainText):
                    Text(plainText)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .textSelection(.enabled)
                        .accessibilityIdentifier(isUser ? "user-message-text" : "assistant-message-text")
                        .contextMenu {
                            Button(action: {
                                #if os(iOS)
                                UIPasteboard.general.string = plainText
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                #else
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(plainText, forType: .string)
                                #endif
                                showCopyConfirmation = true
                            }) {
                                Label("Copy Text", systemImage: "doc.on.doc")
                                    .accessibilityHint("Copies this text segment to clipboard")
                            }
                        }

                case .codeBlock(let codeBlock):
                    CodeBlockView(
                        code: codeBlock.code,
                        language: codeBlock.language
                    )

                case .inlineCode(let code):
                    Text(code)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(theme.bgTertiary)
                        .cornerRadius(4)
                        .textSelection(.enabled)
                }
            }
        }
        .task(id: text) {
            segments = MarkdownParser.parse(text)
        }
    }
}

// MARK: - Preview

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
                ToolCallDisplay(id: "1", name: "Read", inputPreview: "file_path: /src/main.swift")
            ]
        ))
    }
    .padding()
}
