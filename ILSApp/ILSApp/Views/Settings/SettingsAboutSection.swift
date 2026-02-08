import SwiftUI
import ILSShared

// MARK: - About Section

struct SettingsAboutSection: View {
    @Environment(\.theme) private var theme: any AppTheme
    @ObservedObject var viewModel: SettingsViewModel
    let serverURL: String

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            diagnosticsSection
            aboutSection
        }
    }

    // MARK: - Diagnostics

    @ViewBuilder
    var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Diagnostics")

            VStack(spacing: 0) {
                HStack {
                    Label("Analytics", systemImage: "chart.bar")
                        .font(.system(size: theme.fontBody))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Toggle("", isOn: .init(
                        get: { AppLogger.shared.analyticsOptedIn },
                        set: { AppLogger.shared.analyticsOptedIn = $0 }
                    ))
                    .labelsHidden()
                    .tint(theme.accent)
                    .accessibilityLabel("Enable analytics")
                }
                .padding(theme.spacingMD)

                Divider().background(theme.bgTertiary)

                NavigationLink(destination: LogViewerView()) {
                    HStack {
                        Label("View Logs", systemImage: "doc.text")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(theme.spacingMD)
                }

                Divider().background(theme.bgTertiary)

                NavigationLink(destination: NotificationPreferencesView()) {
                    HStack {
                        Label("Notifications", systemImage: "bell.badge")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(theme.spacingMD)
                }
            }
            .modifier(GlassCard())
        }
    }

    // MARK: - About

    @ViewBuilder
    var aboutSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("About")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                settingsRow("App Version", value: "1.0.0")
                settingsRow("Build", value: "1")

                if let claudeVersion = viewModel.claudeVersion {
                    settingsRow("Claude CLI", value: claudeVersion)
                } else {
                    HStack {
                        Text("Claude CLI")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text("Checking...")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                settingsRow("Backend URL", value: serverURL)

                Link(destination: URL(string: "https://github.com/anthropics/claude-code")!) {
                    HStack {
                        Text("Claude Code Documentation")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Reusable Components

    @ViewBuilder
    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
    }

    @ViewBuilder
    func settingsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textSecondary)
        }
    }
}
