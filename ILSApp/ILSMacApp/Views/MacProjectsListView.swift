import SwiftUI
import ILSShared

// MARK: - Mac Projects List View

struct MacProjectsListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @StateObject private var viewModel = ProjectsViewModel()

    @State private var searchText: String = ""
    @State private var selectedProject: Project?
    @State private var showingCreateSheet: Bool = false
    @State private var projectToEdit: Project?
    @State private var showingDeleteConfirmation: Bool = false
    @State private var projectToDelete: Project?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("PROJECTS")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text("\(viewModel.projects.count)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.top, theme.spacingMD)
            .padding(.bottom, theme.spacingSM)

            // Search bar
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                TextField("Search projects...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS + 2)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingSM)

            // Project list
            List(selection: $selectedProject) {
                if viewModel.isLoading && viewModel.projects.isEmpty {
                    loadingView
                } else if filteredProjects.isEmpty {
                    emptyView
                } else {
                    ForEach(filteredProjects) { project in
                        Button {
                            selectedProject = project
                        } label: {
                            projectRow(project)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                projectToEdit = project
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                Task {
                                    _ = await viewModel.duplicateProject(project)
                                }
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            Divider()
                            Button(role: .destructive) {
                                projectToDelete = project
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .tag(project)
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .refreshable {
                await viewModel.loadProjects(refresh: true)
            }

            Divider()

            // New Project button
            Button {
                showingCreateSheet = true
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Project")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM + 2)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingMD)
            .keyboardShortcut("n", modifiers: .command)
            .help("Create new project (⌘N)")
        }
        .background(theme.bgPrimary)
        .navigationTitle("Projects")
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadProjects(refresh: true)
        }
        .sheet(isPresented: $showingCreateSheet) {
            createProjectSheet
        }
        .sheet(item: $projectToEdit) { project in
            editProjectSheet(project)
        }
        .alert("Delete Project", isPresented: $showingDeleteConfirmation, presenting: projectToDelete) { project in
            Button("Cancel", role: .cancel) { projectToDelete = nil }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteProject(project)
                    projectToDelete = nil
                }
            }
        } message: { project in
            Text("Are you sure you want to delete '\(project.name)'? This action cannot be undone.")
        }
    }

    // MARK: - Project Row

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: theme.spacingSM) {
            Circle()
                .fill(theme.entityProject)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let description = project.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                } else {
                    Text(project.path)
                        .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(project.defaultModel.components(separatedBy: "-").first?.capitalized ?? "")
                .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, theme.spacingXS)
        .accessibilityLabel("\(project.name), \(project.description ?? project.path)")
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: theme.spacingSM) {
            ProgressView()
                .tint(theme.accent)
            Text("Loading projects...")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingLG)
    }

    private var emptyView: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "folder")
                .font(.system(size: 24, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text(searchText.isEmpty ? "No projects yet" : "No matching projects")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingLG)
    }

    // MARK: - Create Project Sheet

    @ViewBuilder
    private var createProjectSheet: some View {
        ProjectFormSheet(
            title: "New Project",
            onSave: { name, path, model, description in
                Task {
                    _ = await viewModel.createProject(
                        name: name,
                        path: path,
                        defaultModel: model,
                        description: description
                    )
                    showingCreateSheet = false
                }
            },
            onCancel: {
                showingCreateSheet = false
            }
        )
        .frame(width: 480, height: 400)
    }

    // MARK: - Edit Project Sheet

    @ViewBuilder
    private func editProjectSheet(_ project: Project) -> some View {
        ProjectFormSheet(
            title: "Edit Project",
            initialName: project.name,
            initialPath: project.path,
            initialModel: project.defaultModel,
            initialDescription: project.description,
            onSave: { name, path, model, description in
                Task {
                    _ = await viewModel.updateProject(
                        project,
                        name: name,
                        defaultModel: model,
                        description: description
                    )
                    projectToEdit = nil
                }
            },
            onCancel: {
                projectToEdit = nil
            }
        )
        .frame(width: 480, height: 400)
    }

    // MARK: - Helpers

    private var filteredProjects: [Project] {
        guard !searchText.isEmpty else { return viewModel.projects }
        let query = searchText.lowercased()
        return viewModel.projects.filter { project in
            project.name.lowercased().contains(query) ||
            (project.description?.lowercased().contains(query) ?? false) ||
            project.path.lowercased().contains(query)
        }
    }
}

// MARK: - Project Form Sheet

struct ProjectFormSheet: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let title: String
    var initialName: String = ""
    var initialPath: String = ""
    var initialModel: String = "claude-sonnet-4-20250514"
    var initialDescription: String?
    let onSave: (String, String, String, String?) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var path: String
    @State private var model: String
    @State private var description: String

    let availableModels = [
        "claude-sonnet-4-20250514",
        "claude-opus-4-20250514",
        "claude-haiku-3-5-20241022"
    ]

    init(
        title: String,
        initialName: String = "",
        initialPath: String = "",
        initialModel: String = "claude-sonnet-4-20250514",
        initialDescription: String? = nil,
        onSave: @escaping (String, String, String, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.initialName = initialName
        self.initialPath = initialPath
        self.initialModel = initialModel
        self.initialDescription = initialDescription
        self.onSave = onSave
        self.onCancel = onCancel

        _name = State(initialValue: initialName)
        _path = State(initialValue: initialPath)
        _model = State(initialValue: initialModel)
        _description = State(initialValue: initialDescription ?? "")
    }

    var body: some View {
        VStack(spacing: theme.spacingMD) {
            Text(title)
                .font(.system(size: theme.fontTitle2, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Form {
                TextField("Project Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Project Path", text: $path)
                    .textFieldStyle(.roundedBorder)

                Picker("Default Model", selection: $model) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(formatModelName(model))
                            .tag(model)
                    }
                }

                TextField("Description (optional)", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            .formStyle(.grouped)

            HStack(spacing: theme.spacingSM) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    onSave(name, path, model, description.isEmpty ? nil : description)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || path.isEmpty)
            }
        }
        .padding(theme.spacingLG)
        .background(theme.bgPrimary)
    }

    private func formatModelName(_ model: String) -> String {
        if model.contains("sonnet") { return "Claude Sonnet" }
        if model.contains("opus") { return "Claude Opus" }
        if model.contains("haiku") { return "Claude Haiku" }
        return model
    }
}

#Preview {
    MacProjectsListView()
        .environmentObject(AppState())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
