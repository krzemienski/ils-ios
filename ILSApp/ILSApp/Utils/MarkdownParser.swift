import Foundation

/// Represents a code block extracted from markdown text
public struct CodeBlock: Identifiable {
    public let id: UUID
    public let language: String?
    public let code: String
    public let range: Range<String.Index>

    public init(
        id: UUID = UUID(),
        language: String?,
        code: String,
        range: Range<String.Index>
    ) {
        self.id = id
        self.language = language
        self.code = code
        self.range = range
    }
}

/// Represents a segment of text that can be either plain text, inline code, or a code block
public enum TextSegment: Identifiable {
    case text(String)
    case inlineCode(String)
    case codeBlock(CodeBlock)

    public var id: String {
        switch self {
        case .text(let content):
            return "text-\(content.hashValue)"
        case .inlineCode(let content):
            return "inline-\(content.hashValue)"
        case .codeBlock(let block):
            return "code-\(block.id)"
        }
    }
}

/// Parser for extracting code blocks from markdown text
public struct MarkdownParser {
    /// Parse markdown text and extract code blocks along with plain text segments
    /// - Parameter text: The markdown text to parse
    /// - Returns: An array of text segments (plain text, inline code, and code blocks) in order
    public static func parse(_ text: String) -> [TextSegment] {
        // Handle empty or whitespace-only text
        guard !text.isEmpty else {
            return [.text(text)]
        }

        var segments: [TextSegment] = []
        var currentIndex = text.startIndex

        // First pass: Extract fenced code blocks (```)
        // Pattern matches: ```optionalLanguage\n...code...\n```
        // Made more flexible to handle edge cases:
        // - Optional newline after opening backticks
        // - Handles code blocks without closing backticks (malformed markdown)
        let fencedPattern = #"```([^\n]*)\n?([\s\S]*?)(?:```|$)"#

        guard let fencedRegex = try? NSRegularExpression(pattern: fencedPattern, options: []) else {
            // If regex creation fails (unlikely), fall back to parsing inline code only
            return parseInlineCode(in: text, from: text.startIndex, to: text.endIndex)
        }

        let nsString = text as NSString
        let fencedMatches = fencedRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in fencedMatches {
            // Get the full match range
            let matchRange = match.range
            guard let swiftRange = Range(matchRange, in: text) else { continue }

            // Add any text before this code block (parse for inline code)
            if currentIndex < swiftRange.lowerBound {
                let textSegments = parseInlineCode(in: text, from: currentIndex, to: swiftRange.lowerBound)
                segments.append(contentsOf: textSegments)
            }

            // Extract language (if present)
            var language: String? = nil
            if match.numberOfRanges > 1 {
                let languageRange = match.range(at: 1)
                if languageRange.location != NSNotFound,
                   let swiftLanguageRange = Range(languageRange, in: text) {
                    let languageString = String(text[swiftLanguageRange])
                        .trimmingCharacters(in: .whitespaces)
                    if !languageString.isEmpty {
                        language = languageString
                    }
                }
            }

            // Extract code content
            var code = ""
            if match.numberOfRanges > 2 {
                let codeRange = match.range(at: 2)
                if codeRange.location != NSNotFound,
                   let swiftCodeRange = Range(codeRange, in: text) {
                    code = String(text[swiftCodeRange])
                }
            }

            // Only create code block if it has content or is properly formed
            // Skip empty code blocks with no language
            if !code.isEmpty || language != nil {
                let codeBlock = CodeBlock(
                    language: language,
                    code: code,
                    range: swiftRange
                )
                segments.append(.codeBlock(codeBlock))
            }

            // Move current index past this code block
            currentIndex = swiftRange.upperBound
        }

        // Add any remaining text after the last code block (parse for inline code)
        if currentIndex < text.endIndex {
            let textSegments = parseInlineCode(in: text, from: currentIndex, to: text.endIndex)
            segments.append(contentsOf: textSegments)
        }

        // If no segments were created, return entire text as single segment
        if segments.isEmpty {
            return [.text(text)]
        }

        return segments
    }

    /// Parse inline code (single backticks) in a text range
    /// - Parameters:
    ///   - text: The full text
    ///   - start: Start index of range to parse
    ///   - end: End index of range to parse
    /// - Returns: Array of text segments (text and inline code)
    private static func parseInlineCode(in text: String, from start: String.Index, to end: String.Index) -> [TextSegment] {
        let substring = String(text[start..<end])

        // Handle empty substring
        guard !substring.isEmpty else {
            return []
        }

        // Skip if only whitespace
        if substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [.text(substring)]
        }

        var segments: [TextSegment] = []
        var currentIndex = substring.startIndex

        // Pattern to match inline code: `code`
        // Handles edge cases:
        // - Doesn't match code blocks (```)
        // - Handles unclosed backticks (malformed)
        // - Handles escaped backticks
        let inlinePattern = #"(?<!`)(`{1})(?!`)(.+?)(?<!`)(`{1})(?!`)"#

        guard let inlineRegex = try? NSRegularExpression(pattern: inlinePattern, options: []) else {
            // If regex fails, return as plain text
            return [.text(substring)]
        }

        let nsSubstring = substring as NSString
        let inlineMatches = inlineRegex.matches(in: substring, options: [], range: NSRange(location: 0, length: nsSubstring.length))

        for match in inlineMatches {
            // Get the code content (group 2)
            guard match.numberOfRanges > 2 else { continue }

            let matchRange = match.range
            guard let swiftRange = Range(matchRange, in: substring) else { continue }

            // Add any plain text before this inline code
            if currentIndex < swiftRange.lowerBound {
                let plainText = String(substring[currentIndex..<swiftRange.lowerBound])
                if !plainText.isEmpty {
                    segments.append(.text(plainText))
                }
            }

            // Extract the code content
            let codeRange = match.range(at: 2)
            if codeRange.location != NSNotFound,
               let swiftCodeRange = Range(codeRange, in: substring) {
                let code = String(substring[swiftCodeRange])
                // Only add non-empty inline code
                if !code.isEmpty {
                    segments.append(.inlineCode(code))
                }
            }

            currentIndex = swiftRange.upperBound
        }

        // Add any remaining text after the last inline code
        if currentIndex < substring.endIndex {
            let remainingText = String(substring[currentIndex..<substring.endIndex])
            if !remainingText.isEmpty {
                segments.append(.text(remainingText))
            }
        }

        // If no inline code was found, return entire substring as text
        if segments.isEmpty {
            return [.text(substring)]
        }

        return segments
    }

    /// Extract only code blocks from markdown text
    /// - Parameter text: The markdown text to parse
    /// - Returns: An array of code blocks found in the text
    public static func extractCodeBlocks(_ text: String) -> [CodeBlock] {
        let segments = parse(text)
        return segments.compactMap { segment in
            if case .codeBlock(let block) = segment {
                return block
            }
            return nil
        }
    }
}
