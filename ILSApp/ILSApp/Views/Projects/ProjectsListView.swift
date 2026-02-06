import SwiftUI
import ILSShared

struct ProjectsListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProjectsViewModel()
    @State private var showingNewProject = false
    @State private var selectedProject: Project?
    @State private var projectToDelete: Project?

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
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                projectToDelete = project
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                Task { await viewModel.duplicateProject(project) }
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc.fill")
                            }
                            Button {
                                UIPasteboard.general.string = project.path
                            } label: {
                                Label("Copy Path", systemImage: "doc.on.doc")
                            }
                            Divider()
                            Button(role: .destructive) {
                                projectToDelete = project
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .darkListStyle()
        .navigationTitle("Projects")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .refreshable {
            await viewModel.loadProjects(refresh: true)
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
            .presentationBackground(Color.black)
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailView(project: project, viewModel: viewModel)
                .presentationBackground(Color.black)
        }
        .alert("Delete Project?", isPresented: Binding(
            get: { projectToDelete != nil },
            set: { if !$0 { projectToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    Task { await viewModel.deleteProject(project) }
                    projectToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { projectToDelete = nil }
        } message: {
            Text("This will permanently delete \"\(projectToDelete?.name ?? "this project")\" and all associated data.")
        }
        .overlay {
            if viewModel.isLoading && viewModel.projects.isEmpty {
                List {
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Project Name")
                                    .font(ILSTheme.headlineFont)
                                Spacer()
                                Text("sonnet")
                                    .font(ILSTheme.captionFont)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(ILSTheme.tertiaryBackground)
                                    .cornerRadius(ILSTheme.cornerRadiusXS)
                            }
                            Text("/path/to/project")
                                .font(Font.system(.caption, design: .monospaced))
                            HStack {
                                Label("5 sessions", systemImage: "bubble.left.and.bubble.right")
                                    .font(ILSTheme.captionFont)
                                Spacer()
                                Text("1 hr ago")
                                    .font(ILSTheme.captionFont)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .darkListStyle()
                .redacted(reason: .placeholder)
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
                    .cornerRadius(ILSTheme.cornerRadiusXS)
            }

            Text(project.path)
                .font(Font.system(.caption, design: .monospaced))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.name), \(project.defaultModel)")
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
