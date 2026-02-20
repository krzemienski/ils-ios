import Foundation
import Splash
import SwiftUI

/// Wrapper around Splash library for syntax highlighting code
enum SyntaxHighlighter {
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

        // Select appropriate grammar for the language
        let grammar = grammarForLanguage(language)
        let highlighter = Splash.SyntaxHighlighter(format: AttributedStringOutputFormat(), grammar: grammar)
        let attributedString = highlighter.highlight(code)
        return attributedString
    }

    /// Map language identifier to appropriate grammar
    private static func grammarForLanguage(_ language: String) -> Splash.Grammar {
        switch language {
        case "swift":
            return SwiftGrammar()
        case "python", "py":
            return PythonGrammar()
        case "javascript", "js":
            return JavaScriptGrammar()
        case "typescript", "ts":
            return TypeScriptGrammar()
        case "go", "golang":
            return GoGrammar()
        case "rust", "rs":
            return RustGrammar()
        case "java":
            return JavaGrammar()
        case "kotlin", "kt":
            return KotlinGrammar()
        case "c":
            return CGrammar()
        case "cpp", "c++":
            return CppGrammar()
        case "csharp", "cs", "c#":
            return CSharpGrammar()
        case "ruby", "rb":
            return RubyGrammar()
        case "php":
            return PHPGrammar()
        case "bash", "shell", "sh", "zsh":
            return BashGrammar()
        case "sql":
            return SQLGrammar()
        case "json":
            return JSONGrammar()
        case "yaml", "yml":
            return YAMLGrammar()
        case "html":
            return HTMLGrammar()
        case "css", "scss", "sass":
            return CSSGrammar()
        case "markdown", "md":
            return MarkdownGrammar()
        case "objective-c", "objc":
            return ObjectiveCGrammar()
        default:
            // For unknown languages, use a plain text grammar
            return PlainTextGrammar()
        }
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

// MARK: - Custom Language Grammars

/// Base helper functions for creating syntax rules
private extension Splash.Segment {
    func isNumber() -> Bool {
        let token = tokens.current.trimmingCharacters(in: .whitespaces)
        return !token.isEmpty && token.allSatisfy { $0.isNumber || $0 == "." || $0 == "_" }
    }
}

/// Python Grammar
private struct PythonGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("\"")
        set.remove("'")
        set.remove("#")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            PythonCommentRule(),
            PythonStringRule(),
            NumberRule(),
            PythonKeywordRule(),
            CallRule()
        ]
    }

    struct PythonCommentRule: SyntaxRule {
        var tokenType: TokenType { .comment }
        func matches(_ segment: Segment) -> Bool {
            return segment.tokens.current.hasPrefix("#") ||
                   segment.tokens.onSameLine.contains("#")
        }
    }

    struct PythonStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return token.hasPrefix("\"\"\"") || token.hasSuffix("\"\"\"") ||
                   token.hasPrefix("'''") || token.hasSuffix("'''") ||
                   (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("'") && token.hasSuffix("'"))
        }
    }

    struct PythonKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "def", "class", "if", "elif", "else", "for", "while", "return",
            "import", "from", "as", "try", "except", "finally", "with",
            "lambda", "yield", "pass", "break", "continue", "True", "False",
            "None", "and", "or", "not", "is", "in", "async", "await", "raise"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// JavaScript Grammar
private struct JavaScriptGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("$")
        set.remove("\"")
        set.remove("'")
        set.remove("`")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            CStyleCommentRule(),
            JavaScriptStringRule(),
            NumberRule(),
            JavaScriptKeywordRule(),
            CallRule()
        ]
    }

    struct JavaScriptStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("'") && token.hasSuffix("'")) ||
                   (token.hasPrefix("`") && token.hasSuffix("`"))
        }
    }

    struct JavaScriptKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "var", "let", "const", "function", "return", "if", "else",
            "for", "while", "switch", "case", "break", "continue",
            "class", "extends", "import", "export", "default", "async",
            "await", "try", "catch", "finally", "throw", "new", "this",
            "super", "static", "typeof", "instanceof", "delete", "in", "of"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// TypeScript Grammar (extends JavaScript)
