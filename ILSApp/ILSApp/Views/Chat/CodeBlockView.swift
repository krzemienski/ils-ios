import SwiftUI

/// A view that displays a code block with syntax highlighting and line numbers
struct CodeBlockView: View {
    let codeBlock: CodeBlock
    @State private var showLineNumbers: Bool = true
    @State private var showCopyConfirmation = false
    @State private var showShareSheet = false
    @State private var isExpanded: Bool

    /// Syntax highlighter instance
    private let highlighter = SyntaxHighlighter()

    /// Number of lines to show when collapsed
    private let previewLineCount = 3

    /// Threshold for collapsible behavior
    private let collapsibleThreshold = 10

    /// Detected language for this code block
    private var language: SyntaxHighlighter.Language? {
        SyntaxHighlighter.Language.detect(from: codeBlock.language)
    }

    /// Lines of code split for line numbering
    private var codeLines: [String] {
        codeBlock.code.components(separatedBy: .newlines)
    }

    /// Whether this code block should be collapsible
    private var isCollapsible: Bool {
        codeLines.count > collapsibleThreshold
    }

    /// Lines to display (all lines if expanded or not collapsible, preview lines if collapsed)
    private var displayedLines: Range<Int> {
        if isCollapsible && !isExpanded {
            return 0..<min(previewLineCount, codeLines.count)
        }
        return 0..<codeLines.count
    }

    init(codeBlock: CodeBlock) {
        self.codeBlock = codeBlock
        // Start collapsed if code block is longer than threshold
        let lines = codeBlock.code.components(separatedBy: .newlines)
        _isExpanded = State(initialValue: lines.count <= collapsibleThreshold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and actions
            HStack {
                // Language badge
                if let language = language {
                    Text(language.displayName.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(ILSTheme.accent)
                        .padding(.horizontal, ILSTheme.spacingS)
                        .padding(.vertical, ILSTheme.spacingXS)
                        .background(ILSTheme.accent.opacity(0.1))
                        .cornerRadius(ILSTheme.cornerRadiusS)
                        .accessibilityIdentifier("code-block-language-label")
                }

                // Expand/collapse button for long code blocks
                if isCollapsible {
                    Button(action: { isExpanded.toggle() }) {
                        HStack(spacing: ILSTheme.spacingXS) {
                            Text(isExpanded ? "Collapse" : "Expand")
                                .font(ILSTheme.captionFont)
                                .foregroundColor(ILSTheme.secondaryText)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Collapse code" : "Expand code")
                    .accessibilityIdentifier("code-block-expand-button")
                }

                Spacer()

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
                    .accessibilityHidden(true)
                }

                // Action buttons
                HStack(spacing: ILSTheme.spacingXS) {
                    // Copy button
                    Button(action: copyCode) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy code")
                    .accessibilityIdentifier("code-block-copy-button")

                    // Share button
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share code")
                    .accessibilityIdentifier("code-block-share-button")
                }
            }
            .padding(.horizontal, ILSTheme.spacingS)
            .padding(.vertical, ILSTheme.spacingXS)
            .background(ILSTheme.tertiaryBackground.opacity(0.5))

            // Code content with optional line numbers
            HStack(alignment: .top, spacing: ILSTheme.spacingS) {
                // Line numbers (if enabled)
                if showLineNumbers {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(displayedLines, id: \.self) { index in
                            Text("\(index + 1)")
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.tertiaryText)
                                .frame(minWidth: lineNumberWidth)
                                .accessibilityHidden(true)
                        }

                        // Ellipsis for collapsed state
                        if isCollapsible && !isExpanded {
                            Text("⋮")
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.tertiaryText)
                                .frame(minWidth: lineNumberWidth)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.trailing, ILSTheme.spacingXS)

                    // Separator line
                    Rectangle()
                        .fill(ILSTheme.tertiaryText.opacity(0.3))
                        .frame(width: 1)
                        .accessibilityHidden(true)
                }

                // Syntax-highlighted code
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(displayedLines, id: \.self) { index in
                            Text(attributedLine(at: index))
                                .font(ILSTheme.codeFont)
                                .textSelection(.enabled)
                        }

                        // Ellipsis indicator for collapsed state
                        if isCollapsible && !isExpanded {
                            Text("⋮")
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.tertiaryText)
                                .padding(.vertical, ILSTheme.spacingXS)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityIdentifier("code-block-content")
                .accessibilityLabel(accessibilityCodeLabel)
            }
            .padding(ILSTheme.spacingS)
            .background(ILSTheme.tertiaryBackground)
            .cornerRadius(ILSTheme.cornerRadiusM)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("code-block-container")
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [codeBlock.code])
        }
    }

    // MARK: - Actions

    /// Copy code to clipboard with haptic feedback and confirmation
    private func copyCode() {
        UIPasteboard.general.string = codeBlock.code

        // Haptic feedback on copy
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation {
            showCopyConfirmation = true
        }

        // Hide confirmation after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopyConfirmation = false
            }
        }
    }

    // MARK: - Private Helpers

    /// Calculate the width needed for line numbers based on total line count
    private var lineNumberWidth: CGFloat {
        let digits = String(codeLines.count).count
        return CGFloat(digits) * 10 + 4
    }

    /// Get syntax-highlighted attributed string for a specific line
    /// - Parameter index: The line index
    /// - Returns: AttributedString with syntax highlighting
    private func attributedLine(at index: Int) -> AttributedString {
        guard index < codeLines.count else {
            return AttributedString("")
        }

        let line = codeLines[index]

        // For empty lines, return a space to maintain vertical spacing
        if line.isEmpty {
            return AttributedString(" ")
        }

        // Highlight the entire code block once and cache it would be more efficient,
        // but for simplicity we'll highlight line by line
        let highlightedLine = highlighter.highlight(line, language: language)
        return AttributedString(highlightedLine)
    }

    /// Accessibility label describing the code block
    private var accessibilityCodeLabel: String {
        let languageName = language?.displayName ?? "code"
        let lineCount = codeLines.count
        return "\(languageName) code block with \(lineCount) line\(lineCount == 1 ? "" : "s")"
    }
}

