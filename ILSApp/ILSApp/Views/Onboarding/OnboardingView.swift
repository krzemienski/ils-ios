import SwiftUI
import ILSShared

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme: any AppTheme

    @State private var selectedPath: OnboardingPath?

    enum OnboardingPath: Hashable {
        case quickConnect
        case fullSetup
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingLG) {
                brandingHeader

                pathCard(
                    title: "Quick Connect",
                    subtitle: "Connect to an existing backend server",
                    icon: "bolt.fill",
                    path: .quickConnect
                )

                pathCard(
                    title: "Set Up New Server",
                    subtitle: "Deploy ILSBackend on a remote host via SSH",
                    icon: "server.rack",
                    path: .fullSetup
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
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.accent, theme.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("ILS")
                .font(.system(size: theme.fontTitle1, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            Text("Intelligent Local Server")
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.top, theme.spacingXL)
        .padding(.bottom, theme.spacingMD)
    }

    // MARK: - Path Card

    @ViewBuilder
    private func pathCard(title: String, subtitle: String, icon: String, path: OnboardingPath) -> some View {
        Button {
            selectedPath = path
        } label: {
            HStack(spacing: theme.spacingMD) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: theme.fontBody, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(subtitle)")
    }
}
