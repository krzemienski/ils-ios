import SwiftUI

/// Banner displayed when the device is offline.
///
/// Slides in from the top with animation and shows a message
/// indicating cached data is being displayed.
struct OfflineIndicator: View {
    let isOffline: Bool

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isOffline {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: theme.fontCaption, weight: .semibold))

                Text("Offline \u{2014} showing cached data")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
            }
            .foregroundStyle(theme.warning)
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingXS)
            .frame(maxWidth: .infinity)
            .background(
                theme.warning.opacity(0.15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(theme.warning.opacity(0.3), lineWidth: 0.5)
                    )
            )
            .transition(
                reduceMotion
                    ? .opacity
                    : .move(edge: .top).combined(with: .opacity)
            )
            .accessibilityLabel("Offline mode. Showing cached data.")
        }
    }
}

#Preview {
    VStack {
        OfflineIndicator(isOffline: true)
        Spacer()
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
