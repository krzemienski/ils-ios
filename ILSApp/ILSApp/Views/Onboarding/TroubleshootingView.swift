import SwiftUI

/// Inline expandable troubleshooting section displayed after a connection failure.
///
/// Analyses the raw error message to surface contextual tips:
/// - **Connection refused** → firewall and port configuration hints
/// - **Timeout** → VPN / network-reachability hints
/// - **URL errors** → URL format and scheme hints
/// - **Unknown** → general retry and diagnostic hints
///
/// Each tip renders as a ``GlassCard`` row containing an SF Symbol icon, a bold
/// title, and a descriptive caption. The section collapses by default and expands
/// when the user taps the disclosure header, keeping the screen clean until help
/// is explicitly requested.
///
/// ## Topics
/// ### Error Classification
/// - ``ErrorKind`` - Inferred error category driving the displayed tips
/// - ``errorKind`` - Computed property mapping the error message to an ``ErrorKind``
///
/// ### View Components
/// - ``disclosureHeader`` - Tappable expand/collapse header row
/// - ``tipRow(icon:iconColor:title:description:)`` - Individual GlassCard tip row
/// - ``actionButtons`` - "Try Again" and "Set Up New Server" action row
struct TroubleshootingView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// The raw error message from the failed connection attempt.
    let errorMessage: String
    /// Called when the user taps **Try Again**.
    let onRetry: () -> Void
    /// Called when the user taps **Set Up New Server**.
    let onSetupNewServer: () -> Void

    @State private var isExpanded = true

    // MARK: - Error Classification

    /// Broad category inferred from the error message text.
    enum ErrorKind {
        case connectionRefused
        case timeout
        case urlFormat
        case unknown
    }

    private var errorKind: ErrorKind {
        let lower = errorMessage.lowercased()
        if lower.contains("refused") || lower.contains("econnrefused") || lower.contains("connection refused") {
            return .connectionRefused
        }
        if lower.contains("timeout") || lower.contains("timed out") {
            return .timeout
        }
        if lower.contains("url") || lower.contains("invalid") || lower.contains("scheme") || lower.contains("host") {
            return .urlFormat
        }
        return .unknown
    }

    private struct Tip {
        let icon: String
        let iconColorKeyPath: KeyPath<ThemeSnapshot, Color>
        let title: String
        let description: String
    }

    private var tips: [Tip] {
        switch errorKind {
        case .connectionRefused:
            return [
                Tip(
                    icon: "shield.slash",
                    iconColorKeyPath: \.warning,
                    title: "Check Firewall Rules",
                    description: "Ensure port 9999 is open on your server's firewall and not blocked by any software firewall."
                ),
                Tip(
                    icon: "number.circle",
                    iconColorKeyPath: \.info,
                    title: "Verify Port Number",
                    description: "ILS Backend listens on port 9999 by default. Confirm the backend started without a different --port flag."
                ),
                Tip(
                    icon: "play.circle.fill",
                    iconColorKeyPath: \.success,
                    title: "Is the Backend Running?",
                    description: "Run `swift run ILSBackend` on the server, then wait for the 'Server starting' message before connecting."
                )
            ]
        case .timeout:
            return [
                Tip(
                    icon: "network.slash",
                    iconColorKeyPath: \.warning,
                    title: "VPN Interference",
                    description: "If you're on a VPN, try disconnecting — some VPNs block direct LAN connections to the server."
                ),
                Tip(
                    icon: "wifi",
                    iconColorKeyPath: \.info,
                    title: "Network Reachability",
                    description: "Check that your device and the server share the same network, or that the server's IP is publicly reachable."
                ),
                Tip(
                    icon: "clock.badge.exclamationmark",
                    iconColorKeyPath: \.warning,
                    title: "Slow to Respond",
                    description: "The backend may still be starting up. Wait a few seconds and tap Try Again."
                )
            ]
        case .urlFormat:
            return [
                Tip(
                    icon: "link",
                    iconColorKeyPath: \.info,
                    title: "Include the URL Scheme",
                    description: "Enter the full URL with the http:// or https:// scheme, e.g. http://192.168.1.10:9999"
                ),
                Tip(
                    icon: "textformat",
                    iconColorKeyPath: \.warning,
                    title: "No Trailing Slash",
                    description: "Remove any trailing slash — use http://host:9999, not http://host:9999/."
                ),
                Tip(
                    icon: "number",
                    iconColorKeyPath: \.info,
                    title: "Include the Port",
                    description: "Always specify the port number. ILS Backend defaults to :9999."
                )
            ]
        case .unknown:
            return [
                Tip(
                    icon: "arrow.clockwise.circle",
                    iconColorKeyPath: \.info,
                    title: "Try Again",
                    description: "Transient network errors often resolve on a second attempt."
                ),
                Tip(
                    icon: "wifi",
                    iconColorKeyPath: \.warning,
                    title: "Check Your Network",
                    description: "Verify your device has an active Wi-Fi or cellular connection before retrying."
                ),
                Tip(
                    icon: "terminal",
                    iconColorKeyPath: \.info,
                    title: "Inspect Backend Logs",
                    description: "Check the ILS Backend terminal output for error details that can pinpoint the issue."
                )
            ]
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingMD) {
            disclosureHeader

            if isExpanded {
                VStack(spacing: theme.spacingSM) {
                    ForEach(tips.indices, id: \.self) { index in
                        let tip = tips[index]
                        tipRow(
                            icon: tip.icon,
                            iconColor: theme[keyPath: tip.iconColorKeyPath],
                            title: tip.title,
                            description: tip.description
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                actionButtons
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }

    // MARK: - Disclosure Header

    private var disclosureHeader: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: theme.fontTitle3, design: theme.fontDesign))
                    .foregroundStyle(theme.warning)

                Text("Troubleshooting Tips")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse troubleshooting tips" : "Expand troubleshooting tips")
    }

    // MARK: - Tip Row

    @ViewBuilder
    private func tipRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 20, design: theme.fontDesign))
                .foregroundStyle(iconColor)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text(description)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: theme.spacingSM) {
            Button {
                onRetry()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .accessibilityIdentifier("troubleshooting-retry-button")
            .accessibilityLabel("Try connecting again")

            Button {
                onSetupNewServer()
            } label: {
                Text("Set Up New Server")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("troubleshooting-setup-server-button")
            .accessibilityLabel("Start new server setup")
        }
        .padding(.top, theme.spacingXS)
    }
}
