import SwiftUI
import ILSShared

struct NewSessionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var projectsViewModel = ProjectsViewModel()
    @State private var sessionName = ""
    @State private var selectedProject: Project?
    @State private var selectedModel = "sonnet"
    @State private var permissionMode = "default"
    @State private var isCreating = false

    // New config fields for CLI parity
    @State private var systemPrompt = ""
    @State private var maxBudget = ""
    @State private var maxTurns = ""
    @State private var showAdvanced = false
    @State private var fallbackModel = ""
    @State private var includePartialMessages = false
    @State private var continueConversation = false
    @State private var showTemplates = false

    let onCreated: (ChatSession) -> Void

    private let models = ["sonnet", "opus", "haiku"]
    private let permissionModes = [
        "default", "acceptEdits", "plan", "bypassPermissions", "delegate", "dontAsk"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showTemplates = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(ILSTheme.accent)
                            Text("Start from Template")
                                .foregroundColor(ILSTheme.primaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(ILSTheme.tertiaryText)
                        }
                    }
                }

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

                    Text(permissionDescription)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }

                Section("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .font(ILSTheme.codeFont)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if systemPrompt.isEmpty {
                                Text("Custom instructions for Claude (optional)")
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Limits") {
                    HStack {
                        Text("Max Budget (USD)")
                        Spacer()
                        TextField("No limit", text: $maxBudget)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Max Turns")
                        Spacer()
                        TextField("1", text: $maxTurns)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                Section {
                    DisclosureGroup("Advanced Options", isExpanded: $showAdvanced) {
                        TextField("Fallback Model", text: $fallbackModel)

                        Toggle("Include Partial Messages", isOn: $includePartialMessages)

                        Toggle("Continue Previous Session", isOn: $continueConversation)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ILSTheme.background)
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel-new-session-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Create") {
                            createSession()
                        }
                        .accessibilityIdentifier("create-session-button")
                    }
                }
            }
            .task {
                projectsViewModel.configure(client: appState.apiClient)
                await projectsViewModel.loadProjects()
            }
            .sheet(isPresented: $showTemplates) {
                SessionTemplatesView { template in
                    applyTemplate(template)
                }
                .presentationBackground(Color.black)
            }
        }
    }

    private func formattedMode(_ mode: String) -> String {
        switch mode {
        case "default": return "Default"
        case "acceptEdits": return "Accept Edits"
        case "plan": return "Plan Mode"
        case "bypassPermissions": return "Bypass All"
        case "delegate": return "Delegate"
        case "dontAsk": return "Don't Ask"
        default: return mode
        }
    }

    private var permissionDescription: String {
        switch permissionMode {
        case "default":
            return "Standard permission behavior — Claude will ask before executing tools."
        case "acceptEdits":
            return "Automatically approve file edits without prompting."
        case "plan":
            return "Planning mode — Claude will plan but not execute changes."
        case "bypassPermissions":
            return "Skip all permission checks. Use with caution."
        case "delegate":
            return "Delegate permission decisions to the calling process."
        case "dontAsk":
            return "Never prompt — deny any action that requires permission."
        default:
            return ""
        }
    }

    private func createSession() {
        isCreating = true

        Task {
            let request = CreateSessionRequest(
                projectId: selectedProject?.id,
                name: sessionName.isEmpty ? nil : sessionName,
                model: selectedModel,
                permissionMode: PermissionMode(rawValue: permissionMode),
                systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
                maxBudgetUSD: Double(maxBudget),
                maxTurns: Int(maxTurns)
            )

            do {
                let response: APIResponse<ChatSession> = try await appState.apiClient.post("/sessions", body: request)
                if let session = response.data {
                    await MainActor.run {
                        HapticManager.notification(.success)
                        onCreated(session)
                        dismiss()
                    }
                }
            } catch {
                HapticManager.notification(.error)
                print("Failed to create session: \(error)")
            }

            isCreating = false
        }
    }

    /// Build ChatOptions from the form state for use when sending the first message
    func buildChatOptions() -> ChatOptions {
        ChatOptions(
            model: selectedModel,
            permissionMode: PermissionMode(rawValue: permissionMode),
            maxTurns: Int(maxTurns),
            maxBudgetUSD: Double(maxBudget),
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
            continueConversation: continueConversation ? true : nil,
            includePartialMessages: includePartialMessages ? true : nil,
            fallbackModel: fallbackModel.isEmpty ? nil : fallbackModel
        )
    }

    private func applyTemplate(_ template: SessionTemplate) {
        sessionName = ""
        selectedModel = template.model
        permissionMode = template.permissionMode
        systemPrompt = template.systemPrompt
        maxBudget = template.maxBudget
        maxTurns = template.maxTurns
    }
}

#Preview {
    NewSessionView { _ in }
}
