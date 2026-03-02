import SwiftUI
import HighlightSwift

// MARK: - PreferenceKeys

private struct CodeContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CodeViewWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CodeScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Renders a fenced code block with language header, grammar-aware syntax highlighting,
/// optional line numbers, and copy button. All colors from theme tokens.
struct ThemedCodeBlockView: View {
    let language: String?
    let code: String
    @State private var showCopied = false
    @State private var highlightedCode: AttributedString?
    @State private var detectedLanguage: String?
    @State private var isExpanded = false
    @State private var contentWidth: CGFloat = 0
    @State private var viewWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var zoomFontSize: CGFloat = 13
    @GestureState private var magnifyBy: CGFloat = 0
    @AppStorage("codeblock.lineNumbers") private var showLineNumbers: Bool = false
    @State private var showFullScreen = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            codeContent
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .strokeBorder(theme.borderSubtle, lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Code block, \(detectedLanguage ?? language ?? "code")")
        .task(id: theme.isLight) {
            await performHighlight(isLight: theme.isLight)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showFullScreen) {
            CodeBlockFullScreenView(
                language: detectedLanguage ?? language,
                code: code,
                highlightedCode: highlightedCode
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        #endif
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(detectedLanguage ?? language ?? "code")
                .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Spacer()

            Button(action: { showLineNumbers.toggle() }) {
                Image(systemName: "list.number")
                    .font(.system(size: 13, design: theme.fontDesign))
                    .foregroundStyle(showLineNumbers ? theme.accent : theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showLineNumbers ? "Hide line numbers" : "Show line numbers")
            .accessibilityIdentifier("code-block-line-numbers-toggle")

            #if os(iOS)
            Button(action: { showFullScreen = true }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Expand code block to full screen")
            .accessibilityIdentifier("code-block-expand-button")

            Button(action: { Task { await shareCode() } }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share code as image")
            .accessibilityIdentifier("code-block-share-button")
            #endif

            Button(action: copyCode) {
                HStack(spacing: 4) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    Text(showCopied ? "Copied" : "Copy")
                        .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                }
                .foregroundStyle(showCopied ? theme.success : theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showCopied ? "Code copied to clipboard" : "Copy code to clipboard")
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, 6)
        .background(theme.bgTertiary)
    }

    // MARK: - Code Content

    private var codeContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            codeText
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: CodeContentWidthKey.self, value: geo.size.width)
                            .preference(key: CodeScrollOffsetKey.self,
                                        value: geo.frame(in: .named("hCodeScroll")).minX)
                    }
                )
        }
        .coordinateSpace(name: "hCodeScroll")
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: CodeViewWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(CodeContentWidthKey.self) { contentWidth = $0 }
        .onPreferenceChange(CodeViewWidthKey.self) { viewWidth = $0 }
        .onPreferenceChange(CodeScrollOffsetKey.self) { scrollOffset = -$0 }
        .frame(maxHeight: isExpanded ? .infinity : 300)
        .background(theme.bgTertiary)
        .overlay(alignment: .trailing) {
            scrollGradientOverlay
        }
        .overlay(alignment: .bottom) {
            if !isExpanded && lineCount > 15 {
                Button {
                    if reduceMotion {
                        isExpanded = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded = true
                        }
                    }
                } label: {
                    Text("Show more (\(lineCount) lines)")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingXS)
                        .background(
                            LinearGradient(
                                colors: [theme.bgTertiary.opacity(0), theme.bgTertiary],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
        }
        .simultaneousGesture(
            MagnificationGesture()
                .updating($magnifyBy) { value, state, _ in
                    state = (value - 1.0) * zoomFontSize
                }
                .onEnded { value in
                    zoomFontSize = min(max(zoomFontSize * value, 10), 28)
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    zoomFontSize = 13
                }
        )
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

    // MARK: - Code Text

    private var effectiveFontSize: CGFloat {
        min(max(zoomFontSize + magnifyBy, 10), 28)
    }

    private var codeLines: [String] {
        code.components(separatedBy: "\n")
    }

    private var lineNumbersColumn: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(codeLines.enumerated()), id: \.offset) { index, _ in
                Text("\(index + 1)")
                    .font(.system(size: effectiveFontSize, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.vertical, 2)
                    .frame(minWidth: 30, alignment: .trailing)
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingSM)
        .accessibilityHidden(true)
    }

    private var codeText: some View {
        HStack(alignment: .top, spacing: 0) {
            if showLineNumbers {
                lineNumbersColumn
                Rectangle()
                    .fill(theme.textTertiary.opacity(0.3))
                    .frame(width: 1)
                    .accessibilityHidden(true)
            }

            Group {
                if let highlighted = highlightedCode {
                    Text(highlighted)
                        .font(.system(size: effectiveFontSize, design: theme.fontDesign))
                        .textSelection(.enabled)
                } else {
                    Text(code)
                        .font(.system(size: effectiveFontSize, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                }
            }
            .padding(theme.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("code-block-content")
            .accessibilityLabel("Code: \(code)")
        }
    }

    // MARK: - Helpers

    private var lineCount: Int {
        max(codeLines.count, 1)
    }

    // MARK: - Highlighting

    private func performHighlight(isLight: Bool = false) async {
        let highlight = Highlight()
        do {
            let mode: HighlightMode
            if let lang = language, !lang.isEmpty {
                mode = .languageAlias(lang)
            } else {
                mode = .automatic
            }
            let colors: HighlightColors = isLight ? .light(.xcode) : .dark(.xcode)
            let result = try await highlight.request(code, mode: mode, colors: colors)
            self.highlightedCode = result.attributedText
            if language == nil || language?.isEmpty == true {
                self.detectedLanguage = result.languageName
            }
        } catch {
            // Fallback: unhighlighted code already displayed
        }
    }

    // MARK: - Actions

    private func copyCode() {
        #if os(iOS)
        UIPasteboard.general.string = code
        HapticManager.notification(.success)
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif
        showCopied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showCopied = false
        }
    }

    #if os(iOS)
    private func shareCode() async {
        let snapshot = CodeBlockShareSnapshotView(
            language: detectedLanguage ?? language,
            code: code,
            highlightedCode: highlightedCode,
            theme: theme
        )
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: 360, height: nil)
        guard let uiImage = renderer.uiImage else { return }
        shareItems = [uiImage]
        showShareSheet = true
    }
    #endif
}

// MARK: - Share Snapshot View

#if os(iOS)
/// Static snapshot of a code block used as the source for sharing as an image.
/// Renders the same code block layout without interactive controls.
private struct CodeBlockShareSnapshotView: View {
    let language: String?
    let code: String
    let highlightedCode: AttributedString?
    let theme: ThemeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language ?? "code")
                    .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, 6)
            .background(theme.bgTertiary)

