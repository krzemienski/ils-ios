import SwiftUI

/// A circular progress ring with gradient stroke.
/// Used for memory and disk usage visualization.
struct ProgressRing: View {
    let progress: Double // 0.0 - 1.0
    let gradient: LinearGradient
    let lineWidth: CGFloat
    let title: String
    let subtitle: String

    init(
        progress: Double,
        gradient: LinearGradient = LinearGradient(
            colors: [EntityType.system.color, EntityType.system.color.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        lineWidth: CGFloat = 10,
        title: String = "",
        subtitle: String = ""
    ) {
        self.progress = min(max(progress, 0), 1)
        self.gradient = gradient
        self.lineWidth = lineWidth
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: ILSTheme.spaceS) {
            ZStack {
                // Background track
                Circle()
                    .stroke(ILSTheme.bg3, lineWidth: lineWidth)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)

                // Center label
                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.title3.monospacedDigit().bold())
                        .foregroundColor(ILSTheme.textPrimary)
                }
            }
            .frame(width: 80, height: 80)

            if !title.isEmpty {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(ILSTheme.textPrimary)
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(ILSTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ringAccessibilityLabel)
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    private var ringAccessibilityLabel: String {
        if !title.isEmpty {
            return "\(title), \(Int(progress * 100)) percent"
        }
        return "\(Int(progress * 100)) percent"
    }
}
