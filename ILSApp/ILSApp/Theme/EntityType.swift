import SwiftUI

/// Entity types in ILS with associated colors, gradients, and SF Symbols
enum EntityType: String, CaseIterable {
    case sessions
    case projects
    case skills
    case mcp
    case plugins
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
