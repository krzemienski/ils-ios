import SwiftUI
import ILSShared

struct PluginsListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = PluginsViewModel()
    @State private var showingMarketplace = false

    var body: some View {
        List {
            if let error = viewModel.error {
                ErrorStateView(error: error) {
                    await viewModel.loadPlugins()
                }
            } else if viewModel.filteredPlugins.isEmpty && !viewModel.isLoading {
                if viewModel.searchText.isEmpty {
                    EmptyEntityState(
                        entityType: .plugins,
                        title: "No Plugins",
                        description: "Install plugins from the marketplace",
                        actionTitle: "Browse Marketplace"
                    ) {
                        showingMarketplace = true
                    }
                } else {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            } else {
                ForEach(viewModel.filteredPlugins) { plugin in
                    PluginRowView(plugin: plugin, viewModel: viewModel)
                }
            }
        }
        .darkListStyle()
        .searchable(text: $viewModel.searchText, prompt: "Search plugins...")
        .navigationTitle("Plugins")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .refreshable {
            await viewModel.loadPlugins()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingMarketplace = true }) {
                    Image(systemName: "bag")
                }
                .accessibilityIdentifier("marketplaceButton")
            }
        }
        .sheet(isPresented: $showingMarketplace) {
            NavigationStack {
                MarketplaceView(viewModel: viewModel, apiClient: appState.apiClient)
                    .navigationTitle("Marketplace")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingMarketplace = false
                            }
                        }
                    }
            }
            .background(ILSTheme.background)
            .presentationBackground(Color.black)
        }
        .overlay {
            if viewModel.isLoading && viewModel.plugins.isEmpty {
                List {
                    SkeletonListView()
                }
                .darkListStyle()
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadPlugins()
        }
        .onChange(of: appState.isConnected) { _, isConnected in
            if isConnected && viewModel.error != nil {
                Task { await viewModel.loadPlugins() }
            }
        }
    }
}

struct PluginRowView: View {
    let plugin: PluginItem
    let viewModel: PluginsViewModel

    var body: some View {
        HStack(spacing: ILSTheme.spaceM) {
            Image(systemName: EntityType.plugins.icon)
                .font(.title3)
                .foregroundColor(EntityType.plugins.color)
                .frame(width: 28)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(plugin.name)
                    .font(ILSTheme.headlineFont)
                    .foregroundColor(ILSTheme.textPrimary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { plugin.isEnabled },
                    set: { _ in togglePlugin() }
                ))
                .labelsHidden()
            }

            if let description = plugin.description {
                Text(description)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
            }

            if let commands = plugin.commands, !commands.isEmpty {
                HStack {
                    ForEach(commands.prefix(3), id: \.self) { command in
                        Text(command)
                            .font(.caption2)
                            .foregroundColor(EntityType.plugins.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(EntityType.plugins.color.opacity(0.15))
                            .cornerRadius(ILSTheme.cornerRadiusXS)
                    }
                    if commands.count > 3 {
                        Text("+\(commands.count - 3)")
                            .font(.caption2)
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }
            }
        } // end VStack
        } // end HStack
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plugin.name), \(plugin.isEnabled ? "enabled" : "disabled")\(plugin.description.map { ", \($0)" } ?? "")")
        .accessibilityHint("Double tap to toggle plugin")
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task {
                    await viewModel.uninstallPlugin(plugin)
                }
            } label: {
                Label("Uninstall", systemImage: "trash")
            }
        }
    }

    private func togglePlugin() {
        HapticManager.impact(.light)
        Task {
            if plugin.isEnabled {
                await viewModel.disablePlugin(plugin)
            } else {
                await viewModel.enablePlugin(plugin)
            }
        }
    }
}

