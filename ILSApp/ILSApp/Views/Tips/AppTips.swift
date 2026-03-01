import SwiftUI
import TipKit

// MARK: - Server Setup Tip

/// TipKit tip shown when no backend server has been configured yet.
struct ServerSetupTip: Tip {
    var title: Text { Text("Connect to Backend") }
    var message: Text? { Text("Configure your ILS backend server to unlock all features.") }
    var image: Image? { Image(systemName: "server.rack") }
}

// MARK: - Create Session Tip

/// TipKit tip shown after the backend connects, prompting the user to start a chat session.
struct CreateSessionTip: Tip {
    var title: Text { Text("Start a Chat") }
    var message: Text? { Text("Create a new session to chat with Claude Code.") }
    var image: Image? { Image(systemName: "plus.message") }

    @Parameter
    static var isConnected: Bool = false

    var rules: [Rule] {
        #Rule(Self.$isConnected) { $0 == true }
    }
}

// MARK: - Command Palette Tip

/// TipKit tip introducing the swipe-down command palette gesture.
/// Unlocks after the user has created a session.
struct CommandPaletteTip: Tip {
    var title: Text { Text("Quick Actions") }
    var message: Text? { Text("Swipe down or tap the search icon for quick access to commands and navigation.") }
    var image: Image? { Image(systemName: "command") }

    @Parameter
    static var hasCreatedSession: Bool = false

    var rules: [Rule] {
        #Rule(Self.$hasCreatedSession) { $0 == true }
    }
}

// MARK: - Theme Tip

/// TipKit tip surfacing the theme-customisation option in Settings.
/// Unlocks after 5+ app opens.
struct ThemeTip: Tip {
    var title: Text { Text("Customize Your Theme") }
    var message: Text? { Text("Choose from 12 built-in themes or create your own in Settings.") }
    var image: Image? { Image(systemName: "paintpalette") }

    @Parameter
    static var appOpenCount: Int = 0

    var rules: [Rule] {
        #Rule(Self.$appOpenCount) { $0 >= 5 }
    }
}

// MARK: - MCP Browser Tip

/// TipKit tip surfacing the MCP server browser after the user has created a session.
/// Unlocks after a session has been created and 3+ app opens.
struct MCPBrowserTip: Tip {
    var title: Text { Text("Explore MCP Servers") }
    var message: Text? { Text("Browse and manage your Model Context Protocol server configurations.") }
    var image: Image? { Image(systemName: "server.rack") }

    @Parameter
    static var hasCreatedSession: Bool = false

    @Parameter
    static var appOpenCount: Int = 0

    var rules: [Rule] {
        #Rule(Self.$hasCreatedSession) { $0 == true }
        #Rule(Self.$appOpenCount) { $0 >= 3 }
    }
}

// MARK: - Teams Tip

/// TipKit tip introducing Agent Teams after the user has browsed MCP servers.
/// Unlocks after the user has viewed the MCP tab.
struct TeamsTip: Tip {
    var title: Text { Text("Agent Teams") }
    var message: Text? { Text("Coordinate multiple Claude agents working together on complex tasks.") }
    var image: Image? { Image(systemName: "person.3") }

    @Parameter
    static var hasViewedMCP: Bool = false

    var rules: [Rule] {
        #Rule(Self.$hasViewedMCP) { $0 == true }
    }
}