private struct TypeScriptGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("$")
        set.remove("\"")
        set.remove("'")
        set.remove("`")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            CStyleCommentRule(),
            JavaScriptGrammar.JavaScriptStringRule(),
            NumberRule(),
            TypeScriptKeywordRule(),
            CallRule()
        ]
    }

    struct TypeScriptKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "var", "let", "const", "function", "return", "if", "else",
            "for", "while", "switch", "case", "break", "continue",
            "class", "extends", "implements", "interface", "type", "enum",
            "import", "export", "default", "async", "await", "try", "catch",
            "finally", "throw", "new", "this", "super", "static", "typeof",
            "instanceof", "delete", "in", "of", "as", "readonly", "public",
            "private", "protected", "abstract", "namespace", "module", "declare"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// Go Grammar
private struct GoGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("\"")
        set.remove("`")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            CStyleCommentRule(),
            GoStringRule(),
            NumberRule(),
            GoKeywordRule(),
            CallRule()
        ]
    }

    struct GoStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("`") && token.hasSuffix("`"))
        }
    }

    struct GoKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "func", "var", "const", "type", "struct", "interface", "if",
            "else", "for", "range", "return", "package", "import", "go",
            "defer", "chan", "select", "case", "default", "break",
            "continue", "fallthrough", "goto", "map", "make", "new",
            "true", "false", "nil"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// Rust Grammar
private struct RustGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("\"")
        set.remove("'")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            CStyleCommentRule(),
            RustStringRule(),
            NumberRule(),
            RustKeywordRule(),
            CallRule()
        ]
    }

    struct RustStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("'") && token.hasSuffix("'"))
        }
    }

    struct RustKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "fn", "let", "mut", "const", "static", "if", "else", "match",
            "for", "while", "loop", "return", "struct", "enum", "impl",
            "trait", "type", "use", "mod", "pub", "crate", "self", "Self",
            "super", "true", "false", "as", "break", "continue", "where",
            "unsafe", "async", "await", "move", "ref", "dyn"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// Java Grammar
private struct JavaGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("\"")
        set.remove("@")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            CStyleCommentRule(),
            JavaStringRule(),
            NumberRule(),
            JavaKeywordRule(),
            CallRule()
        ]
    }

    struct JavaStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("'") && token.hasSuffix("'"))
        }
    }

    struct JavaKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "class", "interface", "enum", "extends", "implements", "public",
            "private", "protected", "static", "final", "abstract",
            "synchronized", "volatile", "if", "else", "for", "while", "do",
            "switch", "case", "default", "break", "continue", "return",
            "try", "catch", "finally", "throw", "throws", "new", "this",
            "super", "void", "int", "long", "short", "byte", "float",
            "double", "char", "boolean", "true", "false", "null", "import",
            "package"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// Kotlin Grammar
private struct KotlinGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("\"")
        set.remove("@")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            CStyleCommentRule(),
            JavaGrammar.JavaStringRule(),
            NumberRule(),
            KotlinKeywordRule(),
            CallRule()
        ]
    }

    struct KotlinKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "fun", "val", "var", "class", "interface", "object", "if",
            "else", "when", "for", "while", "do", "return", "break",
            "continue", "try", "catch", "finally", "throw", "throws",
            "public", "private", "protected", "internal", "abstract",
            "final", "open", "override", "companion", "data", "sealed",
            "true", "false", "null", "is", "in", "as", "this", "super",
            "import", "package"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// C Grammar
private struct CGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("\"")
        set.remove("#")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            PreprocessorRule(),
            CStyleCommentRule(),
            CStringRule(),
            NumberRule(),
            CKeywordRule(),
            CallRule()
        ]
    }

    struct CStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("'") && token.hasSuffix("'"))
        }
    }

    struct CKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "int", "float", "double", "char", "void", "if", "else", "for",
            "while", "return", "struct", "typedef", "enum", "union", "const",
            "static", "extern", "auto", "register", "volatile", "sizeof",
            "switch", "case", "default", "break", "continue", "goto", "do",
            "unsigned", "signed", "long", "short"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// C++ Grammar
