import SwiftUI
import MarkdownUI

/// Bridges MarkdownUI's code syntax highlighting protocol to ILS theme colors.
///
/// The `CodeSyntaxHighlighter` protocol is synchronous (`-> Text`), so it cannot
/// use `@Environment(\.theme)`. Uses system monospaced font with primary text color.
/// Fenced code blocks are rendered by `CodeBlockView` which does use theme tokens.
struct ILSCodeHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        Text(code)
            .font(.system(.body, design: .monospaced))
    }
}

extension CodeSyntaxHighlighter where Self == ILSCodeHighlighter {
    static var ils: Self { ILSCodeHighlighter() }
}
