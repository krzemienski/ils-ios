import SwiftUI

/// Red-tinted card that surfaces an error string inside the chat message flow.
///
/// Renders an `exclamationmark.triangle.fill` icon alongside the error text, both in
/// `theme.error` color. The card background is `theme.error` at 10 % opacity with a
/// 0.5 pt stroke at 30 % opacity, making errors visually distinct without overpowering
/// the surrounding conversation.
///
/// When `onRetry` is provided a plain "Try Again" button is appended below the message
/// text. The entire card is collapsed into a single accessibility element whose label
/// includes a prompt to tap "Try Again" when the retry handler is present.
///
/// ## Topics
/// ### Input Properties
/// - ``message`` - The human-readable error string to display
///
/// ### Callbacks
/// - ``onRetry`` - Optional closure invoked when the user taps "Try Again"; omit to hide
///   the retry button
struct ErrorMessageView: View {
    /// The human-readable error string to display inside the card.
    let message: String
    /// Called when the user taps "Try Again". When `nil`, the retry button is hidden.
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
