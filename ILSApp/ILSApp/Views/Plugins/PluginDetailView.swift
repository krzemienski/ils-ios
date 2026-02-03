import SwiftUI
import ILSShared

struct PluginDetailView: View {
    let plugin: PluginDetailData
    @ObservedObject var viewModel: PluginsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isInstalling = false
    @State private var showingUninstallConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                // Basic Information Section
                Section("Plugin Info") {
                    LabeledContent("Name", value: plugin.name)

                    if let description = plugin.description {
                        LabeledContent("Description") {
                            Text(description)
                                .font(ILSTheme.bodyFont)
                                .foregroundColor(ILSTheme.primaryText)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    if let version = plugin.version {
                        LabeledContent("Version", value: version)
                    }

                    if let author = plugin.author {
                        LabeledContent("Author", value: author)
                    }

                    if let marketplace = plugin.marketplace {
                        LabeledContent("Marketplace", value: marketplace)
                    }
                }

                // Statistics Section (if available)
                if plugin.rating != nil || plugin.installCount != nil || plugin.reviewCount != nil {
                    Section("Statistics") {
                        if let rating = plugin.rating {
                            LabeledContent("Rating") {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                    Text(String(format: "%.1f", rating))
                                }
                            }
                        }

                        if let installCount = plugin.installCount {
                            LabeledContent("Installs", value: "\(installCount)")
                        }

                        if let reviewCount = plugin.reviewCount {
                            LabeledContent("Reviews", value: "\(reviewCount)")
                        }
                    }
                }

                // Tags Section (if available)
                if let tags = plugin.tags, !tags.isEmpty {
                    Section("Tags") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: ILSTheme.spacingS) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(ILSTheme.tertiaryBackground)
                                        .cornerRadius(ILSTheme.cornerRadiusS)
                                }
                            }
                        }
                    }
                }

                // Commands Section (if available)
                if let commands = plugin.commands, !commands.isEmpty {
                    Section("Commands") {
                        ForEach(commands, id: \.self) { command in
                            Text(command)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(ILSTheme.primaryText)
                        }
                    }
                }

                // Agents Section (if available)
                if let agents = plugin.agents, !agents.isEmpty {
                    Section("Agents") {
                        ForEach(agents, id: \.self) { agent in
                            Text(agent)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(ILSTheme.primaryText)
                        }
                    }
                }

                // Actions Section
                Section {
                    if plugin.isInstalled {
                        // Installed plugin actions
                        Toggle("Enabled", isOn: Binding(
                            get: { plugin.isEnabled },
                            set: { _ in togglePlugin() }
                        ))

                        Button(role: .destructive) {
                            showingUninstallConfirmation = true
                        } label: {
                            Label("Uninstall Plugin", systemImage: "trash")
                        }
                    } else {
                        // Marketplace plugin actions
                        Button {
                            Task {
                                isInstalling = true
                                await installPlugin()
                                isInstalling = false
                            }
                        } label: {
                            HStack {
                                if isInstalling {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else {
                                    Label("Install Plugin", systemImage: "arrow.down.circle")
                                }
                            }
                        }
                        .disabled(isInstalling)
                    }
                }
            }
            .navigationTitle("Plugin Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Uninstall Plugin", isPresented: $showingUninstallConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Uninstall", role: .destructive) {
                    Task {
                        await uninstallPlugin()
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to uninstall \(plugin.name)? This action cannot be undone.")
            }
        }
    }

    private func togglePlugin() {
        Task {
            guard let pluginItem = plugin.pluginItem else { return }
            if plugin.isEnabled {
                await viewModel.disablePlugin(pluginItem)
            } else {
                await viewModel.enablePlugin(pluginItem)
            }
        }
    }

    private func installPlugin() async {
        guard let marketplace = plugin.marketplace else { return }
        await viewModel.installPlugin(name: plugin.name, marketplace: marketplace)
    }

    private func uninstallPlugin() async {
        guard let pluginItem = plugin.pluginItem else { return }
        await viewModel.uninstallPlugin(pluginItem)
    }
}

// MARK: - Plugin Detail Data

/// Unified data structure for displaying plugin details
/// Supports both installed plugins (PluginItem) and marketplace plugins (MarketplacePlugin)
struct PluginDetailData {
    let name: String
    let description: String?
    let version: String?
    let author: String?
    let marketplace: String?
    let rating: Double?
    let installCount: Int?
    let reviewCount: Int?
    let tags: [String]?
    let commands: [String]?
    let agents: [String]?
    let isInstalled: Bool
    let isEnabled: Bool

    // Keep reference to original plugin for actions
    let pluginItem: PluginItem?

    /// Initialize from an installed plugin
    init(pluginItem: PluginItem) {
        self.name = pluginItem.name
        self.description = pluginItem.description
        self.version = pluginItem.version
        self.author = nil
        self.marketplace = pluginItem.marketplace
        self.rating = nil
        self.installCount = nil
        self.reviewCount = nil
        self.tags = nil
        self.commands = pluginItem.commands
        self.agents = pluginItem.agents
        self.isInstalled = true
        self.isEnabled = pluginItem.isEnabled
        self.pluginItem = pluginItem
    }

    /// Initialize from a marketplace plugin
    init(marketplacePlugin: MarketplacePlugin, marketplace: String) {
        self.name = marketplacePlugin.name
        self.description = marketplacePlugin.description
        self.version = marketplacePlugin.version
        self.author = marketplacePlugin.author
        self.marketplace = marketplace
        self.rating = marketplacePlugin.rating
        self.installCount = marketplacePlugin.installCount
        self.reviewCount = marketplacePlugin.reviewCount
        self.tags = marketplacePlugin.tags
        self.commands = nil
        self.agents = nil
        self.isInstalled = false
        self.isEnabled = false
        self.pluginItem = nil
    }
}

// MARK: - Preview

#Preview {
    PluginDetailView(
        plugin: PluginDetailData(
            pluginItem: PluginItem(
                id: UUID(),
                name: "GitHub Integration",
                description: "Seamlessly integrate with GitHub repositories",
                marketplace: "official",
                isInstalled: true,
                isEnabled: true,
                version: "1.0.0",
                commands: ["/github-pr", "/github-issue", "/github-commit"],
                agents: ["github-agent", "pr-reviewer"]
            )
        ),
        viewModel: PluginsViewModel()
    )
}
