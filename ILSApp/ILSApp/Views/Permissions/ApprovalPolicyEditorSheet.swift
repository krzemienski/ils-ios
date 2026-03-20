import SwiftUI
import ILSShared

/// Modal form sheet for creating or editing an approval policy.
///
/// Presents a comprehensive form with fields for name, description, default action,
/// tool-specific rules (multi-select), path glob patterns (list editor), risk level
/// filters, scope/project picker, priority, and enabled toggle. Follows the
/// ``AutoApproveRuleEditorSheet`` pattern with NavigationStack, Cancel/Save toolbar items.
struct ApprovalPolicyEditorSheet: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    /// Non-nil when editing an existing policy. Nil when creating a new one.
    let existingPolicy: ApprovalPolicy?

    /// Called when the user confirms the save.
    /// Returns a non-nil error message string if the operation failed, otherwise nil.
    let onSave: (CreateApprovalPolicyRequest) async -> String?

    // MARK: - Form State

    @State private var name: String = ""
    @State private var descriptionText: String = ""
    @State private var defaultAction: PolicyAction = .alwaysAsk
    @State private var selectedTools: Set<String> = []
    @State private var pathPatterns: [String] = []
    @State private var newPathPattern: String = ""
    @State private var selectedRiskLevels: Set<PermissionRiskLevel> = []
    @State private var scope: PolicyScope = .global
    @State private var projectName: String = ""
    @State private var priority: Int = 100
    @State private var isEnabled: Bool = true

    @State private var isSaving = false
    @State private var saveError: String?

    var isEditing: Bool { existingPolicy != nil }

    // MARK: - Known Tools

    static let knownTools: [String] = [
        "Bash", "Read", "Write", "Edit", "MultiEdit",
        "Glob", "Grep", "WebFetch", "WebSearch", "NotebookEdit", "TodoWrite",
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                actionSection
                toolsSection
                pathPatternsSection
                riskLevelSection
                scopeSection
                prioritySection
                optionsSection

                if let saveError {
                    Section {
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(theme.error)
                                .accessibilityHidden(true)
                            Text(saveError)
                                .foregroundStyle(theme.error)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Policy" : "New Policy")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                    .bold()
                }
            }
            .onAppear { populateFromExisting() }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            TextField("Policy name", text: $name)
                .autocorrectionDisabled()

            TextField("Description (optional)", text: $descriptionText)
                .autocorrectionDisabled()
        } header: {
            Text("Name")
        } footer: {
            Text("Give the policy a descriptive name so it's easy to identify.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
        }
    }

    private var actionSection: some View {
        Section {
            Picker("Default Action", selection: $defaultAction) {
                ForEach(PolicyAction.allCases, id: \.self) { action in
                    Text(actionLabel(for: action)).tag(action)
                }
            }

            Text(actionHelpText(for: defaultAction))
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        } header: {
            Text("Default Action")
        } footer: {
            Text("Applied to tools not covered by specific tool rules below.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
        }
    }

    private var toolsSection: some View {
        Section {
            ForEach(Self.knownTools, id: \.self) { tool in
                Button {
                    toggleTool(tool)
                } label: {
                    HStack {
                        Text(tool)
                            .font(.system(size: theme.fontBody, design: .monospaced))
                            .foregroundStyle(theme.textPrimary)

                        Spacer()

                        if selectedTools.contains(tool) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.accent)
                                .font(.system(size: theme.fontBody, weight: .semibold))
                        }
                    }
                }
                .accessibilityLabel("\(tool)\(selectedTools.contains(tool) ? ", selected" : "")")
            }
        } header: {
            Text("Tool Rules")
        } footer: {
            if selectedTools.isEmpty {
                Text("No tool-specific rules. The default action applies to all tools.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            } else {
                Text("\(selectedTools.count) tool\(selectedTools.count == 1 ? "" : "s") selected — each will inherit the default action as an override rule.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            }
        }
    }

    private var pathPatternsSection: some View {
        Section {
            ForEach(Array(pathPatterns.enumerated()), id: \.offset) { index, pattern in
                HStack {
                    Text(pattern)
                        .font(.system(size: theme.fontBody, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    Button(role: .destructive) {
                        pathPatterns.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(theme.error)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(pattern)")
                }
            }

            HStack {
                TextField("e.g. src/**/*.swift", text: $newPathPattern)
                    .font(.system(size: theme.fontBody, design: .monospaced))
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif

                Button {
                    addPathPattern()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(newPathPattern.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Add path pattern")
            }
        } header: {
            Text("Path Patterns")
        } footer: {
            Text("Glob patterns to scope this policy to specific file paths. Leave empty to match all paths.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
        }
    }

    private var riskLevelSection: some View {
        Section {
            ForEach(PermissionRiskLevel.allCases, id: \.self) { level in
                Button {
                    toggleRiskLevel(level)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(riskLevelLabel(for: level))
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)

                            Text(riskLevelDescription(for: level))
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }

                        Spacer()

                        if selectedRiskLevels.contains(level) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(riskLevelColor(for: level))
                                .font(.system(size: theme.fontBody, weight: .semibold))
                        }
                    }
                }
                .accessibilityLabel("\(riskLevelLabel(for: level))\(selectedRiskLevels.contains(level) ? ", selected" : "")")
            }
        } header: {
            Text("Confirmation Required Risk Levels")
        } footer: {
            Text("Operations at these risk levels require explicit confirmation regardless of tool rules.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
        }
    }

    private var scopeSection: some View {
        Section {
            Picker("Scope", selection: $scope) {
                ForEach(PolicyScope.allCases, id: \.self) { s in
                    Text(scopeLabel(for: s)).tag(s)
                }
            }

            if scope == .project {
                TextField("Project name", text: $projectName)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }
        } header: {
            Text("Scope")
        } footer: {
            Text(scopeHelpText(for: scope))
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
        }
    }

    private var prioritySection: some View {
        Section {
            Stepper("Priority: \(priority)", value: $priority, in: 0...1000, step: 10)
        } header: {
            Text("Priority")
        } footer: {
            Text("Lower values are evaluated first. Default is 100.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
        }
    }

    private var optionsSection: some View {
        Section {
            Toggle("Enabled", isOn: $isEnabled)
        } header: {
            Text("Options")
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Populate from Existing

    private func populateFromExisting() {
        guard let policy = existingPolicy else { return }
        name = policy.name
        descriptionText = policy.description ?? ""
        defaultAction = policy.defaultAction
        selectedTools = Set(policy.toolRules.map(\.toolPattern))
        pathPatterns = policy.pathPatterns ?? []
        selectedRiskLevels = Set(policy.confirmationRequiredRiskLevels)
        scope = policy.scope
        projectName = policy.projectName ?? ""
        priority = policy.priority
        isEnabled = policy.isEnabled
    }

    // MARK: - Actions

    private func toggleTool(_ tool: String) {
        if selectedTools.contains(tool) {
            selectedTools.remove(tool)
        } else {
            selectedTools.insert(tool)
        }
    }

    private func toggleRiskLevel(_ level: PermissionRiskLevel) {
        if selectedRiskLevels.contains(level) {
            selectedRiskLevels.remove(level)
        } else {
            selectedRiskLevels.insert(level)
        }
    }

    private func addPathPattern() {
        let trimmed = newPathPattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        pathPatterns.append(trimmed)
        newPathPattern = ""
    }

    // MARK: - Save

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        isSaving = true
        saveError = nil

        let toolRules = selectedTools.sorted().map { tool in
            PolicyToolRule(toolPattern: tool, action: defaultAction)
        }

        let riskLevels: [PermissionRiskLevel]? = selectedRiskLevels.isEmpty
            ? nil
            : selectedRiskLevels.sorted(by: { $0.rawValue < $1.rawValue })

        let request = CreateApprovalPolicyRequest(
            name: trimmedName,
            description: descriptionText.isEmpty ? nil : descriptionText,
            template: .custom,
            scope: scope,
            projectName: scope == .project ? projectName : nil,
            pathPatterns: pathPatterns.isEmpty ? nil : pathPatterns,
            defaultAction: defaultAction,
            toolRules: toolRules,
            confirmationRequiredRiskLevels: riskLevels,
            isEnabled: isEnabled,
            priority: priority
        )

        let errorMessage = await onSave(request)
        isSaving = false

        if let errorMessage {
            saveError = errorMessage
        } else {
            HapticManager.selection()
            dismiss()
        }
    }

    // MARK: - Display Helpers

    private func actionLabel(for action: PolicyAction) -> String {
        switch action {
        case .alwaysAsk: return "Always Ask"
        case .autoApprove: return "Auto-Approve"
        case .autoDeny: return "Auto-Deny"
        case .requireConfirmation: return "Require Confirmation"
        }
    }

    private func actionHelpText(for action: PolicyAction) -> String {
        switch action {
        case .alwaysAsk: return "Every tool request will prompt for approval."
        case .autoApprove: return "Tool requests are approved automatically."
        case .autoDeny: return "Tool requests are denied automatically."
        case .requireConfirmation: return "Tool requests require explicit confirmation with context."
        }
    }

    private func scopeLabel(for s: PolicyScope) -> String {
        switch s {
        case .global: return "Global"
        case .project: return "Project"
        case .pathBased: return "Path-Based"
        }
    }

    private func scopeHelpText(for s: PolicyScope) -> String {
        switch s {
        case .global: return "Applies to all sessions and projects."
        case .project: return "Applies only within the specified project."
        case .pathBased: return "Applies only to operations matching the path patterns above."
        }
    }

    private func riskLevelLabel(for level: PermissionRiskLevel) -> String {
        switch level {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    private func riskLevelDescription(for level: PermissionRiskLevel) -> String {
        switch level {
        case .low: return "Read-only operations"
        case .medium: return "Write operations (e.g., editing files)"
        case .high: return "Shell commands and external calls"
        case .critical: return "Irreversible or destructive operations"
        }
    }

    private func riskLevelColor(for level: PermissionRiskLevel) -> Color {
        switch level {
        case .low: return theme.success
        case .medium: return theme.warning
        case .high: return Color.orange
        case .critical: return theme.error
        }
    }
}

#Preview {
    ApprovalPolicyEditorSheet(
        existingPolicy: nil,
        onSave: { _ in nil }
    )
}
