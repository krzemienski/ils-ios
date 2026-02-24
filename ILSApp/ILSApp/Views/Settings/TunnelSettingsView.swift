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
/// On load the view fetches the current tunnel status from the backend and restores any
/// previously saved custom-domain credentials. The Cloudflare API token is persisted securely
/// in the system Keychain via `KeychainService`; the tunnel name and custom domain are stored
/// in `UserDefaults`. A legacy migration path promotes tokens found in `UserDefaults` to the
/// Keychain on first use.
///
/// A QR code for the active tunnel URL is generated with `CIQRCodeGenerator` and shown inline,
/// making it easy to open the backend on a phone or tablet. A copy-to-clipboard button with a
/// timed toast provides a quick way to share the URL.
///
/// ## Topics
/// ### State — Connection
/// - ``isRunning`` - Whether a tunnel is currently active
/// - ``tunnelURL`` - The public URL assigned by Cloudflare
/// - ``uptime`` - Tunnel uptime in seconds
/// - ``tunnelMode`` - Active tunnel mode ("quick" or "named")
///
/// ### State — UI
/// - ``isLoading`` - Global loading flag for status fetch
/// - ``isToggling`` - In-progress flag while starting or stopping the tunnel
/// - ``errorMessage`` - Human-readable error shown in the quick tunnel card
/// - ``notInstalled`` - Whether `cloudflared` CLI is missing on the host Mac
/// - ``installURL`` - Deep link to the Cloudflare download page when not installed
/// - ``showCopiedToast`` - Controls clipboard-copy toast visibility
/// - ``qrImage`` - Platform-appropriate QR code image for the active tunnel URL
///
/// ### State — Custom Domain Credentials
/// - ``cfToken`` - Cloudflare API token (persisted to Keychain)
/// - ``cfTunnelName`` - Named tunnel identifier (persisted to UserDefaults)
/// - ``cfDomain`` - Custom domain hostname (persisted to UserDefaults)
///
/// ### View Sections
/// - ``quickTunnelSection`` - Toggle card for starting/stopping the quick tunnel
/// - ``tunnelInfoSection(url:)`` - Connection info card with URL, mode badge, uptime, copy button, and QR code
/// - ``installSection`` - Installation prompt shown when `cloudflared` is missing
/// - ``customDomainSection`` - Collapsible advanced panel for named tunnel credentials
/// - ``howItWorksSection`` - Numbered explainer of the tunnel flow
///
/// ### Reusable Components
/// - ``sectionLabel(_:)`` - Uppercased, letter-spaced section header label
/// - ``fieldGroup(label:content:)`` - Labeled input field wrapper
/// - ``infoRow(icon:text:)`` - Icon + text row used in the how-it-works list
///
/// ### Actions
/// - ``fetchStatus()`` - Loads current tunnel state from the backend on appear
/// - ``startTunnel()`` - Starts a quick (anonymous) Cloudflare tunnel
/// - ``stopTunnel()`` - Stops the active tunnel
/// - ``startNamedTunnel()`` - Persists credentials and starts a named tunnel with a custom domain
/// - ``loadCustomDomainSettings()`` - Restores saved credentials from Keychain and UserDefaults
/// - ``generateQRCode(from:)`` - Renders a `CIQRCodeGenerator` image scaled for display
/// - ``formatUptime(_:)`` - Formats a raw seconds value as "Xh Ym" or "Xm Ys"
struct TunnelSettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Connection State

    /// Whether a Cloudflare tunnel is currently running.
    @State private var isRunning = false
    /// The public URL assigned by Cloudflare for the active tunnel.
    @State private var tunnelURL: String?
    /// How long the tunnel has been running, in seconds.
    @State private var uptime: Int?
    /// The active tunnel mode reported by the backend — `"quick"` or `"named"`.
    @State private var tunnelMode: String?

    // MARK: - UI State

    /// Whether the initial status fetch is in progress.
    @State private var isLoading = false
    /// Whether a start or stop tunnel request is in flight; disables the toggle and shows a spinner.
    @State private var isToggling = false
    /// Human-readable error message displayed inside the quick tunnel card.
    @State private var errorMessage: String?
    /// `true` when `cloudflared` is not installed on the host Mac; shows the installation section.
    @State private var notInstalled = false
    /// URL to the Cloudflare `cloudflared` download page, populated when ``notInstalled`` is `true`.
    @State private var installURL: String?
    /// Controls visibility of the "URL copied" toast shown after the user taps Copy.
    @State private var showCopiedToast = false
    /// QR code image derived from ``tunnelURL``, regenerated whenever the URL changes.
    @State private var qrImage: PlatformImage?
    // SEC-MED-2: Surface Keychain migration failures to user.
    @State private var keychainMigrationError: String?

    // MARK: - Custom Domain Credentials

    /// Cloudflare API token used to authenticate named tunnel creation; stored in the Keychain.
    @State private var cfToken = ""
    /// Identifier for the named tunnel within the user's Cloudflare account; stored in UserDefaults.
    @State private var cfTunnelName = ""
    /// Custom hostname to route the tunnel to (e.g. `ils.example.com`); stored in UserDefaults.
    @State private var cfDomain = ""

    private enum FocusedField: Hashable {
        case cfToken, cfTunnelName, cfDomain
    }
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                // SEC-MED-2: Banner for Keychain migration errors.
                if let keychainError = keychainMigrationError {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.warning)
                        Text(keychainError)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Button {
                            keychainMigrationError = nil
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
                // UIPERF-01: Off-thread QR generation — CIFilter must not block main thread.
                let urlCopy = url
                Task.detached(priority: .userInitiated) {
                    let image = TunnelSettingsView.generateQRCode(from: urlCopy)
                    await MainActor.run { qrImage = image }
                }
            } else {
                qrImage = nil
            }
        }
        .screenshotProtected()
    }

    // MARK: - Quick Tunnel Section

    /// Card section containing the toggle that starts or stops a temporary Cloudflare quick tunnel.
    ///
    /// Shows a progress spinner in place of the toggle while a start/stop request is in flight,
    /// and surfaces ``errorMessage`` below the toggle row when a failure occurs.
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
                                HapticManager.selection()
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

    /// Card section showing live connection information when a tunnel is active.
    ///
    /// Displays a green status indicator, the tunnel mode badge, formatted uptime, the public URL
    /// (selectable), a copy-to-clipboard button that triggers a toast, and a QR code image for
    /// quick scanning on another device.
    ///
    /// - Parameter url: The active Cloudflare tunnel URL to display and encode into a QR code.
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

    /// Card section shown when the backend reports that `cloudflared` is not installed on the host Mac.
    ///
    /// Provides a deep link to the Cloudflare download page and an inline Homebrew install command
    /// for convenience.
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

    /// Collapsible advanced section for configuring a named Cloudflare tunnel with a custom domain.
    ///
    /// Exposes three secured input fields — API token (`SecureField`), tunnel name, and custom
    /// hostname — along with a "Save & Start" button that persists credentials to Keychain /
    /// UserDefaults and launches the named tunnel. The button is disabled until all three fields
    /// contain non-empty trimmed values (see ``isCustomDomainValid``).
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
                                .focusRing(isFocused: focusedField == .cfToken, cornerRadius: theme.cornerRadiusSmall)
                                .focused($focusedField, equals: .cfToken)
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
                                .focusRing(isFocused: focusedField == .cfTunnelName, cornerRadius: theme.cornerRadiusSmall)
                                .focused($focusedField, equals: .cfTunnelName)
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
                                .focusRing(isFocused: focusedField == .cfDomain, cornerRadius: theme.cornerRadiusSmall)
                                .focused($focusedField, equals: .cfDomain)
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

    /// Informational card explaining the four steps of the Cloudflare tunnel flow to the user.
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

    /// Renders an uppercased, letter-spaced section header in the tertiary text colour.
    ///
    /// - Parameter text: The label string to display.
    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
                .kerning(1)
    }

    /// Wraps an input field with a small label placed above it.
    ///
    /// - Parameters:
    ///   - label: Caption text displayed above the field.
    ///   - content: The input field or other view to render below the label.
    @ViewBuilder
    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }

    /// Renders a numbered step row with an SF Symbol icon and a description string.
    ///
    /// - Parameters:
    ///   - icon: SF Symbol name for the leading icon (e.g. `"1.circle.fill"`).
    ///   - text: The step description displayed beside the icon.
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

    /// `true` when all three custom-domain credential fields contain non-empty trimmed values,
    /// enabling the "Save & Start Named Tunnel" button.
    private var isCustomDomainValid: Bool {
        !cfToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cfTunnelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cfDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    /// Fetches the current tunnel status from the backend and updates all relevant state.
    ///
    /// Handles `404` responses as a signal that `cloudflared` is not installed, populating
    /// ``notInstalled`` and ``installURL`` so the installation section is shown.
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
                // UIPERF-01: Off-thread QR generation — CIFilter must not block main thread.
                let urlCopy = url
                Task.detached(priority: .userInitiated) {
                    let image = TunnelSettingsView.generateQRCode(from: urlCopy)
                    await MainActor.run { qrImage = image }
                }
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

    /// Starts an anonymous Cloudflare quick tunnel and stores the assigned public URL.
    ///
    /// Sets ``isToggling`` while the request is in flight and populates ``tunnelURL`` and
    /// ``qrImage`` on success. On failure, surfaces a user-facing error via ``errorMessage``
    /// or sets ``notInstalled`` if `cloudflared` is missing.
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
            // UIPERF-01: Off-thread QR generation — CIFilter must not block main thread.
            let urlCopy = response.url
            Task.detached(priority: .userInitiated) {
                let image = TunnelSettingsView.generateQRCode(from: urlCopy)
                await MainActor.run { qrImage = image }
            }
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

    /// Stops the currently active tunnel and clears all connection state.
    ///
    /// Sets ``isToggling`` while the request is in flight. On success, clears ``tunnelURL``,
    /// ``uptime``, and sets ``isRunning`` to `false`. Surfaces any error via ``errorMessage``.
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

    /// Persists custom-domain credentials and starts a named Cloudflare tunnel.
    ///
    /// Saves ``cfToken`` to the Keychain and ``cfTunnelName`` / ``cfDomain`` to `UserDefaults`
    /// before POSTing `TunnelStartRequest` with all three values. On success populates
    /// ``tunnelURL`` and regenerates ``qrImage``. Errors are handled identically to
    /// ``startTunnel()``.
    private func startNamedTunnel() async {
        isToggling = true
        errorMessage = nil
        defer { isToggling = false }

        // Persist custom domain settings — token goes to Keychain, others to UserDefaults
        let defaults = UserDefaults.standard
        do {
            try await KeychainService.shared.saveCredential(key: "cfToken", value: cfToken)
        } catch {
            AppLogger.shared.error("Failed to save cfToken to Keychain: \(error)", category: "keychain")
        }
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
            // UIPERF-01: Off-thread QR generation — CIFilter must not block main thread.
            let urlCopy = response.url
            Task.detached(priority: .userInitiated) {
                let image = TunnelSettingsView.generateQRCode(from: urlCopy)
                await MainActor.run { qrImage = image }
            }
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

    /// Restores previously saved custom-domain credentials from Keychain and UserDefaults.
    ///
    /// Reads ``cfToken`` from the Keychain asynchronously. If no Keychain entry exists but a
    /// legacy `UserDefaults` token is found, it is migrated to the Keychain and removed from
    /// `UserDefaults`. ``cfTunnelName`` and ``cfDomain`` are read synchronously from
    /// `UserDefaults`.
    private func loadCustomDomainSettings() {
        let defaults = UserDefaults.standard
        // Load token from Keychain (migrate from UserDefaults if present)
        Task {
            // CODBL-03: try? intentional — token may not exist yet
            if let token = try? await KeychainService.shared.getCredential(key: "cfToken") {
                await MainActor.run { cfToken = token }
            } else if let legacyToken = defaults.string(forKey: "cfToken"), !legacyToken.isEmpty {
                // Migrate legacy token from UserDefaults to Keychain
                do {
                    try await KeychainService.shared.saveCredential(key: "cfToken", value: legacyToken)
                } catch {
                    AppLogger.shared.error("Failed to migrate cfToken to Keychain: \(error)", category: "keychain")
                    // SEC-MED-2: Surface migration error to user.
                    await MainActor.run {
                        keychainMigrationError = "Tunnel token couldn't be secured. Please re-enter your token."
                    }
                }
                defaults.removeObject(forKey: "cfToken")
                await MainActor.run { cfToken = legacyToken }
            }
        }
        cfTunnelName = defaults.string(forKey: "cfTunnelName") ?? ""
        cfDomain = defaults.string(forKey: "cfDomain") ?? ""
    }

    // MARK: - QR Code Generation

    // UIPERF-01: nonisolated to allow safe calls from Task.detached without Swift 6 warnings.
    /// Shared `CIContext` reused across QR code renders to avoid repeated GPU context creation.
    private nonisolated static let ciContext = CIContext()

    // UIPERF-01: nonisolated static — CIFilter/CIContext are thread-safe, called from detached tasks.
    /// Generates a QR code image for the given string using `CIQRCodeGenerator`.
    ///
    /// The raw `CIImage` output is scaled by 10× to produce a crisp 200 pt image. Returns
    /// a `UIImage` on iOS and an `NSImage` on macOS, or `nil` if encoding or rendering fails.
    ///
    /// - Parameter string: The URL or text to encode into the QR code.
    /// - Returns: A platform-appropriate image, or `nil` on failure.
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

    // MARK: - Helpers

    /// Formats a raw uptime value in seconds into a compact human-readable string.
    ///
    /// Returns `"Xh Ym"` when the duration exceeds one hour, `"Xm Ys"` for durations under
    /// an hour but over a minute, and `"Xs"` for durations under one minute.
    ///
    /// - Parameter seconds: Uptime duration in seconds.
    /// - Returns: A formatted uptime string.
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
