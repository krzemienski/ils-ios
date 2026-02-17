import Cocoa
import SwiftUI

/// AppDelegate for macOS-specific app lifecycle.
///
/// Menu bar is provided entirely by `ILSCommands` via SwiftUI `.commands {}`.
/// No manual menu setup is needed here — duplicate NSMenu construction was
/// removed because it posted raw string notification names that no view observed
/// (the typed names live in `ILSCommands.swift`).
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar is handled by ILSCommands via SwiftUI .commands {}
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running when last window closes (standard macOS document-based behavior)
        return false
    }
}
