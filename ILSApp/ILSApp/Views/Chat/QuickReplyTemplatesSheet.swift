import SwiftUI

/// Full-screen sheet for browsing, searching, creating, and editing quick reply templates.
///
/// Presents the complete template library with a category filter bar, keyword search,
/// and a scrollable template list. Tapping a template invokes ``onSelect`` and dismisses
/// the sheet. Swipe actions allow pinning, editing, and deleting custom templates.
/// A "+" toolbar button opens ``QuickReplyTemplateEditSheet`` for creating new templates.
///
/// ## Topics
/// ### State
/// - ``selectedCategory`` - Currently active category filter; `nil` shows all templates
/// - ``searchText`` - Live search query filtering template names and content
/// - ``debouncedTemplates`` - Debounced, filtered, sorted template list fed to the list
/// - ``editingTemplate`` - Template currently open in the edit sheet; `nil` means create-new
/// - ``showingEditSheet`` - Controls presentation of the create/edit modal
///
/// ### Callbacks
/// - ``onSelect`` - Receives the chosen template; caller inserts its content into the input
///
/// ### Sub-Views
/// - ``CategoryFilterBar`` - Horizontal chip bar for category filtering
/// - ``QuickReplyTemplateRow`` - Styled list row for a single template
/// - ``QuickReplyTemplateEditSheet`` - Modal form for creating or editing a template
struct QuickReplyTemplatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Called with the chosen template when the user taps a row.
    let onSelect: (QuickReplyTemplate) -> Void

    // MARK: - State

    @State private var selectedCategory: QuickReplyCategory? = nil
    @State private var searchText = ""
    @State private var debouncedTemplates: [QuickReplyTemplate] = []
    @State private var editingTemplate: QuickReplyTemplate? = nil
    @State private var showingEditSheet = false
    @State private var templateToDelete: QuickReplyTemplate? = nil
    @State private var showingDeleteConfirmation = false

    private var manager: QuickReplyTemplateManager { QuickReplyTemplateManager.shared }

    // MARK: - Body

    var body: some View {
        List {
            // Category filter chips
            Section {
                CategoryFilterBar(
                    selected: $selectedCategory,
                    theme: theme
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
            }

            // Template rows
            if debouncedTemplates.isEmpty {
                emptyStateView
            } else {
                ForEach(debouncedTemplates) { template in
                    QuickReplyTemplateRow(template: template, theme: theme) {
                        selectTemplate(template)
                    } onPin: {
                        Task { await manager.togglePin(id: template.id) }
                    } onEdit: {
                        editingTemplate = template
                        showingEditSheet = true
                    } onDelete: {
                        if !template.isBuiltIn {
                            templateToDelete = template
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
        .searchable(text: $searchText, prompt: "Search templates...")
        .navigationTitle("Quick Replies")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingTemplate = nil
                    showingEditSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create template")
            }
        }
        #if os(iOS)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(theme.bgPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                QuickReplyTemplateEditSheet(
                    template: editingTemplate,
                    onSave: { saved in
                        Task {
                            if editingTemplate != nil {
                                await manager.updateTemplate(saved)
                            } else {
                                await manager.addTemplate(saved)
                            }
                        }
                    }
                )
            }
            .preferredColorScheme(.dark)
        }
        .confirmationDialog(
            "Delete Template",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let t = templateToDelete {
                    Task { await manager.deleteTemplate(id: t.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let t = templateToDelete {
                Text("Delete \"\(t.name)\"? This cannot be undone.")
            }
        }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            updateDebounced()
        }
        .onChange(of: selectedCategory) { _, _ in
            updateDebounced()
        }
        .onChange(of: manager.customTemplates.count) { _, _ in
            updateDebounced()
        }
        .onAppear {
            updateDebounced()
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    private var emptyStateView: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text(searchText.isEmpty ? "No templates in this category" : "No templates match \"\(searchText)\"")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingXL)
        .listRowBackground(Color.clear)
    }

    private func selectTemplate(_ template: QuickReplyTemplate) {
        manager.recordUsage(id: template.id)
        onSelect(template)
        dismiss()
    }

    private func updateDebounced() {
        let source = manager.templates(for: selectedCategory)
        if searchText.isEmpty {
            debouncedTemplates = source.sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
                if lhs.isBuiltIn != rhs.isBuiltIn { return lhs.isBuiltIn }
                return lhs.name < rhs.name
            }
        } else {
            let query = searchText.lowercased()
            debouncedTemplates = source.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                || $0.content.localizedCaseInsensitiveContains(query)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            }.sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
                return lhs.name < rhs.name
            }
        }
    }
}

