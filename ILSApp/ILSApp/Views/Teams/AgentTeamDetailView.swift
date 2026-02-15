import SwiftUI
import ILSShared

struct AgentTeamDetailView: View {
    @Environment(\.theme) private var theme: any AppTheme
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: TeamsViewModel
    let teamName: String
    @State private var selectedTab = 0
    @State private var showSpawnSheet = false

    init(teamName: String, apiClient: APIClient) {
        self.teamName = teamName
        _viewModel = StateObject(wrappedValue: TeamsViewModel(apiClient: apiClient))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let team = viewModel.selectedTeam {
                headerSection(team)
            }

            HStack(spacing: 0) {
                ForEach(Array(["Members", "Tasks", "Messages"].enumerated()), id: \.offset) { index, label in
                    Button {
                        selectedTab = index
                    } label: {
                        Text(label)
                            .font(.system(size: theme.fontCaption, weight: selectedTab == index ? .semibold : .regular, design: theme.fontDesign))
                            .foregroundStyle(selectedTab == index ? theme.textPrimary : theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacingSM)
                            .background(selectedTab == index ? theme.accent.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .padding(theme.spacingMD)

            Group {
                switch selectedTab {
                case 0:
                    membersTab
                case 1:
                    TeamTaskListView(viewModel: viewModel, teamName: teamName)
                case 2:
                    TeamMessagesView(viewModel: viewModel, teamName: teamName)
                default:
                    EmptyView()
                }
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle(teamName)
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .sheet(isPresented: $showSpawnSheet) {
            SpawnTeammateView(viewModel: viewModel, teamName: teamName)
        }
        .task {
            await viewModel.loadTeamDetail(name: teamName)
            viewModel.startPolling(teamName: teamName)
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    private func headerSection(_ team: AgentTeam) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            if let description = team.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            HStack(spacing: theme.spacingMD) {
                Label("\(team.members.count) members", systemImage: "person.2")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .padding(.horizontal, theme.spacingMD)
        .padding(.top, theme.spacingSM)
    }

    private var membersTab: some View {
        ScrollView {
            VStack(spacing: theme.spacingSM) {
                if let team = viewModel.selectedTeam {
                    ForEach(team.members) { member in
                        memberCard(member)
                    }
                }

                Button {
                    showSpawnSheet = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Spawn Teammate")
                    }
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
                }
                .buttonStyle(.plain)
            }
            .padding(theme.spacingMD)
        }
    }

    private func memberCard(_ member: TeamMember) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                if let agentType = member.agentType {
                    Text(agentType)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Spacer()

            statusBadge(for: member.status)

            Button {
                Task {
                    await viewModel.shutdownTeammate(teamName: teamName, name: member.name)
                }
            } label: {
                Image(systemName: "power")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.error)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    private func statusBadge(for status: TeamMemberStatus?) -> some View {
        let (color, text) = statusInfo(for: status)

        return Text(text)
            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            .foregroundStyle(color)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(theme.cornerRadius)
    }

    private func statusInfo(for status: TeamMemberStatus?) -> (Color, String) {
        switch status {
        case .idle:
            return (theme.textTertiary, "Idle")
        case .active:
            return (theme.success, "Active")
        case .shutdown:
            return (theme.error, "Shutdown")
        case .none:
            return (theme.textTertiary, "Unknown")
        }
    }
}
