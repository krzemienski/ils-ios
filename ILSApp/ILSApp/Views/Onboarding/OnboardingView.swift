import SwiftUI
import ILSShared

/// First-launch screen presenting the two server-setup paths available to the user.
///
/// Displays an ILS branding header followed by two tappable path cards:
/// **Quick Connect** (navigates to ``QuickConnectView``) for users who already
/// have a backend running, and **Set Up New Server** (navigates to ``SSHSetupView``)
/// for users who want to deploy ILSBackend via SSH. Navigation destinations are
/// registered on the ``NavigationStack`` provided by ``ServerSetupSheet``.
///
/// ## Topics
/// ### Navigation Paths
/// - ``OnboardingPath`` - Enum of the two available setup routes
/// - ``selectedPath`` - Currently selected navigation destination
///
/// ### View Components
/// - ``brandingHeader`` - ILS logo, title, and tagline banner at the top of the screen
/// - ``PathCardView`` - Tappable card that pushes a setup path with press state feedback
struct OnboardingView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var selectedPath: OnboardingPath?

    enum OnboardingPath: Hashable {
        case quickConnect
        case fullSetup
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingLG) {
                brandingHeader

                PathCardView(
                    title: "Quick Connect",
                    subtitle: "Connect to an existing backend server",
                    icon: "bolt.fill",
                    path: .quickConnect,
                    onSelect: { selectedPath = $0 }
                )

                PathCardView(
                    title: "Set Up New Server",
                    subtitle: "Deploy ILSBackend on a remote host via SSH",
                    icon: "server.rack",
                    path: .fullSetup,
                    onSelect: { selectedPath = $0 }
                )
            }
            .padding(.horizontal, theme.spacingXL)
        }
        .background(theme.bgPrimary)
        .navigationDestination(item: $selectedPath) { path in
            switch path {
            case .quickConnect:
                QuickConnectView()
            case .fullSetup:
                SSHSetupView()
            }
        }
    }

    // MARK: - Branding Header

    @ViewBuilder
    private var brandingHeader: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48, design: theme.fontDesign))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.accent, theme.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("ILS")
                .font(.system(size: theme.fontTitle1, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("Intelligent Local Server")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.top, theme.spacingXL)
        .padding(.bottom, theme.spacingMD)
    }
}

// MARK: - Path Card

/// A tappable setup-path card with press state scale feedback.
/// Follows the same press-detection pattern as ``StatCard``.
private struct PathCardView: View {
    let title: String
    let subtitle: String
    let icon: String
    let path: OnboardingView.OnboardingPath
    let onSelect: (OnboardingView.OnboardingPath) -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var isPressed = false

    var body: some View {
        Button {
            onSelect(path)
        } label: {
            HStack(spacing: theme.spacingMD) {
                Image(systemName: icon)
                    .font(.system(size: 24, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text(subtitle)
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
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("\(title): \(subtitle)")
    }
}
