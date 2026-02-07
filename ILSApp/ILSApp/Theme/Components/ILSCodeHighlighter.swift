import SwiftUI
import MarkdownUI

/// Bridges MarkdownUI's code syntax highlighting protocol to ILS theme colors.
///
/// The `CodeSyntaxHighlighter` protocol is synchronous (`-> Text`), so full
/// grammar-aware highlighting via HighlightSwift isn't possible here. Instead,
/// this provides styled monospaced text for inline code spans. Fenced code blocks
/// are rendered by `CodeBlockView` via the `.codeBlock` theme configuration,
/// which uses HighlightSwift's async API with `.task`.
struct ILSCodeHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        Text(code)
            .font(ILSTheme.codeFont)
            .foregroundColor(ILSTheme.textPrimary)
    }
}

extension CodeSyntaxHighlighter where Self == ILSCodeHighlighter {
    static var ils: Self { ILSCodeHighlighter() }
}
