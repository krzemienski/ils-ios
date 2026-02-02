import SwiftUI
import ILSShared

struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var viewModel: ProjectsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var defaultModel: String
    @State private var description: String
    @State private var isEditing = false
    @State private var isSaving = false

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

                Section("Statistics") {
                    if let count = project.sessionCount {
                        LabeledContent("Sessions", value: "\(count)")
                    }
                    LabeledContent("Created", value: formattedDate(project.createdAt))
                    LabeledContent("Last Accessed", value: formattedDate(project.lastAccessedAt))
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
            .navigationTitle("Project Details")
            .navigationBarTitleDisplayMode(.inline)
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
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
    ProjectDetailView(
        project: Project(
            id: UUID(),
            name: "Test Project",
            path: "/Users/nick/projects/test",
            defaultModel: "sonnet",
            description: "A test project",
            createdAt: Date(),
            lastAccessedAt: Date(),
            sessionCount: 5
        ),
        viewModel: ProjectsViewModel()
    )
}
