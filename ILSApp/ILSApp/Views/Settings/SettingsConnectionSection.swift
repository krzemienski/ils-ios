import SwiftUI
import ILSShared
import TipKit

// MARK: - Connection Section

struct SettingsConnectionSection: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState
    var viewModel: SettingsViewModel
    @Binding var serverURL: String

    private let serverSetupTip = ServerSetupTip()

    @FocusState private var isServerURLFocused: Bool

    let onTestConnection: () -> Void
    let onSaveServerSettings: () -> Void
    var onSyncNow: (() -> Void)? = nil

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

                AccentButton("Test Connection", isLoading: viewModel.isTestingConnection) {
                    onTestConnection()
                }

                if appState.isConnected, let syncNow = onSyncNow {
                    Divider().background(theme.borderSubtle)
                    Button {
                        syncNow()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            Text("Sync Now")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        }
                        .foregroundStyle(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                    }
                    .accessibilityLabel("Sync data from server")
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Configure the ILS backend server address")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            // PLAT-04: Cellular data toggle — controls whether network requests
            // are allowed over cellular connections.
            #if os(iOS)
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Toggle(isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "allowsCellularAccess") },
                    set: { newValue in
                        UserDefaults.standard.set(newValue, forKey: "allowsCellularAccess")
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Cellular Data")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("Allow connections over cellular networks")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .tint(theme.accent)
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
            #endif
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
