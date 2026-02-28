import SwiftUI
import ILSShared
import TipKit

// MARK: - Browser Segment

enum BrowserSegment: String, CaseIterable {
    case mcp = "MCP"
    case skills = "Skills"
    case plugins = "Plugins"
    case discover = "Discover"
}

enum DiscoverType: String, CaseIterable {
    case mcp = "MCP"
    case skills = "Skills"
    case plugins = "Plugins"
}

// MARK: - Browser View

/// Tabbed browsing view presenting MCP servers, Skills, and Plugins in a single scrollable interface.
///
/// `BrowserView` renders a three-segment control at the top (MCP / Skills / Plugins) and a
/// shared search bar whose text is forwarded to each tab's view-model. Switching segments
/// swaps the content area between ``mcpContent``, ``skillsContent``, and ``pluginsContent``
/// without reloading already-fetched data.
///
/// On first appearance all three tabs are loaded concurrently via ``loadAll()``, which fans
/// out to `MCPViewModel.loadServers()`, `SkillsViewModel.loadSkills()`, and
/// `PluginsViewModel.loadPlugins()` using Swift structured concurrency. The view re-loads
/// whenever `AppState.isConnected` transitions to `true` (e.g. after a reconnect).
/// Pull-to-refresh on the scroll view calls ``refreshCurrentSegment()`` to reload only the
/// visible tab.
///
/// Each content section handles three display states:
/// - **Loading** — skeleton placeholder rows shown while the view-model's `isLoading` flag is set and the item list is empty.
/// - **Empty** — a centred icon/title/subtitle via ``emptyState(icon:title:subtitle:)`` when loading completes with no items.
/// - **Populated** — `NavigationLink` rows using the shared ``browserRow(name:subtitle:status:statusColor:entityColor:badge:)`` helper.
///
/// The MCP tab adds a second scope filter (all / user / project / local) that re-fetches
/// servers through `MCPViewModel.loadServers(scope:)` when changed.
///
/// The Skills tab appends a GitHub search section (``githubBrowseSection``) below the local
/// list, enabling one-tap install of remote skills via `SkillsViewModel.installFromGitHub(result:)`.
///
/// The Plugins tab shows horizontal category-filter chips derived from
/// `PluginsViewModel.pluginCategories` and renders richer ``pluginRow(_:)`` cards with
/// version / source / stars badges.
///
/// ## Topics
/// ### Configuration
/// - ``initialSegment`` - The tab displayed when the view first appears
///
/// ### State
/// - ``mcpVM`` - Observable view-model managing MCP server data and search
/// - ``skillsVM`` - Observable view-model managing skills data, search, and GitHub browsing
/// - ``pluginsVM`` - Observable view-model managing plugins data, search, and category filtering
/// - ``segment`` - The currently active ``BrowserSegment`` tab
/// - ``searchText`` - Live search query forwarded to all three view-models
/// - ``mcpScope`` - Active MCP scope filter: `"all"`, `"user"`, `"project"`, or `"local"`
/// - ``isSearchFocused`` - Focus state that drives the search bar focus ring
///
/// ### Async Loading
/// - ``loadAll()`` - Concurrently loads all three tabs on first appearance
/// - ``refreshCurrentSegment()`` - Refreshes only the currently visible tab (pull-to-refresh)
struct BrowserView: View {
    /// The tab that is selected when the view first appears; defaults to `.mcp`.
    var initialSegment: BrowserSegment = .mcp

    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Observable view-model that owns MCP server list, filtered results, and loading state.
    @State private var mcpVM = MCPViewModel()
    /// Observable view-model that owns skills list, filtered results, GitHub search, and loading state.
    @State private var skillsVM = SkillsViewModel()
    /// Observable view-model that owns plugins list, category filtering, and loading state.
    @State private var pluginsVM = PluginsViewModel()
    /// Observable view-model that owns the curated MCP marketplace catalog.
    @State private var mcpMarketplaceVM = MCPMarketplaceViewModel()

