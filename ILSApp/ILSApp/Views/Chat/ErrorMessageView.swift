import SwiftUI

/// Red-tinted card for displaying error messages in the chat.
/// Uses theme error color at low opacity for background, with full error color for icon and border.
struct ErrorMessageView: View {
    let message: String
    var onRetry: (() -> Void)?

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
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

            if let onRetry {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.plain)
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.error)
            }
        }
        .padding(theme.spacingSM)
        .background(theme.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .strokeBorder(theme.error.opacity(0.3), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(onRetry != nil ? "Error: \(message). Tap Try Again to retry." : "Error: \(message)")
    }
}
