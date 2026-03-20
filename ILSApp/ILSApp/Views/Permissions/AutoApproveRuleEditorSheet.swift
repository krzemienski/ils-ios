import SwiftUI
import ILSShared

/// Modal form sheet for creating or editing an auto-approve rule.
///
/// Shows an action picker (allow/deny), a tool picker, optional path glob, optional command
/// prefix, an optional MCP server filter, a priority stepper, and a note field. If the rule
/// targets a known destructive operation pattern (e.g. `rm -rf`, `git push --force`) or is
/// a deny rule, an explicit confirmation alert is shown before the rule is persisted.
struct AutoApproveRuleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Non-nil when editing an existing rule. Nil when creating a new one.
    let existingRule: AutoApproveRule?

    /// Called when the user confirms the save.
    /// - Parameters:
    ///   - rule: The rule to persist.
    ///   - allowDestructive: `true` when the user explicitly confirmed a destructive rule.
    /// - Returns: A non-nil error message string if the operation failed, otherwise nil.
    let onSave: (AutoApproveRule, Bool) async -> String?

    // MARK: - Form State

    @State private var selectedAction: PermissionPolicyAction = .allow
    @State private var selectedTool: String = ""  // empty = "Any Tool"
    @State private var pathGlob: String = ""
    @State private var commandPrefix: String = ""
    @State private var mcpServer: String = ""
    @State private var priority: Int = 100
    @State private var note: String = ""
    @State private var isEnabled: Bool = true

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showDestructiveConfirm = false
    @State private var pendingRule: AutoApproveRule?

    var isEditing: Bool { existingRule != nil }

    // MARK: - Known Tools

    static let knownTools: [String] = [
        "Bash", "Read", "Write", "Edit", "MultiEdit",
        "Glob", "Grep", "WebFetch", "WebSearch", "NotebookEdit", "TodoWrite",
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                actionSection
                toolSection
                conditionsSection
                prioritySection
                optionsSection

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(theme.error)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Rule" : "New Rule")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await attemptSave() }
                    }
                    .disabled(!isValid || isSaving)
                    .bold()
                }
            }
            .onAppear { populateFromExisting() }
        }
        .alert("Confirm Rule", isPresented: $showDestructiveConfirm) {
            Button("Save Anyway", role: .destructive) {
                Task {
                    if let rule = pendingRule {
                        await performSave(rule, allowDestructive: true)
                    }
                    pendingRule = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingRule = nil
            }
        } message: {
            Text(destructiveAlertMessage)
        }
    }

    // MARK: - Sections

    private var actionSection: some View {
        Section {
            Picker("Action", selection: $selectedAction) {
                Label {
                    Text("Allow")
                        .foregroundStyle(.green)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .tag(PermissionPolicyAction.allow)

                Label {
                    Text("Deny")
                        .foregroundStyle(.red)
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .tag(PermissionPolicyAction.deny)
            }
            .pickerStyle(.segmented)

            actionDescriptionText
        } header: {
            Text("Action")
        }
    }

    @ViewBuilder
    private var actionDescriptionText: some View {
        switch selectedAction {
        case .allow:
            Text("Matching requests will be automatically approved without prompting.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        case .deny:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: theme.fontCaption))
                Text("Matching requests will be silently blocked. Use with caution.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var toolSection: some View {
        Section {
            Picker("Tool", selection: $selectedTool) {
                Text("Any Tool").tag("")
                ForEach(Self.knownTools, id: \.self) { tool in
                    Text(tool).tag(tool)
                }
            }

            if selectedTool.isEmpty {
                Text("Matches permission requests from any tool.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            } else {
                Text("Only matches \(selectedTool) permission requests.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        } header: {
            Text("Tool")
        }
    }

    private var conditionsSection: some View {
        Section {
            TextField("Path glob (e.g. /src/**)", text: $pathGlob)
                .font(.system(size: theme.fontBody, design: .monospaced))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            TextField("Command prefix (e.g. git status)", text: $commandPrefix)
                .font(.system(size: theme.fontBody, design: .monospaced))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            TextField("MCP server (optional)", text: $mcpServer)
                .font(.system(size: theme.fontBody, design: .monospaced))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
        } header: {
            Text("Conditions")
        } footer: {
            Text("Leave fields empty to match all requests for the selected tool. At least a specific tool, path glob, or command prefix is required. MCP server restricts matching to requests from a specific MCP server.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
        }
    }

    private var prioritySection: some View {
        Section {
            Stepper(value: $priority, in: 1...999, step: 10) {
                HStack {
                    Text("Priority")
                    Spacer()
                    Text("\(priority)")
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                }
            }
        } header: {
            Text("Priority")
        } footer: {
            Text("Lower numbers are evaluated first (1 = highest priority, 999 = lowest). Default is 100.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
        }
    }

    private var optionsSection: some View {
        Section {
            TextField("Note (optional)", text: $note)
                .autocorrectionDisabled()

            Toggle("Enabled", isOn: $isEnabled)
        } header: {
            Text("Options")
        }
    }

    // MARK: - Validation

    /// At least one of: a specific tool, a path glob, or a command prefix must be set.
    private var isValid: Bool {
        !selectedTool.trimmingCharacters(in: .whitespaces).isEmpty ||
        !pathGlob.trimmingCharacters(in: .whitespaces).isEmpty ||
        !commandPrefix.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Destructive Alert

    private var destructiveAlertMessage: String {
        if selectedAction == PermissionPolicyAction.deny {
            return "This is a deny rule — it will silently block matching tool requests without prompting the user. Are you sure you want to create this rule?"
        }
        return "This rule would auto-approve a potentially destructive operation " +
               "(e.g. rm -rf, git push --force). Are you sure you want to allow this " +
               "without manual confirmation?"
    }

    // MARK: - Populate from Existing

    private func populateFromExisting() {
        guard let existing = existingRule else { return }
        selectedAction = existing.action
        selectedTool = existing.toolName ?? ""
        pathGlob = existing.pathGlob ?? ""
        commandPrefix = existing.commandPrefix ?? ""
        mcpServer = existing.mcpServer ?? ""
        priority = existing.priority
        note = existing.note ?? ""
        isEnabled = existing.isEnabled
    }

    // MARK: - Save Logic

    /// Builds the candidate rule and routes through the destructive safety guard if needed.
    private func attemptSave() async {
        errorMessage = nil
        let rule = buildRule()

        if rule.isDestructive {
            // Surface the explicit confirmation alert before persisting
            pendingRule = rule
            showDestructiveConfirm = true
        } else {
            await performSave(rule, allowDestructive: false)
        }
    }

    /// Calls the parent `onSave` callback and either dismisses or surfaces the error.
    private func performSave(_ rule: AutoApproveRule, allowDestructive: Bool) async {
        isSaving = true
        defer { isSaving = false }

        if let error = await onSave(rule, allowDestructive) {
            errorMessage = error
        } else {
            dismiss()
        }
    }

    /// Constructs an `AutoApproveRule` from the current form state.
    private func buildRule() -> AutoApproveRule {
        let toolNameValue = selectedTool.trimmingCharacters(in: .whitespaces)
        let pathGlobValue = pathGlob.trimmingCharacters(in: .whitespaces)
        let commandPrefixValue = commandPrefix.trimmingCharacters(in: .whitespaces)
        let mcpServerValue = mcpServer.trimmingCharacters(in: .whitespaces)
        let noteValue = note.trimmingCharacters(in: .whitespaces)

        return AutoApproveRule(
            id: existingRule?.id ?? UUID(),
            toolName: toolNameValue.isEmpty ? nil : toolNameValue,
            pathGlob: pathGlobValue.isEmpty ? nil : pathGlobValue,
            commandPrefix: commandPrefixValue.isEmpty ? nil : commandPrefixValue,
            mcpServer: mcpServerValue.isEmpty ? nil : mcpServerValue,
            action: selectedAction,
            isEnabled: isEnabled,
            projectId: existingRule?.projectId,
            note: noteValue.isEmpty ? nil : noteValue,
            priority: priority,
            createdAt: existingRule?.createdAt ?? Date()
        )
    }
}

#Preview {
    AutoApproveRuleEditorSheet(
        existingRule: nil,
        onSave: { _, _ in nil }
    )
}
