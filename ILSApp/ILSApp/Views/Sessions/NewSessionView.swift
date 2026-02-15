import SwiftUI
import ILSShared

struct NewSessionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: any AppTheme

    @StateObject private var projectsViewModel = ProjectsViewModel()
    @State private var sessionName = ""
    @State private var selectedProject: Project?
    @State private var selectedModel = "sonnet"
    @State private var permissionMode = "default"
    @State private var isCreating = false
    @State private var systemPrompt = ""
    @State private var maxBudget = ""
    @State private var maxTurns = ""
    @State private var showAdvanced = false

    let onCreated: (ChatSession) -> Void

    private let models = ["sonnet", "opus", "haiku"]
    private let permissionModes = [
        "default", "acceptEdits", "plan", "bypassPermissions", "delegate", "dontAsk"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    sessionDetailsSection
                    modelSection
                    permissionsSection
                    systemPromptSection
                    limitsSection
                    advancedSection
                    createButton
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
            }
            .background(theme.bgPrimary)
            .navigationTitle("New Session")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .task {
                projectsViewModel.configure(client: appState.apiClient)
                await projectsViewModel.loadProjects()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Session Details

    @ViewBuilder
    private var sessionDetailsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Session Details")

            TextField("Session Name (optional)", text: $sessionName)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .padding(theme.spacingSM)
                .background(theme.bgSecondary)
                .foregroundStyle(theme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .accessibilityIdentifier("session-name-field")

            Picker("Project", selection: $selectedProject) {
                Text("No Project").tag(nil as Project?)
                ForEach(projectsViewModel.projects) { project in
                    Text(project.name).tag(project as Project?)
                }
            }
            .tint(theme.accent)
            .padding(theme.spacingSM)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .accessibilityIdentifier("project-picker")
        }
    }

    // MARK: - Model Selection

    @ViewBuilder
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Model")

            HStack(spacing: 0) {
                ForEach(models, id: \.self) { model in
                    Button {
                        selectedModel = model
                    } label: {
                        Text(model.capitalized)
                            .font(.system(size: theme.fontCaption, weight: selectedModel == model ? .semibold : .regular, design: theme.fontDesign))
                            .foregroundStyle(selectedModel == model ? theme.textPrimary : theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacingSM)
                            .background(selectedModel == model ? theme.accent.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .accessibilityLabel("Claude model selection")
        }
    }

    // MARK: - Permissions

    @ViewBuilder
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Permissions")

            Picker("Permission Mode", selection: $permissionMode) {
                ForEach(permissionModes, id: \.self) { mode in
                    Text(formattedMode(mode)).tag(mode)
                }
            }
            .tint(theme.accent)
            .padding(theme.spacingSM)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            Text(permissionDescription)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - System Prompt

    @ViewBuilder
    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("System Prompt")

            ZStack(alignment: .topLeading) {
                TextEditor(text: $systemPrompt)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)

                if systemPrompt.isEmpty {
                    Text("Custom instructions for Claude (optional)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
            .padding(theme.spacingSM)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
    }

    // MARK: - Limits

    @ViewBuilder
    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Limits")

            HStack {
                Text("Max Budget (USD)")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                TextField("No limit", text: $maxBudget)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 100)
            }
            .padding(theme.spacingSM)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            HStack {
                Text("Max Turns")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                TextField("1", text: $maxTurns)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 100)
            }
            .padding(theme.spacingSM)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
    }

    // MARK: - Advanced

    @ViewBuilder
    private var advancedSection: some View {
        DisclosureGroup("Advanced Options", isExpanded: $showAdvanced) {
            VStack(spacing: theme.spacingSM) {
                Text("Advanced options available when connected")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .font(.system(size: theme.fontBody, design: theme.fontDesign))
        .foregroundStyle(theme.textSecondary)
        .tint(theme.textTertiary)
        .padding(theme.spacingSM)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    // MARK: - Create Button

    @ViewBuilder
    private var createButton: some View {
        Button {
            createSession()
        } label: {
            HStack(spacing: theme.spacingSM) {
                if isCreating {
                    ProgressView()
                        .tint(theme.textOnAccent)
                        .controlSize(.small)
                } else {
                    Image(systemName: "plus.circle.fill")
                }
                Text(isCreating ? "Creating..." : "Create Session")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
            }
            .foregroundStyle(theme.textOnAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
        .disabled(isCreating)
        .opacity(isCreating ? 0.7 : 1.0)
        .padding(.top, theme.spacingSM)
        .accessibilityIdentifier("create-session-button")
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
                .kerning(1)
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
                AppLogger.shared.error("Failed to create session: \(error)", category: "ui")
            }

            isCreating = false
        }
    }

    func buildChatOptions() -> ChatOptions {
        ChatOptions(
            model: selectedModel,
            permissionMode: PermissionMode(rawValue: permissionMode),
            maxTurns: Int(maxTurns),
            maxBudgetUSD: Double(maxBudget),
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
        )
    }

}

#Preview {
    NewSessionView { _ in }
        .environment(\.theme, ObsidianTheme())
}
