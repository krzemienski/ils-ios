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

    @State private var viewModel = TunnelSettingsViewModel()

    // MARK: - UI-only State

    @State private var showCopiedToast = false
    @State private var qrImage: PlatformImage?

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
                customDomainSection
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
        .task {
            viewModel.configure(client: appState.apiClient)
            viewModel.loadCustomDomainSettings()
            await viewModel.fetchStatus()
            // Generate initial QR if tunnel is already running
            if let url = viewModel.tunnelURL {
                generateQRAsync(from: url)
            }
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

    // MARK: - Quick Tunnel Section

    @ViewBuilder
    private var quickTunnelSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Tunnel")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Tunnel")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("Create a temporary public URL")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }

                    Spacer()

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

    // MARK: - Tunnel Info Section

    @ViewBuilder
    private func tunnelInfoSection(url: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Connection Info")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                // Status
                HStack {
                    Circle()
                        .fill(theme.success)
                        .frame(width: 10, height: 10)
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
