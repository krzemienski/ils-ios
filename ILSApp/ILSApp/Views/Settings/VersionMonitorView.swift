import SwiftUI
import ILSShared

// MARK: - Version Monitor View

/// Version monitoring view displaying Claude Code CLI version information.
///
/// Shows current CLI version, update availability status, compatibility check results,
/// changelogs for new versions, and version history tracking past detected versions.
///
/// ## Topics
/// ### View Sections
/// - ``currentVersionSection`` - Displays current version, install method, and detection date
/// - ``updateStatusSection`` - Shows update availability and changelog
/// - ``compatibilitySection`` - Displays compatibility status between ILS and CLI versions
/// - ``versionHistorySection`` - Lists historical version changes
struct VersionMonitorView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var viewModel = VersionMonitorViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                if viewModel.isLoadingAny {
                    loadingSection
                } else {
                    currentVersionSection

                    if viewModel.hasUpdateAvailable {
                        updateStatusSection
                    }

                    compatibilitySection
                    versionHistorySection
                }

                if let error = viewModel.error {
                    errorSection(error)
                }
            }
            .padding(theme.spacingMD)
        }
        .navigationTitle("Version Monitor")
        .task {
            await viewModel.loadAll()
        }
        .refreshable {
            await viewModel.loadAll()
        }
    }

    // MARK: - Loading Section

    @ViewBuilder
    var loadingSection: some View {
        VStack(spacing: theme.spacingMD) {
            ProgressView()
                .tint(theme.accent)
            Text("Loading version information...")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingLG)
    }

    // MARK: - Current Version Section

    @ViewBuilder
    var currentVersionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Current Version")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                if let current = viewModel.currentVersion {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Claude Code CLI")
                                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                            Text("Version \(current.version)")
                                .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                                .foregroundStyle(theme.accent)
                        }
                        Spacer()
                        installMethodBadge(current.installMethod)
                    }

                    Divider().background(theme.bgTertiary)

                    settingsRow("Install Method", value: current.installMethod.capitalized)

                    if let binaryPath = current.binaryPath {
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Binary Path")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                            Text(binaryPath)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, theme.spacingXS)
                    }

                    Divider().background(theme.bgTertiary)

                    settingsRow("Detected", value: formatDate(current.detectedAt))
                } else {
                    HStack {
                        Label("No version detected", systemImage: "exclamationmark.triangle")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Update Status Section

    @ViewBuilder
    var updateStatusSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Update Available")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                if let update = viewModel.updateCheck {
                    HStack {
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundStyle(viewModel.hasBreakingChanges ? theme.error : theme.success)
                                Text("Version \(update.latestVersion)")
                                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                            }
                            Text("New version available")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                        if viewModel.hasBreakingChanges {
                            breakingChangeBadge
                        }
                    }

                    if let releasedAt = update.releasedAt {
                        Divider().background(theme.bgTertiary)
                        settingsRow("Released", value: formatDate(releasedAt))
                    }

                    if let changelog = update.changelog, !changelog.isEmpty {
                        Divider().background(theme.bgTertiary)

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Changelog")
                                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                            Text(changelog)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(10)
                        }
                        .padding(.vertical, theme.spacingXS)
                    }

                    if let releaseUrl = update.releaseUrl, let url = URL(string: releaseUrl) {
                        Divider().background(theme.bgTertiary)

                        Link(destination: url) {
                            HStack {
                                Text("View Release on GitHub")
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                    .foregroundStyle(theme.accent)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.accent)
                            }
                        }
                    }
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Compatibility Section

    @ViewBuilder
    var compatibilitySection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Compatibility")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                if let compat = viewModel.compatibility {
                    HStack {
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            HStack {
                                compatibilityIcon(compat.status)
                                Text(compatibilityStatusText(compat.status))
                                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                                    .foregroundStyle(compatibilityColor(compat.status))
                            }
                            Text(compat.message)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                    }

                    Divider().background(theme.bgTertiary)

                    settingsRow("ILS Version", value: compat.ilsVersion)
                    settingsRow("CLI Version", value: compat.cliVersion)

                    if let recommended = compat.recommendedCliVersionRange {
                        Divider().background(theme.bgTertiary)
                        settingsRow("Recommended CLI", value: recommended)
                    }
                } else {
                    HStack {
                        Label("Checking compatibility...", systemImage: "hourglass")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Version History Section

    @ViewBuilder
    var versionHistorySection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                sectionLabel("Version History")
                Spacer()
                if let count = viewModel.versionHistory?.totalCount, count > 0 {
                    Text("\(count) changes")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            VStack(spacing: 0) {
                if let history = viewModel.versionHistory, !history.entries.isEmpty {
                    ForEach(Array(history.entries.enumerated()), id: \.element.id) { index, entry in
                        historyRow(entry)
                        if index < history.entries.count - 1 {
                            Divider().background(theme.bgTertiary)
                        }
                    }
                } else {
                    HStack {
                        Label("No version history", systemImage: "clock")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(theme.spacingMD)
                }
            }
            .modifier(GlassCard())
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    func errorSection(_ error: Error) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Error")

            HStack {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.error)
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - History Row

    @ViewBuilder
    func historyRow(_ entry: VersionHistoryEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: theme.spacingXS) {
                HStack {
                    Text("v\(entry.version)")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    if entry.wasAutoDetected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.success)
                    }
                }
                HStack(spacing: theme.spacingXS) {
                    Text(entry.installMethod.capitalized)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                    Text("•")
                        .foregroundStyle(theme.textTertiary)
                    Text(formatDate(entry.detectedAt))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(theme.spacingMD)
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
    private func settingsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
    }

    @ViewBuilder
    private func installMethodBadge(_ method: String) -> some View {
        Text(method.uppercased())
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgSecondary)
            .cornerRadius(theme.cornerRadiusSmall)
    }

    @ViewBuilder
    private var breakingChangeBadge: some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("BREAKING")
        }
        .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
        .foregroundStyle(theme.error)
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.error.opacity(0.1))
        .cornerRadius(theme.cornerRadiusSmall)
    }

    // MARK: - Compatibility Helpers

    @ViewBuilder
    private func compatibilityIcon(_ status: CompatibilityCheckResponse.CompatibilityStatus) -> some View {
        switch status {
        case .compatible:
            Image(systemName: "checkmark.circle.fill")
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
        case .incompatible:
            Image(systemName: "xmark.circle.fill")
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
        }
    }

    private func compatibilityColor(_ status: CompatibilityCheckResponse.CompatibilityStatus) -> Color {
        switch status {
        case .compatible:
            return theme.success
        case .warning:
            return theme.warning
        case .incompatible:
            return theme.error
        case .unknown:
            return theme.textTertiary
        }
    }

    private func compatibilityStatusText(_ status: CompatibilityCheckResponse.CompatibilityStatus) -> String {
        switch status {
        case .compatible:
            return "Compatible"
        case .warning:
            return "Warning"
        case .incompatible:
            return "Incompatible"
        case .unknown:
            return "Unknown"
        }
    }

    // MARK: - Date Formatting

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
