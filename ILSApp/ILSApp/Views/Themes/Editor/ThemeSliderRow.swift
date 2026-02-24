import SwiftUI

struct ThemeSliderRow: View {
    let label: String
    @Binding var value: String
    let range: ClosedRange<Double>
    let step: Double
    var unit: String = "pt"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label): \(value.isEmpty ? "0" : value) \(unit)")
                .font(ILSTheme.captionFont)
            Slider(
                value: Binding(
                    get: { Double(value) ?? range.lowerBound },
                    set: { value = String(format: "%.0f", $0) }
                ),
                in: range,
                step: step
            )
        }
    }
}
