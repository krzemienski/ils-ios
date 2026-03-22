import SwiftUI
import ILSShared
import Observation

// MARK: - TeamActivityWidgetViewModel

/// View model for the Team Activity dashboard widget.
///
/// Loads all agent teams from the `/teams` API endpoint and exposes the five
/// most-recently-active teams (sorted by member activity) for display.
///
/// ## Topics
/// ### Configuration
/// - ``configure(client:)`` - Bind to a direct API client for data loading
///
/// ### Data
/// - ``teams`` - Up to five teams shown in the widget
/// - ``totalCount`` - Total number of teams (may exceed five)
@Observable
@MainActor
final class TeamActivityWidgetViewModel: DashboardWidgetViewModel {

    // MARK: DashboardWidgetViewModel

    /// True while the widget is fetching its initial or refreshed data.
    private(set) var isLoading = true
    /// True when the backend is unreachable.
    private(set) var isOffline = false

    // MARK: Data

    /// Teams shown in the widget (capped at five rows).
    private(set) var teams: [AgentTeam] = []
    /// Total number of teams available; may exceed `teams.count`.
    private(set) var totalCount: Int = 0

    // MARK: Private

    /// Direct API client for fetching team data.
    private var client: APIClient?

    // MARK: Init

    init() {}

    // MARK: Configuration

    /// Bind this view model to a direct API client.
    /// - Parameter client: The ``APIClient`` for fetching teams.
    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: DashboardWidgetViewModel

    /// Fetches team data from the API.
    func loadContent() async {
        isLoading = true
        isOffline = false

        guard let client else {
            isLoading = false
            return
        }
        await fetchFromAPI(client: client)
    }

    // MARK: Private Helpers

    /// Fetch teams from the API and surface the first five.
    private func fetchFromAPI(client: APIClient) async {
        do {
            let response: APIResponse<[AgentTeam]> = try await client.get("/teams")
            let all = response.data ?? []
            totalCount = all.count
            // Sort teams with active members first, then by name
            teams = Array(
                all.sorted { lhs, rhs in
                    let lhsActive = lhs.members.filter { $0.status == .active }.count
                    let rhsActive = rhs.members.filter { $0.status == .active }.count
                    if lhsActive != rhsActive { return lhsActive > rhsActive }
                    return lhs.name < rhs.name
                }.prefix(5)
            )
            isOffline = false
        } catch {
            isOffline = true
            AppLogger.shared.error(
                "TeamActivityWidget fetch failed: \(error.localizedDescription)",
                category: "widget"
            )
        }
        isLoading = false
    }
}

// MARK: - TeamActivityWidget

/// Dashboard widget that shows agent teams with member activity indicators.
///
/// Displays up to five teams, each with a member count badge and active-member
/// status dots.  While data loads, skeleton rows shimmer as placeholders.
/// If no teams exist, an empty-state prompt encourages the user to create one.
///
/// ## Usage
/// ```swift
/// TeamActivityWidget(viewModel: vm) { team in
///     navigateTo(team)
/// }
/// ```
struct TeamActivityWidget: View {
    /// View model supplying team data and loading state.
    let viewModel: TeamActivityWidgetViewModel
    /// Called when the user taps a team row.
    var onTeamSelected: ((AgentTeam) -> Void)?

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .background(theme.bgTertiary)

            if viewModel.isLoading {
                skeletonContent
            } else if viewModel.isOffline {
                offlineState
            } else if viewModel.teams.isEmpty {
                emptyState
            } else {
                teamList
            }

