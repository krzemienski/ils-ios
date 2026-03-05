import SwiftUI
import ILSShared

/// macOS-optimized automation rules management view with list layout and keyboard navigation
///
/// Displays automation rules grouped by enabled/disabled status, with search, toggles,
/// and context menu actions. Follows macOS UI conventions with sidebar-style list.
///
/// ## Topics
/// ### Sections
/// - ``enabledRulesSection`` - List of currently active automation rules
/// - ``disabledRulesSection`` - List of inactive automation rules
/// - ``emptyStateView`` - Placeholder shown when no rules exist
///
/// ### Actions
/// - ``onCreateRule`` - Navigate to rule editor for creating a new rule
/// - ``onEditRule`` - Navigate to rule editor for modifying an existing rule
/// - ``toggleRule`` - Enable or disable a rule
/// - ``deleteRule`` - Remove a rule from the system
struct MacAutomationRulesView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// View model managing rule state and API operations.
    @State private var viewModel = AutomationRulesViewModel()
    /// Text entered in the rules search bar.
    @State private var searchText: String = ""
    /// Debounced search text to avoid excessive filtering.
    @State private var debouncedSearchText: String = ""
    /// Selected rule ID for keyboard navigation.
    @State private var selectedRuleId: UUID?
    /// Controls presentation of the New Rule sheet.
    @State private var showNewRuleSheet = false
    /// Rule currently being edited (nil when creating a new rule).
    @State private var editingRule: AutomationRule? = nil
    /// Rule ID for which execution history is being viewed.
    @State private var viewingHistoryForRule: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            headerView

            // Search bar
            searchBarView

            // Rules list
            listView

            Divider()

            // New Rule button
            newRuleButton
        }
        .background(theme.bgPrimary)
        .sheet(isPresented: $showNewRuleSheet) {
            NavigationStack {
                MacRuleEditorView(editingRule: editingRule) {
                    Task { await viewModel.loadRules() }
                }
                .environment(appState)
                .environment(\.theme, theme)
            }
        }
        .sheet(item: Bindable(viewModel).error.map { ErrorWrapper(error: $0) }) { wrapper in
            ErrorAlertView(error: wrapper.error) {
                viewModel.error = nil
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadRules()
        }
        .onChange(of: appState.serverURL) { _, _ in
            viewModel.configure(client: appState.apiClient)
            Task { await viewModel.loadRules() }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("AUTOMATION RULES")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Spacer()
            if !debouncedSearchText.isEmpty {
                Text("\(filteredRules.count) of \(viewModel.rules.count)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            } else {
                Text("\(viewModel.rules.count)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.top, theme.spacingMD)
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - Search Bar

    private var searchBarView: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            TextField("Search rules...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    debouncedSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS + 2)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .padding(.horizontal, theme.spacingMD)
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - List

    private var listView: some View {
        List(selection: $selectedRuleId) {
            if viewModel.isLoading && viewModel.rules.isEmpty {
                loadingView
            } else if filteredRules.isEmpty {
                emptyView
            } else {
                enabledRulesSection
                disabledRulesSection
            }
        }
        .listStyle(.sidebar)
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(300))
            debouncedSearchText = searchText
        }
        .onChange(of: selectedRuleId) { _, newId in
            // Handle keyboard selection (Return key)
            if let ruleId = newId,
               let rule = viewModel.rules.first(where: { $0.id == ruleId }) {
                editingRule = rule
                showNewRuleSheet = true
            }
        }
    }

    // MARK: - Enabled Rules Section

    @ViewBuilder
    private var enabledRulesSection: some View {
        let enabled = filteredRules.filter { $0.isEnabled }

        if !enabled.isEmpty {
            Section {
                ForEach(enabled) { rule in
                    ruleRow(rule)
                        .tag(rule.id)
                }
            } header: {
                HStack {
                    Text("Enabled")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text("\(enabled.count)")
                        .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Disabled Rules Section

    @ViewBuilder
    private var disabledRulesSection: some View {
        let disabled = filteredRules.filter { !$0.isEnabled }

        if !disabled.isEmpty {
            Section {
                ForEach(disabled) { rule in
                    ruleRow(rule)
                        .tag(rule.id)
                }
            } header: {
                HStack {
                    Text("Disabled")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)

                    Text("\(disabled.count)")
                        .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Rule Row

    @ViewBuilder
    private func ruleRow(_ rule: AutomationRule) -> some View {
        HStack(spacing: theme.spacingSM) {
            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(rule.name)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let description = rule.description {
                    Text(description)
                        .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: theme.spacingXS) {
                    triggerBadge(rule.triggerType)

                    Image(systemName: "arrow.right")
                        .font(.system(size: theme.fontCaption - 2, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    actionBadge(rule.actionType)

                    if !rule.conditions.isEmpty {
                        Text("·")
                            .foregroundStyle(theme.textTertiary)
                            .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))

                        Text("\(rule.conditions.count) condition\(rule.conditions.count == 1 ? "" : "s")")
                            .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in
                    Task {
                        do {
                            try await viewModel.toggleRule(rule.id)
                        } catch {
                            // Error handled by viewModel
                        }
                    }
                }
            ))
            .labelsHidden()
            .tint(theme.success)
            .controlSize(.small)
            .accessibilityLabel("\(rule.isEnabled ? "Disable" : "Enable") rule")
            .accessibilityHint("Toggles the rule's active state")
        }
        .padding(.vertical, theme.spacingXS)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                editingRule = rule
                showNewRuleSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                viewingHistoryForRule = rule.id
            } label: {
                Label("View History", systemImage: "clock")
            }

            Divider()

            Button(role: .destructive) {
                Task {
                    do {
                        try await viewModel.deleteRule(rule.id)
                    } catch {
                        // Error handled by viewModel
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Badge Helpers

    @ViewBuilder
    private func triggerBadge(_ trigger: RuleTriggerType) -> some View {
        Text(triggerDisplayName(trigger))
            .font(.system(size: theme.fontCaption - 2, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.textOnAccent)
            .padding(.horizontal, theme.spacingXS)
            .padding(.vertical, 2)
            .background(triggerColor(trigger))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    @ViewBuilder
    private func actionBadge(_ action: RuleActionType) -> some View {
        Text(actionDisplayName(action))
            .font(.system(size: theme.fontCaption - 2, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.textOnAccent)
            .padding(.horizontal, theme.spacingXS)
            .padding(.vertical, 2)
            .background(actionColor(action))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func triggerDisplayName(_ trigger: RuleTriggerType) -> String {
        switch trigger {
        case .sessionComplete: return "Complete"
        case .errorOccurred: return "Error"
        case .idleTimeout: return "Idle"
        case .costThreshold: return "Cost"
        case .contextNearLimit: return "Context"
        }
    }

    private func actionDisplayName(_ action: RuleActionType) -> String {
        switch action {
        case .notify: return "Notify"
        case .pause: return "Pause"
        case .fork: return "Fork"
        case .export: return "Export"
        case .sendMessage: return "Message"
        case .switchModel: return "Switch"
        }
    }

    private func triggerColor(_ trigger: RuleTriggerType) -> Color {
        switch trigger {
        case .sessionComplete: return theme.success
        case .errorOccurred: return theme.error
        case .idleTimeout: return theme.warning
        case .costThreshold: return Color.purple
        case .contextNearLimit: return Color.orange
        }
    }

    private func actionColor(_ action: RuleActionType) -> Color {
        switch action {
        case .notify: return theme.accent
        case .pause: return theme.warning
        case .fork: return Color.purple
        case .export: return theme.success
        case .sendMessage: return Color.blue
        case .switchModel: return Color.orange
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 36, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text(searchText.isEmpty ? "No Automation Rules" : "No Matching Rules")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text(searchText.isEmpty ?
                 "Create your first rule to automate session actions" :
                 "Try a different search term")
                .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            if searchText.isEmpty {
                Button {
                    showNewRuleSheet = true
                } label: {
                    Text("Create Rule")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingMD)
                        .padding(.vertical, theme.spacingSM)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingXL)
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: theme.spacingMD) {
            ProgressView()
                .controlSize(.small)
                .tint(theme.accent)

            Text("Loading rules…")
                .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingXL)
    }

    // MARK: - New Rule Button

    private var newRuleButton: some View {
        Button {
            editingRule = nil
            showNewRuleSheet = true
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)

                Text("New Rule")
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()
            }
            .padding(theme.spacingMD)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create new automation rule")
        .accessibilityHint("Opens the rule editor")
    }

    // MARK: - Filtered Rules

    private var filteredRules: [AutomationRule] {
        if searchText.isEmpty {
            return viewModel.rules
        }
        return viewModel.rules.filter { rule in
            rule.name.localizedCaseInsensitiveContains(searchText) ||
            rule.description?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
}

// MARK: - Error Wrapper

/// Wrapper to make Error conform to Identifiable for sheet presentation.
private struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: Error
}

// MARK: - Error Alert View

private struct ErrorAlertView: View {
    let error: Error
    let onDismiss: () -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.error)

            Text("Error")
                .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text(error.localizedDescription)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                onDismiss()
            } label: {
                Text("OK")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingXL)
        .background(theme.bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .padding(theme.spacingXL * 2)
    }
}

// MARK: - Helper Extension

private extension Binding where Value == Error? {
    func map<T>(_ transform: @escaping (Error) -> T) -> Binding<T?> {
        Binding<T?>(
            get: { self.wrappedValue.map(transform) },
            set: { newValue in
                if newValue == nil {
                    self.wrappedValue = nil
                }
            }
        )
    }
}

#Preview {
    MacAutomationRulesView()
        .environment(AppState())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
        .frame(width: 400, height: 600)
}
