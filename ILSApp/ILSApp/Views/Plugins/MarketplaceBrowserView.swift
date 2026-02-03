import SwiftUI
import ILSShared

struct MarketplaceBrowserView: View {
    @ObservedObject var viewModel: PluginsViewModel
    @State private var searchText = ""
    @State private var displayMode: DisplayMode = .grid

    enum DisplayMode {
        case grid
        case list
    }

    private var filteredMarketplaces: [MarketplaceInfo] {
        if searchText.isEmpty {
            return viewModel.marketplaces
        }
        return viewModel.marketplaces.compactMap { marketplace in
            let filteredPlugins = marketplace.plugins.filter { plugin in
                plugin.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.description?.localizedCaseInsensitiveContains(searchText) == true
            }
            if filteredPlugins.isEmpty {
                return nil
            }
            return MarketplaceInfo(
                name: marketplace.name,
                source: marketplace.source,
                plugins: filteredPlugins
            )
        }
    }

    var body: some View {
        ZStack {
            if viewModel.isLoadingMarketplace && viewModel.marketplaces.isEmpty {
                ProgressView("Loading marketplace...")
            } else if let error = viewModel.error {
                ErrorStateView(error: error) {
                    await viewModel.loadMarketplaces()
                }
            } else if filteredMarketplaces.isEmpty {
                if searchText.isEmpty {
                    EmptyStateView(
                        title: "No Plugins Available",
                        systemImage: "bag",
                        description: "No marketplace plugins found",
                        actionTitle: nil
                    ) {
                        // No action
                    }
                } else {
                    EmptyStateView(
                        title: "No Results",
                        systemImage: "magnifyingglass",
                        description: "No plugins match your search",
                        actionTitle: nil
                    ) {
                        // No action
                    }
                }
            } else {
                if displayMode == .grid {
                    gridView
                } else {
                    listView
                }
            }
        }
        .navigationTitle("Browse Marketplace")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    displayMode = displayMode == .grid ? .list : .grid
                } label: {
                    Image(systemName: displayMode == .grid ? "list.bullet" : "square.grid.2x2")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search marketplace")
        .refreshable {
            await viewModel.loadMarketplaces()
        }
        .task {
            if viewModel.marketplaces.isEmpty {
                await viewModel.loadMarketplaces()
            }
        }
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ILSTheme.spacingL) {
                ForEach(filteredMarketplaces, id: \.name) { marketplace in
                    VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
                        Text(marketplace.name)
                            .font(ILSTheme.headlineFont)
                            .padding(.horizontal, ILSTheme.spacingM)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: ILSTheme.spacingM),
                            GridItem(.flexible(), spacing: ILSTheme.spacingM)
                        ], spacing: ILSTheme.spacingM) {
                            ForEach(marketplace.plugins, id: \.name) { plugin in
                                PluginGridCard(plugin: plugin, marketplace: marketplace.name, viewModel: viewModel)
                            }
                        }
                        .padding(.horizontal, ILSTheme.spacingM)
                    }
                }
            }
            .padding(.vertical, ILSTheme.spacingM)
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(filteredMarketplaces, id: \.name) { marketplace in
                Section(marketplace.name) {
                    ForEach(marketplace.plugins, id: \.name) { plugin in
                        PluginListRow(plugin: plugin, marketplace: marketplace.name, viewModel: viewModel)
                    }
                }
            }
        }
    }
}

// MARK: - Grid Card

struct PluginGridCard: View {
    let plugin: MarketplacePlugin
    let marketplace: String
    @ObservedObject var viewModel: PluginsViewModel
    @State private var isInstalling = false

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
            // Plugin name
            Text(plugin.name)
                .font(ILSTheme.headlineFont)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Description
            if let description = plugin.description {
                Text(description)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .lineLimit(3)
            }

            Spacer()

            // Stats row
            HStack(spacing: ILSTheme.spacingS) {
                if let rating = plugin.rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.caption2)
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }

                if let installCount = plugin.installCount {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.circle")
                            .font(.caption2)
                            .foregroundColor(ILSTheme.secondaryText)
                        Text("\(installCount)")
                            .font(.caption2)
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }
            }

            // Tags
            if let tags = plugin.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ILSTheme.spacingXS) {
                        ForEach(tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ILSTheme.tertiaryBackground)
                                .cornerRadius(ILSTheme.cornerRadiusS)
                        }
                    }
                }
            }

            // Install button
            Button {
                Task {
                    isInstalling = true
                    await viewModel.installPlugin(name: plugin.name, marketplace: marketplace)
                    isInstalling = false
                }
            } label: {
                if isInstalling {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Install")
                        .font(ILSTheme.bodyFont)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(isInstalling)
        }
        .padding(ILSTheme.spacingM)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(ILSTheme.secondaryBackground)
        .cornerRadius(ILSTheme.cornerRadiusL)
    }
}

// MARK: - List Row

struct PluginListRow: View {
    let plugin: MarketplacePlugin
    let marketplace: String
    @ObservedObject var viewModel: PluginsViewModel
    @State private var isInstalling = false

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingXS) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plugin.name)
                        .font(ILSTheme.headlineFont)

                    if let description = plugin.description {
                        Text(description)
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.secondaryText)
                            .lineLimit(2)
                    }

                    // Stats row
                    HStack(spacing: ILSTheme.spacingM) {
                        if let rating = plugin.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption2)
                                    .foregroundColor(ILSTheme.secondaryText)
                            }
                        }

                        if let installCount = plugin.installCount {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.caption2)
                                    .foregroundColor(ILSTheme.secondaryText)
                                Text("\(installCount)")
                                    .font(.caption2)
                                    .foregroundColor(ILSTheme.secondaryText)
                            }
                        }

                        if let author = plugin.author {
                            HStack(spacing: 2) {
                                Image(systemName: "person")
                                    .font(.caption2)
                                    .foregroundColor(ILSTheme.secondaryText)
                                Text(author)
                                    .font(.caption2)
                                    .foregroundColor(ILSTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    Task {
                        isInstalling = true
                        await viewModel.installPlugin(name: plugin.name, marketplace: marketplace)
                        isInstalling = false
                    }
                } label: {
                    if isInstalling {
                        ProgressView()
                    } else {
                        Text("Install")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isInstalling)
            }

            // Tags
            if let tags = plugin.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ILSTheme.spacingXS) {
                        ForEach(tags.prefix(5), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ILSTheme.tertiaryBackground)
                                .cornerRadius(ILSTheme.cornerRadiusS)
                        }
                    }
                }
            }
        }
        .padding(.vertical, ILSTheme.spacingXS)
    }
}

#Preview {
    NavigationStack {
        MarketplaceBrowserView(viewModel: PluginsViewModel())
    }
}
