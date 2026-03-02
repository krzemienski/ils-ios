import SwiftUI
import ILSShared

/// Displays aggregated model usage statistics fetched from the backend.
///
/// Shows a header with the total session count, a per-model breakdown with
/// percentage bars and cost summaries, and an empty state when no sessions
/// have been created yet.
struct ModelStatsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var viewModel = ModelStatsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading statistics…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                errorView(error)
            } else if let stats = viewModel.stats {
                if stats.totalSessions == 0 {
                    emptyStateView
                } else {
                    statsList(stats)
                }
            } else {
                emptyStateView
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Model Usage")
        .inlineNavigationBarTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.loadStats() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                }
                .foregroundStyle(theme.accent)
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadStats()
        }
    }

    // MARK: - Stats List

    @ViewBuilder
    private func statsList(_ stats: ModelStatsResponse) -> some View {
        List {
            Section {
                HStack {
                    Text("Total Sessions")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("\(stats.totalSessions)")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                }

                if let dominant = stats.dominantModel {
                    HStack {
                        Text("Most Used")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text(dominant.capitalized)
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                    }
                }
            } header: {
                Text("Summary")
            }

            Section {
                ForEach(stats.stats, id: \.model) { stat in
                    modelStatRow(stat, totalSessions: stats.totalSessions)
                }
            } header: {
                Text("By Model")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
    }

    // MARK: - Model Stat Row

    @ViewBuilder
    private func modelStatRow(_ stat: ModelUsageStat, totalSessions: Int) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                Text(stat.model.capitalized)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text("\(stat.sessionCount) sessions")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            // Percentage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.bgTertiary)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor(for: stat.model))
                        .frame(width: geo.size.width * stat.percentage, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text(String(format: "%.1f%%", stat.percentage * 100))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                if let cost = stat.totalCostUSD {
                    Text(String(format: "$%.4f total", cost))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
        .padding(.vertical, theme.spacingXS)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text("No Usage Data Yet")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text("Create sessions to see model usage statistics here.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.spacingLG)
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, design: theme.fontDesign))
                .foregroundStyle(theme.warning)
            Text("Failed to Load Statistics")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text(error.localizedDescription)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadStats() }
            }
            .foregroundStyle(theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.spacingLG)
    }

    // MARK: - Helpers

    private func barColor(for model: String) -> Color {
        switch model.lowercased() {
        case "haiku":  return theme.success
        case "sonnet": return theme.accent
        case "opus":   return theme.warning
        default:       return theme.textTertiary
        }
    }
}

#Preview {
    NavigationStack {
        ModelStatsView()
            .environment(AppState())
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
