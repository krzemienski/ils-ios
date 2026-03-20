import SwiftUI
import ILSShared

// MARK: - ApprovalPoliciesView

/// Approval policy management list screen.
///
/// Shows policies grouped by scope (global vs project-scoped), each row
/// displaying the policy name, action type badge, scope summary, and an
/// enabled toggle. Tapping a row opens an editor sheet for editing. Swipe
/// or context-menu to delete. A toolbar button opens the templates browser.
struct ApprovalPoliciesView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) private var appState

    @State private var viewModel = ApprovalPoliciesViewModel()
    @State private var showCreateSheet = false
    @State private var editingPolicy: ApprovalPolicy?
    @State private var showTemplates = false
    @State private var operationError: String?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.policies.isEmpty {
                loadingState
            } else if viewModel.policies.isEmpty {
                emptyState
            } else {
                policiesList
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Approval Policies")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("New Policy", systemImage: "plus")
                    }

                    Button {
                        showTemplates = true
                    } label: {
                        Label("Browse Templates", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add policy")
            }
        }
        .refreshable {
            await viewModel.loadPolicies()
        }
        .task {
            await viewModel.loadPolicies()
            await viewModel.loadTemplates()
        }
        .sheet(isPresented: $showCreateSheet) {
            ApprovalPolicyEditorSheet(
                existingPolicy: nil,
                onSave: { request in
                    let result = await viewModel.createPolicy(request)
                    if let err = viewModel.error {
                        return err.localizedDescription
                    }
                    return result == nil ? "Failed to create policy" : nil
                }
            )
        }
        .sheet(item: $editingPolicy) { policy in
            ApprovalPolicyEditorSheet(
                existingPolicy: policy,
                onSave: { request in
                    let updateRequest = UpdateApprovalPolicyRequest(
                        name: request.name,
                        description: request.description,
                        template: request.template,
                        scope: request.scope,
                        projectName: request.projectName,
                        pathPatterns: request.pathPatterns,
                        defaultAction: request.defaultAction,
                        toolRules: request.toolRules,
                        confirmationRequiredRiskLevels: request.confirmationRequiredRiskLevels,
                        isEnabled: request.isEnabled,
                        priority: request.priority
                    )
                    let result = await viewModel.updatePolicy(id: policy.id, updateRequest)
                    if let err = viewModel.error {
                        return err.localizedDescription
                    }
                    return result == nil ? "Failed to update policy" : nil
                }
            )
        }
        .sheet(isPresented: $showTemplates) {
            PolicyTemplatesSheet(
                templates: viewModel.templates,
                onApply: { templateId in
                    let result = await viewModel.applyTemplate(templateId: templateId)
                    if let err = viewModel.error {
                        operationError = err.localizedDescription
                    }
                    return result != nil
                }
            )
        }
        .alert("Error", isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = operationError {
                Text(error)
            }
        }
    }

    // MARK: - Policies List

    private var policiesList: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingMD) {
                summaryHeader

                if !viewModel.globalPolicies.isEmpty {
                    policiesSection(
                        title: "Global Policies",
                        icon: "globe",
                        policies: viewModel.globalPolicies
                    )
                }

                if !viewModel.projectPolicies.isEmpty {
                    policiesSection(
                        title: "Project Policies",
                        icon: "folder",
                        policies: viewModel.projectPolicies
                    )
                }

                // Path-based policies (shown under their own section)
                let pathPolicies = viewModel.policies.filter { $0.scope == .pathBased }
                if !pathPolicies.isEmpty {
                    policiesSection(
                        title: "Path-Based Policies",
                        icon: "doc.text",
                        policies: pathPolicies
                    )
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        HStack(spacing: theme.spacingMD) {
            VStack(spacing: 2) {
                Text("\(viewModel.totalCount)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                Text("Total")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            VStack(spacing: 2) {
                Text("\(viewModel.enabledCount)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.success)
                Text("Active")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.success.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
    }

    // MARK: - Policies Section

    private func policiesSection(title: String, icon: String, policies: [ApprovalPolicy]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: icon)
                    .foregroundStyle(theme.accent)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Text("\(policies.count)")
                    .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.bgTertiary)
                    .clipShape(Capsule())
            }
            .padding(.top, theme.spacingSM)

            ForEach(policies) { policy in
                policyRow(policy: policy)
            }
        }
    }

    // MARK: - Policy Row

    private func policyRow(policy: ApprovalPolicy) -> some View {
        Button {
            editingPolicy = policy
        } label: {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                // Name and chevron
                HStack(spacing: theme.spacingSM) {
                    Text(policy.name)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(policy.isEnabled ? theme.textPrimary : theme.textTertiary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                }

                // Badges row
                HStack(spacing: theme.spacingSM) {
                    actionBadge(for: policy.defaultAction)

                    scopeBadge(for: policy)

                    if !policy.isEnabled {
                        Text("Disabled")
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if policy.template != .custom {
                        Text(templateLabel(for: policy.template))
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Spacer()
                }

                // Description if available
                if let description = policy.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                // Tool rules summary
                if !policy.toolRules.isEmpty {
                    Text("\(policy.toolRules.count) tool rule\(policy.toolRules.count == 1 ? "" : "s")")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingPolicy = policy
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                Task { await viewModel.toggleEnabled(policy) }
            } label: {
                Label(
                    policy.isEnabled ? "Disable" : "Enable",
                    systemImage: policy.isEnabled ? "pause.circle" : "play.circle"
                )
            }

            Button(role: .destructive) {
                Task {
                    let success = await viewModel.deletePolicy(id: policy.id)
                    if !success, let err = viewModel.error {
                        operationError = err.localizedDescription
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: policy))
        .accessibilityHint("Tap to edit, long press for options")
    }

    // MARK: - Action Badge

    private func actionBadge(for action: PolicyAction) -> some View {
        HStack(spacing: 2) {
            Image(systemName: actionIcon(for: action))
                .accessibilityHidden(true)
            Text(actionLabel(for: action))
        }
        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
        .foregroundStyle(actionColor(for: action))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(actionColor(for: action).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Scope Badge

    private func scopeBadge(for policy: ApprovalPolicy) -> some View {
        let text = scopeSummary(for: policy)
        return Text(text)
            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.accent.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Display Helpers

    private func actionLabel(for action: PolicyAction) -> String {
        switch action {
        case .autoApprove: return "Auto-Approve"
        case .alwaysAsk: return "Always Ask"
        case .autoDeny: return "Auto-Deny"
        case .requireConfirmation: return "Confirm"
        }
    }

    private func actionIcon(for action: PolicyAction) -> String {
        switch action {
        case .autoApprove: return "checkmark.circle.fill"
        case .alwaysAsk: return "questionmark.circle.fill"
        case .autoDeny: return "xmark.circle.fill"
        case .requireConfirmation: return "exclamationmark.circle.fill"
        }
    }

    private func actionColor(for action: PolicyAction) -> Color {
        switch action {
        case .autoApprove: return theme.success
        case .alwaysAsk: return theme.warning
        case .autoDeny: return theme.error
        case .requireConfirmation: return theme.accent
        }
    }

    private func scopeSummary(for policy: ApprovalPolicy) -> String {
        switch policy.scope {
        case .global:
            return "Global"
        case .project:
            return policy.projectName ?? "Project"
        case .pathBased:
            if let patterns = policy.pathPatterns, !patterns.isEmpty {
                return patterns.count == 1 ? patterns[0] : "\(patterns.count) paths"
            }
            return "Path-Based"
        }
    }

    private func templateLabel(for template: PolicyTemplate) -> String {
        switch template {
        case .strict: return "Strict"
        case .balanced: return "Balanced"
        case .permissive: return "Permissive"
        case .custom: return "Custom"
        }
    }

    private func accessibilityLabel(for policy: ApprovalPolicy) -> String {
        let status = policy.isEnabled ? "enabled" : "disabled"
        let action = actionLabel(for: policy.defaultAction)
        let scope = scopeSummary(for: policy)
        return "\(policy.name), \(action), \(scope), \(status)"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 40, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)

                Text("No Approval Policies")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("Approval policies define deterministic rules for how agent tool-use requests are handled — auto-approve, always ask, or auto-deny.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingLG)

                Button {
                    showCreateSheet = true
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "plus.circle.fill")
                            .accessibilityHidden(true)
                        Text("Create Policy")
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingMD)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, theme.spacingMD)

                if !viewModel.templates.isEmpty {
                    Button {
                        showTemplates = true
                    } label: {
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: "doc.on.doc.fill")
                                .accessibilityHidden(true)
                            Text("Browse Templates")
                                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        }
                        .foregroundStyle(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingMD)
                        .background(theme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, theme.spacingMD)
                }

                // Example policies card
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Text("Example Policies")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    ForEach(Self.examplePolicies, id: \.title) { example in
                        HStack(alignment: .top, spacing: theme.spacingSM) {
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: theme.fontCaption))
                                .foregroundStyle(theme.accent)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(example.title)
                                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                                Text(example.detail)
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                    }
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
                .padding(.horizontal, theme.spacingMD)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingXL)
        }
    }

    private static let examplePolicies: [(title: String, detail: String)] = [
        ("Strict", "All actions require explicit approval"),
        ("Balanced", "Low-risk auto-approved, high-risk require confirmation"),
        ("Permissive", "Most auto-approved, only destructive blocked"),
    ]

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: theme.spacingMD) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading policies...")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ApprovalPolicyEditorSheet

/// A sheet for creating or editing an approval policy.
///
/// Presents form fields for name, description, scope, default action,
/// and enabled state. Calls the `onSave` closure with a
/// ``CreateApprovalPolicyRequest`` payload on confirmation.
struct ApprovalPolicyEditorSheet: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    let existingPolicy: ApprovalPolicy?
    let onSave: (CreateApprovalPolicyRequest) async -> String?

    @State private var name: String = ""
    @State private var descriptionText: String = ""
    @State private var scope: PolicyScope = .global
    @State private var projectName: String = ""
    @State private var defaultAction: PolicyAction = .alwaysAsk
    @State private var isEnabled: Bool = true
    @State private var isSaving: Bool = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    // Name field
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        sectionLabel("Name")
                        TextField("Policy name...", text: $name)
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                            .padding(theme.spacingSM)
                            .modifier(GlassCard())
                            .accessibilityLabel("Policy name input")
                    }

                    // Description field
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        sectionLabel("Description")
                        TextField("Optional description...", text: $descriptionText)
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                            .padding(theme.spacingSM)
                            .modifier(GlassCard())
                            .accessibilityLabel("Policy description input")
                    }

                    // Scope picker
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        sectionLabel("Scope")
                        Picker("Scope", selection: $scope) {
                            Text("Global").tag(PolicyScope.global)
                            Text("Project").tag(PolicyScope.project)
                            Text("Path-Based").tag(PolicyScope.pathBased)
                        }
                        .pickerStyle(.segmented)
                        .tint(theme.accent)
                        .accessibilityLabel("Policy scope picker")
                    }

                    // Project name (shown when scope is project)
                    if scope == .project {
                        VStack(alignment: .leading, spacing: theme.spacingSM) {
                            sectionLabel("Project Name")
                            TextField("Project name...", text: $projectName)
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                                .padding(theme.spacingSM)
                                .modifier(GlassCard())
                                .accessibilityLabel("Project name input")
                        }
                    }

                    // Default action picker
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        sectionLabel("Default Action")
                        Picker("Default action", selection: $defaultAction) {
                            Text("Always Ask").tag(PolicyAction.alwaysAsk)
                            Text("Auto-Approve").tag(PolicyAction.autoApprove)
                            Text("Auto-Deny").tag(PolicyAction.autoDeny)
                            Text("Confirm").tag(PolicyAction.requireConfirmation)
                        }
                        .pickerStyle(.segmented)
                        .tint(theme.accent)
                        .accessibilityLabel("Default action picker")

                        Text(actionHelpText(for: defaultAction))
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }

                    // Enabled toggle
                    HStack {
                        Text("Enabled")
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Toggle("", isOn: $isEnabled)
                            .labelsHidden()
                            .tint(theme.accent)
                    }
                    .padding(theme.spacingSM)
                    .modifier(GlassCard())

                    // Error display
                    if let saveError {
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(theme.error)
                                .accessibilityHidden(true)
                            Text(saveError)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.error)
                        }
                        .padding(theme.spacingSM)
                        .modifier(GlassCard())
                    }
                }
                .padding(theme.spacingMD)
            }
            .background(theme.bgPrimary)
            .navigationTitle(existingPolicy != nil ? "Edit Policy" : "New Policy")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .environment(\.theme, theme)
        .onAppear {
            if let policy = existingPolicy {
                name = policy.name
                descriptionText = policy.description ?? ""
                scope = policy.scope
                projectName = policy.projectName ?? ""
                defaultAction = policy.defaultAction
                isEnabled = policy.isEnabled
            }
        }
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    private func actionHelpText(for action: PolicyAction) -> String {
        switch action {
        case .alwaysAsk: return "Every tool request will prompt for approval."
        case .autoApprove: return "Tool requests are approved automatically."
        case .autoDeny: return "Tool requests are denied automatically."
        case .requireConfirmation: return "Tool requests require explicit confirmation with context."
        }
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        isSaving = true
        saveError = nil

        let request = CreateApprovalPolicyRequest(
            name: trimmedName,
            description: descriptionText.isEmpty ? nil : descriptionText,
            scope: scope,
            projectName: scope == .project ? projectName : nil,
            defaultAction: defaultAction,
            isEnabled: isEnabled
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
}

// MARK: - PolicyTemplatesSheet

/// A sheet displaying available built-in policy templates that can be applied
/// to create new policies with pre-configured defaults.
struct PolicyTemplatesSheet: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    let templates: [PolicyTemplateResponse]
    let onApply: (String) async -> Bool

    @State private var applyingTemplateId: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if templates.isEmpty {
                    VStack(spacing: theme.spacingMD) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 40, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .accessibilityHidden(true)
                        Text("No Templates Available")
                            .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("Templates will appear here once the backend is configured.")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingXL)
                } else {
                    LazyVStack(spacing: theme.spacingMD) {
                        ForEach(templates) { template in
                            templateRow(template: template)
                        }
                    }
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.bottom, theme.spacingLG)
                }
            }
            .background(theme.bgPrimary)
            .navigationTitle("Policy Templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .environment(\.theme, theme)
    }

    private func templateRow(template: PolicyTemplateResponse) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text(template.description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                Button {
                    Task {
                        applyingTemplateId = template.id
                        let success = await onApply(template.id)
                        applyingTemplateId = nil
                        if success {
                            HapticManager.selection()
                            dismiss()
                        }
                    }
                } label: {
                    if applyingTemplateId == template.id {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Text("Apply")
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    }
                }
                .buttonStyle(.plain)
                .disabled(applyingTemplateId != nil)
            }

            // Tool rules summary
            if !template.toolRules.isEmpty {
                HStack(spacing: theme.spacingSM) {
                    ForEach(template.toolRules.prefix(3), id: \.toolPattern) { rule in
                        Text(rule.toolPattern)
                            .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if template.toolRules.count > 3 {
                        Text("+\(template.toolRules.count - 3)")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }
}

#Preview {
    NavigationStack {
        ApprovalPoliciesView()
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
            .environment(AppState())
    }
}
