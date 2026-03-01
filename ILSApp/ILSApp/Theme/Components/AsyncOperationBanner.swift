import SwiftUI

// MARK: - AsyncOperationState

/// Represents the lifecycle state of an async operation (e.g., SSE streaming, network connection).
///
/// Designed as a generic alternative to `SSEClient.ConnectionState` so that banners can be
/// reused across contexts that don't directly depend on SSEClient.
enum AsyncOperationState: Equatable {
    /// The operation is initiating a connection.
    case connecting
    /// The operation is running and receiving data.
    case active
    /// The operation lost connectivity and is retrying.
    case reconnecting(attempt: Int)
    /// The operation failed and is no longer running.
    case failed
}

// MARK: - AsyncOperationBanner

/// A reusable status banner that communicates the state of an async operation.
///
/// Reproduces the visual design of `StreamingStatusBanner` but accepts the generic
/// ``AsyncOperationState`` rather than `SSEClient.ConnectionState`, making it suitable
/// for use in chat, teams, fleet, and any other streaming or long-running operation context.
///
/// ## Usage
/// ```swift
/// AsyncOperationBanner(
///     message: "Connecting to session…",
///     state: .connecting
/// )
///
/// AsyncOperationBanner(
///     message: "Streaming response",
///     state: .active,
///     tokenCount: 420,
///     elapsedSeconds: 3.7
/// )
/// ```
struct AsyncOperationBanner: View {
    /// The human-readable status string describing the current operation state.
    let message: String
    /// The current lifecycle state of the async operation.
    let state: AsyncOperationState
    /// Number of tokens received so far. Shown when greater than zero.
    var tokenCount: Int = 0
    /// Elapsed time in seconds for the operation. Shown alongside token count.
    var elapsedSeconds: Double = 0

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            Group {
                switch state {
                case .connecting, .active:
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(theme.accent)
                        .accessibilityIdentifier("async-operation-indicator")
                case .reconnecting:
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(theme.warning)
                case .failed:
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(theme.error)
                }
            }
            .frame(width: 16, height: 16)

            Text(message)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .accessibilityIdentifier("async-operation-status-text")

            Spacer()

            if tokenCount > 0 {
                Text("~\(tokenCount) tokens \u{2022} \(String(format: "%.1f", elapsedSeconds))s")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign).leading(.tight))
                    .foregroundStyle(theme.textTertiary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .accessibilityIdentifier("async-operation-stats-text")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgSecondary)
        .accessibilityIdentifier("async-operation-banner")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Private

    private var accessibilityLabel: String {
        switch state {
        case .connecting:
            return "Connecting: \(message)"
        case .active:
            return tokenCount > 0
                ? "Active: \(message), \(tokenCount) tokens, \(String(format: "%.1f", elapsedSeconds)) seconds"
                : "Active: \(message)"
        case .reconnecting(let attempt):
            return "Reconnecting, attempt \(attempt): \(message)"
        case .failed:
            return "Failed: \(message)"
        }
    }
}

// MARK: - SSEClient.ConnectionState + AsyncOperationState

extension SSEClient.ConnectionState {
    /// Maps an `SSEClient.ConnectionState` to the generic ``AsyncOperationState``.
    ///
    /// This allows views that accept ``AsyncOperationState`` to be driven directly
    /// by an SSE connection without coupling to `SSEClient`.
    var asAsyncOperationState: AsyncOperationState {
        switch self {
        case .connecting:
            return .connecting
        case .connected:
            return .active
        case .reconnecting(let attempt):
            return .reconnecting(attempt: attempt)
        case .disconnected:
            return .failed
        }
    }
}
