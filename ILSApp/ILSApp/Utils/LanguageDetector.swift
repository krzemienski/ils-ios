import Foundation

/// Utility for auto-detecting programming language from code snippets
enum LanguageDetector {
    /// Result of language detection with confidence score
    struct DetectionResult {
        let language: String // Language identifier (lowercase, e.g., "swift", "python")
        let confidence: Double // 0.0 to 1.0

        init(language: String, confidence: Double = 1.0) {
            self.language = language.lowercased()
            self.confidence = min(max(confidence, 0.0), 1.0) // Clamp to 0-1
        }
    }

    // MARK: - Language Pattern Definitions

    /// Language detection pattern with keywords and syntax indicators
    private struct LanguagePattern {
        let identifier: String // e.g., "swift", "python"
        let keywords: Set<String> // Language-specific keywords
        let syntaxPatterns: [String] // Regex patterns for language-specific syntax
        let fileExtensions: Set<String> // Common file extensions (for hint matching)

        /// Calculate match score for given text
        func score(text: String, lowercasedText: String, words: [String]) -> Double {
            var score = 0.0

            // Keyword matching (main signal)
            let keywordMatches = words.filter { keywords.contains($0) }.count
            score += Double(keywordMatches) * 0.20

            // Syntax pattern matching
            for pattern in syntaxPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   !regex.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)).isEmpty {
                    score += 0.25
                }
            }

            return min(score, 1.0)
        }
    }

    // MARK: - Language Patterns (aligned with GrammarRegistry)

    private static let patterns: [LanguagePattern] = [
        // Swift
        LanguagePattern(
            identifier: "swift",
            keywords: ["import", "func", "var", "let", "class", "struct", "enum", "protocol", "extension", "guard", "defer", "init", "deinit", "weak", "unowned", "override", "final", "fileprivate", "typealias"],
            syntaxPatterns: [
                #"func\s+\w+\s*\([^)]*\)\s*(->\s*\w+)?\s*\{"#, // func name() -> Type {
                #"(var|let)\s+\w+:\s*\w+"#, // var name: Type
                #"import\s+\w+"# // import Module
            ],
            fileExtensions: ["swift"]
        ),

        // Python
        LanguagePattern(
            identifier: "python",
            keywords: ["def", "class", "import", "from", "as", "if", "elif", "else", "for", "while", "try", "except", "finally", "with", "pass", "lambda", "yield", "return", "async", "await", "None", "True", "False", "__init__", "self"],
            syntaxPatterns: [
                #"def\s+\w+\s*\([^)]*\)\s*:"#, // def name():
                #"class\s+\w+(\([^)]*\))?\s*:"#, // class Name:
                #"from\s+\w+\s+import"#, // from module import
                #"@\w+"# // @decorator
            ],
            fileExtensions: ["py", "python"]
        ),

        // JavaScript
        LanguagePattern(
            identifier: "javascript",
            keywords: ["function", "const", "let", "var", "class", "extends", "import", "export", "default", "async", "await", "return", "if", "else", "for", "while", "switch", "case", "break", "continue", "typeof", "instanceof", "new", "this", "super", "static"],
            syntaxPatterns: [
                #"(const|let|var)\s+\w+\s*="#, // const/let/var name =
                #"function\s+\w+\s*\([^)]*\)\s*\{"#, // function name() {
                #"=>\s*\{"#, // => { (arrow function)
                #"(import|export)\s+(default\s+)?(\{[^}]+\}|\w+)"# // import/export
            ],
            fileExtensions: ["js", "javascript", "jsx"]
        ),

        // TypeScript
        LanguagePattern(
            identifier: "typescript",
            keywords: ["interface", "type", "enum", "namespace", "implements", "public", "private", "protected", "readonly", "abstract", "as", "const", "let", "var", "function", "class", "extends", "import", "export", "async", "await"],
            syntaxPatterns: [
                #"(interface|type)\s+\w+\s*\{"#, // interface Name {
                #"(public|private|protected)\s+\w+:"#, // public name:
                #":\s*\w+(\[\]|\<[^>]+\>)?\s*[=;]"#, // : Type =
                #"(import|export)\s+type\s+"# // import type
            ],
            fileExtensions: ["ts", "typescript", "tsx"]
        ),

        // Go
        LanguagePattern(
            identifier: "go",
            keywords: ["package", "import", "func", "type", "struct", "interface", "map", "chan", "go", "defer", "if", "else", "for", "range", "switch", "case", "default", "return", "var", "const", "make", "nil"],
            syntaxPatterns: [
                #"package\s+\w+"#, // package main
                #"func\s+(\(\w+\s+\*?\w+\)\s+)?\w+\s*\([^)]*\)"#, // func (r *Receiver) name()
                #"type\s+\w+\s+(struct|interface)\s*\{"#, // type Name struct {
                #":="#, // Short variable declaration
                #"<-\s*\w+"# // Channel receive
            ],
            fileExtensions: ["go", "golang"]
        ),

        // Rust
        LanguagePattern(
            identifier: "rust",
            keywords: ["fn", "let", "mut", "struct", "enum", "impl", "trait", "pub", "use", "mod", "crate", "if", "else", "for", "while", "loop", "match", "return", "async", "await", "unsafe", "const", "static", "type", "where", "self", "Self"],
            syntaxPatterns: [
                #"fn\s+\w+\s*\([^)]*\)\s*(->\s*\w+)?\s*\{"#, // fn name() -> Type {
                #"let\s+(mut\s+)?\w+:\s*\w+"#, // let mut name: Type
                #"impl\s+(\w+\s+for\s+)?\w+"#, // impl Trait for Type
                #"::<"#, // Turbofish operator
                #"\|[^|]*\|\s*\{"# // Closure syntax
            ],
            fileExtensions: ["rs", "rust"]
        ),

        // Java
        LanguagePattern(
            identifier: "java",
            keywords: ["public", "private", "protected", "class", "interface", "extends", "implements", "import", "package", "static", "final", "void", "int", "String", "boolean", "new", "this", "super", "return", "if", "else", "for", "while", "try", "catch", "throws", "throw"],
            syntaxPatterns: [
                #"(public|private|protected)\s+(static\s+)?(class|interface)\s+\w+"#, // public class Name
                #"(public|private|protected)\s+(static\s+)?\w+\s+\w+\s*\([^)]*\)\s*\{"#, // public void method()
                #"import\s+[\w.]+;"#, // import package.Class;
                #"@\w+"# // @Annotation
            ],
            fileExtensions: ["java"]
        ),

        // Kotlin
        LanguagePattern(
            identifier: "kotlin",
            keywords: ["fun", "val", "var", "class", "interface", "object", "companion", "data", "sealed", "open", "abstract", "override", "private", "public", "protected", "internal", "import", "package", "if", "else", "when", "for", "while", "return", "null", "lateinit", "by"],
            syntaxPatterns: [
                #"fun\s+\w+\s*\([^)]*\)\s*(:\s*\w+)?\s*\{"#, // fun name(): Type {
                #"(val|var)\s+\w+:\s*\w+"#, // val name: Type
                #"data\s+class\s+\w+"#, // data class Name
                #"when\s*\([^)]*\)\s*\{"#, // when (value) {
                #"->"# // Lambda arrow
            ],
            fileExtensions: ["kt", "kotlin"]
        ),

        // C
        LanguagePattern(
            identifier: "c",
            keywords: ["int", "char", "float", "double", "void", "struct", "union", "typedef", "enum", "const", "static", "extern", "if", "else", "for", "while", "do", "switch", "case", "break", "continue", "return", "sizeof", "printf", "scanf", "include"],
            syntaxPatterns: [
                #"#include\s*[<"][^>"]+[>"]"#, // #include <stdio.h>
                #"(int|char|float|double|void)\s+\w+\s*\([^)]*\)\s*\{"#, // int main()
                #"typedef\s+struct"#, // typedef struct
                #"printf\s*\("#, // printf(
                #"->"# // Pointer member access
            ],
            fileExtensions: ["c", "h"]
        ),

        // C++
        LanguagePattern(
            identifier: "cpp",
            keywords: ["class", "public", "private", "protected", "virtual", "namespace", "using", "template", "typename", "const", "static", "new", "delete", "this", "nullptr", "override", "final", "auto", "decltype", "std", "cout", "cin", "endl"],
            syntaxPatterns: [
                #"class\s+\w+\s*(:\s*(public|private|protected)\s+\w+)?\s*\{"#, // class Name : public Base {
                #"namespace\s+\w+\s*\{"#, // namespace name {
                #"template\s*<[^>]+>"#, // template<typename T>
                #"std::"#, // std::
                #"::"#, // Scope resolution
                #"(cout|cin)\s*<<"# // cout <<
            ],
            fileExtensions: ["cpp", "cc", "cxx", "hpp", "hxx", "c++", "h++"]
        ),

        // C#
        LanguagePattern(
            identifier: "csharp",
            keywords: ["class", "interface", "namespace", "using", "public", "private", "protected", "internal", "static", "virtual", "override", "abstract", "sealed", "async", "await", "var", "int", "string", "bool", "void", "new", "this", "base", "get", "set", "value"],
            syntaxPatterns: [
                #"namespace\s+[\w.]+"#, // namespace Name.Space
                #"(public|private|protected)\s+(class|interface|struct)\s+\w+"#, // public class Name
                #"(public|private|protected)\s+(static\s+)?\w+\s+\w+\s*\([^)]*\)"#, // public void Method()
                #"(get|set)\s*;"#, // Property accessors
                #"=>"# // Expression-bodied member
            ],
            fileExtensions: ["cs", "csharp"]
        ),

        // Ruby
        LanguagePattern(
            identifier: "ruby",
            keywords: ["def", "class", "module", "if", "elsif", "else", "unless", "case", "when", "for", "while", "until", "do", "end", "begin", "rescue", "ensure", "return", "yield", "self", "attr_accessor", "attr_reader", "attr_writer", "require", "include", "extend"],
            syntaxPatterns: [
                #"def\s+\w+(\([^)]*\))?"#, // def method_name
                #"class\s+\w+(\s*<\s*\w+)?"#, // class Name < Base
                #"module\s+\w+"#, // module Name
                #"\|\w+\|"#, // |param| block parameter
                #":\w+"#, // :symbol
                #"=>"# // Hash rocket
            ],
            fileExtensions: ["rb", "ruby"]
        ),

        // PHP
        LanguagePattern(
            identifier: "php",
            keywords: ["function", "class", "interface", "trait", "namespace", "use", "public", "private", "protected", "static", "final", "abstract", "extends", "implements", "if", "else", "elseif", "foreach", "while", "for", "switch", "case", "return", "echo", "print", "new", "this", "self", "parent"],
            syntaxPatterns: [
                #"<\?php"#, // <?php
                #"\$\w+"#, // $variable
                #"function\s+\w+\s*\([^)]*\)"#, // function name()
                #"(public|private|protected)\s+function"#, // public function
                #"->"#, // Object operator
                #"::"# // Scope resolution
            ],
            fileExtensions: ["php"]
        ),

        // Bash/Shell
        LanguagePattern(
            identifier: "bash",
            keywords: ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "function", "echo", "export", "source", "alias", "cd", "ls", "grep", "sed", "awk", "sudo", "chmod", "chown"],
            syntaxPatterns: [
                #"#!/bin/(bash|sh|zsh)"#, // Shebang
                #"\$\{?\w+\}?"#, // $variable or ${variable}
                #"if\s*\[\[?\s*"#, // if [[ or if [
                #"\|\s*\w+"#, // Pipe
                #"function\s+\w+\s*\(\)\s*\{"#, // function name() {
                #"(echo|export)\s+"# // echo/export
            ],
            fileExtensions: ["sh", "bash", "zsh"]
        ),

        // SQL
        LanguagePattern(
            identifier: "sql",
            keywords: ["SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "CREATE", "DROP", "TABLE", "DATABASE", "INDEX", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "AND", "OR", "NOT", "NULL", "PRIMARY", "KEY", "FOREIGN", "ALTER", "ORDER", "BY", "GROUP", "HAVING", "LIMIT"],
            syntaxPatterns: [
                #"(?i)SELECT\s+.+\s+FROM"#, // SELECT ... FROM
                #"(?i)INSERT\s+INTO"#, // INSERT INTO
                #"(?i)UPDATE\s+\w+\s+SET"#, // UPDATE table SET
                #"(?i)CREATE\s+(TABLE|DATABASE|INDEX)"#, // CREATE TABLE/DATABASE/INDEX
                #"(?i)WHERE\s+\w+\s*="# // WHERE column =
            ],
            fileExtensions: ["sql"]
        ),

        // JSON
        LanguagePattern(
            identifier: "json",
            keywords: ["true", "false", "null"],
            syntaxPatterns: [
                #"^\s*\{"#, // Starts with {
                #"^\s*\["#, // Starts with [
                #""\w+"\s*:\s*"#, // "key": (JSON key-value)
                #":\s*(\{|\[|"\w+"|true|false|null|\d+)"# // Value patterns
            ],
            fileExtensions: ["json"]
        ),

        // YAML
        LanguagePattern(
            identifier: "yaml",
            keywords: ["true", "false", "null", "yes", "no"],
            syntaxPatterns: [
                #"^---"#, // YAML document separator
                #"^\w+:\s*$"#, // key: (no value, nested)
                #"^\s*-\s+\w+"#, // - item (list item)
                #"^\w+:\s+.+"#, // key: value
                #":\s*\|"#, // Multi-line literal block
                #":\s*>"# // Multi-line folded block
            ],
            fileExtensions: ["yaml", "yml"]
        ),

        // HTML
        LanguagePattern(
            identifier: "html",
            keywords: ["html", "head", "body", "div", "span", "a", "img", "src", "href", "class", "id", "style", "script", "link", "meta", "title", "p", "h1", "h2", "h3", "ul", "ol", "li", "table", "tr", "td", "form", "input", "button"],
            syntaxPatterns: [
                #"<!DOCTYPE\s+html>"#, // <!DOCTYPE html>
                #"<html[^>]*>"#, // <html>
                #"<[a-z]+[^>]*>"#, // <tag>
                #"</[a-z]+>"#, // </tag>
                #"<[a-z]+\s+[^>]*\/>"# // <tag />
            ],
            fileExtensions: ["html", "htm"]
        ),

        // CSS/SCSS/SASS
        LanguagePattern(
            identifier: "css",
            keywords: ["color", "background", "font", "margin", "padding", "border", "width", "height", "display", "position", "flex", "grid", "absolute", "relative", "fixed", "important", "hover", "active", "focus", "before", "after"],
            syntaxPatterns: [
                #"[.#]?\w+\s*\{"#, // selector {
                #"\w+:\s*[^;]+;"#, // property: value;
                #"@(media|import|keyframes|font-face)"#, // @media, @import, etc.
                #":\s*(hover|active|focus|before|after)"#, // Pseudo-classes/elements
                #"!\s*important"# // !important
            ],
            fileExtensions: ["css", "scss", "sass"]
        ),

        // Markdown
        LanguagePattern(
            identifier: "markdown",
            keywords: [],
            syntaxPatterns: [
                #"^#{1,6}\s+\w+"#, // # Heading
                #"^\*{1,2}\w+\*{1,2}"#, // *italic* or **bold**
                #"^>\s+"#, // > blockquote
                #"^\s*[-*+]\s+"#, // - list item
                #"^\d+\.\s+"#, // 1. numbered list
                #"\[.+\]\(.+\)"#, // [text](url)
                #"```\w*"# // ```code block
            ],
            fileExtensions: ["md", "markdown"]
        ),

        // Objective-C
        LanguagePattern(
            identifier: "objective-c",
            keywords: ["@interface", "@implementation", "@property", "@synthesize", "@class", "@protocol", "@selector", "@end", "id", "nil", "YES", "NO", "self", "super", "IBOutlet", "IBAction", "NSString", "NSArray", "NSDictionary", "NSInteger"],
            syntaxPatterns: [
                #"@interface\s+\w+"#, // @interface ClassName
                #"@implementation\s+\w+"#, // @implementation ClassName
                #"@property\s*\([^)]*\)"#, // @property(attributes)
                #"-\s*\([^)]*\)\s*\w+"#, // - (void)methodName
                #"\[\w+\s+\w+"#, // [object message
                #"@"\w+"# // @"string"
            ],
            fileExtensions: ["m", "mm", "h"]
        )
    ]

    // MARK: - Detection Method

    /// Detect programming language from code snippet
    /// - Parameter code: The code snippet to analyze
    /// - Returns: Detection result with language and confidence, or nil if no language detected
    static func detect(_ code: String) -> DetectionResult? {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty or very short code defaults to nil
        guard !trimmedCode.isEmpty, trimmedCode.count > 10 else {
            return nil
        }

        // Prepare text for analysis
        let lowercasedCode = code.lowercased()
        let words = lowercasedCode.components(separatedBy: CharacterSet.alphanumerics.inverted)

        // Score all patterns
        var results: [(pattern: LanguagePattern, score: Double)] = []
        for pattern in patterns {
            let score = pattern.score(text: code, lowercasedText: lowercasedCode, words: words)
            if score > 0 {
                results.append((pattern, score))
            }
        }

        // Sort by score descending
        results.sort { $0.score > $1.score }

        // Return top match if confidence meets threshold
        guard let topMatch = results.first, topMatch.score >= 0.30 else {
            return nil
        }

        return DetectionResult(
            language: topMatch.pattern.identifier,
            confidence: topMatch.score
        )
    }

    /// Detect programming language with optional hint (e.g., from file extension)
    /// - Parameters:
    ///   - code: The code snippet to analyze
    ///   - hint: Optional hint (e.g., "swift", ".py", "javascript")
    /// - Returns: Detection result with language and confidence, or nil if no language detected
    static func detect(_ code: String, hint: String?) -> DetectionResult? {
        // Try standard detection first
        guard let baseResult = detect(code) else {
            return nil
        }

        // If hint provided, boost confidence if it matches
        guard let hint = hint?.lowercased().trimmingCharacters(in: .punctuationCharacters) else {
            return baseResult
        }

        // Find pattern matching hint
        let hintMatchesLanguage = patterns.contains { pattern in
            pattern.identifier == hint || pattern.fileExtensions.contains(hint)
        }

        // Boost confidence if hint matches detected language
        if hintMatchesLanguage && baseResult.language == hint {
            let boostedConfidence = min(baseResult.confidence + 0.20, 1.0)
            return DetectionResult(language: baseResult.language, confidence: boostedConfidence)
        }

        return baseResult
    }
}
