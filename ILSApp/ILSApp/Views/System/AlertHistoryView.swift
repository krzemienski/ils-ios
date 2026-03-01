import SwiftUI
import Charts

/// Displays a history of fired system metric alerts with a 7-day trend bar chart.
///
/// Shows all ``AlertRecord`` entries from ``AlertThresholdManager/alertHistory``
/// (newest-first). Supports swipe-to-delete individual rows and a 'Clear All'
/// toolbar button. A ``BarMark`` chart above the list visualises alert frequency
/// per metric type over the past seven days.
///
/// ## Sections
/// 1. **Empty state** — shown when no alerts have been triggered yet.
/// 2. **7-Day Trend** — bar chart grouped by day and metric type.
/// 3. **History list** — scrollable list of alert rows with swipe-to-delete.
struct AlertHistoryView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    private var manager: AlertThresholdManager { AlertThresholdManager.shared }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                if manager.alertHistory.isEmpty {
                    emptyState
                } else {
                    trendChartSection
                    alertListSection
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Alert History")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            if !manager.alertHistory.isEmpty {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    clearAllButton
                }
                #else
                ToolbarItem(placement: .automatic) {
                    clearAllButton
                }
                #endif
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "bell.slash")
                .font(.system(size: 44))
                .foregroundStyle(theme.textTertiary)

            Text("No Alerts Yet")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("Alert history will appear here when metric thresholds are exceeded.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingMD * 2)
        .modifier(GlassCard())
        .padding(.top, theme.spacingSM)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No alerts yet. Configure thresholds to start monitoring.")
    }

    // MARK: - Trend Chart Section

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("7-Day Trend")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                if trendData.isEmpty {
                    Rectangle()
                        .fill(theme.bgSecondary)
                        .frame(height: 120)
                        .overlay {
                            Text("No alerts in the last 7 days")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                } else {
                    Chart(trendData) { item in
                        BarMark(
                            x: .value("Day", item.day, unit: .day),
                            y: .value("Alerts", item.count)
                        )
                        .foregroundStyle(by: .value("Metric", item.metricType.displayName))
                        .cornerRadius(3)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                .font(.caption2)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let v = value.as(Int.self) {
                                    Text("\(v)")
                                        .font(.caption2)
                                        .foregroundStyle(theme.textTertiary)
                                }
                            }
                        }
                    }
                    .chartForegroundStyleScale([
                        AlertMetricType.cpu.displayName: theme.entitySystem,
                        AlertMetricType.memory.displayName: theme.entitySystem.opacity(0.65),
                        AlertMetricType.disk.displayName: theme.accent,
                        AlertMetricType.network.displayName: theme.warning
                    ])
                    .frame(height: 140)
                    .accessibilityLabel("7-day alert trend chart")
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Alert List Section

    private var alertListSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("History (\(manager.alertHistory.count))")

            VStack(spacing: 0) {
                ForEach(manager.alertHistory) { record in
                    alertRow(record)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    manager.removeAlertRecord(id: record.id)
                                }
                                HapticManager.selection()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                    if record.id != manager.alertHistory.last?.id {
                        Divider()
                            .background(theme.bgTertiary)
                            .padding(.leading, theme.spacingMD + 28 + theme.spacingMD)
                    }
                }
            }
            .modifier(GlassCard())
        }
    }

    @ViewBuilder
    private func alertRow(_ record: AlertRecord) -> some View {
        HStack(spacing: theme.spacingMD) {
            // Metric icon
            Image(systemName: icon(for: record.metricType))
                .font(.system(size: theme.fontBody, weight: .semibold))
                .foregroundStyle(color(for: record.metricType))
                .frame(width: 28, alignment: .center)

            // Detail column
            VStack(alignment: .leading, spacing: 3) {
                Text(record.metricType.displayName)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                HStack(spacing: 4) {
                    Text(formattedValue(record.triggeredValue, type: record.metricType))
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(color(for: record.metricType))
                        .monospacedDigit()

                    Text("·")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    Text("threshold \(formattedThreshold(record.thresholdValue, type: record.metricType))")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            // Timestamp
            Text(formattedTimestamp(record.timestamp))
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(theme.spacingMD)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: record))
    }

    // MARK: - Toolbar Button

    private var clearAllButton: some View {
        Button {
            withAnimation {
                manager.clearHistory()
            }
            HapticManager.selection()
        } label: {
            Text("Clear All")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.error)
        }
        .accessibilityLabel("Clear all alert history")
    }

    // MARK: - Section Label

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    // MARK: - Trend Data Model

    private struct AlertDayCount: Identifiable {
        let id = UUID()
        let day: Date
        let metricType: AlertMetricType
        let count: Int
    }

    /// Groups alert history into per-day, per-metric counts for the last 7 days.
    private var trendData: [AlertDayCount] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        var results: [AlertDayCount] = []

        for dayOffset in (0..<7).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) else {
                continue
            }
            for type in AlertMetricType.allCases {
                let count = manager.alertHistory.filter { record in
                    record.metricType == type && calendar.isDate(record.timestamp, inSameDayAs: dayStart)
                }.count
                if count > 0 {
                    results.append(AlertDayCount(day: dayStart, metricType: type, count: count))
                }
            }
        }
        return results
    }

    // MARK: - Metric Helpers

    private func icon(for type: AlertMetricType) -> String {
        switch type {
        case .cpu:     return "cpu"
        case .memory:  return "memorychip"
        case .disk:    return "internaldrive"
        case .network: return "wifi.slash"
        }
    }

    private func color(for type: AlertMetricType) -> Color {
        switch type {
        case .cpu:     return theme.entitySystem
        case .memory:  return theme.entitySystem
        case .disk:    return theme.accent
        case .network: return theme.warning
        }
    }

    // MARK: - Formatting

    private func formattedValue(_ value: Double, type: AlertMetricType) -> String {
        if type == .network {
            return value == 0 ? "Offline" : "Online"
        }
        return String(format: "%.1f%@", value, type.unit)
    }

    private func formattedThreshold(_ value: Double, type: AlertMetricType) -> String {
        if type == .network {
            return "Offline"
        }
        return String(format: "%.1f%@", value, type.unit)
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = .current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday\n" + formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d\nh:mm a"
            return formatter.string(from: date)
        }
    }

    private func accessibilityLabel(for record: AlertRecord) -> String {
        "\(record.metricType.displayName) alert. " +
        "Value: \(formattedValue(record.triggeredValue, type: record.metricType)), " +
        "threshold: \(formattedThreshold(record.thresholdValue, type: record.metricType)). " +
        "Time: \(formattedTimestamp(record.timestamp))"
    }
}

// MARK: - Preview

#Preview("With History") {
    NavigationStack {
        AlertHistoryView()
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}

#Preview("Empty State") {
    NavigationStack {
        AlertHistoryView()
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
