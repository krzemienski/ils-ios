import SwiftUI
import ILSShared

// MARK: - Browser Segment

enum BrowserSegment: String, CaseIterable {
    case mcp = "MCP"
    case skills = "Skills"
    case plugins = "Plugins"
}

// MARK: - Browser View

struct BrowserView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mcpVM = MCPViewModel()
    @State private var skillsVM = SkillsViewModel()
    @State private var pluginsVM = PluginsViewModel()

    @State private var segment: BrowserSegment = .mcp
    @State private var searchText = ""
    @State private var mcpScope: String = "all"
    @State private var skillsScope: String = "all"
    @State private var showGitHubSearch = false
    @State private var showPluginsGitHubSearch = false
    @State private var showMarketplaceSearch = false
    @State private var showingAddMCPServer = false

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
                    switch segment {
                    case .mcp:
                        mcpContent
                    case .skills:
                        skillsContent
                    case .plugins:
                        pluginsContent
                    }
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.bottom, theme.spacingLG)
            }
            .refreshable {
                await refreshCurrentSegment()
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Browse")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            if segment == .mcp {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddMCPServer = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(theme.accent)
                    }
                    .accessibilityLabel("Add MCP Server")
                }
            }
        }
        .sheet(isPresented: $showingAddMCPServer) {
            AddMCPServerView(mcpVM: mcpVM)
        }
        .task {
            mcpVM.configure(client: appState.apiClient)
            skillsVM.configure(client: appState.apiClient)
            pluginsVM.configure(client: appState.apiClient)
            await loadAll()
        }
        .onChange(of: appState.isConnected) { _, connected in
            if connected {
                Task { await loadAll() }
            }
        }
        .onChange(of: appState.browserSegmentIntent) { _, intent in
            guard let intent else { return }
            segment = intent
            appState.browserSegmentIntent = nil
        }
        .onAppear {
            if let intent = appState.browserSegmentIntent {
                segment = intent
                appState.browserSegmentIntent = nil
            }
        }
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(BrowserSegment.allCases, id: \.self) { seg in
                Button {
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
                .accessibilityAddTraits(segment == seg ? .isSelected : [])
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
        .onChange(of: searchText) { _, text in
            mcpVM.searchText = text
            skillsVM.searchText = text
            pluginsVM.searchText = text
        }
    }

    // MARK: - MCP Content

    @ViewBuilder
    private var mcpContent: some View {
        // Scope segmented control
        VStack(spacing: theme.spacingSM) {
            HStack(spacing: 0) {
                ForEach(["all", "user", "project", "local"], id: \.self) { scope in
                    Button {
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

            // Description header
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "info.circle")
                    .foregroundStyle(theme.textTertiary)
                    .font(.system(size: 12, design: theme.fontDesign))
                Text("MCP servers provide Claude with access to external data sources, APIs, and tools via the Model Context Protocol.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingSM)

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
                            subtitle: server.command,
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
        VStack(spacing: theme.spacingSM) {
            // Scope filter — all 4 backend scopes
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacingSM) {
                    ForEach(["all", "local", "plugin", "github", "builtin"], id: \.self) { scope in
                        Button {
                            skillsScope = scope
                        } label: {
                            Text(scope == "all" ? "All" : scope.capitalized)
                                .font(.system(size: theme.fontCaption, weight: skillsScope == scope ? .semibold : .regular, design: theme.fontDesign))
                                .foregroundStyle(skillsScope == scope ? theme.textPrimary : theme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    skillsScope == scope
                                        ? theme.entitySkill.opacity(0.2)
                                        : theme.bgSecondary
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(scope.capitalized) scope filter")
                    }
                }
            }
            .onChange(of: skillsScope) { _, newScope in
                skillsVM.selectedScope = newScope
                Task {
                    await skillsVM.loadSkills(scope: newScope == "all" ? nil : newScope)
                }
            }

            // Active/Inactive summary bar
            if !skillsVM.skills.isEmpty {
                HStack(spacing: theme.spacingMD) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(theme.success)
                            .frame(width: 6, height: 6)
                        Text("\(skillsVM.activeCount) active")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(theme.textTertiary)
                            .frame(width: 6, height: 6)
                        Text("\(skillsVM.inactiveCount) inactive")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Spacer()
                    Text("\(skillsVM.skills.count) total")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, 4)
            }

            // Description header
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "info.circle")
                    .foregroundStyle(theme.textTertiary)
                    .font(.system(size: 12, design: theme.fontDesign))
                Text("Skills are prompt templates and workflows that guide Claude's behavior for specific tasks like code review, debugging, or documentation.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingSM)

            // GitHub search toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showGitHubSearch.toggle()
                }
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "globe")
                        .foregroundStyle(theme.entitySkill)
                    Text("Search GitHub")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Image(systemName: showGitHubSearch ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
            .buttonStyle(.plain)

            if showGitHubSearch {
                gitHubSearchSection
            }

            // Skills list
            let items = skillsVM.filteredSkills
            if skillsVM.isLoading && items.isEmpty {
                loadingRows
            } else if items.isEmpty {
                emptyState(
                    icon: "sparkles",
                    title: searchText.isEmpty ? "No Skills" : "No Results",
                    subtitle: searchText.isEmpty ? "No skills found" : "Try a different search"
                )
            } else {
                ForEach(items) { skill in
                    NavigationLink {
                        SkillDetailView(skill: skill, parentViewModel: skillsVM)
                    } label: {
                        skillRow(skill: skill)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Skill Row

    private func skillRow(skill: Skill) -> some View {
        HStack(spacing: theme.spacingMD) {
            // Entity dot with source-color coding
            Circle()
                .fill(skillSourceColor(skill.source))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(skill.name)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(skill.isActive ? theme.textPrimary : theme.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    // Toggle active/inactive inline
                    if skillsVM.togglingSkills.contains(skill.id) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(skill.isActive ? theme.success : theme.textTertiary)
                                .frame(width: 6, height: 6)
                            Text(skill.isActive ? "Active" : "Inactive")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(skill.isActive ? theme.success : theme.textTertiary)
                        }
                    }
                }

                Text(skill.description ?? "No description")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)

                // Source badge + first tag
                HStack(spacing: theme.spacingSM) {
                    Text(skill.source.rawValue.capitalized)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(skillSourceColor(skill.source))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(skillSourceColor(skill.source).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    if let firstTag = skill.tags.first, !firstTag.isEmpty {
                        Text(firstTag)
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .opacity(skill.isActive ? 1.0 : 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(skill.name), \(skill.source.rawValue), \(skill.isActive ? "Active" : "Inactive")")
    }

    private func skillSourceColor(_ source: SkillSource) -> Color {
        switch source {
        case .local: return theme.info
        case .plugin: return theme.entityPlugin
        case .builtin: return theme.accent
        case .github: return theme.warning
        }
    }

    // MARK: - Plugins Content

    @ViewBuilder
    private var pluginsContent: some View {
        VStack(spacing: theme.spacingSM) {
            // Summary stats bar
            HStack(spacing: theme.spacingMD) {
                pluginStatBadge(label: "Installed", count: pluginsVM.plugins.count, color: theme.entityPlugin)
                pluginStatBadge(label: "Enabled", count: pluginsVM.enabledCount, color: theme.success)
                pluginStatBadge(label: "Disabled", count: pluginsVM.disabledCount, color: theme.textTertiary)
            }

            // Category filter chips
            if pluginsVM.pluginCategories.count > 1 {
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
                }
            }

            // GitHub search toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPluginsGitHubSearch.toggle()
                }
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "globe")
                        .foregroundStyle(theme.entityPlugin)
                    Text("Search GitHub")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Image(systemName: showPluginsGitHubSearch ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
            .buttonStyle(.plain)

            if showPluginsGitHubSearch {
                pluginsGitHubSearchSection
            }

            // Marketplace search toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showMarketplaceSearch.toggle()
                }
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "globe")
                        .foregroundStyle(theme.entityPlugin)
                    Text("Search Marketplace")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Image(systemName: showMarketplaceSearch ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
            .buttonStyle(.plain)

            if showMarketplaceSearch {
                marketplaceSearchSection
            }

            // Description header
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "info.circle")
                    .foregroundStyle(theme.textTertiary)
                    .font(.system(size: 12, design: theme.fontDesign))
                Text("Plugins are code extensions that add new tools, agents, and capabilities to Claude Code. Install from GitHub or the marketplace.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingSM)

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
                            onToggleEnabled: { p in await pluginsVM.togglePlugin(p) },
                            onUninstall: { p in await pluginsVM.uninstallPlugin(p) }
                        )
                    } label: {
                        pluginRow(plugin)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Plugin Row

    private func pluginRow(_ plugin: Plugin) -> some View {
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

                    // Show progress indicator if toggling or installing
                    if pluginsVM.togglingPlugins.contains(plugin.name) || pluginsVM.installingPlugins.contains(plugin.name) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        // Enable/disable toggle button
                        Button {
                            Task { await pluginsVM.togglePlugin(plugin) }
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(plugin.isEnabled ? theme.success : theme.textTertiary)
                                    .frame(width: 6, height: 6)
                                Text(plugin.isEnabled ? "Enabled" : "Disabled")
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(plugin.isEnabled ? theme.success : theme.textTertiary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                (plugin.isEnabled ? theme.success : theme.textTertiary).opacity(0.1)
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(plugin.description ?? "No description")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)

                HStack(spacing: theme.spacingSM) {
                    if let marketplace = plugin.marketplace, !marketplace.isEmpty {
                        Text(marketplace)
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if let version = plugin.version {
                        Text("v\(version)")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }

                    if let commands = plugin.commands, !commands.isEmpty {
                        Text("\(commands.count) cmd\(commands.count == 1 ? "" : "s")")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.entityPlugin.opacity(0.8))
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plugin.name), \(plugin.isEnabled ? "Enabled" : "Disabled")")
        .contextMenu {
            Button {
                Task { await pluginsVM.togglePlugin(plugin) }
            } label: {
                Label(
                    plugin.isEnabled ? "Disable Plugin" : "Enable Plugin",
                    systemImage: plugin.isEnabled ? "xmark.circle" : "checkmark.circle"
                )
            }

            Button(role: .destructive) {
                Task { await pluginsVM.uninstallPlugin(plugin) }
            } label: {
                Label("Uninstall", systemImage: "trash")
            }
        }
    }

    // MARK: - Plugin Stat Badge

    private func pluginStatBadge(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingSM)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    // MARK: - GitHub Search Section

    @ViewBuilder
    private var gitHubSearchSection: some View {
        VStack(spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textTertiary)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                TextField("Search GitHub for skills...", text: Binding(
                    get: { skillsVM.gitHubSearchText },
                    set: { skillsVM.updateGitHubSearchText($0) }
                ))
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                if !skillsVM.gitHubSearchText.isEmpty {
                    Button {
                        skillsVM.updateGitHubSearchText("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textTertiary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            if skillsVM.isSearchingGitHub {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingMD)
            }

            ForEach(skillsVM.gitHubResults) { result in
                HStack(spacing: theme.spacingMD) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.name)
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                        if let desc = result.description {
                            Text(desc)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(2)
                        }
                        HStack(spacing: theme.spacingSM) {
                            if result.stars > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: theme.fontCaption))
                                        .foregroundStyle(.yellow)
                                    Text("\(result.stars)")
                                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                        .foregroundStyle(theme.textTertiary)
                                }
                            }
                            Text(result.repository)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button {
                        Task { _ = await skillsVM.installFromGitHub(result: result) }
                    } label: {
                        Text("Install")
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.entitySkill)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
        }
    }

    // MARK: - Plugins GitHub Search Section

    @ViewBuilder
    private var pluginsGitHubSearchSection: some View {
        VStack(spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textTertiary)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                TextField("Search GitHub for plugins...", text: Binding(
                    get: { pluginsVM.gitHubSearchText },
                    set: { pluginsVM.updateGitHubSearchText($0) }
                ))
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                if !pluginsVM.gitHubSearchText.isEmpty {
                    Button {
                        pluginsVM.updateGitHubSearchText("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textTertiary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            if pluginsVM.isSearchingGitHub {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingMD)
            }

            ForEach(pluginsVM.gitHubResults) { result in
                let isInstalled = pluginsVM.plugins.contains { $0.name == result.name }
                HStack(spacing: theme.spacingMD) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(result.name)
                                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if isInstalled {
                                Text("Installed")
                                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                                    .foregroundStyle(theme.success)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.success.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        if let desc = result.description {
                            Text(desc)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(2)
                        }
                        HStack(spacing: theme.spacingSM) {
                            if result.stars > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: theme.fontCaption))
                                        .foregroundStyle(.yellow)
                                    Text("\(result.stars)")
                                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                        .foregroundStyle(theme.textTertiary)
                                }
                            }
                            Text(result.repository)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    if !isInstalled {
                        Button {
                            Task { _ = await pluginsVM.installFromGitHub(result: result) }
                        } label: {
                            if pluginsVM.installingPlugins.contains(result.name) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Text("Install")
                                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(theme.entityPlugin)
                                    .clipShape(Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
        }
    }

    // MARK: - Marketplace Search Section

    @ViewBuilder
    private var marketplaceSearchSection: some View {
        VStack(spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textTertiary)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                TextField("Search marketplace...", text: Binding(
                    get: { pluginsVM.marketplaceSearchText },
                    set: { newValue in
                        pluginsVM.marketplaceSearchText = newValue
                        Task { await pluginsVM.searchMarketplace(query: newValue) }
                    }
                ))
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                if !pluginsVM.marketplaceSearchText.isEmpty {
                    Button {
                        pluginsVM.marketplaceSearchText = ""
                        pluginsVM.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textTertiary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            if pluginsVM.isSearchingMarketplace {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingMD)
            }

            ForEach(pluginsVM.searchResults, id: \.name) { result in
                let isInstalled = pluginsVM.plugins.contains { $0.name == result.name }
                HStack(spacing: theme.spacingMD) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(result.name)
                                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if isInstalled {
                                Text("Installed")
                                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                                    .foregroundStyle(theme.success)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.success.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        if let desc = result.description {
                            Text(desc)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(2)
                        }
                    }

                    if !isInstalled {
                        Button {
                            Task {
                                await pluginsVM.installPlugin(name: result.name, marketplace: "github")
                            }
                        } label: {
                            if pluginsVM.installingPlugins.contains(result.name) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Text("Install")
                                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(theme.entityPlugin)
                                    .clipShape(Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
        }
    }

    // MARK: - Shared Row

    private func browserRow(
        name: String,
        subtitle: String,
        status: String,
        statusColor: Color,
        entityColor: Color,
        badge: String?
    ) -> some View {
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
                .font(.system(size: 12, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(status)")
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
        }
    }

    private func countFor(_ seg: BrowserSegment) -> Int {
        switch seg {
        case .mcp: return mcpVM.servers.count
        case .skills: return skillsVM.skills.count
        case .plugins: return pluginsVM.plugins.count
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
        }
    }
}
