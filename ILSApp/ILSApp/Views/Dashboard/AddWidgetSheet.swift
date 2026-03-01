import SwiftUI

// MARK: - AddWidgetSheet

/// A sheet that lists all ``DashboardWidgetType`` values not already present in the given
/// ``DashboardLayout``, letting the user add one at a chosen ``WidgetSize``.
///
/// Present this sheet when the user taps an "Add Widget" button in the dashboard edit flow.
/// Each row in the list displays the widget type's icon, display name, and three size buttons
/// (S / M / L). Tapping a size button immediately adds the widget to the layout via
/// ``DashboardLayoutStore/save(_:)`` and dismisses the sheet.
///
/// ```swift
/// .sheet(isPresented: $showAddWidget) {
///     if let layout = layoutStore.activeLayout {
///         AddWidgetSheet(layout: layout, layoutStore: layoutStore)
///     }
/// }
/// ```
///
/// ## Topics
/// ### Sub-views
/// - ``WidgetTypeRow``
struct AddWidgetSheet: View {

    // MARK: - Properties

    let layout: DashboardLayout
    let layoutStore: DashboardLayoutStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Computed

    /// Widget types that are not yet present in the layout.
    private var availableTypes: [DashboardWidgetType] {
        let existing = Set(layout.widgets.map(\.type))
        return DashboardWidgetType.allCases.filter { !existing.contains($0) }
    }

    /// The row index for the next widget appended to the layout.
    private var nextRow: Int {
        (layout.widgets.map(\.position.row).max() ?? -1) + 1
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if availableTypes.isEmpty {
                    emptyState
                } else {
                    widgetList
                }
            }
            .navigationTitle("Add Widget")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
                #else
                ToolbarItem {
                    Button("Done") { dismiss() }
                }
                #endif
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    // MARK: - Sub-views

    private var widgetList: some View {
        List {
            Section {
                ForEach(availableTypes, id: \.self) { type in
                    WidgetTypeRow(type: type) { size in
                        add(type: type, size: size)
                    }
                }
            } header: {
                Text("Available Widgets")
                    .font(.system(
                        size: theme.fontCaption,
                        weight: .semibold,
                        design: theme.fontDesign
                    ))
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.accent)

            Text("All Widgets Added")
                .font(.system(
                    size: theme.fontBody,
                    weight: .semibold,
                    design: theme.fontDesign
                ))
                .foregroundStyle(theme.textPrimary)

            Text("Every available widget is already on your dashboard.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(theme.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func add(type: DashboardWidgetType, size: WidgetSize) {
        let widget = DashboardWidget(
            type: type,
            size: size,
            position: WidgetPosition(row: nextRow, col: 0)
        )
        var updated = layout
        updated.widgets.append(widget)
        layoutStore.save(updated)
        dismiss()
    }
}

// MARK: - WidgetTypeRow

/// A single row in the ``AddWidgetSheet`` widget list.
///
/// Displays the widget type's SF Symbol icon, display name, recommended default size,
/// and three size-picker buttons (S / M / L). Tapping a button invokes `onAdd` with the
/// chosen ``WidgetSize``.
private struct WidgetTypeRow: View {

    // MARK: - Properties

    let type: DashboardWidgetType
    let onAdd: (WidgetSize) -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Body

    var body: some View {
        HStack(spacing: theme.spacingMD) {
            iconView
            labelStack
            Spacer()
            sizePicker
        }
        .padding(.vertical, 4)
    }

    // MARK: - Sub-views

    private var iconView: some View {
        Image(systemName: type.icon)
            .font(.system(size: 20))
            .foregroundStyle(theme.accent)
            .frame(width: 32, alignment: .center)
    }

    private var labelStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(type.displayName)
                .font(.system(
                    size: theme.fontBody,
                    weight: .medium,
                    design: theme.fontDesign
                ))
                .foregroundStyle(theme.textPrimary)

            Text("Default: \(type.defaultSize.displayName)")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private var sizePicker: some View {
        HStack(spacing: theme.spacingSM) {
            ForEach(WidgetSize.allCases, id: \.self) { size in
                sizeButton(size)
            }
        }
    }

    private func sizeButton(_ size: WidgetSize) -> some View {
        let isDefault = size == type.defaultSize
        return Button {
            onAdd(size)
        } label: {
            Text(size.rawValue.prefix(1).uppercased())
                .font(.system(
                    size: theme.fontCaption,
                    weight: .semibold,
                    design: theme.fontDesign
                ))
                .frame(width: 28, height: 28)
                .background(isDefault ? theme.accent : theme.glassBackground)
                .foregroundStyle(isDefault ? theme.textOnAccent : theme.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(type.displayName) widget, \(size.displayName) size")
    }
}

// MARK: - Preview

#Preview {
    let store = DashboardLayoutStore()
    let layout = DashboardLayout(name: "Developer", persona: .developer)

    AddWidgetSheet(layout: layout, layoutStore: store)
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
