import SwiftUI
import ILSShared

/// Side-by-side metric comparison card for two ``ChatSession`` instances.
///
/// Displays a two-column card where each column shows metrics for one session.
/// Numeric values where a clear "better" direction exists are highlighted with
/// `theme.success` (higher message count, lower cost, shorter duration).
///
/// ## Topics
/// ### Parameters
/// - ``sessionA`` - First session to compare
/// - ``sessionB`` - Second session to compare
struct ComparisonMetricsView: View {
    let sessionA: ChatSession
    let sessionB: ChatSession

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Computed Metrics

    private var durationA: TimeInterval {
        sessionA.lastActiveAt.timeIntervalSince(sessionA.createdAt)
    }

    private var durationB: TimeInterval {
        sessionB.lastActiveAt.timeIntervalSince(sessionB.createdAt)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                columnHeader("Session A", color: theme.entitySession)
                Divider()
                    .frame(width: 1)
                    .overlay(theme.divider)
                columnHeader("Session B", color: theme.entitySession)
            }

            Divider().overlay(theme.divider)

            // Metric rows
            metricRow(
                label: "Messages",
                valueA: "\(sessionA.messageCount)",
                valueB: "\(sessionB.messageCount)",
                colorA: messagesColorA,
                colorB: messagesColorB
            )

            Divider().overlay(theme.divider.opacity(0.5))

            metricRow(
                label: "Cost",
                valueA: formattedCost(sessionA.totalCostUSD),
                valueB: formattedCost(sessionB.totalCostUSD),
                colorA: costColorA,
                colorB: costColorB
            )

            Divider().overlay(theme.divider.opacity(0.5))

            metricRow(
                label: "Duration",
                valueA: formattedDuration(durationA),
                valueB: formattedDuration(durationB),
                colorA: durationColorA,
                colorB: durationColorB
            )

            Divider().overlay(theme.divider.opacity(0.5))

            metricRow(
                label: "Model",
                valueA: sessionA.model.capitalized,
                valueB: sessionB.model.capitalized,
                colorA: theme.textPrimary,
                colorB: theme.textPrimary
            )

            Divider().overlay(theme.divider.opacity(0.5))

            metricRow(
                label: "Status",
                valueA: sessionA.status.rawValue.capitalized,
                valueB: sessionB.status.rawValue.capitalized,
                colorA: statusColor(sessionA.status),
                colorB: statusColor(sessionB.status)
            )
        }
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .strokeBorder(theme.border.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Comparison Colors

    private var messagesColorA: Color {
        if sessionA.messageCount > sessionB.messageCount { return theme.success }
        if sessionA.messageCount < sessionB.messageCount { return theme.textSecondary }
        return theme.textPrimary
    }

    private var messagesColorB: Color {
        if sessionB.messageCount > sessionA.messageCount { return theme.success }
        if sessionB.messageCount < sessionA.messageCount { return theme.textSecondary }
        return theme.textPrimary
    }

    private var costColorA: Color {
        guard let costA = sessionA.totalCostUSD, let costB = sessionB.totalCostUSD else {
            return theme.textPrimary
        }
        if costA < costB { return theme.success }
        if costA > costB { return theme.textSecondary }
        return theme.textPrimary
    }

    private var costColorB: Color {
        guard let costA = sessionA.totalCostUSD, let costB = sessionB.totalCostUSD else {
            return theme.textPrimary
        }
        if costB < costA { return theme.success }
        if costB > costA { return theme.textSecondary }
        return theme.textPrimary
    }

    private var durationColorA: Color {
        if durationA < durationB { return theme.success }
        if durationA > durationB { return theme.textSecondary }
        return theme.textPrimary
    }

    private var durationColorB: Color {
        if durationB < durationA { return theme.success }
        if durationB > durationA { return theme.textSecondary }
        return theme.textPrimary
    }

    // MARK: - Sub-Views

    @ViewBuilder
    private func columnHeader(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(color)
            .textCase(.uppercase)
            .kerning(0.5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .padding(.horizontal, theme.spacingMD)
    }

    @ViewBuilder
    private func metricRow(
        label: String,
        valueA: String,
        valueB: String,
        colorA: Color,
        colorB: Color
    ) -> some View {
        HStack(spacing: 0) {
            // Session A value
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Text(valueA)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(colorA)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, theme.spacingSM)
            .padding(.horizontal, theme.spacingMD)

            Divider()
                .frame(width: 1)
                .overlay(theme.divider)

            // Session B value
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Text(valueB)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(colorB)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, theme.spacingSM)
            .padding(.horizontal, theme.spacingMD)
        }
    }

    // MARK: - Formatting Helpers

    private func formattedCost(_ cost: Double?) -> String {
        guard let cost else { return "N/A" }
        return String(format: "$%.4f", cost)
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        formatter.maximumUnitCount = 2
        return formatter.string(from: interval) ?? "—"
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .active: return theme.success
        case .completed: return theme.textPrimary
        case .cancelled: return theme.warning
        case .error: return theme.error
        }
    }
}

// MARK: - Preview

#Preview {
    let sessionA = ChatSession(
        name: "Refactor Auth Module",
        model: "sonnet",
        status: .completed,
        messageCount: 42,
        totalCostUSD: 0.0523,
        createdAt: Date().addingTimeInterval(-7200),
        lastActiveAt: Date().addingTimeInterval(-3600)
    )
    let sessionB = ChatSession(
        name: "Debug Login Flow",
        model: "opus",
        status: .active,
        messageCount: 18,
        totalCostUSD: 0.1240,
        createdAt: Date().addingTimeInterval(-5400),
        lastActiveAt: Date()
    )
    ComparisonMetricsView(sessionA: sessionA, sessionB: sessionB)
        .padding()
        .background(Color.black)
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
