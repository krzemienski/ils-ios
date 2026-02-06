import SwiftUI

struct SSHConnectionsView: View {
    @StateObject private var manager = SSHConnectionManager()
    @State private var showingAddConnection = false
    @State private var selectedConnection: SSHConnection?
    @State private var connectionToDelete: SSHConnection?

    var body: some View {
        List {
            if manager.connections.isEmpty {
                ContentUnavailableView(
                    "No SSH Connections",
                    systemImage: "server.rack",
                    description: Text("Add a remote server to manage Claude Code remotely")
                )
            } else {
                ForEach(manager.connections) { connection in
                    SSHConnectionRow(connection: connection)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedConnection = connection
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                connectionToDelete = connection
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("SSH Connections")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddConnection = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.orange)
                }
            }
        }
        .sheet(isPresented: $showingAddConnection) {
            NavigationStack {
                SSHConnectionFormView(manager: manager)
            }
        }
        .sheet(item: $selectedConnection) { connection in
            NavigationStack {
                SSHConnectionFormView(manager: manager, existingConnection: connection)
            }
        }
        .alert("Delete Connection?", isPresented: .init(
            get: { connectionToDelete != nil },
            set: { if !$0 { connectionToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { connectionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let conn = connectionToDelete {
                    manager.delete(conn)
                    connectionToDelete = nil
                }
            }
        } message: {
            Text("This will remove the SSH connection and its stored credentials.")
        }
    }
}

struct SSHConnectionRow: View {
    let connection: SSHConnection

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(connection.name.isEmpty ? connection.host : connection.name)
                    .font(.headline)
                    .foregroundColor(.white)

                Text("\(connection.username)@\(connection.host):\(connection.port)")
                    .font(.caption)
                    .foregroundColor(.gray)

                if let version = connection.claudeCodeVersion {
                    Text("Claude Code \(version)")
                        .font(.caption2)
                        .foregroundColor(.orange.opacity(0.8))
                }
            }

            Spacer()

            Circle()
                .fill(connection.isConnected ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 4)
    }
}
