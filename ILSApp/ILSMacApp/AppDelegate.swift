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

        // Ensure at least one window is visible on launch.
        // macOS window restoration may restore an empty window set when the user
        // previously closed all windows while the app stayed running. Without this
        // check the app launches with zero visible windows.
        DispatchQueue.main.async { [weak self] in
            self?.ensureMainWindowVisible()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // When the user clicks the dock icon or Cmd-Tabs back, ensure a window
        // is visible. This covers the case where the app was already running in
        // the background with no windows.
        ensureMainWindowVisible()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            ensureMainWindowVisible()
        }
        // Return true to let the system also attempt its default reopen behavior
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running when last window closes (standard macOS document-based behavior)
        return false
    }

    // MARK: - Private

    /// If no windows are currently visible, find the main WindowGroup window and
    /// bring it to front. SwiftUI's WindowGroup always creates at least one
    /// NSWindow; it may just be ordered out (hidden) after restoration.
    private func ensureMainWindowVisible() {
        let app = NSApplication.shared
        let hasVisibleWindow = app.windows.contains { window in
            window.isVisible && !window.isMiniaturized
        }

        guard !hasVisibleWindow else { return }

        // Try to surface an existing window that SwiftUI created but didn't show
        if let mainWindow = app.windows.first(where: { $0.canBecomeMain }) {
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }
}
