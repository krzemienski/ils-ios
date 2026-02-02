import SwiftUI
import ILSShared

struct MCPServerListView: View {
    @StateObject private var viewModel = MCPViewModel()
    @State private var showingNewServer = false

    var body: some View {
        List {
            if viewModel.filteredServers.isEmpty && !viewModel.isLoading {
                if viewModel.servers.isEmpty {
                    ContentUnavailableView(
                        "No MCP Servers",
                        systemImage: "server.rack",
                        description: Text("Add MCP servers to extend Claude's capabilities")
                    )
                } else {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            } else {
                ForEach(viewModel.filteredServers) { server in
                    NavigationLink(value: server) {
                        MCPServerRowView(server: server)
                    }
                }
                .onDelete(perform: deleteServer)
            }
        }
        .navigationTitle("MCP Servers")
        .navigationDestination(for: MCPServerItem.self) { server in
            MCPServerDetailView(server: server)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search servers")
        .refreshable {
            await viewModel.refreshServers()
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
            if viewModel.isLoading && viewModel.servers.isEmpty {
                ProgressView()
            }
        }
        .task {
            await viewModel.loadServers()
        }
    }

    private func deleteServer(at offsets: IndexSet) {
        Task {
            let serversToDelete = offsets.map { viewModel.filteredServers[$0] }
            for server in serversToDelete {
                await viewModel.deleteServer(server)
            }
        }
    }
}

struct MCPServerRowView: View {
    let server: MCPServerItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            HStack(spacing: 8) {
                // Scope badge
                Text(server.scope.capitalized)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ILSTheme.tertiaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusS)

                // Environment variable count badge
                if let env = server.env, !env.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 9))
                        Text("\(env.count) env")
                    }
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ILSTheme.accent.opacity(0.1))
                    .cornerRadius(ILSTheme.cornerRadiusS)
                }

                Spacer()
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

// MARK: - Detail View

struct MCPServerDetailView: View {
    let server: MCPServerItem
    @State private var showCopiedToast = false

    var body: some View {
        List {
            // Command Section
            Section("Command") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(server.command)
                        .font(ILSTheme.codeFont)
                        .foregroundColor(ILSTheme.primaryText)

                    if !server.args.isEmpty {
                        Text("Arguments:")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.secondaryText)

                        Text(server.args.joined(separator: " "))
                            .font(ILSTheme.codeFont)
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }
                .textSelection(.enabled)
            }

            // Environment Variables Section
            if let env = server.env, !env.isEmpty {
                Section("Environment Variables") {
                    ForEach(env.keys.sorted(), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.primaryText)

                            Spacer()

                            Text(env[key] ?? "")
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
            }

            // Configuration Section
            Section("Configuration") {
                LabeledContent("Scope") {
                    Text(server.scope.capitalized)
                        .foregroundColor(ILSTheme.secondaryText)
                }

                LabeledContent("Status") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .foregroundColor(statusColor)
                    }
                }

                if let configPath = server.configPath {
                    LabeledContent("Config Path") {
                        Text(configPath)
                            .font(ILSTheme.codeFont)
                            .foregroundColor(ILSTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
            }

            // Full Command Section
            Section("Full Command") {
                Text(fullCommand)
                    .font(ILSTheme.codeFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(server.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        copyToClipboard()
                    } label: {
                        Label("Copy Command", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(ILSTheme.cornerRadiusM)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
    }

    private var fullCommand: String {
        if server.args.isEmpty {
            return server.command
        }
        return "\(server.command) \(server.args.joined(separator: " "))"
    }

    private var statusColor: Color {
        switch server.status {
        case "healthy":
            return ILSTheme.success
        case "unhealthy":
            return ILSTheme.error
        default:
            return ILSTheme.warning
        }
    }

    private var statusText: String {
        switch server.status {
        case "healthy":
            return "Healthy"
        case "unhealthy":
            return "Unhealthy"
        default:
            return "Unknown"
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = fullCommand
        showCopiedToast = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                showCopiedToast = false
            }
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

struct MCPServerItem: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]?
    let scope: String
    let status: String
    let configPath: String?

    // Hashable conformance for NavigationLink
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MCPServerItem, rhs: MCPServerItem) -> Bool {
        lhs.id == rhs.id
    }
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
