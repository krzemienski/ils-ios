// CONC-18: @preconcurrency suppresses Sendable warnings from the pre-Swift-6 Splash library.
@preconcurrency import Splash

/// Namespace for resolving language identifiers to Splash Grammar instances.
/// Swift is handled as a special case using Splash's native SwiftGrammar;
/// all other languages are dispatched through DataDrivenGrammar.
enum GrammarRegistry {

    /// Maps every supported language alias (lowercased) to its GrammarConfig.
    /// "swift" is intentionally omitted — it returns SwiftGrammar() directly.
    static let languageMap: [String: GrammarConfig] = [
        // Python
        "python": .python,
        "py":     .python,

        // JavaScript
        "javascript": .javascript,
        "js":         .javascript,

        // TypeScript
        "typescript": .typescript,
        "ts":         .typescript,

        // Go
        "go":     .go,
        "golang": .go,

        // Rust
        "rust": .rust,
        "rs":   .rust,

        // Java
        "java": .java,

        // Kotlin
        "kotlin": .kotlin,
        "kt":     .kotlin,

        // C
        "c": .c,

        // C++
        "cpp": .cpp,
        "c++": .cpp,

        // C#
        "csharp": .csharp,
        "cs":     .csharp,
        "c#":     .csharp,

        // Ruby
        "ruby": .ruby,
        "rb":   .ruby,

        // PHP
        "php": .php,

        // Bash / Shell
        "bash":  .bash,
        "shell": .bash,
        "sh":    .bash,
        "zsh":   .bash,

        // SQL
        "sql": .sql,

        // JSON
        "json": .json,

        // YAML
        "yaml": .yaml,
        "yml":  .yaml,

        // HTML
        "html": .html,

        // CSS / pre-processors (share the same config)
        "css":  .css,
        "scss": .css,
        "sass": .css,

        // Markdown
        "markdown": .markdown,
        "md":       .markdown,

        // Objective-C
        "objective-c": .objectiveC,
        "objc":        .objectiveC
    ]

    /// Returns the appropriate Splash Grammar for the given (lowercased) language string.
    /// - Parameter language: A lowercased language identifier.
    /// - Returns: `SwiftGrammar` for "swift"; a `DataDrivenGrammar` for all other languages
    ///   (falling back to `.plainText` for unrecognised identifiers).
    static func grammar(for language: String) -> Splash.Grammar {
        if language == "swift" {
            return SwiftGrammar()
        }
        return DataDrivenGrammar(config: languageMap[language] ?? .plainText)
    }
}
