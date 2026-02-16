import SwiftUI

/// Single pulsing orange dot with "Claude is thinking..." text.
/// Left-aligned, minimal footprint on pure black background.
struct StreamingIndicatorView: View {
    var statusText: String?

    @State private var isPulsing = false
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            // Leading accent bar to match assistant cards
            RoundedRectangle(cornerRadius: 1)
                .fill(theme.accent)
                .frame(width: 2, height: 16)

            Circle()
                .fill(theme.accent)
                .frame(width: 6, height: 6)
                .opacity(isPulsing ? 1.0 : 0.3)

            Text(statusText ?? "Claude is thinking\u{2026}")
                .font(.system(size: 12, design: theme.fontDesign).leading(.tight))
                .foregroundStyle(theme.textTertiary)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .padding(.leading, 10)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .accessibilityLabel("AI is responding")
    }
}
