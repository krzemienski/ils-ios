import SwiftUI
import ILSShared

/// Full-detail health score sheet for a single ``ChatSession``.
///
/// Presents the overall score as a large circular arc gauge, a colour-coded
/// level indicator, actionable recommendations (when present), and a
/// per-factor breakdown showing each signal's sub-score, weight, and description.
///
/// Data is fetched via ``SessionHealthViewModel`` on appearance using `.task`.
/// While loading a centred ``ProgressView`` is shown; on failure an error card
/// with a retry button is displayed.
///
/// ## Topics
/// ### State
/// - ``viewModel`` — Owns health data fetching and display helpers
struct SessionHealthDetailView: View {
    let session: ChatSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    @State private var viewModel = SessionHealthViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingHealth {
                    ProgressView("Loading health data…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.healthError,
                          viewModel.healthScore == nil {
                    errorView(message: errorMessage)
                } else {
                    scrollContent
                }
            }
            .background(theme.bgPrimary)
            .navigationTitle("Session Health")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                viewModel.configure(client: appState.apiClient)
                await viewModel.loadHealth(sessionId: session.id)
            }
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: theme.spacingLG) {
                scoreGauge
                levelBadge

                if let healthScore = viewModel.healthScore,
                   !healthScore.recommendations.isEmpty {
                    recommendationsCard(recommendations: healthScore.recommendations)
                }

                if let healthScore = viewModel.healthScore,
                   !healthScore.factors.isEmpty {
                    factorsSection(factors: healthScore.factors)
                }

                if let computedAt = viewModel.healthScore?.computedAt {
                    Text("Computed \(computedAt.formatted())")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(theme.spacingMD)
        }
    }

    // MARK: - Score Gauge

    private var scoreGauge: some View {
        let gaugeColor = levelColor(for: viewModel.healthScore?.level)
        let progress = CGFloat(viewModel.healthScore?.score ?? 0) / 100.0

        return ZStack {
            // Background track
            Circle()
                .stroke(gaugeColor.opacity(0.15), lineWidth: 16)

            // Filled arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    gaugeColor,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)

            // Score text
            VStack(spacing: 2) {
                Text(viewModel.formattedScore)
                    .font(.system(size: 48, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(gaugeColor)
                    .monospacedDigit()
                Text("out of 100")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(width: 180, height: 180)
        .padding(.top, theme.spacingSM)
    }

    // MARK: - Level Badge

    private var levelBadge: some View {
        let level = viewModel.healthScore?.level
        let color = levelColor(for: level)

        return HStack(spacing: theme.spacingSM) {
            Image(systemName: viewModel.scoreIcon)
                .font(.system(size: theme.fontTitle3, weight: .semibold))
                .foregroundStyle(color)
            Text(levelName(for: level))
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(color)
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Recommendations Card

    private func recommendationsCard(recommendations: [String]) -> some View {
        let cardColor = levelColor(for: viewModel.healthScore?.level)

        return GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                ForEach(recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: theme.spacingSM) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(cardColor)
                        Text(recommendation)
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Recommendations", systemImage: "lightbulb.fill")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(cardColor)
        }
    }

    // MARK: - Factors Section

    private func factorsSection(factors: [HealthScoreFactor]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Score Breakdown")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: theme.spacingXS) {
                ForEach(factors, id: \.factorId) { factor in
                    factorRow(factor)
                }
            }
        }
    }

    private func factorRow(_ factor: HealthScoreFactor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: theme.spacingXS) {
                Text(factor.name)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text(String(format: "%.0f", factor.score))
                    .font(.system(size: theme.fontBody, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(factorScoreColor(factor.score))
                    .monospacedDigit()
                Text(String(format: "× %.0f%%", factor.weight * 100))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            ProgressView(value: factor.score, total: 100)
                .tint(factorScoreColor(factor.score))

            Text(factor.description)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(theme.spacingSM)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "heart.slash")
                .font(.largeTitle)
                .foregroundStyle(theme.error)
            Text("Failed to load health data")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadHealth(sessionId: session.id) }
            }
        }
        .padding(theme.spacingMD)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func levelColor(for level: HealthScoreLevel?) -> Color {
        switch level {
        case .healthy:     return theme.success
        case .degrading:   return theme.warning
        case .problematic: return theme.error
        case nil:          return theme.textSecondary
        }
    }

    private func levelName(for level: HealthScoreLevel?) -> String {
        switch level {
        case .healthy:     return "Healthy"
        case .degrading:   return "Degrading"
        case .problematic: return "Critical"
        case nil:          return "Unknown"
        }
    }

    /// Maps a factor sub-score to a semantic colour (same thresholds as ``HealthScoreLevel``).
    private func factorScoreColor(_ score: Double) -> Color {
        if score >= 70 { return theme.success }
        if score >= 40 { return theme.warning }
        return theme.error
    }
}

