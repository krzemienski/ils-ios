import SwiftUI

/// Red-tinted card for displaying error messages in the chat.
/// Uses theme error color at low opacity for background, with full error color for icon and border.
struct ErrorMessageView: View {
    let message: String

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.error)
                .frame(width: 24)

            Text(message)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.error)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.spacingSM)
        .background(theme.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .strokeBorder(theme.error.opacity(0.3), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}
