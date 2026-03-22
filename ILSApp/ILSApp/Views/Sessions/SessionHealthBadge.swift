import SwiftUI
import ILSShared

/// A compact badge that displays a session health score with a colour-coded indicator dot.
///
/// Renders a small filled circle (green/orange/red) alongside the integer score,
/// giving users an immediate at-a-glance quality signal suitable for embedding inside
/// session rows, info headers, or any dense list context.
///
/// When `healthScore` is `nil` (data still loading or unavailable) the dot uses a neutral
/// grey fill and the label shows `"--"`.
///
/// ## Topics
/// ### Inputs
/// - ``healthScore`` — Optional `SessionHealthScore` driving colour and numeric label
/// - ``showLabel`` — Whether to append the qualitative level name ("Healthy", etc.)
///
/// ### Display Helpers
/// - ``dotColor`` — Mapped from ``HealthScoreLevel``: healthy → success, degrading → warning, problematic → error
/// - ``scoreText`` — Integer score string, or `"--"` when unavailable
struct SessionHealthBadge: View {
    /// The health score to display. Pass `nil` while data is loading.
    let healthScore: SessionHealthScore?

    /// When `true` a short level label ("Healthy", "Degrading", "Critical") is shown
    /// after the numeric score.  Defaults to `false` for the most compact presentation.
    var showLabel: Bool = false

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        HStack(spacing: theme.spacingXS) {
            // Colour-coded indicator dot
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            // Numeric score
            Text(scoreText)
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(dotColor)
                .monospacedDigit()

            // Optional qualitative label
            if showLabel, let level = healthScore?.level {
                Text(levelLabel(for: level))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.horizontal, theme.spacingXS + 2)
        .padding(.vertical, 3)
        .background(dotColor.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Helpers

    /// Fill colour for the indicator dot, mapped from the health level.
    private var dotColor: Color {
        switch healthScore?.level {
        case .healthy:     return theme.success
        case .degrading:   return theme.warning
        case .problematic: return theme.error
        case nil:          return theme.textSecondary
        }
    }

    /// Formatted score text: integer string or "--" when unavailable.
    private var scoreText: String {
        guard let score = healthScore?.score else { return "--" }
        return String(Int(score))
    }

    /// Short human-readable label for the given health level.
    private func levelLabel(for level: HealthScoreLevel) -> String {
        switch level {
        case .healthy:     return "Healthy"
        case .degrading:   return "Degrading"
        case .problematic: return "Critical"
        }
    }

    /// Full accessibility description combining score and level.
    private var accessibilityDescription: String {
        guard let hs = healthScore else { return "Health score unavailable" }
        let levelName = levelLabel(for: hs.level)
        return "Health score \(Int(hs.score)), \(levelName)"
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Health levels") {
    VStack(spacing: 16) {
        SessionHealthBadge(
            healthScore: SessionHealthScore(
                sessionId: "preview-1",
                score: 92,
                level: .healthy,
                factors: [],
                recommendations: [],
                computedAt: Date()
            )
        )

        SessionHealthBadge(
            healthScore: SessionHealthScore(
                sessionId: "preview-2",
                score: 63,
                level: .degrading,
                factors: [],
                recommendations: [],
                computedAt: Date()
            ),
            showLabel: true
        )

        SessionHealthBadge(
            healthScore: SessionHealthScore(
                sessionId: "preview-3",
                score: 31,
                level: .problematic,
                factors: [],
                recommendations: [],
                computedAt: Date()
            ),
            showLabel: true
        )

        // Loading / unavailable state
        SessionHealthBadge(healthScore: nil)
    }
    .padding()
}
#endif
