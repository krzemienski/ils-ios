import SwiftUI

struct AccentButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let icon: String?
    let action: () -> Void

    @State private var isPressed = false
    @State private var resetTask: Task<Void, Never>?

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button {
            HapticManager.impact(.medium)

            if !reduceMotion {
                isPressed = true
            }
            action()

            if !reduceMotion {
                resetTask?.cancel()
                resetTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    isPressed = false
                }
            }
        } label: {
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
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .accessibilityLabel(title)
        .onDisappear { resetTask?.cancel() }
    }
}
