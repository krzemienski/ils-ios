import SwiftUI
import Charts
import ILSShared

/// Unified consumption and quota transparency dashboard.
///
/// Assembles burn-rate gauges, trend charts, model/project breakdowns,
/// anomaly cards, top sessions, and summary stats into a scrollable view.
/// Follows the same lifecycle and toolbar patterns as ``UsageDashboardView``.
///
/// ## Topics
/// ### Sections
/// - ``periodPicker`` – Day / Week / Month segmented ``Picker`` reusing ``UsagePeriod``
/// - ``burnRateSection`` – ``BurnRateGauge`` card
/// - ``trendChartSection`` – ``ConsumptionTrendChart`` with anomaly overlay
/// - ``modelBreakdownSection`` – Per-model consumption rows with percentage bars
/// - ``projectBreakdownSection`` – Per-project consumption rows
/// - ``anomalySection`` – ``AnomalyListSection`` (only when anomalies exist)
/// - ``topSessionsSection`` – Top 5 sessions by consumption
/// - ``statsRow`` – Total tokens, cost, sessions summary cells
struct ConsumptionDashboardView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var viewModel = ConsumptionDashboardViewModel()
    /// Controls presentation of the alert-settings sheet.
    @State private var showAlertSettings = false
    /// Controls presentation of the export ShareSheet.
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                periodPicker
                burnRateSection
                trendChartSection
                modelBreakdownSection
                projectBreakdownSection
                anomalySection
                topSessionsSection
                statsRow
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Consumption")
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
        .sheet(isPresented: $showAlertSettings) {
            ConsumptionAlertSettingsView(viewModel: viewModel)
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

    // MARK: - Burn Rate Section

    @ViewBuilder
    private var burnRateSection: some View {
        if let data = viewModel.consumptionData {
            BurnRateGauge(
                burnRate: data.burnRate,
                severity: viewModel.burnRateSeverity
            )
        }
    }

    // MARK: - Trend Chart Section

    @ViewBuilder
    private var trendChartSection: some View {
        ConsumptionTrendChart(
            data: viewModel.filteredDailyConsumption,
            anomalies: viewModel.activeAnomalies
        )
    }

    // MARK: - Model Breakdown Section

    @ViewBuilder
    private var modelBreakdownSection: some View {
        let models = viewModel.consumptionData?.modelBreakdown ?? []
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Models")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            if models.isEmpty {
                Text("No model data for this period")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, theme.spacingMD)
            } else {
                VStack(spacing: theme.spacingXS) {
                    ForEach(models) { model in
                        ModelConsumptionRow(model: model, theme: theme)
                    }
                }
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard(padding: 0))
    }

    // MARK: - Project Breakdown Section

    @ViewBuilder
    private var projectBreakdownSection: some View {
        let projects = viewModel.consumptionData?.projectBreakdown ?? []
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
                        ProjectConsumptionRow(project: project, theme: theme)
                    }
                }
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard(padding: 0))
    }

    // MARK: - Anomaly Section

    @ViewBuilder
    private var anomalySection: some View {
        AnomalyListSection(anomalies: viewModel.activeAnomalies)
    }

    // MARK: - Top Sessions Section

    @ViewBuilder
    private var topSessionsSection: some View {
        let sessions = Array((viewModel.consumptionData?.topSessionsByConsumption ?? []).prefix(5))
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Text("Top Sessions")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                VStack(spacing: theme.spacingXS) {
                    ForEach(sessions) { session in
                        SessionConsumptionRow(session: session, theme: theme)
                    }
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard(padding: 0))
        }
    }

    // MARK: - Stats Row

    @ViewBuilder
    private var statsRow: some View {
        if let data = viewModel.consumptionData {
            HStack(spacing: theme.spacingMD) {
                ConsumptionStatCell(
                    label: "Tokens",
                    value: formattedTokenCount(data.totalEstimatedTokens),
                    icon: "number",
                    color: theme.accent,
                    theme: theme
                )
                ConsumptionStatCell(
                    label: "Cost",
                    value: viewModel.totalEstimatedCostFormatted,
                    icon: "dollarsign.circle",
                    color: theme.entityProject,
                    theme: theme
                )
                ConsumptionStatCell(
                    label: "Sessions",
                    value: "\(data.totalSessions)",
                    icon: "bubble.left.and.bubble.right",
                    color: theme.entitySession,
                    theme: theme
                )
            }
        }
    }

    // MARK: - Toolbar Buttons

    private var alertSettingsButton: some View {
        Button {
            showAlertSettings = true
        } label: {
            Image(systemName: viewModel.consumptionAlertsEnabled ? "bell.fill" : "bell")
                .foregroundStyle(viewModel.consumptionAlertsEnabled ? theme.accent : theme.textSecondary)
        }
        .accessibilityLabel("Alert settings")
    }

    private var exportToolbarButton: some View {
        Button {
            // Export action placeholder — future subtask
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(viewModel.consumptionData == nil)
        .accessibilityLabel("Export consumption data")
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

    // MARK: - Formatting Helpers

    private func formattedTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000.0)
        }
        return "\(count)"
    }
}

// MARK: - Model Consumption Row

private struct ModelConsumptionRow: View {
    let model: ModelConsumption
    let theme: ThemeSnapshot

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "cpu")
                .foregroundStyle(theme.accent)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))

            VStack(alignment: .leading, spacing: 2) {
                Text(model.model)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text("\(model.messageCount) message\(model.messageCount == 1 ? "" : "s")")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedTokens(model.tokenCount))
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(String(format: "%.0f%%", model.percentageOfTotal))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.vertical, theme.spacingXS)
        if model.percentageOfTotal > 0 {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.accent.opacity(0.25))
                    .frame(width: geo.size.width)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.accent)
                            .frame(width: geo.size.width * min(1, model.percentageOfTotal / 100))
                    }
            }
            .frame(height: 3)
        }
        Divider()
            .background(theme.divider)
    }

    private func formattedTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000.0)
        }
        return "\(count)"
    }
}

// MARK: - Project Consumption Row

private struct ProjectConsumptionRow: View {
    let project: ProjectConsumption
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
                Text(formattedTokens(project.estimatedTokens))
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

    private func formattedTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000.0)
        }
        return "\(count)"
    }
}

// MARK: - Session Consumption Row

private struct SessionConsumptionRow: View {
    let session: SessionConsumption
    let theme: ThemeSnapshot

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "bubble.left.fill")
                .foregroundStyle(theme.entitySession)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.sessionName)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text(session.model)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedTokens(session.estimatedTokens))
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(formattedCost(session.estimatedCostUSD))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.vertical, theme.spacingXS)
        Divider()
            .background(theme.divider)
    }

    private func formattedTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000.0)
        }
        return "\(count)"
    }

    private func formattedCost(_ cost: Double) -> String {
        if cost < 0.01 { return "<$0.01" }
        return String(format: "$%.2f", cost)
    }
}

// MARK: - Consumption Stat Cell

private struct ConsumptionStatCell: View {
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
