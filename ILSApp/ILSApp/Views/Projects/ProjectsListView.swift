import SwiftUI
import ILSShared

struct ProjectsListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProjectsViewModel()
    @State private var searchText = ""

    private var filteredProjects: [Project] {
        guard !searchText.isEmpty else { return viewModel.projects }
        return viewModel.projects.filter { project in
            project.name.localizedCaseInsensitiveContains(searchText)
                || project.path.localizedCaseInsensitiveContains(searchText)
                || (project.description?.localizedCaseInsensitiveContains(searchText) ?? false)
                || project.defaultModel.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if let error = viewModel.error {
                ErrorStateView(error: error) {
                    await viewModel.retryLoadProjects()
                }
            } else if viewModel.projects.isEmpty && !viewModel.isLoading {
                EmptyEntityState(
                    entityType: .projects,
                    title: "No Projects",
                    description: "Connect to a backend with projects"
                )
            } else if !searchText.isEmpty && filteredProjects.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(filteredProjects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project, viewModel: viewModel)) {
                        ProjectRowView(project: project)
                    }
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = project.path
                        } label: {
                            Label("Copy Path", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
        }
        .darkListStyle()
        .navigationTitle("Projects")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search projects...")
        .refreshable {
            await viewModel.loadProjects(refresh: true)
        }
        .overlay {
            if viewModel.isLoading && viewModel.projects.isEmpty {
                List {
                    SkeletonListView()
                }
                .darkListStyle()
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadProjects()
        }
        .onChange(of: appState.isConnected) { _, isConnected in
            if isConnected && viewModel.error != nil {
                Task { await viewModel.retryLoadProjects() }
            }
        }
    }
}

struct ProjectRowView: View {
    let project: Project

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        HStack(spacing: ILSTheme.spaceM) {
            // Green folder icon accent
            Image(systemName: EntityType.projects.icon)
                .font(.title3)
                .foregroundColor(EntityType.projects.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(project.name)
                        .font(ILSTheme.headlineFont)
                        .foregroundColor(ILSTheme.textPrimary)

                    Spacer()

                    Text(project.defaultModel)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(ILSTheme.bg3)
                        .cornerRadius(ILSTheme.cornerRadiusXS)
                }

                Text(project.path)
                    .font(Font.system(.caption, design: .monospaced))
                    .foregroundColor(ILSTheme.textSecondary)
                    .lineLimit(1)

                if let description = project.description {
                    Text(description)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.textTertiary)
                        .lineLimit(2)
                }

                HStack {
                    if let count = project.sessionCount {
                        Label("\(count) sessions", systemImage: "bubble.left.and.bubble.right")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.textTertiary)
                    }

                    Spacer()

                    Text(formattedDate(project.lastAccessedAt))
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.name), \(project.defaultModel), \(project.sessionCount.map { "\($0) sessions" } ?? "no sessions")")
        .accessibilityHint("Double tap to view project details")
    }

    private func formattedDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        ProjectsListView()
    }
}
