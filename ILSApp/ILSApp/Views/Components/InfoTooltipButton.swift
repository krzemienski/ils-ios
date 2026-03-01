import SwiftUI

/// A small info button that shows a tooltip popover with explanatory text.
///
/// Used in Settings and configuration screens to provide context
/// for settings that may not be self-explanatory.
struct InfoTooltipButton: View {
    let text: String
    @State private var isShowing = false
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Button {
            isShowing.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowing) {
            Text(text)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .padding(theme.spacingSM)
                .frame(maxWidth: 280)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("More information")
        .accessibilityHint(text)
    }
}

#Preview {
    HStack {
        Text("Extended Thinking")
        InfoTooltipButton(text: "Allows Claude to use internal reasoning before responding.")
    }
    .padding()
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
