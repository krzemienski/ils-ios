import SwiftUI
import ILSShared
import TipKit

// MARK: - Connection Section

/// Settings section that manages backend server URL configuration and connection testing.
///
/// Renders the "Backend Connection" group, including a URL text field bound to ``serverURL``,
/// a live connection-status indicator driven by `AppState.isConnected`, and a "Test Connection"
/// button that delegates to ``onTestConnection``. When the app is not connected a TipKit
/// ``ServerSetupTip`` tip card is shown above the controls to guide first-time setup.
///
/// A companion ``remoteAccessSection`` computed property renders a separate "Remote Access"
/// group containing a `NavigationLink` that pushes `TunnelSettingsView` for Cloudflare
/// Tunnel configuration.
///
/// ## Topics
/// ### Bindings
/// - ``serverURL`` - Two-way binding to the backend server URL string
///
/// ### Input Properties
/// - ``viewModel`` - Provides `isTestingConnection` state for the test button
///
/// ### Callbacks
/// - ``onTestConnection`` - Invoked when the user taps "Test Connection"
/// - ``onSaveServerSettings`` - Invoked when the URL text field is submitted
struct SettingsConnectionSection: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState
    /// View model supplying connection-testing state (e.g. `isTestingConnection`).
    var viewModel: SettingsViewModel
    /// Two-way binding to the backend server URL being edited.
    @Binding var serverURL: String

    /// TipKit tip shown when the app is not yet connected to guide initial server setup.
    private let serverSetupTip = ServerSetupTip()

    @FocusState private var isServerURLFocused: Bool

    /// Called when the user taps the "Test Connection" button.
    let onTestConnection: () -> Void
    /// Called when the URL text field's return key is pressed to persist the entered URL.
    let onSaveServerSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Backend Connection")

            if !appState.isConnected {
                TipView(serverSetupTip)
                    .tipBackground(theme.bgSecondary)
            }

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                    TextField("https://example.com or http://localhost:9999", text: $serverURL)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .textContentType(.URL)
                        #if os(iOS)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()
                        .foregroundStyle(theme.textPrimary)
                        .padding(theme.spacingSM)
                        .background(theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        .focusRing(isFocused: isServerURLFocused, cornerRadius: theme.cornerRadiusSmall)
                        .focused($isServerURLFocused)
                        .accessibilityLabel("Server URL")
                        .onSubmit { onSaveServerSettings() }
                }

                HStack {
                    Text("Status")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isConnected ? theme.success : theme.error)
                            .frame(width: 8, height: 8)
                        Text(appState.isConnected ? "Connected" : "Disconnected")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Connection status: \(appState.isConnected ? "Connected" : "Disconnected")")
                }

                Button {
                    onTestConnection()
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        if viewModel.isTestingConnection {
                            ProgressView()
                                .tint(theme.textOnAccent)
                                .controlSize(.small)
                        }
                        Text(viewModel.isTestingConnection ? "Testing..." : "Test Connection")
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .disabled(viewModel.isTestingConnection)
                .opacity(viewModel.isTestingConnection ? 0.7 : 1.0)
                .accessibilityLabel("Test connection to backend server")
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Configure the ILS backend server address")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Remote Access

    var remoteAccessSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Remote Access")

            NavigationLink {
                TunnelSettingsView()
            } label: {
                HStack(spacing: theme.spacingMD) {
                    Image(systemName: "network")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.info)
                        .frame(width: 28, height: 28)
                        .background(theme.info.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remote Access")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("Cloudflare Tunnel")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
                .kerning(1)
    }
}
