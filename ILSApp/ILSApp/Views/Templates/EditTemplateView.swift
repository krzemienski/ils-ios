import SwiftUI
import ILSShared

// MARK: - EditTemplateView

/// Sheet for creating or editing a ``SessionTemplate``.
///
/// When initialised with `template: nil` the view operates in **create mode**
/// and calls ``TemplatesViewModel/createTemplate(request:)`` on save.
/// When initialised with a non-nil ``SessionTemplate`` the view operates in
/// **edit mode** and calls ``TemplatesViewModel/updateTemplate(id:request:)``
/// on save, pre-populating every field from the existing template.
///
/// The save button is disabled until the `name` field is non-empty.
/// Keyboard focus across the text inputs is managed via a `FocusedField` enum
/// and `@FocusState` so fields can be programmatically activated without extra taps.
///
/// ## Topics
/// ### Inputs
/// - ``template`` — Optional template to edit; `nil` triggers create mode
/// - ``viewModel`` — Shared view model for API calls and templates list updates
///
/// ### Fields
/// - ``name``
/// - ``description``
/// - ``selectedModel``
/// - ``permissionMode``
/// - ``systemPrompt``
/// - ``maxBudget``
/// - ``maxTurns``
///
/// ### Actions
/// - ``save()``
struct EditTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// The template to edit, or `nil` when creating a new template.
    let template: SessionTemplate?
    /// Shared view model; save actions update its `templates` array in-place.
    var viewModel: TemplatesViewModel

    // MARK: - Field State

    /// Template display name (required — save is disabled when empty).
    @State private var name: String
    /// Brief description of the template's purpose.
    @State private var description: String
    /// The Claude model identifier (e.g. "sonnet", "opus", "haiku").
    @State private var selectedModel: String
    /// Raw permission-mode string (e.g. "default", "acceptEdits").
    @State private var permissionMode: String
    /// Custom system prompt injected at the start of every session.
    @State private var systemPrompt: String
    /// Optional maximum budget in USD, stored as a free-form string and parsed on save.
    @State private var maxBudget: String
    /// Optional maximum turn count, stored as a free-form string and parsed on save.
    @State private var maxTurns: String

    // MARK: - Saving State

    /// `true` while the create/update API call is in flight.
    @State private var isSaving = false

    /// Identifies the text inputs that participate in `@FocusState` management.
    private enum FocusedField: Hashable {
        case name, description, systemPrompt, maxBudget, maxTurns
    }
    @FocusState private var focusedField: FocusedField?

    private let models: [String] = ["sonnet", "opus", "haiku"]
    private let permissionModes: [String] = [
        "default", "acceptEdits", "plan", "bypassPermissions"
    ]

    // MARK: - Init

    /// Creates the view in create or edit mode.
    /// - Parameters:
    ///   - template: The template to edit, or `nil` to create a new one.
    ///   - prefillName: Initial name used when `template` is `nil` (e.g. from a session name).
    ///   - prefillModel: Initial model used when `template` is `nil`.
    ///   - prefillPermissionMode: Initial permission mode used when `template` is `nil`.
    ///   - viewModel: The shared templates view model.
    init(
        template: SessionTemplate?,
        prefillName: String = "",
        prefillModel: String = "sonnet",
        prefillPermissionMode: String = "default",
        viewModel: TemplatesViewModel
    ) {
        self.template = template
        self.viewModel = viewModel
        _name = State(initialValue: template?.name ?? prefillName)
        _description = State(initialValue: template?.description ?? "")
        _selectedModel = State(initialValue: template?.model ?? prefillModel)
        _permissionMode = State(initialValue: template?.permissionMode ?? prefillPermissionMode)
        _systemPrompt = State(initialValue: template?.systemPrompt ?? "")
        if let budget = template?.maxBudgetUSD {
            _maxBudget = State(initialValue: String(format: "%.2f", budget))
        } else {
            _maxBudget = State(initialValue: "")
        }
        if let turns = template?.maxTurns {
            _maxTurns = State(initialValue: "\(turns)")
        } else {
            _maxTurns = State(initialValue: "")
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(theme.divider)

            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    nameSection
                    descriptionSection
                    modelSection
                    permissionsSection
                    systemPromptSection
                    limitsSection
                    saveButton
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle(template == nil ? "New Template" : "Edit Template")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    // MARK: - Name Section

    @ViewBuilder
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Name")

            TextField("Template name", text: $name)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .focused($focusedField, equals: .name)
                .padding(theme.spacingSM)
                .background(theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .focusRing(isFocused: focusedField == .name, cornerRadius: theme.cornerRadiusSmall)
                .accessibilityIdentifier("template-name-field")
        }
    }

    // MARK: - Description Section

    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Description")

            TextField("Brief description (optional)", text: $description)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .focused($focusedField, equals: .description)
                .padding(theme.spacingSM)
                .background(theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .focusRing(isFocused: focusedField == .description, cornerRadius: theme.cornerRadiusSmall)
                .accessibilityIdentifier("template-description-field")
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
                            .font(.system(
                                size: theme.fontCaption,
                                weight: selectedModel == model ? .semibold : .regular,
                                design: theme.fontDesign
                            ))
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
            .background(theme.bgTertiary)
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
            .background(theme.bgTertiary)
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
                    .focused($focusedField, equals: .systemPrompt)

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
            .focusRing(isFocused: focusedField == .systemPrompt, cornerRadius: theme.cornerRadiusSmall)
            .accessibilityIdentifier("template-system-prompt-field")
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
                TextField("e.g. 5.00", text: $maxBudget)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 100)
                    .focused($focusedField, equals: .maxBudget)
                    .accessibilityIdentifier("template-max-budget-field")
            }
            .padding(theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .focusRing(isFocused: focusedField == .maxBudget, cornerRadius: theme.cornerRadiusSmall)

            HStack {
                Text("Max Turns")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                TextField("No limit", text: $maxTurns)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 100)
                    .focused($focusedField, equals: .maxTurns)
                    .accessibilityIdentifier("template-max-turns-field")
            }
            .padding(theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .focusRing(isFocused: focusedField == .maxTurns, cornerRadius: theme.cornerRadiusSmall)
        }
    }

    // MARK: - Save Button

    /// Full-width primary action button that creates or updates the template.
    ///
    /// Disabled until the `name` field is non-empty. Shows a spinner while saving.
    @ViewBuilder
    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack(spacing: theme.spacingSM) {
                if isSaving {
                    ProgressView()
                        .tint(theme.textOnAccent)
                        .controlSize(.small)
                } else {
                    Image(systemName: template == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                }
                Text(isSaving ? "Saving..." : (template == nil ? "Create Template" : "Save Changes"))
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
            }
            .foregroundStyle(theme.textOnAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(canSave ? theme.accent : theme.accent.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
        .disabled(isSaving || !canSave)
        .opacity(isSaving ? 0.7 : 1.0)
        .padding(.top, theme.spacingSM)
        .accessibilityIdentifier("save-template-button")
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
        case "default":             return "Default"
        case "acceptEdits":         return "Accept Edits"
        case "plan":                return "Plan Mode"
        case "bypassPermissions":   return "Bypass All"
        default:                    return mode
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
        default:
            return ""
        }
    }

    // MARK: - Actions

    private func save() {
        guard canSave else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let budgetValue = Double(maxBudget.trimmingCharacters(in: .whitespacesAndNewlines))
        let turnsValue = Int(maxTurns.trimmingCharacters(in: .whitespacesAndNewlines))
        let mode = PermissionMode(rawValue: permissionMode) ?? .default

        isSaving = true
        Task {
            if let existing = template {
                let request = UpdateTemplateRequest(
                    name: trimmedName,
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    model: selectedModel,
                    permissionMode: mode,
                    systemPrompt: trimmedPrompt.isEmpty ? nil : trimmedPrompt,
                    maxBudgetUSD: budgetValue,
                    maxTurns: turnsValue
                )
                _ = await viewModel.updateTemplate(id: existing.id, request: request)
            } else {
                let request = CreateTemplateRequest(
                    name: trimmedName,
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    model: selectedModel,
                    permissionMode: mode,
                    systemPrompt: trimmedPrompt.isEmpty ? nil : trimmedPrompt,
                    maxBudgetUSD: budgetValue,
                    maxTurns: turnsValue
                )
                _ = await viewModel.createTemplate(request: request)
            }
            isSaving = false
            dismiss()
        }
    }
}
