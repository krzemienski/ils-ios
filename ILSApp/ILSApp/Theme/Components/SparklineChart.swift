import SwiftUI
import Charts

/// Minimal sparkline chart using Swift Charts LineMark.
/// Renders entity-colored line at compact height for stat cards.
struct SparklineChart: View {
    let data: [Double]
    let color: Color

    var body: some View {
        if data.count >= 2 {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                    AreaMark(
                        x: .value("Index", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 24)
        } else {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 24)
        }
    }
}
