import SwiftUI
import ILSShared

struct MCPServerListView: View {
    @StateObject private var viewModel = MCPViewModel()
    @State private var showingNewServer = false

    var body: some View {
        List {
            if viewModel.servers.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No MCP Servers",
                    systemImage: "server.rack",
                    description: Text("Add MCP servers to extend Claude's capabilities")
                )
            } else {
                ForEach(viewModel.servers) { server in
                    MCPServerRowView(server: server)
                }
                .onDelete(perform: deleteServer)
            }
        }
        .navigationTitle("MCP Servers")
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
            NewMCPServerView { server in
                viewModel.servers.append(server)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
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

struct MCPServerRowView: View {
    let server: MCPServerItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(server.name)
                    .font(ILSTheme.headlineFont)

                Spacer()

                statusBadge
            }

            Text("\(server.command) \(server.args.joined(separator: " "))")
                .font(ILSTheme.codeFont)
                .foregroundColor(ILSTheme.secondaryText)
                .lineLimit(1)

            HStack {
                Text(server.scope.capitalized)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ILSTheme.tertiaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusS)

                if let path = server.configPath {
                    Text(path)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (color, text) = statusInfo

        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption2)
                .foregroundColor(color)
        }
    }

    private var statusInfo: (Color, String) {
        switch server.status {
        case "healthy":
            return (ILSTheme.success, "Healthy")
        case "unhealthy":
            return (ILSTheme.error, "Unhealthy")
        default:
            return (ILSTheme.warning, "Unknown")
        }
    }
}

struct NewMCPServerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var command = ""
    @State private var args = ""
    @State private var scope = "user"
    @State private var isCreating = false

    let onCreated: (MCPServerItem) -> Void

    private let scopes = ["user", "project", "local"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Name", text: $name)
                    TextField("Command (e.g., npx)", text: $command)
                    TextField("Arguments (space-separated)", text: $args)
                }

                Section("Scope") {
                    Picker("Scope", selection: $scope) {
                        ForEach(scopes, id: \.self) { scope in
                            Text(scope.capitalized).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text("The MCP server will be added to your Claude Code configuration.")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }
            .navigationTitle("Add MCP Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        createServer()
                    }
                    .disabled(name.isEmpty || command.isEmpty || isCreating)
                }
            }
        }
    }

    private func createServer() {
        isCreating = true

        Task {
            let client = APIClient()
            let argsArray = args.split(separator: " ").map(String.init)
            let request = CreateMCPRequest(
                name: name,
                command: command,
                args: argsArray,
                scope: scope
            )

            do {
                let response: APIResponse<MCPServerItem> = try await client.post("/mcp", body: request)
                if let server = response.data {
                    await MainActor.run {
                        onCreated(server)
                        dismiss()
                    }
                }
            } catch {
                print("Failed to create MCP server: \(error)")
            }

            isCreating = false
        }
    }
}

// MARK: - Models

struct MCPServerItem: Identifiable, Decodable {
    let id: UUID
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]?
    let scope: String
    let status: String
    let configPath: String?
}

struct CreateMCPRequest: Encodable {
    let name: String
    let command: String
    let args: [String]
    let scope: String
}

#Preview {
    NavigationStack {
        MCPServerListView()
    }
}
