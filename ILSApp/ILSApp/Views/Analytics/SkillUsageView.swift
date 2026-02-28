import SwiftUI
import ILSShared

/// Card view displaying skill usage analytics with active/inactive status indicators.
///
/// Renders a header with the skill count, a scrollable list of ``SkillUsageStat`` rows
/// each showing an active/inactive status dot, usage percentage progress bar, invocation
/// count badge, and optional effectiveness star rating.  An empty-state placeholder is
/// shown when ``analytics`` is `nil` or contains no skill stats.
///
/// ## Topics
/// ### Parameters
/// - ``analytics`` - The skill analytics response to display; pass `nil` for the empty-state.
///
/// ### Sections
/// - ``headerRow`` - Title, skill count subtitle, and top-skill callout badge.
/// - ``skillList(stats:)`` - Sorted list of skill rows with status indicators and progress bars.
/// - ``skillRow(stat:)`` - A single skill row: status dot, name, bar, and invocation count.
/// - ``emptyState`` - Placeholder shown when ``analytics`` is `nil` or has no stats.
///
/// ### Helpers
/// - ``activeSkillCount`` - Number of skills with at least one invocation.
/// - ``statusColor(for:)`` - Returns green for active skills, gray for inactive ones.
struct SkillUsageView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// The skill analytics data to display.  Pass `nil` to show the empty-state placeholder.
    let analytics: SkillAnalyticsResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            headerRow

            if let analytics, !analytics.skillStats.isEmpty {
                skillList(stats: analytics.skillStats)
            } else {
                emptyState
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Header

    /// Title, optional skill-count subtitle, and top-skill callout badge.
    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Skill Usage")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                if let analytics, !analytics.skillStats.isEmpty {
                    Text(subtitleText(analytics: analytics))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            // Top skill callout badge
            if let topStat = analytics?.skillStats.first, topStat.invocationCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(topStat.invocationCount)")
                        .font(.system(size: theme.fontBody, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(theme.success)
                    Text("Top skill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Top skill: \(topStat.skillName) with \(topStat.invocationCount) invocations")
            }
        }
    }

    // MARK: - Skill List

    /// Sorted list of skill rows, ordered by invocation count descending.
    private func skillList(stats: [SkillUsageStat]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            let sorted = stats.sorted { $0.invocationCount > $1.invocationCount }
            ForEach(sorted) { stat in
                skillRow(stat: stat)
            }
        }
    }

    /// A single skill row: status indicator dot, name, usage bar, and invocation count.
    private func skillRow(stat: SkillUsageStat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: theme.spacingXS) {
                // Active / inactive status dot
                Circle()
                    .fill(statusColor(for: stat))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                // Skill name
                Text(stat.skillName)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Invocation count badge
                Text("\(stat.invocationCount) call\(stat.invocationCount == 1 ? "" : "s")")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }

            // Usage percentage progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.bgSecondary)
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(statusColor(for: stat).gradient)
                        .frame(
                            width: geo.size.width * (stat.usagePercentage / 100.0).clamped(to: 0...1),
                            height: 5
                        )
                }
            }
            .frame(height: 5)

            // Effectiveness rating row (shown only when data is present)
            if let rating = stat.avgEffectivenessRating {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                            .font(.system(size: 9))
                            .foregroundStyle(Double(star) <= rating ? theme.warning : theme.textTertiary)
                    }
                    Text(String(format: "%.1f avg effectiveness", rating))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: "Average effectiveness: %.1f out of 5", rating))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: stat))
    }

    // MARK: - Empty State

    /// Placeholder shown when ``analytics`` is `nil` or has no skill stats.
    private var emptyState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text("No skill usage data")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No skill usage data available")
    }

    // MARK: - Helpers

    /// Number of skills in the response that have at least one invocation.
    private var activeSkillCount: Int {
        analytics?.skillStats.filter { $0.invocationCount > 0 }.count ?? 0
    }

    /// Returns the status indicator colour: green for active skills, gray for inactive.
    ///
    /// - Parameter stat: The skill usage stat to evaluate.
    /// - Returns: ``ThemeSnapshot/success`` when invocationCount > 0, ``ThemeSnapshot/textTertiary`` otherwise.
    private func statusColor(for stat: SkillUsageStat) -> Color {
        stat.invocationCount > 0 ? theme.success : theme.textTertiary
    }

    /// Builds a subtitle string summarising active vs. total skill counts.
    ///
    /// - Parameter analytics: The analytics response to derive counts from.
    /// - Returns: A string such as `"3 of 5 skills active"`.
    private func subtitleText(analytics: SkillAnalyticsResponse) -> String {
        let total = analytics.skillStats.count
        let active = analytics.skillStats.filter { $0.invocationCount > 0 }.count
        return "\(active) of \(total) skill\(total == 1 ? "" : "s") active"
    }

    /// VoiceOver label for a skill row combining name, invocations, sessions, and status.
    ///
    /// - Parameter stat: The skill usage stat to describe.
    /// - Returns: An accessibility label string.
    private func accessibilityLabel(for stat: SkillUsageStat) -> String {
        let status = stat.invocationCount > 0 ? "active" : "inactive"
        return "\(stat.skillName), \(status), \(stat.invocationCount) invocations in \(stat.sessionCount) session\(stat.sessionCount == 1 ? "" : "s"), \(String(format: "%.0f", stat.usagePercentage))% usage"
    }
}

// MARK: - Comparable+Clamped (local extension)

private extension Comparable {
    /// Clamps the value to the given closed range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview {
    let sampleStats = [
        SkillUsageStat(
            skillName: "code-review",
            invocationCount: 42,
            sessionCount: 18,
            usagePercentage: 60.0,
            avgEffectivenessRating: 4.3
        ),
        SkillUsageStat(
            skillName: "test-generator",
            invocationCount: 27,
            sessionCount: 12,
            usagePercentage: 40.0,
            avgEffectivenessRating: 3.8
        ),
        SkillUsageStat(
            skillName: "commit",
            invocationCount: 19,
            sessionCount: 9,
            usagePercentage: 30.0,
            avgEffectivenessRating: nil
        ),
        SkillUsageStat(
            skillName: "doc-writer",
            invocationCount: 5,
            sessionCount: 3,
            usagePercentage: 10.0,
            avgEffectivenessRating: 2.5
        ),
        SkillUsageStat(
            skillName: "refactor-helper",
            invocationCount: 0,
            sessionCount: 0,
            usagePercentage: 0.0,
            avgEffectivenessRating: nil
        ),
    ]

    let sampleAnalytics = SkillAnalyticsResponse(
        projectName: "my-project",
        totalSessions: 30,
        skillStats: sampleStats,
        startDate: "2024-01-01",
        endDate: "2024-01-07"
    )

    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                SkillUsageView(analytics: sampleAnalytics)
                SkillUsageView(analytics: nil)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
