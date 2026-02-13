import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Syntax highlighter with multi-language support
/// Provides syntax highlighting for 20+ programming languages using pattern-based tokenization
public struct SyntaxHighlighter {

    /// Supported programming languages
    public enum Language: String, CaseIterable {
        case swift
        case python
        case javascript
        case typescript
        case java
        case kotlin
        case go
        case rust
        case c
        case cpp
        case csharp
        case php
        case ruby
        case perl
        case bash
        case shell
        case sql
        case html
        case css
        case json
        case yaml
        case markdown
        case xml
        case plaintext

        /// Detect language from string identifier
        /// - Parameter identifier: Language identifier (e.g., "swift", "py", "js")
        /// - Returns: Detected language or nil if not recognized
        public static func detect(from identifier: String?) -> Language? {
            guard let identifier = identifier?.lowercased() else {
                return nil
            }

            // Direct matches
            if let language = Language(rawValue: identifier) {
                return language
            }

            // Common aliases
            switch identifier {
            case "py", "python3":
                return .python
            case "js", "node":
                return .javascript
            case "ts":
                return .typescript
            case "c++", "cplusplus":
                return .cpp
            case "c#", "cs":
                return .csharp
            case "sh", "zsh", "fish":
                return .shell
            case "yml":
                return .yaml
            case "htm":
                return .html
            case "rb":
                return .ruby
            case "pl":
                return .perl
            case "rs":
                return .rust
            case "md":
                return .markdown
            case "txt", "text":
                return .plaintext
            default:
                return nil
            }
        }

        /// Display name for the language
        public var displayName: String {
            switch self {
            case .swift: return "Swift"
            case .python: return "Python"
            case .javascript: return "JavaScript"
            case .typescript: return "TypeScript"
            case .java: return "Java"
            case .kotlin: return "Kotlin"
            case .go: return "Go"
            case .rust: return "Rust"
            case .c: return "C"
            case .cpp: return "C++"
            case .csharp: return "C#"
            case .php: return "PHP"
            case .ruby: return "Ruby"
            case .perl: return "Perl"
            case .bash: return "Bash"
            case .shell: return "Shell"
            case .sql: return "SQL"
            case .html: return "HTML"
            case .css: return "CSS"
            case .json: return "JSON"
            case .yaml: return "YAML"
            case .markdown: return "Markdown"
            case .xml: return "XML"
            case .plaintext: return "Plain Text"
            }
        }
    }

    /// Color theme for syntax highlighting
    public struct Theme {
        #if canImport(UIKit)
        public let plainText: UIColor
        public let keyword: UIColor
        public let type: UIColor
        public let string: UIColor
        public let number: UIColor
        public let comment: UIColor
        public let property: UIColor
        public let dotAccess: UIColor
        public let preprocessing: UIColor

        public init(
            plainText: UIColor = .label,
            keyword: UIColor = .systemPink,
            type: UIColor = .systemPurple,
            string: UIColor = .systemRed,
            number: UIColor = .systemBlue,
            comment: UIColor = .systemGreen,
            property: UIColor = .systemTeal,
            dotAccess: UIColor = .systemGray,
            preprocessing: UIColor = .systemOrange
        ) {
            self.plainText = plainText
            self.keyword = keyword
            self.type = type
            self.string = string
            self.number = number
            self.comment = comment
            self.property = property
            self.dotAccess = dotAccess
            self.preprocessing = preprocessing
        }
        #elseif canImport(AppKit)
        public let plainText: NSColor
        public let keyword: NSColor
        public let type: NSColor
        public let string: NSColor
        public let number: NSColor
        public let comment: NSColor
        public let property: NSColor
        public let dotAccess: NSColor
        public let preprocessing: NSColor

        public init(
            plainText: NSColor = .labelColor,
            keyword: NSColor = .systemPink,
            type: NSColor = .systemPurple,
            string: NSColor = .systemRed,
            number: NSColor = .systemBlue,
            comment: NSColor = .systemGreen,
            property: NSColor = .systemTeal,
            dotAccess: NSColor = .systemGray,
            preprocessing: NSColor = .systemOrange
        ) {
            self.plainText = plainText
            self.keyword = keyword
            self.type = type
            self.string = string
            self.number = number
            self.comment = comment
            self.property = property
            self.dotAccess = dotAccess
            self.preprocessing = preprocessing
        }
        #endif

