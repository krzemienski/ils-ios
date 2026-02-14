import Foundation
import Citadel
import Crypto
import NIO

/// SSH service using Citadel for connecting to remote servers
actor CitadelSSHService {
    private var client: SSHClient?
    private var connectionInfo: ConnectionInfo?

    struct ConnectionInfo {
        let host: String
        let port: Int
        let username: String
        let connectedAt: Date
    }

    // MARK: - Connection Management

    func connect(
        host: String,
        port: Int,
        username: String,
        authMethod: String,
        credential: String
    ) async throws -> Bool {
        do {
            let authenticationMethod: SSHAuthenticationMethod

            if authMethod == "password" {
                authenticationMethod = .passwordBased(username: username, password: credential)
            } else {
                // For SSH key authentication, read the private key file and parse by algorithm
                let keyString: String
                if credential.contains("BEGIN") {
                    // Credential is the key contents directly
                    keyString = credential
                } else {
                    // Credential is a file path
                    let keyData = try Data(contentsOf: URL(fileURLWithPath: credential))
                    guard let decoded = String(data: keyData, encoding: .utf8) else {
                        throw SSHError.commandFailed("Could not read SSH key file as UTF-8")
                    }
                    keyString = decoded
                }
                authenticationMethod = try Self.parseKeyAuth(username: username, keyString: keyString)
            }

            // Connect to SSH server
            self.client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: authenticationMethod,
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )

            self.connectionInfo = ConnectionInfo(
                host: host,
                port: port,
                username: username,
                connectedAt: Date()
            )

            return true
        } catch let error as SSHError {
            throw error
        } catch {
            throw SSHError.connectionFailed(error.localizedDescription)
        }
    }

    func disconnect() async {
        if let client = client {
            try? await client.close()
        }
        client = nil
        connectionInfo = nil
    }

    func getStatus() async -> (connected: Bool, host: String?, username: String?, connectedAt: Date?) {
        guard let info = connectionInfo else {
            return (false, nil, nil, nil)
        }
        return (client != nil, info.host, info.username, info.connectedAt)
    }

    // MARK: - SSH Key Parsing

    /// Parses an SSH private key string and returns the appropriate authentication method.
    /// Tries key types in order: ed25519 (most common modern), RSA (legacy but common),
    /// P256 (ECDSA), P384 (ECDSA).
    private static func parseKeyAuth(username: String, keyString: String) throws -> SSHAuthenticationMethod {
        // Try ed25519 first (most common for modern keys)
        if let key = try? Curve25519.Signing.PrivateKey(sshEd25519: keyString) {
            return .ed25519(username: username, privateKey: key)
        }

        // Try RSA (legacy but still very common)
        if let key = try? Insecure.RSA.PrivateKey(sshRsa: keyString) {
            return .rsa(username: username, privateKey: key)
        }

        // P256 and P384 don't have OpenSSH parsing initializers in Citadel,
        // but we include them for completeness if raw key data is provided
        // (these would need rawRepresentation, not SSH format)

        throw SSHError.unsupportedKeyType(
            "Could not parse SSH key. Supported types: ed25519, RSA. " +
            "Ensure the key is in OpenSSH format (BEGIN OPENSSH PRIVATE KEY)."
        )
    }

    // MARK: - Platform Detection

    func detectPlatform() async throws -> (platform: String, isSupported: Bool, rejectionReason: String?) {
        guard client != nil else {
            throw SSHError.notConnected
        }

        let result = try await executeCommand("uname -s")
        let rawOutput = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        // When inShell: true, the output may include MOTD/login banners before the
        // actual command output. Check each line for the platform identifier, and also
        // do a contains-check on the full output as a fallback.
        let lines = rawOutput.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        let lastNonEmptyLine = lines.last(where: { !$0.isEmpty }) ?? rawOutput

        let detectedPlatform: String
        let isSupported: Bool

        if lastNonEmptyLine.lowercased() == "linux" || rawOutput.lowercased().contains("linux") {
            detectedPlatform = "Linux"
            isSupported = true
        } else if lastNonEmptyLine.lowercased() == "darwin" || rawOutput.lowercased().contains("darwin") {
            detectedPlatform = "Darwin"
            isSupported = true
        } else {
            detectedPlatform = lastNonEmptyLine
            isSupported = false
        }

        let rejectionReason = isSupported ? nil : "Unsupported platform: \(detectedPlatform). Only Linux and macOS are supported."
        return (detectedPlatform, isSupported, rejectionReason)
    }

    // MARK: - Command Execution

    /// Executes a command on the remote server and returns the result.
    /// Citadel's `executeCommand` returns a `ByteBuffer` on success and throws
    /// `SSHClient.CommandFailed` on non-zero exit codes.
    func executeCommand(_ command: String, timeout: Int? = 30) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        guard let client = client else {
            throw SSHError.notConnected
        }

        do {
            // executeCommand returns ByteBuffer with stdout content.
            // Use mergeStreams: true to capture stderr in the output as well.
            // Use inShell: true for commands that need shell features (pipes, redirects).
            let buffer = try await client.executeCommand(command, mergeStreams: true, inShell: true)
            let output = String(buffer: buffer)
            return (stdout: output, stderr: "", exitCode: 0)
        } catch let error as SSHClient.CommandFailed {
            // Non-zero exit code — command ran but failed
            return (stdout: "", stderr: "Command exited with code \(error.exitCode)", exitCode: Int32(error.exitCode))
        }
    }

    // MARK: - Streaming Command Execution

    /// Executes a command on the remote server with real-time streaming output.
    /// Use this for long-running commands (git clone, swift build, cloudflared tunnel).
    /// The `onOutput` closure is called with each chunk of output as it arrives.
    ///
    /// - Parameters:
    ///   - command: The shell command to execute
    ///   - onOutput: Closure called with each output chunk (stdout and stderr)
    /// - Returns: A tuple with the exit code and the full accumulated output
    /// - Throws: SSHError if not connected, or other errors from the SSH layer
    func executeStreamingCommand(
        _ command: String,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> (exitCode: Int32, output: String) {
        guard let client = client else {
            throw SSHError.notConnected
        }

        do {
            let stream = try await client.executeCommandStream(command, inShell: true)
            var fullOutput = ""

            for try await chunk in stream {
                switch chunk {
                case .stdout(let buffer):
                    let text = String(buffer: buffer)
                    fullOutput += text
                    onOutput(text)
                case .stderr(let buffer):
                    let text = String(buffer: buffer)
                    fullOutput += text
                    onOutput(text)  // Show stderr too for build progress
                }
            }

            return (exitCode: 0, output: fullOutput)
        } catch let error as SSHClient.CommandFailed {
            // Command ran but exited with non-zero code
            return (exitCode: Int32(error.exitCode), output: "Command failed with exit code \(error.exitCode)")
        }
    }

    // MARK: - SSH Port Forwarding (Fallback Tunnel Strategy)

    /// Starts SSH local port forwarding as a fallback when Cloudflare tunnel is unavailable.
    /// This forwards a local port to a remote host:port through the SSH connection.
    ///
    /// **Note**: This is a simplified stub implementation. Full port forwarding requires:
    /// - NIO ServerBootstrap to listen on the local port
    /// - DirectTCPIP channels for each incoming connection
    /// - Bidirectional data relay between local socket and SSH channel
    ///
    /// For the MVP, this returns a localhost URL immediately. A complete implementation
    /// would require significant NIO networking code and is deferred to post-MVP.
    ///
    /// - Parameters:
    ///   - localPort: Local port to listen on (e.g., 9999)
    ///   - remoteHost: Remote host to forward to (default: "localhost")
    ///   - remotePort: Remote port to forward to (e.g., 9999)
    /// - Returns: The server URL (`http://localhost:{localPort}`)
    /// - Throws: SSHError if not connected
    func startPortForwarding(
        localPort: Int,
        remoteHost: String = "localhost",
        remotePort: Int
    ) async throws -> String {
        guard client != nil else {
            throw SSHError.notConnected
        }

        // TODO: Full implementation requires:
        // 1. NIO ServerBootstrap listening on localPort
        // 2. For each accepted connection:
        //    - Create DirectTCPIP channel: client.createDirectTCPIPChannel(
        //        using: SSHChannelType.DirectTCPIP(
        //            targetHost: remoteHost,
        //            targetPort: remotePort,
        //            originatorAddress: localSocketAddress
        //        )
        //      )
        //    - Relay data bidirectionally: local socket <-> SSH channel
        // 3. Keep forwarding active as long as SSH connection is alive
        //
        // This is complex and requires ~200 lines of NIO networking code.
        // For MVP, we prioritize Cloudflare tunnel and note this limitation.

        // Stub: return the URL without actually setting up forwarding
        // The calling code should prefer Cloudflare tunnel as primary strategy
        return "http://localhost:\(localPort)"
    }
}

// MARK: - Error Types

enum SSHError: Error, LocalizedError {
    case notConnected
    case connectionFailed(String)
    case commandFailed(String)
    case timeout(Int)
    case unsupportedKeyType(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to SSH host"
        case .connectionFailed(let message):
            return "SSH connection failed: \(message)"
        case .commandFailed(let message):
            return "Command execution failed: \(message)"
        case .timeout(let seconds):
            return "Command timed out after \(seconds) seconds"
        case .unsupportedKeyType(let message):
            return message
        }
    }
}
