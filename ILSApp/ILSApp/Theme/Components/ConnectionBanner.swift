import SwiftUI

/// Slim connection status banner that slides down from top.
/// Shows "Reconnecting..." when disconnected, "Connected" when reconnected (auto-dismisses after 2s).
struct ConnectionBanner: View {
    let isConnected: Bool
    @Environment(\.theme) private var theme: any AppTheme

    @State private var showConnectedBanner = false
    @State private var wasDisconnected = false

    private var shouldShow: Bool {
        !isConnected || showConnectedBanner
    }

    var body: some View {
        if shouldShow {
            HStack(spacing: 8) {
                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(theme.success)
                    Text("Connected")
                        .font(.system(size: theme.fontCaption, weight: .medium))
                        .foregroundColor(theme.success)
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                    Text("Reconnecting...")
                        .font(.system(size: theme.fontCaption, weight: .medium))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.horizontal, theme.spacingMD)
            .frame(height: 36)
            .background(
                Group {
                    if isConnected {
                        theme.success.opacity(0.15)
                    } else {
                        theme.error.opacity(0.2)
                    }
                }
                .background(.ultraThinMaterial)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isConnected ? "Connected to server" : "Disconnected from server")
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

/// View modifier that manages ConnectionBanner state and auto-dismiss logic.
struct ConnectionBannerModifier: ViewModifier {
    let isConnected: Bool
    @Environment(\.theme) private var theme: any AppTheme

    @State private var showConnectedBanner = false
    @State private var wasDisconnected = false
    @State private var dismissTask: Task<Void, Never>?

    private var shouldShowBanner: Bool {
        !isConnected || showConnectedBanner
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top) {
                if shouldShowBanner {
                    HStack(spacing: 8) {
                        if isConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(theme.success)
                            Text("Connected")
                                .font(.system(size: theme.fontCaption, weight: .medium))
                                .foregroundColor(theme.success)
                        } else {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                            Text("Reconnecting...")
                                .font(.system(size: theme.fontCaption, weight: .medium))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, theme.spacingMD)
                    .frame(height: 36)
                    .background(
                        Group {
                            if isConnected {
                                theme.success.opacity(0.15)
                            } else {
                                theme.error.opacity(0.2)
                            }
                        }
                        .background(.ultraThinMaterial)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(isConnected ? "Connected to server" : "Disconnected from server, reconnecting")
                    .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: shouldShowBanner)
            .onChange(of: isConnected) { oldValue, newValue in
                if !oldValue && newValue {
                    showConnectedBanner = true
                    wasDisconnected = false
                    dismissTask?.cancel()
                    dismissTask = Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        guard !Task.isCancelled else { return }
                        withAnimation {
                            showConnectedBanner = false
                        }
                    }
                } else if oldValue && !newValue {
                    wasDisconnected = true
                    showConnectedBanner = false
                    dismissTask?.cancel()
                }
            }
    }
}

extension View {
    /// Adds a slim connection banner that slides down when disconnected
    /// and auto-dismisses after reconnection.
    func connectionBanner(isConnected: Bool) -> some View {
        modifier(ConnectionBannerModifier(isConnected: isConnected))
    }
}
