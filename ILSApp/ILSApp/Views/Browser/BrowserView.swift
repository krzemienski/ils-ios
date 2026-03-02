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
    case skills = "Skills"
    case plugins = "Plugins"
}

// MARK: - Browser View

struct BrowserView: View {
    /// Optional initial segment to show when the view first appears.
    var initialSegment: BrowserSegment = .mcp

    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mcpVM = MCPViewModel()
    @State private var skillsVM = SkillsViewModel()
    @State private var pluginsVM = PluginsViewModel()

    @State private var segment: BrowserSegment = .mcp
    @State private var searchText = ""
    @State private var mcpScope: String = "all"
    @State private var showAddMCP = false
    @FocusState private var isSearchFocused: Bool
    /// Sub-segment within the Discover tab: search skills or plugins
    @State private var discoverType: DiscoverType = .skills
    /// Favorites manager for skill star/unstar actions.
    @State private var favoritesManager = SkillFavoritesManager.shared

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
                #if os(iOS)
                HapticManager.impact(.light)
                #endif
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
            await loadAll()
            Task { await favoritesManager.syncFromCloud() }
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
            Task { await loadAll() }
        }
        .toolbar {
            if segment == .mcp {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.selection()
                        showAddMCP = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add MCP Server")
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button {
                        HapticManager.selection()
                        showAddMCP = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add MCP Server")
                }
                #endif
            }
        }
        .sheet(isPresented: $showAddMCP) {
            NavigationStack {
                MCPAddEditView(viewModel: mcpVM) { _ in
                    Task { await mcpVM.loadServers() }
                }
            }
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
                    mcpServerRow(server)
                }
            }
        }
    }

    // MARK: - MCP Server Row

    private func mcpServerRow(_ server: MCPServer) -> some View {
        let statusColor: Color = server.status == .healthy ? theme.success : (server.status == .unhealthy ? theme.error : theme.warning)
        let statusText: String = server.status == .healthy ? "Healthy" : (server.status == .unhealthy ? "Unhealthy" : "Unknown")

        return HStack(spacing: 0) {
            NavigationLink {
                MCPServerDetailView(server: server, viewModel: mcpVM)
            } label: {
                HStack(spacing: theme.spacingMD) {
                    Circle()
                        .fill(server.isEnabled ? theme.entityMCP : theme.entityMCP.opacity(0.4))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(server.name)
                                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(server.isEnabled ? theme.textPrimary : theme.textSecondary)
                                .lineLimit(1)

                            Spacer()

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 6, height: 6)
                                Text(statusText)
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(statusColor)
                            }
                        }

                        Text("\(server.command) \(server.args.joined(separator: " "))")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)

                        Text(server.scope.rawValue.capitalized)
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
            }
            .buttonStyle(.plain)

            // Quick enable/disable toggle
            Button {
                HapticManager.impact(.light)
                Task { await mcpVM.toggleEnabled(server) }
            } label: {
                Image(systemName: server.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(server.isEnabled ? theme.success : theme.textTertiary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, theme.spacingMD)
            .accessibilityLabel(server.isEnabled ? "Disable \(server.name)" : "Enable \(server.name)")
        }
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(server.name), \(server.isEnabled ? "Enabled" : "Disabled"), \(statusText)")
    }

    // MARK: - Skills Content

    @ViewBuilder
    private var skillsContent: some View {
        let items = skillsVM.filteredSkills
        let favoriteItems = searchText.isEmpty ? items.filter { favoritesManager.isFavorite(skillName: $0.name) } : []
        let regularItems = searchText.isEmpty ? items.filter { !favoritesManager.isFavorite(skillName: $0.name) } : items
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
            if !favoriteItems.isEmpty {
                skillsSectionHeader("FAVORITES")
                ForEach(favoriteItems) { skill in
                    skillRowEntry(skill)
                }
                if !regularItems.isEmpty {
                    skillsSectionHeader("ALL SKILLS")
                }
            }
            ForEach(regularItems) { skill in
                skillRowEntry(skill)
            }
        }
    }

    @ViewBuilder
    private func skillRowEntry(_ skill: Skill) -> some View {
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

            // Favorite button
            Button {
                Task { await favoritesManager.toggleFavorite(skill: skill) }
            } label: {
                Image(systemName: favoritesManager.isFavorite(skillName: skill.name) ? "star.fill" : "star")
                    .foregroundStyle(favoritesManager.isFavorite(skillName: skill.name) ? theme.warning : theme.textTertiary)
                    .font(.system(size: 18))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favoritesManager.isFavorite(skillName: skill.name) ? "Unfavorite \(skill.name)" : "Favorite \(skill.name)")

            // Active toggle button
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
                Task { await favoritesManager.toggleFavorite(skill: skill) }
            } label: {
                Label(
                    favoritesManager.isFavorite(skillName: skill.name) ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: favoritesManager.isFavorite(skillName: skill.name) ? "star.slash" : "star"
                )
            }
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

    private func skillsSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .tracking(1)
            Spacer()
        }
        .padding(.top, theme.spacingSM)
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
                                HapticManager.selection()
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
            if discoverType == .skills {
                discoverSkillResults
            } else {
                discoverPluginResults
            }
        }
    }

    @ViewBuilder
    private var discoverSearchField: some View {
        let searchBinding = discoverType == .skills ? $skillsVM.gitHubSearchText : $pluginsVM.gitHubSearchText
        let isSearching = discoverType == .skills ? skillsVM.isSearchingGitHub : pluginsVM.isSearchingGitHub

        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))

            TextField(
                discoverType == .skills ? "Search GitHub for skills..." : "Search GitHub for plugins...",
                text: searchBinding
            )
            .font(.system(size: theme.fontBody, design: theme.fontDesign))
            .foregroundStyle(theme.textPrimary)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
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

            if !(discoverType == .skills ? skillsVM.gitHubSearchText : pluginsVM.gitHubSearchText).isEmpty {
                Button {
                    if discoverType == .skills {
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
        let gitHubError = discoverType == .skills ? skillsVM.gitHubError : pluginsVM.gitHubError
        let countdown = discoverType == .skills ? skillsVM.rateLimitCountdown : pluginsVM.rateLimitCountdown

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
        case .discover: return skillsVM.gitHubResults.count + pluginsVM.gitHubResults.count
        }
    }

    private func loadAll() async {
        async let m: () = mcpVM.loadServers()
        async let s: () = skillsVM.loadSkills()
        async let p: () = pluginsVM.loadPlugins()
        _ = await (m, s, p)
    }

    private func refreshCurrentSegment() async {
        switch segment {
        case .mcp: await mcpVM.refreshServers()
        case .skills: await skillsVM.refreshSkills()
        case .plugins: await pluginsVM.loadPlugins()
        case .discover:
            if discoverType == .skills {
                await skillsVM.searchGitHub(query: skillsVM.gitHubSearchText)
            } else {
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
