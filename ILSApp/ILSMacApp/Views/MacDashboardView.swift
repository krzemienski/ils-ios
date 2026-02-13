import SwiftUI
import ILSShared

// MARK: - Mac Dashboard View

struct MacDashboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme: any AppTheme

    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var sessionsVM = SessionsViewModel()

    var onSessionSelected: ((ChatSession) -> Void)?
    var onNavigate: ((ActiveScreen) -> Void)?

    @State private var showingNewSession: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                welcomeSection
                connectionBanner
                statsGrid
                recentSessionsSection
                quickActionsSection
            }
            .padding(.horizontal, theme.spacingLG)
            .padding(.vertical, theme.spacingLG)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Dashboard")
        .navigationSubtitle(appState.isConnected ? appState.serverURL : "Not Connected")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh dashboard (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .task {
            dashboardVM.configure(client: appState.apiClient)
            sessionsVM.configure(client: appState.apiClient)
            await loadAll()
        }
        .refreshable {
            await refreshAll()
        }
        .sheet(isPresented: $showingNewSession) {
            NewSessionSheet(
                onSessionCreated: { session in
                    onSessionSelected?(session)
                    showingNewSession = false
                },
                onCancel: {
                    showingNewSession = false
                }
            )
        }
    }

    // MARK: - Welcome Section

    @ViewBuilder
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("Welcome to ILS")
                .font(.system(size: theme.fontTitle1, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            if appState.isConnected {
                HStack(spacing: theme.spacingSM) {
                    Circle()
                        .fill(theme.success)
                        .frame(width: 8, height: 8)
                    Text(appState.serverURL)
                        .font(.system(size: theme.fontBody, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - Connection Banner

    @ViewBuilder
    private var connectionBanner: some View {
        if !appState.isConnected {
            HStack(spacing: theme.spacingMD) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(theme.warning)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Not Connected to Server")
                        .font(.system(size: theme.fontBody, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("Configure your ILS backend to get started")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                Button {
                    appState.showOnboarding = true
                } label: {
                    Text("Configure Server")
                        .font(.system(size: theme.fontBody, weight: .semibold))
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingMD)
                        .padding(.vertical, theme.spacingSM)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .buttonStyle(.plain)
            }
            .padding(theme.spacingMD)
            .background(theme.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.warning.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Stats Grid

    @ViewBuilder
    private var statsGrid: some View {
        if let stats = dashboardVM.stats {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Text("Overview")
                    .font(.system(size: theme.fontTitle3, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: theme.spacingMD),
                        GridItem(.flexible(), spacing: theme.spacingMD),
                        GridItem(.flexible(), spacing: theme.spacingMD),
                        GridItem(.flexible(), spacing: theme.spacingMD)
                    ],
                    spacing: theme.spacingMD
                ) {
                    StatCard(
                        title: "Sessions",
                        count: stats.sessions.total,
                        entityType: .sessions,
                        sparklineData: dashboardVM.sessionSparkline
                    )

                    StatCard(
                        title: "Projects",
                        count: stats.projects.total,
                        entityType: .projects,
                        sparklineData: dashboardVM.projectSparkline
                    )

                    StatCard(
                        title: "Skills",
                        count: stats.skills.total,
                        entityType: .skills,
                        sparklineData: dashboardVM.skillSparkline
                    )

                    StatCard(
                        title: "MCP Servers",
                        count: stats.mcpServers.total,
                        entityType: .mcp,
                        sparklineData: dashboardVM.mcpSparkline
                    )
                }
            }
        } else if dashboardVM.isLoading {
            VStack(spacing: theme.spacingSM) {
                ProgressView()
                    .tint(theme.accent)
                Text("Loading statistics...")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingLG)
        }
    }

    // MARK: - Recent Sessions

    @ViewBuilder
    private var recentSessionsSection: some View {
        let recent = Array(sessionsVM.sessions.prefix(8))

        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                Text("Recent Sessions")
                    .font(.system(size: theme.fontTitle3, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                if !recent.isEmpty {
                    Text("\(sessionsVM.sessions.count) total")
                        .font(.system(size: theme.fontCaption, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            if !recent.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: theme.spacingMD),
                        GridItem(.flexible(), spacing: theme.spacingMD)
                    ],
                    spacing: theme.spacingMD
                ) {
                    ForEach(recent) { session in
                        Button {
                            onSessionSelected?(session)
                        } label: {
                            recentSessionCard(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if !appState.isConnected {
                // Handled by connection banner
                EmptyView()
            } else if sessionsVM.isLoading {
                VStack(spacing: theme.spacingSM) {
                    ProgressView()
                        .tint(theme.accent)
                    Text("Loading sessions...")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingLG)
            } else {
                emptySessionsCard
            }
        }
    }

    @ViewBuilder
    private func recentSessionCard(_ session: ChatSession) -> some View {
        HStack(spacing: theme.spacingMD) {
            Circle()
                .fill(session.status == .active ? theme.success : theme.textTertiary.opacity(0.3))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.name ?? "Unnamed Session")
                    .font(.system(size: theme.fontBody, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: theme.spacingSM) {
                    Text(session.model.capitalized)
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.entitySession)

                    Text("·")
                        .foregroundStyle(theme.textTertiary)

                    Text("\(session.messageCount) msgs")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)

                    if let projectName = session.projectName {
                        Text("·")
                            .foregroundStyle(theme.textTertiary)
                        Text(projectName)
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.entityProject)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .accessibilityLabel("\(session.name ?? "Unnamed"), \(session.model), \(session.messageCount) messages")
    }

    private var emptySessionsCard: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)

            Text("No sessions yet")
                .font(.system(size: theme.fontBody, weight: .medium))
                .foregroundStyle(theme.textPrimary)

            Button {
                showingNewSession = true
            } label: {
                Text("Create Your First Session")
                    .font(.system(size: theme.fontBody, weight: .semibold))
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingXL)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - Quick Actions

    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Quick Actions")
                .font(.system(size: theme.fontTitle3, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            HStack(spacing: theme.spacingMD) {
                quickActionButton(
                    icon: "plus.bubble.fill",
                    title: "New Session",
                    subtitle: "Start chatting",
                    color: theme.entitySession,
                    shortcut: "n"
                ) {
                    showingNewSession = true
                }

                quickActionButton(
                    icon: "sparkles",
                    title: "Browse Skills",
                    subtitle: "\(dashboardVM.stats?.skills.total ?? 0) available",
                    color: theme.entitySkill,
                    shortcut: "2"
                ) {
                    onNavigate?(.browser)
                }

                quickActionButton(
                    icon: "server.rack",
                    title: "MCP Servers",
                    subtitle: "\(dashboardVM.stats?.mcpServers.total ?? 0) configured",
                    color: theme.entityMCP,
                    shortcut: "3"
                ) {
                    onNavigate?(.browser)
                }

                quickActionButton(
                    icon: "gauge.with.dots.needle.33percent",
                    title: "System Monitor",
                    subtitle: "View metrics",
                    color: theme.accent,
                    shortcut: "4"
                ) {
                    onNavigate?(.system)
                }
            }
        }
    }

    @ViewBuilder
    private func quickActionButton(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        shortcut: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundStyle(color)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: theme.fontBody, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacingMD)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
        .buttonStyle(.plain)
        .help("\(title) (⌘\(shortcut))")
        .accessibilityLabel("\(title): \(subtitle)")
    }

    // MARK: - Helpers

    private func loadAll() async {
        await dashboardVM.loadAll()
        await sessionsVM.loadSessions(refresh: true)
    }

    private func refreshAll() async {
        await dashboardVM.loadAll()
        await sessionsVM.loadSessions(refresh: true)
    }
}

// MARK: - New Session Sheet

struct NewSessionSheet: View {
    @Environment(\.theme) private var theme: any AppTheme
    @EnvironmentObject var appState: AppState

    let onSessionCreated: (ChatSession) -> Void
    let onCancel: () -> Void

    @State private var sessionName: String = ""
    @State private var selectedModel: String = "sonnet"

    let availableModels = [
        "sonnet": "Claude Sonnet",
        "opus": "Claude Opus",
        "haiku": "Claude Haiku"
    ]

    var body: some View {
        VStack(spacing: theme.spacingLG) {
            Text("New Session")
                .font(.system(size: theme.fontTitle2, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            VStack(alignment: .leading, spacing: theme.spacingMD) {
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Text("Session Name")
                        .font(.system(size: theme.fontCaption, weight: .medium))
                        .foregroundStyle(theme.textSecondary)

                    TextField("Enter session name...", text: $sessionName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Text("Model")
                        .font(.system(size: theme.fontCaption, weight: .medium))
                        .foregroundStyle(theme.textSecondary)

                    Picker("Model", selection: $selectedModel) {
                        ForEach(Array(availableModels.keys.sorted()), id: \.self) { key in
                            Text(availableModels[key] ?? key).tag(key)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            HStack(spacing: theme.spacingMD) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create Session") {
                    let session = ChatSession(
                        name: sessionName.isEmpty ? "New Session" : sessionName,
                        model: selectedModel
                    )
                    onSessionCreated(session)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(theme.spacingXL)
        .frame(width: 420, height: 280)
        .background(theme.bgPrimary)
    }
}

#Preview {
    MacDashboardView()
        .environmentObject(AppState())
        .environment(\.theme, ObsidianTheme())
}
