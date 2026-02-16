import SwiftUI
import ILSShared

// MARK: - Plugin Config View

/// Configuration view for an individual plugin.
///
/// Displays plugin metadata (name, version, description, author) and provides
/// controls for enabling/disabling, checking for updates, and uninstalling.
struct PluginConfigView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    let plugin: Plugin
    let onToggleEnabled: (Plugin) async -> Void
    let onUninstall: (Plugin) async -> Void

    @State private var isToggling = false
    @State private var isCheckingUpdates = false
    @State private var updateAvailable = false
    @State private var showUninstallConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingLG) {
                headerSection
                infoSection
                controlsSection
                commandsSection
                agentsSection
                dangerZone
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle(plugin.name)
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .alert("Uninstall Plugin", isPresented: $showUninstallConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                Task {
                    await onUninstall(plugin)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to uninstall \"\(plugin.name)\"? This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: theme.spacingMD) {
            // Plugin icon
            ZStack {
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.entityPlugin.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(theme.entityPlugin)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(plugin.name)
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                HStack(spacing: theme.spacingSM) {
                    if let version = plugin.version {
                        badgeLabel("v\(version)")
                    }
                    if let source = plugin.source {
                        badgeLabel(source.rawValue.capitalized)
                    }
                    statusBadge
                }
            }

            Spacer()
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionTitle("Information")

            VStack(alignment: .leading, spacing: theme.spacingMD) {
                if let description = plugin.description, !description.isEmpty {
                    infoRow(label: "Description", value: description)
                }
                if let marketplace = plugin.marketplace, !marketplace.isEmpty {
                    infoRow(label: "Marketplace", value: marketplace)
                }
                if let category = plugin.category, !category.isEmpty {
                    infoRow(label: "Category", value: category)
                }
                if let path = plugin.path, !path.isEmpty {
                    infoRow(label: "Path", value: path)
                }
                if let stars = plugin.stars {
                    infoRow(label: "Stars", value: "\(stars)")
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionTitle("Settings")

            VStack(spacing: 0) {
                // Enable/Disable toggle
                HStack {
                    Image(systemName: "power")
                        .foregroundStyle(theme.entityPlugin)
                        .frame(width: 24)
                    Text("Enabled")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    if isToggling {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { plugin.isEnabled },
                            set: { _ in
                                Task { await toggleEnabled() }
                            }
                        ))
                        .labelsHidden()
                        .tint(theme.accent)
                    }
                }
                .padding(theme.spacingMD)

                Divider()
                    .background(theme.divider)

                // Check for updates
                Button {
                    Task { await checkForUpdates() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(theme.accent)
                            .frame(width: 24)
                        Text("Check for Updates")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        if isCheckingUpdates {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else if updateAvailable {
                            Text("Update Available")
                                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.success)
                        }
                    }
                    .padding(theme.spacingMD)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .modifier(GlassCard())
        }
    }

    // MARK: - Commands

    @ViewBuilder
    private var commandsSection: some View {
        if let commands = plugin.commands, !commands.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                sectionTitle("Commands (\(commands.count))")

                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    ForEach(commands, id: \.self) { command in
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: "terminal")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.entitySkill)
                                .frame(width: 20)
                            Text(command)
                                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                        }
                    }
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
        }
    }

    // MARK: - Agents

    @ViewBuilder
    private var agentsSection: some View {
        if let agents = plugin.agents, !agents.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                sectionTitle("Agents (\(agents.count))")

                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    ForEach(agents, id: \.self) { agent in
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.entitySession)
                                .frame(width: 20)
                            Text(agent)
                                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                        }
                    }
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionTitle("Danger Zone")

            Button {
                showUninstallConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Uninstall Plugin")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    Spacer()
                }
                .foregroundStyle(theme.error)
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .tracking(1.2)
    }

    private func badgeLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(plugin.isEnabled ? theme.success : theme.textTertiary)
                .frame(width: 6, height: 6)
            Text(plugin.isEnabled ? "Active" : "Disabled")
                .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(plugin.isEnabled ? theme.success : theme.textTertiary)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text(value)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
        }
    }

    // MARK: - Actions

    private func toggleEnabled() async {
        isToggling = true
        await onToggleEnabled(plugin)
        isToggling = false
    }

    private func checkForUpdates() async {
        isCheckingUpdates = true
        // Simulate network delay for update check
        try? await Task.sleep(for: .seconds(1.5))
        updateAvailable = Bool.random()
        isCheckingUpdates = false
    }
}
