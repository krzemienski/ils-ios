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

    /// UserDefaults key for storing window frames
    private let windowFramesKey = "ils_window_frames"

    /// Map of session IDs to window delegates for tracking frame changes
    private var windowDelegates: [UUID: WindowFrameDelegate] = [:]

    private init() {}

    // MARK: - Window Management

    /// Register a window for a session
    func registerWindow(for sessionId: UUID, windowId: String) {
        openWindows[sessionId] = windowId

        // Set up frame autosave and delegate for window frame tracking
        // Try to find window by identifier or by session window title
        if let window = findWindow(withId: windowId) ?? findSessionWindow(for: sessionId) {
            setupWindowPersistence(window: window, sessionId: sessionId)
        }
    }

    /// Register a window for a session with the actual NSWindow object
    func registerWindow(for sessionId: UUID, windowId: String, window: NSWindow) {
        openWindows[sessionId] = windowId
        setupWindowPersistence(window: window, sessionId: sessionId)
    }

    /// Unregister a window for a session
    func unregisterWindow(for sessionId: UUID) {
        // Save final frame before unregistering
        if let windowId = openWindows[sessionId], let window = findWindow(withId: windowId) {
            saveWindowFrame(window: window, sessionId: sessionId)
        }

        // Clean up delegate
        windowDelegates.removeValue(forKey: sessionId)

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

    // MARK: - Window Persistence

    /// Set up window frame persistence for a session window
    private func setupWindowPersistence(window: NSWindow, sessionId: UUID) {
        // Set frameAutosaveName for macOS automatic frame persistence
        let autosaveName = "session-window-\(sessionId.uuidString)"
        window.setFrameAutosaveName(autosaveName)

        // Restore saved frame if available
        if let savedFrame = getSavedWindowFrame(for: sessionId) {
            window.setFrame(savedFrame, display: true)
        }

        // Set up delegate to track frame changes
        let delegate = WindowFrameDelegate(sessionId: sessionId, windowManager: self)
        windowDelegates[sessionId] = delegate
        window.delegate = delegate
    }

    /// Save window frame to UserDefaults
    func saveWindowFrame(window: NSWindow, sessionId: UUID) {
        let frame = window.frame
        let frameDict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]

        var allFrames = getAllSavedFrames()
        allFrames[sessionId.uuidString] = frameDict
        UserDefaults.standard.set(allFrames, forKey: windowFramesKey)
    }

    /// Get saved window frame for a session
    private func getSavedWindowFrame(for sessionId: UUID) -> NSRect? {
        let allFrames = getAllSavedFrames()
        guard let frameDict = allFrames[sessionId.uuidString] as? [String: CGFloat],
              let x = frameDict["x"],
              let y = frameDict["y"],
              let width = frameDict["width"],
              let height = frameDict["height"] else {
            return nil
        }

        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// Get all saved window frames from UserDefaults
    private func getAllSavedFrames() -> [String: Any] {
        return UserDefaults.standard.dictionary(forKey: windowFramesKey) ?? [:]
    }

    /// Find window by identifier
    private func findWindow(withId windowId: String) -> NSWindow? {
        return NSApplication.shared.windows.first { window in
            window.identifier?.rawValue == windowId
        }
    }

    /// Find session window by looking for "Session" title
    private func findSessionWindow(for sessionId: UUID) -> NSWindow? {
        return NSApplication.shared.windows.first { window in
            window.title == "Session" || window.title.contains(sessionId.uuidString)
        }
    }

    /// Clear saved frame for a session
    func clearSavedFrame(for sessionId: UUID) {
        var allFrames = getAllSavedFrames()
        allFrames.removeValue(forKey: sessionId.uuidString)
        UserDefaults.standard.set(allFrames, forKey: windowFramesKey)
    }

    /// Clear all saved window frames
    func clearAllSavedFrames() {
        UserDefaults.standard.removeObject(forKey: windowFramesKey)
    }
}

// MARK: - Window Frame Delegate

/// NSWindowDelegate to track and save window frame changes
class WindowFrameDelegate: NSObject, NSWindowDelegate {
    let sessionId: UUID
    weak var windowManager: WindowManager?

    init(sessionId: UUID, windowManager: WindowManager) {
        self.sessionId = sessionId
        self.windowManager = windowManager
        super.init()
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            windowManager?.saveWindowFrame(window: window, sessionId: sessionId)
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            windowManager?.saveWindowFrame(window: window, sessionId: sessionId)
        }
    }
}
