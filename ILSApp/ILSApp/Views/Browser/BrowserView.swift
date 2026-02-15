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
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var mcpVM = MCPViewModel()
    @StateObject private var skillsVM = SkillsViewModel()
    @StateObject private var pluginsVM = PluginsViewModel()

    @State private var segment: BrowserSegment = .mcp
    @State private var searchText = ""
    @State private var mcpScope: String = "all"

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
                }
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
        } else if items.isEmpty {
            emptyState(
                icon: "sparkles",
                title: searchText.isEmpty ? "No Skills" : "No Results",
                subtitle: searchText.isEmpty ? "No skills found" : "Try a different search"
            )
        } else {
            ForEach(items) { skill in
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

                                // Show progress indicator if installing
                                if pluginsVM.installingPlugins.contains(plugin.name) {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
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

                            if let marketplace = plugin.marketplace, !marketplace.isEmpty {
                                Text(marketplace)
                                    .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
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
                    .accessibilityLabel("\(plugin.name), \(plugin.isEnabled ? "Enabled" : "Disabled")")
                }
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
                        .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
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
        ForEach(0..<5, id: \.self) { _ in
            HStack(spacing: theme.spacingMD) {
                Circle()
                    .fill(theme.bgTertiary)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.bgTertiary)
                        .frame(width: 120, height: 14)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.bgTertiary)
                        .frame(height: 10)
                }
                Spacer()
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
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
