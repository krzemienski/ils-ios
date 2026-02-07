import SwiftUI

/// Renders markdown text with proper formatting for chat messages.
/// Handles headers, code blocks, inline code, bold, italic, links, and lists.
struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let content):
            headingView(level: level, content: content)
        case .codeBlock(let language, let code):
            CodeBlockView(language: language, code: code)
        case .paragraph(let content):
            inlineMarkdownText(content)
                .font(ILSTheme.bodyFont)
        case .listItem(let content):
            HStack(alignment: .top, spacing: ILSTheme.spacingS) {
                Text("\u{2022}")
                    .font(ILSTheme.bodyFont)
                    .foregroundColor(ILSTheme.secondaryText)
                inlineMarkdownText(content)
                    .font(ILSTheme.bodyFont)
            }
        case .orderedListItem(let number, let content):
            HStack(alignment: .top, spacing: ILSTheme.spacingS) {
                Text("\(number).")
                    .font(ILSTheme.bodyFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .frame(minWidth: 20, alignment: .trailing)
                inlineMarkdownText(content)
                    .font(ILSTheme.bodyFont)
            }
        }
    }

    private func headingView(level: Int, content: String) -> some View {
        let font: Font = switch level {
        case 1: .system(.title, design: .default, weight: .bold)
        case 2: .system(.title2, design: .default, weight: .bold)
        case 3: .system(.title3, design: .default, weight: .semibold)
        default: .system(.headline, design: .default, weight: .semibold)
        }
        return Text(content)
            .font(font)
            .foregroundColor(ILSTheme.primaryText)
            .padding(.top, level <= 2 ? ILSTheme.spacingXS : 0)
    }

    /// Renders inline markdown (bold, italic, inline code, links) as styled Text
    private func inlineMarkdownText(_ content: String) -> Text {
        var result = Text("")
        var remaining = content[content.startIndex...]

        while !remaining.isEmpty {
            // Link: [text](url)
            if remaining.hasPrefix("[") {
                let afterBracket = remaining.index(after: remaining.startIndex)
                if let closeBracket = remaining[afterBracket...].firstIndex(of: "]") {
                    let linkText = String(remaining[afterBracket..<closeBracket])
                    let afterClose = remaining.index(after: closeBracket)
                    if afterClose < remaining.endIndex && remaining[afterClose] == "(" {
                        let afterParen = remaining.index(after: afterClose)
                        if let closeParen = remaining[afterParen...].firstIndex(of: ")") {
                            let urlString = String(remaining[afterParen..<closeParen])
                            if let url = URL(string: urlString) {
                                result = result + Text(.init("[\(linkText)](\(url.absoluteString))"))
                                    .foregroundColor(ILSTheme.info)
                                    .underline()
                            } else {
                                result = result + Text(linkText)
                                    .foregroundColor(ILSTheme.info)
                            }
                            remaining = remaining[remaining.index(after: closeParen)...]
                            continue
                        }
                    }
                }
            }

            // Inline code: `code`
            if remaining.hasPrefix("`") {
                let afterTick = remaining.index(after: remaining.startIndex)
                if let endTick = remaining[afterTick...].firstIndex(of: "`") {
                    let code = String(remaining[afterTick..<endTick])
                    result = result + Text(code)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(ILSTheme.accent)
                    remaining = remaining[remaining.index(after: endTick)...]
                    continue
                }
            }

            // Bold: **text**
            if remaining.hasPrefix("**") {
                let afterStars = remaining.index(remaining.startIndex, offsetBy: 2)
                if let endRange = remaining[afterStars...].range(of: "**") {
                    let bold = String(remaining[afterStars..<endRange.lowerBound])
                    result = result + Text(bold).bold()
                    remaining = remaining[endRange.upperBound...]
                    continue
                }
            }

            // Italic: *text* (single asterisk, not followed by another)
            if remaining.hasPrefix("*") && !remaining.hasPrefix("**") {
                let afterStar = remaining.index(after: remaining.startIndex)
                if let endStar = remaining[afterStar...].firstIndex(of: "*") {
                    let italic = String(remaining[afterStar..<endStar])
                    result = result + Text(italic).italic()
                    remaining = remaining[remaining.index(after: endStar)...]
                    continue
                }
            }

            // Regular text: consume until next special character
            var endIndex = remaining.index(after: remaining.startIndex)
            while endIndex < remaining.endIndex {
                let ch = remaining[endIndex]
                if ch == "`" || ch == "*" || ch == "[" {
                    break
                }
                endIndex = remaining.index(after: endIndex)
            }
            let plain = String(remaining[remaining.startIndex..<endIndex])
            result = result + Text(plain)
            remaining = remaining[endIndex...]
        }

        return result
    }

    // MARK: - Block Parser

    private func parseBlocks() -> [MarkdownBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var i = 0
        var currentParagraph: [String] = []

        func flushParagraph() {
            if !currentParagraph.isEmpty {
                let paragraphText = currentParagraph.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !paragraphText.isEmpty {
                    blocks.append(.paragraph(content: paragraphText))
                }
                currentParagraph = []
            }
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block: ```
            if trimmed.hasPrefix("```") {
                flushParagraph()
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }
                let code = codeLines.joined(separator: "\n")
                blocks.append(.codeBlock(language: language.isEmpty ? nil : language, code: code))
                i += 1
                continue
            }

            // Heading: # ## ### etc.
            if let headingMatch = parseHeading(trimmed) {
                flushParagraph()
                blocks.append(.heading(level: headingMatch.level, content: headingMatch.content))
                i += 1
                continue
            }

            // Unordered list: - item or * item
            if let listContent = parseUnorderedListItem(trimmed) {
                flushParagraph()
                blocks.append(.listItem(content: listContent))
                i += 1
                continue
            }

            // Ordered list: 1. item
            if let (number, listContent) = parseOrderedListItem(trimmed) {
                flushParagraph()
                blocks.append(.orderedListItem(number: number, content: listContent))
                i += 1
                continue
            }

            // Empty line: paragraph break
            if trimmed.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // Regular text line
            currentParagraph.append(trimmed)
            i += 1
        }

        flushParagraph()
        return blocks
    }

    private func parseHeading(_ line: String) -> (level: Int, content: String)? {
        var level = 0
        var idx = line.startIndex
        while idx < line.endIndex && line[idx] == "#" && level < 6 {
            level += 1
            idx = line.index(after: idx)
        }
        guard level > 0,
              idx < line.endIndex,
              line[idx] == " " else { return nil }
        let content = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
        return (level, content)
    }

    private func parseUnorderedListItem(_ line: String) -> String? {
        if (line.hasPrefix("- ") || line.hasPrefix("* ")) && !line.hasPrefix("**") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private func parseOrderedListItem(_ line: String) -> (Int, String)? {
        let pattern = /^(\d+)\.\s+(.+)$/
        if let match = line.firstMatch(of: pattern) {
            let number = Int(match.1) ?? 1
            let content = String(match.2)
            return (number, content)
        }
        return nil
    }
}

// MARK: - Block Types

private enum MarkdownBlock {
    case heading(level: Int, content: String)
    case codeBlock(language: String?, code: String)
    case paragraph(content: String)
    case listItem(content: String)
    case orderedListItem(number: Int, content: String)
}

#Preview {
    ScrollView {
        MarkdownTextView(text: """
        ## Getting Started

        Here's a **bold** statement and some *italic* text.

        Check out [SwiftUI docs](https://developer.apple.com/swiftui/) for more.

        ### Code Example

        ```swift
        func greet(_ name: String) -> String {
            return "Hello, \\(name)!"
        }
        ```

        Some features:

        - First item with `inline code`
        - Second item
        - Third **important** item

        1. Step one
        2. Step two
        3. Step three

        Regular paragraph text continues here.
        """)
        .foregroundColor(ILSTheme.primaryText)
        .padding()
    }
    .background(Color.black)
}
