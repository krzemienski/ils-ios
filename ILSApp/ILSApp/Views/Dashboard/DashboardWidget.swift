import Foundation

// MARK: - WidgetSize

/// Grid-cell dimensions for a dashboard widget.
///
/// The dashboard uses a 2-column grid. Each size maps to a concrete
/// column-span × row-span pairing:
///
/// | Size   | Columns | Rows |
/// |--------|---------|------|
/// | small  | 1       | 1    |
/// | medium | 2       | 1    |
/// | large  | 2       | 2    |
///
/// ## Topics
/// ### Cases
/// - ``small`` - 1 × 1 grid cell
/// - ``medium`` - 2 × 1 grid cells
/// - ``large`` - 2 × 2 grid cells
///
/// ### Properties
/// - ``columnSpan`` - Number of grid columns occupied
/// - ``rowSpan`` - Number of grid rows occupied
/// - ``displayName`` - Human-readable label
enum WidgetSize: String, CaseIterable, Codable, Sendable {
    /// 1 column × 1 row.
    case small
    /// 2 columns × 1 row.
    case medium
    /// 2 columns × 2 rows.
    case large
}

extension WidgetSize {
    /// Number of grid columns this size occupies.
    var columnSpan: Int {
        switch self {
        case .small:  return 1
        case .medium: return 2
        case .large:  return 2
        }
    }

    /// Number of grid rows this size occupies.
    var rowSpan: Int {
        switch self {
        case .small:  return 1
        case .medium: return 1
        case .large:  return 2
        }
    }

    /// Human-readable label for display in the widget picker.
    var displayName: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        }
    }
}

// MARK: - DashboardWidget

/// A single tile on the configurable dashboard.
///
/// Each widget has a stable identity, a content type, a display size, a
/// grid position, and an optional refresh cadence. The model is persisted
/// as part of a ``DashboardLayout`` and can be synced via iCloud.
///
/// ```swift
/// let widget = DashboardWidget(
///     type: .systemMetrics,
///     size: .large,
///     position: WidgetPosition(row: 0, col: 0),
///     refreshInterval: 30
/// )
/// ```
///
/// ## Topics
/// ### Properties
/// - ``id`` - Stable UUID for diffing and drag-and-drop
/// - ``type`` - Content category (``DashboardWidgetType``)
/// - ``size`` - Display size (``WidgetSize``)
/// - ``position`` - Grid location (``WidgetPosition``)
/// - ``refreshInterval`` - Data refresh cadence in seconds, or `nil` for manual
struct DashboardWidget: Codable, Identifiable, Sendable {
    /// Stable unique identifier used for diffing and animation.
    let id: UUID
    /// The kind of content this widget displays.
    var type: DashboardWidgetType
    /// How many grid cells this widget occupies.
    var size: WidgetSize
    /// Where this widget is anchored in the dashboard grid.
    var position: WidgetPosition
    /// How often (in seconds) the widget refreshes its data.
    /// `nil` means the widget refreshes only on manual pull-to-refresh.
    var refreshInterval: TimeInterval?

    init(
        id: UUID = UUID(),
        type: DashboardWidgetType,
        size: WidgetSize? = nil,
        position: WidgetPosition = WidgetPosition(row: 0, col: 0),
        refreshInterval: TimeInterval? = nil
    ) {
        self.id = id
        self.type = type
        self.size = size ?? type.defaultSize
        self.position = position
        self.refreshInterval = refreshInterval
    }
}

// MARK: - WidgetPosition

/// A row/column anchor point in the dashboard grid.
///
/// Row and column indices are zero-based. The dashboard grid origin (0, 0)
/// is the top-leading corner.
///
/// ## Topics
/// ### Properties
/// - ``row`` - Zero-based row index
/// - ``col`` - Zero-based column index
struct WidgetPosition: Codable, Equatable, Sendable {
    /// Zero-based row index in the dashboard grid.
    var row: Int
    /// Zero-based column index in the dashboard grid.
    var col: Int
}
