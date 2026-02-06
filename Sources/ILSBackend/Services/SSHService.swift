import Vapor
import Citadel
import NIO
import ILSShared
import NIOSSH

/// SSH connection errors
enum SSHError: AbortError {
    case connectionFailed(String)
    case authenticationFailed(String)
    case timeout
    case notConnected

    var status: HTTPResponseStatus {
        switch self {
        case .connectionFailed, .authenticationFailed, .timeout:
            return .badGateway
        case .notConnected:
            return .preconditionFailed
        }
    }

    var reason: String {
        switch self {
        case .connectionFailed(let message):
            return "SSH connection failed: \(message)"
        case .authenticationFailed(let message):
            return "SSH authentication failed: \(message)"
        case .timeout:
            return "SSH connection timeout"
        case .notConnected:
            return "Not connected to any server"
        }
    }
}

/// SSH service for remote server operations using Citadel
actor SSHService {
    private var client: SSHClient?
    private var connectionInfo: ServerConnection?
    private let eventLoopGroup: EventLoopGroup
    private var connectedAt: Date?

    init(eventLoopGroup: EventLoopGroup) {
        self.eventLoopGroup = eventLoopGroup
    }

    /// Connect to a remote server via SSH
    func connect(host: String, port: Int = 22, username: String, authMethod: ServerConnection.AuthMethod, credential: String) async throws -> ConnectionResponse {
        // Disconnect existing connection if any
        if client != nil {
            await disconnect()
        }

        do {
            let sshAuthMethod: SSHAuthenticationMethod
            switch authMethod {
            case .password:
                sshAuthMethod = .passwordBased(username: username, password: credential)
            case .sshKey:
                let privateKey = try Insecure.RSA.PrivateKey(sshRsa: credential)
                sshAuthMethod = .rsa(username: username, privateKey: privateKey)
            }

            client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: sshAuthMethod,
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )

            connectedAt = Date()
            connectionInfo = ServerConnection(
                host: host,
                port: port,
                username: username,
                authMethod: authMethod,
                label: "\(username)@\(host)"
            )

            // Probe server for Claude CLI
            let serverInfo = try await probeServerInfo()

            return ConnectionResponse(
                success: true,
                sessionId: UUID().uuidString,
                serverInfo: serverInfo
            )
        } catch {
            return ConnectionResponse(
                success: false,
                error: "SSH connection failed: \(error.localizedDescription)"
            )
        }
    }

    /// Disconnect from the current server
    func disconnect() async {
        do {
            try await client?.close()
        } catch {
            // Ignore close errors
        }
        client = nil
        connectionInfo = nil
        connectedAt = nil
    }

    /// Execute a remote command and return stdout/stderr
    func executeCommand(_ command: String) async throws -> CommandResult {
        guard let client = client else {
            throw SSHError.notConnected
        }

        var stdout = ""
        var stderr = ""

        let stream = try await client.executeCommandStream(command)
        for try await event in stream {
            switch event {
            case .stdout(let buffer):
                stdout += String(buffer: buffer)
            case .stderr(let buffer):
                stderr += String(buffer: buffer)
            }
        }

        return CommandResult(
            stdout: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
            exitCode: 0
        )
    }

    /// Check if currently connected
    func isConnected() -> Bool {
        return client != nil
    }

    /// Get server status including Claude version
    func getServerStatus() async throws -> ServerStatus {
        guard client != nil else {
            return ServerStatus(connected: false)
        }

        let uptime: TimeInterval? = connectedAt.map { Date().timeIntervalSince($0) }

        do {
            let versionResult = try await executeCommand("claude --version")
            let claudeVersion = versionResult.stdout.isEmpty ? nil : versionResult.stdout

            let configResult = try await executeCommand("ls ~/.claude/ 2>/dev/null || echo 'no config'")
            let hasConfig = !configResult.stdout.contains("no config")

            let configPaths: ClaudeConfigPaths? = hasConfig ? ClaudeConfigPaths(
                userSettings: "~/.claude/settings.json",
                projectSettings: nil,
                localSettings: nil,
                userMCP: "~/.claude/mcp.json",
                skills: "~/.claude/skills/"
            ) : nil

            return ServerStatus(
                connected: true,
                claudeVersion: claudeVersion,
                uptime: uptime,
                configPaths: configPaths
            )
        } catch {
            return ServerStatus(
                connected: true,
                claudeVersion: nil,
                uptime: uptime
            )
        }
    }

    /// Probe the server for Claude installation info
    private func probeServerInfo() async throws -> ServerInfo {
        let versionResult = try? await executeCommand("claude --version")
        let claudeInstalled = versionResult != nil && !(versionResult?.stdout.isEmpty ?? true)

        return ServerInfo(
            claudeInstalled: claudeInstalled,
            claudeVersion: versionResult?.stdout
        )
    }
}

/// Command execution result
public struct CommandResult: Codable, Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int

    public init(stdout: String, stderr: String, exitCode: Int) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}
