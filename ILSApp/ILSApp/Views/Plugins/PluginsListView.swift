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
            } else if viewModel.plugins.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No Plugins",
                    systemImage: "puzzlepiece.extension",
                    description: "Install plugins from the marketplace",
                    actionTitle: "Browse Marketplace"
                ) {
                    showingMarketplace = true
                }
            } else {
                ForEach(viewModel.plugins) { plugin in
                    PluginRowView(plugin: plugin, viewModel: viewModel)
                }
            }
        }
        .darkListStyle()
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
                ProgressView("Loading plugins...")
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
    @ObservedObject var viewModel: PluginsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(plugin.name)
                    .font(ILSTheme.headlineFont)

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
                            .foregroundColor(ILSTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ILSTheme.accent.opacity(0.15))
                            .cornerRadius(ILSTheme.cornerRadiusXS)
                    }
                    if commands.count > 3 {
                        Text("+\(commands.count - 3)")
                            .font(.caption2)
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }
            }
        }
        .padding(.vertical, 4)
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
    @ObservedObject var viewModel: PluginsViewModel
    let apiClient: APIClient
    @State private var marketplaces: [MarketplaceInfo] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var newRepoPath = ""
    @State private var isAddingRepo = false
    @State private var installingPlugins: Set<String> = []

    private let categories = ["All", "Productivity", "DevOps", "Testing", "Documentation"]

    var filteredPlugins: [(marketplace: MarketplaceInfo, plugins: [MarketplacePlugin])] {
        if !searchText.isEmpty {
            return viewModel.searchResults.isEmpty ? [] : [
                (marketplace: MarketplaceInfo(name: "Search Results", source: "search", plugins: viewModel.searchResults),
                 plugins: viewModel.searchResults)
            ]
        }

        return marketplaces.map { marketplace in
            let filtered = selectedCategory == "All" ? marketplace.plugins : marketplace.plugins.filter { plugin in
                plugin.description?.lowercased().contains(selectedCategory.lowercased()) ?? false
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
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Text(category)
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(selectedCategory == category ? .white : ILSTheme.secondaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedCategory == category ? ILSTheme.accent : ILSTheme.tertiaryBackground)
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
                                            .foregroundColor(newRepoPath.isEmpty ? ILSTheme.tertiaryText : ILSTheme.accent)
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
            .onChange(of: searchText) { _, newValue in
                Task {
                    await viewModel.searchMarketplace(query: newValue)
                }
            }
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
            }
        } catch {
            print("Failed to load marketplaces: \(error)")
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
                        .background(ILSTheme.accent)
                        .cornerRadius(ILSTheme.cornerRadiusXS)
                }
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
}

#Preview {
    NavigationStack {
        PluginsListView()
    }
}
