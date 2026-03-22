import SwiftUI

// MARK: - DashboardLayoutPickerView

/// Layout selection sheet for switching between saved dashboard configurations.
///
/// Presents a `List` divided into three sections:
///
/// 1. **Presets** — The three read-only built-in persona layouts (Developer, DevOps,
///    Team Lead). These cannot be deleted but can be made active.
/// 2. **My Layouts** — User-created custom layouts. Supports swipe-to-delete.
/// 3. **Actions** — "New Layout" (prompts for a name) and "Reset to Default"
///    (replaces all layouts with the built-in persona defaults).
///
/// Each row shows a 64 × 64 thumbnail with up to four widget-type icons arranged in
/// a mini 2-column grid, mirroring the actual dashboard layout at a glance.
///
/// ## Topics
/// ### View Components
/// - ``layoutRow(_:isPreset:)`` - A tappable row card for one layout
/// - ``layoutThumbnail(_:)`` - The mini icon-grid preview inside each row
///
/// ### Helpers
/// - ``presetLayouts`` - Persona-seeded layouts filtered from the store
/// - ``customLayouts`` - User-created layouts filtered from the store
struct DashboardLayoutPickerView: View {
    @Environment(DashboardLayoutStore.self) var layoutStore
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    @State private var showingNewLayoutAlert = false
    @State private var newLayoutName = ""
    @State private var showingResetConfirmation = false

    // MARK: - Computed Properties

    /// Layouts seeded from a persona (Developer, DevOps, Team Lead) — read-only.
    private var presetLayouts: [DashboardLayout] {
        layoutStore.layouts.filter { $0.persona != .custom }
    }

    /// User-created layouts — can be deleted.
    private var customLayouts: [DashboardLayout] {
        layoutStore.layouts.filter { $0.persona == .custom }
    }

    // MARK: - Body

    var body: some View {
        List {
            descriptionRow

            presetsSection

            if !customLayouts.isEmpty {
                customSection
            }

            actionsSection
        }
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
        .navigationTitle("Dashboard Layout")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .alert("New Layout", isPresented: $showingNewLayoutAlert) {
            TextField("Layout name", text: $newLayoutName)
                .autocorrectionDisabled()
            Button("Create") {
                createNewLayout()
            }
            Button("Cancel", role: .cancel) {
                newLayoutName = ""
            }
        } message: {
            Text("Enter a name for your new custom layout.")
        }
        .confirmationDialog(
            "Reset to Default?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                layoutStore.resetToDefault()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This replaces all layouts with the built-in Developer, DevOps, and Team Lead presets.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var descriptionRow: some View {
        Section {
            Text("Choose a layout for the home dashboard. Presets are read-only; custom layouts can be deleted.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var presetsSection: some View {
        Section {
            ForEach(presetLayouts) { layout in
                layoutRow(layout, isPreset: true)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: theme.spacingMD, bottom: 4, trailing: theme.spacingMD))
            }
        } header: {
            sectionHeader("Presets")
        }
    }

    @ViewBuilder
    private var customSection: some View {
        Section {
            ForEach(customLayouts) { layout in
                layoutRow(layout, isPreset: false)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: theme.spacingMD, bottom: 4, trailing: theme.spacingMD))
            }
            .onDelete(perform: deleteCustomLayouts)
        } header: {
            sectionHeader("My Layouts")
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            Button {
                newLayoutName = ""
                showingNewLayoutAlert = true
            } label: {
                Label("New Layout", systemImage: "plus.circle.fill")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                Label("Reset to Default", systemImage: "arrow.counterclockwise")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .tracking(1)
    }

    // MARK: - Layout Row

    @ViewBuilder
    private func layoutRow(_ layout: DashboardLayout, isPreset: Bool) -> some View {
        let isActive = layoutStore.activeLayout?.id == layout.id

        Button {
            layoutStore.setActiveLayout(layout)
        } label: {
            HStack(spacing: theme.spacingMD) {
                // Thumbnail preview
                layoutThumbnail(layout)

                // Name and widget count
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(layout.name)
                            .font(.system(
                                size: theme.fontBody,
                                weight: isActive ? .semibold : .regular,
                                design: theme.fontDesign
                            ))
                            .foregroundStyle(isActive ? theme.accent : theme.textPrimary)
                            .lineLimit(1)

                        if isPreset {
                            Text("PRESET")
                                // ACC-007: Use 11pt minimum for Dynamic Type compliance
                                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(theme.bgSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    Text("\(layout.widgets.count) widget\(layout.widgets.count == 1 ? "" : "s")")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer(minLength: 0)

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.vertical, theme.spacingSM)
        }
        .buttonStyle(.plain)
        .modifier(GlassCard())
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(isActive ? theme.accent : Color.clear, lineWidth: 1.5)
        )
        .accessibilityLabel(accessibilityLabel(for: layout, isPreset: isPreset, isActive: isActive))
    }

    // MARK: - Layout Thumbnail

    /// Mini 2-column grid showing up to four widget-type SF Symbol icons.
    @ViewBuilder
    private func layoutThumbnail(_ layout: DashboardLayout) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .fill(theme.bgSecondary)
                .frame(width: 64, height: 64)

            if layout.widgets.isEmpty {
                Image(systemName: "square.dashed")
                    .font(.system(size: 20, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            } else {
                let displayWidgets = Array(layout.widgets.prefix(4))
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(22), spacing: 4),
                        GridItem(.fixed(22), spacing: 4)
                    ],
                    spacing: 4
                ) {
                    ForEach(displayWidgets) { widget in
                        widgetIconCell(for: widget.type)
                    }
                }
                .padding(8)
            }
        }
        .frame(width: 64, height: 64)
    }

    @ViewBuilder
    private func widgetIconCell(for widgetType: DashboardWidgetType) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.accent.opacity(0.15))
                .frame(width: 22, height: 22)
            Image(systemName: widgetType.icon)
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
        }
        .frame(width: 22, height: 22)
    }

    // MARK: - Accessibility

    private func accessibilityLabel(
        for layout: DashboardLayout,
        isPreset: Bool,
        isActive: Bool
    ) -> String {
        var parts = [layout.name, "layout"]
        if isPreset { parts.append("preset") }
        if isActive { parts.append("active") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Actions

    private func createNewLayout() {
        let trimmed = newLayoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let layout = DashboardLayout(name: trimmed, persona: .custom)
        layoutStore.save(layout)
        layoutStore.setActiveLayout(layout)
        newLayoutName = ""
    }

    private func deleteCustomLayouts(at offsets: IndexSet) {
        for index in offsets {
            layoutStore.delete(customLayouts[index])
        }
    }
}

// MARK: - Preview

#Preview {
    let store = DashboardLayoutStore()
    return NavigationStack {
        DashboardLayoutPickerView()
            .environment(store)
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
