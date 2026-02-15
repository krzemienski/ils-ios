import SwiftUI
import ILSShared

/// macOS-optimized sessions list view with search, grouping, and keyboard navigation
struct MacSessionsListView: View {
    @StateObject private var viewModel = SessionsViewModel()
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var windowManager: WindowManager
    @Environment(\.theme) private var theme: any AppTheme

    // Callbacks
    let onSessionSelected: (ChatSession) -> Void
    let onRenameSession: (ChatSession, String) -> Void
    let onExportSession: (ChatSession) -> Void

    // State
    @State private var searchText: String = ""
    @State private var expandedProjects: Set<String> = []
    @State private var selectedSessionId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            headerView

            // Search bar
            searchBarView

            // Session list
            listView

            Divider()

            // New Session button
            newSessionButton
        }
        .background(theme.bgPrimary)
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadSessions(refresh: true)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("SESSIONS")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
            Spacer()
            Text("\(viewModel.totalCount)")
                .font(.system(size: theme.fontCaption, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.top, theme.spacingMD)
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - Search Bar

    private var searchBarView: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
            TextField("Search sessions...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textPrimary)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS + 2)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .padding(.horizontal, theme.spacingMD)
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - List

    private var listView: some View {
        List(selection: $selectedSessionId) {
            if viewModel.isLoading && viewModel.sessions.isEmpty {
                loadingView
            } else if filteredSessions.isEmpty {
                emptyView
            } else {
                ForEach(groupedSessions, id: \.key) { project, sessions in
                    projectGroup(name: project, sessions: sessions)
                }
            }
        }
        .listStyle(.sidebar)
        .refreshable {
            await viewModel.loadSessions(refresh: true)
        }
        .onChange(of: selectedSessionId) { _, newId in
            // Handle keyboard selection (Return key)
            if let sessionId = newId,
               let session = viewModel.sessions.first(where: { $0.id == sessionId }) {
                onSessionSelected(session)
            }
        }
    }

    // MARK: - Project Group

    @ViewBuilder
    private func projectGroup(name: String, sessions: [ChatSession]) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedProjects.contains(name) },
                set: { isExpanded in
                    if isExpanded {
                        expandedProjects.insert(name)
                    } else {
                        expandedProjects.remove(name)
                    }
                }
            )
        ) {
            ForEach(sessions) { session in
                sessionRow(session)
                    .tag(session.id)
            }
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "folder.fill")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.entityProject)
                Text(name)
                    .font(.system(size: theme.fontCaption, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text("\(sessions.count)")
                    .font(.system(size: theme.fontCaption, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    // MARK: - Session Row

    @ViewBuilder
    private func sessionRow(_ session: ChatSession) -> some View {
        Button {
            // Single click selects
            selectedSessionId = session.id
        } label: {
            MacSessionRowContent(session: session)
        }
        .buttonStyle(.plain)
        // Double-click to open (macOS convention)
        .onTapGesture(count: 2) {
            onSessionSelected(session)
        }
        .contextMenu {
            Button {
                windowManager.openSessionWindow(session)
            } label: {
                Label("Open in New Window", systemImage: "macwindow.badge.plus")
            }

            Divider()

            Button {
                let currentName = session.name ?? ""
                onRenameSession(session, currentName)
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                onExportSession(session)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                Task {
                    await viewModel.deleteSession(session)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .help("Double-click to open session")
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: theme.spacingSM) {
            ProgressView()
                .tint(theme.accent)
            Text("Loading sessions...")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingLG)
    }

    private var emptyView: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 24))
                .foregroundStyle(theme.textTertiary)
            Text(searchText.isEmpty ? "No sessions yet" : "No matching sessions")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingLG)
    }

    // MARK: - New Session Button

    private var newSessionButton: some View {
        Button {
            let newSession = ChatSession(name: "New Session", model: "sonnet")
            onSessionSelected(newSession)
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "plus.circle.fill")
                Text("New Session")
                    .font(.system(size: theme.fontBody, weight: .semibold))
            }
            .foregroundStyle(theme.textOnAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM + 2)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingMD)
        .keyboardShortcut("n", modifiers: [.command])
        .help("Create a new session (⌘N)")
    }

    // MARK: - Helpers

    private var filteredSessions: [ChatSession] {
        guard !searchText.isEmpty else { return viewModel.sessions }
        let query = searchText.lowercased()
        return viewModel.sessions.filter { session in
            (session.name?.lowercased().contains(query) ?? false) ||
            (session.projectName?.lowercased().contains(query) ?? false) ||
            (session.firstPrompt?.lowercased().contains(query) ?? false)
        }
    }

    private var groupedSessions: [(key: String, value: [ChatSession])] {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            session.projectName ?? "Ungrouped"
        }
        return grouped.sorted { group1, group2 in
            let latest1 = group1.value.map(\.lastActiveAt).max() ?? .distantPast
            let latest2 = group2.value.map(\.lastActiveAt).max() ?? .distantPast
            return latest1 > latest2
        }
    }
}

// MARK: - Session Row Content

struct MacSessionRowContent: View {
    let session: ChatSession
    @Environment(\.theme) private var theme: any AppTheme

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name ?? "Unnamed Session")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let firstPrompt = session.firstPrompt {
                    Text(firstPrompt)
                        .font(.system(size: theme.fontCaption - 1))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(session.messageCount > 0 ? "\(session.messageCount)" : "")
                .font(.system(size: theme.fontCaption - 1, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, theme.spacingXS)
    }
}

// MARK: - Preview

#Preview {
    MacSessionsListView(
        onSessionSelected: { _ in },
        onRenameSession: { _, _ in },
        onExportSession: { _ in }
    )
    .environmentObject(AppState())
    .environmentObject(WindowManager.shared)
    .environment(\.theme, ObsidianTheme())
    .frame(width: 320, height: 600)
}
