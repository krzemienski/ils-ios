import SwiftUI
import ILSShared
import AppKit

/// A dedicated window view for displaying a single session.
/// Used in multi-window scenarios where a session is opened in its own window.
struct SessionWindowView: View {
    let sessionId: UUID

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var windowManager: WindowManager
    @Environment(\.theme) private var theme

    @StateObject private var viewModel: ChatViewModel
    @State private var session: ChatSession?
    @State private var isLoading = true
    @State private var errorMessage: String?

    init(sessionId: UUID) {
        self.sessionId = sessionId
        _viewModel = StateObject(wrappedValue: ChatViewModel(sessionId: sessionId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading session...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("Error Loading Session")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Close Window") {
                        closeWindow()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let session {
                // TODO: Replace with actual MacChatView when implemented in Phase 2
                chatPlaceholderView(for: session)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .focusedSceneValue(\.selectedSession, session)
        .background(WindowAccessor(sessionId: sessionId, windowManager: windowManager))
        .onAppear {
            loadSession()
        }
        .onDisappear {
            windowManager.unregisterWindow(for: sessionId)
        }
    }

    // MARK: - Placeholder View

    /// Placeholder view until MacChatView is implemented
    private func chatPlaceholderView(for session: ChatSession) -> some View {
        VStack(spacing: 20) {
            Text("Session: \(session.name)")
                .font(.title)

            Text("Session ID: \(session.id.uuidString)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let project = session.projectName {
                Text("Project: \(project)")
                    .font(.subheadline)
            }

            Divider()

            Text("Multi-window support active!")
                .font(.headline)
                .foregroundColor(theme.accentColor)

            Text("Chat view will be implemented in Phase 2")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Close Window") {
                closeWindow()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Methods

    private func loadSession() {
        Task {
            do {
                let sessions = try await appState.apiClient.getSessions()
                if let foundSession = sessions.first(where: { $0.id == sessionId }) {
                    await MainActor.run {
                        self.session = foundSession
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Session not found"
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func closeWindow() {
        windowManager.closeSessionWindow(sessionId)
    }
}

// MARK: - Window Accessor

/// Helper to access the NSWindow from SwiftUI and set up window persistence
struct WindowAccessor: NSViewRepresentable {
    let sessionId: UUID
    let windowManager: WindowManager

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                let windowId = "session-\(sessionId.uuidString)"
                windowManager.registerWindow(for: sessionId, windowId: windowId, window: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

#Preview {
    SessionWindowView(sessionId: UUID())
        .environmentObject(AppState())
        .environmentObject(ThemeManager())
        .environmentObject(WindowManager.shared)
}
