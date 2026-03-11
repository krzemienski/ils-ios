import SwiftUI
import ILSShared

/// Guided 4-step wizard for setting up a Cloudflare tunnel.
///
/// Walks the user through:
/// 1. **Prerequisites** — verifies cloudflared is installed on the backend host
/// 2. **Tunnel Type** — choose between a quick (temporary) or named (custom domain) tunnel
/// 3. **Credentials** — enter API token, tunnel name, and domain (named tunnels only)
/// 4. **Launch** — starts the tunnel and displays the resulting public URL
///
/// On completion, the wizard calls ``onComplete`` with the tunnel URL so the parent
/// view can update its state accordingly.
struct TunnelSetupWizardView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    /// Called when the wizard finishes successfully, passing the live tunnel URL.
    var onComplete: (String) -> Void = { _ in }

    // MARK: - Wizard State

    @State private var currentStep: WizardStep = .prerequisites
    @State private var tunnelType: TunnelType = .quick
    @State private var viewModel = TunnelSettingsViewModel()

    // Step 3 credential fields
    @State private var cfToken = ""
    @State private var cfTunnelName = ""
    @State private var cfDomain = ""

    // Step 1 prereq check
    @State private var isCheckingPrereqs = false
    @State private var prereqError: String?
    @State private var cloudflaredInstalled: Bool?

    // Step 4 launch state
    @State private var isLaunching = false
    @State private var launchError: String?
    @State private var tunnelURL: String?
    @State private var showCopiedToast = false

    private enum FocusedField: Hashable {
        case cfToken, cfTunnelName, cfDomain
    }
    @FocusState private var focusedField: FocusedField?

    // MARK: - Wizard Steps

    enum WizardStep: Int, CaseIterable {
        case prerequisites = 0
        case tunnelType = 1
        case credentials = 2
        case launch = 3

        var title: String {
            switch self {
            case .prerequisites: return "Prerequisites"
            case .tunnelType:    return "Tunnel Type"
            case .credentials:   return "Credentials"
            case .launch:        return "Launch"
            }
        }

        var systemImage: String {
            switch self {
            case .prerequisites: return "checkmark.shield"
            case .tunnelType:    return "network"
            case .credentials:   return "key"
            case .launch:        return "play.circle"
            }
        }
    }

    enum TunnelType {
        case quick, named
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepProgressBar
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.top, theme.spacingMD)
                    .padding(.bottom, theme.spacingSM)

                ScrollView {
                    VStack(spacing: theme.spacingMD) {
                        stepContent
                    }
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.vertical, theme.spacingSM)
                }

                navigationButtons
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.bottom, theme.spacingMD)
                    .padding(.top, theme.spacingSM)
            }
            .background(theme.bgPrimary)
            .navigationTitle("Tunnel Setup")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.selection()
                        dismiss()
                    }
                    .foregroundStyle(theme.textSecondary)
                }
            }
            .toast(isPresented: $showCopiedToast, message: "URL copied to clipboard")
        }
        .task {
            viewModel.configure(client: appState.apiClient)
        }
    }

    // MARK: - Step Progress Bar

    @ViewBuilder
    private var stepProgressBar: some View {
        let steps = WizardStep.allCases
        let visibleSteps: [WizardStep] = tunnelType == .quick
            ? [.prerequisites, .tunnelType, .launch]
            : steps

        VStack(spacing: theme.spacingSM) {
            HStack(spacing: 0) {
                ForEach(Array(visibleSteps.enumerated()), id: \.element) { index, step in
                    let isActive = step == currentStep
                    let isDone = step.rawValue < currentStep.rawValue

                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(isDone ? theme.success : (isActive ? theme.accent : theme.bgTertiary))
                                    .frame(width: 28, height: 28)

                                if isDone {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(theme.textOnAccent)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .semibold, design: theme.fontDesign))
                                        .foregroundStyle(isActive ? theme.textOnAccent : theme.textTertiary)
                                }
                            }

                            Text(step.title)
                                // ACC-007: Use theme caption size for Dynamic Type compliance
                                .font(.system(size: theme.fontCaption, weight: isActive ? .semibold : .regular, design: theme.fontDesign))
                                .foregroundStyle(isActive ? theme.accent : (isDone ? theme.success : theme.textTertiary))
                                .lineLimit(1)
                        }

                        if index < visibleSteps.count - 1 {
                            Rectangle()
                                .fill(isDone ? theme.success : theme.bgTertiary)
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 18)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .prerequisites:
            prerequisitesStep
        case .tunnelType:
            tunnelTypeStep
        case .credentials:
            credentialsStep
        case .launch:
            launchStep
        }
    }

    // MARK: - Step 1: Prerequisites

    @ViewBuilder
    private var prerequisitesStep: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            stepHeader(
                icon: WizardStep.prerequisites.systemImage,
                title: "Check Prerequisites",
                subtitle: "Verify cloudflared is installed on your Mac before creating a tunnel."
            )

            // Check result card
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack(spacing: theme.spacingSM) {
                    Group {
                        if isCheckingPrereqs {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(theme.accent)
                                .frame(width: 20, height: 20)
                        } else if let installed = cloudflaredInstalled {
                            Image(systemName: installed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(installed ? theme.success : theme.error)
                        } else {
                            Image(systemName: "circle.dashed")
                                .font(.system(size: 20))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("cloudflared CLI")
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)

                        if isCheckingPrereqs {
                            Text("Checking...")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        } else if let installed = cloudflaredInstalled {
                            Text(installed ? "Installed and ready" : "Not found")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(installed ? theme.success : theme.error)
                        } else {
                            Text("Tap check to verify")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }

                    Spacer()
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())

                if cloudflaredInstalled == false {
                    installInstructionsCard
                }

                if let error = prereqError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.warning)
                        Text(error)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.error)
                    }
                }

                Button {
                    HapticManager.selection()
                    checkPrerequisites()
                } label: {
                    HStack {
                        if isCheckingPrereqs {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(cloudflaredInstalled == nil ? "Check Now" : "Re-check")
                    }
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .disabled(isCheckingPrereqs)
                .accessibilityLabel("Check cloudflared installation")
            }

            infoCard(
                icon: "info.circle",
                text: "cloudflared is required to create Cloudflare tunnels. It runs on your Mac and establishes the secure connection to Cloudflare's network."
            )
        }
    }

    @ViewBuilder
    private var installInstructionsCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Installation")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Quick install with Homebrew:")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                Text("brew install cloudflared")
                    .font(.system(size: theme.fontCaption, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .padding(theme.spacingSM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.bgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }

            if let url = URL(string: "https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/") {
                Link(destination: url) {
                    HStack {
                        Text("Official download page")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                        Image(systemName: "arrow.up.right")
                            // ACC-007: Use theme caption size for Dynamic Type compliance
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.accent)
                    }
                }
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Step 2: Tunnel Type

    @ViewBuilder
    private var tunnelTypeStep: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            stepHeader(
                icon: WizardStep.tunnelType.systemImage,
                title: "Choose Tunnel Type",
                subtitle: "Select how you'd like to expose your ILS backend."
            )

            VStack(spacing: theme.spacingSM) {
                tunnelTypeCard(
                    type: .quick,
                    icon: "bolt.fill",
                    title: "Quick Tunnel",
                    description: "Instantly create a temporary public URL. No account required. URL changes each session.",
                    badge: "No Setup"
                )

                tunnelTypeCard(
                    type: .named,
                    icon: "globe",
                    title: "Named Tunnel",
                    description: "Use your own domain for a stable URL that never changes. Requires a Cloudflare account.",
                    badge: "Custom Domain"
                )
            }

            infoCard(
                icon: "lightbulb",
                text: "Quick tunnels are great for testing. Named tunnels are recommended for regular use — your URL stays the same every time."
            )
        }
    }

    @ViewBuilder
    private func tunnelTypeCard(
        type: TunnelType,
        icon: String,
        title: String,
        description: String,
        badge: String
    ) -> some View {
        let isSelected = tunnelType == type

        Button {
            HapticManager.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                tunnelType = type
            }
        } label: {
            HStack(alignment: .top, spacing: theme.spacingMD) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text(badge)
                            // ACC-007: Use theme caption size for Dynamic Type compliance
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(isSelected ? theme.textOnAccent : theme.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(isSelected ? theme.accent : theme.bgTertiary)
                            .clipShape(Capsule())
                    }
                    Text(description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(theme.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.bgSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cornerRadius)
                            .strokeBorder(
                                isSelected ? theme.accent : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) — \(description)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Step 3: Credentials

    @ViewBuilder
    private var credentialsStep: some View {
        @Bindable var vm = viewModel

        VStack(alignment: .leading, spacing: theme.spacingSM) {
            stepHeader(
                icon: WizardStep.credentials.systemImage,
                title: "Enter Credentials",
                subtitle: "Provide your Cloudflare API token and tunnel details."
            )

            VStack(alignment: .leading, spacing: theme.spacingSM) {
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
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .padding(theme.spacingSM)
                        .background(theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        .focusRing(isFocused: focusedField == .cfDomain, cornerRadius: theme.cornerRadiusSmall)
                        .focused($focusedField, equals: .cfDomain)
                        .accessibilityLabel("Custom domain")
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            infoCard(
                icon: "lock.shield",
                text: "Your API token is stored securely in the system Keychain and never transmitted in plain text."
            )

            dnsHelperCard
        }
    }

    @ViewBuilder
    private var dnsHelperCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "globe.badge.chevron.backward")
                    .foregroundStyle(theme.accent)
                Text("DNS Configuration")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
            }

            Text("After creating your tunnel, add a CNAME record in your Cloudflare DNS dashboard:")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                dnsRow(label: "Type", value: "CNAME")
                dnsRow(label: "Name", value: cfDomain.isEmpty ? "ils.yourdomain.com" : cfDomain)
                dnsRow(label: "Target", value: "<tunnel-id>.cfargotunnel.com")
                dnsRow(label: "Proxy", value: "Proxied (orange cloud)")
            }
            .padding(theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    @ViewBuilder
    private func dnsRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: theme.fontCaption, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
        }
    }

    // MARK: - Step 4: Launch

    @ViewBuilder
    private var launchStep: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            stepHeader(
                icon: WizardStep.launch.systemImage,
                title: "Launch Tunnel",
                subtitle: tunnelURL == nil
                    ? "Ready to start your \(tunnelType == .quick ? "quick" : "named") tunnel."
                    : "Your tunnel is running and ready to use."
            )

            if isLaunching {
                launchingCard
            } else if let url = tunnelURL {
                successCard(url: url)
            } else {
                readyToLaunchCard
            }

            if let error = launchError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.warning)
                    Text(error)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.error)
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }

            infoCard(
                icon: "shield.lefthalf.filled",
                text: "All traffic is encrypted end-to-end through Cloudflare's global network. Only connections to your tunnel URL can reach your local backend."
            )
        }
    }

    @ViewBuilder
    private var launchingCard: some View {
        VStack(spacing: theme.spacingMD) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(theme.accent)
                .padding(.top, theme.spacingSM)

            Text("Starting tunnel...")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            Text("This may take a few seconds while cloudflared establishes the connection to Cloudflare's network.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    @ViewBuilder
    private func successCard(url: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Circle()
                    .fill(theme.success)
                    .frame(width: 10, height: 10)
                Text("Tunnel Active")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.success)
                Spacer()
                Text(tunnelType == .quick ? "Quick" : "Named")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(tunnelType == .named ? theme.success : theme.accent)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Public URL")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                Text(url)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                    .textSelection(.enabled)
            }

            Button {
                HapticManager.selection()
                #if os(iOS)
                UIPasteboard.general.string = url
                #else
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
                #endif
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
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    @ViewBuilder
    private var readyToLaunchCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            let summaryItems: [(String, String)] = tunnelType == .quick
                ? [
                    ("Type", "Quick Tunnel"),
                    ("URL", "Generated on start"),
                    ("Duration", "Session only")
                  ]
                : [
                    ("Type", "Named Tunnel"),
                    ("Tunnel", cfTunnelName.isEmpty ? "—" : cfTunnelName),
                    ("Domain", cfDomain.isEmpty ? "—" : cfDomain)
                  ]

            Text("Summary")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            ForEach(summaryItems, id: \.0) { item in
                HStack {
                    Text(item.0)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text(item.1)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                }
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Navigation Buttons

    @ViewBuilder
    private var navigationButtons: some View {
        HStack(spacing: theme.spacingSM) {
            // Back button
            if currentStep != .prerequisites {
                Button {
                    HapticManager.selection()
                    navigateBack()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .disabled(isLaunching)
                .accessibilityLabel("Go back")
            }

            // Primary action button
            primaryButton
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch currentStep {
        case .prerequisites:
            Button {
                HapticManager.selection()
                navigateForward()
            } label: {
                HStack(spacing: 6) {
                    Text("Continue")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM)
                .background(canProceedFromPrereqs ? theme.accent : theme.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
            .disabled(!canProceedFromPrereqs)
            .accessibilityLabel("Continue to next step")

        case .tunnelType:
            Button {
                HapticManager.selection()
                navigateForward()
            } label: {
                HStack(spacing: 6) {
                    Text("Continue")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
            .accessibilityLabel("Continue to next step")

        case .credentials:
            Button {
                HapticManager.selection()
                navigateForward()
            } label: {
                HStack(spacing: 6) {
                    Text("Continue")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM)
                .background(isCredentialsValid ? theme.accent : theme.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
            .disabled(!isCredentialsValid)
            .accessibilityLabel("Continue to launch step")

        case .launch:
            if let _ = tunnelURL {
                Button {
                    HapticManager.impact(.medium)
                    if let url = tunnelURL {
                        onComplete(url)
                    }
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Done")
                    }
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.success)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .accessibilityLabel("Finish wizard")
            } else {
                Button {
                    HapticManager.impact(.medium)
                    launchTunnel()
                } label: {
                    HStack(spacing: 6) {
                        if isLaunching {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isLaunching ? "Starting..." : "Start Tunnel")
                    }
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(isLaunching ? theme.bgTertiary : theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .disabled(isLaunching)
                .accessibilityLabel("Start tunnel")
            }
        }
    }

    // MARK: - Navigation Logic

    private var canProceedFromPrereqs: Bool {
        cloudflaredInstalled == true
    }

    private var isCredentialsValid: Bool {
        !cfToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cfTunnelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cfDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func navigateForward() {
        switch currentStep {
        case .prerequisites:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentStep = .tunnelType
            }
        case .tunnelType:
            if tunnelType == .quick {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    currentStep = .launch
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    currentStep = .credentials
                }
            }
        case .credentials:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentStep = .launch
            }
        case .launch:
            break
        }
    }

    private func navigateBack() {
        switch currentStep {
        case .prerequisites:
            break
        case .tunnelType:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentStep = .prerequisites
            }
        case .credentials:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentStep = .tunnelType
            }
        case .launch:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentStep = tunnelType == .quick ? .tunnelType : .credentials
            }
        }
    }

    // MARK: - Actions

    private func checkPrerequisites() {
        isCheckingPrereqs = true
        prereqError = nil
        Task {
            await viewModel.fetchStatus()
            await MainActor.run {
                isCheckingPrereqs = false
                if viewModel.notInstalled {
                    cloudflaredInstalled = false
                } else {
                    cloudflaredInstalled = true
                }
            }
        }
    }

    private func launchTunnel() {
        isLaunching = true
        launchError = nil
        Task {
            if tunnelType == .quick {
                await viewModel.startTunnel()
            } else {
                viewModel.cfToken = cfToken
                viewModel.cfTunnelName = cfTunnelName
                viewModel.cfDomain = cfDomain
                await viewModel.startNamedTunnel()
            }
            await MainActor.run {
                isLaunching = false
                if let url = viewModel.tunnelURL {
                    tunnelURL = url
                    HapticManager.notification(.success)
                } else if let error = viewModel.errorMessage {
                    launchError = error
                    HapticManager.notification(.error)
                }
            }
        }
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(theme.accent)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.bottom, theme.spacingSM)
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

    @ViewBuilder
    private func infoCard(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            Image(systemName: icon)
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.accent)
            Text(text)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(theme.spacingSM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }
}


#Preview {
    TunnelSetupWizardView()
        .environment(AppState())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
