import SwiftUI
import ILSShared

struct SSHServersListView: View {
    @StateObject private var viewModel = SSHViewModel()
    @State private var showingNewServer = false
    @State private var selectedServer: SSHServer?

    var body: some View {
        List {
            if let error = viewModel.error {
                ErrorStateView(error: error) {
                    await viewModel.retryLoadServers()
                }
            } else if viewModel.servers.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No SSH Servers",
                    systemImage: "server.rack",
                    description: "Add an SSH server to connect to remote machines",
                    actionTitle: "Add Server"
                ) {
                    showingNewServer = true
                }
            } else {
                ForEach(viewModel.servers) { server in
                    SSHServerRowView(server: server)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedServer = server
                        }
                }
                .onDelete(perform: deleteServer)
            }
        }
        .navigationTitle("SSH Servers")
        .refreshable {
            await viewModel.loadServers()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNewServer = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewServer) {
            // TODO: NewSSHServerView to be implemented in next subtask
            Text("New SSH Server View")
        }
        .sheet(item: $selectedServer) { server in
            // TODO: SSHServerDetailView to be implemented in later subtask
            Text("SSH Server Detail View for \(server.name)")
        }
        .overlay {
            if viewModel.isLoading && viewModel.servers.isEmpty {
                ProgressView("Loading SSH servers...")
            }
        }
        .task {
            await viewModel.loadServers()
        }
    }

    private func deleteServer(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let server = viewModel.servers[index]
                await viewModel.deleteServer(server)
            }
        }
    }
}

struct SSHServerRowView: View {
    let server: SSHServer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(server.name)
                    .font(ILSTheme.headlineFont)

                Spacer()

                Text(server.authType.rawValue)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(ILSTheme.tertiaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusS)
            }

            Text("\(server.username)@\(server.host):\(server.port)")
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.secondaryText)
                .lineLimit(1)

            if let description = server.description {
                Text(description)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
                    .lineLimit(2)
            }

            HStack {
                if let lastConnected = server.lastConnectedAt {
                    Label("Last connected \(formattedDate(lastConnected))", systemImage: "clock")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                } else {
                    Label("Never connected", systemImage: "clock")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                }

                Spacer()

                Text(formattedDate(server.createdAt))
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        SSHServersListView()
    }
}
