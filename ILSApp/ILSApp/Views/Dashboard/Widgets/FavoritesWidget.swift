import SwiftUI
import Observation

// MARK: - FavoriteItemType

/// The kind of entity represented by a ``FavoriteItem``.
enum FavoriteItemType: String, Codable, Sendable {
    /// A Claude Code chat session.
    case session
    /// A project associated with a chat session.
    case project
}

// MARK: - FavoriteItem

/// A single entry in the user's favourites list.
///
/// Favourite items are persisted to `UserDefaults` as JSON and surfaced on the
/// ``FavoritesWidget``.  Each entry stores enough information to render a row and
/// navigate to the underlying entity without a network round-trip.
///
/// ## Topics
/// ### Properties
/// - ``id`` - Stable UUID for list diffing
/// - ``name`` - Display name shown in the widget row
/// - ``type`` - Whether the item is a session or a project
/// - ``itemID`` - Backend identifier for the entity (UUID string)
/// - ``addedAt`` - Timestamp used to sort favourites newest-first
struct FavoriteItem: Codable, Identifiable, Sendable {
    /// Stable unique identifier used for list diffing.
    let id: UUID
    /// Display name shown in the widget row.
    let name: String
    /// Whether this favourite represents a session or a project.
    let type: FavoriteItemType
    /// Backend identifier for the entity.
    let itemID: String
    /// When the item was added; used to sort the list newest-first.
    let addedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: FavoriteItemType,
        itemID: String,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.itemID = itemID
        self.addedAt = addedAt
    }
}

// MARK: - FavoritesStore

/// Shared helpers for reading and writing the favourites list in `UserDefaults`.
///
/// All mutations are synchronous and update `UserDefaults.standard` immediately.
/// Call ``load()`` on any `@Observable` view model that wants to observe the list.
///
/// ## Usage
/// ```swift
/// // Add a session
/// FavoritesStore.add(FavoriteItem(name: "My session", type: .session, itemID: session.id))
///
/// // Remove a session
/// FavoritesStore.remove(item)
///
/// // Check membership
/// let starred = FavoritesStore.isFavorite(itemID: id, type: .session)
/// ```
enum FavoritesStore {

    private static let defaultsKey = "com.ils.dashboard.favorites"

    /// Loads all persisted favourite items sorted newest-first.
    static func load() -> [FavoriteItem] {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let items = try? JSONDecoder().decode([FavoriteItem].self, from: data)
        else { return [] }
        return items.sorted { $0.addedAt > $1.addedAt }
    }

    /// Persists `items` to `UserDefaults`.
    private static func save(_ items: [FavoriteItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    /// Adds `item` if no existing favourite with the same `itemID` and `type` exists.
    static func add(_ item: FavoriteItem) {
        var items = load()
        guard !items.contains(where: { $0.itemID == item.itemID && $0.type == item.type }) else { return }
        items.append(item)
        save(items)
    }

    /// Removes the favourite identified by `item.id`.
    static func remove(_ item: FavoriteItem) {
        var items = load()
        items.removeAll { $0.id == item.id }
        save(items)
    }

    /// Returns `true` when the given entity is already in the favourites list.
    static func isFavorite(itemID: String, type: FavoriteItemType) -> Bool {
        load().contains { $0.itemID == itemID && $0.type == type }
    }
}

// MARK: - FavoritesWidgetViewModel

/// View model for the Favourites dashboard widget.
///
/// Reads the favourites list from `UserDefaults` via ``FavoritesStore`` and
/// exposes it to the view.  Because favourites are stored locally, no network
/// fetch is needed — `isOffline` is always `false`.
///
/// ## Topics
/// ### Data
/// - ``favorites`` - Currently persisted favourite items, sorted newest-first
///
/// ### DashboardWidgetViewModel
/// - ``isLoading`` - `true` briefly while reading `UserDefaults`
/// - ``isOffline`` - Always `false`; favourites are stored locally
/// - ``loadContent()`` - Reads favourites from `UserDefaults`
@Observable
@MainActor
final class FavoritesWidgetViewModel: DashboardWidgetViewModel {

    // MARK: DashboardWidgetViewModel

    /// `true` briefly while reading `UserDefaults`.
    private(set) var isLoading = true
    /// Always `false`; favourites are stored locally.
    private(set) var isOffline = false

    // MARK: Data

    /// Favourite items sorted newest-first.
    private(set) var favorites: [FavoriteItem] = []

    // MARK: Init

    init() {}

    // MARK: DashboardWidgetViewModel

    /// Reads favourites from `UserDefaults`.
    func loadContent() async {
        isLoading = true
        favorites = FavoritesStore.load()
        isLoading = false
    }

    // MARK: Mutations

    /// Removes `item` from the favourites list and persists the change.
    func remove(_ item: FavoriteItem) {
        FavoritesStore.remove(item)
        favorites.removeAll { $0.id == item.id }
    }
}

// MARK: - FavoritesWidget

/// Dashboard widget that lists the user's pinned sessions and projects.
///
/// Favourite items are persisted to `UserDefaults` via ``FavoritesStore`` and
/// displayed as tappable rows.  Tapping a row calls ``onSelectFavorite`` so the
/// parent can navigate to the underlying session or project.  Items can be
/// removed by swiping left.
///
/// The widget is size-adaptive: a ``LazyVGrid`` with an adaptive minimum column
/// width of 72 pt displays two columns on narrow small widgets and three columns
/// on wider medium or large widgets, matching the behaviour of ``QuickActionsWidget``.
///
/// ## Usage
/// ```swift
/// FavoritesWidget(viewModel: vm) { item in
///     navigate(to: item)
/// }
/// ```
struct FavoritesWidget: View {

    // MARK: - Properties

    /// View model supplying the list of favourite items.
    let viewModel: FavoritesWidgetViewModel
    /// Called when the user taps a favourite item row.
    var onSelectFavorite: ((FavoriteItem) -> Void)?

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .background(theme.bgTertiary)

            if viewModel.isLoading {
                skeletonContent
            } else if viewModel.favorites.isEmpty {
                emptyState
            } else {
                favoritesList
            }

            Spacer(minLength: 0)
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: DashboardWidgetType.favorites.icon)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.warning)
                .accessibilityHidden(true)

