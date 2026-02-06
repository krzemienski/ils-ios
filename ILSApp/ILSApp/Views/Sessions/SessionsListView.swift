import SwiftUI
import ILSShared

struct SessionsListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SessionsViewModel()
    @State private var showingNewSession = false

    var body: some View {
        List {
            if let error = viewModel.error {
                ErrorStateView(error: error) {
                    await viewModel.retryLoadSessions()
                }
            } else if viewModel.sessions.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No Sessions",
                    systemImage: "bubble.left.and.bubble.right",
                    description: "Start a new chat session to begin",
                    actionTitle: "New Chat"
                ) {
                    showingNewSession = true
                }
                .accessibilityIdentifier("empty-sessions-state")
            } else {
                ForEach(viewModel.sessions) { session in
                    NavigationLink(destination: ChatView(session: session)) {
                        SessionRowView(session: session)
                    }
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("session-\(session.id)")
                }
                .onDelete(perform: deleteSession)
            }
        }
        .darkListStyle()
        .navigationTitle("Sessions")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .refreshable {
            await viewModel.loadSessions()
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
        .safeAreaInset(edge: .bottom) {
            // Floating action button for accessibility testing
            // This provides a tappable target that idb can hit
            HStack {
                Spacer()
                Button(action: { showingNewSession = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(ILSTheme.accent)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                }
                .accessibilityIdentifier("fab-add-session")
                .accessibilityLabel("Add new session")
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingNewSession) {
            NewSessionView { session in
                viewModel.sessions.insert(session, at: 0)
            }
            .presentationBackground(Color.black)
        }
        .overlay {
            if viewModel.isLoading && viewModel.sessions.isEmpty {
                ProgressView("Loading sessions...")
                    .accessibilityIdentifier("loading-sessions-indicator")
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

    private func deleteSession(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let session = viewModel.sessions[index]
                await viewModel.deleteSession(session)
            }
        }
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if isExternal {
                    Image(systemName: "terminal")
                        .font(.caption)
                        .foregroundColor(ILSTheme.accent)
                }

                Text(displayName)
                    .font(ILSTheme.headlineFont)
                    .lineLimit(1)

                Spacer()

                Text(session.model)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(ILSTheme.tertiaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusXS)
            }

            HStack {
                if let projectName = session.projectName {
                    Label(projectName, systemImage: "folder")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }

                Spacer()

                Text(formattedDate(session.lastActiveAt))
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
            }

            HStack {
                Label("\(session.messageCount) messages", systemImage: "bubble.left")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)

                if let cost = session.totalCostUSD {
                    Text("$\(cost, specifier: "%.4f")")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                }

                Spacer()

                if isExternal {
                    Text("Claude Code")
                        .font(.caption2)
                        .foregroundColor(ILSTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ILSTheme.accent.opacity(0.15))
                        .cornerRadius(ILSTheme.cornerRadiusXS)
                } else {
                    statusBadge
                }
            }
        }
        .padding(.vertical, 4)
        .shadow(color: ILSTheme.shadowLight, radius: 2, x: 0, y: 1)
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
