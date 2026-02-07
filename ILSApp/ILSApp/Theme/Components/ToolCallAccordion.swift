import SwiftUI

/// Expandable accordion for displaying tool call details in chat messages.
/// Shows tool name with icon as header; expands to reveal input and output.
struct ToolCallAccordion: View {
    let toolName: String
    let input: String?
    let output: String?
    let isError: Bool

    @State private var isExpanded = false

    /// Dark background for the accordion
    private let accordionBg = Color(red: 17.0/255.0, green: 24.0/255.0, blue: 39.0/255.0)
    /// Border color
    private let borderColor = Color.white.opacity(0.06)

    init(toolName: String, input: String? = nil, output: String? = nil, isError: Bool = false) {
        self.toolName = toolName
        self.input = input
        self.output = output
        self.isError = isError
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
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
                    if let input, !input.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Input")
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundColor(ILSTheme.textTertiary)
                                .textCase(.uppercase)

                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(input)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(ILSTheme.textSecondary)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 120)
                        }
                    }

                    if let output, !output.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output")
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundColor(ILSTheme.textTertiary)
                                .textCase(.uppercase)

                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(output)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(isError ? ILSTheme.error : ILSTheme.textSecondary)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 200)
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
                .strokeBorder(borderColor, lineWidth: 1)
        )
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
    VStack(spacing: 12) {
        ToolCallAccordion(
            toolName: "Read",
            input: "file_path: /src/main.swift",
            output: "import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        Text(\"Hello\")\n    }\n}"
        )

        ToolCallAccordion(
            toolName: "Bash",
            input: "command: swift build",
            output: "Build complete! (0.45s)",
            isError: false
        )

        ToolCallAccordion(
            toolName: "Write",
            input: "file_path: /src/error.swift",
            output: "Error: file not found",
            isError: true
        )
    }
    .padding()
    .background(Color.black)
}
