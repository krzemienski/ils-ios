import SwiftUI
import ILSShared
import AppKit

/// A dedicated window view for displaying a single session.
/// Used in multi-window scenarios where a session is opened in its own window.
struct SessionWindowView: View {
    let sessionId: UUID

    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.theme) private var theme

    @State private var viewModel: ChatViewModel
    @State private var session: ChatSession?
    @State private var isLoading = true
    @State private var errorMessage: String?

    init(sessionId: UUID) {
        self.sessionId = sessionId
        _viewModel = State(wrappedValue: ChatViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading session...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48, design: theme.fontDesign))
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
                MacChatView(session: session)
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

    // MARK: - Helper Methods

    private func loadSession() {
        Task {
            do {
                // Use single-session endpoint instead of fetching all 22K+ sessions (O(n) → O(1))
                let response: APIResponse<ChatSession> = try await appState.apiClient.get("/sessions/\(sessionId.uuidString.lowercased())")
                if let foundSession = response.data {
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
        .environment(AppState())
        .environment(ThemeManager())
        .environment(WindowManager.shared)
        .environmentObject(NotificationManager.shared)
}
