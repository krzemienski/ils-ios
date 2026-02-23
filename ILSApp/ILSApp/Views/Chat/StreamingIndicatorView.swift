import SwiftUI
import Foundation

/// Single pulsing orange dot with "Claude is thinking..." text.
/// Left-aligned, minimal footprint on pure black background.
/// Three-tier animation hierarchy: reduceMotion > Low Power Mode > scenePhase.
struct StreamingIndicatorView: View {
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