struct MarketplaceView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: PluginsViewModel
    let apiClient: APIClient
    @State private var marketplaces: [MarketplaceInfo] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var cachedCategories: [String] = ["All"]
    @State private var newRepoPath = ""
    @State private var isAddingRepo = false
    @State private var installingPlugins: Set<String> = []

    /// Rebuild cached categories from marketplace data
    private func rebuildCategories() {
        var cats = Set<String>()
        let keywords = ["productivity", "devops", "testing", "documentation", "security", "monitoring", "integration", "ai", "database", "networking", "utilities"]
        for marketplace in marketplaces {
            for plugin in marketplace.plugins {
                if let desc = plugin.description?.lowercased() {
                    for keyword in keywords where desc.contains(keyword) {
                        cats.insert(keyword.capitalized)
                    }
                }
                if let category = plugin.category, !category.isEmpty {
                    cats.insert(category)
                }
            }
        }
        cachedCategories = ["All"] + cats.sorted()
    }

    var filteredPlugins: [(marketplace: MarketplaceInfo, plugins: [MarketplacePlugin])] {
        return marketplaces.map { marketplace in
            var filtered = marketplace.plugins

            // Apply search filter
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                filtered = filtered.filter { plugin in
                    plugin.name.lowercased().contains(query) ||
                    (plugin.description?.lowercased().contains(query) ?? false)
                }
            }

            // Apply category filter
            if selectedCategory != "All" {
                filtered = filtered.filter { plugin in
                    plugin.description?.lowercased().contains(selectedCategory.lowercased()) ?? false
                }
            }

            return (marketplace, filtered)
        }.filter { !$0.plugins.isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(cachedCategories, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Text(category)
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(selectedCategory == category ? .white : ILSTheme.secondaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedCategory == category ? EntityType.plugins.color : ILSTheme.tertiaryBackground)
                                    .cornerRadius(ILSTheme.cornerRadiusXS)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(ILSTheme.background)

                List {
                    if isLoading {
                        ProgressView()
                    } else {
                        ForEach(filteredPlugins, id: \.marketplace.name) { item in
                            Section(item.marketplace.name) {
                                ForEach(item.plugins, id: \.name) { plugin in
                                    PluginMarketplaceRow(
                                        plugin: plugin,
                                        marketplace: item.marketplace.name,
                                        isInstalling: installingPlugins.contains(plugin.name)
                                    ) {
                                        await installPlugin(plugin, marketplace: item.marketplace.name)
                                    }
                                }
                            }
                        }

                        // Add from GitHub section
                        Section("Add from GitHub") {
                            HStack {
                                TextField("owner/repo", text: $newRepoPath)
                                    .font(ILSTheme.bodyFont)
                                    .foregroundColor(ILSTheme.primaryText)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()

                                if isAddingRepo {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Button(action: {
                                        Task { await addMarketplace() }
                                    }) {
                                        Text("Add")
                                            .font(ILSTheme.captionFont.weight(.semibold))
                                            .foregroundColor(newRepoPath.isEmpty ? ILSTheme.tertiaryText : EntityType.plugins.color)
                                    }
                                    .disabled(newRepoPath.isEmpty)
                                }
                            }
                        }
                    }
                }
                .darkListStyle()
                .scrollContentBackground(.hidden)
                .background(ILSTheme.background)
            }
            .searchable(text: $searchText, prompt: "Search plugins...")
            .navigationTitle("Marketplace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadMarketplaces()
            }
        }
    }

    private func loadMarketplaces() async {
        isLoading = true
        do {
            let response: APIResponse<[MarketplaceInfo]> = try await apiClient.get("/plugins/marketplace")
            if let data = response.data {
                marketplaces = data
                rebuildCategories()
            }
        } catch {
            AppLogger.shared.error("Failed to load marketplaces: \(error)", category: "ui")
        }
        isLoading = false
    }

    private func installPlugin(_ plugin: MarketplacePlugin, marketplace: String) async {
        installingPlugins.insert(plugin.name)
        await viewModel.installPlugin(name: plugin.name, marketplace: marketplace)
        installingPlugins.remove(plugin.name)
    }

    private func addMarketplace() async {
        guard !newRepoPath.isEmpty else { return }
        isAddingRepo = true
        let success = await viewModel.addMarketplace(repo: newRepoPath)
        if success {
            newRepoPath = ""
            await loadMarketplaces()
        }
        isAddingRepo = false
    }
}

struct PluginMarketplaceRow: View {
    let plugin: MarketplacePlugin
    let marketplace: String
    let isInstalling: Bool
    let onInstall: () async -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(plugin.name)
                    .font(ILSTheme.headlineFont)
                    .foregroundColor(ILSTheme.primaryText)

                if let desc = plugin.description {
                    Text(desc)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer()

            if isInstalling {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Installing...")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }
            } else {
                Button(action: {
                    Task { await onInstall() }
                }) {
                    Text("Install")
                        .font(ILSTheme.captionFont.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(EntityType.plugins.color)
                        .cornerRadius(ILSTheme.cornerRadiusXS)
                }
                .accessibilityLabel("Install \(plugin.name)")
            }
        }
    }
}

// MARK: - Models

struct PluginItem: Identifiable, Decodable {
    let id: UUID
    let name: String
    let description: String?
    let marketplace: String?
    let isInstalled: Bool
    var isEnabled: Bool
    let version: String?
    let commands: [String]?
    let agents: [String]?
}

struct MarketplaceInfo: Decodable {
    let name: String
    let source: String
    let plugins: [MarketplacePlugin]
}

struct MarketplacePlugin: Decodable {
    let name: String
    let description: String?
    let category: String?
}

#Preview {
    NavigationStack {
        PluginsListView()
    }
}