            Spacer(minLength: 0)
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: DashboardWidgetType.teamActivity.icon)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)

            Text("Team Activity")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()

            if !viewModel.isLoading && viewModel.totalCount > 0 {
                countBadge
            }
        }
        .padding(.bottom, theme.spacingSM)
    }

    private var countBadge: some View {
        Text("\(viewModel.totalCount)")
            .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
            .foregroundStyle(theme.textOnAccent)
            .padding(.horizontal, theme.spacingXS + 2)
            .padding(.vertical, 2)
            .background(theme.accent)
            .clipShape(Capsule())
            .accessibilityLabel("\(viewModel.totalCount) \(viewModel.totalCount == 1 ? "team" : "teams")")
    }

    // MARK: - Team List

    private var teamList: some View {
        VStack(spacing: theme.spacingXS) {
            ForEach(viewModel.teams) { team in
                teamRow(team)
            }

            if viewModel.totalCount > 5 {
                Text("+\(viewModel.totalCount - 5) more")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, theme.spacingXS)
            }
        }
        .padding(.top, theme.spacingSM)
    }

    @ViewBuilder
    private func teamRow(_ team: AgentTeam) -> some View {
        Button {
            onTeamSelected?(team)
        } label: {
            HStack(spacing: theme.spacingSM) {
                // Member avatar cluster
                memberAvatars(team.members)

                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: theme.spacingXS) {
                        let activeCount = team.members.filter { $0.status == .active }.count
                        if activeCount > 0 {
                            Circle()
                                .fill(theme.success)
                                .frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                            Text("\(activeCount) active")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.success)
                        } else {
                            Text("\(team.members.count) \(team.members.count == 1 ? "member" : "members")")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption - 1, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgTertiary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(teamAccessibilityLabel(team))
        .accessibilityHint("Opens team details")
        .accessibilityAddTraits(.isButton)
    }

    /// Small overlapping avatar circles for team members (up to three).
    @ViewBuilder
    private func memberAvatars(_ members: [TeamMember]) -> some View {
        let visible = members.prefix(3)
        ZStack(alignment: .leading) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, member in
                Circle()
                    .fill(memberColor(member))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text(String(member.name.prefix(1)).uppercased())
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.textOnAccent)
                    )
                    .offset(x: CGFloat(index) * 14)
            }
        }
        .frame(width: CGFloat(min(members.count, 3)) * 14 + 6, height: 20)
        .accessibilityHidden(true)
    }

    /// Color for a member avatar based on their status.
    private func memberColor(_ member: TeamMember) -> Color {
        switch member.status {
        case .active:   return theme.success
        case .idle:     return theme.accent.opacity(0.7)
        case .shutdown: return theme.textTertiary
        case nil:       return theme.accent.opacity(0.5)
        }
    }

    /// Accessibility label for a team row.
    private func teamAccessibilityLabel(_ team: AgentTeam) -> String {
        let activeCount = team.members.filter { $0.status == .active }.count
        if activeCount > 0 {
            return "\(team.name), \(activeCount) active \(activeCount == 1 ? "member" : "members")"
        }
        return "\(team.name), \(team.members.count) \(team.members.count == 1 ? "member" : "members")"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "person.3")
                .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("No Teams")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, theme.spacingMD)
        .accessibilityLabel("No teams")
    }

    // MARK: - Offline State

    private var offlineState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "wifi.slash")
                .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("Offline")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, theme.spacingMD)
        .accessibilityLabel("Team activity unavailable — offline")
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(spacing: theme.spacingXS) {
            ForEach(0..<4, id: \.self) { _ in
                skeletonRow
            }
        }
        .padding(.top, theme.spacingSM)
    }

    private var skeletonRow: some View {
        HStack(spacing: theme.spacingSM) {
            // Avatar cluster placeholder
            HStack(spacing: -6) {
                ForEach(0..<2, id: \.self) { _ in
                    Circle()
                        .fill(theme.bgTertiary)
                        .frame(width: 20, height: 20)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.bgTertiary)
                    .frame(width: 110, height: 13)

                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.bgTertiary)
                    .frame(width: 60, height: 10)
            }

            Spacer()
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgTertiary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    TeamActivityWidget(viewModel: TeamActivityWidgetViewModel())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
        .frame(width: 320, height: 260)
        .glassCard()
        .padding()
}
