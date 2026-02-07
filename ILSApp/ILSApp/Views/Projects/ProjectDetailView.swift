import SwiftUI
import ILSShared

struct ProjectDetailView: View {
    let project: Project
    let viewModel: ProjectsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var defaultModel: String
    @State private var description: String
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showCopiedToast = false

    init(project: Project, viewModel: ProjectsViewModel) {
        self.project = project
        self.viewModel = viewModel
        _name = State(initialValue: project.name)
        _defaultModel = State(initialValue: project.defaultModel)
        _description = State(initialValue: project.description ?? "")
    }

    private let models = ["sonnet", "opus", "haiku"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Info") {
                    if isEditing {
                        TextField("Name", text: $name)
                    } else {
                        LabeledContent("Name", value: project.name)
                    }

                    LabeledContent("Path", value: project.path)

                    if isEditing {
                        Picker("Default Model", selection: $defaultModel) {
                            ForEach(models, id: \.self) { model in
                                Text(model.capitalized).tag(model)
                            }
                        }
                    } else {
                        LabeledContent("Default Model", value: project.defaultModel)
                    }

                    if isEditing {
                        TextField("Description", text: $description)
                    } else if let desc = project.description {
                        LabeledContent("Description", value: desc)
                    }
                }

                Section("Sessions") {
                    if let count = project.sessionCount {
                        NavigationLink {
                            ProjectSessionsListView(project: project)
                        } label: {
                            HStack {
                                Label("\(count) sessions", systemImage: "bubble.left.and.bubble.right")
                                Spacer()
                            }
                        }
                    } else {
                        Text("No sessions")
                            .foregroundColor(ILSTheme.tertiaryText)
                    }
                }

                Section("Details") {
                    LabeledContent("Created", value: formattedDate(project.createdAt))
                    LabeledContent("Last Accessed", value: formattedDate(project.lastAccessedAt))
                    if let encodedPath = project.encodedPath {
                        LabeledContent("Directory", value: encodedPath)
                    }
                }

                if !isEditing {
                    Section {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteProject(project)
                                dismiss()
                            }
                        } label: {
                            Label("Delete Project", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ILSTheme.background)
            .navigationTitle("Project Details")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                // Refresh project details from server
                await viewModel.loadProjects()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Done") {
                        if isEditing {
                            // Reset values
                            name = project.name
                            defaultModel = project.defaultModel
                            description = project.description ?? ""
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(isSaving)
                    } else {
                        Menu {
                            Button {
                                UIPasteboard.general.string = project.path
                                showCopiedToast = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCopiedToast = false
                                }
                            } label: {
                                Label("Copy Path", systemImage: "doc.on.doc")
                            }
                            Button {
                                UIPasteboard.general.string = project.name
                                showCopiedToast = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCopiedToast = false
                                }
                            } label: {
                                Label("Copy Name", systemImage: "doc.on.doc")
                            }
                            Divider()
                            Button("Edit") {
                                isEditing = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .toast(isPresented: $showCopiedToast, message: "Copied to clipboard")
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func saveChanges() {
        isSaving = true

        Task {
            _ = await viewModel.updateProject(
                project,
                name: name != project.name ? name : nil,
                defaultModel: defaultModel != project.defaultModel ? defaultModel : nil,
                description: description != (project.description ?? "") ? description : nil
            )

            isSaving = false
            isEditing = false
        }
    }
}

#Preview {
    let viewModel = ProjectsViewModel()
    return ProjectDetailView(
        project: Project(
            id: UUID(),
            name: "Test Project",
            path: "/Users/nick/projects/test",
            defaultModel: "sonnet",
            description: "A test project",
            createdAt: Date(),
            lastAccessedAt: Date(),
            sessionCount: 5,
            encodedPath: "-Users-nick-projects-test"
        ),
        viewModel: viewModel
    )
}
