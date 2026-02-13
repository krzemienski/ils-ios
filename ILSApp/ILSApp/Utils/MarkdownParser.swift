import Foundation

/// Utility for parsing markdown text and extracting code blocks
enum MarkdownParser {
    /// Represents a segment of parsed text
    enum TextSegment {
        case plainText(String)
        case codeBlock(CodeBlock)
        case inlineCode(String)
    }

    /// Represents a code block with optional language hint
    struct CodeBlock {
        let language: String?
        let code: String
    }

    /// Parse markdown text into segments of plain text and code blocks
    /// - Parameter text: The markdown text to parse
    /// - Returns: Array of text segments (plain text, code blocks, inline code)
    static func parse(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentPosition = text.startIndex

        // Regular expression for code blocks: ```language\ncode\n```
        let codeBlockPattern = #"```([a-zA-Z0-9_+-]*)\n([\s\S]*?)```"#

        guard let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) else {
            // If regex fails, return entire text as plain text
            return [.plainText(text)]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let matchRange = match.range
            let matchStartIndex = text.index(text.startIndex, offsetBy: matchRange.location)

            // Add any plain text before this code block
            if currentPosition < matchStartIndex {
                let plainText = String(text[currentPosition..<matchStartIndex])
                segments.append(contentsOf: parseInlineCode(plainText))
            }

            // Extract language and code
            let languageRange = match.range(at: 1)
            let codeRange = match.range(at: 2)

            let language = languageRange.location != NSNotFound ? nsText.substring(with: languageRange) : nil
            let code = codeRange.location != NSNotFound ? nsText.substring(with: codeRange) : ""

            // Add code block segment
            let codeBlock = CodeBlock(
                language: language?.isEmpty == false ? language : nil,
                code: code
            )
            segments.append(.codeBlock(codeBlock))

            // Update current position
            currentPosition = text.index(text.startIndex, offsetBy: matchRange.location + matchRange.length)
        }

        // Add any remaining plain text after the last code block
        if currentPosition < text.endIndex {
            let remainingText = String(text[currentPosition..<text.endIndex])
            segments.append(contentsOf: parseInlineCode(remainingText))
        }

        // If no code blocks found, parse for inline code
        if segments.isEmpty {
            return parseInlineCode(text)
        }

        return segments
    }

    /// Parse inline code (single backticks) from plain text
    /// - Parameter text: The text to parse for inline code
    /// - Returns: Array of text segments (plain text and inline code)
    private static func parseInlineCode(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentPosition = text.startIndex

        // Regular expression for inline code: `code`
        let inlineCodePattern = #"`([^`]+)`"#

        guard let regex = try? NSRegularExpression(pattern: inlineCodePattern, options: []) else {
            // If regex fails, return entire text as plain text
            return text.isEmpty ? [] : [.plainText(text)]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let matchRange = match.range
            let matchStartIndex = text.index(text.startIndex, offsetBy: matchRange.location)

            // Add any plain text before this inline code
            if currentPosition < matchStartIndex {
                let plainText = String(text[currentPosition..<matchStartIndex])
                if !plainText.isEmpty {
                    segments.append(.plainText(plainText))
                }
            }

            // Extract inline code content (without backticks)
            let codeRange = match.range(at: 1)
            if codeRange.location != NSNotFound {
                let code = nsText.substring(with: codeRange)
                segments.append(.inlineCode(code))
            }

            // Update current position
            currentPosition = text.index(text.startIndex, offsetBy: matchRange.location + matchRange.length)
        }

        // Add any remaining plain text
        if currentPosition < text.endIndex {
            let remainingText = String(text[currentPosition..<text.endIndex])
            if !remainingText.isEmpty {
                segments.append(.plainText(remainingText))
            }
        }

        // If no inline code found, return plain text (if not empty)
        if segments.isEmpty && !text.isEmpty {
            return [.plainText(text)]
        }

        return segments
    }
}
