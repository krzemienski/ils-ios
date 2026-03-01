import SwiftUI

/// Animated waveform visualization driven by audio power level values.
/// Uses Canvas for smooth, performant rendering of oscillating bars.
struct AudioWaveformView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Current audio power level (0.0 silent … 1.0 loudest).
    var powerLevel: CGFloat = 0.0

    /// Number of bars in the waveform.
    var barCount: Int = 5

    /// Overall size of the waveform view.
    var size: CGSize = CGSize(width: 40, height: 24)

    @State private var phase: Double = 0

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    private let minBarHeight: CGFloat = 4
    private let cornerRadius: CGFloat = 1.5
    private let animationInterval: TimeInterval = 1.0 / 30.0

    var body: some View {
        Canvas { context, canvasSize in
            let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
            let originX = (canvasSize.width - totalWidth) / 2
            let centerY = canvasSize.height / 2

            for i in 0..<barCount {
                let normalizedIndex = Double(i) / Double(max(barCount - 1, 1))
                let wave = reduceMotion
                    ? 0.5
                    : (sin(phase + normalizedIndex * .pi * 1.5) + 1) / 2

                let amplitude = minBarHeight + (canvasSize.height - minBarHeight) * powerLevel * wave
                let x = originX + CGFloat(i) * (barWidth + barSpacing)
                let y = centerY - amplitude / 2

                let rect = CGRect(x: x, y: y, width: barWidth, height: amplitude)
                let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
                context.fill(path, with: .color(theme.accent))
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear { startAnimating() }
        .onDisappear { phase = 0 }
        .accessibilityLabel("Audio waveform")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func startAnimating() {
        guard !reduceMotion else { return }
        Timer.scheduledTimer(withTimeInterval: animationInterval, repeats: true) { _ in
            phase += 0.15
        }
    }
}

#Preview {
    AudioWaveformView(powerLevel: 0.6)
        .padding()
        .background(Color.black)
}
