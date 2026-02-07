import SwiftUI

/// Expandable accordion for displaying tool call details in chat messages.
/// Shows tool name with icon as header; expands to reveal input and output.
struct ToolCallAccordion: View {
    let toolName: String
    let input: String?
    let inputPairs: [(key: String, value: String)]
    let output: String?
    let isError: Bool
    var expandAll: Binding<Bool?>?

    @State private var isExpanded = false
    @State private var showFullOutput = false

    /// Dark background for the accordion
    private let accordionBg = Color(red: 17.0/255.0, green: 24.0/255.0, blue: 39.0/255.0)
    /// Border color
    private let borderColor = Color.white.opacity(0.06)

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
            // Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                    if let expandAll = expandAll {
                        expandAll.wrappedValue = isExpanded
                    }
                }
            }) {
                HStack(spacing: ILSTheme.spacingS) {
                    Image(systemName: toolIcon)
                        .font(.system(.caption, weight: .medium))
                        .foregroundColor(isError ? ILSTheme.error : ILSTheme.accent)
                        .frame(width: 20)

                    Text(toolName)
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundColor(ILSTheme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(ILSTheme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, ILSTheme.spacingS)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
                    if !inputPairs.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Input")
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundColor(ILSTheme.textTertiary)
                                .textCase(.uppercase)

                            ForEach(Array(inputPairs.enumerated()), id: \.offset) { _, pair in
                                HStack(alignment: .top, spacing: 4) {
                                    Text(pair.key + ":")
                                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                                        .foregroundColor(ILSTheme.accent)
                                    Text(pair.value)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(ILSTheme.textSecondary)
                                        .textSelection(.enabled)
                                        .lineLimit(3)
                                }
                            }
                        }
                    } else if let input, !input.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Input")
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundColor(ILSTheme.textTertiary)
                                .textCase(.uppercase)

                            Text(input)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(ILSTheme.textSecondary)
                                .textSelection(.enabled)
                        }
                    }

                    if let output, !output.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output")
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundColor(ILSTheme.textTertiary)
                                .textCase(.uppercase)

                            Text(output)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(isError ? ILSTheme.error : ILSTheme.textSecondary)
                                .textSelection(.enabled)
                                .lineLimit(showFullOutput ? nil : 5)

                            if output.components(separatedBy: "\n").count > 5 {
                                Button(action: { showFullOutput.toggle() }) {
                                    Text(showFullOutput ? "Show less" : "Show more")
                                        .font(.system(.caption2, weight: .medium))
                                        .foregroundColor(ILSTheme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, ILSTheme.spacingS)
                .padding(.bottom, ILSTheme.spacingS)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(accordionBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isError ? ILSTheme.error.opacity(0.5) : borderColor, lineWidth: isError ? 2 : 1)
        )
        .onChange(of: expandAll?.wrappedValue) { _, newValue in
            if let newValue {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = newValue
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tool call: \(toolName)\(isError ? ", error" : "")")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
    }

    private var toolIcon: String {
        let name = toolName.lowercased()
        if name.contains("read") { return "doc.text" }
        if name.contains("write") || name.contains("edit") { return "pencil" }
        if name.contains("bash") || name.contains("terminal") { return "terminal" }
        if name.contains("search") || name.contains("grep") || name.contains("glob") { return "magnifyingglass" }
        if name.contains("web") || name.contains("fetch") { return "globe" }
        if name.contains("list") { return "list.bullet" }
        return "wrench.and.screwdriver"
    }
}

#Preview {
    @Previewable @State var expandAllState: Bool? = nil

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

        Button("Toggle Expand All") {
            expandAllState = !(expandAllState ?? false)
        }
    }
    .padding()
    .background(Color.black)
}
