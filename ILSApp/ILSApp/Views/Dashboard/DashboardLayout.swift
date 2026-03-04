import Foundation

// MARK: - DashboardPersona

/// A predefined persona that seeds a ``DashboardLayout`` with sensible defaults.
///
/// Each persona maps to a curated widget list optimised for that role's priorities.
///
/// ## Topics
/// ### Cases
/// - ``developer`` - Active sessions, recent sessions, and favorites
/// - ``devops`` - System metrics, project status, and usage stats
/// - ``teamLead`` - Team activity, usage stats, and active sessions
/// - ``custom`` - User-defined layout with no pre-seeded widgets
///
/// ### Properties
/// - ``displayName`` - Human-readable label
/// - ``defaultWidgets`` - Ordered array of widgets for this persona
enum DashboardPersona: String, CaseIterable, Codable, Sendable {
    /// Focuses on active and recent sessions with quick access to favorites.
    case developer
    /// Focuses on system metrics, build status, and usage overview.
    case devops
    /// Focuses on team activity and high-level usage statistics.
    case teamLead
    /// No pre-seeded widgets; the user builds the layout from scratch.
    case custom
}

extension DashboardPersona {
    /// Human-readable name shown in the layout-picker UI.
    var displayName: String {
        switch self {
        case .developer: return "Developer"
        case .devops:    return "DevOps"
        case .teamLead:  return "Team Lead"
        case .custom:    return "Custom"
        }
    }

    /// Ordered list of widgets seeded when a layout is created for this persona.
    var defaultWidgets: [DashboardWidget] {
        switch self {
        case .developer:
            return [
                DashboardWidget(type: .activeSessions,  size: .medium, position: WidgetPosition(row: 0, col: 0)),
                DashboardWidget(type: .recentSessions,  size: .medium, position: WidgetPosition(row: 1, col: 0)),
                DashboardWidget(type: .favorites,       size: .medium, position: WidgetPosition(row: 2, col: 0)),
                DashboardWidget(type: .quickActions,    size: .small,  position: WidgetPosition(row: 3, col: 0)),
            ]
        case .devops:
            return [
                DashboardWidget(type: .systemMetrics,  size: .large,  position: WidgetPosition(row: 0, col: 0)),
                DashboardWidget(type: .projectStatus,  size: .small,  position: WidgetPosition(row: 2, col: 0)),
                DashboardWidget(type: .usageStats,     size: .medium, position: WidgetPosition(row: 3, col: 0)),
                DashboardWidget(type: .quickActions,   size: .small,  position: WidgetPosition(row: 4, col: 0)),
            ]
        case .teamLead:
            return [
                DashboardWidget(type: .teamActivity,   size: .large,  position: WidgetPosition(row: 0, col: 0)),
                DashboardWidget(type: .usageStats,     size: .medium, position: WidgetPosition(row: 2, col: 0)),
                DashboardWidget(type: .activeSessions, size: .medium, position: WidgetPosition(row: 3, col: 0)),
            ]
        case .custom:
            return []
        }
    }
}

// MARK: - DashboardLayout

/// A named, persisted arrangement of ``DashboardWidget`` tiles.
///
/// Layouts are created by the user (or seeded from a ``DashboardPersona``) and
/// stored locally via ``DashboardLayoutStore``. When iCloud is enabled the store
/// mirrors layouts to `NSUbiquitousKeyValueStore` so they sync across devices.
///
/// ```swift
/// let layout = DashboardLayout(
///     name: "Work",
///     persona: .developer
/// )
/// ```
///
/// ## Topics
/// ### Properties
/// - ``id`` - Stable UUID used for diffing and iCloud key construction
/// - ``name`` - User-visible name shown in the layout picker
/// - ``persona`` - Persona this layout was seeded from (or `.custom`)
/// - ``widgets`` - Ordered list of widget tiles
/// - ``createdAt`` - Timestamp recorded at creation
struct DashboardLayout: Codable, Identifiable, Sendable {
    /// Stable unique identifier used for persistence keys and diffing.
    let id: UUID
    /// User-visible name displayed in the layout-switcher UI.
    var name: String
    /// Persona this layout was originally seeded from.
    var persona: DashboardPersona
    /// Ordered list of widget tiles that make up the layout.
    var widgets: [DashboardWidget]
    /// When this layout was first created.
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        persona: DashboardPersona = .custom,
        widgets: [DashboardWidget]? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.persona = persona
        self.widgets = widgets ?? persona.defaultWidgets
        self.createdAt = createdAt
    }
}
