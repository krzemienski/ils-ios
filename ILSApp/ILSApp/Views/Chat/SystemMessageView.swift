import SwiftUI

/// Centered text display for system events in the chat (e.g. "Session started", "Session forked").
/// Uses textTertiary color and smaller font to visually distinguish from user/AI messages.
struct SystemMessageView: View {
    let message: String

    @Environment(\.theme) private var theme: any AppTheme

    var body: some View {
        HStack {
            Spacer()
            Text(message)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.vertical, theme.spacingXS)
            Spacer()
        }
        .accessibilityLabel("System message: \(message)")
    }
}
