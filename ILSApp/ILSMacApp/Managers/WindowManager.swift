import SwiftUI
import AppKit
import ILSShared

/// Manages multiple session windows for macOS multi-window support.
@MainActor
class WindowManager: ObservableObject {
    /// Map of session IDs to their window identifiers
    @Published private(set) var openWindows: [UUID: String] = [:]

    /// The currently focused session ID (if any)
    @Published var focusedSessionId: UUID?

    /// Singleton instance for app-wide access
    static let shared = WindowManager()

    private init() {}

    // MARK: - Window Management

    /// Register a window for a session
    func registerWindow(for sessionId: UUID, windowId: String) {
        openWindows[sessionId] = windowId
    }

    /// Unregister a window for a session
    func unregisterWindow(for sessionId: UUID) {
        openWindows.removeValue(forKey: sessionId)
        if focusedSessionId == sessionId {
            focusedSessionId = nil
        }
    }

    /// Check if a session is already open in a window
    func isSessionOpen(_ sessionId: UUID) -> Bool {
        return openWindows[sessionId] != nil
    }

    /// Get the window identifier for a session
    func windowId(for sessionId: UUID) -> String? {
        return openWindows[sessionId]
    }

    /// Open a session in a new window
    func openSessionWindow(_ session: ChatSession) {
        let windowId = "session-\(session.id.uuidString)"

        // If window is already open, focus it
        if isSessionOpen(session.id) {
            focusExistingWindow(sessionId: session.id)
            return
        }

        // Register the window
        registerWindow(for: session.id, windowId: windowId)
        focusedSessionId = session.id

        // Open URL with handlesExternalEvents identifier
        if let url = URL(string: "ils://session/\(session.id.uuidString)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Focus an existing window for a session
    func focusExistingWindow(sessionId: UUID) {
        guard let windowId = openWindows[sessionId] else { return }

        // Find the window with matching identifier and bring to front
        for window in NSApplication.shared.windows {
            if window.identifier?.rawValue == windowId {
                window.makeKeyAndOrderFront(nil)
                focusedSessionId = sessionId
                return
            }
        }
    }

    /// Close a session window
    func closeSessionWindow(_ sessionId: UUID) {
        guard let windowId = openWindows[sessionId] else { return }

        // Find and close the window
        for window in NSApplication.shared.windows {
            if window.identifier?.rawValue == windowId {
                window.close()
                unregisterWindow(for: sessionId)
                return
            }
        }
    }

    /// Close all session windows
    func closeAllSessionWindows() {
        let sessionIds = Array(openWindows.keys)
        for sessionId in sessionIds {
            closeSessionWindow(sessionId)
        }
    }

    /// Get all open session IDs
    func openSessionIds() -> [UUID] {
        return Array(openWindows.keys)
    }

    /// Get the count of open windows
    var openWindowCount: Int {
        return openWindows.count
    }
}
