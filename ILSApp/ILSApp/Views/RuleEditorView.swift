import SwiftUI
import ILSShared

/// Visual rule editor for creating and editing automation rules.
///
/// Provides a step-by-step builder interface following the trigger → condition → action pattern.
/// Users can select trigger types, configure conditions, and define actions with their parameters.
///
/// ## Topics
/// ### Sections
/// - ``basicInfoSection`` - Rule name and description
/// - ``triggerSection`` - Trigger type selection
/// - ``conditionsSection`` - Optional condition builder
/// - ``actionSection`` - Action type and configuration
///
/// ### Actions
/// - ``saveRule()`` - Validate and save the rule
/// - ``validateRule()`` - Check if the rule configuration is valid
struct RuleEditorView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// View model managing rule operations.
    @State private var viewModel = AutomationRulesViewModel()

    /// Rule being edited (nil for new rules).
    let editingRule: AutomationRule?
    /// Callback invoked when the rule is successfully saved.
    let onSaved: () -> Void

    // Form state
    @State private var ruleName = ""
    @State private var ruleDescription = ""
    @State private var selectedTrigger: RuleTriggerType = .sessionComplete
    @State private var conditions: [RuleCondition] = []
    @State private var selectedAction: RuleActionType = .notify
    @State private var isEnabled = true

    // Action config
    @State private var notificationMessage = ""
    @State private var exportFormat = "markdown"
    @State private var targetModel = "sonnet"
    @State private var messageContent = ""

    // Condition builder
    @State private var showAddCondition = false
    @State private var conditionField = ""
    @State private var conditionOperator: ConditionOperator = .greaterThan
    @State private var conditionValue = ""

    // UI state
    @State private var isSaving = false
    @State private var validationError: String?
    @State private var showTemplates = true
    @State private var selectedTemplate: RuleTemplate?

    private enum FocusedField: Hashable {
        case ruleName, ruleDescription
        case notificationMessage, messageContent
        case conditionField, conditionValue
    }
    @FocusState private var focusedField: FocusedField?

    init(editingRule: AutomationRule? = nil, onSaved: @escaping () -> Void) {
        self.editingRule = editingRule
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider().overlay(theme.divider)

            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    if editingRule == nil && showTemplates {
                        templatesSection
                    }

                    basicInfoSection
                    triggerSection
                    conditionsSection
                    actionSection

                    if let error = validationError {
                        errorBanner(error)
                    }

                    actionButtons
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle(editingRule == nil ? "New Rule" : "Edit Rule")
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
            viewModel.configure(client: appState.apiClient)
            populateFromEditingRule()
            if editingRule == nil {
                await viewModel.loadTemplates()
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(editingRule == nil ? "Create Automation Rule" : "Edit Rule")
                .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("Build IFTTT-style rules with trigger → condition → action")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, theme.spacingMD)
        .padding(.top, theme.spacingMD)
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - Basic Info Section

    @ViewBuilder
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                sectionLabel("Quick Start Templates")
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTemplates = false
                    }
                } label: {
                    Text("Start from Scratch")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }

            Text("Choose a pre-built template to get started quickly")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            if viewModel.isLoadingTemplates {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(theme.accent)
                    Spacer()
                }
                .padding(.vertical, theme.spacingMD)
            } else if viewModel.templates.isEmpty {
                emptyTemplatesView
            } else {
                VStack(spacing: theme.spacingXS) {
                    ForEach(viewModel.templates) { template in
                        templateCard(template)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyTemplatesView: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "doc.text")
                .foregroundStyle(theme.textTertiary)
            Text("No templates available")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(theme.spacingMD)
        .background(theme.bgSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    @ViewBuilder
    private func templateCard(_ template: RuleTemplate) -> some View {
        let isSelected = selectedTemplate?.id == template.id
        Button {
            applyTemplate(template)
        } label: {
            VStack(alignment: .leading, spacing: theme.spacingXS) {
                HStack(alignment: .top, spacing: theme.spacingSM) {
                    Image(systemName: templateIcon(template))
                        .font(.system(size: theme.fontTitle3, design: theme.fontDesign))
                        .foregroundStyle(templateColor(template))
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)

                        Text(template.description)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)

                        HStack(spacing: theme.spacingXS) {
                            templateBadge(
                                icon: triggerIcon(template.triggerType),
                                text: triggerDisplayName(template.triggerType),
                                color: triggerColor(template.triggerType)
                            )
                            Image(systemName: "arrow.right")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                            templateBadge(
                                icon: actionIcon(template.actionType),
                                text: actionDisplayName(template.actionType),
                                color: actionColor(template.actionType)
                            )
                        }
                        .padding(.top, 4)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.success)
                            .font(.system(size: theme.fontTitle3))
                    }
                }
            }
            .padding(theme.spacingSM)
            .background(isSelected ? theme.success.opacity(0.08) : theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(isSelected ? theme.success.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(template.name). \(template.description)")
    }

    @ViewBuilder
    private func templateBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            Text(text)
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Basic Info Section

    @ViewBuilder
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Basic Information")

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                TextField("Rule Name", text: $ruleName)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .padding(theme.spacingSM)
                    .background(theme.bgSecondary)
                    .foregroundStyle(theme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    .focusRing(isFocused: focusedField == .ruleName, cornerRadius: theme.cornerRadiusSmall)
                    .focused($focusedField, equals: .ruleName)
                    .accessibilityIdentifier("rule-name-field")

                if ruleName.isEmpty {
                    Text("Give your rule a descriptive name")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $ruleDescription)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 60)
                        .focused($focusedField, equals: .ruleDescription)

                    if ruleDescription.isEmpty {
                        Text("Description (optional)")
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
                .focusRing(isFocused: focusedField == .ruleDescription, cornerRadius: theme.cornerRadiusSmall)
            }
        }
    }

    // MARK: - Trigger Section

    @ViewBuilder
    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Trigger")

            Text("When should this rule activate?")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: theme.spacingXS) {
                ForEach(RuleTriggerType.allCases, id: \.self) { trigger in
                    triggerOption(trigger)
                }
            }
        }
    }

    @ViewBuilder
    private func triggerOption(_ trigger: RuleTriggerType) -> some View {
        let isSelected = selectedTrigger == trigger
        Button {
            selectedTrigger = trigger
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: triggerIcon(trigger))
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(triggerColor(trigger))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(triggerDisplayName(trigger))
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text(triggerDescription(trigger))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(theme.spacingSM)
            .background(isSelected ? theme.accent.opacity(0.08) : theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(triggerDisplayName(trigger)). \(triggerDescription(trigger))")
    }

    // MARK: - Conditions Section

    @ViewBuilder
    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                sectionLabel("Conditions")
                Spacer()
                Text("Optional")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            Text("Add conditions to refine when this rule triggers")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            if conditions.isEmpty {
                emptyConditionsView
            } else {
                ForEach(Array(conditions.enumerated()), id: \.offset) { index, condition in
                    conditionRow(condition, at: index)
                }
            }

            if showAddCondition {
                addConditionForm
            } else {
                Button {
                    showAddCondition = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(theme.accent)
                        Text("Add Condition")
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var emptyConditionsView: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(theme.textTertiary)
            Text("No conditions - rule will trigger for all events")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacingSM)
        .background(theme.bgSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    @ViewBuilder
    private func conditionRow(_ condition: RuleCondition, at index: Int) -> some View {
        HStack(spacing: theme.spacingSM) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingXS) {
                    Text(condition.field)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text(operatorDisplayName(condition.operator))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    Text(condition.value)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                }
            }

            Spacer()

            Button {
                conditions.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingSM)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    @ViewBuilder
    private var addConditionForm: some View {
        VStack(spacing: theme.spacingSM) {
            TextField("Field (e.g., error_count, cost_usd)", text: $conditionField)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .padding(theme.spacingSM)
                .background(theme.bgTertiary)
                .foregroundStyle(theme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .focused($focusedField, equals: .conditionField)

            Picker("Operator", selection: $conditionOperator) {
                ForEach(ConditionOperator.allCases, id: \.self) { op in
                    Text(operatorDisplayName(op)).tag(op)
                }
            }
            .tint(theme.accent)
            .padding(theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            TextField("Value", text: $conditionValue)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .padding(theme.spacingSM)
                .background(theme.bgTertiary)
                .foregroundStyle(theme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .focused($focusedField, equals: .conditionValue)

            HStack(spacing: theme.spacingSM) {
                Button {
                    showAddCondition = false
                    conditionField = ""
                    conditionValue = ""
                } label: {
                    Text("Cancel")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                        .background(theme.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)

                Button {
                    addCondition()
                } label: {
                    Text("Add")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                        .background(canAddCondition ? theme.accent : theme.accent.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .disabled(!canAddCondition)
            }
        }
        .padding(theme.spacingSM)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - Action Section

    @ViewBuilder
    private var actionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Action")

            Text("What should happen when the rule triggers?")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: theme.spacingXS) {
                ForEach(RuleActionType.allCases, id: \.self) { action in
                    actionOption(action)
                }
            }

            actionConfigSection
        }
    }

    @ViewBuilder
    private func actionOption(_ action: RuleActionType) -> some View {
        let isSelected = selectedAction == action
        Button {
            selectedAction = action
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: actionIcon(action))
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(actionColor(action))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(actionDisplayName(action))
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text(actionDescription(action))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(theme.spacingSM)
            .background(isSelected ? theme.accent.opacity(0.08) : theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(actionDisplayName(action)). \(actionDescription(action))")
    }

    @ViewBuilder
    private var actionConfigSection: some View {
        switch selectedAction {
        case .notify:
            notifyConfigView
        case .export:
            exportConfigView
        case .switchModel:
            switchModelConfigView
        case .sendMessage:
            sendMessageConfigView
        case .pause, .fork:
            EmptyView()
        }
    }

    @ViewBuilder
    private var notifyConfigView: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("Notification Message")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            TextField("Enter notification message (optional)", text: $notificationMessage)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .padding(theme.spacingSM)
                .background(theme.bgTertiary)
                .foregroundStyle(theme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .focused($focusedField, equals: .notificationMessage)
        }
        .padding(.top, theme.spacingSM)
    }

    @ViewBuilder
    private var exportConfigView: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("Export Format")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Picker("Format", selection: $exportFormat) {
                Text("Markdown").tag("markdown")
                Text("JSON").tag("json")
                Text("HTML").tag("html")
            }
            .tint(theme.accent)
            .padding(theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .padding(.top, theme.spacingSM)
    }

    @ViewBuilder
    private var switchModelConfigView: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("Target Model")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Picker("Model", selection: $targetModel) {
                Text("Sonnet").tag("sonnet")
                Text("Opus").tag("opus")
                Text("Haiku").tag("haiku")
            }
            .tint(theme.accent)
            .padding(theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .padding(.top, theme.spacingSM)
    }

    @ViewBuilder
    private var sendMessageConfigView: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("Message Content")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            TextField("Enter message to send", text: $messageContent)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .padding(theme.spacingSM)
                .background(theme.bgTertiary)
                .foregroundStyle(theme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .focused($focusedField, equals: .messageContent)
        }
        .padding(.top, theme.spacingSM)
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.error)
            Text(message)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacingSM)
        .background(theme.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(theme.error.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: theme.spacingSM) {
            Toggle(isOn: $isEnabled) {
                Text("Enable Rule")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
            }
            .tint(theme.success)

            Spacer()
        }
        .padding(.top, theme.spacingSM)

        Button {
            saveRule()
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(theme.textOnAccent)
                        .scaleEffect(0.8)
                }
                Text(editingRule == nil ? "Create Rule" : "Save Changes")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(canSaveRule ? theme.accent : theme.accent.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
        .buttonStyle(.plain)
        .disabled(!canSaveRule || isSaving)
        .accessibilityIdentifier("save-rule-button")
    }

    // MARK: - Validation

    private var canAddCondition: Bool {
        !conditionField.isEmpty && !conditionValue.isEmpty
    }

    private var canSaveRule: Bool {
        !ruleName.isEmpty
    }

    private func validateRule() -> String? {
        if ruleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Rule name is required"
        }
        return nil
    }

    // MARK: - Actions

    private func addCondition() {
        guard !conditionField.isEmpty, !conditionValue.isEmpty else { return }

        let condition = RuleCondition(
            field: conditionField,
            operator: conditionOperator,
            value: conditionValue
        )
        conditions.append(condition)

        // Reset form
        conditionField = ""
        conditionValue = ""
        showAddCondition = false
    }

    private func saveRule() {
        validationError = validateRule()
        guard validationError == nil else { return }

        isSaving = true

        Task {
            do {
                let actionConfig = buildActionConfig()

                if let rule = editingRule {
                    // Update existing rule
                    let request = UpdateAutomationRuleRequest(
                        name: ruleName,
                        description: ruleDescription.isEmpty ? nil : ruleDescription,
                        triggerType: selectedTrigger,
                        conditions: conditions,
                        actionType: selectedAction,
                        actionConfig: actionConfig,
                        isEnabled: isEnabled
                    )
                    try await viewModel.updateRule(rule.id, request: request)
                } else {
                    // Create new rule
                    let request = CreateAutomationRuleRequest(
                        name: ruleName,
                        description: ruleDescription.isEmpty ? nil : ruleDescription,
                        triggerType: selectedTrigger,
                        conditions: conditions,
                        actionType: selectedAction,
                        actionConfig: actionConfig,
                        isEnabled: isEnabled
                    )
                    try await viewModel.createRule(request)
                }

                #if os(iOS)
                HapticManager.success()
                #endif

                onSaved()
                dismiss()
            } catch {
                validationError = error.localizedDescription
                #if os(iOS)
                HapticManager.error()
                #endif
            }

            isSaving = false
        }
    }

    private func buildActionConfig() -> RuleActionConfig {
        RuleActionConfig(
            notificationMessage: notificationMessage.isEmpty ? nil : notificationMessage,
            exportFormat: exportFormat,
            targetModel: targetModel,
            messageContent: messageContent.isEmpty ? nil : messageContent
        )
    }

    private func populateFromEditingRule() {
        guard let rule = editingRule else { return }

        ruleName = rule.name
        ruleDescription = rule.description ?? ""
        selectedTrigger = rule.triggerType
        conditions = rule.conditions
        selectedAction = rule.actionType
        isEnabled = rule.isEnabled

        // Populate action config
        notificationMessage = rule.actionConfig.notificationMessage ?? ""
        exportFormat = rule.actionConfig.exportFormat ?? "markdown"
        targetModel = rule.actionConfig.targetModel ?? "sonnet"
        messageContent = rule.actionConfig.messageContent ?? ""
    }

    private func applyTemplate(_ template: RuleTemplate) {
        selectedTemplate = template

        // Pre-fill form with template data
        ruleName = template.name
        ruleDescription = template.description
        selectedTrigger = template.triggerType
        conditions = template.conditions
        selectedAction = template.actionType

        // Populate action config from template
        notificationMessage = template.actionConfig.notificationMessage ?? ""
        exportFormat = template.actionConfig.exportFormat ?? "markdown"
        targetModel = template.actionConfig.targetModel ?? "sonnet"
        messageContent = template.actionConfig.messageContent ?? ""

        // Scroll to top to show the filled form
        withAnimation(.easeInOut(duration: 0.3)) {
            showTemplates = false
        }

        #if os(iOS)
        HapticManager.light()
        #endif
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

    // MARK: - Display Names & Descriptions

    private func triggerDisplayName(_ trigger: RuleTriggerType) -> String {
        switch trigger {
        case .sessionComplete: return "Session Complete"
        case .errorOccurred: return "Error Occurred"
        case .idleTimeout: return "Idle Timeout"
        case .costThreshold: return "Cost Threshold"
        case .contextNearLimit: return "Context Near Limit"
        }
    }

    private func triggerDescription(_ trigger: RuleTriggerType) -> String {
        switch trigger {
        case .sessionComplete: return "When a session finishes successfully"
        case .errorOccurred: return "When an error occurs in a session"
        case .idleTimeout: return "When a session has been idle for too long"
        case .costThreshold: return "When session cost exceeds a threshold"
        case .contextNearLimit: return "When context usage nears the limit"
        }
    }

    private func triggerIcon(_ trigger: RuleTriggerType) -> String {
        switch trigger {
        case .sessionComplete: return "checkmark.circle.fill"
        case .errorOccurred: return "exclamationmark.triangle.fill"
        case .idleTimeout: return "clock.fill"
        case .costThreshold: return "dollarsign.circle.fill"
        case .contextNearLimit: return "gauge.high"
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

    private func actionDescription(_ action: RuleActionType) -> String {
        switch action {
        case .notify: return "Send a notification to the user"
        case .pause: return "Pause the session"
        case .fork: return "Fork the session into a new session"
        case .export: return "Export the session to a file"
        case .sendMessage: return "Send an automated message"
        case .switchModel: return "Switch to a different Claude model"
        }
    }

    private func actionIcon(_ action: RuleActionType) -> String {
        switch action {
        case .notify: return "bell.fill"
        case .pause: return "pause.circle.fill"
        case .fork: return "arrow.triangle.branch"
        case .export: return "square.and.arrow.up.fill"
        case .sendMessage: return "message.fill"
        case .switchModel: return "arrow.left.arrow.right.circle.fill"
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

    private func operatorDisplayName(_ op: ConditionOperator) -> String {
        switch op {
        case .greaterThan: return ">"
        case .lessThan: return "<"
        case .equals: return "="
        case .contains: return "contains"
        }
    }

    private func templateIcon(_ template: RuleTemplate) -> String {
        // Use action icon for template card
        actionIcon(template.actionType)
    }

    private func templateColor(_ template: RuleTemplate) -> Color {
        // Use action color for template card
        actionColor(template.actionType)
    }
}

#Preview {
    NavigationStack {
        RuleEditorView(onSaved: {})
            .environment(AppState())
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
