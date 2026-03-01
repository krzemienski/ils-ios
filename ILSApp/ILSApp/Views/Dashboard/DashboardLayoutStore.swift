import Foundation

/// Persists and manages ``DashboardLayout`` objects across sessions.
///
/// Layouts are encoded as JSON and written to `UserDefaults`. When
/// `NSUbiquitousKeyValueStore` is available (iCloud enabled) the store also
/// mirrors data there so layouts sync across the user's devices.
///
/// ## Usage
/// ```swift
/// @Environment(DashboardLayoutStore.self) var layoutStore
///
/// // Save a new layout
/// layoutStore.save(layout)
///
/// // Delete a layout
/// layoutStore.delete(layout)
///
/// // Switch the active layout
/// layoutStore.setActiveLayout(layout)
/// ```
///
/// ## Topics
/// ### Properties
/// - ``layouts`` - All persisted layouts, ordered by creation date
/// - ``activeLayout`` - The currently displayed layout
///
/// ### Methods
/// - ``save(_:)`` - Persist or update a layout
/// - ``delete(_:)`` - Remove a layout
/// - ``setActiveLayout(_:)`` - Change the active layout
/// - ``resetToDefault()`` - Replace layouts with persona defaults
@Observable
@MainActor
final class DashboardLayoutStore {

    // MARK: - Default Layouts

    /// Pre-built Developer layout: active sessions, recent sessions, quick actions, favorites.
    static let defaultDeveloperLayout = DashboardLayout(
        name: DashboardPersona.developer.displayName,
        persona: .developer,
        widgets: [
            DashboardWidget(type: .activeSessions, size: .medium, position: WidgetPosition(row: 0, col: 0)),
            DashboardWidget(type: .recentSessions, size: .medium, position: WidgetPosition(row: 1, col: 0)),
            DashboardWidget(type: .quickActions,   size: .small,  position: WidgetPosition(row: 2, col: 0)),
            DashboardWidget(type: .favorites,      size: .medium, position: WidgetPosition(row: 3, col: 0)),
        ]
    )

    /// Pre-built DevOps layout: system metrics, usage stats, project status, active sessions.
    static let defaultDevOpsLayout = DashboardLayout(
        name: DashboardPersona.devops.displayName,
        persona: .devops,
        widgets: [
            DashboardWidget(type: .systemMetrics,  size: .large,  position: WidgetPosition(row: 0, col: 0)),
            DashboardWidget(type: .usageStats,     size: .medium, position: WidgetPosition(row: 2, col: 0)),
            DashboardWidget(type: .projectStatus,  size: .small,  position: WidgetPosition(row: 3, col: 0)),
            DashboardWidget(type: .activeSessions, size: .medium, position: WidgetPosition(row: 4, col: 0)),
        ]
    )

    /// Pre-built Team Lead layout: team activity, usage stats, recent sessions, project status.
    static let defaultTeamLeadLayout = DashboardLayout(
        name: DashboardPersona.teamLead.displayName,
        persona: .teamLead,
        widgets: [
            DashboardWidget(type: .teamActivity,   size: .large,  position: WidgetPosition(row: 0, col: 0)),
            DashboardWidget(type: .usageStats,     size: .medium, position: WidgetPosition(row: 2, col: 0)),
            DashboardWidget(type: .recentSessions, size: .medium, position: WidgetPosition(row: 3, col: 0)),
            DashboardWidget(type: .projectStatus,  size: .small,  position: WidgetPosition(row: 4, col: 0)),
        ]
    )

    /// Ordered array of the three persona default layouts used for seeding and reset.
    private static var defaultLayouts: [DashboardLayout] {
        [defaultDeveloperLayout, defaultDevOpsLayout, defaultTeamLeadLayout]
    }

    // MARK: - Published State

    /// All persisted layouts, ordered by creation date (oldest first).
    private(set) var layouts: [DashboardLayout] = []

    /// The layout currently shown on the dashboard.
    /// Falls back to the first available layout if the persisted ID is not found.
    private(set) var activeLayout: DashboardLayout?

    // MARK: - Private

