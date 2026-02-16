import SwiftUI
import TipKit

// MARK: - Server Setup Tip

struct ServerSetupTip: Tip {
    var title: Text { Text("Connect to Backend") }
    var message: Text? { Text("Configure your ILS backend server to unlock all features.") }
    var image: Image? { Image(systemName: "server.rack") }
}

// MARK: - Create Session Tip

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

struct CommandPaletteTip: Tip {
    var title: Text { Text("Quick Actions") }
    var message: Text? { Text("Swipe down or tap the search icon for quick access to commands and navigation.") }
    var image: Image? { Image(systemName: "command") }
}

// MARK: - Theme Tip

struct ThemeTip: Tip {
    var title: Text { Text("Customize Your Theme") }
    var message: Text? { Text("Choose from 12 built-in themes or create your own in Settings.") }
    var image: Image? { Image(systemName: "paintpalette") }
}
