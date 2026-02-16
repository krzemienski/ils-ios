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

/// Settings screen for managing Cloudflare tunnel remote access.
struct TunnelSettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var isRunning = false
    @State private var tunnelURL: String?
    @State private var uptime: Int?
    @State private var tunnelMode: String?
    @State private var isLoading = false
    @State private var isToggling = false
    @State private var errorMessage: String?
    @State private var notInstalled = false
    @State private var installURL: String?
    @State private var showCopiedToast = false
    @State private var toastTask: Task<Void, Never>?
    @State private var qrImage: PlatformImage?

    // Custom domain fields
    @State private var cfToken = ""
    @State private var cfTunnelName = ""
    @State private var cfDomain = ""

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                quickTunnelSection
                if isRunning, let url = tunnelURL {
                    tunnelInfoSection(url: url)
                }
                if notInstalled {
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
            loadCustomDomainSettings()
            await fetchStatus()
        }
        .onChange(of: tunnelURL) { _, newURL in
            if let url = newURL {
                qrImage = Self.generateQRCode(from: url)
            } else {
                qrImage = nil
            }
        }
        .screenshotProtected()
        .onDisappear {
            toastTask?.cancel()
        }
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

                    if isToggling {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(theme.accent)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { isRunning },
                            set: { newValue in
                                Task {
                                    if newValue {
                                        await startTunnel()
                                    } else {
                                        await stopTunnel()
                                    }
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(theme.success)
                        .accessibilityLabel("Enable quick tunnel")
                    }
                }

                if let error = errorMessage {
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
                    if let mode = tunnelMode {
                        Text(mode.capitalized)
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textOnAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(mode == "named" ? theme.success : theme.accent)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if let uptime = uptime {
                        Text(formatUptime(uptime))
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
                    showCopiedToast = true
                    toastTask?.cancel()
                    toastTask = Task {
                        try? await Task.sleep(for: .seconds(2))
                        guard !Task.isCancelled else { return }
                        showCopiedToast = false
                    }
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

                if let installURL = installURL, let url = URL(string: installURL) {
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
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Advanced")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        Text("Use a Cloudflare account and API token for a stable custom domain instead of a random trycloudflare.com URL.")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)

                        fieldGroup(label: "API Token") {
                            SecureField("Cloudflare API token", text: $cfToken)
                                .textContentType(.password)
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                                .padding(theme.spacingSM)
                                .background(theme.bgSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                                .accessibilityLabel("Cloudflare API token")
                        }

                        fieldGroup(label: "Tunnel Name") {
                            TextField("my-ils-tunnel", text: $cfTunnelName)
                                #if os(iOS)
                                .autocapitalization(.none)
                                #endif
                                .autocorrectionDisabled()
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                                .padding(theme.spacingSM)
                                .background(theme.bgSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                                .accessibilityLabel("Tunnel name")
                        }

                        fieldGroup(label: "Custom Domain") {
                            TextField("ils.example.com", text: $cfDomain)
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
                                .accessibilityLabel("Custom domain")
                        }
                        // Save & Start button
                        Button {
                            Task { await startNamedTunnel() }
                        } label: {
                            HStack {
                                if isToggling {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text("Save & Start Named Tunnel")
                            }
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacingSM)
                            .background(isCustomDomainValid ? theme.accent : theme.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                        }
                        .disabled(!isCustomDomainValid || isToggling)
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

    // MARK: - Computed Properties

    private var isCustomDomainValid: Bool {
        !cfToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cfTunnelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cfDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func fetchStatus() async {
        do {
            let status: TunnelStatusResponse = try await appState.apiClient.get("/tunnel/status")
            isRunning = status.running
            tunnelURL = status.url
            uptime = status.uptime
            tunnelMode = status.mode
            notInstalled = false
            errorMessage = nil
            if let url = status.url {
                qrImage = Self.generateQRCode(from: url)
            }
        } catch let apiError as APIError {
            if case .httpError(let code) = apiError, code == 404 {
                notInstalled = true
                installURL = "https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startTunnel() async {
        isToggling = true
        errorMessage = nil
        defer { isToggling = false }

        do {
            let request = TunnelStartRequest()
            let response: TunnelStartResponse = try await appState.apiClient.post("/tunnel/start", body: request)
            tunnelURL = response.url
            isRunning = true
            notInstalled = false
            qrImage = Self.generateQRCode(from: response.url)
        } catch let apiError as APIError {
            if case .httpError(let code) = apiError, code == 404 {
                notInstalled = true
                installURL = "https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
            } else {
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopTunnel() async {
        isToggling = true
        errorMessage = nil
        defer { isToggling = false }

        do {
            let request = TunnelStartRequest()
            let _: TunnelStopResponse = try await appState.apiClient.post("/tunnel/stop", body: request)
            isRunning = false
            tunnelURL = nil
            uptime = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startNamedTunnel() async {
        isToggling = true
        errorMessage = nil
        defer { isToggling = false }

        // Persist custom domain settings — token goes to Keychain, others to UserDefaults
        let defaults = UserDefaults.standard
        try? await KeychainService.shared.saveCredential(key: "cfToken", value: cfToken)
        defaults.set(cfTunnelName, forKey: "cfTunnelName")
        defaults.set(cfDomain, forKey: "cfDomain")

        do {
            let request = TunnelStartRequest(
                token: cfToken.trimmingCharacters(in: .whitespacesAndNewlines),
                tunnelName: cfTunnelName.trimmingCharacters(in: .whitespacesAndNewlines),
                domain: cfDomain.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let response: TunnelStartResponse = try await appState.apiClient.post("/tunnel/start", body: request)
            tunnelURL = response.url
            isRunning = true
            notInstalled = false
            qrImage = Self.generateQRCode(from: response.url)
        } catch let apiError as APIError {
            if case .httpError(let code) = apiError, code == 404 {
                notInstalled = true
                installURL = "https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
            } else {
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadCustomDomainSettings() {
        let defaults = UserDefaults.standard
        // Load token from Keychain (migrate from UserDefaults if present)
        Task {
            if let token = try? await KeychainService.shared.getCredential(key: "cfToken") {
                await MainActor.run { cfToken = token }
            } else if let legacyToken = defaults.string(forKey: "cfToken"), !legacyToken.isEmpty {
                // Migrate legacy token from UserDefaults to Keychain
                try? await KeychainService.shared.saveCredential(key: "cfToken", value: legacyToken)
                defaults.removeObject(forKey: "cfToken")
                await MainActor.run { cfToken = legacyToken }
            }
        }
        cfTunnelName = defaults.string(forKey: "cfTunnelName") ?? ""
        cfDomain = defaults.string(forKey: "cfDomain") ?? ""
    }

    // MARK: - QR Code Generation

    private static let ciContext = CIContext()

    private static func generateQRCode(from string: String) -> PlatformImage? {
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

    // MARK: - Helpers

    private func formatUptime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
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
