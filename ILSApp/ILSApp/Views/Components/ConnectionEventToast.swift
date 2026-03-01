import SwiftUI

// MARK: - ConnectionEvent

/// The connection transition that triggered a toast notification.
enum ConnectionEvent: Equatable {
    /// Connection to the backend was lost.
    case lost
    /// Connection to the backend was restored.
    case restored
}

// MARK: - ConnectionEventToast

/// Animated overlay banner that slides in from the top when connection is lost or restored.
///
/// Auto-dismisses after 3 seconds. Respects the system Reduce Motion preference.
/// Add this view to the top of a `ZStack` so it overlays existing content.
///
/// ## Usage
/// ```swift
/// ZStack(alignment: .top) {
///     ContentView()
///     ConnectionEventToast(event: $connectionEvent)
/// }
/// ```
struct ConnectionEventToast: View {

    // MARK: - State

    /// The current event to display. Set to `nil` to hide the toast.
    @Binding var event: ConnectionEvent?

    // MARK: - Environment

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Private State

    @State private var dismissTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        if let event {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: iconName(for: event))
                    .font(.system(size: theme.fontCaption, weight: .semibold))

                Text(message(for: event))
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
            }
            .foregroundStyle(foregroundColor(for: event))
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingXS)
            .frame(maxWidth: .infinity)
            .background(
                foregroundColor(for: event).opacity(0.15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(foregroundColor(for: event).opacity(0.3), lineWidth: 0.5)
                    )
            )
            .transition(
                reduceMotion
                    ? .opacity
                    : .move(edge: .top).combined(with: .opacity)
            )
            .accessibilityLabel(accessibilityLabel(for: event))
            .accessibilityAddTraits(.isStaticText)
            .onAppear {
                scheduleDismiss()
            }
            .onChange(of: event) { _, _ in
                scheduleDismiss()
            }
        }
    }

    // MARK: - Auto-Dismiss

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
            guard !Task.isCancelled else { return }
            withAnimation {
                event = nil
            }
        }
    }

    // MARK: - Appearance Helpers

    private func iconName(for event: ConnectionEvent) -> String {
        switch event {
        case .lost:     return "wifi.slash"
        case .restored: return "wifi"
        }
    }

    private func message(for event: ConnectionEvent) -> String {
        switch event {
        case .lost:     return "Connection lost"
        case .restored: return "Connected"
        }
    }

    private func foregroundColor(for event: ConnectionEvent) -> Color {
        switch event {
        case .lost:     return theme.error
        case .restored: return theme.success
        }
    }

    private func accessibilityLabel(for event: ConnectionEvent) -> String {
        switch event {
        case .lost:     return "Connection lost."
        case .restored: return "Connection restored."
        }
    }
}

// MARK: - Previews

#Preview("Lost") {
    VStack {
        ConnectionEventToast(event: .constant(.lost))
        Spacer()
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}

#Preview("Restored") {
    VStack {
        ConnectionEventToast(event: .constant(.restored))
        Spacer()
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}

#Preview("Hidden") {
    VStack {
        ConnectionEventToast(event: .constant(nil))
        Spacer()
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
