import Foundation

/// Utility for detecting content type in pasted text (code, URL, file path, error log)
enum ContentDetector {
    /// Represents the detected content type
    enum ContentType {
        case code
        case url
        case filePath
        case errorLog
        case plainText
    }

    /// Result of content detection with confidence score
    struct DetectionResult {
        let type: ContentType
        let confidence: Double // 0.0 to 1.0
        let metadata: [String: String] // e.g., ["url": "https://example.com"], ["path": "/usr/bin"]

        init(type: ContentType, confidence: Double = 1.0, metadata: [String: String] = [:]) {
            self.type = type
            self.confidence = min(max(confidence, 0.0), 1.0) // Clamp to 0-1
            self.metadata = metadata
        }
    }

    // MARK: - Cached Regex Patterns

    /// Regex for URLs (RFC-compliant, supports http/https/ftp and common TLDs)
    private static let urlRegex: NSRegularExpression? = {
        let pattern = #"(?i)\b((?:https?|ftp):\/\/[^\s<>"{}|\\^`\[\]]+|www\.[^\s<>"{}|\\^`\[\]]+\.[a-z]{2,})"#
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// Regex for Unix file paths (/path/to/file or ~/path/to/file)
    private static let unixPathRegex: NSRegularExpression? = {
        let pattern = #"(?:^|[\s])([~/][\w\-./]+)(?:[\s]|$)"#
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()

    /// Regex for Windows file paths (C:\path\to\file or \\network\path)
    private static let windowsPathRegex: NSRegularExpression? = {
        let pattern = #"(?:^|[\s])([A-Za-z]:\\[\w\-\\/.]+|\\\\[\w\-\\/.]+)(?:[\s]|$)"#
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()

    /// Regex for stack trace patterns (common error log indicators)
    /// Matches patterns like "at ClassName.method", "File \"path\", line 123", "Error:", "Exception:"
    private static let stackTraceRegex: NSRegularExpression? = {
        let pattern = #"(?:at\s+[\w.<>]+\(|File\s+[""']|line\s+\d+|Error:|Exception:|Traceback|Stack trace:)"#
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()

    // MARK: - Code Detection Keywords

    /// Common programming keywords that indicate code
    private static let codeKeywords: Set<String> = [
        // Control flow
        "if", "else", "for", "while", "switch", "case", "break", "continue", "return",
        // Function/class declarations
        "func", "function", "def", "class", "struct", "enum", "interface", "protocol",
        // Variable declarations
        "var", "let", "const", "int", "String", "boolean", "float", "double",
        // Common language-specific
        "import", "from", "export", "require", "include", "using",
        "public", "private", "static", "final", "override", "async", "await",
        // Common operators/symbols in code context
        "void", "null", "nil", "undefined", "true", "false",
        "this", "self", "super", "extends", "implements"
    ]

    // MARK: - Detection Methods

    /// Detect content type from pasted text
    /// - Parameter text: The text to analyze
    /// - Returns: Detection result with type, confidence, and metadata
    static func detect(_ text: String) -> DetectionResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty or very short text defaults to plain text
        guard !trimmedText.isEmpty, trimmedText.count > 5 else {
            return DetectionResult(type: .plainText, confidence: 1.0)
        }

        // Check for URL (highest priority for short text)
        if let urlResult = detectURL(in: trimmedText) {
            return urlResult
        }

        // Check for error log/stack trace
        if let errorResult = detectErrorLog(in: trimmedText) {
            return errorResult
        }

        // Check for file path
        if let pathResult = detectFilePath(in: trimmedText) {
            return pathResult
        }

        // Check for code
        if let codeResult = detectCode(in: trimmedText) {
            return codeResult
        }

        // Default to plain text
        return DetectionResult(type: .plainText, confidence: 1.0)
    }

    /// Detect URL in text
    /// - Parameter text: The text to analyze
    /// - Returns: Detection result if URL found, nil otherwise
    private static func detectURL(in text: String) -> DetectionResult? {
        guard let regex = urlRegex else { return nil }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        guard !matches.isEmpty else { return nil }

        // Extract first URL for metadata
        let firstMatch = matches[0]
        let urlString = nsText.substring(with: firstMatch.range)

        // High confidence if text is mostly URL (single URL paste)
        let urlCharCount = matches.reduce(0) { $0 + $1.range.length }
        let urlRatio = Double(urlCharCount) / Double(text.count)

        let confidence = urlRatio > 0.7 ? 0.95 : 0.70

        return DetectionResult(
            type: .url,
            confidence: confidence,
            metadata: ["url": urlString]
        )
    }

    /// Detect file path in text
    /// - Parameter text: The text to analyze
    /// - Returns: Detection result if file path found, nil otherwise
    private static func detectFilePath(in text: String) -> DetectionResult? {
        let nsText = text as NSString

        // Check Unix paths
        if let unixRegex = unixPathRegex {
            let matches = unixRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
            if !matches.isEmpty {
                let firstPath = nsText.substring(with: matches[0].range(at: 1))
                // Higher confidence if text is just the path
                let confidence = text.trimmingCharacters(in: .whitespaces) == firstPath ? 0.90 : 0.60
                return DetectionResult(
                    type: .filePath,
                    confidence: confidence,
                    metadata: ["path": firstPath]
                )
            }
        }

        // Check Windows paths
        if let windowsRegex = windowsPathRegex {
            let matches = windowsRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
            if !matches.isEmpty {
                let firstPath = nsText.substring(with: matches[0].range(at: 1))
                let confidence = text.trimmingCharacters(in: .whitespaces) == firstPath ? 0.90 : 0.60
                return DetectionResult(
                    type: .filePath,
                    confidence: confidence,
                    metadata: ["path": firstPath]
                )
            }
        }

        return nil
    }

    /// Detect error log or stack trace in text
    /// - Parameter text: The text to analyze
    /// - Returns: Detection result if error log pattern found, nil otherwise
    private static func detectErrorLog(in text: String) -> DetectionResult? {
        guard let regex = stackTraceRegex else { return nil }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        // Need at least 2 stack trace indicators for reasonable confidence
        guard matches.count >= 2 else { return nil }

        // Check if text has multiple lines (error logs are usually multi-line)
        let lineCount = text.components(separatedBy: .newlines).count
        let hasMultipleLines = lineCount > 2

        // Higher confidence with more indicators and multiple lines
        let confidence = hasMultipleLines ? 0.85 : 0.65

        return DetectionResult(
            type: .errorLog,
            confidence: confidence,
            metadata: ["indicatorCount": "\(matches.count)"]
        )
    }

    /// Detect code in text using heuristics (keywords, braces, indentation)
    /// - Parameter text: The text to analyze
    /// - Returns: Detection result if code patterns found, nil otherwise
    private static func detectCode(in text: String) -> DetectionResult? {
        var codeScore = 0.0

        // Check for code keywords
        let lowercasedText = text.lowercased()
        let words = lowercasedText.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let keywordCount = words.filter { codeKeywords.contains($0) }.count

        if keywordCount > 0 {
            codeScore += Double(keywordCount) * 0.15
        }

        // Check for common code symbols: braces, semicolons, brackets
        let braceCount = text.filter { $0 == "{" || $0 == "}" }.count
        let semicolonCount = text.filter { $0 == ";" }.count
        let bracketCount = text.filter { $0 == "[" || $0 == "]" }.count
        let parenCount = text.filter { $0 == "(" || $0 == ")" }.count

        if braceCount > 0 {
            codeScore += Double(braceCount) * 0.10
        }
        if semicolonCount > 0 {
            codeScore += Double(semicolonCount) * 0.05
        }
        if bracketCount > 0 {
            codeScore += Double(bracketCount) * 0.05
        }
        if parenCount > 2 {
            codeScore += 0.10
        }

        // Check for indentation patterns (code often has consistent indentation)
        let lines = text.components(separatedBy: .newlines)
        let indentedLines = lines.filter { line in
            line.hasPrefix("    ") || line.hasPrefix("\t")
        }

        if indentedLines.count > 1 {
            let indentRatio = Double(indentedLines.count) / Double(lines.count)
            codeScore += indentRatio * 0.30
        }

        // Check for assignment operators (=, :=, ==, ===)
        let assignmentPattern = #"[^=!<>]=(?!=)"# // Matches = but not ==, !=, <=, >=
        if let assignmentRegex = try? NSRegularExpression(pattern: assignmentPattern, options: []) {
            let nsText = text as NSString
            let assignmentMatches = assignmentRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
            if assignmentMatches.count > 0 {
                codeScore += Double(assignmentMatches.count) * 0.08
            }
        }

        // Check for arrow functions/lambda syntax (=>, ->)
        if text.contains("=>") || text.contains("->") {
            codeScore += 0.15
        }

        // Normalize score to 0-1 range (cap at 1.0)
        let confidence = min(codeScore, 1.0)

        // Require minimum confidence threshold
        guard confidence >= 0.30 else { return nil }

        return DetectionResult(
            type: .code,
            confidence: confidence,
            metadata: [
                "keywordCount": "\(keywordCount)",
                "symbolScore": String(format: "%.2f", codeScore)
            ]
        )
    }
}
