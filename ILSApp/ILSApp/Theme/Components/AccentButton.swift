import SwiftUI

struct AccentButton: View {
    @Environment(\.theme) private var theme
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
                        .font(.system(size: theme.fontBody))
                }
                Text(title)
                    .font(.system(size: theme.fontBody, weight: .semibold))
            }
            .foregroundColor(theme.textOnAccent)
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM + 2)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .accessibilityLabel(title)
    }
}
