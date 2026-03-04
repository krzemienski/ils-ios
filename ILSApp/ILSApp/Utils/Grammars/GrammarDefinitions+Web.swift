import Foundation
import Splash

// MARK: - Web Language Grammar Configs
//
// Grammar configurations for web technologies: JavaScript, TypeScript, HTML, CSS.

// MARK: - Private Rule Types

/// HTML tag rule — matches opening/closing HTML tags.
private struct HTMLTagRule: SyntaxRule {
    var tokenType: TokenType { .keyword }

    func matches(_ segment: Segment) -> Bool {
        let token = segment.tokens.current
        return token.hasPrefix("<") || token.hasSuffix(">")
    }
}

/// CSS selector rule — matches class (`.foo`) and ID (`#bar`) selectors.
private struct CSSSelectorRule: SyntaxRule {
    var tokenType: TokenType { .type }

    func matches(_ segment: Segment) -> Bool {
        let token = segment.tokens.current
        return token.hasPrefix("#") || token.hasPrefix(".")
    }
}

// MARK: - GrammarConfig Web Extensions

extension GrammarConfig {

    // MARK: JavaScript

    static let javascript = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("$")
            set.remove("\"")
            set.remove("'")
            set.remove("`")
            return set
        }(),
        commentStyle: .cStyle,
        stringPairs: [
            ("\"", "\""),
            ("'", "'"),
            ("`", "`")
        ],
        keywords: [
            "var", "let", "const", "function", "return", "if", "else",
            "for", "while", "switch", "case", "break", "continue",
            "class", "extends", "import", "export", "default", "async",
            "await", "try", "catch", "finally", "throw", "new", "this",
            "super", "static", "typeof", "instanceof", "delete", "in", "of"
        ]
    )

    // MARK: TypeScript

    static let typescript = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("$")
            set.remove("\"")
            set.remove("'")
            set.remove("`")
            return set
        }(),
        commentStyle: .cStyle,
        stringPairs: [
            ("\"", "\""),
            ("'", "'"),
            ("`", "`")
        ],
        keywords: [
            "var", "let", "const", "function", "return", "if", "else",
            "for", "while", "switch", "case", "break", "continue",
            "class", "extends", "implements", "interface", "type", "enum",
            "import", "export", "default", "async", "await", "try", "catch",
            "finally", "throw", "new", "this", "super", "static", "typeof",
            "instanceof", "delete", "in", "of", "as", "readonly", "public",
            "private", "protected", "abstract", "namespace", "module", "declare"
        ]
    )

    // MARK: HTML

    static let html = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("-")
            set.remove("_")
            set.remove("\"")
            set.remove("'")
            return set
        }(),
        commentStyle: .html,
        stringPairs: [
            ("\"", "\""),
            ("'", "'")
        ],
        keywords: [],
        includeCallRule: false,
        includeNumberRule: false,
        extraRules: [HTMLTagRule()]
    )

    // MARK: CSS

    static let css = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("-")
            set.remove("_")
            set.remove("#")
            set.remove(".")
            set.remove("\"")
            set.remove("'")
            return set
        }(),
        commentStyle: .cssBlock,
        stringPairs: [
            ("\"", "\""),
            ("'", "'")
        ],
        keywords: [],
        includeCallRule: false,
        extraRules: [CSSSelectorRule()]
    )
}