// MARK: - ShareSheet Helper

/// UIActivityViewController wrapper for SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

#Preview("Swift Code") {
    let swiftCode = """
    func greet(name: String) -> String {
        let greeting = "Hello, \\(name)!"
        return greeting
    }
    """

    let codeBlock = CodeBlock(
        language: "swift",
        code: swiftCode,
        range: swiftCode.startIndex..<swiftCode.endIndex
    )

    MessageView(
        message: ChatMessage(
            id: UUID(),
            isUser: false,
            text: "Here's a Swift function:",
            timestamp: Date()
        )
    )
    .padding()
}

#Preview("Python Code") {
    let pythonCode = """
    def calculate_sum(numbers):
        total = 0
        for num in numbers:
            total += num
        return total
    """

    let codeBlock = CodeBlock(
        language: "python",
        code: pythonCode,
        range: pythonCode.startIndex..<pythonCode.endIndex
    )

    return CodeBlockView(codeBlock: codeBlock)
        .padding()
}

#Preview("JavaScript Code") {
    let jsCode = """
    const fetchData = async (url) => {
        try {
            const response = await fetch(url);
            const data = await response.json();
            return data;
        } catch (error) {
            console.error('Error:', error);
        }
    };
    """

    let codeBlock = CodeBlock(
        language: "javascript",
        code: jsCode,
        range: jsCode.startIndex..<jsCode.endIndex
    )

    return CodeBlockView(codeBlock: codeBlock)
        .padding()
}

#Preview("No Language Specified") {
    let plainCode = """
    This is some code
    without a specific language
    so it gets basic highlighting
    """

    let codeBlock = CodeBlock(
        language: nil,
        code: plainCode,
        range: plainCode.startIndex..<plainCode.endIndex
    )

    return CodeBlockView(codeBlock: codeBlock)
        .padding()
}

#Preview("Long Code Block - Collapsible") {
    let longCode = """
    func processData(items: [String]) -> [String] {
        var processed: [String] = []

        for item in items {
            let cleaned = item.trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty {
                processed.append(cleaned.uppercased())
            }
        }

        return processed.sorted()
    }

    func validateInput(_ input: String) -> Bool {
        guard !input.isEmpty else { return false }
        return input.count >= 3
    }
    """

    let codeBlock = CodeBlock(
        language: "swift",
        code: longCode,
        range: longCode.startIndex..<longCode.endIndex
    )

    return CodeBlockView(codeBlock: codeBlock)
        .padding()
}
