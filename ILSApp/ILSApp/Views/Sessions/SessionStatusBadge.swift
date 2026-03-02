import SwiftUI
import ILSShared

// MARK: - SessionStatusBadge

/// Compact visual indicator for session activity state.
///
/// Displays a colored dot (and optional label in `.full` mode) that reflects the
/// combined `SessionStatus` + streaming state of a Claude Code session. Intended
/// for use in split-pane headers and the iPhone persistent status bar.
///
/// ## Color mapping
/// | State                              | Color            | Animation    |
/// |------------------------------------|------------------|--------------|
/// | `isStreaming == true`              | accent           | pulse loop   |
/// | `.active` (not streaming)          | warning (yellow) | none         |
/// | `.error`                           | error (red)      | none         |
/// | `.completed` / `.cancelled`        | textTertiary     | none         |
///
/// ## Size modes
/// - `.compact` — dot only (8 pt diameter)
/// - `.full`    — dot + status label
struct SessionStatusBadge: View {

    // MARK: - Size Mode

    enum SizeMode {
        /// Dot-only indicator; smallest footprint, suits dense layouts.
        case compact
        /// Dot accompanied by a short status label.
        case full
    }

    // MARK: - Input

    let sessionStatus: SessionStatus
    let isStreaming: Bool
    var sizeMode: SizeMode = .compact

    // MARK: - State

    @State private var isPulsing = false
    @State private var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Derived properties

    private var shouldAnimate: Bool {
        isStreaming && !reduceMotion && !isLowPowerMode && scenePhase == .active
    }

    private var dotColor: Color {
        if isStreaming { return theme.accent }
        switch sessionStatus {
        case .active:    return theme.warning
        case .error:     return theme.error
        case .completed, .cancelled: return theme.textTertiary
        }
    }

    private var statusLabel: String {
        if isStreaming { return "Streaming" }
        switch sessionStatus {
        case .active:    return "Waiting"
        case .error:     return "Error"
        case .completed: return "Done"
        case .cancelled: return "Cancelled"
        }
    }

    private var accessibilityDescription: String {
        if isStreaming { return "Session is streaming" }
        switch sessionStatus {
        case .active:    return "Session is waiting for input"
        case .error:     return "Session has an error"
        case .completed: return "Session completed"
        case .cancelled: return "Session cancelled"
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: theme.spacingXS) {
            dot
            if sizeMode == .full {
                Text(statusLabel)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(dotColor)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .onAppear { startPulseIfNeeded() }
        .onDisappear { isPulsing = false }
        .onChange(of: isStreaming) { _, streaming in
            if streaming {
                startPulseIfNeeded()
            } else {
                stopPulse()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                startPulseIfNeeded()
            } else {
                stopPulse()
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: Notification.Name.NSProcessInfoPowerStateDidChange
        )) { _ in
            isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            if isLowPowerMode { stopPulse() }
        }
    }

    // MARK: - Subviews

    private var dot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
            .opacity(isPulsing ? 1.0 : (isStreaming ? 0.3 : 1.0))
            .scaleEffect(isPulsing ? 1.1 : 1.0)
    }

    // MARK: - Helpers

    private func startPulseIfNeeded() {
        guard shouldAnimate else { return }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }

    private func stopPulse() {
        if reduceMotion || isLowPowerMode {
            isPulsing = false
        } else {
            withAnimation(.default) {
                isPulsing = false
            }
        }
    }
}

// MARK: - Preview

#Preview("All States") {
    VStack(alignment: .leading, spacing: 12) {
        Group {
            Text("Compact").font(.caption.bold())
            HStack(spacing: 16) {
                SessionStatusBadge(sessionStatus: .active, isStreaming: true, sizeMode: .compact)
                SessionStatusBadge(sessionStatus: .active, isStreaming: false, sizeMode: .compact)
                SessionStatusBadge(sessionStatus: .error, isStreaming: false, sizeMode: .compact)
                SessionStatusBadge(sessionStatus: .completed, isStreaming: false, sizeMode: .compact)
                SessionStatusBadge(sessionStatus: .cancelled, isStreaming: false, sizeMode: .compact)
            }
        }
        Divider()
        Group {
            Text("Full").font(.caption.bold())
            VStack(alignment: .leading, spacing: 8) {
                SessionStatusBadge(sessionStatus: .active, isStreaming: true, sizeMode: .full)
                SessionStatusBadge(sessionStatus: .active, isStreaming: false, sizeMode: .full)
                SessionStatusBadge(sessionStatus: .error, isStreaming: false, sizeMode: .full)
                SessionStatusBadge(sessionStatus: .completed, isStreaming: false, sizeMode: .full)
                SessionStatusBadge(sessionStatus: .cancelled, isStreaming: false, sizeMode: .full)
            }
        }
    }
    .padding()
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
