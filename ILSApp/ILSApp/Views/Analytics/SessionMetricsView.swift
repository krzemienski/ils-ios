import SwiftUI
import Charts
import ILSShared

/// Card view displaying session effectiveness statistics and model usage breakdown.
///
/// Renders a header with the overall completion rate callout, a 2×2 grid of key
/// effectiveness metrics (average messages, average duration, average iterations, and
/// completed vs. abandoned counts), and a per-model usage list with labelled progress
/// bars.  An empty-state placeholder is shown when ``metrics`` is `nil`.
///
/// ## Topics
/// ### Parameters
/// - ``metrics`` - The session metrics response to display; pass `nil` for the empty-state.
///
/// ### Sections
/// - ``headerRow`` - Title, optional subtitle, and completion-rate callout badge.
/// - ``metricsGrid`` - Four compact stat tiles arranged in a 2×2 ``LazyVGrid``.
/// - ``modelBreakdown`` - Sorted list of model rows with progress bars and usage labels.
/// - ``emptyState`` - Placeholder shown when ``metrics`` is `nil`.
///
/// ### Helpers
/// - ``formattedDuration(_:)`` - Converts seconds to a human-readable `"Xm Ys"` string.
/// - ``shortModelName(_:)`` - Extracts the last path component of a model identifier.
struct SessionMetricsView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// The session metrics data to display.  Pass `nil` to show the empty-state placeholder.
    let metrics: SessionMetricsResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            headerRow

            if let metrics {
                metricsGrid(metrics: metrics)

                if !metrics.modelUsage.isEmpty {
                    modelBreakdown(models: metrics.modelUsage)
                }
            } else {
                emptyState
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Header

    /// Title, optional total-sessions subtitle, and a completion-rate badge.
    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Session Metrics")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                if let metrics {
                    Text("\(metrics.totalSessions) session\(metrics.totalSessions == 1 ? "" : "s") analysed")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            // Completion rate badge
            if let metrics {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f%%", metrics.completionRate))
                        .font(.system(size: theme.fontBody, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(completionColor(for: metrics.completionRate))
                    Text("Completion")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: "Completion rate: %.0f%%", metrics.completionRate))
            }
        }
    }

    // MARK: - Metrics Grid

    /// 2×2 grid of key effectiveness stat tiles.
    private func metricsGrid(metrics: SessionMetricsResponse) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: theme.spacingSM
        ) {
            SessionStatTile(
                label: "Avg Messages",
                value: String(format: "%.1f", metrics.avgMessagesPerSession),
                icon: "message.fill",
                color: theme.accent
            )
            SessionStatTile(
                label: "Avg Duration",
                value: formattedDuration(metrics.avgSessionDurationSeconds),
                icon: "clock.fill",
                color: theme.entitySystem
            )
            SessionStatTile(
                label: "Avg Iterations",
                value: String(format: "%.1f", metrics.avgIterationsPerSession),
                icon: "arrow.triangle.2.circlepath",
                color: theme.warning
            )
            SessionStatTile(
                label: "Completed",
                value: "\(metrics.completedSessions) / \(metrics.totalSessions)",
                icon: "checkmark.circle.fill",
                color: theme.success
            )
        }
    }

    // MARK: - Model Breakdown

    /// Sorted list of model rows with usage percentage progress bars.
    private func modelBreakdown(models: [ModelUsageStat]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Model Usage")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .padding(.top, theme.spacingXS)

            let sorted = models.sorted { $0.usagePercentage > $1.usagePercentage }
            ForEach(sorted) { stat in
                modelRow(stat: stat)
            }
        }
    }

    /// A single model usage row: name label, progress bar, and percentage.
    private func modelRow(stat: ModelUsageStat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "cpu.fill")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)

                Text(shortModelName(stat.model))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(String(format: "%.0f%%", stat.usagePercentage))
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.bgSecondary)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.accent.gradient)
                        .frame(width: geo.size.width * (stat.usagePercentage / 100.0).clamped(to: 0...1), height: 6)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(shortModelName(stat.model)): \(String(format: "%.0f", stat.usagePercentage))% of sessions")
    }

    // MARK: - Empty State

    /// Placeholder shown when ``metrics`` is `nil`.
    private var emptyState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "chart.pie")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text("No session metrics")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No session metrics available")
    }

    // MARK: - Helpers

    /// Colour for the completion-rate badge based on threshold levels.
    ///
    /// - Parameter rate: Completion rate as a percentage (0–100).
    /// - Returns: Green for ≥ 80%, orange for ≥ 50%, red otherwise.
    private func completionColor(for rate: Double) -> Color {
        if rate >= 80 { return theme.success }
        if rate >= 50 { return theme.warning }
        return theme.error
    }

    /// Converts a duration in seconds to a human-readable abbreviated string.
    ///
    /// - Parameter seconds: Duration in seconds.
    /// - Returns: `"Xm Ys"` for durations ≥ 60 s, `"Xs"` otherwise.
    private func formattedDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        if total >= 60 {
            let minutes = total / 60
            let secs = total % 60
            return secs > 0 ? "\(minutes)m \(secs)s" : "\(minutes)m"
        }
        return "\(total)s"
    }

    /// Extracts the last component of a model identifier for compact display.
    ///
    /// For example, `"anthropic/claude-sonnet-4-5"` becomes `"claude-sonnet-4-5"`.
    ///
    /// - Parameter model: The full model identifier string.
    /// - Returns: The substring after the last `/`, or the full string if no `/` is present.
    private func shortModelName(_ model: String) -> String {
        model.split(separator: "/").last.map(String.init) ?? model
    }
}

// MARK: - Session Stat Tile

/// A compact key-metric tile used inside ``SessionMetricsView/metricsGrid(metrics:)``.
///
/// Renders an SF Symbols icon, a bold value, and a short label.
private struct SessionStatTile: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: theme.fontBody))
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Comparable+Clamped

private extension Comparable {
    /// Clamps the value to the given closed range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview {
    let sampleModels = [
        ModelUsageStat(
            model: "claude-sonnet-4-5",
            sessionCount: 18,
            messageCount: 144,
            tokensUsed: 72000,
            usagePercentage: 60.0
        ),
        ModelUsageStat(
            model: "claude-opus-4-5",
            sessionCount: 9,
            messageCount: 63,
            tokensUsed: 45000,
            usagePercentage: 30.0
        ),
        ModelUsageStat(
            model: "claude-haiku-3-5",
            sessionCount: 3,
            messageCount: 12,
            tokensUsed: 3000,
            usagePercentage: 10.0
        ),
    ]

    let sampleMetrics = SessionMetricsResponse(
        projectName: "my-project",
        totalSessions: 30,
        avgMessagesPerSession: 7.3,
        avgSessionDurationSeconds: 342,
        completedSessions: 25,
        abandonedSessions: 5,
        completionRate: 83.3,
        avgIterationsPerSession: 2.1,
        modelUsage: sampleModels
    )

    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                SessionMetricsView(metrics: sampleMetrics)
                SessionMetricsView(metrics: nil)
            }
            .padding()
        }
        .background(.background)
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
