import SwiftUI
import ILSShared

/// A compact card displaying the current burn rate and projected exhaustion.
///
/// Shows a circular gauge representing the consumption fraction of the rate limit,
/// the current burn rate in messages per hour, and a projected exhaustion countdown.
/// The gauge is color-coded: green (< 50% used), yellow (50–80%), red (> 80%).
///
/// ## Topics
/// ### Display
/// - ``circularGauge`` – Circular ``Gauge`` showing consumption fraction
/// - ``burnRateLabel`` – Current rate formatted as "X msgs/hr"
/// - ``exhaustionLabel`` – Projected time remaining until exhaustion
struct BurnRateGauge: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let burnRate: BurnRateInfo
    let severity: BurnRateSeverity

    // MARK: - Body

    var body: some View {
        VStack(spacing: theme.spacingSM) {
            headerRow
            HStack(spacing: theme.spacingMD) {
                circularGauge
                metricsColumn
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard(padding: 0))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Image(systemName: "flame")
                .foregroundStyle(severityColor)
            Text("Burn Rate")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(exhaustionSummary)
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(severityColor)
        }
    }

    // MARK: - Circular Gauge

    private var circularGauge: some View {
        Gauge(value: consumptionFraction, in: 0...1) {
            EmptyView()
        } currentValueLabel: {
            Text("\(Int(consumptionFraction * 100))%")
                .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(severityColor)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(severityGradient)
        .scaleEffect(1.4)
        .frame(width: 60, height: 60)
    }

    // MARK: - Metrics Column

    private var metricsColumn: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            burnRateLabel
            exhaustionLabel
            costLabel
        }
    }

    private var burnRateLabel: some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(severityColor)
            Text(formattedRate)
                .font(.system(size: theme.fontBody, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
        }
    }

    private var exhaustionLabel: some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "clock")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textSecondary)
            Text(exhaustionSummary)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var costLabel: some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
            Text(formattedCostPerHour)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Computed Properties

    /// Fraction of consumption used (0–1), derived from severity thresholds.
    private var consumptionFraction: Double {
        // Map severity to a representative fraction for the gauge
        switch severity {
        case .high:
            return min(burnRate.messagesPerHour / max(burnRate.messagesPerHour, 1.0), 1.0)
        case .medium:
            return 0.65
        case .low:
            return burnRate.messagesPerHour > 0 ? min(burnRate.messagesPerHour / 20.0, 0.49) : 0.0
        }
    }

    private var formattedRate: String {
        if burnRate.messagesPerHour < 1.0 {
            return String(format: "%.1f msgs/hr", burnRate.messagesPerHour)
        }
        return String(format: "%.0f msgs/hr", burnRate.messagesPerHour)
    }

    private var exhaustionSummary: String {
        guard let hours = burnRate.projectedHoursRemaining else {
            return "No exhaustion projected"
        }
        if hours < 1.0 {
            let minutes = max(1, Int(hours * 60))
            return "\(minutes)m remaining"
        }
        let wholeHours = Int(hours)
        let minutes = Int((hours - Double(wholeHours)) * 60)
        if minutes > 0 {
            return "\(wholeHours)h \(minutes)m remaining"
        }
        return "\(wholeHours)h remaining"
    }

    private var formattedCostPerHour: String {
        let cost = burnRate.estimatedCostPerHour
        if cost < 0.01 {
            return "<$0.01/hr"
        }
        return String(format: "$%.2f/hr", cost)
    }

    private var severityColor: Color {
        switch severity {
        case .low: return theme.success
        case .medium: return theme.warning
        case .high: return theme.error
        }
    }

    private var severityGradient: Gradient {
        Gradient(colors: [severityColor.opacity(0.6), severityColor])
    }

    private var accessibilityDescription: String {
        var label = "Burn rate: \(formattedRate), \(exhaustionSummary)"
        label += ", severity \(severity.rawValue)"
        return label
    }
}
