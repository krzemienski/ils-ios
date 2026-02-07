import SwiftUI
import HighlightSwift

/// Renders a fenced code block with language header, grammar-aware syntax highlighting,
/// optional line numbers, and copy button.
struct CodeBlockView: View {
    let language: String?
    let code: String
    @State private var showCopied = false
    @State private var highlightedCode: AttributedString?
    @State private var detectedLanguage: String?
    @State private var showLineNumbers = true

    /// Header background color (#1E293B)
    private let headerBg = Color(red: 30.0/255.0, green: 41.0/255.0, blue: 59.0/255.0)
    /// Code background color (#0F172A)
    private let codeBg = Color(red: 15.0/255.0, green: 23.0/255.0, blue: 42.0/255.0)
    /// Border color: white at 8% opacity
    private let borderColor = Color.white.opacity(0.08)
    /// Line number color
    private let lineNumberColor = Color(red: 100.0/255.0, green: 116.0/255.0, blue: 139.0/255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            codeContent
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Code block, \(detectedLanguage ?? language ?? "code")")
        .task {
            await performHighlight()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(detectedLanguage ?? language ?? "code")
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
            .accessibilityLabel(showCopied ? "Code copied to clipboard" : "Copy code to clipboard")
        }
        .padding(.horizontal, ILSTheme.spacingS)
        .padding(.vertical, 6)
        .background(headerBg)
    }

    // MARK: - Code Content

    private var codeContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                if showLineNumbers {
                    lineNumbersGutter
                }
                codeText
            }
        }
        .background(codeBg)
    }

    private var codeText: some View {
        Group {
            if let highlighted = highlightedCode {
                Text(highlighted)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            } else {
                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(Color(red: 226.0/255.0, green: 232.0/255.0, blue: 240.0/255.0))
                    .textSelection(.enabled)
            }
        }
        .padding(ILSTheme.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Line Numbers

    private var lineNumbersGutter: some View {
        let lineCount = max(code.components(separatedBy: "\n").count, 1)
        return VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...lineCount, id: \.self) { lineNum in
                Text("\(lineNum)")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(lineNumberColor)
                    .frame(minWidth: 30, alignment: .trailing)
            }
        }
        .padding(.vertical, ILSTheme.spacingS)
        .padding(.leading, ILSTheme.spacingS)
        .padding(.trailing, 4)
        .background(codeBg.opacity(0.5))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(borderColor)
                .frame(width: 1)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showLineNumbers.toggle()
            }
        }
    }

    // MARK: - Highlighting

    private func performHighlight() async {
        let highlight = Highlight()
        do {
            let mode: HighlightMode
            if let lang = language, !lang.isEmpty {
                mode = .languageAlias(lang)
            } else {
                mode = .automatic
            }
            let result = try await highlight.request(code, mode: mode, colors: .dark(.xcode))
            self.highlightedCode = result.attributedText
            if language == nil || language?.isEmpty == true {
                self.detectedLanguage = result.languageName
            }
        } catch {
            // Fallback: unhighlighted code already displayed
        }
    }

    // MARK: - Actions

    private func copyCode() {
        UIPasteboard.general.string = code
        HapticManager.notification(.success)
        showCopied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showCopied = false
        }
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
