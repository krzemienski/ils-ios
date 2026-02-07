import SwiftUI
import MarkdownUI

/// Renders markdown text with proper formatting for chat messages.
/// Uses MarkdownUI for full GitHub Flavored Markdown support.
/// Theme colors are read from the environment for dynamic theming.
struct MarkdownTextView: View {
    let text: String

    @Environment(\.theme) private var theme: any AppTheme

    var body: some View {
        Markdown(text)
            .markdownTheme(chatTheme)
            .markdownCodeSyntaxHighlighter(ILSCodeHighlighter())
            .textSelection(.enabled)
    }

    /// Build a MarkdownUI theme dynamically from current AppTheme tokens.
    /// MarkdownUI Theme is a struct built via result builders, so we construct
    /// it using the current theme's colors.
    private var chatTheme: MarkdownUI.Theme {
        let t = theme
        return Theme()
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
                CodeBlockView(
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
