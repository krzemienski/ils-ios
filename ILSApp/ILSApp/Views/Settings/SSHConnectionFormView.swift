import SwiftUI

struct SSHConnectionFormView: View {
    @ObservedObject var manager: SSHConnectionManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var authMethod: SSHConnection.AuthMethod = .sshKey
    @State private var credential: String = ""
    @State private var isTesting: Bool = false
    @State private var testResult: Bool?

    let existingConnection: SSHConnection?

    init(manager: SSHConnectionManager, existingConnection: SSHConnection? = nil) {
        self.manager = manager
        self.existingConnection = existingConnection
    }

    var body: some View {
        Form {
            Section("Connection Details") {
                TextField("Name (optional)", text: $name)
                TextField("Host", text: $host)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocapitalization(.none)
            }

            Section("Authentication") {
                Picker("Method", selection: $authMethod) {
                    ForEach(SSHConnection.AuthMethod.allCases, id: \.self) { method in
                        Text(method == .sshKey ? "SSH Key" : "Password").tag(method)
                    }
                }
                .pickerStyle(.segmented)

                if authMethod == .password {
                    SecureField("Password", text: $credential)
                } else {
                    TextField("Private Key Path", text: $credential)
                        .autocapitalization(.none)
                        .font(.system(.body, design: .monospaced))
                    Text("e.g. ~/.ssh/id_ed25519")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Section {
                Button {
                    Task { await testConnectionTapped() }
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .tint(.orange)
                        } else {
                            Image(systemName: testResult == true ? "checkmark.circle.fill" : testResult == false ? "xmark.circle.fill" : "antenna.radiowaves.left.and.right")
                                .foregroundColor(testResult == true ? .green : testResult == false ? .red : .orange)
                        }
                        Text(isTesting ? "Testing..." : "Test Connection")
                    }
                }
                .disabled(host.isEmpty || username.isEmpty || isTesting)
            }

            if let result = testResult {
                Section {
                    HStack {
                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result ? .green : .red)
                        Text(result ? "Connection successful" : "Connection failed")
                            .foregroundColor(result ? .green : .red)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle(existingConnection == nil ? "Add Server" : "Edit Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.orange)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveConnection() }
                    .foregroundColor(.orange)
                    .disabled(host.isEmpty || username.isEmpty)
            }
        }
        .onAppear {
            if let conn = existingConnection {
                name = conn.name
                host = conn.host
                port = String(conn.port)
                username = conn.username
                authMethod = conn.authMethod
                credential = manager.loadCredential(for: conn.id) ?? ""
            }
        }
    }

    private func testConnectionTapped() async {
        isTesting = true
        testResult = nil
        let connection = SSHConnection(
            name: name, host: host,
            port: Int(port) ?? 22, username: username,
            authMethod: authMethod
        )
        testResult = await manager.testConnection(connection)
        isTesting = false
    }

    private func saveConnection() {
        var connection = existingConnection ?? SSHConnection()
        connection.name = name
        connection.host = host
        connection.port = Int(port) ?? 22
        connection.username = username
        connection.authMethod = authMethod

        manager.save(connection)
        if !credential.isEmpty {
            manager.saveCredential(credential, for: connection.id)
        }
        dismiss()
    }
}
