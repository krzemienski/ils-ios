import SwiftUI
import ILSShared

struct SessionsListView: View {
    @StateObject private var viewModel = SessionsViewModel()
    @State private var showingNewSession = false

    var body: some View {
        List {
            if viewModel.sessions.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start a new chat session to begin")
                )
            } else {
                ForEach(viewModel.sessions) { session in
                    NavigationLink(destination: ChatView(session: session)) {
                        SessionRowView(session: session)
                    }
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
            }
        }
        .sheet(isPresented: $showingNewSession) {
            NewSessionView { session in
                viewModel.sessions.insert(session, at: 0)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .task {
            await viewModel.loadSessions()
        }
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
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (color, text) = statusInfo

        Text(text)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(ILSTheme.cornerRadiusS)
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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        SessionsListView()
    }
}
