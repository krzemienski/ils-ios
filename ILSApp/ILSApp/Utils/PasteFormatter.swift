import Foundation

/// Utility for transforming detected content into properly formatted markdown
enum PasteFormatter {
    /// Format content based on detected type
    /// - Parameters:
    ///   - text: The raw text content to format
    ///   - contentType: The detected content type
    ///   - language: Optional language identifier for code formatting (e.g., "swift", "python")
    ///   - metadata: Optional metadata from content detection (e.g., URL, file path)
    /// - Returns: Formatted markdown string
    static func format(
        _ text: String,
        contentType: ContentDetector.ContentType,
        language: String? = nil,
        metadata: [String: String] = [:]
    ) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            return text
        }

        switch contentType {
        case .code:
            return formatCode(trimmedText, language: language)
        case .url:
            return formatURL(trimmedText, metadata: metadata)
        case .filePath:
            return formatFilePath(trimmedText, metadata: metadata)
        case .errorLog:
            return formatErrorLog(trimmedText)
        case .plainText:
            return text
        }
    }

    // MARK: - Private Formatting Methods

    /// Format code as fenced code block with language tag
    /// - Parameters:
    ///   - code: The code content
    ///   - language: Optional language identifier
    /// - Returns: Markdown fenced code block
    private static func formatCode(_ code: String, language: String?) -> String {
        let languageTag = language ?? ""
        return "```\(languageTag)\n\(code)\n```"
    }

    /// Format URL as markdown link
    /// - Parameters:
    ///   - text: The text containing URL(s)
    ///   - metadata: Metadata containing extracted URL
    /// - Returns: Markdown link or plain URL if extraction fails
    private static func formatURL(_ text: String, metadata: [String: String]) -> String {
        // If metadata contains extracted URL, use it for clean link
        if let extractedURL = metadata["url"] {
            // Clean URL (remove www. prefix if present)
            let cleanURL = extractedURL.hasPrefix("www.") ? "https://\(extractedURL)" : extractedURL

            // For single URL paste, create a simple markdown link
            // Use domain as link text for brevity
            if let domain = extractDomain(from: cleanURL) {
                return "[\(domain)](\(cleanURL))"
            }

            // Fallback to plain URL if domain extraction fails
            return cleanURL
        }

        // If no metadata, return text as-is (may contain embedded URLs)
        return text
    }

    /// Format file path as inline code
    /// - Parameters:
    ///   - text: The text containing file path(s)
    ///   - metadata: Metadata containing extracted path
    /// - Returns: Inline code formatted path
    private static func formatFilePath(_ text: String, metadata: [String: String]) -> String {
        // If metadata contains extracted path, format it as inline code
        if let extractedPath = metadata["path"] {
            return "`\(extractedPath)`"
        }

        // Fallback to wrapping entire text in inline code
        return "`\(text)`"
    }

    /// Format error log with preserved line breaks and structure
    /// - Parameter errorLog: The error log text
    /// - Returns: Formatted error log (plain text with preserved formatting)
    private static func formatErrorLog(_ errorLog: String) -> String {
        // Error logs are typically multi-line with meaningful structure
        // Preserve original formatting but ensure consistent line breaks
        let lines = errorLog.components(separatedBy: .newlines)

        // Remove excessive blank lines (more than 2 consecutive)
        var formattedLines: [String] = []
        var consecutiveBlankLines = 0

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty {
                consecutiveBlankLines += 1
                if consecutiveBlankLines <= 2 {
                    formattedLines.append("")
                }
            } else {
                consecutiveBlankLines = 0
                formattedLines.append(line)
            }
        }

        // Join with newlines and trim trailing whitespace
        return formattedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helper Methods

    /// Extract domain from URL for link text
    /// - Parameter urlString: The URL string
    /// - Returns: Domain string (e.g., "example.com") or nil if invalid
    private static func extractDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }

        // Remove www. prefix if present
        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return domain
    }

    // MARK: - Convenience Methods

    /// Format detected content using LanguageDetector for code snippets
    /// - Parameters:
    ///   - text: The raw text content
    ///   - detectionResult: Content detection result
    /// - Returns: Formatted markdown string
    static func format(_ text: String, detectionResult: ContentDetector.DetectionResult) -> String {
        // If code type, try to detect language
        var language: String?
        if detectionResult.type == .code {
            language = LanguageDetector.detect(text)?.language
        }

        return format(
            text,
            contentType: detectionResult.type,
            language: language,
            metadata: detectionResult.metadata
        )
    }
}
