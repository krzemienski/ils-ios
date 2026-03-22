import SwiftUI
import CoreImage.CIFilterBuiltins
import ILSShared

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

/// Settings screen for configuring and managing Cloudflare tunnel remote access.
///
/// Allows users to expose the local ILS backend through a Cloudflare tunnel so it can be
/// reached from any device without port-forwarding or VPN configuration. Supports two tunnel
/// modes: a **quick tunnel** (temporary random `trycloudflare.com` URL, no account required)
/// and a **named tunnel** (stable custom domain backed by a Cloudflare account and API token).
///
/// ## Topics
/// ### State
/// - ``viewModel`` - Manages tunnel operations via `TunnelSettingsViewModel`
/// - ``qrImage`` - QR code image for the active tunnel URL
/// - ``showCopiedToast`` - Controls clipboard-copy toast visibility
struct TunnelSettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = TunnelSettingsViewModel()

    // MARK: - UI-only State

    @State private var showCopiedToast = false
    @State private var qrImage: PlatformImage?
    @State private var showSetupWizard = false
    @State private var pulseAnimation = false
    @State private var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var troubleshootingExpanded = false
    @State private var dnsHelperExpanded = false

    private var shouldAnimatePulse: Bool {
        !reduceMotion && !isLowPowerMode && scenePhase == .active
    }

    private enum FocusedField: Hashable {
        case cfToken, cfTunnelName, cfDomain
    }
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                // SEC-MED-2: Banner for Keychain migration errors.
                if let keychainError = viewModel.keychainMigrationError {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.warning)
                        Text(keychainError)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Button {
                            viewModel.keychainMigrationError = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(theme.textTertiary)
                        }
                        .accessibilityLabel("Dismiss error")
                    }
                    .padding(theme.spacingSM)
                    .background(theme.warning.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }

                quickTunnelSection
                if viewModel.isRunning, let url = viewModel.tunnelURL {
                    tunnelInfoSection(url: url)
                }
                if viewModel.notInstalled {
                    installSection
                }
                if viewModel.isRunning && viewModel.tunnelMode == "named" {
                    dnsHelperSection
                }
                if viewModel.isRunning && !viewModel.accessLog.isEmpty {
                    accessLogSection
                }
                customDomainSection
                troubleshootingSection
                howItWorksSection
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Remote Access")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toast(isPresented: $showCopiedToast, message: "URL copied to clipboard")
        .sheet(isPresented: $showSetupWizard) {
            TunnelSetupWizardView()
                .environment(appState)
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            viewModel.loadCustomDomainSettings()
            await viewModel.fetchStatus()
            // Generate initial QR if tunnel is already running
            if let url = viewModel.tunnelURL {
                generateQRAsync(from: url)
            }
            viewModel.startStatusPolling()
        }
        .onDisappear {
            viewModel.stopStatusPolling()
        }
        .onChange(of: viewModel.tunnelURL) { _, newURL in
            if let url = newURL {
                generateQRAsync(from: url)
            } else {
                qrImage = nil
            }
        }
        .screenshotProtected()
    }

    // MARK: - Connection State Indicator

    @ViewBuilder
    private var connectionStateIndicator: some View {
        switch viewModel.connectionState {
        case .connecting, .reconnecting:
            ProgressView()
                .scaleEffect(0.7)
                .tint(theme.accent)
        case .connected:
            ZStack {
                Circle()
                    .fill(theme.success.opacity(pulseAnimation ? 0 : 0.4))
                    .frame(width: 18, height: 18)
                    .scaleEffect(pulseAnimation ? 1.6 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
                Circle()
                    .fill(theme.success)
                    .frame(width: 10, height: 10)
            }
            .onAppear { startPulseIfNeeded() }
            .onDisappear { pulseAnimation = false }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    startPulseIfNeeded()
                } else {
                    pulseAnimation = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: Notification.Name.NSProcessInfoPowerStateDidChange
            )) { _ in
                isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                if isLowPowerMode { pulseAnimation = false }
            }
        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(theme.error)
                .font(.system(size: theme.fontBody))
        case .disconnected:
            Circle()
                .fill(theme.textTertiary)
                .frame(width: 10, height: 10)
        }
    }

    // MARK: - Pulse Animation Helpers

    private func startPulseIfNeeded() {
        guard shouldAnimatePulse else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
    }

    // MARK: - Quick Tunnel Section

    @ViewBuilder
    private var quickTunnelSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Tunnel")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    connectionStateIndicator
                        .frame(width: 20, height: 20)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Tunnel")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text(connectionStateLabel)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(connectionStateLabelColor)
                    }

                    Spacer()

                    // Set Up wizard button
                    Button {
                        showSetupWizard = true
                    } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.accent)
                            .padding(6)
                            .background(theme.accent.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Open setup wizard")

                    if viewModel.isToggling {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(theme.accent)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { viewModel.isRunning },
                            set: { newValue in
                                HapticManager.selection()
                                Task {
                                    if newValue {
                                        await viewModel.startTunnel()
                                    } else {
                                        await viewModel.stopTunnel()
                                    }
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(theme.success)
                        .accessibilityLabel("Enable quick tunnel")
                    }
                }

                // Health metrics row
                if viewModel.isRunning {
                    HStack(spacing: theme.spacingSM) {
                        if let latency = viewModel.latencyMs {
                            latencyBadge(ms: latency)
                        }
                        if let uptime = viewModel.uptime {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: theme.fontCaption - 1))
                                    .foregroundStyle(theme.textTertiary)
                                Text(viewModel.formatUptime(uptime))
                                    .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        if viewModel.isAutoReconnecting {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(theme.accent)
                                Text("Reconnecting…")
                                    .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                }

                if let error = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.warning)
                        Text(error)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.error)
                    }
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Exposes your local backend through a Cloudflare tunnel so you can access it from anywhere.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private var connectionStateLabel: String {
        switch viewModel.connectionState {
        case .connected: return "Connected"
        case .connecting: return "Connecting…"
        case .reconnecting: return "Reconnecting…"
        case .error: return "Connection error"
        case .disconnected: return "Create a temporary public URL"
        }
    }

    private var connectionStateLabelColor: Color {
        switch viewModel.connectionState {
        case .connected: return theme.success
        case .connecting, .reconnecting: return theme.accent
        case .error: return theme.error
        case .disconnected: return theme.textSecondary
        }
    }

    @ViewBuilder
    private func latencyBadge(ms: Int) -> some View {
        let color: Color = ms < 100 ? theme.success : ms < 300 ? theme.warning : theme.error
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.system(size: theme.fontCaption - 2))
                .foregroundStyle(color)
            Text("\(ms)ms")
                .font(.system(size: theme.fontCaption - 1, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Tunnel Info Section

    @ViewBuilder
    private func tunnelInfoSection(url: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Connection Info")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                // Status with animated indicator
                HStack {
                    connectionStateIndicator
                        .frame(width: 20, height: 20)
                    Text("Running")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.success)
                    if let mode = viewModel.tunnelMode {
                        Text(mode.capitalized)
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textOnAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(mode == "named" ? theme.success : theme.accent)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if let uptime = viewModel.uptime {
                        Text(viewModel.formatUptime(uptime))
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                // Health metrics row
                if viewModel.latencyMs != nil {
                    HStack(spacing: theme.spacingSM) {
                        if let latency = viewModel.latencyMs {
                            latencyBadge(ms: latency)
                        }
                        Spacer()
                    }
                }

                // URL
                VStack(alignment: .leading, spacing: 6) {
                    Text("Public URL")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                    Text(url)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                        .textSelection(.enabled)
                }

                // Copy button
                Button {
                    #if os(iOS)
                    UIPasteboard.general.string = url
                    #else
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url, forType: .string)
                    #endif
                    // SA-MED-4: ToastModifier handles auto-dismiss — no manual timer needed.
                    showCopiedToast = true
                } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .accessibilityLabel("Copy tunnel URL to clipboard")

                // QR Code
                if let qrImage = qrImage {
                    HStack {
                        Spacer()
                        #if os(iOS)
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        #else
                        Image(nsImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        #endif
                        Spacer()
                    }
                    .padding(.vertical, theme.spacingSM)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Install Section

    @ViewBuilder
    private var installSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Installation Required")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.warning)
                    Text("cloudflared not installed")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.warning)
                }

                Text("The cloudflared CLI tool is required to create tunnels. Install it via Homebrew or download from Cloudflare.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                if let installURL = viewModel.installURL, let url = URL(string: installURL) {
                    Link(destination: url) {
                        HStack {
                            Text("Install cloudflared")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick install with Homebrew:")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                    Text("brew install cloudflared")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .padding(theme.spacingSM)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - DNS Helper Section

    @ViewBuilder
    private var dnsHelperSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("DNS Configuration")

            VStack(alignment: .leading, spacing: 0) {
                DisclosureGroup(isExpanded: $dnsHelperExpanded) {
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        Text("Your named tunnel requires DNS records in your Cloudflare dashboard. If the tunnel is active but unreachable, verify these settings.")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.top, theme.spacingSM)

                        dnsStep(number: "1", title: "CNAME record",
                                detail: "Add a CNAME pointing \(viewModel.cfDomain.isEmpty ? "your domain" : viewModel.cfDomain) to your tunnel ID (.cfargotunnel.com).")
                        dnsStep(number: "2", title: "Proxy enabled",
                                detail: "Ensure the Proxy status (orange cloud) is enabled in your Cloudflare DNS dashboard.")
                        dnsStep(number: "3", title: "SSL/TLS mode",
                                detail: "Set SSL/TLS encryption mode to Full or Full (strict) for secure connections.")
                        dnsStep(number: "4", title: "Verify propagation",
                                detail: "DNS changes may take up to 5 minutes. Use 'dig \(viewModel.cfDomain.isEmpty ? "yourdomain.com" : viewModel.cfDomain)' to confirm.")
                    }
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "network")
                            .foregroundStyle(theme.accent)
                        Text("DNS Setup Guide")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                    }
                }
                .tint(theme.textTertiary)
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Named tunnels require DNS configuration in your Cloudflare account.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    @ViewBuilder
    private func dnsStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: theme.fontCaption - 1, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textOnAccent)
                .frame(width: 18, height: 18)
                .background(theme.accent)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(detail)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    // MARK: - Access Log Section

    @ViewBuilder
    private var accessLogSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Activity Log")

            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.accessLog.prefix(8)) { entry in
                    logEntryRow(entry: entry)
                    if entry.id != viewModel.accessLog.prefix(8).last?.id {
                        Divider()
                            .background(theme.borderSubtle)
                    }
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            if viewModel.accessLog.count > 8 {
                Text("Showing 8 of \(viewModel.accessLog.count) entries.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func logEntryRow(entry: TunnelLogEntry) -> some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            Image(systemName: logLevelIcon(entry.level))
                .font(.system(size: theme.fontCaption - 1))
                .foregroundStyle(logLevelColor(entry.level))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.system(size: theme.fontCaption - 1, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                Text(entry.timestamp)
                    .font(.system(size: theme.fontCaption - 2, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private func logLevelIcon(_ level: TunnelLogLevel) -> String {
        switch level {
        case .debug: return "chevron.right"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }

    private func logLevelColor(_ level: TunnelLogLevel) -> Color {
        switch level {
        case .debug: return theme.textTertiary
        case .info: return theme.accent
        case .warning: return theme.warning
        case .error: return theme.error
        }
    }

    // MARK: - Custom Domain Section

    @ViewBuilder
    private var customDomainSection: some View {
        @Bindable var vm = viewModel
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Advanced")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        Text("Use a Cloudflare account and API token for a stable custom domain instead of a random trycloudflare.com URL.")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)

                        fieldGroup(label: "API Token") {
                            SecureField("Cloudflare API token", text: $vm.cfToken)
                                .textContentType(.password)
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                                .padding(theme.spacingSM)
                                .background(theme.bgSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                                .focusRing(isFocused: focusedField == .cfToken, cornerRadius: theme.cornerRadiusSmall)
                                .focused($focusedField, equals: .cfToken)
                                .accessibilityLabel("Cloudflare API token")
                        }

                        fieldGroup(label: "Tunnel Name") {
                            TextField("my-ils-tunnel", text: $vm.cfTunnelName)
                                #if os(iOS)
                                .autocapitalization(.none)
                                #endif
                                .autocorrectionDisabled()
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                                .padding(theme.spacingSM)
                                .background(theme.bgSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                                .focusRing(isFocused: focusedField == .cfTunnelName, cornerRadius: theme.cornerRadiusSmall)
                                .focused($focusedField, equals: .cfTunnelName)
                                .accessibilityLabel("Tunnel name")
                        }

                        fieldGroup(label: "Custom Domain") {
                            TextField("ils.example.com", text: $vm.cfDomain)
                                #if os(iOS)
                                .autocapitalization(.none)
                                #endif
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .keyboardType(.URL)
                                #endif
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                                .padding(theme.spacingSM)
                                .background(theme.bgSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                                .focusRing(isFocused: focusedField == .cfDomain, cornerRadius: theme.cornerRadiusSmall)
                                .focused($focusedField, equals: .cfDomain)
                                .accessibilityLabel("Custom domain")
                        }
                        // Save & Start button
                        Button {
                            Task { await viewModel.startNamedTunnel() }
                        } label: {
                            HStack {
                                if viewModel.isToggling {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(theme.textOnAccent)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text("Save & Start Named Tunnel")
                            }
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacingSM)
                            .background(viewModel.isCustomDomainValid ? theme.accent : theme.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                        }
                        .disabled(!viewModel.isCustomDomainValid || viewModel.isToggling)
                        .accessibilityLabel("Save and start named tunnel")
                    }
                    .padding(.top, theme.spacingSM)
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "globe")
                            .foregroundStyle(theme.accent)
                        Text("Custom Domain")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                    }
                }
                .tint(theme.textTertiary)
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Requires a Cloudflare account with a registered domain.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Troubleshooting Section

    @ViewBuilder
    private var troubleshootingSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Troubleshooting")

            VStack(alignment: .leading, spacing: 0) {
                DisclosureGroup(isExpanded: $troubleshootingExpanded) {
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        troubleshootingIssue(
                            title: "Tunnel won't start",
                            detail: "Ensure cloudflared is installed and accessible in your PATH. Try running 'cloudflared version' in Terminal. If missing, install via Homebrew: brew install cloudflared.",
                            icon: "play.slash"
                        )
                        Divider().background(theme.borderSubtle)
                        troubleshootingIssue(
                            title: "URL not reachable from outside",
                            detail: "Check that your firewall is not blocking outbound connections on port 443. Cloudflare tunnels require outbound HTTPS access.",
                            icon: "wifi.slash"
                        )
                        Divider().background(theme.borderSubtle)
                        troubleshootingIssue(
                            title: "High latency or slow response",
                            detail: "Quick tunnels route through Cloudflare's nearest edge. Consider using a named tunnel with a custom domain for better routing control.",
                            icon: "bolt.slash"
                        )
                        Divider().background(theme.borderSubtle)
                        troubleshootingIssue(
                            title: "Named tunnel authentication failed",
                            detail: "Verify your Cloudflare API token has the 'Cloudflare Tunnel' permission. Tokens can be created in the Cloudflare dashboard under My Profile → API Tokens.",
                            icon: "lock.slash"
                        )
                        Divider().background(theme.borderSubtle)
                        troubleshootingIssue(
                            title: "Tunnel disconnects frequently",
                            detail: "Auto-reconnect is enabled and will restore your tunnel when network connectivity is restored. If disconnects persist, check your internet connection stability.",
                            icon: "arrow.counterclockwise"
                        )
                    }
                    .padding(.top, theme.spacingSM)
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "wrench.and.screwdriver")
                            .foregroundStyle(theme.textSecondary)
                        Text("Common Issues")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                    }
                }
                .tint(theme.textTertiary)
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    @ViewBuilder
    private func troubleshootingIssue(title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 20)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(detail)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - How It Works Section

    @ViewBuilder
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("How It Works")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                infoRow(icon: "1.circle.fill", text: "Starts a cloudflared tunnel on your Mac")
                infoRow(icon: "2.circle.fill", text: "Cloudflare assigns a temporary public URL")
                infoRow(icon: "3.circle.fill", text: "Access your ILS backend from any device using the URL or QR code")
                infoRow(icon: "4.circle.fill", text: "Traffic is encrypted end-to-end via Cloudflare's network")
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Quick tunnels use randomly generated URLs that change each time. Use a custom domain for a stable URL.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
                .kerning(1)
    }

    @ViewBuilder
    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .frame(width: 20)
            Text(text)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - QR Code Generation

    // UIPERF-01: nonisolated to allow safe calls from Task.detached without Swift 6 warnings.
    private nonisolated static let ciContext = CIContext()

    // UIPERF-01: nonisolated static — CIFilter/CIContext are thread-safe, called from detached tasks.
    private nonisolated static func generateQRCode(from string: String) -> PlatformImage? {
        let filter = CIFilter.qrCodeGenerator()

        guard let data = string.data(using: .ascii) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: scale)

        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        #if os(iOS)
        return UIImage(cgImage: cgImage)
        #else
        return NSImage(cgImage: cgImage, size: NSSize(width: scaledImage.extent.width, height: scaledImage.extent.height))
        #endif
    }

    /// Generates QR code off the main thread and updates the image state.
    private func generateQRAsync(from url: String) {
        Task.detached(priority: .userInitiated) {
            let image = TunnelSettingsView.generateQRCode(from: url)
            await MainActor.run { qrImage = image }
        }
    }
}

#Preview {
    NavigationStack {
        TunnelSettingsView()
            .environment(AppState())
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
