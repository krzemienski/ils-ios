import SwiftUI
import MarkdownUI

/// Intentional passthrough highlighter for inline code spans in MarkdownUI.
///
/// Inline code uses system monospaced font without syntax coloring. This is intentional:
/// the `CodeSyntaxHighlighter` protocol is synchronous (`-> Text`), so it cannot
/// use `@Environment(\.theme)` or perform async work.
///
/// Fenced code blocks are handled by `CodeBlockView` which provides full async syntax
/// highlighting via the Highlight framework with proper theme integration.
struct ILSCodeHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        Text(code)
            .font(.system(.body, design: .monospaced))
    }
}

extension CodeSyntaxHighlighter where Self == ILSCodeHighlighter {
    static var ils: Self { ILSCodeHighlighter() }
}
