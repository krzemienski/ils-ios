import SwiftUI

/// Scrollable terminal output display.
///
/// Renders accumulated ``AttributedString`` output lines in a monospace font, auto-scrolling
/// to the bottom whenever the `lines` array grows.  The view uses a `LazyVStack` inside a
/// `ScrollViewReader` so that only visible rows are materialised while still supporting
/// efficient scroll-to-bottom via the sentinel `"bottom"` anchor.
///
/// A `Color.clear` spacer anchored to `"bottom"` is placed after the last line so that
/// `proxy.scrollTo("bottom")` always lands below all content regardless of viewport height.
///
/// ## Topics
/// ### Input Properties
/// - ``lines`` - Parsed output lines produced by the terminal view model
///
/// ### Scroll Management
/// - Scrolls to `"bottom"` anchor on every `lines.count` change via `.onChange`
struct TerminalOutputView: View {

    /// Parsed terminal output lines ready for rendering.
    let lines: [AttributedString]

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Sentinel anchor — always sits below all content
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, theme.spacingSM)
            }
            .background(theme.bgPrimary)
            .onChange(of: lines.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    // MARK: - Helpers

    /// Scrolls to the bottom sentinel, respecting the Reduce Motion accessibility setting.
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo("bottom", anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

#Preview {
    let sampleLines: [AttributedString] = {
        var prompt = AttributedString("$ ls -la")
        prompt.font = .system(.body, design: .monospaced)
        if let range = prompt.range(of: "$ ") {
            prompt[range].foregroundColor = .green
        }

        var output = AttributedString("total 48\ndrwxr-xr-x  8 user staff  256 Mar  2 10:00 .\ndrwxr-xr-x 12 user staff  384 Mar  2 09:58 ..")
        output.font = .system(.body, design: .monospaced)

        var errorLine = AttributedString("error: permission denied")
        errorLine.font = .system(.body, design: .monospaced)
        errorLine.foregroundColor = .red

        return [prompt, output, errorLine]
    }()

    TerminalOutputView(lines: sampleLines)
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
        .frame(height: 300)
}
