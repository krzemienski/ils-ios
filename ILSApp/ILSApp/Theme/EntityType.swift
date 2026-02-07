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
    /// Entity primary color
    var color: Color {
        switch self {
        case .sessions: return Color(red: 0, green: 122.0/255.0, blue: 255.0/255.0)       // #007AFF
        case .projects: return Color(red: 52.0/255.0, green: 199.0/255.0, blue: 89.0/255.0) // #34C759
        case .skills:   return Color(red: 175.0/255.0, green: 82.0/255.0, blue: 222.0/255.0) // #AF52DE
        case .mcp:      return Color(red: 255.0/255.0, green: 149.0/255.0, blue: 0)          // #FF9500
        case .plugins:  return Color(red: 255.0/255.0, green: 214.0/255.0, blue: 10.0/255.0) // #FFD60A
        case .system:   return Color(red: 48.0/255.0, green: 176.0/255.0, blue: 199.0/255.0) // #30B0C7
        }
    }

    /// Entity gradient for cards and accents
    var gradient: LinearGradient {
        switch self {
        case .sessions:
            return LinearGradient(colors: [Color(red: 0, green: 122.0/255.0, blue: 255.0/255.0), Color(red: 90.0/255.0, green: 200.0/255.0, blue: 250.0/255.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .projects:
            return LinearGradient(colors: [Color(red: 52.0/255.0, green: 199.0/255.0, blue: 89.0/255.0), Color(red: 48.0/255.0, green: 209.0/255.0, blue: 88.0/255.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .skills:
            return LinearGradient(colors: [Color(red: 175.0/255.0, green: 82.0/255.0, blue: 222.0/255.0), Color(red: 191.0/255.0, green: 90.0/255.0, blue: 242.0/255.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .mcp:
            return LinearGradient(colors: [Color(red: 255.0/255.0, green: 149.0/255.0, blue: 0), Color(red: 255.0/255.0, green: 107.0/255.0, blue: 53.0/255.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .plugins:
            return LinearGradient(colors: [Color(red: 255.0/255.0, green: 214.0/255.0, blue: 10.0/255.0), Color(red: 255.0/255.0, green: 159.0/255.0, blue: 10.0/255.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .system:
            return LinearGradient(colors: [Color(red: 48.0/255.0, green: 176.0/255.0, blue: 199.0/255.0), Color(red: 100.0/255.0, green: 210.0/255.0, blue: 255.0/255.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

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
}
