import SwiftUI
import ILSShared
import UniformTypeIdentifiers

// MARK: - KanbanColumnView

/// A single column on the session kanban board.
///
/// Displays a themed header (icon, title, item count badge) followed by a
/// vertically scrolling list of ``KanbanSessionCardView`` instances. The
/// column acts as a drop target for drag-and-drop reordering and shows a
/// visual highlight while an item is dragged over it.
///
/// ## Layout Adaptation
/// - **iPad / landscape**: Fixed width of 280pt for side-by-side columns.
/// - **iPhone portrait**: Full width in a vertical stack.
///
/// ## Callbacks
/// - ``onCardTapped`` — user tapped the card body
/// - ``onOpenChat`` — user tapped "Open Chat" quick action
/// - ``onApprovePermission`` — user tapped "Approve" quick action
/// - ``onViewDetails`` — user tapped "Details" quick action
///
/// ## Empty State
/// When the column contains no items a subtle "No items" placeholder is shown.
struct KanbanColumnView: View {

    // MARK: - Properties

    /// The column definition (title, icon, color).
    let column: KanbanColumn
    /// Items to display within this column.
    let items: [KanbanBoardItem]

    /// Called when the user taps a card body.
    var onCardTapped: ((KanbanBoardItem) -> Void)?
    /// Called when the user taps "Open Chat" on a session card.
    var onOpenChat: ((KanbanBoardItem) -> Void)?
    /// Called when the user taps "Approve" on a waiting-for-approval card.
    var onApprovePermission: ((KanbanBoardItem) -> Void)?
    /// Called when the user taps "View Details" on any card.
    var onViewDetails: ((KanbanBoardItem) -> Void)?
    /// Called when a dragged item is dropped onto this column.
    /// Receives the dropped item's ID string.
    var onItemDropped: ((String) -> Void)?

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Tracks whether a dragged item is currently hovering over this column.
    @State private var isDropTargeted = false

    // MARK: - Constants

    /// Fixed column width used on iPad and landscape layouts.
    private static let fixedWidth: CGFloat = 280

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            columnHeader
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, theme.spacingSM)

            Divider()
                .overlay(column.color.opacity(0.3))

            if items.isEmpty {
                emptyState
            } else {
                cardList
            }
        }
        .background(column.color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .strokeBorder(
                    isDropTargeted ? column.color.opacity(0.6) : column.color.opacity(0.15),
                    lineWidth: isDropTargeted ? 2 : 1
                )
        )
        .frame(width: useFixedWidth ? Self.fixedWidth : nil)
        #if os(iOS)
        .onDrop(of: [UTType.plainText], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        #endif
        .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(column.displayTitle) column, \(items.count) items")
    }

    // MARK: - Fixed vs Flexible Width

    /// Use fixed width on iPad (regular horizontal size class).
    private var useFixedWidth: Bool {
        horizontalSizeClass == .regular
    }

    // MARK: - Column Header

    private var columnHeader: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: column.iconName)
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(column.color)

            Text(column.displayTitle)
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 0)

            // Item count badge
            Text("\(items.count)")
                .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textOnAccent)
                .frame(minWidth: 22, minHeight: 22)
                .background(column.color)
                .clipShape(Circle())
        }
    }

    // MARK: - Card List

    private var cardList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: theme.spacingSM) {
                ForEach(items) { item in
                    KanbanSessionCardView(
                        item: item,
                        column: column,
                        onTap: { onCardTapped?(item) },
                        onOpenChat: { onOpenChat?(item) },
                        onApprove: { onApprovePermission?(item) },
                        onViewDetails: { onViewDetails?(item) }
                    )
                    #if os(iOS)
                    .onDrag {
                        NSItemProvider(object: item.id as NSString)
                    }
                    #endif
                }
            }
            .padding(theme.spacingSM)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No items")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    // MARK: - Drop Handling

    #if os(iOS)
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let idString = item as? String else { return }
            DispatchQueue.main.async {
                onItemDropped?(idString)
            }
        }
        return true
    }
    #endif
}

// MARK: - Preview

#Preview("Kanban Column — Active") {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            KanbanColumnView(
                column: .active,
                items: [
                    .session(TaggedSession(
                        session: ChatSession(
                            name: "Implement authentication",
                            projectName: "MyApp",
                            model: "sonnet",
                            status: .active,
                            messageCount: 42
                        ),
                        backendId: UUID(),
                        backendName: "Work Mac",
                        backendColorHex: "#4A90E2"
                    )),
                    .session(TaggedSession(
                        session: ChatSession(
                            name: "Fix database migration",
                            projectName: "Backend",
                            model: "opus",
                            status: .active,
                            messageCount: 15
                        ),
                        backendId: UUID(),
                        backendName: "Home Mac",
                        backendColorHex: "#7ED321"
                    )),
                ]
            )

            KanbanColumnView(
                column: .completed,
                items: []
            )
        }
        .padding()
    }
    .background(Color.black)
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
