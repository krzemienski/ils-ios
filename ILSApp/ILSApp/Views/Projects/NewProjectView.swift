import SwiftUI
import ILSShared

struct NewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var path = ""
    @State private var defaultModel = "sonnet"
    @State private var description = ""
    @State private var isCreating = false

    let onCreated: (Project) -> Void

    private let models = ["sonnet", "opus", "haiku"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $name)
                    TextField("Directory Path", text: $path)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    TextField("Description (optional)", text: $description)
                }

                Section("Default Model") {
                    Picker("Model", selection: $defaultModel) {
                        ForEach(models, id: \.self) { model in
                            Text(model.capitalized).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text("The directory path should point to your project folder on the host machine where Claude Code is installed.")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ILSTheme.background)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(name.isEmpty || path.isEmpty || isCreating)
                }
            }
        }
    }

    private func createProject() {
        isCreating = true

        Task {
            let client = APIClient()
            let request = CreateProjectRequest(
                name: name,
                path: path,
                defaultModel: defaultModel,
                description: description.isEmpty ? nil : description
            )

            do {
                let response: APIResponse<Project> = try await client.post("/projects", body: request)
                if let project = response.data {
                    await MainActor.run {
                        onCreated(project)
                        dismiss()
                    }
                }
            } catch {
                print("Failed to create project: \(error)")
            }

            isCreating = false
        }
    }
}

#Preview {
    NewProjectView { _ in }
}
