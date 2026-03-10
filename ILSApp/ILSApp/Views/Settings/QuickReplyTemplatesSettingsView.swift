import SwiftUI

/// Full-featured settings screen for managing quick reply templates.
///
/// Displays all templates (built-ins and custom) grouped by category. Built-in
/// templates are read-only and shown with a lock icon. Custom templates support
/// swipe-to-delete and tap-to-edit. A summary header shows totals, and a usage
/// stats section highlights the five most-used templates.
///
/// ## Topics
/// ### Sections
/// - Summary header with template counts
/// - Templates grouped by ``QuickReplyCategory``
/// - Most-used usage stats section
struct QuickReplyTemplatesSettingsView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    private var manager: QuickReplyTemplateManager { QuickReplyTemplateManager.shared }

    // MARK: - State

    @State private var editingTemplate: QuickReplyTemplate? = nil
    @State private var showingEditSheet = false
    @State private var templateToDelete: QuickReplyTemplate? = nil
    @State private var showingDeleteConfirmation = false

    // MARK: - Body

    var body: some View {
        let allTemplates = manager.allTemplates

        Group {
            if allTemplates.isEmpty {
                emptyState
            } else {
                templateList
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Quick Reply Templates")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingTemplate = nil
                    showingEditSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add template")
                .accessibilityIdentifier("qr-settings-add")
            }
        }
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
    }

    // MARK: - Template List

    private var templateList: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingMD) {
                // Summary header
                summaryHeader

                // Templates grouped by category
                ForEach(QuickReplyCategory.allCases, id: \.self) { category in
                    let templates = manager.templates(for: category)
                    if !templates.isEmpty {
                        categorySection(category, templates: templates)
                    }
                }

                // Usage stats
                let topUsed = manager.mostUsedTemplates(limit: 5)
                if !topUsed.isEmpty {
                    usageStatsSection(topUsed)
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        let allTemplates = manager.allTemplates
        let builtInCount = allTemplates.filter(\.isBuiltIn).count
        let customCount = manager.customTemplates.count

        return HStack(spacing: theme.spacingMD) {
            VStack(spacing: 2) {
                Text("\(allTemplates.count)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                Text("Total")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            VStack(spacing: 2) {
                Text("\(builtInCount)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.info)
                Text("Built-In")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.info.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            VStack(spacing: 2) {
                Text("\(customCount)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.success)
                Text("Custom")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.success.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
    }

    // MARK: - Category Section

    private func categorySection(_ category: QuickReplyCategory, templates: [QuickReplyTemplate]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Section header
            HStack(spacing: theme.spacingSM) {
                Image(systemName: category.systemImage)
                    .foregroundStyle(theme.accent)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .accessibilityHidden(true)

                Text(category.displayName)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Text("\(templates.count)")
                    .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.bgTertiary)
                    .clipShape(Capsule())
            }
            .padding(.top, theme.spacingSM)

            // Template rows
            ForEach(templates) { template in
                templateRow(template)
            }
        }
    }

    // MARK: - Template Row

    private func templateRow(_ template: QuickReplyTemplate) -> some View {
        HStack(spacing: theme.spacingSM) {
            // Pin indicator
            if template.isFavorite {
                Image(systemName: "pin.fill")
                    // ACC-007: Use theme caption size for Dynamic Type compliance
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(template.name)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    if template.hasVariables {
                        Image(systemName: "curlybraces")
                            // ACC-007: Use theme caption size for Dynamic Type compliance
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textTertiary)
                            .accessibilityHidden(true)
                    }
                }

                Text(template.content)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // Usage count badge
            if template.usageStats.useCount > 0 {
                Text("\(template.usageStats.useCount)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.bgTertiary)
                    .clipShape(Capsule())
            }

            // Lock icon for built-ins; chevron for custom
            if template.isBuiltIn {
                Image(systemName: "lock")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityLabel("Built-in template, read-only")
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .contentShape(Rectangle())
        .onTapGesture {
            guard !template.isBuiltIn else { return }
            editingTemplate = template
            showingEditSheet = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(template.isBuiltIn
            ? "\(template.name), built-in, read-only"
            : "\(template.name), custom template, tap to edit"
        )
        .accessibilityIdentifier("qr-settings-row-\(template.id.uuidString.lowercased())")
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { await manager.togglePin(id: template.id) }
            } label: {
                Label(
                    template.isFavorite ? "Unpin" : "Pin",
                    systemImage: template.isFavorite ? "pin.slash" : "pin"
                )
            }
            .tint(theme.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !template.isBuiltIn {
                Button(role: .destructive) {
                    templateToDelete = template
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    editingTemplate = template
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
        .contextMenu {
            Button {
                Task { await manager.togglePin(id: template.id) }
            } label: {
                Label(
                    template.isFavorite ? "Unpin" : "Pin",
                    systemImage: template.isFavorite ? "pin.slash" : "pin"
                )
            }
            if !template.isBuiltIn {
                Button {
                    editingTemplate = template
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    templateToDelete = template
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Usage Stats Section

    private func usageStatsSection(_ templates: [QuickReplyTemplate]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "chart.bar")
                    .foregroundStyle(theme.accent)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .accessibilityHidden(true)

                Text("Most Used")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()
            }
            .padding(.top, theme.spacingSM)

            ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                HStack(spacing: theme.spacingSM) {
                    Text("\(index + 1)")
                        .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .frame(width: 20)

                    Image(systemName: template.category.systemImage)
                        .font(.system(size: 14))
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)

                    Text(template.name)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(template.usageStats.useCount)")
                            .font(.system(size: theme.fontBody, weight: .bold, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                        Text("uses")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
                .modifier(GlassCard())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(template.name), \(template.usageStats.useCount) uses")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "text.bubble")
                .font(.system(size: 40, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .accessibilityHidden(true)
            Text("No Templates Yet")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text("Quick reply templates let you send common messages with one tap. Tap + to create your first custom template.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, theme.spacingXL)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        QuickReplyTemplatesSettingsView()
    }
}