        /// Default theme using system colors
        public static let `default` = Theme()
    }

    private let theme: Theme

    /// Initialize syntax highlighter with optional theme
    /// - Parameter theme: Color theme to use (defaults to system colors)
    public init(theme: Theme = .default) {
        self.theme = theme
    }

    /// Highlight code with syntax coloring
    /// - Parameters:
    ///   - code: The code string to highlight
    ///   - language: Programming language (if nil, attempts to detect or uses plain text)
    /// - Returns: Attributed string with syntax highlighting applied
    public func highlight(_ code: String, language: Language?) -> NSAttributedString {
        let detectedLanguage = language ?? .plaintext
        return highlightGeneric(code, language: detectedLanguage)
    }

    /// Highlight code with automatic language detection
    /// - Parameters:
    ///   - code: The code string to highlight
    ///   - languageHint: Language identifier string (e.g., "swift", "python")
    /// - Returns: Attributed string with syntax highlighting applied
    public func highlight(_ code: String, languageHint: String?) -> NSAttributedString {
        let language = Language.detect(from: languageHint)
        return highlight(code, language: language)
    }

    // MARK: - Private Highlighting Methods

    private func highlightGeneric(_ code: String, language: Language) -> NSAttributedString {
        // For non-Swift languages, provide basic monospace formatting
        // with simple pattern-based highlighting for common constructs

        #if canImport(UIKit)
        let baseFont = UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)
        #elseif canImport(AppKit)
        let baseFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        #endif

        let attributedString = NSMutableAttributedString(string: code)
        let fullRange = NSRange(location: 0, length: code.utf16.count)

        // Apply base font and color
        attributedString.addAttribute(.font, value: baseFont, range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: theme.plainText, range: fullRange)

        // Apply basic syntax highlighting patterns
        highlightComments(in: attributedString)
        highlightStrings(in: attributedString)
        highlightKeywords(in: attributedString, for: language)
        highlightNumbers(in: attributedString)

