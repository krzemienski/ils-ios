import Foundation
import Splash

// MARK: - Private Rule Types for HTML, CSS, and Markdown

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

/// Markdown inline-code rule — matches tokens wrapped in backticks.
private struct MarkdownCodeRule: SyntaxRule {
    var tokenType: TokenType { .string }

    func matches(_ segment: Segment) -> Bool {
        let token = segment.tokens.current
        return token.hasPrefix("`") || token.hasSuffix("`")
    }
}

/// Markdown heading rule — matches `#`-prefixed heading tokens.
private struct MarkdownHeaderRule: SyntaxRule {
    var tokenType: TokenType { .keyword }

    func matches(_ segment: Segment) -> Bool {
        return segment.tokens.current.hasPrefix("#")
    }
}

/// Markdown bold/emphasis rule — matches `**` or `__` prefixed tokens.
private struct MarkdownBoldRule: SyntaxRule {
    var tokenType: TokenType { .keyword }

    func matches(_ segment: Segment) -> Bool {
        let token = segment.tokens.current
        return token.hasPrefix("**") || token.hasPrefix("__")
    }
}

// MARK: - GrammarConfig Static Definitions

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

    // MARK: SQL

    static let sql = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("\"")
            set.remove("'")
            return set
        }(),
        commentStyle: .sql,
        stringPairs: [
            ("\"", "\""),
            ("'", "'")
        ],
        keywords: [
            "SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE",
            "CREATE", "ALTER", "DROP", "TABLE", "INDEX", "VIEW", "JOIN",
            "INNER", "LEFT", "RIGHT", "OUTER", "ON", "AS", "AND", "OR",
            "NOT", "NULL", "IS", "IN", "LIKE", "BETWEEN", "ORDER", "BY",
            "GROUP", "HAVING", "LIMIT", "OFFSET", "UNION", "ALL", "DISTINCT"
        ],
        keywordCaseSensitive: false,
        includeCallRule: false
    )

    // MARK: JSON

    static let json = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("\"")
            return set
        }(),
        commentStyle: .none,
        stringPairs: [
            ("\"", "\"")
        ],
        keywords: ["true", "false", "null"],
        includeCallRule: false
    )

    // MARK: YAML

    static let yaml = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("-")
            set.remove("\"")
            set.remove("'")
            set.remove("#")
            return set
        }(),
        commentStyle: .hash,
        stringPairs: [
            ("\"", "\""),
            ("'", "'")
        ],
        keywords: ["true", "false", "null", "yes", "no"],
        includeCallRule: false
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

    // MARK: Markdown

    static let markdown = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("#")
            set.remove("`")
            set.remove("*")
            return set
        }(),
        commentStyle: .none,
        stringPairs: [],
        keywords: [],
        includeCallRule: false,
        includeNumberRule: false,
        extraRules: [
            MarkdownCodeRule(),
            MarkdownHeaderRule(),
            MarkdownBoldRule()
        ]
    )

    // MARK: Objective-C

    static let objectiveC = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("@")
            set.remove("\"")
            set.remove("#")
            return set
        }(),
        commentStyle: .cStyle,
        stringPairs: [
            ("@\"", "\""),
            ("\"", "\"")
        ],
        keywords: [
            "int", "float", "double", "char", "void", "BOOL", "YES", "NO",
            "nil", "if", "else", "for", "while", "return", "struct",
            "typedef", "enum", "const", "static", "extern", "switch",
            "case", "default", "break", "continue", "@interface",
            "@implementation", "@end", "@property", "@synthesize",
            "@protocol", "@class", "@selector", "@try", "@catch",
            "@finally", "@throw", "self", "super", "id", "instancetype"
        ],
        includePreprocessor: true
    )

    // MARK: Plain Text (fallback for unknown languages)

    static let plainText = GrammarConfig(
        delimiters: .alphanumerics.inverted,
        commentStyle: .none,
        stringPairs: [],
        keywords: [],
        includeCallRule: false,
        includeNumberRule: false
    )
}
