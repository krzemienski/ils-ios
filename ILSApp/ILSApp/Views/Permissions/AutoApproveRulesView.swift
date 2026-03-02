import SwiftUI
import ILSShared

// MARK: - AutoApproveRulesView

/// Settings view for managing auto-approve rules for Claude Code tool-use requests.
///
/// Displays a list of ``AutoApproveRule`` records persisted by ``PermissionService``.
/// Each row shows the tool-name pattern, a human-readable match-type description,
/// the maximum risk level the rule will approve, and an enable/disable toggle.
/// Rules can be deleted via the trailing trash button and added via the toolbar `+` button.
///
/// On first launch (empty rules list), the view seeds two common read-only defaults:
/// - **Read** (contains match, low risk)
/// - **Glob** (contains match, low risk)
///
/// ## Topics
/// ### State
/// - ``showAddRule`` - Whether the add-rule sheet is presented
/// - ``newPattern`` - Tool-name pattern being entered in the sheet
/// - ``newMatchType`` - Match strategy for the new rule
/// - ``newMaxRiskLevel`` - Maximum risk level for the new rule
struct AutoApproveRulesView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var showAddRule: Bool = false
    @State private var newPattern: String = ""
    @State private var newMatchType: AutoApproveMatchType = .contains
    @State private var newMaxRiskLevel: PermissionRiskLevel = .low

    private var service: PermissionService { appState.permissionService }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                warningSection
                rulesSection
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Auto-Approve Rules")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddRule = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add auto-approve rule")
            }
        }
        .sheet(isPresented: $showAddRule) {
            addRuleSheet
        }
        .onAppear {
            if service.autoApproveRules.isEmpty {
                seedDefaultRules()
            }
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

    // MARK: - Rules Section

    @ViewBuilder
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Rules")

            if service.autoApproveRules.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(service.autoApproveRules) { rule in
                        ruleRow(rule)

                        if rule.id != service.autoApproveRules.last?.id {
                            Divider().background(theme.bgTertiary)
                        }
                    }
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
        }
    }

    // MARK: - Rule Row

    @ViewBuilder
    private func ruleRow(_ rule: AutoApproveRule) -> some View {
        HStack(spacing: theme.spacingSM) {
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in toggleRule(rule) }
            ))
            .labelsHidden()
            .tint(theme.accent)
            .accessibilityLabel(rule.isEnabled ? "Disable rule" : "Enable rule")
            .onChange(of: rule.isEnabled) {
                HapticManager.selection()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.toolPattern)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(matchTypeLabel(for: rule.toolPattern))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                    Text("·")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                    Text(riskLabel(for: rule.maxRiskLevel))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(riskColor(for: rule.maxRiskLevel))
                }
            }

            Spacer()

            Button {
                service.removeAutoApproveRule(id: rule.id)
                HapticManager.selection()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.error)
            }
            .accessibilityLabel("Delete rule \(rule.toolPattern)")
        }
        .padding(.vertical, theme.spacingXS)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rule.toolPattern), \(matchTypeLabel(for: rule.toolPattern)), \(riskLabel(for: rule.maxRiskLevel)), \(rule.isEnabled ? "enabled" : "disabled")")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 40, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text("No Rules Configured")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text("Tap + to add a rule that auto-approves matching tool requests.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(theme.spacingXL)
        .frame(maxWidth: .infinity)
        .modifier(GlassCard())
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
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    @ViewBuilder
    private func sheetSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    // MARK: - Actions

    private func toggleRule(_ rule: AutoApproveRule) {
        guard let idx = service.autoApproveRules.firstIndex(where: { $0.id == rule.id }) else { return }
        let toggled = AutoApproveRule(
            id: rule.id,
            toolPattern: rule.toolPattern,
            projectId: rule.projectId,
            maxRiskLevel: rule.maxRiskLevel,
            isEnabled: !rule.isEnabled,
            createdAt: rule.createdAt
        )
        service.autoApproveRules[idx] = toggled
        service.saveAutoApproveRules()
        HapticManager.selection()
    }

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
            id: UUID().uuidString,
            toolPattern: pattern,
            maxRiskLevel: newMaxRiskLevel,
            isEnabled: true,
            createdAt: Date()
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
                id: UUID().uuidString,
                toolPattern: entry.pattern,
                maxRiskLevel: entry.risk,
                isEnabled: true,
                createdAt: Date()
            )
            service.addAutoApproveRule(rule)
        }
    }

    // MARK: - Display Helpers

    private func matchTypeLabel(for pattern: String) -> String {
        pattern.hasSuffix("*") ? "Starts with" : "Contains"
    }

    private func riskLabel(for level: PermissionRiskLevel) -> String {
        switch level {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    private func riskColor(for level: PermissionRiskLevel) -> Color {
        switch level {
        case .low: return theme.accent
        case .medium: return theme.warning
        case .high, .critical: return theme.error
        }
    }
}

// MARK: - AutoApproveMatchType

/// Describes how a tool-name pattern is matched against incoming tool requests.
///
/// Used exclusively in ``AutoApproveRulesView`` to present a user-friendly
/// match-type picker. The selected type is serialised into the pattern string
/// stored in ``AutoApproveRule/toolPattern``:
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