    private let defaults: UserDefaults
    private let iCloud: NSUbiquitousKeyValueStore?

    // MARK: - Init

    /// Creates the store, loads persisted data, and wires up iCloud sync.
    ///
    /// - Parameters:
    ///   - defaults: The `UserDefaults` suite to read/write. Defaults to `.standard`.
    ///   - iCloud: The key-value store used for iCloud sync. Pass `nil` to disable sync.
    init(
        defaults: UserDefaults = .standard,
        iCloud: NSUbiquitousKeyValueStore? = .default
    ) {
        self.defaults = defaults
        self.iCloud = iCloud
        load()
        observeICloudChanges()
    }

    // MARK: - Public API

    /// Persist a new layout or update an existing one (matched by `id`).
    ///
    /// - Parameter layout: The layout to save.
    func save(_ layout: DashboardLayout) {
        if let index = layouts.firstIndex(where: { $0.id == layout.id }) {
            layouts[index] = layout
        } else {
            layouts.append(layout)
        }
        persist()
        if activeLayout == nil {
            activeLayout = layouts.first
            persistActiveID()
        }
    }

    /// Remove a layout from the store.
    ///
    /// If the deleted layout was active, the store selects the first remaining
    /// layout (or `nil` when no layouts remain).
    ///
    /// - Parameter layout: The layout to delete.
    func delete(_ layout: DashboardLayout) {
        layouts.removeAll { $0.id == layout.id }
        if activeLayout?.id == layout.id {
            activeLayout = layouts.first
            persistActiveID()
        }
        persist()
    }

    /// Switch the dashboard to a different layout.
    ///
    /// - Parameter layout: The layout to make active. Must already be in ``layouts``.
    func setActiveLayout(_ layout: DashboardLayout) {
        guard layouts.contains(where: { $0.id == layout.id }) else { return }
        activeLayout = layout
        persistActiveID()
    }

    /// Replace all layouts with the three default persona layouts and activate
    /// the Developer layout.
    func resetToDefault() {
        layouts = Self.defaultLayouts
        activeLayout = layouts.first
        persist()
        persistActiveID()
    }

    // MARK: - Persistence

    private func load() {
        layouts = loadLayouts()
        activeLayout = resolveActiveLayout()
    }

    private func loadLayouts() -> [DashboardLayout] {
        // Prefer iCloud data if available and newer
        if let iCloudData = iCloud?.data(forKey: AppConstants.dashboardLayoutsKey) {
            if let decoded = try? JSONDecoder().decode([DashboardLayout].self, from: iCloudData) {
                return decoded
            }
        }
        // Fall back to UserDefaults
        if let localData = defaults.data(forKey: AppConstants.dashboardLayoutsKey) {
            if let decoded = try? JSONDecoder().decode([DashboardLayout].self, from: localData) {
                return decoded
            }
        }
        // No persisted data — seed with defaults
        return Self.defaultLayouts
    }

    private func resolveActiveLayout() -> DashboardLayout? {
        let activeIDString = defaults.string(forKey: AppConstants.dashboardActiveLayoutIDKey)
            ?? iCloud?.string(forKey: AppConstants.dashboardActiveLayoutIDKey)
        if let idString = activeIDString,
           let uuid = UUID(uuidString: idString),
           let match = layouts.first(where: { $0.id == uuid }) {
            return match
        }
        return layouts.first
    }

    private func persist() {
        guard let encoded = try? JSONEncoder().encode(layouts) else { return }
        defaults.set(encoded, forKey: AppConstants.dashboardLayoutsKey)
        iCloud?.set(encoded, forKey: AppConstants.dashboardLayoutsKey)
        iCloud?.synchronize()
    }

    private func persistActiveID() {
        let idString = activeLayout?.id.uuidString ?? ""
        defaults.set(idString, forKey: AppConstants.dashboardActiveLayoutIDKey)
        iCloud?.set(idString, forKey: AppConstants.dashboardActiveLayoutIDKey)
        iCloud?.synchronize()
    }

    // MARK: - iCloud Sync

    private func observeICloudChanges() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloud,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.load()
            }
        }
    }
}
