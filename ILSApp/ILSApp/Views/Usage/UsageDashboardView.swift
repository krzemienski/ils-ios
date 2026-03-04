import SwiftUI
import Charts
import ILSShared

/// Usage and rate-limit monitoring dashboard.
///
/// Presents Claude Code usage statistics for the selected time period, including a
/// rate-limit consumption gauge, a daily-message-count bar chart, a per-project
/// breakdown list, and an Export toolbar button that triggers a `ShareSheet`.
///
/// ## Topics
/// ### Sections
/// - ``rateLimitSection`` - ProgressView gauge with colour-coded warning/danger states
/// - ``periodPicker`` - Day / Week / Month segmented ``Picker``
/// - ``trendChartSection`` - ``BarMark`` chart plotting daily message counts
/// - ``projectBreakdownSection`` - Per-project message-count list
///
/// ### Export
/// - ``exportToolbarButton`` - Toolbar button that triggers CSV export and ``ShareSheet``
struct UsageDashboardView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var viewModel = UsageDashboardViewModel()
    /// Controls presentation of the CSV ShareSheet after a successful export.
    @State private var showShareSheet = false
    /// Controls presentation of the alert-settings sheet.
    @State private var showAlertSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                periodPicker
                rateLimitSection
                trendChartSection
                projectBreakdownSection
                statsRow
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Usage")
        .inlineNavigationBarTitle()
        .toolbar {
            #if os(iOS)
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                alertSettingsButton
                exportToolbarButton
            }
            #else
            ToolbarItemGroup(placement: .automatic) {
                alertSettingsButton
                exportToolbarButton
            }
            #endif
        }
        .sheet(isPresented: $showShareSheet) {
            exportShareSheet
        }
        .sheet(isPresented: $showAlertSettings) {
            AlertSettingsSheet(viewModel: viewModel)
                .environment(\.theme, theme)
        }
        .overlay {
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadAll()
        }
        .onChange(of: viewModel.selectedPeriod) { _, _ in
            Task { await viewModel.loadAll() }
        }
        .onChange(of: viewModel.exportData) { _, data in
            if data != nil {
                showShareSheet = true
            }
        }
        .onChange(of: appState.serverURL) { _, _ in
            viewModel.configure(client: appState.apiClient)
            Task { await viewModel.loadAll() }
        }
        .refreshable {
            await viewModel.loadAll()
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: Binding(
            get: { viewModel.selectedPeriod },
            set: { viewModel.selectedPeriod = $0 }
        )) {
            Text("Day").tag(UsagePeriod.daily)
            Text("Week").tag(UsagePeriod.weekly)
            Text("Month").tag(UsagePeriod.monthly)
        }
        .pickerStyle(.segmented)
        .padding(.top, theme.spacingSM)
    }

    // MARK: - Rate Limit Section

    @ViewBuilder
    private var rateLimitSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                Image(systemName: "gauge.with.needle")
                    .foregroundStyle(rateLimitColor)
                Text("Rate Limit")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text(viewModel.rateLimitSummary)
                    .font(.system(size: theme.fontBody, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(rateLimitColor)
            }

            ProgressView(value: progressValue, total: 1.0)
                .progressViewStyle(.linear)
                .tint(rateLimitColor)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                .accessibilityValue(
                    "\(Int(viewModel.rateLimitPercentage)) percent consumed"
                )

            HStack {
                if let status = viewModel.metrics?.rateLimitStatus {
                    Text("\(status.messagesRemaining) messages remaining")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)

                    Spacer()

                    if let resetsAt = status.windowResetsAt, !resetsAt.isEmpty {
                        Text("Resets \(formattedResetTime(resetsAt))")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                } else {
                    Text("No data")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
            }

            if viewModel.isNearingLimit {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.warning)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    Text("Approaching rate limit (\(viewModel.alertThreshold)% threshold)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.warning)
                }
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, theme.spacingXS)
                .background(theme.warning.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard(padding: 0))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Rate limit: \(viewModel.rateLimitSummary), \(Int(viewModel.rateLimitPercentage)) percent consumed"
        )
    }

    // MARK: - Trend Chart Section

    @ViewBuilder
    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                Text("Message Trend")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if !viewModel.filteredDailyData.isEmpty {
                    Text("\(viewModel.filteredDailyData.map(\.messageCount).reduce(0, +)) total")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            let data = viewModel.filteredDailyData
            if data.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(data) { day in
                    BarMark(
                        x: .value("Date", day.date),
                        y: .value("Messages", day.messageCount)
                    )
                    .foregroundStyle(theme.accent.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(data.count, 7))) { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(shortDate(label))
                                    .font(.system(size: theme.fontCaption - 2, design: theme.fontDesign))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                        AxisGridLine()
                            .foregroundStyle(theme.borderSubtle)
                    }
                }
                .frame(height: 160)
                .accessibilityLabel("Daily message count bar chart for the selected period")
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard(padding: 0))
    }

    // MARK: - Project Breakdown Section

    @ViewBuilder
    private var projectBreakdownSection: some View {
        let projects = viewModel.metrics?.projectBreakdown ?? []
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Projects")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            if projects.isEmpty {
                Text("No project data for this period")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, theme.spacingMD)
            } else {
                VStack(spacing: theme.spacingXS) {
                    ForEach(projects) { project in
                        ProjectUsageRow(project: project, theme: theme)
                    }
                }
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard(padding: 0))
    }

    // MARK: - Stats Row

    @ViewBuilder
    private var statsRow: some View {
        if let metrics = viewModel.metrics {
            HStack(spacing: theme.spacingMD) {
                UsageStatCell(
                    label: "Sessions",
                    value: "\(metrics.totalSessions)",
                    icon: "bubble.left.and.bubble.right",
                    color: theme.entitySession,
                    theme: theme
                )
                UsageStatCell(
                    label: "Avg/Session",
                    value: String(format: "%.1f", metrics.averageMessagesPerSession),
                    icon: "chart.bar",
                    color: theme.entityProject,
                    theme: theme
                )
                UsageStatCell(
                    label: "Duration",
                    value: formatDuration(metrics.totalDurationSeconds),
                    icon: "clock",
                    color: theme.entitySystem,
                    theme: theme
                )
            }
        }
    }

    // MARK: - Toolbar Buttons

    private var exportToolbarButton: some View {
        Button {
            Task {
                await viewModel.exportUsage(format: .csv)
            }
        } label: {
            if viewModel.isExporting {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .disabled(viewModel.isExporting || viewModel.metrics == nil)
        .accessibilityLabel("Export usage as CSV")
    }

    private var alertSettingsButton: some View {
        Button {
            showAlertSettings = true
        } label: {
            Image(systemName: viewModel.alertsEnabled ? "bell.fill" : "bell")
                .foregroundStyle(viewModel.alertsEnabled ? theme.accent : theme.textSecondary)
        }
        .accessibilityLabel("Alert settings")
    }

    // MARK: - Share Sheet

    @ViewBuilder
    private var exportShareSheet: some View {
        if let data = viewModel.exportData,
           let text = String(data: data, encoding: .utf8) {
            ShareSheet(text: text, fileName: "usage-export-\(viewModel.selectedPeriod.rawValue).csv")
        }
    }

    // MARK: - Empty Chart Placeholder

    private var emptyChartPlaceholder: some View {
        Rectangle()
            .fill(theme.bgTertiary)
            .frame(height: 100)
            .overlay {
                Text("No data for this period")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.clear
            VStack(spacing: theme.spacingSM) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(theme.accent)
                Text("Loading…")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Computed Properties

    /// ProgressView value clamped to [0, 1].
    private var progressValue: Double {
        min(1.0, max(0.0, viewModel.rateLimitPercentage / 100.0))
    }

    /// Colour for the rate-limit gauge — green below 60%, warning 60–80%, danger above 80%.
    private var rateLimitColor: Color {
        let pct = viewModel.rateLimitPercentage
        if pct >= 80 { return theme.error }
        if pct >= 60 { return theme.warning }
        return theme.success
    }

    // MARK: - Formatting Helpers

    private func shortDate(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count >= 3 else { return iso }
        return "\(parts[1])/\(parts[2])"
    }

    private func formattedResetTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return iso }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(seconds)s"
    }
}

// MARK: - Project Usage Row

private struct ProjectUsageRow: View {
    let project: ProjectUsage
    let theme: ThemeSnapshot

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "folder.fill")
                .foregroundStyle(theme.entityProject)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))

            VStack(alignment: .leading, spacing: 2) {
                Text(project.projectName)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text("\(project.sessionCount) session\(project.sessionCount == 1 ? "" : "s")")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(project.messageCount)")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(String(format: "%.0f%%", project.percentageOfTotal))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.vertical, theme.spacingXS)
        if project.percentageOfTotal > 0 {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.entityProject.opacity(0.25))
                    .frame(width: geo.size.width)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.entityProject)
                            .frame(width: geo.size.width * min(1, project.percentageOfTotal / 100))
                    }
            }
            .frame(height: 3)
        }
        Divider()
            .background(theme.divider)
    }
}

