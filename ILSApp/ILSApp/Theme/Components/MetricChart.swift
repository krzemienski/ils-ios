import SwiftUI
import Charts

/// A reusable area + line chart for system metrics.
/// Renders an AreaMark with gradient fill and a LineMark overlay.
struct MetricChart: View {
    @Environment(\.theme) private var theme: any AppTheme

    let title: String
    let data: [MetricDataPoint]
    let color: Color
    let unit: String
    let currentValue: String

    init(
        title: String,
        data: [MetricDataPoint],
        color: Color = .cyan,
        unit: String = "%",
        currentValue: String = ""
    ) {
        self.title = title
        self.data = data
        self.color = color
        self.unit = unit
        self.currentValue = currentValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                Text(title)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                if !currentValue.isEmpty {
                    Text(currentValue)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(color)
                }
            }

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
                Chart(data) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value(title, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value(title, point.value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))\(unit)")
                                    .font(.caption2)
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 120)
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metricAccessibilityLabel)
    }

    private var metricAccessibilityLabel: String {
        if data.isEmpty {
            return "\(title) chart, waiting for data"
        }
        if !currentValue.isEmpty {
            return "\(title) chart, current value \(currentValue)"
        }
        return "\(title) chart"
    }
}
