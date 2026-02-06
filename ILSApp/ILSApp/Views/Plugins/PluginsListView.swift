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

    var body: some View {
        NavigationStack {
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
                                    .buttonStyle(PrimaryButtonStyle())
                                }
                            }
                        }
                    }
                }
            }
            .darkListStyle()
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