        return attributedString
    }

    private func highlightComments(in attributedString: NSMutableAttributedString) {
        // Single-line comments (// or #)
        let singleLinePattern = #"(//|#).*$"#
        highlightPattern(singleLinePattern, in: attributedString, color: theme.comment, options: [.anchorsMatchLines])

        // Multi-line comments (/* ... */)
        let multiLinePattern = #"/\*[\s\S]*?\*/"#
        highlightPattern(multiLinePattern, in: attributedString, color: theme.comment)
    }

    private func highlightStrings(in attributedString: NSMutableAttributedString) {
        // Double-quoted strings
        let doubleQuotePattern = #""(?:[^"\\]|\\.)*""#
        highlightPattern(doubleQuotePattern, in: attributedString, color: theme.string)

        // Single-quoted strings
        let singleQuotePattern = #"'(?:[^'\\]|\\.)*'"#
        highlightPattern(singleQuotePattern, in: attributedString, color: theme.string)

        // Template literals / backticks (JavaScript, etc.)
        let backtickPattern = #"`(?:[^`\\]|\\.)*`"#
        highlightPattern(backtickPattern, in: attributedString, color: theme.string)
    }

    private func highlightKeywords(in attributedString: NSMutableAttributedString, for language: Language) {
        let keywords = keywordsForLanguage(language)

        for keyword in keywords {
            // Match whole words only using word boundaries
            let pattern = "\\b\(keyword)\\b"
            highlightPattern(pattern, in: attributedString, color: theme.keyword)
        }
    }

    private func highlightNumbers(in attributedString: NSMutableAttributedString) {
        // Match integers, floats, hex, binary
        let numberPattern = #"\b(?:0[xX][0-9a-fA-F]+|0[bB][01]+|\d+\.?\d*(?:[eE][+-]?\d+)?)\b"#
        highlightPattern(numberPattern, in: attributedString, color: theme.number)
    }

    private func highlightPattern(
        _ pattern: String,
        in attributedString: NSMutableAttributedString,
        color: PlatformColor,
        options: NSRegularExpression.Options = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return
        }

        let text = attributedString.string
        let range = NSRange(location: 0, length: text.utf16.count)

        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }
            attributedString.addAttribute(.foregroundColor, value: color, range: matchRange)
        }
    }

    private func keywordsForLanguage(_ language: Language) -> [String] {
        switch language {
        case .swift:
            return ["class", "struct", "enum", "protocol", "extension", "func", "var", "let",
                    "if", "else", "switch", "case", "default", "for", "while", "repeat",
                    "return", "break", "continue", "import", "public", "private", "internal",
                    "fileprivate", "static", "final", "override", "init", "deinit", "self",
                    "super", "nil", "true", "false", "try", "catch", "throw", "throws",
                    "guard", "defer", "async", "await", "actor"]

        case .python:
            return ["def", "class", "if", "elif", "else", "for", "while", "return",
                    "import", "from", "as", "try", "except", "finally", "with", "lambda",
                    "True", "False", "None", "and", "or", "not", "in", "is", "pass",
                    "break", "continue", "yield", "async", "await", "raise", "assert"]

        case .javascript, .typescript:
            return ["function", "const", "let", "var", "if", "else", "for", "while",
                    "return", "break", "continue", "switch", "case", "default", "try",
                    "catch", "finally", "throw", "new", "class", "extends", "super",
                    "this", "import", "export", "from", "async", "await", "yield",
                    "typeof", "instanceof", "null", "undefined", "true", "false"]

        case .java, .kotlin:
            return ["public", "private", "protected", "class", "interface", "extends",
                    "implements", "new", "if", "else", "for", "while", "do", "switch",
                    "case", "default", "return", "break", "continue", "try", "catch",
                    "finally", "throw", "throws", "static", "final", "abstract", "void",
                    "boolean", "int", "long", "float", "double", "String", "true", "false", "null"]

        case .go:
            return ["func", "package", "import", "var", "const", "type", "struct",
                    "interface", "if", "else", "for", "range", "return", "break",
                    "continue", "switch", "case", "default", "defer", "go", "chan",
                    "select", "map", "true", "false", "nil"]

        case .rust:
            return ["fn", "let", "mut", "const", "struct", "enum", "impl", "trait",
                    "if", "else", "match", "for", "while", "loop", "return", "break",
                    "continue", "pub", "use", "mod", "crate", "self", "super", "async",
                    "await", "true", "false", "Some", "None", "Ok", "Err"]

        case .c, .cpp:
            return ["int", "char", "float", "double", "void", "if", "else", "for",
                    "while", "do", "switch", "case", "default", "return", "break",
                    "continue", "struct", "union", "enum", "typedef", "sizeof",
                    "static", "const", "extern", "auto", "register", "volatile",
                    "true", "false", "NULL"]

        case .csharp:
            return ["public", "private", "protected", "class", "interface", "struct",
                    "namespace", "using", "if", "else", "for", "foreach", "while",
                    "do", "switch", "case", "default", "return", "break", "continue",
                    "try", "catch", "finally", "throw", "new", "async", "await",
                    "var", "const", "static", "readonly", "true", "false", "null"]

        case .ruby:
            return ["def", "class", "module", "if", "elsif", "else", "unless", "case",
                    "when", "for", "while", "until", "begin", "end", "rescue", "ensure",
                    "return", "break", "next", "yield", "true", "false", "nil", "self",
                    "super", "require", "include", "extend", "attr_accessor"]

        case .php:
            return ["function", "class", "interface", "trait", "namespace", "use",
                    "if", "else", "elseif", "for", "foreach", "while", "do", "switch",
                    "case", "default", "return", "break", "continue", "try", "catch",
                    "finally", "throw", "new", "public", "private", "protected",
                    "static", "final", "abstract", "true", "false", "null"]

        case .bash, .shell:
            return ["if", "then", "else", "elif", "fi", "case", "esac", "for", "while",
                    "do", "done", "function", "return", "break", "continue", "exit",
                    "export", "local", "readonly", "true", "false"]

        case .sql:
            return ["SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "CREATE",
                    "DROP", "ALTER", "TABLE", "INDEX", "VIEW", "JOIN", "INNER", "LEFT",
                    "RIGHT", "ON", "AS", "AND", "OR", "NOT", "IN", "LIKE", "ORDER BY",
                    "GROUP BY", "HAVING", "LIMIT", "OFFSET", "NULL", "TRUE", "FALSE"]

        default:
            return []
        }
    }
}

// MARK: - Platform-specific Type Alias

#if canImport(UIKit)
private typealias PlatformColor = UIColor
#elseif canImport(AppKit)
private typealias PlatformColor = NSColor
#endif
