import SwiftUI
import ILSShared

struct ProjectsListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProjectsViewModel()
    @State private var showingNewProject = false
    @State private var selectedProject: Project?

    var body: some View {
        List {
            if let error = viewModel.error {
                ErrorStateView(error: error) {
                    await viewModel.retryLoadProjects()
                }
            } else if viewModel.projects.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No Projects",
                    systemImage: "folder",
                    description: "Add a project to organize your sessions",
                    actionTitle: "Create Project"
                ) {
                    showingNewProject = true
                }
            } else {
                ForEach(viewModel.projects) { project in
                    ProjectRowView(project: project)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedProject = project
                        }
                }
                .onDelete(perform: deleteProject)
            }
        }
        .navigationTitle("Projects")
        .refreshable {
            await viewModel.loadProjects()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNewProject = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewProject) {
            NewProjectView { project in
                viewModel.projects.append(project)
            }
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailView(project: project, viewModel: viewModel)
        }
        .overlay {
            if viewModel.isLoading && viewModel.projects.isEmpty {
                ProgressView("Loading projects...")
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadProjects()
        }
    }

    private func deleteProject(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let project = viewModel.projects[index]
                await viewModel.deleteProject(project)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(project.name)
                    .font(ILSTheme.headlineFont)

                Spacer()

                Text(project.defaultModel)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(ILSTheme.tertiaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusS)
            }

            Text(project.path)
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.secondaryText)
                .lineLimit(1)

            if let description = project.description {
                Text(description)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
                    .lineLimit(2)
            }

            HStack {
                if let count = project.sessionCount {
                    Label("\(count) sessions", systemImage: "bubble.left.and.bubble.right")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                }

                Spacer()

                Text(formattedDate(project.lastAccessedAt))
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
            }
        }
        .padding(.vertical, 4)
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
