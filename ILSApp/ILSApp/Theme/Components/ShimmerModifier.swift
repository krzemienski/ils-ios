import SwiftUI

/// Left-to-right gradient sweep animation for skeleton loading placeholders.
/// Repeats every 1.5 seconds. Respects reduced motion preferences.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .overlay(
                    Color.white.opacity(0.04)
                )
        } else {
            content
                .overlay(
                    // LinearGradient fills its overlay parent naturally —
                    // GeometryReader was unnecessary and caused 60 layout passes/sec
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: max(0, phase - 0.3)),
                            .init(color: .white.opacity(0.08), location: phase),
                            .init(color: .clear, location: min(1, phase + 0.3))
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipped()
                )
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                    ) {
                        phase = 2.0
                    }
                }
        }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
