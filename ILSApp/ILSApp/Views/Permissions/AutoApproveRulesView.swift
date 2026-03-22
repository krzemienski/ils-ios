import SwiftUI
import ILSShared

// MARK: - AutoApproveRulesView

/// Auto-approve rules management view.
///
/// Shows rules grouped into Allow and Deny sections with color-coded action badges.
/// A Settings section surfaces the Default Deny toggle fetched from the backend.
/// Tapping a rule opens ``AutoApproveRuleEditorSheet`` for editing. Rules can
/// be toggled, edited, or deleted via context menu.
///
/// Each rule row shows a match count badge drawn from the permission history,
/// making it easy to see which rules are actively being evaluated.
///
/// On first launch (empty rules list), seeds two common read-only defaults:
/// - **Read** (contains match, low risk)
/// - **Glob** (contains match, low risk)
struct AutoApproveRulesView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) private var appState

    @State private var viewModel = AutoApproveRulesViewModel()
    @State private var showCreateSheet = false
    @State private var editingRule: AutoApproveRule?
    @State private var operationError: String?
    @State private var showAddRule: Bool = false
    @State private var newPattern: String = ""
    @State private var newMatchType: AutoApproveMatchType = .contains
    @State private var newMaxRiskLevel: PermissionRiskLevel = .low

    // MARK: - Policy Settings State

    @State private var defaultDeny: Bool = false
    @State private var isLoadingSettings: Bool = false

    private let policyAPIService = PermissionPolicyAPIService()

    private var service: PermissionService { appState.permissionService }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.rules.isEmpty {
                loadingState
            } else if viewModel.rules.isEmpty {
                emptyState
            } else {
                rulesList
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Auto-Approve Rules")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create new rule")
            }
        }
        .refreshable {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await viewModel.loadRules() }
                group.addTask { await loadSettings() }
            }
        }
        .task {
            await viewModel.loadRules()
            await loadSettings()
        }
        .sheet(isPresented: $showCreateSheet) {
            AutoApproveRuleEditorSheet(
                existingRule: nil,
                onSave: { rule, allowDestructive in
                    await viewModel.addRule(rule, allowDestructive: allowDestructive)
                    return viewModel.error
                }
            )
        }
        .sheet(item: $editingRule) { rule in
            AutoApproveRuleEditorSheet(
                existingRule: rule,
                onSave: { updated, allowDestructive in
                    await viewModel.updateRule(updated, allowDestructive: allowDestructive)
                    return viewModel.error
                }
            )
        }
        .sheet(isPresented: $showAddRule) {
            addRuleSheet
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
        .onAppear {
            if service.autoApproveRules.isEmpty {
                seedDefaultRules()
            }
        }
    }

    // MARK: - Rules List

    private var rulesList: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingMD) {
                warningSection
                settingsSection
                summaryHeader

                let allowRules = viewModel.rules.filter { $0.action == .allow }
                let denyRules = viewModel.rules.filter { $0.action == .deny }

                if !allowRules.isEmpty {
                    rulesSection(
                        title: "Allow Rules",
                        icon: "checkmark.shield.fill",
                        iconColor: theme.success,
                        rules: allowRules
                    )
                }

                if !denyRules.isEmpty {
                    rulesSection(
                        title: "Deny Rules",
                        icon: "xmark.shield.fill",
                        iconColor: theme.error,
                        rules: denyRules
                    )
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(theme.accent)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .accessibilityHidden(true)

                Text("Settings")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
            }
            .padding(.top, theme.spacingSM)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Default Deny")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text("Auto-deny unmatched requests")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                if isLoadingSettings {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                } else {
                    Toggle("", isOn: Binding(
                        get: { defaultDeny },
                        set: { newValue in
                            defaultDeny = newValue
                            Task { await saveDefaultDeny(newValue) }
                        }
                    ))
                    .tint(theme.error)
                    .labelsHidden()
                    .accessibilityLabel("Default deny mode")
                    .accessibilityHint("When enabled, unmatched permission requests are automatically denied")
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Warning Section

    private var warningSection: some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.warning)
            Text("Auto-approved tools run without asking. Only enable for read-only operations like file reading.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning: auto-approved tools run without asking. Only enable for read-only operations.")
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        HStack(spacing: theme.spacingMD) {
            VStack(spacing: 2) {
                Text("\(viewModel.rules.filter { $0.action == .allow }.count)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.success)
                Text("Allow")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.success.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            VStack(spacing: 2) {
                Text("\(viewModel.rules.filter { $0.action == .deny }.count)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.error)
                Text("Deny")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.error.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            VStack(spacing: 2) {
                Text("\(viewModel.rules.filter(\.isEnabled).count)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                Text("Active")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
    }

    // MARK: - Rules Section

    private func rulesSection(
        title: String,
        icon: String,
        iconColor: Color,
        rules: [AutoApproveRule]
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Text("\(rules.count)")
                    .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.bgTertiary)
                    .clipShape(Capsule())
            }
            .padding(.top, theme.spacingSM)

            ForEach(rules) { rule in
                ruleRow(rule: rule)
            }
        }
    }

    // MARK: - Rule Row

    private func ruleRow(rule: AutoApproveRule) -> some View {
        let matchCount = service.permissionHistory.filter { $0.matchedPolicyId == rule.id }.count

        return Button {
            editingRule = rule
        } label: {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                // Summary line
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: rule.isEnabled ? "checkmark.shield.fill" : "shield.slash")
                        .foregroundStyle(rule.isEnabled ? theme.success : theme.textTertiary)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .accessibilityHidden(true)

                    Text(ruleSummary(rule))
                        .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)

                    Spacer()

                    // Match count badge
                    if matchCount > 0 {
                        Text("\(matchCount)")
                            .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                            .foregroundStyle(theme.textOnAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rule.action == .allow ? theme.success : theme.error)
                            .clipShape(Capsule())
                            .accessibilityLabel("\(matchCount) matches")
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                }

                // Badges row
                HStack(spacing: theme.spacingSM) {
                    // Allow / Deny action badge
                    actionBadge(for: rule.action)

                    if let toolName = rule.toolName {
                        Text(toolName)
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if rule.isDestructive && rule.action == .allow {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .accessibilityHidden(true)
                            Text("Destructive")
                        }
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.error)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.error.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if !rule.isEnabled {
                        Text("Disabled")
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if let note = rule.note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingRule = rule
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                Task { await viewModel.toggleEnabled(rule) }
            } label: {
                Label(
                    rule.isEnabled ? "Disable" : "Enable",
                    systemImage: rule.isEnabled ? "pause.circle" : "play.circle"
                )
            }

            Button(role: .destructive) {
                Task {
                    await viewModel.deleteRules(atOffsets: IndexSet(integer: 0), in: [rule])
                    if let err = viewModel.error {
                        operationError = err
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: rule, matchCount: matchCount))
        .accessibilityHint("Tap to edit, long press for options")
    }

    // MARK: - Action Badge

    @ViewBuilder
    private func actionBadge(for action: PermissionPolicyAction) -> some View {
        HStack(spacing: 3) {
            Image(systemName: action == .allow ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: theme.fontCaption))
                .accessibilityHidden(true)
            Text(action == .allow ? "Allow" : "Deny")
        }
        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
        .foregroundStyle(action == .allow ? theme.success : theme.error)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background((action == .allow ? theme.success : theme.error).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Helpers

    private func ruleSummary(_ rule: AutoApproveRule) -> String {
        var parts: [String] = []
        if let tool = rule.toolName { parts.append(tool) }
        if let cmd = rule.commandPrefix { parts.append("cmd: \(cmd)") }
        if let path = rule.pathGlob { parts.append("path: \(path)") }
        if parts.isEmpty { parts.append("Any tool") }
        return parts.joined(separator: " · ")
    }

    private func accessibilityLabel(for rule: AutoApproveRule, matchCount: Int) -> String {
        let status = rule.isEnabled ? "enabled" : "disabled"
        let action = rule.action == .allow ? "allow" : "deny"
        var label = "\(ruleSummary(rule)), \(action), \(status)"
        if matchCount > 0 {
            label += ", \(matchCount) matches"
        }
        return label
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 40, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)

                Text("No Auto-Approve Rules")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("Create rules to automatically allow or deny Claude Code tool operations.")
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
                        Text("Create Rule")
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingMD)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, theme.spacingMD)

                // Example rules card
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Text("Example Rules")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    ForEach(Self.exampleRules, id: \.title) { example in
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

    private static let exampleRules: [(title: String, detail: String)] = [
        ("Allow reads in /src", "Tool: Read · Path: /src/** · Action: Allow"),
        ("Deny writes to .env", "Tool: Write · Path: **/.env · Action: Deny"),
        ("Allow git status", "Tool: Bash · Command: git status · Action: Allow"),
    ]

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: theme.spacingMD) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading rules...")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Add Rule Sheet

    private var addRuleSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    // Pattern field
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        sheetSectionLabel("Pattern")

                        TextField("Tool name pattern...", text: $newPattern)
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                            .padding(theme.spacingSM)
                            .modifier(GlassCard())
                            .accessibilityLabel("Tool name pattern input")
                    }

                    // Match type picker
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        sheetSectionLabel("Match Type")

                        Picker("Match type", selection: $newMatchType) {
                            ForEach(AutoApproveMatchType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(theme.accent)
                        .accessibilityLabel("Match type picker")
                    }

                    // Max risk level picker
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        sheetSectionLabel("Max Risk Level")

                        Picker("Max risk level", selection: $newMaxRiskLevel) {
                            ForEach(PermissionRiskLevel.allCases, id: \.self) { level in
                                Text(riskLabel(for: level)).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(theme.accent)
                        .accessibilityLabel("Maximum risk level picker")
                    }

                    // Help text
                    Text("The rule auto-approves requests at or below the selected risk level.")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(theme.spacingMD)
            }
            .background(theme.bgPrimary)
            .navigationTitle("Add Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetAddRuleForm()
                        showAddRule = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNewRule()
                        showAddRule = false
                    }
                    .disabled(newPattern.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .environment(\.theme, theme)
    }

    // MARK: - Section Labels

    @ViewBuilder
    private func sheetSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    // MARK: - Backend Settings

    private func loadSettings() async {
        isLoadingSettings = true
        defer { isLoadingSettings = false }
        do {
            let settings = try await policyAPIService.fetchSettings(apiClient: appState.apiClient)
            defaultDeny = settings.defaultDeny
        } catch {
            // Settings load failure is non-fatal; keep existing value
            AppLogger.shared.info(
                "Could not load policy settings: \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    private func saveDefaultDeny(_ value: Bool) async {
        isLoadingSettings = true
        defer { isLoadingSettings = false }
        do {
            let request = UpdatePermissionPolicySettingsRequest(defaultDeny: value)
            let updated = try await policyAPIService.updateSettings(request, apiClient: appState.apiClient)
            defaultDeny = updated.defaultDeny
        } catch {
            // Revert optimistic update on failure
            defaultDeny = !value
            AppLogger.shared.error(
                "Failed to save policy settings: \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    // MARK: - Actions

    private func saveNewRule() {
        let trimmed = newPattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let pattern: String
        switch newMatchType {
        case .contains:
            pattern = trimmed
        case .prefix:
            pattern = trimmed.hasSuffix("*") ? trimmed : trimmed + "*"
        }

        let rule = AutoApproveRule(
            toolName: pattern,
            isEnabled: true
        )
        service.addAutoApproveRule(rule)
        HapticManager.selection()
        resetAddRuleForm()
    }

    private func resetAddRuleForm() {
        newPattern = ""
        newMatchType = .contains
        newMaxRiskLevel = .low
    }

    private func seedDefaultRules() {
        let defaults: [(pattern: String, risk: PermissionRiskLevel)] = [
            ("Read", .low),
            ("Glob", .low)
        ]
        for entry in defaults {
            let rule = AutoApproveRule(
                toolName: entry.pattern,
                isEnabled: true
            )
            service.addAutoApproveRule(rule)
        }
    }

    // MARK: - Display Helpers

    private func riskLabel(for level: PermissionRiskLevel) -> String {
        switch level {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

// MARK: - AutoApproveMatchType

/// Describes how a tool-name pattern is matched against incoming tool requests.
///
/// Used in ``AutoApproveRulesView`` to present a user-friendly match-type picker.
/// The selected type is serialised into the pattern string stored in
/// ``AutoApproveRule/toolPattern``:
/// - `contains`: pattern stored as-is (service performs substring match)
/// - `prefix`: pattern stored with trailing `*` (service strips `*` and prefix-matches)
private enum AutoApproveMatchType: String, CaseIterable {
    /// Match any tool name that contains the pattern string.
    case contains = "contains"
    /// Match any tool name that starts with the pattern string.
    case prefix = "prefix"

    var displayName: String {
        switch self {
        case .contains: return "Contains"
        case .prefix: return "Starts with"
        }
    }
}

#Preview {
    NavigationStack {
        AutoApproveRulesView()
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
            .environment(AppState())
    }
}
