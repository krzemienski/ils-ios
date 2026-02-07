import SwiftUI

/// Renders a fenced code block with language header, syntax coloring, and copy button.
struct CodeBlockView: View {
    let language: String?
    let code: String
    @State private var showCopied = false

    /// Header background color (#1E293B)
    private let headerBg = Color(red: 30.0/255.0, green: 41.0/255.0, blue: 59.0/255.0)
    /// Code background color (#0F172A)
    private let codeBg = Color(red: 15.0/255.0, green: 23.0/255.0, blue: 42.0/255.0)
    /// Border color: white at 8% opacity
    private let borderColor = Color.white.opacity(0.08)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language header bar
            HStack {
                Text(language ?? "code")
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundColor(ILSTheme.textSecondary)

                Spacer()

                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                        Text(showCopied ? "Copied" : "Copy")
                            .font(.system(.caption2, design: .default, weight: .medium))
                    }
                    .foregroundColor(showCopied ? ILSTheme.success : ILSTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ILSTheme.spacingS)
            .padding(.vertical, 6)
            .background(headerBg)

            // Code content with horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                syntaxHighlightedCode()
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(ILSTheme.spacingS)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(codeBg)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    private func copyCode() {
        UIPasteboard.general.string = code
        HapticManager.notification(.success)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
    }

    // MARK: - Syntax Highlighting

    /// Common keywords for popular languages
    private static let keywords: Set<String> = [
        // Swift / general
        "func", "let", "var", "if", "else", "guard", "return", "import", "struct", "class",
        "enum", "protocol", "extension", "private", "public", "static", "self", "Self",
        "true", "false", "nil", "for", "in", "while", "switch", "case", "default", "break",
        "continue", "throw", "throws", "try", "catch", "async", "await", "init", "deinit",
        "typealias", "associatedtype", "where", "some", "any", "override", "final", "lazy",
        "weak", "unowned", "mutating", "nonmutating", "inout", "defer",
        // JavaScript / TypeScript
        "const", "function", "export", "from", "new", "this", "typeof", "instanceof",
        "undefined", "null", "void", "interface", "type", "implements", "extends",
        "abstract", "readonly", "declare", "module", "namespace", "require",
        // Python
        "def", "class", "print", "range", "len", "list", "dict", "set", "tuple",
        "lambda", "with", "as", "is", "not", "and", "or", "elif", "pass", "raise",
        "yield", "from", "global", "nonlocal", "assert", "del", "except", "finally",
        // Rust / Go / general
        "fn", "mod", "use", "crate", "pub", "impl", "trait", "move", "ref", "mut",
        "unsafe", "extern", "loop", "match", "go", "chan", "select", "package", "main",
    ]

    /// Keyword color (blue)
    private let keywordColor = Color(red: 96.0/255.0, green: 165.0/255.0, blue: 250.0/255.0)
    /// String color (green)
    private let stringColor = Color(red: 134.0/255.0, green: 239.0/255.0, blue: 172.0/255.0)
    /// Comment color (gray)
    private let commentColor = Color(red: 100.0/255.0, green: 116.0/255.0, blue: 139.0/255.0)
    /// Number color (orange)
    private let numberColor = Color(red: 251.0/255.0, green: 191.0/255.0, blue: 36.0/255.0)
    /// Default text color
    private let defaultColor = Color(red: 226.0/255.0, green: 232.0/255.0, blue: 240.0/255.0)

    private func syntaxHighlightedCode() -> Text {
        let lines = code.components(separatedBy: "\n")
        var result = Text("")
        var inBlockComment = false

        for (lineIndex, line) in lines.enumerated() {
            if lineIndex > 0 {
                result = result + Text("\n")
            }
            let (coloredLine, stillInBlock) = colorizeLine(line, inBlockComment: inBlockComment)
            result = result + coloredLine
            inBlockComment = stillInBlock
        }

        return result
    }

