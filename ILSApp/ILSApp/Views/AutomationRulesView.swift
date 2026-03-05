import SwiftUI
import ILSShared

/// View for managing automation rules.
///
/// Displays a list of automation rules with enable/disable toggles, rule metadata,
/// and navigation to create or edit rules. Rules are grouped by enabled/disabled status
/// for easier management. Pull-to-refresh reloads rules from the backend.
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
struct AutomationRulesView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// View model managing rule state and API operations.
    @State private var viewModel = AutomationRulesViewModel()
    /// Whether a pull-to-refresh reload is currently in flight.
    @State private var isRefreshing = false
    /// Controls presentation of the New Rule sheet.
    @State private var showNewRuleSheet = false
    /// Rule currently being edited (nil when creating a new rule).
    @State private var editingRule: AutomationRule? = nil
    /// Text entered in the rules search bar.
    @State private var searchText: String = ""
    /// Rule ID for which execution history is being viewed.
    @State private var viewingHistoryForRule: UUID? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                headerSection
                refreshingBanner
                connectionBanner

                if viewModel.isLoading && viewModel.rules.isEmpty {
                    loadingView
                } else if filteredRules.isEmpty {
                    emptyStateView
                } else {
                    enabledRulesSection
                    disabledRulesSection
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingMD)
            .animation(.easeInOut(duration: 0.3), value: isRefreshing)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Automation Rules")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewRuleSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                }
                .accessibilityLabel("Create new automation rule")
                .accessibilityHint("Opens the rule editor")
            }
        }
        .searchable(text: $searchText, prompt: "Search rules")
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadRules()
        }
        .refreshable {
            #if os(iOS)
            HapticManager.impact(.light)
            #endif
            isRefreshing = true
            await viewModel.loadRules()
            isRefreshing = false
        }
        .onChange(of: appState.serverURL) { _, _ in
            viewModel.configure(client: appState.apiClient)
            Task { await viewModel.loadRules() }
        }
        .sheet(isPresented: $showNewRuleSheet) {
            NavigationStack {
                RuleEditorView(editingRule: editingRule) {
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
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("Automation Rules")
                .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("Create IFTTT-style rules to automate session actions")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.top, theme.spacingSM)
    }

    // MARK: - Refreshing Banner

    @ViewBuilder
    private var refreshingBanner: some View {
        if isRefreshing {
            HStack(spacing: theme.spacingSM) {
                if !reduceMotion {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .tint(theme.textSecondary)
                }

                Text("Refreshing…")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgSecondary.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .transition(
                .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                )
            )
            .accessibilityLabel("Refreshing rules")
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    // MARK: - Connection Banner

    @ViewBuilder
    private var connectionBanner: some View {
        if !appState.isConnected {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Not Connected")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text("Configure your server to manage automation rules")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                Button {
                    appState.showOnboarding = true
                } label: {
                    Text("Setup")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, theme.spacingXS)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .accessibilityLabel("Setup server connection")
                .accessibilityHint("Opens the server configuration wizard")
            }
            .padding(theme.spacingMD)
            .background(theme.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.warning.opacity(0.3), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Enabled Rules Section

    @ViewBuilder
    private var enabledRulesSection: some View {
        let enabled = filteredRules.filter { $0.isEnabled }

        if !enabled.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    Text("Enabled")
                        .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text("\(enabled.count)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    Spacer()
                }

                ForEach(enabled) { rule in
                    ruleRow(rule)
                }
            }
        }
    }

    // MARK: - Disabled Rules Section

    @ViewBuilder
    private var disabledRulesSection: some View {
        let disabled = filteredRules.filter { !$0.isEnabled }

        if !disabled.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    Text("Disabled")
                        .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)

                    Text("\(disabled.count)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    Spacer()
                }

                ForEach(disabled) { rule in
                    ruleRow(rule)
                }
            }
        }
    }

    // MARK: - Rule Row

    @ViewBuilder
    private func ruleRow(_ rule: AutomationRule) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(rule.name)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    if let description = rule.description {
                        Text(description)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
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

                            Text("\(rule.conditions.count) condition\(rule.conditions.count == 1 ? "" : "s")")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
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
                                #if os(iOS)
                                HapticManager.notification(.success)
                                #endif
                            } catch {
                                #if os(iOS)
                                HapticManager.notification(.error)
                                #endif
                            }
                        }
                    }
                ))
                .labelsHidden()
                .tint(theme.success)
                .accessibilityLabel("\(rule.isEnabled ? "Disable" : "Enable") rule")
                .accessibilityHint("Toggles the rule's active state")
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
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
                        #if os(iOS)
                        HapticManager.notification(.success)
                        #endif
                    } catch {
                        #if os(iOS)
                        HapticManager.notification(.error)
                        #endif
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
            .font(.system(size: theme.fontCaption - 1, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.textOnAccent)
            .padding(.horizontal, theme.spacingXS)
            .padding(.vertical, 2)
            .background(triggerColor(trigger))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private func actionBadge(_ action: RuleActionType) -> some View {
        Text(actionDisplayName(action))
            .font(.system(size: theme.fontCaption - 1, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.textOnAccent)
            .padding(.horizontal, theme.spacingXS)
            .padding(.vertical, 2)
            .background(actionColor(action))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func triggerDisplayName(_ trigger: RuleTriggerType) -> String {
        switch trigger {
        case .sessionComplete: return "Session Complete"
        case .errorOccurred: return "Error Occurred"
        case .idleTimeout: return "Idle Timeout"
        case .costThreshold: return "Cost Threshold"
        case .contextNearLimit: return "Context Near Limit"
        }
    }

    private func actionDisplayName(_ action: RuleActionType) -> String {
        switch action {
        case .notify: return "Notify"
        case .pause: return "Pause"
        case .fork: return "Fork"
        case .export: return "Export"
        case .sendMessage: return "Send Message"
        case .switchModel: return "Switch Model"
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
    private var emptyStateView: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text(searchText.isEmpty ? "No Automation Rules" : "No Matching Rules")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text(searchText.isEmpty ?
                 "Create your first rule to automate session actions" :
                 "Try a different search term")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            if searchText.isEmpty {
                Button {
                    showNewRuleSheet = true
                } label: {
                    Text("Create Rule")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingMD)
                        .padding(.vertical, theme.spacingSM)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
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
                .progressViewStyle(.circular)
                .tint(theme.accent)

            Text("Loading rules…")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingXL)
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
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.error)

            Text("Error")
                .font(.system(size: 20, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text(error.localizedDescription)
                .font(.system(size: 14, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                onDismiss()
            } label: {
                Text("OK")
                    .font(.system(size: 16, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(theme.bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(40)
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
    NavigationStack {
        AutomationRulesView()
            .environment(AppState())
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