private struct CppGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("\"")
        set.remove("#")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            PreprocessorRule(),
            CStyleCommentRule(),
            CGrammar.CStringRule(),
            NumberRule(),
            CppKeywordRule(),
            CallRule()
        ]
    }

    struct CppKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "int", "float", "double", "char", "void", "bool", "if", "else",
            "for", "while", "return", "class", "struct", "typedef", "enum",
            "union", "const", "static", "extern", "auto", "register",
            "volatile", "sizeof", "switch", "case", "default", "break",
            "continue", "goto", "do", "namespace", "using", "public",
            "private", "protected", "virtual", "template", "typename",
            "try", "catch", "throw", "new", "delete", "this", "true",
            "false", "nullptr"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// C# Grammar
private struct CSharpGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("\"")
        set.remove("@")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            CStyleCommentRule(),
            CGrammar.CStringRule(),
            NumberRule(),
            CSharpKeywordRule(),
            CallRule()
        ]
    }

    struct CSharpKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "class", "struct", "interface", "enum", "namespace", "using",
            "public", "private", "protected", "internal", "static", "const",
            "readonly", "virtual", "override", "abstract", "sealed", "if",
            "else", "for", "foreach", "while", "do", "switch", "case",
            "default", "break", "continue", "return", "try", "catch",
            "finally", "throw", "new", "this", "base", "true", "false",
            "null", "var", "void", "int", "string", "bool", "async", "await"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// Ruby Grammar
private struct RubyGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("\"")
        set.remove("'")
        set.remove("#")
        set.remove("@")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            RubyCommentRule(),
            RubyStringRule(),
            NumberRule(),
            RubyKeywordRule(),
            CallRule()
        ]
    }

    struct RubyCommentRule: SyntaxRule {
        var tokenType: TokenType { .comment }
        func matches(_ segment: Segment) -> Bool {
            return segment.tokens.current.hasPrefix("#") ||
                   segment.tokens.onSameLine.contains("#")
        }
    }

    struct RubyStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("'") && token.hasSuffix("'"))
        }
    }

    struct RubyKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "def", "end", "class", "module", "if", "elsif", "else", "unless",
            "case", "when", "for", "while", "until", "return", "yield",
            "break", "next", "redo", "retry", "true", "false", "nil", "and",
            "or", "not", "do", "begin", "rescue", "ensure", "raise", "include",
            "extend", "require"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// PHP Grammar
private struct PHPGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("$")
        set.remove("\"")
        set.remove("'")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            CStyleCommentRule(),
            PHPCommentRule(),
            PHPStringRule(),
            NumberRule(),
            PHPKeywordRule(),
            CallRule()
        ]
    }

    struct PHPCommentRule: SyntaxRule {
        var tokenType: TokenType { .comment }
        func matches(_ segment: Segment) -> Bool {
            return segment.tokens.current.hasPrefix("#") ||
                   segment.tokens.onSameLine.contains("#")
        }
    }

    struct PHPStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("'") && token.hasSuffix("'"))
        }
    }

    struct PHPKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "function", "class", "interface", "trait", "extends", "implements",
            "public", "private", "protected", "static", "final", "abstract",
            "if", "else", "elseif", "for", "foreach", "while", "do", "switch",
            "case", "default", "break", "continue", "return", "try", "catch",
            "finally", "throw", "new", "this", "self", "parent", "var",
            "const", "echo", "print", "true", "false", "null", "array", "as",
            "namespace", "use"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// Bash Grammar
