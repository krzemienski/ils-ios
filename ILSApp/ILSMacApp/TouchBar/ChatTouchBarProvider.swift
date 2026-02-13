import SwiftUI

#if os(macOS)
import AppKit

/// Provides Touch Bar support for the chat view on macOS devices with Touch Bar hardware.
/// Touch Bar displays common actions: Send message, Command palette, Session info, and New session.
struct ChatTouchBarProvider: View {
    // MARK: - Bindings & State

    let inputText: String
    let isStreaming: Bool
    let isDisabled: Bool
    let onSend: () -> Void
    let onCommandPalette: () -> Void
    let onSessionInfo: () -> Void
    let onNewSession: () -> Void

    // MARK: - Body

    var body: some View {
        // The content returned here is what appears in the Touch Bar
        HStack(spacing: 12) {
            // Send button - primary action
            Button {
                onSend()
            } label: {
                Label("Send", systemImage: "paperplane.fill")
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming || isDisabled)
            .keyboardShortcut(.return, modifiers: .command)

            // Command palette button
            Button {
                onCommandPalette()
            } label: {
                Label("Commands", systemImage: "command")
            }
            .keyboardShortcut("k", modifiers: .command)

            // Session info button
            Button {
                onSessionInfo()
            } label: {
                Label("Info", systemImage: "info.circle")
            }
            .keyboardShortcut("i", modifiers: .command)

            // New session button
            Button {
                onNewSession()
            } label: {
                Label("New Session", systemImage: "plus.circle")
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }
}

/// Extension to make it easy to add Touch Bar to any View
extension View {
    /// Adds chat-specific Touch Bar controls to the view
    /// - Parameters:
    ///   - inputText: Current input text (to enable/disable Send button)
    ///   - isStreaming: Whether a message is currently streaming
    ///   - isDisabled: Whether input is disabled
    ///   - onSend: Action to send a message
    ///   - onCommandPalette: Action to show command palette
    ///   - onSessionInfo: Action to show session info
    ///   - onNewSession: Action to create a new session
    /// - Returns: View with Touch Bar attached
    @ViewBuilder
    func chatTouchBar(
        inputText: String,
        isStreaming: Bool,
        isDisabled: Bool,
        onSend: @escaping () -> Void,
        onCommandPalette: @escaping () -> Void,
        onSessionInfo: @escaping () -> Void,
        onNewSession: @escaping () -> Void
    ) -> some View {
        self.touchBar {
            ChatTouchBarProvider(
                inputText: inputText,
                isStreaming: isStreaming,
                isDisabled: isDisabled,
                onSend: onSend,
                onCommandPalette: onCommandPalette,
                onSessionInfo: onSessionInfo,
                onNewSession: onNewSession
            )
        }
    }
}

#endif