    private func colorizeLine(_ line: String, inBlockComment: Bool) -> (Text, Bool) {
        let inBlock = inBlockComment

        // If inside a block comment, render whole line as comment
        if inBlock {
            if let endRange = line.range(of: "*/") {
                let commentPart = String(line[line.startIndex..<endRange.upperBound])
                let rest = String(line[endRange.upperBound...])
                let (restText, _) = colorizeLine(rest, inBlockComment: false)
                return (Text(commentPart).foregroundColor(commentColor) + restText, false)
            }
            return (Text(line).foregroundColor(commentColor), true)
        }

        // Check for line comment (// or #)
        if let commentIdx = findLineComment(in: line) {
            let before = String(line[line.startIndex..<commentIdx])
            let comment = String(line[commentIdx...])
            return (colorizeTokens(before) + Text(comment).foregroundColor(commentColor), false)
        }

        // Check for block comment start
        if let blockStart = line.range(of: "/*") {
            let before = String(line[line.startIndex..<blockStart.lowerBound])
            if let blockEnd = line.range(of: "*/", range: blockStart.upperBound..<line.endIndex) {
                let comment = String(line[blockStart.lowerBound..<blockEnd.upperBound])
                let after = String(line[blockEnd.upperBound...])
                let (afterText, _) = colorizeLine(after, inBlockComment: false)
                return (colorizeTokens(before) + Text(comment).foregroundColor(commentColor) + afterText, false)
            } else {
                let comment = String(line[blockStart.lowerBound...])
                return (colorizeTokens(before) + Text(comment).foregroundColor(commentColor), true)
            }
        }

        return (colorizeTokens(line), inBlock)
    }

    private func findLineComment(in line: String) -> String.Index? {
        var inString = false
        var stringChar: Character = "\""
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if inString {
                if ch == "\\" {
                    // Skip escaped char
                    i = line.index(after: i)
                    if i < line.endIndex { i = line.index(after: i) }
                    continue
                }
                if ch == stringChar { inString = false }
            } else {
                if ch == "\"" || ch == "'" {
                    inString = true
                    stringChar = ch
                } else if ch == "/" {
                    let next = line.index(after: i)
                    if next < line.endIndex && line[next] == "/" {
                        return i
                    }
                } else if ch == "#" {
                    // Python-style comment (rough heuristic)
                    let lang = language?.lowercased() ?? ""
                    if lang == "python" || lang == "py" || lang == "bash" || lang == "sh" || lang == "yaml" || lang == "yml" {
                        return i
                    }
                }
            }
            i = line.index(after: i)
        }
        return nil
    }

    private func colorizeTokens(_ text: String) -> Text {
        var result = Text("")
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // String literal
            if remaining.first == "\"" || remaining.first == "'" {
                let quote = remaining.first!
                var endIdx = remaining.index(after: remaining.startIndex)
                while endIdx < remaining.endIndex {
                    if remaining[endIdx] == "\\" {
                        endIdx = remaining.index(after: endIdx)
                        if endIdx < remaining.endIndex { endIdx = remaining.index(after: endIdx) }
                        continue
                    }
                    if remaining[endIdx] == quote {
                        endIdx = remaining.index(after: endIdx)
                        break
                    }
                    endIdx = remaining.index(after: endIdx)
                }
                let str = String(remaining[remaining.startIndex..<endIdx])
                result = result + Text(str).foregroundColor(stringColor)
                remaining = remaining[endIdx...]
                continue
            }

            // Number
            if let first = remaining.first, first.isNumber {
                var endIdx = remaining.startIndex
                while endIdx < remaining.endIndex && (remaining[endIdx].isNumber || remaining[endIdx] == ".") {
                    endIdx = remaining.index(after: endIdx)
                }
                let num = String(remaining[remaining.startIndex..<endIdx])
                result = result + Text(num).foregroundColor(numberColor)
                remaining = remaining[endIdx...]
                continue
            }

            // Word (potential keyword)
            if let first = remaining.first, first.isLetter || first == "_" {
                var endIdx = remaining.startIndex
                while endIdx < remaining.endIndex && (remaining[endIdx].isLetter || remaining[endIdx].isNumber || remaining[endIdx] == "_") {
                    endIdx = remaining.index(after: endIdx)
                }
                let word = String(remaining[remaining.startIndex..<endIdx])
                if Self.keywords.contains(word) {
                    result = result + Text(word).foregroundColor(keywordColor)
                } else {
                    result = result + Text(word).foregroundColor(defaultColor)
                }
                remaining = remaining[endIdx...]
                continue
            }

            // Other character
            let ch = String(remaining[remaining.startIndex...remaining.startIndex])
            result = result + Text(ch).foregroundColor(defaultColor)
            remaining = remaining[remaining.index(after: remaining.startIndex)...]
        }

        return result
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            CodeBlockView(language: "swift", code: """
            func greet(_ name: String) -> String {
                let message = "Hello, \\(name)!"
                // Return greeting
                return message
            }
            """)

            CodeBlockView(language: "python", code: """
            def fibonacci(n):
                # Calculate fibonacci
                if n <= 1:
                    return n
                return fibonacci(n - 1) + fibonacci(n - 2)
            """)

            CodeBlockView(language: nil, code: "npm install express")
        }
        .padding()
    }
    .background(Color.black)
}
