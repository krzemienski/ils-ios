import SwiftUI
import ILSShared

struct SessionsListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SessionsViewModel()
    @State private var showingNewSession = false
    private let cloudKitService = CloudKitService()

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
        .navigationTitle("Sessions")
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
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
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
        }
        .overlay {
            if viewModel.isLoading && viewModel.sessions.isEmpty {
                ProgressView("Loading sessions...")
                    .accessibilityIdentifier("loading-sessions-indicator")
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient, cloudKitService: cloudKitService)
            await viewModel.loadSessions()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.name ?? "Unnamed Session")
                    .font(ILSTheme.headlineFont)
                    .lineLimit(1)

                Spacer()

                Text(session.model)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(ILSTheme.tertiaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusS)
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

                statusBadge
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
                .cornerRadius(ILSTheme.cornerRadiusS)
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
            .cornerRadius(ILSTheme.cornerRadiusS)
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
