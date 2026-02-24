import SwiftUI
import ILSShared

/// List view displaying all agent teams with navigation to team details.
///
/// Shows team cards in a scrollable list when teams exist, or an empty-state prompt
/// when none have been created. A toolbar button opens the ``CreateTeamView`` sheet.
/// Coordinates with ``TeamsViewModel`` to fetch and manage team data on appear.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - View model managing team data and API interactions
/// - ``showCreateSheet`` - Controls presentation of the create-team sheet
///
/// ### View Components
/// - ``emptyState`` - Placeholder shown when no teams exist
/// - ``teamCard(_:)`` - Card row for an individual team with member count
struct AgentTeamsListView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState
    /// View model managing team list loading and mutations.
    @State private var viewModel: TeamsViewModel
    /// Whether the create-team sheet is currently presented.
    @State private var showCreateSheet = false

    init(apiClient: APIClient) {
        _viewModel = State(wrappedValue: TeamsViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                if viewModel.teams.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.teams) { team in
                        teamCard(team)
                    }
                }
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Agent Teams")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateTeamView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadTeams()
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "person.3")
                .font(.system(size: 64, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("No Agent Teams")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("Create a team to coordinate multiple AI agents working together")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private func teamCard(_ team: AgentTeam) -> some View {
        NavigationLink(destination: AgentTeamDetailView(teamName: team.name, apiClient: appState.apiClient)) {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Text(team.name)
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                if let description = team.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: theme.spacingMD) {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "person.2")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        Text("\(team.members.count)")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
    }
}
