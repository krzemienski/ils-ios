import SwiftUI

/// Entity types in ILS with associated colors, icons, and display names.
///
/// Represents the six main entity types in the ILS app. Each entity type has:
/// - A unique color (consistent across themes)
/// - An SF Symbol icon
/// - A display name for UI
///
/// ## Topics
/// ### Cases
/// - ``sessions`` - Chat sessions with Claude
/// - ``projects`` - Code projects/repositories
/// - ``skills`` - Custom Claude workflows
/// - ``mcp`` - Model Context Protocol servers
/// - ``plugins`` - Claude plugin extensions
/// - ``system`` - System monitoring and files
///
/// ### Properties
/// - ``icon`` - SF Symbol name for the entity
/// - ``displayName`` - Human-readable name
/// - ``themeColor(from:)`` - Theme-aware color
enum EntityType: String, CaseIterable {
    /// Chat sessions with Claude.
    case sessions
    /// Code projects and repositories.
    case projects
    /// Custom Claude workflows and skills.
    case skills
    /// Model Context Protocol servers.
    case mcp
    /// Claude plugin extensions.
    case plugins
    /// System monitoring and files.
    case system
}

extension EntityType {
    /// SF Symbol name for the entity
    var icon: String {
        switch self {
        case .sessions: return "bubble.left.and.bubble.right"
        case .projects: return "folder.fill"
        case .skills:   return "sparkles"
        case .mcp:      return "server.rack"
        case .plugins:  return "puzzlepiece.extension"
        case .system:   return "gauge.with.dots.needle.33percent"
        }
    }

    /// Display name
    var displayName: String {
        switch self {
        case .sessions: return "Sessions"
        case .projects: return "Projects"
        case .skills:   return "Skills"
        case .mcp:      return "MCP Servers"
        case .plugins:  return "Plugins"
        case .system:   return "System"
        }
    }

    /// Theme-aware entity color from AppTheme tokens
    func themeColor(from theme: any AppTheme) -> Color {
        switch self {
        case .sessions: return theme.entitySession
        case .projects: return theme.entityProject
        case .skills:   return theme.entitySkill
        case .mcp:      return theme.entityMCP
        case .plugins:  return theme.entityPlugin
        case .system:   return theme.entitySystem
        }
    }
}
