import SwiftUI
import ILSShared

struct NewSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var projectsViewModel = ProjectsViewModel()
    @State private var sessionName = ""
    @State private var selectedProject: Project?
    @State private var selectedModel = "sonnet"
    @State private var permissionMode = "default"
    @State private var isCreating = false
    @State private var error: Error?
    @State private var showErrorAlert = false

    let onCreated: (ChatSession) -> Void

    private let models = ["sonnet", "opus", "haiku"]
    private let permissionModes = ["default", "acceptEdits", "plan", "bypassPermissions"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Details") {
                    TextField("Session Name (optional)", text: $sessionName)
                        .accessibilityIdentifier("session-name-field")

                    Picker("Project", selection: $selectedProject) {
                        Text("No Project").tag(nil as Project?)
                        ForEach(projectsViewModel.projects) { project in
                            Text(project.name).tag(project as Project?)
                        }
                    }
                    .accessibilityIdentifier("project-picker")
                }

                Section("Model") {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(models, id: \.self) { model in
                            Text(model.capitalized).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Permissions") {
                    Picker("Permission Mode", selection: $permissionMode) {
                        ForEach(permissionModes, id: \.self) { mode in
                            Text(formattedMode(mode)).tag(mode)
                        }
                    }
                }

                Section {
                    Text(permissionDescription)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel-new-session-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSession()
                    }
                    .disabled(isCreating)
                    .accessibilityIdentifier("create-session-button")
                }
            }
            .task {
                await projectsViewModel.loadProjects()
            }
            .alert("Error Creating Session", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
                Button("Retry") {
                    retryCreateSession()
                }
            } message: {
                Text(error?.localizedDescription ?? "An error occurred while creating the session.")
            }
        }
    }

    private func formattedMode(_ mode: String) -> String {
        switch mode {
        case "default": return "Default"
        case "acceptEdits": return "Accept Edits"
        case "plan": return "Plan Mode"
        case "bypassPermissions": return "Bypass All"
        default: return mode
        }
    }

    private var permissionDescription: String {
        switch permissionMode {
        case "default":
            return "Standard permission behavior - Claude will ask before executing tools."
        case "acceptEdits":
            return "Automatically approve file edits without prompting."
        case "plan":
            return "Planning mode - Claude will plan but not execute changes."
        case "bypassPermissions":
            return "Skip all permission checks. Use with caution."
        default:
            return ""
        }
    }

    private func createSession() {
        isCreating = true

        Task {
            let client = APIClient()
            let request = CreateSessionRequest(
                projectId: selectedProject?.id,
                name: sessionName.isEmpty ? nil : sessionName,
                model: selectedModel
            )

            do {
                let response: APIResponse<ChatSession> = try await client.post("/sessions", body: request)
                if let session = response.data {
                    await MainActor.run {
                        onCreated(session)
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.showErrorAlert = true
                    self.isCreating = false
                }
                return
            }

            await MainActor.run {
                isCreating = false
            }
        }
    }

    private func retryCreateSession() {
        createSession()
    }
}

#Preview {
    NewSessionView { _ in }
}
