import SwiftUI
import ILSShared

struct ProjectsListView: View {
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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No projects, Add a project to organize your sessions")
                .accessibilityIdentifier("empty-projects-state")
            } else {
                ForEach(viewModel.projects) { project in
                    ProjectRowView(project: project)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedProject = project
                        }
                        .accessibilityIdentifier("project-\(project.id)")
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
                .accessibilityLabel("New project")
                .accessibilityHint("Creates a new project")
                .accessibilityIdentifier("add-project-button")
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
                    .accessibilityLabel("Loading projects")
                    .accessibilityIdentifier("loading-projects-indicator")
            }
        }
        .task {
            await viewModel.loadProjects()
        }
        .accessibilityIdentifier("projects-list")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var accessibilityText: String {
        let name = project.name
        let model = "\(project.defaultModel) model"
        let path = "Project path: \(project.path)"
        let lastAccessed = "Last accessed \(formattedDate(project.lastAccessedAt))"

        var components = [name, model]

        // Add session count if exists
        if let count = project.sessionCount {
            components.append("\(count) sessions")
        }

        // Add description if exists
        if let description = project.description {
            components.append(description)
        }

        // Add path and last accessed
        components.append(path)
        components.append(lastAccessed)

        return components.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        ProjectsListView()
    }
}
