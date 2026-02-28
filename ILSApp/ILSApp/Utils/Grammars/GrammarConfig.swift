import Foundation
import Splash

// MARK: - Comment Style

/// Describes the comment syntax variant for a language grammar.
enum CommentStyle {
    /// C-style comments: `//` line comments and `/* */` block comments.
    case cStyle
    /// Hash-prefixed line comments: `#`. Used by Python, Ruby, Bash, YAML, PHP.
    case hash
    /// SQL-style line comments: `--`.
    case sql
    /// HTML-style block comments: `<!-- -->`.
    case html
    /// CSS/C-style block comments only: `/* */` (no `//` line-comment variant).
    case cssBlock
    /// Language has no comment syntax (e.g., JSON, plain text).
    case none
}

// MARK: - Grammar Configuration

/// Data-driven configuration for building a `DataDrivenGrammar`.
///
/// Specify delimiters, comment style, string pairs, keywords, and optional
/// rule inclusions. Pass this to `DataDrivenGrammar` to obtain a fully
/// functional `Grammar` conformance without writing boilerplate.
struct GrammarConfig {
    /// Character set used to split the source into tokens.
    let delimiters: CharacterSet

    /// Comment syntax style for the language.
    let commentStyle: CommentStyle

    /// String literal delimiter pairs, e.g. `[("\"", "\""), ("'", "'")]`.
    /// An empty array disables string highlighting.
    let stringPairs: [(String, String)]

    /// Keyword set for the language.
    let keywords: Set<String>

    /// Whether keyword matching is case-sensitive. Defaults to `true`.
    /// When `false`, the token is uppercased before lookup, so `keywords`
    /// should be stored in uppercase (e.g. SQL: `"SELECT"`, `"FROM"`).
    let keywordCaseSensitive: Bool

    /// Whether to include the generic `CallRule` (identifier followed by `(`).
    let includeCallRule: Bool

    /// Whether to include the generic `NumberRule`.
    let includeNumberRule: Bool

    /// Whether to include the `PreprocessorRule` (`#` prefix directives).
    let includePreprocessor: Bool

    /// Additional grammar-specific rules appended after the generated ones.
    let extraRules: [any SyntaxRule]

    /// Creates a `GrammarConfig` with explicit values and sensible defaults.
    init(
        delimiters: CharacterSet,
        commentStyle: CommentStyle,
        stringPairs: [(String, String)],
        keywords: Set<String>,
        keywordCaseSensitive: Bool = true,
        includeCallRule: Bool = true,
        includeNumberRule: Bool = true,
        includePreprocessor: Bool = false,
        extraRules: [any SyntaxRule] = []
    ) {
        self.delimiters = delimiters
        self.commentStyle = commentStyle
        self.stringPairs = stringPairs
        self.keywords = keywords
        self.keywordCaseSensitive = keywordCaseSensitive
        self.includeCallRule = includeCallRule
        self.includeNumberRule = includeNumberRule
        self.includePreprocessor = includePreprocessor
        self.extraRules = extraRules
    }
}

// MARK: - Data-Driven Grammar

/// A `Grammar` implementation built from a `GrammarConfig`.
///
/// Rules are assembled in this order:
/// 1. `PreprocessorRule`   — only if `config.includePreprocessor`
/// 2. Comment rule         — selected by `config.commentStyle` (skipped for `.none`)
/// 3. `StringLiteralRule`  — only if `config.stringPairs` is non-empty
/// 4. `NumberRule`         — only if `config.includeNumberRule`
/// 5. `KeywordRule`        — only if `config.keywords` is non-empty
/// 6. `CallRule`           — only if `config.includeCallRule`
/// 7. `config.extraRules`  — appended verbatim at the end
struct DataDrivenGrammar: Grammar {
    /// The configuration that drives rule generation and tokenisation.
    let config: GrammarConfig

    /// Forwards the delimiter set from the configuration.
    var delimiters: CharacterSet { config.delimiters }

    /// Cached rule list, built once from the configuration at init time.
    let syntaxRules: [SyntaxRule]

    init(config: GrammarConfig) {
        self.config = config

        var rules: [any SyntaxRule] = []

        // 1. Preprocessor rule (e.g. #include, #define)
        if config.includePreprocessor {
            rules.append(PreprocessorRule())
        }

        // 2. Comment rule
        switch config.commentStyle {
        case .cStyle:
            rules.append(CStyleCommentRule())
        case .hash:
            rules.append(HashCommentRule())
        case .sql:
            rules.append(SQLCommentRule())
        case .html:
            rules.append(HTMLCommentRule())
        case .cssBlock:
            rules.append(CSSBlockCommentRule())
        case .none:
            break
        }

        // 3. String literal rule
        if !config.stringPairs.isEmpty {
            let pairs = config.stringPairs.map { (open: $0.0, close: $0.1) }
            rules.append(StringLiteralRule(pairs: pairs))
        }

        // 4. Number rule
        if config.includeNumberRule {
            rules.append(NumberRule())
        }

        // 5. Keyword rule
        if !config.keywords.isEmpty {
            rules.append(KeywordRule(
                keywords: config.keywords,
                caseSensitive: config.keywordCaseSensitive
            ))
        }

        // 6. Call rule
        if config.includeCallRule {
            rules.append(CallRule())
        }

        // 7. Extra language-specific rules
        rules.append(contentsOf: config.extraRules)

        self.syntaxRules = rules
    }
}
