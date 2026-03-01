import Foundation
import Splash

// MARK: - Data & Markup Language Grammar Configs
//
// Grammar configurations for data formats and markup languages:
// JSON, YAML, SQL, Markdown, Objective-C, and plain text fallback.

// MARK: - Private Rule Types

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

// MARK: - GrammarConfig Data Extensions

extension GrammarConfig {

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
