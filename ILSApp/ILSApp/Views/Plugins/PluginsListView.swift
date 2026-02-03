import SwiftUI
import ILSShared

struct PluginsListView: View {
    @StateObject private var viewModel = PluginsViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Installed Tab
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
                        selectedTab = 1
                    }
                } else {
                    ForEach(viewModel.plugins) { plugin in
                        PluginRowView(plugin: plugin, viewModel: viewModel)
                    }
                }
            }
            .refreshable {
                await viewModel.loadPlugins()
            }
            .overlay {
                if viewModel.isLoading && viewModel.plugins.isEmpty {
                    ProgressView("Loading plugins...")
                }
            }
            .task {
                await viewModel.loadPlugins()
            }
            .tabItem {
                Label("Installed", systemImage: "puzzlepiece.extension")
            }
            .tag(0)

            // Browse Tab
            MarketplaceView(viewModel: viewModel)
                .tabItem {
                    Label("Browse", systemImage: "bag")
                }
                .tag(1)
        }
        .navigationTitle("Plugins")
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
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ILSTheme.tertiaryBackground)
                            .cornerRadius(ILSTheme.cornerRadiusS)
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
    @ObservedObject var viewModel: PluginsViewModel
    @State private var marketplaces: [MarketplaceInfo] = []
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else {
                ForEach(marketplaces, id: \.name) { marketplace in
                    Section(marketplace.name) {
                        ForEach(marketplace.plugins, id: \.name) { plugin in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(plugin.name)
                                        .font(ILSTheme.headlineFont)
                                    if let desc = plugin.description {
                                        Text(desc)
                                            .font(ILSTheme.captionFont)
                                            .foregroundColor(ILSTheme.secondaryText)
                                    }
                                }

                                Spacer()

                                Button("Install") {
                                    Task {
                                        await viewModel.installPlugin(
                                            name: plugin.name,
                                            marketplace: marketplace.name
                                        )
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
        .task {
            await loadMarketplaces()
        }
    }

    private func loadMarketplaces() async {
        isLoading = true
        do {
            let client = APIClient()
            let response: APIResponse<[MarketplaceInfo]> = try await client.get("/plugins/marketplace")
            if let data = response.data {
                marketplaces = data
            }
        } catch {
            print("Failed to load marketplaces: \(error)")
        }
        isLoading = false
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