// MARK: - Category Filter Bar

/// Horizontal chip bar letting the user narrow templates to a specific ``QuickReplyCategory``.
///
/// An "All" chip is always shown first; tapping a selected category chip deselects it
/// (returns to "All"). The bar scrolls horizontally when all categories exceed screen width.
private struct CategoryFilterBar: View {
    @Binding var selected: QuickReplyCategory?
    let theme: ThemeSnapshot

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingSM) {
                CategoryChip(
                    label: "All",
                    icon: "square.grid.2x2",
                    isSelected: selected == nil,
                    theme: theme
                ) {
                    selected = nil
                }

                ForEach(QuickReplyCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        label: category.displayName,
                        icon: category.systemImage,
                        isSelected: selected == category,
                        theme: theme
                    ) {
                        selected = (selected == category) ? nil : category
                    }
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .accessibilityIdentifier("quick-reply-category-filter")
    }
}

private struct CategoryChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let theme: ThemeSnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: theme.fontCaption, weight: .medium))
                Text(label)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
            }
            .foregroundStyle(isSelected ? theme.bgPrimary : theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : theme.bgTertiary)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isSelected ? Color.clear : theme.borderSubtle,
                                lineWidth: 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Template Row

/// Styled list row for a single `QuickReplyTemplate`.
///
/// Shows the template name, category badge, pin indicator, and variable count.
/// Swipe-leading action pins/unpins; swipe-trailing actions edit and delete.
/// Built-in templates do not offer a delete action.
private struct QuickReplyTemplateRow: View {
    let template: QuickReplyTemplate
    let theme: ThemeSnapshot
    let onTap: () -> Void
    let onPin: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: theme.spacingSM) {
                // Category icon
                Image(systemName: template.category.systemImage)
                    .font(.system(size: theme.fontBody))
                    .foregroundStyle(theme.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(template.name)
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        if template.isFavorite {
                            Image(systemName: "pin.fill")
                                // ACC-007: Use theme caption size for Dynamic Type compliance
                                .font(.system(size: theme.fontCaption))
                                .foregroundStyle(theme.accent)
                        }
                        if template.hasVariables {
                            Image(systemName: "curlybraces")
                                // ACC-007: Use theme caption size for Dynamic Type compliance
                                .font(.system(size: theme.fontCaption))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    Text(template.content)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if template.usageStats.useCount > 0 {
                    Text("\(template.usageStats.useCount)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
        .accessibilityLabel(template.name)
        .accessibilityHint("Insert template into chat input")
        .accessibilityIdentifier("quick-reply-row-\(template.id.uuidString.lowercased())")
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onPin) {
                Label(
                    template.isFavorite ? "Unpin" : "Pin",
                    systemImage: template.isFavorite ? "pin.slash" : "pin"
                )
            }
            .tint(theme.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !template.isBuiltIn {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(theme.accent)
            }
        }
        .contextMenu {
            Button(action: onPin) {
                Label(
                    template.isFavorite ? "Unpin" : "Pin",
                    systemImage: template.isFavorite ? "pin.slash" : "pin"
                )
            }
            if !template.isBuiltIn {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Edit Sheet

/// Modal form for creating a new template or editing an existing custom template.
///
/// When `template` is `nil` the form starts blank (create mode). When a template is
/// passed the fields are pre-populated (edit mode). Built-in templates cannot be edited
/// but the sheet will not be shown for them — the call site enforces this guard.
///
/// Variable rows can be added and removed inline. The save button is disabled until
/// both name and content fields are non-empty.
struct QuickReplyTemplateEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Template to edit; `nil` means create new.
    let template: QuickReplyTemplate?
    /// Called with the saved template on confirmation.
    let onSave: (QuickReplyTemplate) -> Void

    // MARK: - Form State

    @State private var name: String
    @State private var content: String
    @State private var category: QuickReplyCategory
    @State private var variables: [QuickReplyVariable]
    @State private var tags: String
    @State private var isFavorite: Bool

    init(template: QuickReplyTemplate?, onSave: @escaping (QuickReplyTemplate) -> Void) {
        self.template = template
        self.onSave = onSave
        _name = State(initialValue: template?.name ?? "")
        _content = State(initialValue: template?.content ?? "")
        _category = State(initialValue: template?.category ?? .custom)
        _variables = State(initialValue: template?.variables ?? [])
        _tags = State(initialValue: template?.tags.joined(separator: ", ") ?? "")
        _isFavorite = State(initialValue: template?.isFavorite ?? false)
    }

    private var isEditing: Bool { template != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !content.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        Form {
            // Basic info
            Section("Template Info") {
                TextField("Name", text: $name)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .accessibilityIdentifier("qr-edit-name")

                Picker("Category", selection: $category) {
                    ForEach(QuickReplyCategory.allCases, id: \.self) { cat in
                        Label(cat.displayName, systemImage: cat.systemImage).tag(cat)
                    }
                }
                .accessibilityIdentifier("qr-edit-category")

                Toggle("Pin to Toolbar", isOn: $isFavorite)
            }

            // Content
            Section("Content") {
                TextEditor(text: $content)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .frame(minHeight: 100)
                    .accessibilityIdentifier("qr-edit-content")

                if !variables.isEmpty {
                    Text("Use {{variable_name}} in content to reference variables.")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            // Variables
            Section {
                ForEach($variables) { $variable in
                    VariableRow(variable: $variable, theme: theme)
                }
                .onDelete { indexSet in
                    variables.remove(atOffsets: indexSet)
                }

                Button {
                    variables.append(QuickReplyVariable(name: "variable\(variables.count + 1)"))
                } label: {
                    Label("Add Variable", systemImage: "plus.circle")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                }
            } header: {
                Text("Variables")
            } footer: {
                Text("Variables allow dynamic content. Use {{name}} in the template content.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            }

            // Tags
            Section("Tags") {
                TextField("e.g. approve, run, test", text: $tags)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .accessibilityIdentifier("qr-edit-tags")
                    .autocorrectionDisabled()
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
        .navigationTitle(isEditing ? "Edit Template" : "New Template")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveTemplate() }
                    .disabled(!canSave)
                    .accessibilityIdentifier("qr-edit-save")
            }
        }
        #if os(iOS)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(theme.bgPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .preferredColorScheme(.dark)
    }

    private func saveTemplate() {
        let parsedTags = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let saved = QuickReplyTemplate(
            id: template?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            content: content.trimmingCharacters(in: .whitespaces),
            category: category,
            variables: variables,
            usageStats: template?.usageStats ?? QuickReplyUsageStats(),
            projectOverrides: template?.projectOverrides ?? [],
            isFavorite: isFavorite,
            isBuiltIn: false,
            createdAt: template?.createdAt ?? Date(),
            tags: parsedTags
        )
        onSave(saved)
        dismiss()
    }
}

// MARK: - Variable Row

/// Inline editable row for a single `QuickReplyVariable` within the edit form.
private struct VariableRow: View {
    @Binding var variable: QuickReplyVariable
    let theme: ThemeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Variable name", text: $variable.name)
                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            TextField("Default value (optional)", text: $variable.defaultValue)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        QuickReplyTemplatesSheet { template in
            AppLogger.shared.info("Selected template: \(template.name)", category: "ui")
        }
    }
}
