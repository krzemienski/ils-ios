import SwiftUI
import ILSShared

struct MessageView: View {
    let message: ChatMessage

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
                .background(message.isUser ? ILSTheme.userBubble : ILSTheme.assistantBubble)
                .cornerRadius(ILSTheme.cornerRadiusL)

                if !message.isUser { Spacer() }
            }

            // Metadata
            if let cost = message.cost {
                HStack {
                    if message.isUser { Spacer() }
                    Text("$\(cost, specifier: "%.4f")")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                    if !message.isUser { Spacer() }
                }
            }
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
    let id = UUID()
    let isUser: Bool
    var text: String
    var toolCalls: [ToolCall] = []
    var toolResults: [ToolResult] = []
    var thinking: String?
    var cost: Double?
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
