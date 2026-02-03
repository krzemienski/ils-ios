import SwiftUI
import ILSShared

struct NewTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TemplatesViewModel()
    @State private var templateName = ""
    @State private var description = ""
    @State private var initialPrompt = ""
    @State private var selectedModel = "sonnet"
    @State private var permissionMode: PermissionMode = .default
    @State private var tagsInput = ""
    @State private var isFavorite = false
    @State private var isCreating = false

    let onCreated: (SessionTemplate) -> Void

    private let models = ["sonnet", "opus", "haiku"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Details") {
                    TextField("Template Name", text: $templateName)
                        .accessibilityIdentifier("template-name-field")

                    TextField("Description (optional)", text: $description)
                        .accessibilityIdentifier("template-description-field")
                }

                Section("Initial Prompt") {
                    TextEditor(text: $initialPrompt)
                        .frame(minHeight: 100)
                        .accessibilityIdentifier("template-initial-prompt-field")
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
                }

                Section("Permissions") {
                    Picker("Permission Mode", selection: $permissionMode) {
                        Text("Default").tag(PermissionMode.default)
                        Text("Accept Edits").tag(PermissionMode.acceptEdits)
                        Text("Plan Mode").tag(PermissionMode.plan)
                        Text("Bypass All").tag(PermissionMode.bypassPermissions)
                    }
                    .accessibilityIdentifier("template-permission-picker")
                }

                Section {
                    Text(permissionDescription)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }

                Section("Tags") {
                    TextField("Tags (comma-separated)", text: $tagsInput)
                        .accessibilityIdentifier("template-tags-field")

                    if !parsedTags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(parsedTags, id: \.self) { tag in
                                Text(tag)
                                    .font(ILSTheme.captionFont)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(ILSTheme.accentColor.opacity(0.1))
                                    .foregroundColor(ILSTheme.accentColor)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .help("Add tags to help organize and search for this template")

                Section {
                    Toggle("Mark as Favorite", isOn: $isFavorite)
                        .accessibilityIdentifier("template-favorite-toggle")
                }
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel-new-template-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTemplate()
                    }
                    .disabled(isCreating || templateName.isEmpty)
                    .accessibilityIdentifier("create-template-button")
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

    private func createTemplate() {
        isCreating = true

        Task {
            let template = await viewModel.createTemplate(
                name: templateName,
                description: description.isEmpty ? nil : description,
                initialPrompt: initialPrompt.isEmpty ? nil : initialPrompt,
                model: selectedModel,
                permissionMode: permissionMode,
                tags: parsedTags.isEmpty ? nil : parsedTags
            )

            await MainActor.run {
                isCreating = false
                if let template = template {
                    // Update favorite status if needed
                    if isFavorite && !template.isFavorite {
                        Task {
                            await viewModel.toggleFavorite(template)
                            if let updated = viewModel.templates.first(where: { $0.id == template.id }) {
                                onCreated(updated)
                            } else {
                                onCreated(template)
                            }
                            dismiss()
                        }
                    } else {
                        onCreated(template)
                        dismiss()
                    }
                } else if let error = viewModel.error {
                    print("Failed to create template: \(error)")
                }
            }
        }
    }
}

// MARK: - FlowLayout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)

        let height = rows.reduce(0) { $0 + $1.maxHeight } + CGFloat(max(0, rows.count - 1)) * spacing
        let width = proposal.width ?? 0

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)

        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.subviewIndices {
                let subview = subviews[index]
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.maxHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && !currentRow.subviewIndices.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
                x = 0
            }

            currentRow.subviewIndices.append(index)
            currentRow.maxHeight = max(currentRow.maxHeight, size.height)
            x += size.width + spacing
        }

        if !currentRow.subviewIndices.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    private struct Row {
        var subviewIndices: [Int] = []
        var maxHeight: CGFloat = 0
    }
}

#Preview {
    NewTemplateView { _ in }
}
