import Foundation
import Splash
import SwiftUI

/// Wrapper around Splash library for syntax highlighting code
enum SyntaxHighlighter {
    /// Shared output format instance (stateless, safe to reuse)
    private static let outputFormat = AttributedStringOutputFormat()

    /// Cache of highlighters keyed by language to avoid per-call allocation.
    /// `nonisolated(unsafe)` is safe here because:
    /// - Dictionary reads/writes happen only on @MainActor (SwiftUI rendering)
    /// - Splash.SyntaxHighlighter is a struct, so values are copied on read
    nonisolated(unsafe) private static var highlighterCache: [String: Splash.SyntaxHighlighter<AttributedStringOutputFormat>] = [:]

    /// Highlight code with syntax colors using Splash
    /// - Parameters:
    ///   - code: The code string to highlight
    ///   - language: Optional language identifier (e.g., "swift", "python", "javascript")
    /// - Returns: AttributedString with syntax highlighting applied
    static func highlight(code: String, language: String?) -> AttributedString {
        guard let language = language?.lowercased() else {
            // No language specified, return plain monospace text
            return plainMonospace(code)
        }

        // Reuse cached highlighter for this language to avoid per-call allocation
        let highlighter: Splash.SyntaxHighlighter<AttributedStringOutputFormat>
        if let cached = highlighterCache[language] {
            highlighter = cached
        } else {
            let grammar = grammarForLanguage(language)
            highlighter = Splash.SyntaxHighlighter(format: outputFormat, grammar: grammar)
            highlighterCache[language] = highlighter
        }

        return highlighter.highlight(code)
    }

    /// Map language identifier to appropriate grammar
    private static func grammarForLanguage(_ language: String) -> Splash.Grammar {
        return GrammarRegistry.grammar(for: language)
    }

    /// Return plain monospace text
    private static func plainMonospace(_ code: String) -> AttributedString {
        var attributedString = AttributedString(code)
        attributedString.font = .system(.body, design: .monospaced)
        attributedString.foregroundColor = SwiftUI.Color.primary
        return attributedString
    }
}

/// Custom output format for Splash that generates AttributedString
private struct AttributedStringOutputFormat: OutputFormat {
    func makeBuilder() -> Builder {
        Builder()
    }

    struct Builder: OutputBuilder {
        private var components: [(text: String, token: Splash.TokenType?)] = []

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
                return SwiftUI.Color(red: 0.9, green: 0.2, blue: 0.5) // Pink
            case .string:
                return SwiftUI.Color(red: 0.9, green: 0.3, blue: 0.2) // Red
            case .type:
                return SwiftUI.Color(red: 0.4, green: 0.6, blue: 0.9) // Blue
            case .call:
                return SwiftUI.Color(red: 0.3, green: 0.7, blue: 0.5) // Green
            case .number:
                return SwiftUI.Color(red: 0.7, green: 0.4, blue: 0.9) // Purple
            case .comment:
                return SwiftUI.Color(red: 0.5, green: 0.5, blue: 0.5) // Gray
            case .property:
                return SwiftUI.Color(red: 0.3, green: 0.7, blue: 0.8) // Cyan
            case .dotAccess:
                return SwiftUI.Color(red: 0.5, green: 0.5, blue: 0.5) // Gray
            case .preprocessing:
                return SwiftUI.Color(red: 0.9, green: 0.6, blue: 0.2) // Orange
            case .custom:
                return SwiftUI.Color.primary
            @unknown default:
                return SwiftUI.Color.primary
            }
        }
    }
}