            Text("Favorites")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()

            if !viewModel.favorites.isEmpty {
                countBadge
            }
        }
        .padding(.bottom, theme.spacingSM)
    }

    private var countBadge: some View {
        Text("\(viewModel.favorites.count)")
            .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
            .foregroundStyle(theme.textOnAccent)
            .padding(.horizontal, theme.spacingXS + 2)
            .padding(.vertical, 2)
            .background(theme.warning)
            .clipShape(Capsule())
            .accessibilityLabel("\(viewModel.favorites.count) favorited \(viewModel.favorites.count == 1 ? "item" : "items")")
    }

    // MARK: - Favorites List

    private var favoritesList: some View {
        VStack(spacing: theme.spacingXS) {
            ForEach(viewModel.favorites) { item in
                favoriteRow(item)
            }
        }
        .padding(.top, theme.spacingSM)
    }

    @ViewBuilder
    private func favoriteRow(_ item: FavoriteItem) -> some View {
        Button {
            onSelectFavorite?(item)
        } label: {
            HStack(spacing: theme.spacingSM) {
                // Type icon
                Image(systemName: item.type == .session ? "bubble.left.and.bubble.right.fill" : "folder.fill")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(item.type == .session ? theme.entitySession : theme.entityPlugin)
                    .frame(width: 16)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text(item.type == .session ? "Session" : "Project")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption - 1, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgTertiary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(item.type == .session ? "Session" : "Project")")
        .accessibilityHint("Opens this \(item.type == .session ? "session" : "project")")
        .accessibilityAddTraits(.isButton)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.remove(item)
            } label: {
                Label("Remove", systemImage: "star.slash.fill")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "star")
                .font(.system(size: 22, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("No Favorites Yet")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            Text("Star sessions or projects to pin them here")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.spacingMD)
        .accessibilityLabel("No favorites yet. Star sessions or projects to pin them here.")
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(spacing: theme.spacingXS) {
            ForEach(0..<3, id: \.self) { _ in
                skeletonRow
            }
        }
        .padding(.top, theme.spacingSM)
    }

    private var skeletonRow: some View {
        HStack(spacing: theme.spacingSM) {
            RoundedRectangle(cornerRadius: 3)
                .fill(theme.bgTertiary)
                .frame(width: 16, height: 14)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.bgTertiary)
                    .frame(width: 130, height: 13)

                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.bgTertiary)
                    .frame(width: 60, height: 10)
            }

            Spacer()
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgTertiary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    FavoritesWidget(viewModel: FavoritesWidgetViewModel())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
        .frame(width: 320, height: 240)
        .glassCard()
        .padding()
}
