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
    private var detectedPlatform: String?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts: Int = 0
    private let maxReconnectDelay: TimeInterval = 30

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

            // Note: In production, replace with .trustedKeys or custom validator
            // that verifies against known_hosts. Using .acceptAnything() for
            // development/trusted-network scenarios only.
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

        // Citadel's executeCommandStream does not provide exit codes.
        // Infer failure from stderr presence when stdout is empty.
        let trimmedStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let inferredExitCode = (trimmedStdout.isEmpty && !trimmedStderr.isEmpty) ? 1 : 0

        return CommandResult(
            stdout: trimmedStdout,
            stderr: trimmedStderr,
            exitCode: inferredExitCode
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

    func detectPlatform() async throws -> SSHPlatformResponse {
        let result = try await executeCommand("uname -s")
        let platform = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        detectedPlatform = platform

        let isWindows = platform.lowercased().contains("mingw") ||
                        platform.lowercased().contains("msys") ||
                        platform.lowercased().contains("cygwin")
        let isSupported = !isWindows && (platform == "Linux" || platform == "Darwin")

        return SSHPlatformResponse(
            platform: platform,
            isSupported: isSupported,
            rejectionReason: isWindows
                ? "Windows is not supported. Please use a Linux or macOS server."
                : (!isSupported ? "Unsupported platform: \(platform)" : nil)
        )
    }

    func getStatus() async -> SSHStatusResponse {
        SSHStatusResponse(
            connected: client != nil,
            host: connectionInfo?.host,
            username: connectionInfo?.username,
            platform: detectedPlatform,
            connectedAt: connectedAt,
            uptime: connectedAt.map { Date().timeIntervalSince($0) }
        )
    }

    func startAutoReconnect(
        host: String, port: Int, username: String,
        authMethod: ServerConnection.AuthMethod, credential: String
    ) {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let delay = min(
                    pow(2.0, Double(await self.reconnectAttempts)),
                    await self.maxReconnectDelay
                )
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { break }

                let result = try? await self.connect(
                    host: host, port: port, username: username,
                    authMethod: authMethod, credential: credential
                )
                if result?.success == true {
                    await self.resetReconnectAttempts()
                    break
                }
                await self.incrementReconnectAttempts()
            }
        }
    }

    func stopAutoReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempts = 0
    }

    private func resetReconnectAttempts() { reconnectAttempts = 0 }
    private func incrementReconnectAttempts() { reconnectAttempts += 1 }
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
