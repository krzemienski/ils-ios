import SwiftUI

struct AccentButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void

    @State private var isPressed = false
    @State private var resetTask: Task<Void, Never>?

    init(_ title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button {
            guard !isLoading else { return }
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
                if isLoading {
                    ProgressView()
                        .tint(theme.textOnAccent)
                        .controlSize(.small)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                }
                Text(title)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
            }
            .foregroundColor(theme.textOnAccent)
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM + 2)
            .background(theme.accent.opacity(isEnabled ? 1.0 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .scaleEffect(isPressed ? 0.85 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : (isEnabled ? 1.0 : 0.5))
        .saturation(isEnabled ? 1.0 : 0.3)
        .accessibilityLabel(isLoading ? "\(title), loading" : title)
        .accessibilityAddTraits(isLoading ? .updatesFrequently : [])
        .onDisappear { resetTask?.cancel() }
    }
}
