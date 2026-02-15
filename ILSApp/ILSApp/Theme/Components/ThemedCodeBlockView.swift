import SwiftUI
import HighlightSwift

/// Renders a fenced code block with language header, grammar-aware syntax highlighting,
/// optional line numbers, and copy button. All colors from theme tokens.
struct ThemedCodeBlockView: View {
    let language: String?
    let code: String
    @State private var showCopied = false
    @State private var highlightedCode: AttributedString?
    @State private var detectedLanguage: String?
    @State private var isExpanded = false

    @Environment(\.theme) private var theme: any AppTheme
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
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(detectedLanguage ?? language ?? "code")
                .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Spacer()

            Button(action: copyCode) {
                HStack(spacing: 4) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, design: theme.fontDesign))
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
        }
        .frame(maxHeight: isExpanded ? .infinity : 300)
        .background(theme.bgTertiary)
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
    }

    private var codeText: some View {
        Group {
            if let highlighted = highlightedCode {
                Text(highlighted)
                    .font(.system(size: 13, design: theme.fontDesign))
                    .textSelection(.enabled)
            } else {
                Text(code)
                    .font(.system(size: 13, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
            }
        }
        .padding(theme.spacingSM)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var lineCount: Int {
        max(code.components(separatedBy: "\n").count, 1)
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
}
