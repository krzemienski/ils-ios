import SwiftUI

/// Widget types available on the configurable dashboard.
///
/// Each type represents a distinct data source or action group that can be
/// placed as a tile on the home dashboard. Users can add, remove, and
/// reorder widgets to build a personalised command-centre view.
///
/// ## Topics
/// ### Cases
/// - ``activeSessions`` - Currently running Claude Code sessions
/// - ``recentSessions`` - Recently completed or paused sessions
/// - ``systemMetrics`` - CPU, memory, and disk usage
/// - ``teamActivity`` - Team member usage and collaboration feed
/// - ``usageStats`` - Token consumption and budget overview
/// - ``quickActions`` - Shortcut buttons for common tasks
/// - ``favorites`` - Pinned sessions, projects, and skills
/// - ``projectStatus`` - Build / CI status across projects
///
/// ### Properties
/// - ``icon`` - SF Symbol name for the widget
/// - ``displayName`` - Human-readable title shown on the widget header
/// - ``defaultSize`` - Recommended ``WidgetSize`` for this widget type
enum DashboardWidgetType: String, CaseIterable, Codable, Sendable {
    /// Currently running Claude Code sessions.
    case activeSessions
    /// Recently completed or paused sessions.
    case recentSessions
    /// CPU, memory, and disk usage gauges.
    case systemMetrics
    /// Team member activity and collaboration feed.
    case teamActivity
    /// Token consumption and budget overview.
    case usageStats
    /// Shortcut buttons for common tasks.
    case quickActions
    /// Pinned sessions, projects, and skills.
    case favorites
    /// Build and CI status across projects.
    case projectStatus
}

extension DashboardWidgetType {
    /// SF Symbol name for the widget type.
    var icon: String {
        switch self {
        case .activeSessions:  return "bubble.left.and.bubble.right.fill"
        case .recentSessions:  return "clock.arrow.circlepath"
        case .systemMetrics:   return "gauge.with.dots.needle.33percent"
        case .teamActivity:    return "person.3.fill"
        case .usageStats:      return "chart.bar.fill"
        case .quickActions:    return "bolt.fill"
        case .favorites:       return "star.fill"
        case .projectStatus:   return "checkmark.seal.fill"
        }
    }

    /// Human-readable title shown on the widget header.
    var displayName: String {
        switch self {
        case .activeSessions:  return "Active Sessions"
        case .recentSessions:  return "Recent Sessions"
        case .systemMetrics:   return "System Metrics"
        case .teamActivity:    return "Team Activity"
        case .usageStats:      return "Usage Stats"
        case .quickActions:    return "Quick Actions"
        case .favorites:       return "Favorites"
        case .projectStatus:   return "Project Status"
        }
    }

    /// Recommended size for first-time placement of this widget type.
    var defaultSize: WidgetSize {
        switch self {
        case .activeSessions:  return .medium
        case .recentSessions:  return .medium
        case .systemMetrics:   return .large
        case .teamActivity:    return .large
        case .usageStats:      return .medium
        case .quickActions:    return .small
        case .favorites:       return .medium
        case .projectStatus:   return .small
        }
    }
}
