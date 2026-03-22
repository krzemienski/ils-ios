import SwiftUI

/// View that displays a code block with syntax highlighting, line numbers, and actions
struct CodeBlockView: View {
    let code: String
    let language: String?
    @State private var showCopyConfirmation = false
    @State private var isExpanded = true
    @State private var showShareSheet = false
    @State private var highlightedCode: AttributedString
    @State private var contentWidth: CGFloat = 0
    @State private var viewWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // PERF-CB: Reference LowPowerModeMonitor so SwiftUI tracks isLowPowerModeEnabled changes.
    private var lowPowerMonitor: LowPowerModeMonitor { LowPowerModeMonitor.shared }

    init(code: String, language: String?) {
        self.code = code
        self.language = language
        _highlightedCode = State(initialValue: AttributedString(code))
    }

    /// Maximum number of lines to show when collapsed
    private let collapsedLineLimit = 3

    /// Split code into lines for line numbering
    private var codeLines: [String] {
        code.components(separatedBy: .newlines)
    }

    /// Whether the code block should be collapsible (more than 10 lines)
    private var shouldBeCollapsible: Bool {
        codeLines.count > 10
    }

    /// Lines to display based on expanded state
    private var displayedLines: [String] {
        if shouldBeCollapsible && !isExpanded {
            return Array(codeLines.prefix(collapsedLineLimit))
        }
        return codeLines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language badge and action buttons
            HStack {
                // Language badge
                if let language = language {
                    Text(language.uppercased())
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
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
                if shouldBeCollapsible {
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
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointerHover()
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
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundColor(showCopyConfirmation ? theme.success : theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerHover()
                .accessibilityIdentifier("code-block-copy-button")
                .accessibilityLabel(showCopyConfirmation ? "Copied to clipboard" : "Copy code")
                .accessibilityHint("Copies the code to your clipboard")

                // Share button
                Button(action: {
                    showShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerHover()
                .accessibilityIdentifier("code-block-share-button")
                .accessibilityLabel("Share code")
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgTertiary.opacity(0.5))

            Divider()

            // Code content with line numbers
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(Array(displayedLines.enumerated()), id: \.offset) { index, _ in
                            Text("\(index + 1)")
                                .font(.system(.caption, design: theme.fontDesign))
                                .foregroundColor(theme.textTertiary)
                                .padding(.vertical, 2)
                                .frame(minWidth: 30, alignment: .trailing)
                        }

                        // Ellipsis indicator when collapsed
                        if shouldBeCollapsible && !isExpanded {
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

                    // Code text with syntax highlighting (cached — only recomputed when code/language changes)
                    // PERF-CB: .drawingGroup() composites the attributed-string Text into a single CALayer,
                    // reducing per-frame CPU cost during chat scroll. Skipped in Low Power Mode to avoid
                    // the upfront GPU rasterisation cost when the device is conserving energy.
                    codeContentView
                        .drawingGroupIfEnabled(!lowPowerMonitor.isLowPowerModeEnabled)
                }
                .padding(.vertical, theme.spacingSM)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
                    contentWidth = width
                }
                .onGeometryChange(for: CGFloat.self, of: { $0.frame(in: .named("hCodeScrollCB")).minX }) { minX in
                    scrollOffset = -minX
                }
            }
            .coordinateSpace(name: "hCodeScrollCB")
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
                viewWidth = width
            }
            .background(theme.bgTertiary)
            .overlay(alignment: .trailing) {
                scrollGradientOverlay
            }
        }
        .cornerRadius(theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .strokeBorder(theme.textTertiary.opacity(0.2), lineWidth: 1)
        )
        .accessibilityIdentifier("code-block-container")
        .task(id: "\(code.hashValue)-\(language ?? "")-\(theme.id)") {
            let colors = theme.syntaxColors
            highlightedCode = await Task.detached(priority: .userInitiated) {
                SyntaxHighlighter.highlight(code: code, language: language, colors: colors)
            }.value
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [code])
        }
    }

    // MARK: - Code Content View

    /// Attributed-string rendering area. Extracted so `.drawingGroup()` can be applied conditionally.
    @ViewBuilder
    private var codeContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(highlightedCode)
                .lineLimit(shouldBeCollapsible && !isExpanded ? collapsedLineLimit : nil)
                .textSelection(.enabled)
                .padding(.leading, theme.spacingSM)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("code-block-content")
        .accessibilityLabel(accessibilityCodeLabel)
    }

    // MARK: - Scroll Gradient Overlay

    @ViewBuilder
    private var scrollGradientOverlay: some View {
        if shouldShowScrollIndicator {
            LinearGradient(
                colors: [theme.bgTertiary.opacity(0), theme.bgTertiary.opacity(0.85)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 32)
            .allowsHitTesting(false)
        }
    }

    private var shouldShowScrollIndicator: Bool {
        guard contentWidth > viewWidth else { return false }
        let remainingScroll = contentWidth - viewWidth - scrollOffset
        return remainingScroll > 1
    }

    /// Accessibility label for the code content
    private var accessibilityCodeLabel: String {
        var label = "Code block"
        if let language = language {
            label += " in \(language)"
        }
        label += ", \(codeLines.count) lines"
        if shouldBeCollapsible && !isExpanded {
            label += ", showing first \(collapsedLineLimit) lines"
        }
        return label
    }
}


// MARK: - View+DrawingGroup Helpers

private extension View {
    /// Applies `.drawingGroup()` only when `enabled` is true, allowing callers to skip
    /// GPU rasterisation in Low Power Mode or other battery-sensitive contexts.
    @ViewBuilder
    func drawingGroupIfEnabled(_ enabled: Bool) -> some View {
        if enabled {
            self.drawingGroup()
        } else {
            self
        }
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
