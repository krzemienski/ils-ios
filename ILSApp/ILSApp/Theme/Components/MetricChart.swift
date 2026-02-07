import SwiftUI
import Charts

/// A reusable area + line chart for system metrics.
/// Renders an AreaMark with gradient fill and a LineMark overlay.
struct MetricChart: View {
    let title: String
    let data: [MetricDataPoint]
    let color: Color
    let unit: String
    let currentValue: String

    init(
        title: String,
        data: [MetricDataPoint],
        color: Color = EntityType.system.color,
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
        VStack(alignment: .leading, spacing: ILSTheme.spaceS) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(ILSTheme.textPrimary)

                Spacer()

                if !currentValue.isEmpty {
                    Text(currentValue)
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(color)
                }
            }

            if data.isEmpty {
                Rectangle()
                    .fill(ILSTheme.bg2)
                    .frame(height: 120)
                    .overlay {
                        Text("Waiting for data...")
                            .font(.caption)
                            .foregroundColor(ILSTheme.textTertiary)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusXS))
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
                                    .foregroundColor(ILSTheme.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 120)
            }
        }
        .padding(ILSTheme.spaceM)
        .background(ILSTheme.bg2)
        .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
    }
}