// MARK: - Usage Stat Cell

private struct UsageStatCell: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    let theme: ThemeSnapshot

    var body: some View {
        VStack(spacing: theme.spacingXS) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
            Text(value)
                .font(.system(size: theme.fontBody, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingMD)
        .modifier(GlassCard(padding: 0))
    }
}

// MARK: - Alert Settings Sheet

private struct AlertSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    var viewModel: UsageDashboardViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Usage Alerts") {
                    Toggle("Enable Alerts", isOn: Binding(
                        get: { viewModel.alertsEnabled },
                        set: { viewModel.alertsEnabled = $0 }
                    ))
                    .tint(theme.accent)

                    if viewModel.alertsEnabled {
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            HStack {
                                Text("Alert Threshold")
                                Spacer()
                                Text("\(viewModel.alertThreshold)%")
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(viewModel.alertThreshold) },
                                    set: { viewModel.alertThreshold = Int($0) }
                                ),
                                in: 50...95,
                                step: 5
                            )
                            .tint(theme.accent)
                            Text("You'll receive a notification when rate limit consumption reaches this percentage.")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }

                Section("About Rate Limits") {
                    Text(
                        "Claude Pro accounts share a rate limit of approximately 45 messages per 5-hour window. " +
                        "This dashboard tracks messages sent through ILS sessions. Alerts fire once per threshold crossing and reset automatically."
                    )
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                }
            }
            .navigationTitle("Alert Settings")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
