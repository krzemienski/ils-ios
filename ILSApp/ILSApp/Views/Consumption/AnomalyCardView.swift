import SwiftUI
import ILSShared

/// A card displaying a single detected consumption anomaly.
///
/// Shows an SF Symbol icon based on anomaly type, a severity badge,
/// the affected date, percentage change, and explanatory context.
struct AnomalyCardView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let anomaly: AnomalyFlag

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            anomalyIcon
            contentColumn
            Spacer(minLength: 0)
            severityBadge
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard(padding: 0))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Icon

    private var anomalyIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: theme.fontTitle2, weight: .semibold))
            .foregroundStyle(iconColor)
            .frame(width: 36, height: 36)
            .background(iconColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    // MARK: - Content

    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(anomaly.description)
                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)

            HStack(spacing: theme.spacingSM) {
                Label(formattedDate, systemImage: "calendar")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                percentageChangeLabel
            }

            if let context = anomaly.context, !context.isEmpty {
                Text(context)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(3)
            }
        }
    }

    // MARK: - Percentage Change

    private var percentageChangeLabel: some View {
        HStack(spacing: 2) {
            Image(systemName: anomaly.percentageChange >= 0 ? "arrow.up" : "arrow.down")
                .font(.system(size: theme.fontCaption - 2, weight: .bold))
            Text("\(abs(Int(anomaly.percentageChange)))%")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
        }
        .foregroundStyle(anomaly.percentageChange >= 0 ? theme.error : theme.accent)
    }

    // MARK: - Severity Badge

    private var severityBadge: some View {
        Text(anomaly.severity.rawValue.capitalized)
            .font(.system(size: theme.fontCaption - 1, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(severityTextColor)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS / 2)
            .background(severityBackgroundColor.opacity(0.2))
            .clipShape(Capsule())
    }

    // MARK: - Helpers

    private var iconName: String {
        switch anomaly.type {
        case .spike:
            return "exclamationmark.triangle"
        case .drop:
            return "arrow.down.circle"
        case .unusualModelMix:
            return "cpu"
        }
    }

    private var iconColor: Color {
        switch anomaly.severity {
        case .warning:
            return theme.warning
        case .critical:
            return theme.error
        }
    }

    private var severityTextColor: Color {
        switch anomaly.severity {
        case .warning:
            return theme.warning
        case .critical:
            return theme.error
        }
    }

    private var severityBackgroundColor: Color {
        switch anomaly.severity {
        case .warning:
            return theme.warning
        case .critical:
            return theme.error
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: anomaly.affectedDate) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return anomaly.affectedDate
    }

    private var accessibilityDescription: String {
        let direction = anomaly.percentageChange >= 0 ? "increase" : "decrease"
        return "\(anomaly.severity.rawValue) anomaly: \(anomaly.description). \(abs(Int(anomaly.percentageChange))) percent \(direction) on \(formattedDate)"
    }
}

// MARK: - Anomaly List Section

/// A section that displays a list of consumption anomaly cards with a header.
///
/// Shows a header with an icon and count badge, followed by individual
/// ``AnomalyCardView`` cards for each detected anomaly.
struct AnomalyListSection: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let anomalies: [AnomalyFlag]

    var body: some View {
        if !anomalies.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                sectionHeader
                ForEach(anomalies) { anomaly in
                    AnomalyCardView(anomaly: anomaly)
                }
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.warning)
            Text("Anomalies")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("\(anomalies.count)")
                .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textOnAccent)
                .padding(.horizontal, theme.spacingXS)
                .padding(.vertical, 2)
                .background(theme.warning)
                .clipShape(Capsule())

            Spacer()
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Anomaly Cards") {
    ScrollView {
        VStack(spacing: 12) {
            AnomalyCardView(anomaly: AnomalyFlag(
                id: "1",
                type: .spike,
                severity: .critical,
                affectedDate: "2026-03-18",
                percentageChange: 250.0,
                description: "Token usage spiked 250% above 7-day average",
                context: "Driven by extended Opus sessions in project 'ils-ios'"
            ))

            AnomalyCardView(anomaly: AnomalyFlag(
                id: "2",
                type: .drop,
                severity: .warning,
                affectedDate: "2026-03-17",
                percentageChange: -60.0,
                description: "Usage dropped 60% from previous day",
                context: nil
            ))

            AnomalyCardView(anomaly: AnomalyFlag(
                id: "3",
                type: .unusualModelMix,
                severity: .warning,
                affectedDate: "2026-03-16",
                percentageChange: 80.0,
                description: "Unusual shift toward Opus model usage",
                context: "Opus usage jumped from 10% to 90% of total tokens"
            ))
        }
        .padding()
    }
}
#endif
