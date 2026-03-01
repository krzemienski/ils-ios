import SwiftUI
import MarkdownUI

/// Renders markdown text with proper formatting for chat messages.
/// Uses MarkdownUI for full GitHub Flavored Markdown support.
/// Theme colors are read from the environment for dynamic theming.
struct MarkdownTextView: View {
    let text: String

    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Global cache: theme ID → built MarkdownUI.Theme, shared across all instances.
    /// Building the 90-line Theme struct is expensive; caching eliminates redundant
    /// rebuilds when the same theme is applied to many chat-message views.
    /// nonisolated(unsafe) is required because MarkdownUI.Theme is non-Sendable and
    /// we access it from the MainActor without wanting actor hops.
    nonisolated(unsafe) private static var themeCache: [String: MarkdownUI.Theme] = [:]

    /// Per-instance mirrors of the shared cache entry — drive SwiftUI re-render.
    @State private var cachedTheme: MarkdownUI.Theme = .basic
    @State private var cachedThemeId: String = ""

    var body: some View {
        Markdown(text)
            .markdownTheme(cachedTheme)
            .markdownCodeSyntaxHighlighter(ILSCodeHighlighter())
            .textSelection(.enabled)
            .onChange(of: theme.id, initial: true) {
                guard theme.id != cachedThemeId else { return }
                cachedThemeId = theme.id
                if let cached = Self.themeCache[theme.id] {
                    cachedTheme = cached
                } else {
                    let built = Self.buildChatTheme(from: theme)
                    Self.themeCache[theme.id] = built
                    cachedTheme = built
                }
            }
    }

    /// Build a MarkdownUI theme dynamically from current AppTheme tokens.
    /// MarkdownUI Theme is a struct built via result builders, so we construct
    /// it using the current theme's colors. Only called when theme.id changes
    /// and the result is not already in the global cache.
    private static func buildChatTheme(from t: ThemeSnapshot) -> MarkdownUI.Theme {
        Theme()
            .text {
                ForegroundColor(t.textPrimary)
                FontSize(.em(1.0))
            }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.5))
                        ForegroundColor(t.textPrimary)
                    }
                    .markdownMargin(top: 8, bottom: 4)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.3))
                        ForegroundColor(t.textPrimary)
                    }
                    .markdownMargin(top: 8, bottom: 4)
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.15))
                        ForegroundColor(t.textPrimary)
                    }
                    .markdownMargin(top: 4, bottom: 4)
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(t.accent.opacity(0.6))
                        .frame(width: 3)
                    configuration.label
                        .markdownTextStyle {
                            ForegroundColor(t.textSecondary)
                        }
                        .padding(.leading, 12)
                }
                .markdownMargin(top: 4, bottom: 4)
            }
            .codeBlock { configuration in
                ThemedCodeBlockView(
                    language: configuration.language,
                    code: configuration.content
                )
                .markdownMargin(top: 4, bottom: 4)
            }
            .table { configuration in
                configuration.label
                    .markdownTableBorderStyle(.init(color: t.border))
                    .markdownTableBackgroundStyle(.alternatingRows(t.bgSecondary, t.bgPrimary))
                    .markdownMargin(top: 4, bottom: 4)
            }
            .paragraph { configuration in
                configuration.label
                    .markdownMargin(top: 2, bottom: 2)
            }
            .listItem { configuration in
                configuration.label
                    .markdownMargin(top: 1, bottom: 1)
            }
            .taskListMarker { configuration in
                Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isCompleted ? t.success : t.textTertiary)
                    .font(.body)
            }
            .strikethrough {
                StrikethroughStyle(.init(pattern: .solid, color: .init(t.textSecondary)))
            }
            .thematicBreak {
                Divider()
                    .overlay(t.divider)
                    .markdownMargin(top: 8, bottom: 8)
            }
            .link {
                ForegroundColor(t.info)
            }
            .code {
                FontFamilyVariant(.monospaced)
                ForegroundColor(t.accent)
                BackgroundColor(t.bgTertiary.opacity(0.5))
            }
    }
}
