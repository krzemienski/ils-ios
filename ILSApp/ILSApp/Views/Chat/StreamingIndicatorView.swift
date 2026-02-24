import SwiftUI
import Foundation

/// Left-aligned typing indicator shown while Claude is streaming but no tokens have arrived yet.
///
/// Displays a 2 pt accent bar (matching the visual language of `AssistantCard`), a small
/// pulsing accent-colored dot, and a status label. The dot animates between 30 % and 100 %
/// opacity on a repeating 0.8 s ease-in-out curve unless `accessibilityReduceMotion` is
/// enabled, in which case the animation is skipped entirely.
///
/// Animation is also paused when the app transitions to a non-active `scenePhase` (e.g.
/// backgrounded or in the app switcher) and resumed when the scene returns to `.active`,
/// preventing CPU spin in the background.
///
/// The status label defaults to "Claude is thinking…" but can be overridden via `statusText`
/// to surface real-time tool-use status strings from the streaming pipeline.
///
/// ## Topics
/// ### Input Properties
/// - ``statusText`` - Optional override for the default "Claude is thinking…" label; typically
///   a short tool-use status string sourced from the streaming event payload
struct StreamingIndicatorView: View {
    /// Optional label shown next to the pulsing dot; falls back to "Claude is thinking…"
    /// when `nil`. Typically set to a short tool-use status from the streaming event.
    var statusText: String?

    @State private var isPulsing = false
    @State private var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var shouldAnimate: Bool {
        !reduceMotion && !isLowPowerMode && scenePhase == .active
    }

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
            guard shouldAnimate else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .onDisappear {
            isPulsing = false
        }
        .onChange(of: scenePhase) { _, phase in
            if shouldAnimate {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                if reduceMotion || isLowPowerMode {
                    isPulsing = false
                } else {
                    withAnimation(.default) {
                        isPulsing = false
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: Notification.Name.NSProcessInfoPowerStateDidChange
        )) { _ in
            isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            if isLowPowerMode {
                isPulsing = false
            }
        }
        .accessibilityLabel("AI is responding")
    }
}