    /// The currently visible tab; animated transitions unless `reduceMotion` is enabled.
    @State private var segment: BrowserSegment = .mcp
    /// Shared search query applied to all three tabs simultaneously via each view-model's `searchText`.
    @State private var searchText = ""
    /// Active scope filter for the MCP tab (`"all"`, `"user"`, `"project"`, or `"local"`).
    @State private var mcpScope: String = "all"
    /// Tracks keyboard focus on the search bar to render the themed focus ring.
    @FocusState private var isSearchFocused: Bool
    /// Sub-segment within the Discover tab: search skills or plugins
    @State private var discoverType: DiscoverType = .skills

    /// TipKit tip surfacing the MCP browser after session creation.
    private let mcpBrowserTip = MCPBrowserTip()

    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            segmentedControl
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)

            // Search bar
            searchBar
                .padding(.horizontal, theme.spacingMD)
                .padding(.bottom, theme.spacingSM)

            // Content
            ScrollView {
                // UIPERF-05: Verified — LazyVStack used for efficient browser content rendering.
                LazyVStack(spacing: theme.spacingSM) {
                    // Cache freshness indicator per segment (DATA-04)
                    HStack {
                        Spacer()
                        switch segment {
                        case .mcp:
                            CacheStatusView(lastUpdated: mcpVM.lastUpdated)
                        case .skills:
                            CacheStatusView(lastUpdated: skillsVM.lastUpdated)
                        case .plugins:
                            CacheStatusView(lastUpdated: pluginsVM.lastUpdated)
                        case .discover:
                            EmptyView()
                        }
                    }

                    switch segment {
                    case .mcp:
                        mcpContent
                    case .skills:
                        skillsContent
                    case .plugins:
                        pluginsContent
                    case .discover:
                        discoverContent
                    }
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.bottom, theme.spacingLG)
            }
            .refreshable {
                HapticManager.impact(.medium)
                await refreshCurrentSegment()
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Browse")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .task {
            // Consume deep link segment intent if present; otherwise use initialSegment
            if let intent = appState.browserSegmentIntent {
                segment = intent
                appState.browserSegmentIntent = nil
            } else {
                segment = initialSegment
            }
            mcpVM.configure(client: appState.apiClient)
            skillsVM.configure(client: appState.apiClient)
            pluginsVM.configure(client: appState.apiClient)
            mcpMarketplaceVM.configure(client: appState.apiClient)
            await loadAll()
        }
        .onChange(of: appState.browserSegmentIntent) { _, intent in
            // React to deep links when BrowserView is already on screen
            guard let intent else { return }
            segment = intent
            appState.browserSegmentIntent = nil
        }
        .onChange(of: appState.isConnected) { _, connected in
            if connected {
                Task { await loadAll() }
            }
        }
        .onChange(of: appState.serverURL) { _, _ in
            mcpVM.configure(client: appState.apiClient)
            skillsVM.configure(client: appState.apiClient)
            pluginsVM.configure(client: appState.apiClient)
            mcpMarketplaceVM.configure(client: appState.apiClient)
            Task { await loadAll() }
        }
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(BrowserSegment.allCases, id: \.self) { seg in
                Button {
                    HapticManager.selection()
                    if reduceMotion {
                        segment = seg
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            segment = seg
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(entityColor(for: seg))
                            .frame(width: 8, height: 8)
                        Text(seg.rawValue)
                            .font(.system(size: theme.fontCaption, weight: segment == seg ? .semibold : .regular, design: theme.fontDesign))
                        Text("(\(countFor(seg)))")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .foregroundStyle(segment == seg ? theme.textPrimary : theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(
                        segment == seg
                            ? entityColor(for: seg).opacity(0.15)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(seg.rawValue), \(countFor(seg)) items")
            }
        }
        .padding(4)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            TextField("Search \(segment.rawValue.lowercased())...", text: $searchText)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .focused($isSearchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .focusRing(isFocused: isSearchFocused, cornerRadius: theme.cornerRadiusSmall)
        .onChange(of: searchText) { _, text in
            mcpVM.searchText = text
            skillsVM.searchText = text
            pluginsVM.searchText = text
        }
    }

    // MARK: - MCP Content

    @ViewBuilder
    private var mcpContent: some View {
        TipView(mcpBrowserTip)
            .tipBackground(theme.bgSecondary)
            .onAppear {
                TeamsTip.hasViewedMCP = true
            }

        // Scope segmented control
        VStack(spacing: theme.spacingSM) {
            HStack(spacing: 0) {
                ForEach(["all", "user", "project", "local"], id: \.self) { scope in
                    Button {
                        HapticManager.selection()
                        mcpScope = scope
                    } label: {
                        Text(scope.capitalized)
                            .font(.system(size: theme.fontCaption, weight: mcpScope == scope ? .semibold : .regular, design: theme.fontDesign))
                            .foregroundStyle(mcpScope == scope ? theme.textPrimary : theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacingSM)
                            .background(mcpScope == scope ? theme.accent.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(scope.capitalized) scope filter")
                }
            }
            .padding(4)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .padding(.horizontal, theme.spacingMD)
            .onChange(of: mcpScope) { _, newScope in
                Task {
                    if newScope == "all" {
                        await mcpVM.loadServers()
                    } else {
                        await mcpVM.loadServers(scope: newScope)
                    }
                }
            }

            let items = mcpVM.filteredServers
            if mcpVM.isLoading && items.isEmpty {
                loadingRows
            } else if items.isEmpty {
                emptyState(
                    icon: "server.rack",
                    title: searchText.isEmpty ? "No MCP Servers" : "No Results",
                    subtitle: searchText.isEmpty ? "No servers configured" : "Try a different search"
                )
            } else {
                ForEach(items) { server in
                    NavigationLink {
                        MCPServerDetailView(server: server)
                    } label: {
                        browserRow(
                            name: server.name,
                            subtitle: "\(server.command) \(server.args.joined(separator: " "))",
                            status: server.status == .healthy ? "Healthy" : (server.status == .unhealthy ? "Unhealthy" : "Unknown"),
                            statusColor: server.status == .healthy ? theme.success : (server.status == .unhealthy ? theme.error : theme.warning),
                            entityColor: theme.entityMCP,
                            badge: server.scope.rawValue.capitalized
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Skills Content

    @ViewBuilder
    private var skillsContent: some View {
        let items = skillsVM.filteredSkills
        if skillsVM.isLoading && items.isEmpty {
            loadingRows
        } else if items.isEmpty && searchText.isEmpty {
            emptyState(
                icon: "sparkles",
                title: "No Skills",
                subtitle: "No skills found in ~/.claude/skills"
            )
        } else if items.isEmpty {
            emptyState(
                icon: "sparkles",
                title: "No Results",
                subtitle: "Try a different search"
            )
        } else {
            ForEach(items) { skill in
                HStack(spacing: 0) {
                    NavigationLink {
                        SkillDetailView(skill: skill)
                    } label: {
                        browserRow(
                            name: skill.name,
                            subtitle: skill.description ?? "No description",
                            status: skill.isActive ? "Active" : "Inactive",
                            statusColor: skill.isActive ? theme.success : theme.textTertiary,
                            entityColor: theme.entitySkill,
                            badge: skill.tags.first
                        )
                    }
                    .buttonStyle(.plain)

                    // Visible toggle button for active/inactive status
                    Button {
                        Task { await skillsVM.toggleSkillActive(skill) }
                    } label: {
                        Image(systemName: skill.isActive ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(skill.isActive ? theme.success : theme.textTertiary)
                            .font(.system(size: 22))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(skill.isActive ? "Disable \(skill.name)" : "Enable \(skill.name)")
                }
                .contextMenu {
                    Button {
                        Task { await skillsVM.toggleSkillActive(skill) }
                    } label: {
                        Label(skill.isActive ? "Disable" : "Enable", systemImage: skill.isActive ? "pause.circle" : "play.circle")
                    }
                    if skill.source == .local || skill.source == .github {
                        Button(role: .destructive) {
                            Task { await skillsVM.deleteSkill(skill) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Plugins Content

    @ViewBuilder
    private var pluginsContent: some View {
        VStack(spacing: theme.spacingSM) {
            // Category filter chips
            if !pluginsVM.pluginCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacingSM) {
                        ForEach(pluginsVM.pluginCategories, id: \.self) { category in
                            Button {
                                pluginsVM.selectedCategory = category
                            } label: {
                                Text(category)
                                    .font(.system(size: theme.fontCaption, weight: pluginsVM.selectedCategory == category ? .semibold : .regular, design: theme.fontDesign))
                                    .foregroundStyle(pluginsVM.selectedCategory == category ? theme.textPrimary : theme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        pluginsVM.selectedCategory == category
                                            ? theme.entityPlugin.opacity(0.2)
                                            : theme.bgSecondary
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, theme.spacingMD)
                }
            }

            let items = pluginsVM.filteredPluginsByCategory
            if pluginsVM.isLoading && items.isEmpty {
                loadingRows
            } else if items.isEmpty {
                emptyState(
                    icon: "puzzlepiece.extension",
                    title: searchText.isEmpty ? "No Plugins" : "No Results",
                    subtitle: searchText.isEmpty ? "No plugins installed" : "Try a different search"
                )
            } else {
                ForEach(items) { plugin in
                    NavigationLink {
                        PluginConfigView(
                            plugin: plugin,
                            onToggleEnabled: { p in
                                if p.isEnabled {
                                    await pluginsVM.disablePlugin(p)
                                } else {
                                    await pluginsVM.enablePlugin(p)
                                }
                            },
                            onUninstall: { p in
                                await pluginsVM.uninstallPlugin(p)
                            }
                        )
                        .environment(pluginsVM)
                    } label: {
                        pluginRow(plugin)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            Task {
                                if plugin.isEnabled {
                                    await pluginsVM.disablePlugin(plugin)
                                } else {
                                    await pluginsVM.enablePlugin(plugin)
                                }
                            }
                        } label: {
                            Label(plugin.isEnabled ? "Disable" : "Enable", systemImage: plugin.isEnabled ? "pause.circle" : "play.circle")
                        }
                        Button(role: .destructive) {
                            Task { await pluginsVM.uninstallPlugin(plugin) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }

        }
    }

    // MARK: - Discover Content

    @ViewBuilder
    private var discoverContent: some View {
        VStack(spacing: theme.spacingSM) {
            // Sub-segment picker: Skills vs Plugins
            Picker("Type", selection: $discoverType) {
                ForEach(DiscoverType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, theme.spacingSM)

            // Search field
            discoverSearchField

            // Rate limit banner
            discoverRateLimitBanner

            // Results
            switch discoverType {
            case .mcp:
                discoverMCPResults
            case .skills:
                discoverSkillResults
            case .plugins:
                discoverPluginResults
            }
        }
    }

    @ViewBuilder
    private var discoverSearchField: some View {
        let searchBinding = discoverType == .mcp
            ? $mcpVM.gitHubSearchText
            : (discoverType == .skills ? $skillsVM.gitHubSearchText : $pluginsVM.gitHubSearchText)
        let isSearching = discoverType == .mcp
            ? mcpVM.isSearchingGitHub
            : (discoverType == .skills ? skillsVM.isSearchingGitHub : pluginsVM.isSearchingGitHub)

        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))

            TextField(
                discoverType == .mcp
                    ? "Search GitHub for MCP servers..."
                    : (discoverType == .skills ? "Search GitHub for skills..." : "Search GitHub for plugins..."),
                text: searchBinding
            )
            .font(.system(size: theme.fontBody, design: theme.fontDesign))
            .foregroundStyle(theme.textPrimary)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .onChange(of: mcpVM.gitHubSearchText) { _, text in
                guard discoverType == .mcp, text.count >= 3 else {
                    if discoverType == .mcp && text.isEmpty {
                        mcpVM.gitHubResults = []
                    }
                    return
                }
                mcpVM.updateGitHubSearchText(text)
            }
            .onChange(of: skillsVM.gitHubSearchText) { _, text in
                guard discoverType == .skills, text.count >= 3 else {
                    if discoverType == .skills && text.isEmpty {
                        skillsVM.gitHubResults = []
                    }
                    return
                }
                skillsVM.updateGitHubSearchText(text)
            }
            .onChange(of: pluginsVM.gitHubSearchText) { _, text in
                guard discoverType == .plugins, text.count >= 3 else {
                    if discoverType == .plugins && text.isEmpty {
                        pluginsVM.gitHubResults = []
                    }
                    return
                }
                pluginsVM.updateGitHubSearchText(text)
            }

            let currentSearchText = discoverType == .mcp
                ? mcpVM.gitHubSearchText
                : (discoverType == .skills ? skillsVM.gitHubSearchText : pluginsVM.gitHubSearchText)
            if !currentSearchText.isEmpty {
                Button {
                    if discoverType == .mcp {
                        mcpVM.gitHubSearchText = ""
                        mcpVM.gitHubResults = []
                    } else if discoverType == .skills {
                        skillsVM.gitHubSearchText = ""
                        skillsVM.gitHubResults = []
                    } else {
                        pluginsVM.gitHubSearchText = ""
                        pluginsVM.gitHubResults = []
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            if isSearching {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
                    .tint(theme.accent)
            }
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    @ViewBuilder
    private var discoverRateLimitBanner: some View {
        let gitHubError = discoverType == .mcp
            ? mcpVM.gitHubError
            : (discoverType == .skills ? skillsVM.gitHubError : pluginsVM.gitHubError)
        let countdown = discoverType == .mcp
            ? mcpVM.rateLimitCountdown
            : (discoverType == .skills ? skillsVM.rateLimitCountdown : pluginsVM.rateLimitCountdown)

        if let errorMsg = gitHubError {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.warning)
                if countdown > 0 {
                    Text("Try again in \(countdown) seconds")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                } else {
                    Text(errorMsg)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(theme.spacingMD)
            .background(theme.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
    }

    @ViewBuilder
    private var discoverSkillResults: some View {
        let searchText = skillsVM.gitHubSearchText

        if !skillsVM.gitHubResults.isEmpty {
            VStack(spacing: theme.spacingSM) {
                ForEach(skillsVM.gitHubResults, id: \.repository) { result in
                    NavigationLink {
                        GitHubPreviewView(
                            result: result,
                            entityType: .skill,
                            skillsVM: skillsVM,
                            pluginsVM: pluginsVM
                        )
                    } label: {
                        discoverResultRow(
                            result: result,
                            entityColor: theme.entitySkill,
                            isInstalled: skillsVM.isInstalled(result: result),
                            isInstalling: skillsVM.installingSkills.contains(result.repository)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if searchText.count >= 3 && !skillsVM.isSearchingGitHub {
            Text("No skills found on GitHub for \"\(searchText)\"")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingMD)
        } else if searchText.count > 0 && searchText.count < 3 {
            Text("Type at least 3 characters to search")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingMD)
        } else {
            // Empty state -- show browsing hint
            VStack(spacing: theme.spacingSM) {
                Image(systemName: "globe.americas")
                    .font(.system(size: 40))
                    .foregroundStyle(theme.textTertiary.opacity(0.5))
                Text("Search GitHub for Claude Code skills")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Text("Find and install community skills with search")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingXL)
        }
    }

    @ViewBuilder
    private var discoverPluginResults: some View {
        let searchText = pluginsVM.gitHubSearchText

        if !pluginsVM.gitHubResults.isEmpty {
            VStack(spacing: theme.spacingSM) {
                ForEach(pluginsVM.gitHubResults, id: \.repository) { result in
                    NavigationLink {
                        GitHubPreviewView(
                            result: result,
                            entityType: .plugin,
                            skillsVM: skillsVM,
                            pluginsVM: pluginsVM
                        )
                    } label: {
                        discoverResultRow(
                            result: result,
                            entityColor: theme.entityPlugin,
                            isInstalled: pluginsVM.isInstalled(result: result),
                            isInstalling: pluginsVM.installingPlugins.contains(result.repository)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if searchText.count >= 3 && !pluginsVM.isSearchingGitHub {
            Text("No plugins found on GitHub for \"\(searchText)\"")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingMD)
        } else if searchText.count > 0 && searchText.count < 3 {
            Text("Type at least 3 characters to search")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingMD)
        } else {
            VStack(spacing: theme.spacingSM) {
                Image(systemName: "globe.americas")
                    .font(.system(size: 40))
                    .foregroundStyle(theme.textTertiary.opacity(0.5))
                Text("Search GitHub for Claude Code plugins")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Text("Find and install community plugins with search")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingXL)
        }
    }

    // MARK: - MCP Discover Results

    @ViewBuilder
    private var discoverMCPResults: some View {
        let searchText = mcpVM.gitHubSearchText

        if searchText.isEmpty {
            // Curated featured list with category filter chips
            VStack(spacing: theme.spacingSM) {
                // Category filter chips
                if !mcpMarketplaceVM.categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: theme.spacingSM) {
                            ForEach(mcpMarketplaceVM.categories, id: \.self) { category in
                                Button {
                                    mcpMarketplaceVM.selectedCategory = category
                                } label: {
                                    Text(category)
                                        .font(.system(size: theme.fontCaption, weight: mcpMarketplaceVM.selectedCategory == category ? .semibold : .regular, design: theme.fontDesign))
                                        .foregroundStyle(mcpMarketplaceVM.selectedCategory == category ? theme.textPrimary : theme.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            mcpMarketplaceVM.selectedCategory == category
                                                ? theme.entityMCP.opacity(0.2)
                                                : theme.bgSecondary
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, theme.spacingMD)
                    }
                }

                let entries = mcpMarketplaceVM.filteredEntries
                if mcpMarketplaceVM.isLoadingFeatured && entries.isEmpty {
                    loadingRows
                } else if entries.isEmpty {
                    VStack(spacing: theme.spacingSM) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 40))
                            .foregroundStyle(theme.textTertiary.opacity(0.5))
                        Text("MCP Marketplace")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                        Text("Search GitHub for MCP servers or browse curated picks")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingXL)
                } else {
                    ForEach(entries) { entry in
                        mcpMarketplaceEntryRow(entry)
                    }
                }
            }
        } else if !mcpVM.gitHubResults.isEmpty {
            VStack(spacing: theme.spacingSM) {
                ForEach(mcpVM.gitHubResults, id: \.repository) { result in
                    discoverResultRow(
                        result: result,
                        entityColor: theme.entityMCP,
                        isInstalled: mcpVM.isInstalled(result: result),
                        isInstalling: mcpVM.installingMCPServers.contains(result.repository)
                    )
                }
            }
        } else if searchText.count >= 3 && !mcpVM.isSearchingGitHub {
            Text("No MCP servers found on GitHub for \"\(searchText)\"")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingMD)
        } else if searchText.count > 0 && searchText.count < 3 {
            Text("Type at least 3 characters to search")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingMD)
        } else {
            VStack(spacing: theme.spacingSM) {
                Image(systemName: "globe.americas")
                    .font(.system(size: 40))
                    .foregroundStyle(theme.textTertiary.opacity(0.5))
                Text("Search GitHub for MCP servers")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Text("Find and install community MCP servers with search")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingXL)
        }
    }

    @ViewBuilder
    private func mcpMarketplaceEntryRow(_ entry: MCPMarketplaceEntry) -> some View {
        HStack(spacing: theme.spacingMD) {
            Circle()
                .fill(theme.entityMCP.opacity(0.6))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.name)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if entry.isStaffPick {
                        Text("Staff Pick")
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(theme.warning.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    if entry.stars > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.warning)
                            Text("\(entry.stars)")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }

                if let description = entry.description {
                    Text(description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: theme.spacingSM) {
                    Text(entry.category)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(entry.repository)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.name), \(entry.category)")
    }

    /// Shared result row used by both skill and plugin discover results.
    @ViewBuilder
    private func discoverResultRow(
        result: GitHubSearchResult,
        entityColor: Color,
        isInstalled: Bool,
        isInstalling: Bool
    ) -> some View {
        HStack(spacing: theme.spacingMD) {
            // Entity dot
            Circle()
                .fill(entityColor.opacity(0.6))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.name.isEmpty ? result.repository : result.name)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if isInstalled {
                        Text("Installed")
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(theme.success.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    if result.stars > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.warning)
                            Text("\(result.stars)")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }

                if let description = result.description {
                    Text(description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                Text(result.repository)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            // Status indicator (no install button in row -- install is in preview)
            if isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.success)
            } else if isInstalling {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
                    .tint(theme.accent)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Plugin Row (delegates to PluginRowView)

    private func pluginRow(_ plugin: Plugin) -> some View {
        let isInstalling = pluginsVM.installingPlugins.contains(plugin.name)
        return PluginRowView(
            plugin: plugin,
            isInstalling: isInstalling,
            onToggle: {
                Task {
                    if plugin.isEnabled {
                        await pluginsVM.disablePlugin(plugin)
                    } else {
                        await pluginsVM.enablePlugin(plugin)
                    }
                }
            }
        )
        .equatable()
    }

    // MARK: - Shared Row (delegates to BrowserRowView)

    private func browserRow(
        name: String,
        subtitle: String,
        status: String,
        statusColor: Color,
        entityColor: Color,
        badge: String?
    ) -> some View {
        BrowserRowView(
            name: name,
            subtitle: subtitle,
            status: status,
            statusColor: statusColor,
            entityColor: entityColor,
            badge: badge
        )
        .equatable()
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 40, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text(title)
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text(subtitle)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingXL)
    }

    // MARK: - Loading

    private var loadingRows: some View {
        SkeletonListView()
    }

    // MARK: - Helpers

    private func entityColor(for seg: BrowserSegment) -> Color {
        switch seg {
        case .mcp: return theme.entityMCP
        case .skills: return theme.entitySkill
        case .plugins: return theme.entityPlugin
        case .discover: return theme.accent
        }
    }

    private func countFor(_ seg: BrowserSegment) -> Int {
        switch seg {
        case .mcp: return mcpVM.servers.count
        case .skills: return skillsVM.skills.count
        case .plugins: return pluginsVM.plugins.count
        case .discover: return mcpVM.gitHubResults.count + skillsVM.gitHubResults.count + pluginsVM.gitHubResults.count
        }
    }

    private func loadAll() async {
        async let m: () = mcpVM.loadServers()
        async let s: () = skillsVM.loadSkills()
        async let p: () = pluginsVM.loadPlugins()
        async let mkt: () = mcpMarketplaceVM.loadFeatured()
        _ = await (m, s, p, mkt)
    }

    private func refreshCurrentSegment() async {
        switch segment {
        case .mcp: await mcpVM.refreshServers()
        case .skills: await skillsVM.refreshSkills()
        case .plugins: await pluginsVM.loadPlugins()
        case .discover:
            switch discoverType {
            case .mcp:
                if mcpVM.gitHubSearchText.isEmpty {
                    await mcpMarketplaceVM.loadFeatured()
                } else {
                    await mcpVM.searchGitHub(query: mcpVM.gitHubSearchText)
                }
            case .skills:
                await skillsVM.searchGitHub(query: skillsVM.gitHubSearchText)
            case .plugins:
                await pluginsVM.searchGitHub(query: pluginsVM.gitHubSearchText)
            }
        }
    }
}

// MARK: - Extracted Equatable Row Views

/// Extracted row view for MCP servers and skills with Equatable conformance for render skipping.
struct BrowserRowView: View, Equatable {
    let name: String
    let subtitle: String
    let status: String
    let statusColor: Color
    let entityColor: Color
    let badge: String?

    @Environment(\.theme) private var theme: ThemeSnapshot

    static func == (lhs: BrowserRowView, rhs: BrowserRowView) -> Bool {
        lhs.name == rhs.name &&
        lhs.subtitle == rhs.subtitle &&
        lhs.status == rhs.status &&
        lhs.badge == rhs.badge
    }

    var body: some View {
        HStack(spacing: theme.spacingMD) {
            // Entity dot
            Circle()
                .fill(entityColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Status dot + text
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(status)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(statusColor)
                    }
                }

                Text(subtitle)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)

                if let badge, !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(status)")
    }
}

/// Extracted plugin row view with Equatable conformance for render skipping.
struct PluginRowView: View, Equatable {
    let plugin: Plugin
    let isInstalling: Bool
    var onToggle: (() -> Void)?

    @Environment(\.theme) private var theme: ThemeSnapshot

    static func == (lhs: PluginRowView, rhs: PluginRowView) -> Bool {
        lhs.plugin.id == rhs.plugin.id &&
        lhs.plugin.name == rhs.plugin.name &&
        lhs.plugin.isEnabled == rhs.plugin.isEnabled &&
        lhs.plugin.description == rhs.plugin.description &&
        lhs.isInstalling == rhs.isInstalling
    }

    var body: some View {
        HStack(spacing: theme.spacingMD) {
            // Entity dot
            Circle()
                .fill(theme.entityPlugin)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plugin.name)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Install progress spinner
                    if isInstalling {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                            .tint(theme.accent)
                    } else {
                        // Status dot + text
                        HStack(spacing: 4) {
                            Circle()
                                .fill(plugin.isEnabled ? theme.success : theme.textTertiary)
                                .frame(width: 6, height: 6)
                            Text(plugin.isEnabled ? "Enabled" : "Disabled")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(plugin.isEnabled ? theme.success : theme.textTertiary)
                        }
                    }
                }

                Text(plugin.description ?? "No description")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)

                // Badges row: version, source, stars, marketplace
                HStack(spacing: 6) {
                    if let version = plugin.version {
                        pluginBadge("v\(version)", color: theme.textTertiary)
                    }
                    if let source = plugin.source {
                        pluginBadge(
                            source == .official ? "Official" : "Community",
                            color: source == .official ? theme.accent : theme.entitySkill
                        )
                    }
                    if let stars = plugin.stars, stars > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.warning)
                            Text("\(stars)")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    if let marketplace = plugin.marketplace, !marketplace.isEmpty {
                        pluginBadge(marketplace, color: theme.textTertiary)
                    }
                }
            }

            // Visible toggle button
            if !isInstalling {
                Button {
                    onToggle?()
                } label: {
                    Image(systemName: plugin.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(plugin.isEnabled ? theme.success : theme.textTertiary)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(plugin.isEnabled ? "Disable \(plugin.name)" : "Enable \(plugin.name)")
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plugin.name), \(plugin.isEnabled ? "Enabled" : "Disabled")")
    }

    private func pluginBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
