import SwiftUI
import CoreImage.CIFilterBuiltins

/// Settings screen for managing Cloudflare tunnel remote access.
struct TunnelSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRunning = false
    @State private var tunnelURL: String?
    @State private var uptime: Int?
    @State private var isLoading = false
    @State private var isToggling = false
    @State private var errorMessage: String?
    @State private var notInstalled = false
    @State private var installURL: String?
    @State private var showCopiedToast = false
    @State private var toastTask: Task<Void, Never>?
    @State private var qrImage: UIImage?

    // Custom domain fields
    @State private var cfToken = ""
    @State private var cfTunnelName = ""
    @State private var cfDomain = ""

    var body: some View {
        Form {
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
        .scrollContentBackground(.hidden)
        .background(ILSTheme.background)
        .navigationTitle("Remote Access")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toast(isPresented: $showCopiedToast, message: "URL copied to clipboard")
        .task {
            await fetchStatus()
        }
        .onChange(of: tunnelURL) { _, newURL in
            if let url = newURL {
                qrImage = Self.generateQRCode(from: url)
            } else {
                qrImage = nil
            }
        }
        .onDisappear {
            toastTask?.cancel()
        }
    }

    // MARK: - Quick Tunnel Section

    @ViewBuilder
    private var quickTunnelSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Tunnel")
                        .font(ILSTheme.bodyFont)
                    Text("Create a temporary public URL")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }

                Spacer()

                if isToggling {
                    ProgressView()
                        .scaleEffect(0.8)
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
                    .tint(ILSTheme.success)
                    .accessibilityLabel("Enable quick tunnel")
                }
            }

            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ILSTheme.warning)
                    Text(error)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.error)
                }
            }
        } header: {
            Text("Tunnel")
        } footer: {
            Text("Exposes your local backend through a Cloudflare tunnel so you can access it from anywhere.")
        }
    }

    // MARK: - Tunnel Info Section

    @ViewBuilder
    private func tunnelInfoSection(url: String) -> some View {
        Section {
            // Status
            HStack {
                Circle()
                    .fill(ILSTheme.success)
                    .frame(width: 10, height: 10)
                Text("Running")
                    .font(ILSTheme.bodyFont)
                    .foregroundColor(ILSTheme.success)
                Spacer()
                if let uptime = uptime {
                    Text(formatUptime(uptime))
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }

            // URL
            VStack(alignment: .leading, spacing: 6) {
                Text("Public URL")
                    .font(.caption)
                    .foregroundColor(ILSTheme.secondaryText)
                Text(url)
                    .font(ILSTheme.codeFont)
                    .foregroundColor(ILSTheme.accent)
                    .textSelection(.enabled)
            }

            // Copy button
            Button {
                UIPasteboard.general.string = url
                showCopiedToast = true
                toastTask?.cancel()
                toastTask = Task {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    showCopiedToast = false
                }
            } label: {
                Label("Copy URL", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Copy tunnel URL to clipboard")

            // QR Code (pre-generated, not computed in view body)
            if let qrImage = qrImage {
                HStack {
                    Spacer()
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .cornerRadius(ILSTheme.cornerRadiusSmall)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text("Connection Info")
        }
    }

    // MARK: - Install Section

    @ViewBuilder
    private var installSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ILSTheme.warning)
                    Text("cloudflared not installed")
                        .font(ILSTheme.bodyFont)
                        .foregroundColor(ILSTheme.warning)
                }

                Text("The cloudflared CLI tool is required to create tunnels. Install it via Homebrew or download from Cloudflare.")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)

                if let installURL = installURL, let url = URL(string: installURL) {
                    Link(destination: url) {
                        HStack {
                            Text("Install cloudflared")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick install with Homebrew:")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                    Text("brew install cloudflared")
                        .font(ILSTheme.codeFont)
                        .padding(8)
                        .background(ILSTheme.tertiaryBackground)
                        .cornerRadius(6)
                }
            }
        } header: {
            Text("Installation Required")
        }
    }

    // MARK: - Custom Domain Section

    @ViewBuilder
    private var customDomainSection: some View {
        Section {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Use a Cloudflare account and API token for a stable custom domain instead of a random trycloudflare.com URL.")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Token")
                            .font(.caption)
                            .foregroundColor(ILSTheme.secondaryText)
                        SecureField("Cloudflare API token", text: $cfToken)
                            .textContentType(.password)
                            .accessibilityLabel("Cloudflare API token")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tunnel Name")
                            .font(.caption)
                            .foregroundColor(ILSTheme.secondaryText)
                        TextField("my-ils-tunnel", text: $cfTunnelName)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Tunnel name")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Custom Domain")
                            .font(.caption)
                            .foregroundColor(ILSTheme.secondaryText)
                        TextField("ils.example.com", text: $cfDomain)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .accessibilityLabel("Custom domain")
                    }
                }
                .padding(.vertical, 4)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundColor(ILSTheme.accent)
                    Text("Custom Domain")
                        .font(ILSTheme.bodyFont)
                }
            }
        } header: {
            Text("Advanced")
        } footer: {
            Text("Requires a Cloudflare account with a registered domain.")
        }
    }

    // MARK: - How It Works Section

    @ViewBuilder
    private var howItWorksSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "1.circle.fill", text: "Starts a cloudflared tunnel on your Mac")
                infoRow(icon: "2.circle.fill", text: "Cloudflare assigns a temporary public URL")
                infoRow(icon: "3.circle.fill", text: "Access your ILS backend from any device using the URL or QR code")
                infoRow(icon: "4.circle.fill", text: "Traffic is encrypted end-to-end via Cloudflare's network")
            }
        } header: {
            Text("How It Works")
        } footer: {
            Text("Quick tunnels use randomly generated URLs that change each time. Use a custom domain for a stable URL.")
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(ILSTheme.accent)
                .frame(width: 20)
            Text(text)
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.secondaryText)
        }
    }

    // MARK: - Actions

    private func fetchStatus() async {
        do {
            let status: TunnelStatusDTO = try await appState.apiClient.get("/tunnel/status")
            isRunning = status.running
            tunnelURL = status.url
            uptime = status.uptime
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
            let emptyBody = EmptyTunnelRequest()
            let response: TunnelStartDTO = try await appState.apiClient.post("/tunnel/start", body: emptyBody)
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
            let emptyBody = EmptyTunnelRequest()
            let _: TunnelStopDTO = try await appState.apiClient.post("/tunnel/stop", body: emptyBody)
            isRunning = false
            tunnelURL = nil
            uptime = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - QR Code Generation

    private static let ciContext = CIContext()

    private static func generateQRCode(from string: String) -> UIImage? {
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

        return UIImage(cgImage: cgImage)
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

// MARK: - Local DTOs for decoding API responses

/// Matches TunnelStatusResponse from backend.
private struct TunnelStatusDTO: Decodable {
    let running: Bool
    let url: String?
    let uptime: Int?
}

/// Matches TunnelStartResponse from backend.
private struct TunnelStartDTO: Decodable {
    let url: String
}

/// Matches TunnelStopResponse from backend.
private struct TunnelStopDTO: Decodable {
    let stopped: Bool
}

/// Empty request body for tunnel start/stop when no custom domain options needed.
struct EmptyTunnelRequest: Encodable {}

#Preview {
    NavigationStack {
        TunnelSettingsView()
            .environmentObject(AppState())
    }
}
