import SwiftUI
import Charts
import ILSShared

/// Bar chart showing project activity over time, grouped by day.
///
/// Renders a Swift Charts ``BarMark`` for each ``ActivityDataPoint`` in the provided
/// ``ActivityTimelineResponse``, with the number of sessions on the Y axis and an
/// abbreviated day label on the X axis.  A dashed ``RuleMark`` annotation highlights the
/// peak session day when the highest-count data point has at least one session.
/// An empty-state placeholder is shown when ``data`` is `nil` or contains no data points.
///
/// ## Topics
/// ### Parameters
/// - ``data`` - The timeline response to render; pass `nil` to show the empty-state placeholder.
///
/// ### Helpers
/// - ``dataPoints`` - Convenience accessor for the response's data points array.
/// - ``peakDataPoint`` - The ``ActivityDataPoint`` with the highest ``ActivityDataPoint/sessionCount``.
/// - ``periodSubtitle`` - Human-readable subtitle derived from the data point count.
/// - ``abbreviatedDay(for:)`` - Converts an ISO-8601 date string to a short display label.
/// - ``shortDayLabel(from:)`` - Returns weekday abbreviation for weekly ranges, day number otherwise.
struct ActivityTimelineView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// The activity timeline response to display.  Pass `nil` to show the empty state.
    let data: ActivityTimelineResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Card header
            headerRow

            if dataPoints.isEmpty {
                emptyState
            } else {
                barChart
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Sub-views

    /// Title, optional subtitle, and optional peak-sessions callout.
    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Activity Timeline")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                if let subtitle = periodSubtitle {
                    Text(subtitle)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            // Peak-day callout shown only when there is activity data
            if let peak = peakDataPoint, peak.sessionCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(peak.sessionCount)")
                        .font(.system(size: theme.fontBody, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                    Text("Peak day")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Peak day: \(peak.sessionCount) sessions on \(peak.date)")
            }
        }
    }

    /// Placeholder shown when there are no data points.
    private var emptyState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "chart.bar")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text("No activity data")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No activity data available")
    }

    /// Bar chart with one bar per ``ActivityDataPoint``.
    ///
    /// A dashed ``RuleMark`` drawn at the peak session count makes the busiest
    /// day immediately legible.  The mark is suppressed when the peak count is zero
    /// (all days had no sessions).
    private var barChart: some View {
        Chart(dataPoints) { point in
            BarMark(
                x: .value("Date", abbreviatedDay(for: point.date)),
                y: .value("Sessions", point.sessionCount)
            )
            .foregroundStyle(theme.accent.gradient)
            .cornerRadius(4)

            // Peak annotation — drawn as a RuleMark at the peak session count
            if let peak = peakDataPoint, peak.sessionCount > 0, point.date == peak.date {
                RuleMark(y: .value("Peak", peak.sessionCount))
                    .foregroundStyle(theme.accent.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Peak")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    }
            }
        }
        .frame(height: 160)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                    .foregroundStyle(theme.borderSubtle)
                AxisValueLabel()
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .accessibilityLabel("Activity timeline bar chart")
        .accessibilityHint("Shows the number of sessions per day")
    }

    // MARK: - Helpers

    /// Data points from the response, or an empty array when ``data`` is `nil`.
    private var dataPoints: [ActivityDataPoint] {
        data?.dataPoints ?? []
    }

    /// The ``ActivityDataPoint`` with the highest ``ActivityDataPoint/sessionCount``.
    ///
    /// Returns `nil` when ``dataPoints`` is empty.
    private var peakDataPoint: ActivityDataPoint? {
        dataPoints.max(by: { $0.sessionCount < $1.sessionCount })
    }

    /// Human-readable subtitle derived from the number of data points.
    ///
    /// Returns `nil` when ``data`` is `nil` or the data set is empty.
    private var periodSubtitle: String? {
        guard let response = data, !response.dataPoints.isEmpty else { return nil }
        let count = response.dataPoints.count
        return "Last \(count) day\(count == 1 ? "" : "s")"
    }

    /// Converts an ISO-8601 date string into a short display label for the X axis.
    ///
    /// Returns `"EEE"` (e.g., `"Mon"`) for ranges of 7 days or fewer, and the
    /// day-of-month number (e.g., `"15"`) for longer ranges.  Falls back to the
    /// first three characters of the raw string if parsing fails.
    ///
    /// - Parameter dateString: ISO-8601 date string (e.g., `"2024-01-15"`).
    /// - Returns: An abbreviated label such as `"Mon"` or `"15"`.
    private func abbreviatedDay(for dateString: String) -> String {
        // Try ISO8601DateFormatter first (handles "yyyy-MM-dd" with withFullDate option)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let date = iso.date(from: dateString) {
            return shortDayLabel(from: date)
        }

        // Fallback: standard yyyy-MM-dd formatter
        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd"
        if let date = fallback.date(from: dateString) {
            return shortDayLabel(from: date)
        }

        // Last resort: first three characters of the raw string
        return String(dateString.prefix(3))
    }

    /// Returns a short day label appropriate for the current range size.
    ///
    /// - Parameter date: The `Date` to format.
    /// - Returns: Weekday abbreviation (`"Mon"`) for weekly ranges; day number (`"15"`) otherwise.
    private func shortDayLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = dataPoints.count <= 7 ? "EEE" : "d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let samplePoints = [
        ActivityDataPoint(date: "2024-01-15", sessionCount: 3, messageCount: 12, tokensUsed: 1200),
        ActivityDataPoint(date: "2024-01-16", sessionCount: 7, messageCount: 28, tokensUsed: 2800),
        ActivityDataPoint(date: "2024-01-17", sessionCount: 2, messageCount: 8, tokensUsed: 800),
        ActivityDataPoint(date: "2024-01-18", sessionCount: 9, messageCount: 36, tokensUsed: 3600),
        ActivityDataPoint(date: "2024-01-19", sessionCount: 5, messageCount: 20, tokensUsed: 2000),
        ActivityDataPoint(date: "2024-01-20", sessionCount: 0, messageCount: 0, tokensUsed: 0),
        ActivityDataPoint(date: "2024-01-21", sessionCount: 4, messageCount: 16, tokensUsed: 1600),
    ]

    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                ActivityTimelineView(
                    data: ActivityTimelineResponse(
                        projectName: "my-project",
                        dataPoints: samplePoints,
                        startDate: "2024-01-15",
                        endDate: "2024-01-21",
                        granularity: "day"
                    )
                )

                // Empty state preview
                ActivityTimelineView(data: nil)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
