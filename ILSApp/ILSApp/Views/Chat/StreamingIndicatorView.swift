import SwiftUI

/// Animated 3-dot typing indicator shown when the AI is generating a response.
/// Uses a 1.2s easeInOut loop for each dot with staggered delays.
/// When reduce-motion is enabled, shows static "Responding..." text instead.
struct StreamingIndicatorView: View {
    var statusText: String?

    @State private var animatingDot = 0
    @State private var animationTask: Task<Void, Never>?
    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            if reduceMotion {
                staticIndicator
            } else {
                animatedDots
            }

            if let statusText, !statusText.isEmpty {
                Text(statusText)
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingSM)
        .accessibilityLabel("AI is responding")
    }

    // MARK: - Animated Dots

    private var animatedDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(theme.accent)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDot == index ? 1.3 : 0.7)
                    .opacity(animatingDot == index ? 1.0 : 0.4)
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    // MARK: - Static Indicator (Reduce Motion)

    private var staticIndicator: some View {
        HStack(spacing: theme.spacingXS) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(theme.accent)
            Text("Responding...")
                .font(.system(size: theme.fontCaption, weight: .medium))
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled, !reduceMotion else { break }
                withAnimation(.easeInOut(duration: 0.4)) {
                    animatingDot = (animatingDot + 1) % 3
                }
            }
        }
    }
}
