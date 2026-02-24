import Foundation
import Splash

// MARK: - Segment Helper Extension

extension Splash.Segment {
    func isNumber() -> Bool {
        let token = tokens.current.trimmingCharacters(in: .whitespaces)
        return !token.isEmpty && token.allSatisfy { $0.isNumber || $0 == "." || $0 == "_" }
    }
}

// MARK: - Generic Reusable Syntax Rules

/// Matches string literals delimited by configurable open/close pairs.
/// Each pair is a tuple of (open: String, close: String).
struct StringLiteralRule: SyntaxRule {
    var tokenType: TokenType { .string }

    let pairs: [(open: String, close: String)]

    init(pairs: [(open: String, close: String)]) {
        self.pairs = pairs
    }

    func matches(_ segment: Segment) -> Bool {
        let token = segment.tokens.current
        for pair in pairs {
            if token.hasPrefix(pair.open) && token.hasSuffix(pair.close) {
                return true
            }
        }
        return false
    }
}

/// Matches keywords from a configurable set, with optional case sensitivity.
/// When caseSensitive is false, the current token is uppercased before comparison,
/// so keywords should be stored in uppercase (e.g., SQL: "SELECT", "FROM").
struct KeywordRule: SyntaxRule {
    var tokenType: TokenType { .keyword }

    let keywords: Set<String>
    let caseSensitive: Bool

    init(keywords: Set<String>, caseSensitive: Bool = true) {
        self.keywords = keywords
        self.caseSensitive = caseSensitive
    }

    func matches(_ segment: Segment) -> Bool {
        if caseSensitive {
            return keywords.contains(segment.tokens.current)
        } else {
            return keywords.contains(segment.tokens.current.uppercased())
        }
    }
}

/// Matches hash-style line comments (`#` prefix), used by Python, Ruby, Bash, YAML, PHP.
struct HashCommentRule: SyntaxRule {
    var tokenType: TokenType { .comment }

    func matches(_ segment: Segment) -> Bool {
        return segment.tokens.current.hasPrefix("#") ||
               segment.tokens.onSameLine.contains("#")
    }
}

/// Matches SQL-style line comments (`--` prefix).
struct SQLCommentRule: SyntaxRule {
    var tokenType: TokenType { .comment }

    func matches(_ segment: Segment) -> Bool {
        return segment.tokens.current.hasPrefix("--") ||
               segment.tokens.onSameLine.contains("--")
    }
}

/// Matches HTML-style block comments (`<!-- ... -->`).
struct HTMLCommentRule: SyntaxRule {
    var tokenType: TokenType { .comment }

    func matches(_ segment: Segment) -> Bool {
        return segment.tokens.current.hasPrefix("<!--") ||
               segment.tokens.current.hasSuffix("-->")
    }
}

/// Matches CSS/C-style block comments (`/* ... */`) without the `//` line-comment variant.
struct CSSBlockCommentRule: SyntaxRule {
    var tokenType: TokenType { .comment }

    func matches(_ segment: Segment) -> Bool {
        return segment.tokens.current.hasPrefix("/*") ||
               segment.tokens.current.hasSuffix("*/")
    }
}

// MARK: - Shared Syntax Rules (used across multiple grammars)

/// C-style comment rule (// and /* */)
struct CStyleCommentRule: SyntaxRule {
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
struct PreprocessorRule: SyntaxRule {
    var tokenType: TokenType { .preprocessing }

    func matches(_ segment: Segment) -> Bool {
        return segment.tokens.current.hasPrefix("#")
    }
}

/// Generic number rule
struct NumberRule: SyntaxRule {
    var tokenType: TokenType { .number }

    func matches(_ segment: Segment) -> Bool {
        let token = segment.tokens.current.trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        guard !token.isEmpty else { return false }
        guard let first = token.first else { return false }

        // Check if it starts with a digit
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
struct CallRule: SyntaxRule {
    var tokenType: TokenType { .call }

    func matches(_ segment: Segment) -> Bool {
        guard let first = segment.tokens.current.first else { return false }
        guard first.isLetter || first == "_" else { return false }

        return segment.tokens.next?.hasPrefix("(") ?? false
    }
}
