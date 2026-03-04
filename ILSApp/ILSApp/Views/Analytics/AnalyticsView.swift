import SwiftUI
import Charts
import ILSShared

/// Main analytics dashboard view providing project activity and usage insights.
///
/// Displays a segmented period picker (week / month), a high-level summary card with key
/// metrics, and three sub-section views: ``ActivityTimelineView`` for the session bar chart,
/// ``SessionMetricsView`` for completion and model breakdown, and ``SkillUsageView`` for
/// skill adoption statistics.  A toolbar export button generates a shareable JSON payload
/// via ``ShareLink``.  While data is loading for the first time a shimmer skeleton is shown
/// in place of the content sections.  If any request fails, an inline error banner with a
/// Retry action appears above the stale (or empty) content.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - Observable analytics view model that owns all data loading
/// - ``exportJSON`` - Cached JSON string of the last export payload; drives ``ShareLink``
/// - ``isExporting`` - Tracks in-flight export fetch; shows a spinner in the toolbar
///
/// ### Sections
/// - ``periodPicker`` - Segmented picker binding to ``AnalyticsViewModel/selectedPeriod``
/// - ``summarySection`` - Key-metric cards derived from ``AnalyticsSummary``
/// - ``errorBanner`` - Inline error banner with a Retry action
/// - ``loadingSkeleton`` - Shimmer placeholder shown while ``viewModel.isLoading`` is true
struct AnalyticsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Observable view model that manages all analytics data loading and state.
    @State private var viewModel = AnalyticsViewModel()
    /// Cached JSON string from the last export fetch; non-nil enables the ``ShareLink``.
    @State private var exportJSON: String?
    /// Whether an export fetch is currently in flight; shows a spinner in the toolbar.
    @State private var isExporting = false
    /// Mirrors the same AppStorage key used by AnalyticsViewModel to gate loading.
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                // Period Picker
                periodPicker

                if !analyticsEnabled {
                    // Analytics disabled — show informational banner
                    analyticsDisabledBanner
                } else if viewModel.isLoading && viewModel.summary == nil {
                    // Show shimmer skeleton only on the first load (no cached data yet)
                    loadingSkeleton
                } else {
                    // Inline error banner — shown even when partial data is present
                    errorBanner

                    // High-level summary metrics
                    summarySection

                    // Sub-section charts and lists
                    ActivityTimelineView(data: viewModel.activityTimeline)
                    SessionMetricsView(metrics: viewModel.sessionMetrics)
                    SkillUsageView(analytics: viewModel.skillAnalytics)
                    FileTypeBreakdownView()
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Analytics")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                exportButton
            }
            #else
            ToolbarItem(placement: .automatic) {
                exportButton
            }
            #endif
        }
        .onAppear {
            viewModel.configure(client: appState.apiClient)
            Task {
                await viewModel.loadAll()
            }
        }
        .onChange(of: viewModel.selectedPeriod) { _, _ in
            // Reload all data when the user switches the time period
            exportJSON = nil  // Clear stale export when period changes
            Task {
                await viewModel.loadAll()
            }
        }
    }

    // MARK: - Period Picker

    /// Segmented control binding to ``AnalyticsViewModel/selectedPeriod``.
    ///
    /// Switching the selection triggers a full data reload via `onChange(of: viewModel.selectedPeriod)`.
    private var periodPicker: some View {
        Picker("Period", selection: Bindable(viewModel).selectedPeriod) {
            ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, theme.spacingXS)
        .accessibilityLabel("Analytics time period")
        .accessibilityHint("Switch between Last 7 Days and Last 30 Days")
    }

    // MARK: - Summary Section

    /// High-level metrics card sourced from ``AnalyticsSummary``.
    ///
    /// Renders a 2×2 grid of ``AnalyticsSummaryCard`` tiles for sessions, messages,
    /// completion rate, and token usage.  Optional highlights for the top model and
    /// week-over-week change appear below the grid when the server provides them.
    @ViewBuilder
    private var summarySection: some View {
        if let summary = viewModel.summary {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Text("Summary")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: theme.spacingSM
                ) {
                    AnalyticsSummaryCard(
                        title: "Sessions",
                        value: "\(summary.totalSessions)",
                        icon: "text.bubble.fill",
                        color: theme.accent
                    )
                    AnalyticsSummaryCard(
                        title: "Messages",
                        value: "\(summary.totalMessages)",
                        icon: "message.fill",
                        color: theme.entitySystem
                    )
                    AnalyticsSummaryCard(
                        title: "Completion",
                        value: String(format: "%.0f%%", summary.completionRate),
                        icon: "checkmark.circle.fill",
                        color: theme.success
                    )
                    AnalyticsSummaryCard(
                        title: "Tokens",
                        value: formatTokenCount(summary.totalTokensUsed),
                        icon: "sparkles",
                        color: theme.warning
                    )
                }

                // Top model highlight
                if let topModel = summary.topModel {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                        Text("Top model: ")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                        Text(topModel)
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .padding(.top, theme.spacingXS)
                }

                // Week-over-week change indicator
                if let wowChange = summary.weekOverWeekChange {
                    let isPositive = wowChange >= 0
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(isPositive ? theme.success : theme.error)
                        Text(String(format: "%.0f%% week over week", abs(wowChange)))
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(isPositive ? theme.success : theme.error)
                    }
                    .padding(.top, theme.spacingXS)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Error Banner

    /// Inline error banner displayed when ``AnalyticsViewModel/error`` is non-nil.
    ///
    /// Shows the localised error description and a Retry button that re-triggers
    /// ``AnalyticsViewModel/retryLoad()``.
    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.error {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Failed to load analytics")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text(error.localizedDescription)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    Task { await viewModel.retryLoad() }
                } label: {
                    Text("Retry")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, theme.spacingXS)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .accessibilityLabel("Retry loading analytics")
            }
            .padding(theme.spacingMD)
            .background(theme.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.warning.opacity(0.3), lineWidth: 0.5)
            )
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Analytics Disabled Banner

    /// Informational banner shown when the user has disabled analytics collection.
    ///
    /// Instructs the user to re-enable analytics via the Settings toggle and provides
    /// a direct navigation link to the Settings screen via ``AppState/navigationIntent``.
    private var analyticsDisabledBanner: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "chart.bar.xmark")
                .font(.system(size: 48, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("Analytics Collection Disabled")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("Analytics data collection is turned off. Enable it in Settings to view activity timelines, session metrics, and skill usage.")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                appState.navigationIntent = .settings
            } label: {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "gearshape.fill")
                    Text("Open Settings")
                }
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textOnAccent)
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .accessibilityLabel("Open Settings to enable analytics")
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingLG)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Loading Skeleton

    /// Shimmer skeleton shown on the first load before any data arrives.
    ///
    /// Renders four placeholder cards that match the approximate heights of the
    /// summary card and the three sub-section cards below it.
    private var loadingSkeleton: some View {
        VStack(spacing: theme.spacingSM) {
            // Summary card placeholder
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .fill(theme.bgSecondary)
                .frame(height: 160)
                .shimmer()

            // Timeline placeholder
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .fill(theme.bgSecondary)
                .frame(height: 200)
                .shimmer()

            // Session metrics placeholder
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .fill(theme.bgSecondary)
                .frame(height: 180)
                .shimmer()

            // Skill usage placeholder
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .fill(theme.bgSecondary)
                .frame(height: 140)
                .shimmer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading analytics data")
    }

    // MARK: - Export Button

    /// Toolbar button that fetches a JSON export and presents a system share sheet.
    ///
    /// On first tap the button fetches the export payload from the backend and caches
    /// the JSON string in ``exportJSON``.  Subsequent taps re-use the cached value so
    /// the share sheet opens immediately.  While the fetch is in flight a spinner
    /// replaces the icon.
    @ViewBuilder
    private var exportButton: some View {
        if isExporting {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
        } else if let json = exportJSON {
            ShareLink(
                item: json,
                subject: Text("ILS Analytics Export"),
                message: Text("Analytics data exported from ILS")
            ) {
                Image(systemName: "square.and.arrow.up")
            }
        } else {
            Button {
                Task {
                    isExporting = true
                    if let exportData = await viewModel.exportData(),
                       let encoded = try? JSONEncoder().encode(exportData),
                       let jsonStr = String(data: encoded, encoding: .utf8) {
                        exportJSON = jsonStr
                    }
                    isExporting = false
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Export analytics data")
            .accessibilityHint("Generates a JSON export of your analytics")
        }
    }

    // MARK: - Helpers

    /// Formats a raw token count into a human-readable abbreviated string.
    ///
    /// Returns values in plain digits for counts below 1 000, `K` suffix for
    /// thousands, and `M` suffix for millions.
    ///
    /// - Parameter count: The number of tokens to format.
    /// - Returns: A string such as `"42"`, `"1.4K"`, or `"2.3M"`.
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Analytics Summary Card

/// A compact metric tile used in the 2×2 analytics summary grid.
///
/// Renders an SF Symbols icon, a bold numeric value, and a short title label.
/// The icon colour is injected by the parent to visually distinguish each metric.
private struct AnalyticsSummaryCard: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Short label describing the metric (e.g., "Sessions", "Tokens").
    let title: String
    /// Formatted value string to display prominently (e.g., "42", "1.4K").
    let value: String
    /// SF Symbols name for the icon shown at the top of the card.
    let icon: String
    /// Accent colour applied to the icon.
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: theme.fontBody))
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(title)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    NavigationStack {
        AnalyticsView()
            .environment(AppState())
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
