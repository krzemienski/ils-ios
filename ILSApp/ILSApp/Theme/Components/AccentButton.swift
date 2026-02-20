import SwiftUI

struct AccentButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacingSM) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                }
                Text(title)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
            }
            .foregroundColor(theme.textOnAccent)
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM + 2)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .accessibilityLabel(title)
        .opacity(isEnabled ? 1.0 : 0.5)
        .saturation(isEnabled ? 1.0 : 0.3)
    }
}
