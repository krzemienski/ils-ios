import SwiftUI
import ILSShared

struct EditTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TemplatesViewModel()
    @State private var templateName = ""
    @State private var description = ""
    @State private var initialPrompt = ""
    @State private var selectedModel = "sonnet"
    @State private var permissionMode: PermissionMode = .default
    @State private var tagsInput = ""
    @State private var isFavorite = false
    @State private var isUpdating = false

    let template: SessionTemplate
    let onUpdated: (SessionTemplate) -> Void

    private let models = ["sonnet", "opus", "haiku"]

    init(template: SessionTemplate, onUpdated: @escaping (SessionTemplate) -> Void) {
        self.template = template
        self.onUpdated = onUpdated

        // Initialize state with template values
        _templateName = State(initialValue: template.name)
        _description = State(initialValue: template.description ?? "")
        _initialPrompt = State(initialValue: template.initialPrompt ?? "")
        _selectedModel = State(initialValue: template.model)
        _permissionMode = State(initialValue: template.permissionMode)
        _tagsInput = State(initialValue: template.tags.joined(separator: ", "))
        _isFavorite = State(initialValue: template.isFavorite)
    }

    var body: some View {
        NavigationStack {
            Form {
                if template.isDefault {
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(ILSTheme.accent)
                            Text("Default templates cannot be edited")
                                .font(ILSTheme.bodyFont)
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }
                }

                Section("Template Details") {
                    TextField("Template Name", text: $templateName)
                        .accessibilityIdentifier("template-name-field")
                        .disabled(template.isDefault)

                    TextField("Description (optional)", text: $description)
                        .accessibilityIdentifier("template-description-field")
                        .disabled(template.isDefault)
                }

                Section("Initial Prompt") {
                    TextEditor(text: $initialPrompt)
                        .frame(minHeight: 100)
                        .accessibilityIdentifier("template-initial-prompt-field")
                        .disabled(template.isDefault)
                }
                .help("The default prompt that will be used when creating a session from this template")

                Section("Model") {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(models, id: \.self) { model in
                            Text(model.capitalized).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("template-model-picker")
                    .disabled(template.isDefault)
                }

                Section("Permissions") {
                    Picker("Permission Mode", selection: $permissionMode) {
                        Text("Default").tag(PermissionMode.default)
                        Text("Accept Edits").tag(PermissionMode.acceptEdits)
                        Text("Plan Mode").tag(PermissionMode.plan)
                        Text("Bypass All").tag(PermissionMode.bypassPermissions)
                    }
                    .accessibilityIdentifier("template-permission-picker")
                    .disabled(template.isDefault)
                }

                Section {
                    Text(permissionDescription)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }

                Section("Tags") {
                    TextField("Tags (comma-separated)", text: $tagsInput)
                        .accessibilityIdentifier("template-tags-field")
                        .disabled(template.isDefault)

                    if !parsedTags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(parsedTags, id: \.self) { tag in
                                Text(tag)
                                    .font(ILSTheme.captionFont)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(ILSTheme.accent.opacity(0.1))
                                    .foregroundColor(ILSTheme.accent)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .help("Add tags to help organize and search for this template")

                Section {
                    Toggle("Mark as Favorite", isOn: $isFavorite)
                        .accessibilityIdentifier("template-favorite-toggle")
                        .disabled(template.isDefault)
                }
            }
            .navigationTitle("Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel-edit-template-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateTemplate()
                    }
                    .disabled(isUpdating || templateName.isEmpty || template.isDefault)
                    .accessibilityIdentifier("save-template-button")
                }
            }
        }
    }

    private var parsedTags: [String] {
        tagsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var permissionDescription: String {
        switch permissionMode {
        case .default:
            return "Standard permission behavior - Claude will ask before executing tools."
        case .acceptEdits:
            return "Automatically approve file edits without prompting."
        case .plan:
            return "Planning mode - Claude will plan but not execute changes."
        case .bypassPermissions:
            return "Skip all permission checks. Use with caution."
        }
    }

    private func updateTemplate() {
        isUpdating = true

        Task {
            let updated = await viewModel.updateTemplate(
                template,
                name: templateName,
                description: description.isEmpty ? nil : description,
                initialPrompt: initialPrompt.isEmpty ? nil : initialPrompt,
                model: selectedModel,
                permissionMode: permissionMode,
                tags: parsedTags.isEmpty ? nil : parsedTags,
                isFavorite: isFavorite
            )

            await MainActor.run {
                isUpdating = false
                if let updated = updated {
                    onUpdated(updated)
                    dismiss()
                } else if let error = viewModel.error {
                    print("Failed to update template: \(error)")
                }
            }
        }
    }
}

#Preview {
    EditTemplateView(
        template: SessionTemplate(
            name: "Sample Template",
            description: "A sample template for preview",
            initialPrompt: "Sample prompt",
            model: "sonnet",
            permissionMode: .default,
            isFavorite: false,
            isDefault: false,
            tags: ["ios", "swift"]
        ),
        onUpdated: { _ in }
    )
}