private struct BashGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("$")
        set.remove("\"")
        set.remove("'")
        set.remove("#")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            BashCommentRule(),
            BashStringRule(),
            NumberRule(),
            BashKeywordRule()
        ]
    }

    struct BashCommentRule: SyntaxRule {
        var tokenType: TokenType { .comment }
        func matches(_ segment: Segment) -> Bool {
            return segment.tokens.current.hasPrefix("#") ||
                   segment.tokens.onSameLine.contains("#")
        }
    }

    struct BashStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("'") && token.hasSuffix("'"))
        }
    }

    struct BashKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "if", "then", "else", "elif", "fi", "case", "esac", "for",
            "while", "until", "do", "done", "function", "in", "select"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// SQL Grammar
private struct SQLGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("\"")
        set.remove("'")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            SQLCommentRule(),
            SQLStringRule(),
            NumberRule(),
            SQLKeywordRule()
        ]
    }

    struct SQLCommentRule: SyntaxRule {
        var tokenType: TokenType { .comment }
        func matches(_ segment: Segment) -> Bool {
            return segment.tokens.current.hasPrefix("--") ||
                   segment.tokens.onSameLine.contains("--")
        }
    }

    struct SQLStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("'") && token.hasSuffix("'"))
        }
    }

    struct SQLKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE",
            "CREATE", "ALTER", "DROP", "TABLE", "INDEX", "VIEW", "JOIN",
            "INNER", "LEFT", "RIGHT", "OUTER", "ON", "AS", "AND", "OR",
            "NOT", "NULL", "IS", "IN", "LIKE", "BETWEEN", "ORDER", "BY",
            "GROUP", "HAVING", "LIMIT", "OFFSET", "UNION", "ALL", "DISTINCT"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current.uppercased())
        }
    }
}

/// JSON Grammar
private struct JSONGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("\"")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            JSONStringRule(),
            NumberRule(),
            JSONKeywordRule()
        ]
    }

    struct JSONStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return token.hasPrefix("\"") && token.hasSuffix("\"")
        }
    }

    struct JSONKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = ["true", "false", "null"]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// YAML Grammar
private struct YAMLGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("-")
        set.remove("\"")
        set.remove("'")
        set.remove("#")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            YAMLCommentRule(),
            YAMLStringRule(),
            NumberRule(),
            YAMLKeywordRule()
        ]
    }

    struct YAMLCommentRule: SyntaxRule {
        var tokenType: TokenType { .comment }
        func matches(_ segment: Segment) -> Bool {
            return segment.tokens.current.hasPrefix("#") ||
                   segment.tokens.onSameLine.contains("#")
        }
    }

    struct YAMLStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("'") && token.hasSuffix("'"))
        }
    }

    struct YAMLKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = ["true", "false", "null", "yes", "no"]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// HTML Grammar
private struct HTMLGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("-")
        set.remove("_")
        set.remove("\"")
        set.remove("'")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            HTMLCommentRule(),
            HTMLTagRule(),
            HTMLStringRule()
        ]
    }

    struct HTMLCommentRule: SyntaxRule {
        var tokenType: TokenType { .comment }
        func matches(_ segment: Segment) -> Bool {
            return segment.tokens.current.hasPrefix("<!--") ||
                   segment.tokens.current.hasSuffix("-->")
        }
    }

    struct HTMLTagRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return token.hasPrefix("<") || token.hasSuffix(">")
        }
    }

    struct HTMLStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("'") && token.hasSuffix("'"))
        }
    }
}

/// CSS Grammar
private struct CSSGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("-")
        set.remove("_")
        set.remove("#")
        set.remove(".")
        set.remove("\"")
        set.remove("'")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            CSSCommentRule(),
            CSSStringRule(),
            NumberRule(),
            CSSSelectorRule()
        ]
    }

    struct CSSCommentRule: SyntaxRule {
        var tokenType: TokenType { .comment }
        func matches(_ segment: Segment) -> Bool {
            return segment.tokens.current.hasPrefix("/*") ||
                   segment.tokens.current.hasSuffix("*/")
        }
    }

    struct CSSStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                   (token.hasPrefix("'") && token.hasSuffix("'"))
        }
    }

    struct CSSSelectorRule: SyntaxRule {
        var tokenType: TokenType { .type }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return token.hasPrefix("#") || token.hasPrefix(".")
        }
    }
}

