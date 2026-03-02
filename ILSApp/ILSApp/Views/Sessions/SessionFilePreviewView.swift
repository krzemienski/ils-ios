import SwiftUI

/// Syntax-highlighted file content preview for a session file change.
///
/// Displays the file content using ``CodeBlockView`` for syntax highlighting with line
/// numbers, copy, and share functionality. Shows the full file path in the header and the
/// inferred language badge through the code block.
struct SessionFilePreviewView: View {
    let file: SessionFileBrowserViewModel.PreviewFile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingMD) {
                    // Full file path
                    Text(file.path)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, theme.spacingMD)
                        .padding(.top, theme.spacingSM)

                    // Syntax-highlighted code block
                    CodeBlockView(code: file.content, language: file.language)
                        .padding(.horizontal, theme.spacingMD)
                }
                .padding(.bottom, theme.spacingMD)
            }
            .background(theme.bgPrimary)
            .navigationTitle(file.name)
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(theme.entitySystem)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Swift File Preview") {
    SessionFilePreviewView(
        file: SessionFileBrowserViewModel.PreviewFile(
            name: "ContentView.swift",
            path: "Sources/App/Views/ContentView.swift",
            content: """
            import SwiftUI

            struct ContentView: View {
                @State private var counter = 0

                var body: some View {
                    VStack(spacing: 16) {
                        Text("Count: \\(counter)")
                            .font(.title)
                        HStack {
                            Button("–") { counter -= 1 }
                            Button("+") { counter += 1 }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            """,
            language: "swift"
        )
    )
}

#Preview("Python File Preview") {
    SessionFilePreviewView(
        file: SessionFileBrowserViewModel.PreviewFile(
            name: "main.py",
            path: "scripts/main.py",
            content: """
            def greet(name: str) -> str:
                return f"Hello, {name}!"

            if __name__ == "__main__":
                print(greet("World"))
            """,
            language: "python"
        )
    )
}

#Preview("No Language Preview") {
    SessionFilePreviewView(
        file: SessionFileBrowserViewModel.PreviewFile(
            name: "README.md",
            path: "README.md",
            content: """
            # My Project

            A short description of what this project does.

            ## Installation

            Run `npm install` to install dependencies.
            """,
            language: nil
        )
    )
}
