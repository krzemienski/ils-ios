import SwiftUI

// MARK: - WidgetSizeSelectorModifier

/// A `ViewModifier` that attaches a long-press context menu to a dashboard widget tile,
/// letting the user choose a new ``WidgetSize``.
///
/// The selected size is applied to the widget inside the given ``DashboardLayout`` and
/// persisted immediately via ``DashboardLayoutStore/save(_:)``.
///
/// ## Usage
/// ```swift
/// widgetTile
///     .widgetSizeSelector(widget: widget, layout: layout, layoutStore: store)
/// ```
///
/// ## Topics
/// ### Modifier
/// - ``WidgetSizeSelectorModifier``
///
/// ### Extension
/// - ``SwiftUICore/View/widgetSizeSelector(widget:layout:layoutStore:)``
struct WidgetSizeSelectorModifier: ViewModifier {

    // MARK: - Properties

    let widget: DashboardWidget
    let layout: DashboardLayout
    let layoutStore: DashboardLayoutStore

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Text("Resize \(widget.type.displayName)")
                    .font(.caption)
                Divider()
                ForEach(WidgetSize.allCases, id: \.self) { size in
                    Button {
                        resize(to: size)
                    } label: {
                        Label(
                            size.displayName,
                            systemImage: sizeIcon(for: size)
                        )
                    }
                    // Show a checkmark on the currently active size
                    .disabled(widget.size == size)
                }
            }
    }

    // MARK: - Private Helpers

    /// Updates the widget's size in a copy of the layout and persists via the store.
    private func resize(to size: WidgetSize) {
        var updated = layout
        guard let index = updated.widgets.firstIndex(where: { $0.id == widget.id }) else { return }
        updated.widgets[index].size = size
        layoutStore.save(updated)
        layoutStore.setActiveLayout(updated)
    }

    /// Returns an SF Symbol name representing the given size.
    private func sizeIcon(for size: WidgetSize) -> String {
        if widget.size == size { return "checkmark" }
        switch size {
        case .small:  return "square"
        case .medium: return "rectangle"
        case .large:  return "square.split.2x2"
        }
    }
}

// MARK: - View Extension

extension View {
    /// Attaches a long-press context menu that lets the user resize a dashboard widget.
    ///
    /// The context menu presents all ``WidgetSize`` options, with the current size
    /// indicated by a checkmark. Selecting an option immediately persists the change
    /// through ``DashboardLayoutStore``.
    ///
    /// - Parameters:
    ///   - widget: The widget whose size can be changed.
    ///   - layout: The ``DashboardLayout`` that contains the widget.
    ///   - layoutStore: The store responsible for persisting layout changes.
    func widgetSizeSelector(
        widget: DashboardWidget,
        layout: DashboardLayout,
        layoutStore: DashboardLayoutStore
    ) -> some View {
        modifier(WidgetSizeSelectorModifier(
            widget: widget,
            layout: layout,
            layoutStore: layoutStore
        ))
    }
}
