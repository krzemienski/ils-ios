import SwiftUI
import ILSShared

struct SessionsListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SessionsViewModel()
    @State private var showingNewSession = false
    @State private var sessionToDelete: ChatSession?
    @State private var searchText = ""
    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""
    @State private var navigateToSession: ChatSession?
    @State private var sessionToRename: ChatSession?
    @State private var renameText = ""

    private var filteredSessions: [ChatSession] {
        guard !searchText.isEmpty else { return viewModel.sessions }
        return viewModel.sessions.filter { session in
            let name = session.name ?? ""
            let project = session.projectName ?? ""
            let prompt = session.firstPrompt ?? ""
            return name.localizedCaseInsensitiveContains(searchText)
                || project.localizedCaseInsensitiveContains(searchText)
                || prompt.localizedCaseInsensitiveContains(searchText)
                || session.model.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if let error = viewModel.error {
                ErrorStateView(error: error) {
                    await viewModel.retryLoadSessions()
                }
            } else if viewModel.sessions.isEmpty && !viewModel.isLoading {
                EmptyEntityState(
                    entityType: .sessions,
                    title: "No Sessions Yet",
                    description: "Start a conversation with Claude",
                    actionTitle: "New Chat"
                ) {
                    showingNewSession = true
                }
                .accessibilityIdentifier("empty-sessions-state")
            } else if !searchText.isEmpty && filteredSessions.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(filteredSessions) { session in
                    NavigationLink(destination: ChatView(session: session)) {
                        SessionRowView(session: session)
                    }
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("session-\(session.id)")
                    .swipeActions(edge: .leading) {
                        Button {
                            renameText = session.name ?? ""
                            sessionToRename = session
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(EntityType.sessions.color)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            sessionToDelete = session
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            renameText = session.name ?? ""
                            sessionToRename = session
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button {
                            UIPasteboard.general.string = session.id.uuidString
                        } label: {
                            Label("Copy Session ID", systemImage: "doc.on.doc")
                        }
                        Divider()
                        Button(role: .destructive) {
                            sessionToDelete = session
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .darkListStyle()
        .navigationTitle("Sessions")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search sessions...")
        .refreshable {
            await viewModel.loadSessions(refresh: true)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNewSession = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("add-session-button")
                .accessibilityLabel("Add new session")
            }
        }
        .navigationDestination(item: $navigateToSession) { session in
            ChatView(session: session)
        }
        .sheet(isPresented: $showingNewSession) {
            NewSessionView { session in
                viewModel.sessions.insert(session, at: 0)
                showingNewSession = false
                // Auto-navigate to the new session's chat
                navigateToSession = session
            }
            .presentationBackground(Color.black)
        }
        .alert("Delete Session?", isPresented: Binding(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    Task {
                        await viewModel.deleteSession(session)
                        if viewModel.error != nil {
                            errorAlertMessage = viewModel.error?.localizedDescription ?? "Failed to delete session"
                            showErrorAlert = true
                            viewModel.error = nil
                        } else {
                            HapticManager.notification(.success)
                        }
                    }
                    sessionToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
        } message: {
            Text("This will permanently delete this session and all its messages.")
        }
        .alert("Rename Session", isPresented: Binding(
            get: { sessionToRename != nil },
            set: { if !$0 { sessionToRename = nil } }
        )) {
            TextField("Session Name", text: $renameText)
            Button("Rename") {
                if let session = sessionToRename {
                    Task {
                        do {
                            let _: APIResponse<ChatSession> = try await appState.apiClient.renameSession(id: session.id, name: renameText)
                            await viewModel.loadSessions(refresh: true)
                            HapticManager.notification(.success)
                        } catch {
                            errorAlertMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                    sessionToRename = nil
                }
            }
            Button("Cancel", role: .cancel) { sessionToRename = nil }
        } message: {
            Text("Enter a new name for this session.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorAlertMessage)
        }
        .overlay {
            if viewModel.isLoading && viewModel.sessions.isEmpty {
                List {
                    SkeletonListView()
                }
                .darkListStyle()
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadSessions()
        }
        .onChange(of: appState.isConnected) { _, isConnected in
            if isConnected && viewModel.error != nil {
                Task { await viewModel.retryLoadSessions() }
            }
        }
        .accessibilityIdentifier("sessions-list")
    }
}

struct SessionRowView: View {
    let session: ChatSession

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// Whether this is an external Claude Code session
    private var isExternal: Bool {
        session.source == .external
    }

    /// Display name: use session name, fall back to firstPrompt truncated, then "Claude Code Session"
    private var displayName: String {
        if let name = session.name, !name.isEmpty {
            return name
        }
        if let prompt = session.firstPrompt, !prompt.isEmpty, prompt != "No prompt" {
            return String(prompt.prefix(60))
        }
        return isExternal ? "Claude Code Session" : "Unnamed Session"
    }

    var body: some View {
        HStack(spacing: ILSTheme.spaceM) {
            // Blue status dot - filled=active, hollow=inactive
            Circle()
                .fill(session.status == .active
                      ? EntityType.sessions.color
                      : EntityType.sessions.color.opacity(0.3))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if isExternal {
                        Image(systemName: "terminal")
                            .font(.caption)
                            .foregroundColor(EntityType.sessions.color)
                    }

                    Text(displayName)
                        .font(ILSTheme.headlineFont)
                        .foregroundColor(ILSTheme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(session.model)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(ILSTheme.bg3)
                        .cornerRadius(ILSTheme.cornerRadiusXS)
                }

                HStack {
                    if let projectName = session.projectName {
                        Label(projectName, systemImage: "folder")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.textSecondary)
                    }

                    Spacer()

                    Text(formattedDate(session.lastActiveAt))
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.textTertiary)
                }

                HStack {
                    Label("\(session.messageCount) messages", systemImage: "bubble.left")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.textTertiary)

                    if let cost = session.totalCostUSD {
                        Text("$\(cost, specifier: "%.4f")")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.textTertiary)
                    }

                    Spacer()

                    if isExternal {
                        Text("Claude Code")
                            .font(.caption2)
                            .foregroundColor(EntityType.sessions.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(EntityType.sessions.color.opacity(0.15))
                            .cornerRadius(ILSTheme.cornerRadiusXS)
                    } else {
                        statusBadge
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName), \(session.model), \(session.messageCount) messages, \(session.status.rawValue)")
        .accessibilityHint("Double tap to open chat session")
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (color, text) = statusInfo

        if session.status == .active {
            // Active badge with pulse animation
            PulsingBadgeView(text: text, color: color)
        } else {
            // Static badge for other states
            Text(text)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color)
                .cornerRadius(ILSTheme.cornerRadiusXS)
        }
    }

    private var statusInfo: (Color, String) {
        switch session.status {
        case .active:
            return (ILSTheme.success, "Active")
        case .completed:
            return (ILSTheme.info, "Completed")
        case .error:
            return (ILSTheme.error, "Error")
        case .cancelled:
            return (ILSTheme.secondaryText, "Cancelled")
        }
    }

    private func formattedDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Pulsing Badge Component

struct PulsingBadgeView: View {
    let text: String
    let color: Color
    @State private var isPulsing = false

    private var shouldAnimate: Bool {
        !UIAccessibility.isReduceMotionEnabled
    }

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(ILSTheme.cornerRadiusXS)
            .opacity(shouldAnimate && isPulsing ? 0.7 : 1.0)
            .animation(shouldAnimate ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : nil, value: isPulsing)
            .onAppear {
                if shouldAnimate {
                    isPulsing = true
                }
            }
    }
}

#Preview {
    NavigationStack {
        SessionsListView()
    }
}
