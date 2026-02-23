import SwiftUI

/// View that displays a code block with syntax highlighting, line numbers, and actions
struct CodeBlockView: View {
    let code: String
    let language: String?
    @State private var showCopyConfirmation = false
    @State private var isExpanded = true
    @State private var showShareSheet = false
    @State private var highlightedCode: AttributedString?
    /// Cached lines split from `code` — populated via `.task(id: code)`.
    @State private var cachedCodeLines: [String] = []
    /// Whether the code block should show expand/collapse — cached via `.task(id: code)`.
    @State private var cachedShouldBeCollapsible: Bool = false
    /// Lines currently visible (respects collapse state) — cached via `.task(id: code)` and `.onChange(of: isExpanded)`.
    @State private var cachedDisplayedLines: [String] = []
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Maximum number of lines to show when collapsed
    private let collapsedLineLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language badge and action buttons
            HStack {
                // Language badge
                if let language = language {
                    Text(language.uppercased())
                        .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                        .foregroundColor(theme.accent)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, theme.spacingXS)
                        .background(theme.accent.opacity(0.15))
                        .cornerRadius(theme.cornerRadiusSmall)
                        .accessibilityIdentifier("code-block-language-label")
                        .accessibilityLabel("Code language: \(language)")
                }

                Spacer()

                // Expand/Collapse button (only if collapsible)
                if cachedShouldBeCollapsible {
                    Button(action: {
                        if reduceMotion {
                            isExpanded.toggle()
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold, design: theme.fontDesign))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("code-block-expand-button")
                    .accessibilityLabel(isExpanded ? "Collapse code" : "Expand code")
                }

                // Copy button
                Button(action: {
                    #if os(iOS)
                    UIPasteboard.general.string = code
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    #else
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    #endif
                    showCopyConfirmation = true
                    // Hide confirmation after 2 seconds
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        showCopyConfirmation = false
                    }
                }) {
                    Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 15, weight: .medium, design: theme.fontDesign))
                        .foregroundColor(showCopyConfirmation ? theme.success : theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("code-block-copy-button")
                .accessibilityLabel("Copy code")

                // Share button
                Button(action: {
                    showShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium, design: theme.fontDesign))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("code-block-share-button")
                .accessibilityLabel("Share code")
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgTertiary.opacity(0.5))

            Divider()

            // Code content with line numbers
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers
                    // SPERF-MED-6: Use indices for stable ForEach identity.
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(cachedDisplayedLines.indices, id: \.self) { index in
                            Text("\(index + 1)")
                                .font(.system(.caption, design: theme.fontDesign))
                                .foregroundColor(theme.textTertiary)
                                .padding(.vertical, 2)
                                .frame(minWidth: 30, alignment: .trailing)
                        }

                        // Ellipsis indicator when collapsed
                        if cachedShouldBeCollapsible && !isExpanded {
                            Text("\u{22EE}")
                                .font(.system(.caption, design: theme.fontDesign))
                                .foregroundColor(theme.textTertiary)
                                .padding(.vertical, 2)
                                .frame(minWidth: 30, alignment: .trailing)
                        }
                    }
                    .padding(.trailing, theme.spacingSM)
                    .padding(.leading, theme.spacingSM)
                    .accessibilityHidden(true) // Line numbers are visual only

                    // Separator
                    Rectangle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 1)
                        .accessibilityHidden(true)

                    // Code text with syntax highlighting (cached via @State + .task(id:))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(highlightedCode ?? AttributedString(cachedDisplayedLines.joined(separator: "\n")))
                            .textSelection(.enabled)
                            .padding(.leading, theme.spacingSM)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("code-block-content")
                    .accessibilityLabel(accessibilityCodeLabel)
                }
                .padding(.vertical, theme.spacingSM)
            }
            .background(theme.bgTertiary)
        }
        .cornerRadius(theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .strokeBorder(theme.textTertiary.opacity(0.2), lineWidth: 1)
        )
        .accessibilityIdentifier("code-block-container")
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [code])
        }
        .task(id: code) {
            let lines = code.components(separatedBy: .newlines)
            cachedCodeLines = lines
            cachedShouldBeCollapsible = lines.count > 10
            if cachedShouldBeCollapsible && !isExpanded {
                cachedDisplayedLines = Array(lines.prefix(collapsedLineLimit))
            } else {
                cachedDisplayedLines = lines
            }
            highlightedCode = SyntaxHighlighter.highlight(
                code: cachedDisplayedLines.joined(separator: "\n"),
                language: language
            )
        }
        .onChange(of: isExpanded) { _, expanded in
            if cachedShouldBeCollapsible && !expanded {
                cachedDisplayedLines = Array(cachedCodeLines.prefix(collapsedLineLimit))
            } else {
                cachedDisplayedLines = cachedCodeLines
            }
            highlightedCode = SyntaxHighlighter.highlight(
                code: cachedDisplayedLines.joined(separator: "\n"),
                language: language
            )
        }
    }

    /// Accessibility label for the code content
    private var accessibilityCodeLabel: String {
        var label = "Code block"
        if let language = language {
            label += " in \(language)"
        }
        label += ", \(cachedCodeLines.count) lines"
        if cachedShouldBeCollapsible && !isExpanded {
            label += ", showing first \(collapsedLineLimit) lines"
        }
        return label
    }
}


// MARK: - Preview

#Preview("Swift Code Block") {
    VStack {
        CodeBlockView(
            code: """
            func greet(name: String) -> String {
                return "Hello, \\(name)!"
            }

            let message = greet(name: "World")
            print(message)
            """,
            language: "swift"
        )

        CodeBlockView(
            code: """
            def fibonacci(n):
                if n <= 1:
                    return n
                return fibonacci(n-1) + fibonacci(n-2)

            # Calculate first 10 Fibonacci numbers
            for i in range(10):
                print(fibonacci(i))
            """,
            language: "python"
        )
    }
    .padding()
}

#Preview("Long Code Block (Collapsed)") {
    CodeBlockView(
        code: """
        import SwiftUI

        struct ContentView: View {
            @State private var counter = 0

            var body: some View {
                VStack {
                    Text("Count: \\(counter)")
                    Button("Increment") {
                        counter += 1
                    }
                    Button("Decrement") {
                        counter -= 1
                    }
                    Button("Reset") {
                        counter = 0
                    }
                }
            }
        }
        """,
        language: "swift"
    )
    .padding()
}

#Preview("Code Without Language") {
    CodeBlockView(
        code: """
        This is some code
        without a specific language
        specified
        """,
        language: nil
    )
    .padding()
}
