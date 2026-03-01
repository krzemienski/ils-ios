import Foundation
import Splash

// MARK: - GrammarConfig Scripting Language Definitions
//
// Scripting language grammar configurations: Python, Ruby, PHP, Bash/Shell.

extension GrammarConfig {

    // MARK: Python

    static let python = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("\"")
            set.remove("'")
            set.remove("#")
            return set
        }(),
        commentStyle: .hash,
        stringPairs: [
            ("\"\"\"", "\"\"\""),
            ("'''", "'''"),
            ("\"", "\""),
            ("'", "'")
        ],
        keywords: [
            "def", "class", "if", "elif", "else", "for", "while", "return",
            "import", "from", "as", "try", "except", "finally", "with",
            "lambda", "yield", "pass", "break", "continue", "True", "False",
            "None", "and", "or", "not", "is", "in", "async", "await", "raise"
        ]
    )

    // MARK: Ruby

    static let ruby = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("\"")
            set.remove("'")
            set.remove("#")
            set.remove("@")
            return set
        }(),
        commentStyle: .hash,
        stringPairs: [
            ("\"", "\""),
            ("'", "'")
        ],
        keywords: [
            "def", "end", "class", "module", "if", "elsif", "else", "unless",
            "case", "when", "for", "while", "until", "return", "yield",
            "break", "next", "redo", "retry", "true", "false", "nil", "and",
            "or", "not", "do", "begin", "rescue", "ensure", "raise", "include",
            "extend", "require"
        ]
    )

    // MARK: PHP

    static let php = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("$")
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
            "function", "class", "interface", "trait", "extends", "implements",
            "public", "private", "protected", "static", "final", "abstract",
            "if", "else", "elseif", "for", "foreach", "while", "do", "switch",
            "case", "default", "break", "continue", "return", "try", "catch",
            "finally", "throw", "new", "this", "self", "parent", "var",
            "const", "echo", "print", "true", "false", "null", "array", "as",
            "namespace", "use"
        ],
        extraRules: [HashCommentRule()]
    )

    // MARK: Bash

    static let bash = GrammarConfig(
        delimiters: {
            var set = CharacterSet.alphanumerics.inverted
            set.remove("_")
            set.remove("$")
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
        keywords: [
            "if", "then", "else", "elif", "fi", "case", "esac", "for",
            "while", "until", "do", "done", "function", "in", "select"
        ],
        includeCallRule: false
    )
}
