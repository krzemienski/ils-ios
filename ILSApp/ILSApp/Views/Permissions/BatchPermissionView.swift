import SwiftUI

/// Batch action bar shown when multi-select mode is active in ``PermissionInboxView``.
///
/// Displays the count of selected permission requests alongside **Allow All** and
/// **Deny All** action buttons. Intended for placement in `.bottomBar` toolbar items
/// so it sits above the tab bar / home indicator.
///
/// The view is purely presentational — callers supply the callbacks and count.
///
/// ## Topics
/// ### Inputs
/// - ``selectedCount`` - Number of currently selected permission requests
/// - ``onAllowAll`` - Called when the user taps Allow All
/// - ``onDenyAll`` - Called when the user taps Deny All
struct BatchPermissionView: View {

    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Number of currently selected permission requests.
    let selectedCount: Int
    /// Called when the user taps Allow All.
    let onAllowAll: () -> Void
    /// Called when the user taps Deny All.
    let onDenyAll: () -> Void

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            // Selected count badge
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                Text("\(selectedCount) selected")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            // Deny All button
            Button {
                onDenyAll()
            } label: {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    Text("Deny All")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.error)
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, theme.spacingXS)
                .background(theme.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .accessibilityLabel("Deny all \(selectedCount) selected permissions")

            // Allow All button
            Button {
                onAllowAll()
            } label: {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    Text("Allow All")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.textOnAccent)
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, theme.spacingXS)
                .background(theme.success)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .accessibilityLabel("Allow all \(selectedCount) selected permissions")
        }
    }
}

#Preview {
    BatchPermissionView(
        selectedCount: 3,
        onAllowAll: {},
        onDenyAll: {}
    )
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    .padding()
}
