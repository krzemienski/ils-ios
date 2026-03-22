import SwiftUI
import Charts
import ILSShared

/// Grouped bar chart showing thumbs-up and thumbs-down ratings per day.
///
/// Renders a Swift Charts grouped ``BarMark`` for each ``QualityTrendPoint`` in the
/// provided ``QualityTrendResponse``: a green bar for thumbs-up counts and a red bar
/// for thumbs-down counts.  The card header displays the overall quality score
/// percentage computed across all data points.  An empty-state placeholder is shown
/// when ``data`` is `nil` or contains no data points.
///
/// ## Topics
/// ### Parameters
/// - ``data`` - The quality trend response to render; pass `nil` to show the empty-state placeholder.
///
/// ### Helpers
/// - ``dataPoints`` - Convenience accessor for the response's data points array.
/// - ``overallScore`` - Aggregate quality score across all data points (0–100).
/// - ``chartEntries`` - Flat list of ``ChartEntry`` values used to drive the grouped chart.
/// - ``abbreviatedDay(for:)`` - Converts an ISO-8601 date string to a short display label.
/// - ``shortDayLabel(from:)`` - Returns weekday abbreviation for weekly ranges, day number otherwise.
struct QualityTrendView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// The quality trend response to display.  Pass `nil` to show the empty state.
    let data: QualityTrendResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            headerRow

            if dataPoints.isEmpty {
                emptyState
            } else {
                barChart
                legend
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Sub-views

    /// Title and overall quality score callout.
    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Quality Trend")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                if let subtitle = periodSubtitle {
                    Text(subtitle)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            // Overall quality score callout — shown only when there is data
            if !dataPoints.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(overallScore)%")
                        .font(.system(size: theme.fontBody, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(scoreColor)
                    Text("Quality score")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Overall quality score: \(overallScore) percent")
            }
        }
    }

    /// Placeholder shown when there are no data points.
    private var emptyState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "hand.thumbsup")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text("No ratings yet")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No quality ratings available")
    }

    /// Grouped bar chart with thumbs-up (green) and thumbs-down (red) bars per day.
    private var barChart: some View {
        Chart(chartEntries) { entry in
            BarMark(
                x: .value("Date", entry.day),
                y: .value("Count", entry.count)
            )
            .foregroundStyle(entry.isPositive ? theme.success : theme.error)
            .cornerRadius(theme.cornerRadiusSmall)
            .position(by: .value("Rating", entry.label))
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
        .chartLegend(.hidden)
        .accessibilityLabel("Quality trend grouped bar chart")
        .accessibilityHint("Shows thumbs-up and thumbs-down ratings per day")
    }

    /// Inline legend identifying the two bar colours.
    private var legend: some View {
        HStack(spacing: theme.spacingMD) {
            legendItem(color: theme.success, label: "Thumbs up")
            legendItem(color: theme.error, label: "Thumbs down")
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Helpers

    /// Data points from the response, or an empty array when ``data`` is `nil`.
    private var dataPoints: [QualityTrendPoint] {
        data?.dataPoints ?? []
    }

    /// Human-readable subtitle derived from the number of data points.
    ///
    /// Returns `nil` when ``data`` is `nil` or the data set is empty.
    private var periodSubtitle: String? {
        guard let response = data, !response.dataPoints.isEmpty else { return nil }
        let count = response.dataPoints.count
        return "Last \(count) day\(count == 1 ? "" : "s")"
    }

    /// Aggregate quality score (0–100) across all data points.
    ///
    /// Computed as total thumbs-up divided by total ratings, expressed as a percentage.
    /// Returns `0` when there are no ratings.
    private var overallScore: Int {
        let totalUp = dataPoints.reduce(0) { $0 + $1.thumbsUp }
        let totalDown = dataPoints.reduce(0) { $0 + $1.thumbsDown }
        let total = totalUp + totalDown
        guard total > 0 else { return 0 }
        return Int((Double(totalUp) / Double(total)) * 100)
    }

    /// Color for the quality score — green when ≥ 70 %, amber below.
    private var scoreColor: Color {
        overallScore >= 70 ? theme.success : theme.error
    }

    /// Flat list of chart entries used to drive the grouped bar chart.
    ///
    /// Each ``QualityTrendPoint`` produces two entries: one for thumbs-up and one for
    /// thumbs-down, keyed by an abbreviated day label.
    private var chartEntries: [ChartEntry] {
        dataPoints.flatMap { point in
            let day = abbreviatedDay(for: point.date)
            return [
                ChartEntry(day: day, label: "👍", count: point.thumbsUp, isPositive: true),
                ChartEntry(day: day, label: "👎", count: point.thumbsDown, isPositive: false)
            ]
        }
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
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let date = iso.date(from: dateString) {
            return shortDayLabel(from: date)
        }

        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd"
        if let date = fallback.date(from: dateString) {
            return shortDayLabel(from: date)
        }

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

// MARK: - ChartEntry

/// A single bar entry for the grouped quality trend chart.
private struct ChartEntry: Identifiable {
    let id = UUID()
    /// Abbreviated day label used on the X axis.
    let day: String
    /// Series label used to group bars (`"👍"` or `"👎"`).
    let label: String
    /// Number of ratings for this day and series.
    let count: Int
    /// `true` for thumbs-up entries, `false` for thumbs-down.
    let isPositive: Bool
}

// MARK: - Preview

#Preview {
    let samplePoints = [
        QualityTrendPoint(date: "2024-01-15", thumbsUp: 5, thumbsDown: 1, score: 0.83),
        QualityTrendPoint(date: "2024-01-16", thumbsUp: 8, thumbsDown: 2, score: 0.80),
        QualityTrendPoint(date: "2024-01-17", thumbsUp: 3, thumbsDown: 3, score: 0.50),
        QualityTrendPoint(date: "2024-01-18", thumbsUp: 10, thumbsDown: 1, score: 0.91),
        QualityTrendPoint(date: "2024-01-19", thumbsUp: 6, thumbsDown: 0, score: 1.00),
        QualityTrendPoint(date: "2024-01-20", thumbsUp: 0, thumbsDown: 2, score: 0.00),
        QualityTrendPoint(date: "2024-01-21", thumbsUp: 7, thumbsDown: 1, score: 0.88),
    ]

    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                QualityTrendView(
                    data: QualityTrendResponse(
                        projectId: "my-project",
                        dataPoints: samplePoints,
                        startDate: "2024-01-15",
                        endDate: "2024-01-21"
                    )
                )

                // Empty state preview
                QualityTrendView(data: nil)
            }
            .padding()
        }
        .background(.background)
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
