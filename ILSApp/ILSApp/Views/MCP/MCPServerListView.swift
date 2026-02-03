import SwiftUI
import ILSShared

struct MCPServerListView: View {
    @StateObject private var viewModel = MCPViewModel()
    @State private var showingNewServer = false

    var body: some View {
        List {
            if let error = viewModel.error {
                ErrorStateView(error: error) {
                    await viewModel.loadServers()
                }
            } else if viewModel.filteredServers.isEmpty && !viewModel.isLoading {
                if viewModel.servers.isEmpty {
                    EmptyStateView(
                        title: "No MCP Servers",
                        systemImage: "server.rack",
                        description: "Add MCP servers to extend Claude's capabilities",
                        actionTitle: "Add Server"
                    ) {
                        showingNewServer = true
                    }
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
                ProgressView("Loading MCP servers...")
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
    @StateObject private var viewModel: MCPViewModel
    @State private var showCopiedToast = false
    @State private var showingEditSheet = false
    @State private var isEnabled: Bool

    init(server: MCPServerItem) {
        self.server = server
        self._viewModel = StateObject(wrappedValue: MCPViewModel())
        self._isEnabled = State(initialValue: !server.disabled)
    }

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

                Toggle("Enabled", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        Task {
                            await viewModel.toggleServer(server)
                        }
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
                Button {
                    showingEditSheet = true
                } label: {
                    Text("Edit")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
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
        .sheet(isPresented: $showingEditSheet) {
            EditMCPServerView(server: server) { _ in
                // Optional: handle updated server
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
    @State private var envVars: [EnvVar] = []
    @State private var isCreating = false
    @State private var showingAddEnvVar = false
    @State private var newEnvKey = ""
    @State private var newEnvValue = ""

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

                // Environment Variables Section
                Section {
                    ForEach(envVars.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(envVars[index].key)
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.primaryText)

                            TextField("Value", text: $envVars[index].value)
                                .font(ILSTheme.codeFont)
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }
                    .onDelete(perform: deleteEnvVar)

                    Button {
                        showingAddEnvVar = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Environment Variable")
                        }
                        .foregroundColor(ILSTheme.accent)
                    }
                } header: {
                    Text("Environment Variables")
                } footer: {
                    Text("Environment variables will be passed to the MCP server process.")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
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
            .sheet(isPresented: $showingAddEnvVar) {
                addEnvVarSheet
            }
        }
    }

    private var addEnvVarSheet: some View {
        NavigationStack {
            Form {
                Section("Environment Variable") {
                    TextField("Key (e.g., API_KEY)", text: $newEnvKey)
                        .font(ILSTheme.codeFont)
                        .autocapitalization(.allCharacters)

                    TextField("Value", text: $newEnvValue)
                        .font(ILSTheme.codeFont)
                }

                Section {
                    Text("Add an environment variable that will be available to the MCP server.")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }
            .navigationTitle("Add Environment Variable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetEnvVarForm()
                        showingAddEnvVar = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addEnvVar()
                    }
                    .disabled(newEnvKey.isEmpty)
                }
            }
        }
    }

    private func deleteEnvVar(at offsets: IndexSet) {
        envVars.remove(atOffsets: offsets)
    }

    private func addEnvVar() {
        let key = newEnvKey.trimmingCharacters(in: .whitespaces)
        let value = newEnvValue.trimmingCharacters(in: .whitespaces)

        // Check if key already exists and update it, otherwise add new
        if let index = envVars.firstIndex(where: { $0.key == key }) {
            envVars[index].value = value
        } else {
            envVars.append(EnvVar(key: key, value: value))
            envVars.sort { $0.key < $1.key }
        }

        resetEnvVarForm()
        showingAddEnvVar = false
    }

    private func resetEnvVarForm() {
        newEnvKey = ""
        newEnvValue = ""
    }

    private func createServer() {
        isCreating = true

        Task {
            let client = APIClient()
            let argsArray = args.split(separator: " ").map(String.init)
            let envDict = envVars.isEmpty ? nil : Dictionary(uniqueKeysWithValues: envVars.map { ($0.key, $0.value) })
            let request = CreateMCPRequest(
                name: name,
                command: command,
                args: argsArray,
                scope: scope,
                env: envDict
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
    let disabled: Bool

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
    let env: [String: String]?
}

// MARK: - Supporting Types

private struct EnvVar: Identifiable {
    let id = UUID()
    let key: String
    var value: String
}

#Preview {
    NavigationStack {
        MCPServerListView()
    }
}
