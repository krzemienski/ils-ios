import SwiftUI

/// Expandable accordion for displaying tool call details in chat messages.
/// Shows tool name with type-specific SF Symbol icon as header; expands to reveal input and output.
/// All colors from theme tokens via @Environment(\.theme).
struct ToolCallAccordion: View {
    let toolName: String
    let input: String?
    let inputPairs: [(key: String, value: String)]
    let output: String?
    let isError: Bool
    var expandAll: Binding<Bool?>?

    @State private var isExpanded = false
    @State private var showFullOutput = false

    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(toolName: String, input: String? = nil, inputPairs: [(key: String, value: String)] = [], output: String? = nil, isError: Bool = false, expandAll: Binding<Bool?>? = nil) {
        self.toolName = toolName
        self.input = input
        self.inputPairs = inputPairs
        self.output = output
        self.isError = isError
        self.expandAll = expandAll
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton
            if isExpanded {
                expandedContent
            }
        }
        .background(theme.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .strokeBorder(isError ? theme.error.opacity(0.5) : theme.borderSubtle, lineWidth: isError ? 1 : 0.5)
        )
        .onChange(of: expandAll?.wrappedValue) { _, newValue in
            if let newValue {
                if reduceMotion {
                    isExpanded = newValue
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = newValue
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tool call: \(toolName)\(isError ? ", error" : "")")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
    }

    // MARK: - Header

    private var headerButton: some View {
        Button {
            if reduceMotion {
                isExpanded.toggle()
                if let expandAll = expandAll {
                    expandAll.wrappedValue = isExpanded
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                    if let expandAll = expandAll {
                        expandAll.wrappedValue = isExpanded
                    }
                }
            }
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: toolIcon)
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(isError ? theme.error : toolColor)
                    .frame(width: 20)

                Text(toolName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if isError {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.error)
                } else if isExpanded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.success)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            if !inputPairs.isEmpty {
                inputSection(pairs: inputPairs)
            } else if let input, !input.isEmpty {
                inputTextSection(text: input)
            }

            if let output, !output.isEmpty {
                outputSection(text: output)
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.bottom, theme.spacingSM)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Input Section (Key-Value Pairs)

    private func inputSection(pairs: [(key: String, value: String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Input")

            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                HStack(alignment: .top, spacing: 4) {
                    Text(pair.key + ":")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.accent)
                    Text(pair.value)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .textSelection(.enabled)
                        .lineLimit(3)
                }
            }
        }
    }

    // MARK: - Input Section (Plain Text)

    private func inputTextSection(text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Input")

            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Output Section

    private func outputSection(text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Output")

            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isError ? theme.error : theme.textSecondary)
                .textSelection(.enabled)
                .lineLimit(showFullOutput ? nil : 5)

            if text.components(separatedBy: "\n").count > 5 {
                Button {
                    showFullOutput.toggle()
                } label: {
                    Text(showFullOutput ? "Show less" : "Show more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
    }

    /// Maps tool names to SF Symbol icons for all 10 Claude tool types.
    private var toolIcon: String {
        let name = toolName.lowercased()
        if name.contains("read") { return "doc.text" }
        if name.contains("write") { return "doc.badge.plus" }
        if name.contains("edit") { return "pencil.line" }
        if name.contains("bash") { return "terminal" }
        if name.contains("grep") { return "magnifyingglass" }
        if name.contains("glob") { return "folder.badge.questionmark" }
        if name.contains("websearch") || name == "web_search" { return "globe" }
        if name.contains("webfetch") || name == "web_fetch" { return "arrow.down.doc" }
        if name.contains("task") { return "person.2" }
        if name.contains("skill") { return "sparkles" }
        if name.contains("list") { return "list.bullet" }
        return "wrench.and.screwdriver"
    }

    /// Maps tool names to entity-derived colors for visual distinction.
    private var toolColor: Color {
        let name = toolName.lowercased()
        if name.contains("read") || name.contains("write") || name.contains("edit") {
            return theme.entitySkill
        }
        if name.contains("bash") {
            return theme.entitySystem
        }
        if name.contains("grep") || name.contains("glob") {
            return theme.entityMCP
        }
        if name.contains("web") {
            return theme.info
        }
        if name.contains("task") {
            return theme.entitySession
        }
        if name.contains("skill") {
            return theme.entityPlugin
        }
        return theme.accent
    }
}

#Preview {
    @Previewable @State var expandAllState: Bool?

    ScrollView {
        VStack(spacing: 12) {
            ToolCallAccordion(
                toolName: "Read",
                inputPairs: [("file_path", "/src/main.swift"), ("offset", "0"), ("limit", "100")],
                output: "import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        Text(\"Hello\")\n    }\n}",
                expandAll: $expandAllState
            )

            ToolCallAccordion(
                toolName: "Bash",
                input: "command: swift build",
                output: "Build complete! (0.45s)\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6\nLine 7\nLine 8\nLine 9\nLine 10",
                isError: false,
                expandAll: $expandAllState
            )

            ToolCallAccordion(
                toolName: "Write",
                inputPairs: [("file_path", "/src/error.swift"), ("content", "Invalid syntax")],
                output: "Error: file not found\nStack trace...\nLine 3\nLine 4\nLine 5\nLine 6\nLine 7",
                isError: true,
                expandAll: $expandAllState
            )

            ToolCallAccordion(
                toolName: "Grep",
                inputPairs: [("pattern", "TODO"), ("path", "/src")],
                output: "src/main.swift:42: // TODO: fix this"
            )

            ToolCallAccordion(
                toolName: "WebSearch",
                input: "query: SwiftUI best practices 2026",
                output: "Found 5 results..."
            )

            ToolCallAccordion(
                toolName: "Task",
                input: "Delegated to sub-agent: explore codebase",
                output: "Found 42 relevant files"
            )

            Button("Toggle Expand All") {
                expandAllState = !(expandAllState ?? false)
            }
        }
        .padding()
    }
    .background(Color.black)
}
