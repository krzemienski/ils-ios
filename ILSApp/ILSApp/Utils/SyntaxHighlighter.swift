import Foundation
import os
import Splash
import SwiftUI

/// Wrapper around Splash library for syntax highlighting code.
/// Nonisolated with OSAllocatedUnfairLock-protected cache so highlighting
/// can run on background threads via Task.detached without blocking the main thread.
enum SyntaxHighlighter {
    /// Fallback colors matching original hardcoded values, used when no theme colors are provided.
    private static let defaultColors = SyntaxColors(
        keyword: SwiftUI.Color(red: 0.9, green: 0.2, blue: 0.5),
        string: SwiftUI.Color(red: 0.9, green: 0.3, blue: 0.2),
        type: SwiftUI.Color(red: 0.4, green: 0.6, blue: 0.9),
        call: SwiftUI.Color(red: 0.3, green: 0.7, blue: 0.5),
        number: SwiftUI.Color(red: 0.7, green: 0.4, blue: 0.9),
        comment: SwiftUI.Color(red: 0.5, green: 0.5, blue: 0.5),
        property: SwiftUI.Color(red: 0.3, green: 0.7, blue: 0.8),
        preprocessing: SwiftUI.Color(red: 0.9, green: 0.6, blue: 0.2)
    )

    /// Sendable box around a Splash.Grammar existential so it can be stored in
    /// OSAllocatedUnfairLock without triggering strict-concurrency diagnostics.
    /// Safe because the grammar is written once at creation time and never mutated.
    private final class GrammarBox: @unchecked Sendable {
        let grammar: Splash.Grammar
        init(_ grammar: Splash.Grammar) { self.grammar = grammar }
    }

    /// Cache of grammars keyed by language to avoid per-call DataDrivenGrammar allocation.
    /// Protected by OSAllocatedUnfairLock for thread-safe access from any thread.
    private static let cacheLock = OSAllocatedUnfairLock(
        initialState: [String: GrammarBox]()
    )

    /// Highlight code with theme-aware syntax colors using Splash.
    /// - Parameters:
    ///   - code: The code string to highlight.
    ///   - language: Optional language identifier (e.g., "swift", "python", "javascript").
    ///   - colors: Theme-aware syntax highlighting colors. Defaults to built-in dark palette.
    /// - Returns: AttributedString with syntax highlighting applied.
    static func highlight(
        code: String,
        language: String?,
        colors: SyntaxColors = defaultColors
    ) -> AttributedString {
        guard let language = language?.lowercased() else {
            // No language specified, return plain monospace text
            return plainMonospace(code)
        }

        // Get or create grammar under the lock, then highlight OUTSIDE the lock
        // (highlighting is the expensive part and should not hold the lock)
        let grammarBox = cacheLock.withLock { cache -> GrammarBox in
            if let cached = cache[language] { return cached }
            let box = GrammarBox(grammarForLanguage(language))
            cache[language] = box
            return box
        }

        // Build a fresh format with the current theme colors for each call.
        // Grammars are reused; only the color-bearing format is recreated.
        let format = AttributedStringOutputFormat(colors: colors)
        let highlighter = Splash.SyntaxHighlighter(format: format, grammar: grammarBox.grammar)
        return highlighter.highlight(code)
    }

    /// Map language identifier to appropriate grammar.
    private static func grammarForLanguage(_ language: String) -> Splash.Grammar {
        return GrammarRegistry.grammar(for: language)
    }

    /// Return plain monospace text.
    private static func plainMonospace(_ code: String) -> AttributedString {
        var attributedString = AttributedString(code)
        attributedString.font = .system(.body, design: .monospaced)
        attributedString.foregroundColor = SwiftUI.Color.primary
        return attributedString
    }
}

/// Custom output format for Splash that generates AttributedString with theme-aware colors.
private struct AttributedStringOutputFormat: OutputFormat {
    let colors: SyntaxColors

    func makeBuilder() -> Builder {
        Builder(colors: colors)
    }

    struct Builder: OutputBuilder {
        let colors: SyntaxColors

        // SPERF-HIGH: Pre-allocate for typical code blocks
        private var components: [(text: String, token: Splash.TokenType?)]

        init(colors: SyntaxColors) {
            self.colors = colors
            var arr = [(text: String, token: Splash.TokenType?)]()
            arr.reserveCapacity(256)
            self.components = arr
        }

        mutating func addToken(_ token: String, ofType type: Splash.TokenType) {
            components.append((token, type))
        }

        mutating func addPlainText(_ text: String) {
            components.append((text, nil))
        }

        mutating func addWhitespace(_ whitespace: String) {
            components.append((whitespace, nil))
        }

        func build() -> AttributedString {
            var result = AttributedString()

            for component in components {
                var segment = AttributedString(component.text)
                segment.font = .system(.body, design: .monospaced)

                // Apply color based on token type
                if let tokenType = component.token {
                    segment.foregroundColor = colorForTokenType(tokenType)
                }

                result.append(segment)
            }

            return result
        }

        private func colorForTokenType(_ type: Splash.TokenType) -> SwiftUI.Color {
            switch type {
            case .keyword:
                return colors.keyword
            case .string:
                return colors.string
            case .type:
                return colors.type
            case .call:
                return colors.call
            case .number:
                return colors.number
            case .comment:
                return colors.comment
            case .property:
                return colors.property
            case .dotAccess:
                return colors.comment // muted, same as comments
            case .preprocessing:
                return colors.preprocessing
            case .custom:
                return SwiftUI.Color.primary
            @unknown default:
                return SwiftUI.Color.primary
            }
        }
    }
}
