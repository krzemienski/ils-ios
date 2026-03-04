// iPadKeyboardShortcuts.swift
// Zero-size overlay that provides global keyboard shortcuts for iPad external keyboard support.
// Hidden buttons with .keyboardShortcut() modifiers stay in the SwiftUI responder chain
// without contributing to layout or accessibility.

import SwiftUI

#if os(iOS)

// MARK: - Notification Names (iOS)

extension Notification.Name {
    /// Posted when the user triggers the new-session keyboard shortcut (Cmd+N).
    /// Observers (e.g. HomeView, SessionsView) can react to this to begin session creation.
    static let ilsCreateNewSession = Notification.Name("ILSCreateNewSession")
}

// MARK: - iPad Keyboard Shortcut Overlay

/// Zero-size overlay view that activates global keyboard shortcuts for iPad external keyboards.
///
/// Embed this view at the root of the view hierarchy to make shortcuts available app-wide.
/// Each shortcut is a hidden, zero-size button using `.keyboardShortcut()` — the button
/// participates in the SwiftUI responder chain without contributing any visible UI or layout.
///
/// ## Supported Shortcuts
/// | Shortcut | Action |
/// |-----------|--------|
/// | `Cmd+N`  | Post ``Notification.Name/ilsCreateNewSession`` to trigger new session creation |
/// | `Cmd+,`  | Navigate to Settings via ``AppState/navigationIntent`` |
struct iPadKeyboardShortcutOverlay: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            // Cmd+N — New Session
            Button {
                NotificationCenter.default.post(name: .ilsCreateNewSession, object: nil)
            } label: {
                EmptyView()
            }
            .keyboardShortcut("n", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)

            // Cmd+, — Settings
            Button {
                appState.navigationIntent = .settings
            } label: {
                EmptyView()
            }
            .keyboardShortcut(",", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
    }
}

#endif