            Group {
                if let highlighted = highlightedCode {
                    Text(highlighted)
                        .font(.system(size: 13, design: theme.fontDesign))
                } else {
                    Text(code)
                        .font(.system(size: 13, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                }
            }
            .padding(theme.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.bgTertiary)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .strokeBorder(theme.borderSubtle, lineWidth: 0.5)
        )
        .padding()
        .background(theme.bgPrimary)
    }
}
#endif

// MARK: - Full Screen View

#if os(iOS)
/// Full-screen presentation of a code block with horizontal scrolling,
/// zoom gesture support, and copy/dismiss toolbar buttons.
struct CodeBlockFullScreenView: View {
    let language: String?
    let code: String
    let highlightedCode: AttributedString?

    @State private var showCopied = false
    @State private var zoomFontSize: CGFloat = 13
    @GestureState private var magnifyBy: CGFloat = 0
    @AppStorage("codeblock.lineNumbers") private var showLineNumbers: Bool = false
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                codeText
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.bgTertiary)
            .navigationTitle(language ?? "code")
            .inlineNavigationBarTitle()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .accessibilityLabel("Dismiss full screen code viewer")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: copyCode) {
                        HStack(spacing: 4) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            Text(showCopied ? "Copied" : "Copy")
                                .font(.system(size: 13, weight: .medium, design: theme.fontDesign))
                        }
                        .foregroundStyle(showCopied ? theme.success : theme.accent)
                    }
                    .accessibilityLabel(showCopied ? "Code copied to clipboard" : "Copy code to clipboard")
                }
            }
        }
        .simultaneousGesture(
            MagnificationGesture()
                .updating($magnifyBy) { value, state, _ in
                    state = (value - 1.0) * zoomFontSize
                }
                .onEnded { value in
                    zoomFontSize = min(max(zoomFontSize * value, 10), 28)
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    zoomFontSize = 13
                }
        )
    }

    // MARK: - Code Text

    private var effectiveFontSize: CGFloat {
        min(max(zoomFontSize + magnifyBy, 10), 28)
    }

    private var codeLines: [String] {
        code.components(separatedBy: "\n")
    }

    private var lineNumbersColumn: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(codeLines.enumerated()), id: \.offset) { index, _ in
                Text("\(index + 1)")
                    .font(.system(size: effectiveFontSize, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.vertical, 2)
                    .frame(minWidth: 30, alignment: .trailing)
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingSM)
        .accessibilityHidden(true)
    }

    private var codeText: some View {
        HStack(alignment: .top, spacing: 0) {
            if showLineNumbers {
                lineNumbersColumn
                Rectangle()
                    .fill(theme.textTertiary.opacity(0.3))
                    .frame(width: 1)
                    .accessibilityHidden(true)
            }

            Group {
                if let highlighted = highlightedCode {
                    Text(highlighted)
                        .font(.system(size: effectiveFontSize, design: theme.fontDesign))
                        .textSelection(.enabled)
                } else {
                    Text(code)
                        .font(.system(size: effectiveFontSize, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                }
            }
            .padding(theme.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("code-block-fullscreen-content")
            .accessibilityLabel("Code: \(code)")
        }
    }

    // MARK: - Actions

    private func copyCode() {
        UIPasteboard.general.string = code
        HapticManager.notification(.success)
        showCopied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showCopied = false
        }
    }
}
#endif
