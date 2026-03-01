import Foundation

// MARK: - Systems & JVM Language Grammar Configs

extension GrammarConfig {

    // MARK: C

    static let c = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("\"")
            set.remove("#")
            return set
        }(),
        commentStyle: .cStyle,
        stringPairs: [
            ("\"", "\""),
            ("'", "'")
        ],
        keywords: [
            "int", "float", "double", "char", "void", "if", "else", "for",
            "while", "return", "struct", "typedef", "enum", "union", "const",
            "static", "extern", "auto", "register", "volatile", "sizeof",
            "switch", "case", "default", "break", "continue", "goto", "do",
            "unsigned", "signed", "long", "short"
        ],
        includePreprocessor: true
    )

    // MARK: C++

    static let cpp = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("\"")
            set.remove("#")
            return set
        }(),
        commentStyle: .cStyle,
        stringPairs: [
            ("\"", "\""),
            ("'", "'")
        ],
        keywords: [
            "int", "float", "double", "char", "void", "bool", "if", "else",
            "for", "while", "return", "class", "struct", "typedef", "enum",
            "union", "const", "static", "extern", "auto", "register",
            "volatile", "sizeof", "switch", "case", "default", "break",
            "continue", "goto", "do", "namespace", "using", "public",
            "private", "protected", "virtual", "template", "typename",
            "try", "catch", "throw", "new", "delete", "this", "true",
            "false", "nullptr"
        ],
        includePreprocessor: true
    )

    // MARK: C#

    static let csharp = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("\"")
            set.remove("@")
            return set
        }(),
        commentStyle: .cStyle,
        stringPairs: [
            ("\"", "\""),
            ("'", "'")
        ],
        keywords: [
            "class", "struct", "interface", "enum", "namespace", "using",
            "public", "private", "protected", "internal", "static", "const",
            "readonly", "virtual", "override", "abstract", "sealed", "if",
            "else", "for", "foreach", "while", "do", "switch", "case",
            "default", "break", "continue", "return", "try", "catch",
            "finally", "throw", "new", "this", "base", "true", "false",
            "null", "var", "void", "int", "string", "bool", "async", "await"
        ]
    )

    // MARK: Rust

    static let rust = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("\"")
            set.remove("'")
            return set
        }(),
        commentStyle: .cStyle,
        stringPairs: [
            ("\"", "\""),
            ("'", "'")
        ],
        keywords: [
            "fn", "let", "mut", "const", "static", "if", "else", "match",
            "for", "while", "loop", "return", "struct", "enum", "impl",
            "trait", "type", "use", "mod", "pub", "crate", "self", "Self",
            "super", "true", "false", "as", "break", "continue", "where",
            "unsafe", "async", "await", "move", "ref", "dyn"
        ]
    )

    // MARK: Go

    static let go = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("\"")
            set.remove("`")
            return set
        }(),
        commentStyle: .cStyle,
        stringPairs: [
            ("\"", "\""),
            ("`", "`")
        ],
        keywords: [
            "func", "var", "const", "type", "struct", "interface", "if",
            "else", "for", "range", "return", "package", "import", "go",
            "defer", "chan", "select", "case", "default", "break",
            "continue", "fallthrough", "goto", "map", "make", "new",
            "true", "false", "nil"
        ]
    )

    // MARK: Java

    static let java = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("\"")
            set.remove("@")
            return set
        }(),
        commentStyle: .cStyle,
        stringPairs: [
            ("\"", "\""),
            ("'", "'")
        ],
        keywords: [
            "class", "interface", "enum", "extends", "implements", "public",
            "private", "protected", "static", "final", "abstract",
            "synchronized", "volatile", "if", "else", "for", "while", "do",
            "switch", "case", "default", "break", "continue", "return",
            "try", "catch", "finally", "throw", "throws", "new", "this",
            "super", "void", "int", "long", "short", "byte", "float",
            "double", "char", "boolean", "true", "false", "null", "import",
            "package"
        ]
    )

    // MARK: Kotlin

    static let kotlin = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("\"")
            set.remove("@")
            return set
        }(),
        commentStyle: .cStyle,
        stringPairs: [
            ("\"", "\""),
            ("'", "'")
        ],
        keywords: [
            "fun", "val", "var", "class", "interface", "object", "if",
            "else", "when", "for", "while", "do", "return", "break",
            "continue", "try", "catch", "finally", "throw", "throws",
            "public", "private", "protected", "internal", "abstract",
            "final", "open", "override", "companion", "data", "sealed",
            "true", "false", "null", "is", "in", "as", "this", "super",
            "import", "package"
        ]
    )
}
