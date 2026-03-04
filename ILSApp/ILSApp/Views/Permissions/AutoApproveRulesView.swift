import SwiftUI

/// Auto-approve rules management view.
///
/// Shows global and project-scoped rules in sections with CRUD operations.
/// Tapping a rule opens ``AutoApproveRuleEditorSheet`` for editing. Rules can
/// be toggled, edited, or deleted via context menu.
struct AutoApproveRulesView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var viewModel = AutoApproveRulesViewModel()
    @State private var showCreateSheet = false
    @State private var editingRule: AutoApproveRule?
    @State private var operationError: String?

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
            await viewModel.loadRules()
        }
        .task {
            await viewModel.loadRules()
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

    // MARK: - Rules List

    private var rulesList: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingMD) {
                summaryHeader

                if !viewModel.globalRules.isEmpty {
                    rulesSection(
                        title: "Global Rules",
                        icon: "globe",
                        rules: viewModel.globalRules
                    )
                }

                if !viewModel.projectRules.isEmpty {
                    rulesSection(
                        title: "Project Rules",
                        icon: "folder",
                        rules: viewModel.projectRules
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
                Text("\(viewModel.rules.count)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                Text("Total Rules")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            VStack(spacing: 2) {
                Text("\(viewModel.rules.filter(\.isEnabled).count)")
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

    // MARK: - Rules Section

    private func rulesSection(title: String, icon: String, rules: [AutoApproveRule]) -> some View {
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
        Button {
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

                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                }

                // Badges row
                HStack(spacing: theme.spacingSM) {
                    if let toolName = rule.toolName {
                        Text(toolName)
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if rule.isDestructive {
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
        .accessibilityLabel(accessibilityLabel(for: rule))
        .accessibilityHint("Tap to edit, long press for options")
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

    private func accessibilityLabel(for rule: AutoApproveRule) -> String {
        let status = rule.isEnabled ? "enabled" : "disabled"
        return "\(ruleSummary(rule)), \(status)"
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

                Text("Create rules to automatically approve common safe operations — like file reads in your project directory or routine git commands.")
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
                    .foregroundStyle(.white)
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
        ("Read anything in /src", "Tool: Read · Path: /src/**"),
        ("Git status", "Tool: Bash · Command prefix: git status"),
        ("Run tests", "Tool: Bash · Command prefix: swift test"),
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
}

#Preview {
    NavigationStack {
        AutoApproveRulesView()
    }
}