/// Markdown Grammar
private struct MarkdownGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("#")
        set.remove("`")
        set.remove("*")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            MarkdownCodeRule(),
            MarkdownHeaderRule(),
            MarkdownBoldRule()
        ]
    }

    struct MarkdownCodeRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return token.hasPrefix("`") || token.hasSuffix("`")
        }
    }

    struct MarkdownHeaderRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        func matches(_ segment: Segment) -> Bool {
            return segment.tokens.current.hasPrefix("#")
        }
    }

    struct MarkdownBoldRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return token.hasPrefix("**") || token.hasPrefix("__")
        }
    }
}

/// Objective-C Grammar
private struct ObjectiveCGrammar: Grammar {
    var delimiters: CharacterSet = {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("@")
        set.remove("\"")
        set.remove("#")
        return set
    }()

    var syntaxRules: [SyntaxRule] {
        [
            PreprocessorRule(),
            CStyleCommentRule(),
            ObjectiveCStringRule(),
            NumberRule(),
            ObjectiveCKeywordRule(),
            CallRule()
        ]
    }

    struct ObjectiveCStringRule: SyntaxRule {
        var tokenType: TokenType { .string }
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            return token.hasPrefix("@\"") ||
                   (token.hasPrefix("\"") && token.hasSuffix("\""))
        }
    }

    struct ObjectiveCKeywordRule: SyntaxRule {
        var tokenType: TokenType { .keyword }
        let keywords: Set<String> = [
            "int", "float", "double", "char", "void", "BOOL", "YES", "NO",
            "nil", "if", "else", "for", "while", "return", "struct",
            "typedef", "enum", "const", "static", "extern", "switch",
            "case", "default", "break", "continue", "@interface",
            "@implementation", "@end", "@property", "@synthesize",
            "@protocol", "@class", "@selector", "@try", "@catch",
            "@finally", "@throw", "self", "super", "id", "instancetype"
        ]

        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
}

/// Plain Text Grammar (fallback for unknown languages)
private struct PlainTextGrammar: Grammar {
    var delimiters: CharacterSet = .alphanumerics.inverted
    var syntaxRules: [SyntaxRule] { [] }
}

// MARK: - Shared Syntax Rules

/// C-style comment rule (// and /* */)
private struct CStyleCommentRule: SyntaxRule {
    var tokenType: TokenType { .comment }

    func matches(_ segment: Segment) -> Bool {
        if segment.tokens.current.hasPrefix("/*") {
            return true
        }

        if segment.tokens.current.hasPrefix("//") {
            return true
        }

        if segment.tokens.onSameLine.contains("//") {
            return true
        }

        let multiLineStartCount = segment.tokens.count(of: "/*")
        return multiLineStartCount != segment.tokens.count(of: "*/")
    }
}

/// Preprocessor directive rule (#include, #define, etc.)
private struct PreprocessorRule: SyntaxRule {
    var tokenType: TokenType { .preprocessing }

    func matches(_ segment: Segment) -> Bool {
        return segment.tokens.current.hasPrefix("#")
    }
}

/// Generic number rule
private struct NumberRule: SyntaxRule {
    var tokenType: TokenType { .number }

    func matches(_ segment: Segment) -> Bool {
        let token = segment.tokens.current.trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        guard !token.isEmpty else { return false }
        guard let first = token.first else { return false }

        // Check if it's a number
        if first.isNumber {
            return true
        }

        // Handle decimal numbers like .5
        if first == ".", token.count > 1 {
            return token.dropFirst().allSatisfy { $0.isNumber }
        }

        return false
    }
}

/// Generic function call rule
private struct CallRule: SyntaxRule {
    var tokenType: TokenType { .call }

    func matches(_ segment: Segment) -> Bool {
        guard let first = segment.tokens.current.first else { return false }
        guard first.isLetter || first == "_" else { return false }

        return segment.tokens.next?.hasPrefix("(") ?? false
    }
}
