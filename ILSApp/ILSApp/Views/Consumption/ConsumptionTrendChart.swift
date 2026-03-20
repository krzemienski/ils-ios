import SwiftUI
import Charts
import ILSShared

/// An area + line chart showing daily token consumption over time.
///
/// Renders an ``AreaMark`` with gradient fill and a ``LineMark`` overlay
/// (mirroring ``MetricChart``), with optional red ``PointMark`` overlays
/// on anomaly days.
struct ConsumptionTrendChart: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let data: [DailyConsumption]
    let anomalies: [AnomalyFlag]

    init(data: [DailyConsumption], anomalies: [AnomalyFlag] = []) {
        self.data = data
        self.anomalies = anomalies
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            headerRow
            chartContent
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("Consumption Trend")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Text(totalSummary)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartContent: some View {
        if data.isEmpty {
            Rectangle()
                .fill(theme.bgSecondary)
                .frame(height: 120)
                .overlay {
                    Text("Waiting for data...")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        } else {
            Chart {
                ForEach(data) { day in
                    AreaMark(
                        x: .value("Date", day.date),
                        y: .value("Tokens", day.totalTokens)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent.opacity(0.3), theme.accent.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", day.date),
                        y: .value("Tokens", day.totalTokens)
                    )
                    .foregroundStyle(theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                ForEach(anomalyPoints) { point in
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Tokens", point.tokens)
                    )
                    .foregroundStyle(.red)
                    .symbolSize(40)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let dateStr = value.as(String.self) {
                            Text(abbreviatedDate(dateStr))
                                .font(.caption2)
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(formattedTokenCount(v))
                                .font(.caption2)
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 120)
        }
    }

    // MARK: - Anomaly Points

    private var anomalyPoints: [AnomalyPoint] {
        let anomalyDates = Set(anomalies.map(\.affectedDate))
        return data.compactMap { day in
            guard anomalyDates.contains(day.date) else { return nil }
            return AnomalyPoint(date: day.date, tokens: day.totalTokens)
        }
    }

    // MARK: - Formatting

    private var totalSummary: String {
        let total = data.reduce(0) { $0 + $1.totalTokens }
        return "\(formattedTokenCount(total)) tokens"
    }

    private func formattedTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            let millions = Double(count) / 1_000_000.0
            return String(format: "%.1fM", millions)
        } else if count >= 1_000 {
            let thousands = Double(count) / 1_000.0
            return String(format: "%.0fK", thousands)
        }
        return "\(count)"
    }

    private func abbreviatedDate(_ isoDate: String) -> String {
        // Extract month/day from ISO 8601 date string "YYYY-MM-DD"
        let components = isoDate.split(separator: "-")
        guard components.count == 3,
              let month = Int(components[1]),
              let day = Int(components[2]) else {
            return isoDate
        }
        return "\(month)/\(day)"
    }

    private var accessibilityDescription: String {
        if data.isEmpty {
            return "Consumption trend chart, waiting for data"
        }
        let total = data.reduce(0) { $0 + $1.totalTokens }
        let anomalyCount = anomalies.count
        var label = "Consumption trend chart, \(formattedTokenCount(total)) total tokens over \(data.count) days"
        if anomalyCount > 0 {
            label += ", \(anomalyCount) anomal\(anomalyCount == 1 ? "y" : "ies") detected"
        }
        return label
    }
}

// MARK: - Supporting Types

private struct AnomalyPoint: Identifiable {
    let date: String
    let tokens: Int
    var id: String { date }
}

private extension DailyConsumption {
    var totalTokens: Int {
        estimatedInputTokens + estimatedOutputTokens
    }
}
