import SwiftUI
import Foundation

/// Left-to-right gradient sweep animation for skeleton loading placeholders.
/// Repeats every 1.5 seconds. Three-tier animation hierarchy:
/// 1. reduceMotion = no animations (static overlay)
/// 2. Low Power Mode = no continuous animations (static overlay)
/// 3. background scenePhase = no animations (paused)
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0
    @State private var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var shouldAnimate: Bool {
        !reduceMotion && !isLowPowerMode && scenePhase == .active
    }

    func body(content: Content) -> some View {
        if !shouldAnimate {
            content
                .overlay(
                    Color.white.opacity(0.04)
                )
                .onReceive(NotificationCenter.default.publisher(
                    for: Notification.Name.NSProcessInfoPowerStateDidChange
                )) { _ in
                    isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                }
        } else {
            content
                .overlay(
                    // LinearGradient fills its overlay parent naturally —
                    // GeometryReader was unnecessary and caused 60 layout passes/sec
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: max(0, min(1, phase - 0.3))),
                            .init(color: .white.opacity(0.08), location: max(0, min(1, phase))),
                            .init(color: .clear, location: max(0, min(1, phase + 0.3)))
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipped()
                )
                .onAppear { startAnimation() }
                .onDisappear {
                    // H-E2: Cancel repeatForever animation to stop GPU work after navigation.
                    withAnimation(.linear(duration: 0.0)) {
                        phase = -1.0
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active { startAnimation() }
                    else {
                        withAnimation(.linear(duration: 0.0)) {
                            phase = -1.0
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: Notification.Name.NSProcessInfoPowerStateDidChange
                )) { _ in
                    isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                }
        }
    }

    private func startAnimation() {
        guard shouldAnimate else { return }
        phase = -1.0
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            phase = 2.0
        }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
