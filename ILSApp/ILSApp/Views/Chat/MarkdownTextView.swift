import SwiftUI
import MarkdownUI

/// Renders markdown text with proper formatting for chat messages.
/// Uses MarkdownUI for full GitHub Flavored Markdown support including
/// tables, blockquotes, horizontal rules, strikethrough, task lists, and nested lists.
struct MarkdownTextView: View {
    let text: String

    var body: some View {
        Markdown(text)
            .markdownTheme(.ilsChat)
            .markdownCodeSyntaxHighlighter(ILSCodeHighlighter())
            .textSelection(.enabled)
    }
}

// MARK: - ILS Chat Theme

extension Theme {
    static let ilsChat = Theme()
        .text {
            ForegroundColor(ILSTheme.textPrimary)
            FontSize(.em(1.0))
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.5))
                    ForegroundColor(ILSTheme.textPrimary)
                }
                .markdownMargin(top: 8, bottom: 4)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.3))
                    ForegroundColor(ILSTheme.textPrimary)
                }
                .markdownMargin(top: 8, bottom: 4)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.15))
                    ForegroundColor(ILSTheme.textPrimary)
                }
                .markdownMargin(top: 4, bottom: 4)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(ILSTheme.accent.opacity(0.6))
                    .frame(width: 3)
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(ILSTheme.textSecondary)
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
                .markdownTableBorderStyle(.init(color: ILSTheme.borderDefault))
                .markdownTableBackgroundStyle(.alternatingRows(ILSTheme.bg2, ILSTheme.bg1))
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
                .foregroundColor(configuration.isCompleted ? ILSTheme.success : ILSTheme.textTertiary)
                .font(.body)
        }
        .strikethrough {
            StrikethroughStyle(.init(pattern: .solid, color: .init(ILSTheme.textSecondary)))
        }
        .thematicBreak {
            Divider()
                .overlay(ILSTheme.borderDefault)
                .markdownMargin(top: 8, bottom: 8)
        }
        .link {
            ForegroundColor(ILSTheme.info)
        }
        .code {
            FontFamilyVariant(.monospaced)
            ForegroundColor(ILSTheme.accent)
            BackgroundColor(ILSTheme.bg3.opacity(0.5))
        }
}

// MARK: - ILSCodeHighlighter Stub (temporary - will be replaced in task 2.3)

/// Temporary stub for ILSCodeHighlighter
/// This will be replaced with a full implementation using HighlightSwift in task 2.3
struct ILSCodeHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        Text(code).font(.system(.body, design: .monospaced))
    }
}

#Preview {
    ScrollView {
        MarkdownTextView(text: """
        ## Getting Started

        Here's a **bold** statement and some *italic* text.

        Check out [SwiftUI docs](https://developer.apple.com/swiftui/) for more.

        ### Code Example

        ```swift
        func greet(_ name: String) -> String {
            return "Hello, \\(name)!"
        }
        ```

        Some features:

        - First item with `inline code`
        - Second item
        - Third **important** item

        1. Step one
        2. Step two
        3. Step three

        > This is a blockquote with some wisdom.

        | Column 1 | Column 2 |
        |----------|----------|
        | Cell A   | Cell B   |

        ---

        - [x] Completed task
        - [ ] Pending task

        Regular paragraph text with ~~strikethrough~~ continues here.
        """)
        .foregroundColor(ILSTheme.primaryText)
        .padding()
    }
    .background(Color.black)
}
