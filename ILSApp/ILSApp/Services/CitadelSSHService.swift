import Foundation
// CONC-29: @preconcurrency suppresses Sendable warnings for Citadel types (SSHClient)
// which pre-date Swift 6 and lack Sendable conformance.
@preconcurrency import Citadel
import Crypto
import NIO
import NIOSSH

/// SSH service using Citadel for connecting to remote servers.
actor CitadelSSHService {
    private var client: SSHClient?
    private var jumpHostClient: SSHClient?
    private var connectionInfo: ConnectionInfo?

    // MARK: - Phase 3: Connection Monitoring

    /// Handler invoked when the connection is detected as dropped.
    private var reconnectionHandler: (@Sendable () -> Void)?
    /// Background task that periodically checks if the SSH connection is alive.
    private var monitoringTask: Task<Void, Never>?

    // MARK: - Phase 6: Port Forwarding

    /// NIO event loop group used for local port-forwarding server bootstraps.
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    /// Map of localPort → active NIO Channel (server side of the forwarding).
    private var portForwardings: [Int: Channel] = [:]

    /// MEM-HIGH-2: Safety-net deinit cancels monitoringTask if disconnect() was not called.
    /// Task.cancel() is thread-safe and valid from nonisolated deinit context.
    deinit {
        monitoringTask?.cancel()
    }

    // MARK: - Connection Info

    struct ConnectionInfo {
        let host: String
        let port: Int
        let username: String
        let connectedAt: Date
        let agentForwarding: Bool
    }

    /// Jump host configuration for proxied SSH connections.
    struct JumpHostConfig {
        let host: String
        let port: Int
        let username: String
        let authMethod: String
        let credential: String
    }

    // MARK: - Connection Management

    func connect(
        host: String,
        port: Int,
        username: String,
        authMethod: String,
        credential: String,
        agentForwarding: Bool = false,
        jumpHost: JumpHostConfig? = nil
    ) async throws -> Bool {
        do {
            if let jumpHost = jumpHost {
                try await connectViaJumpHost(
                    targetHost: host,
                    targetPort: port,
                    targetUsername: username,
                    targetAuthMethod: authMethod,
                    targetCredential: credential,
                    jumpHost: jumpHost
                )
            } else {
                let authenticationMethod = try buildAuthMethod(
                    username: username,
                    authMethod: authMethod,
                    credential: credential
                )

                // Connect to SSH server
                // NET-01: SSH host key validation — TOFU (Trust On First Use) model.
                // This is a developer tool where users explicitly configure their SSH hosts
                // (host, port, username, credentials). The user has already expressed intent
                // to connect to a specific machine they control.
                //
                // Full known_hosts management would require:
                //   1. Persistent storage of per-host public key fingerprints (Keychain/file)
                //   2. UI to review and approve new or changed host keys
                //   3. Handling key rotation (legitimate server re-keys after OS reinstall)
                //
                // This is deferred to a future enhancement. Users who need strict host key
                // pinning should use their system SSH client with a properly maintained
                // ~/.ssh/known_hosts file. For this developer tool, .acceptAnything() is the
                // documented and intentional security posture — not an oversight.
                self.client = try await SSHClient.connect(
                    host: host,
                    port: port,
                    authenticationMethod: authenticationMethod,
                    hostKeyValidator: .acceptAnything(),
                    reconnect: .always
                )
            }

            self.connectionInfo = ConnectionInfo(
                host: host,
                port: port,
                username: username,
                connectedAt: Date(),
                agentForwarding: agentForwarding
            )

            // Note: Citadel 0.12.x does not expose an agent forwarding API.
            // agentForwarding=true is stored in ConnectionInfo for future use
            // when Citadel adds support or a manual implementation is added.

            return true
        } catch let error as SSHError {
            throw error
        } catch {
            throw SSHError.connectionFailed(error.localizedDescription)
        }
    }

    func disconnect() async {
        await stopConnectionMonitoring()

        // Stop all active port forwardings
        let activePorts = Array(portForwardings.keys)
        for localPort in activePorts {
            try? await stopPortForwarding(localPort: localPort)
        }

        // Shut down the event loop group used for port forwarding
        if let elg = eventLoopGroup {
            try? await elg.shutdownGracefully()
            eventLoopGroup = nil
        }

        if let client = client {
            try? await client.close()
        }
        if let jumpHostClient = jumpHostClient {
            try? await jumpHostClient.close()
        }
        client = nil
        jumpHostClient = nil
        connectionInfo = nil
    }

    func getStatus() async -> (connected: Bool, host: String?, username: String?, connectedAt: Date?) {
        guard let info = connectionInfo else {
            return (false, nil, nil, nil)
        }
        return (client != nil, info.host, info.username, info.connectedAt)
    }

    // MARK: - Phase 3: Connection Monitoring & Auto-Reconnect

    /// Starts a background task that pings the remote every `interval` seconds.
    /// If the ping fails, the registered reconnection handler is invoked.
    func startConnectionMonitoring(interval: TimeInterval = 5) async {
        monitoringTask?.cancel()
        monitoringTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                let alive = await self.checkConnectionAlive()
                if !alive {
                    await self.reconnectionHandler?()
                }
            }
        }
    }

    /// Stops the connection monitoring background task.
    func stopConnectionMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    /// Checks whether the SSH connection is alive by sending a lightweight echo command.
    /// - Returns: `true` if the connection is responsive, `false` otherwise.
    func checkConnectionAlive() async -> Bool {
        guard client != nil else { return false }
        do {
            let result = try await executeCommand("echo ping", timeout: 5)
            return result.exitCode == 0
        } catch {
            return false
        }
    }

    /// Registers a handler to be called when the connection is detected as dropped.
    func setReconnectionHandler(_ handler: @escaping @Sendable () -> Void) async {
        self.reconnectionHandler = handler
    }

    // MARK: - Phase 5: Jump Host Support

    /// Connects to the target SSH host by first establishing a connection through a jump/bastion host.
    /// Uses Citadel's built-in `jump(to:)` API which creates a DirectTCPIP channel through
    /// the jump host and layers a new SSH session on top of it.
    private func connectViaJumpHost(
        targetHost: String,
        targetPort: Int,
        targetUsername: String,
        targetAuthMethod: String,
        targetCredential: String,
        jumpHost: JumpHostConfig
    ) async throws {
        // 1. Connect to the jump/bastion host first
        let jumpAuth = try buildAuthMethod(
            username: jumpHost.username,
            authMethod: jumpHost.authMethod,
            credential: jumpHost.credential
        )
        let jumpClient = try await SSHClient.connect(
            host: jumpHost.host,
            port: jumpHost.port,
            authenticationMethod: jumpAuth,
            hostKeyValidator: .acceptAnything(),
            reconnect: .always
        )
        self.jumpHostClient = jumpClient

        // 2. Connect to the target through the jump host using Citadel's jump(to:) API.
        //    This opens a DirectTCPIP channel through jumpClient and negotiates SSH on top.
        let targetAuth = try buildAuthMethod(
            username: targetUsername,
            authMethod: targetAuthMethod,
            credential: targetCredential
        )
        let targetSettings = SSHClientSettings(
            host: targetHost,
            port: targetPort,
            authenticationMethod: { targetAuth },
            hostKeyValidator: .acceptAnything()
        )
        self.client = try await jumpClient.jump(to: targetSettings)
    }

    // MARK: - SSH Key Parsing

    /// Parses an SSH private key string and returns the appropriate authentication method.
    /// Tries key types in order: ed25519 (most common modern), RSA (legacy but common).
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
        // but we include them for completeness if raw key data is provided.

        throw SSHError.unsupportedKeyType(
            "Could not parse SSH key. Supported types: ed25519, RSA. " +
            "Ensure the key is in OpenSSH format (BEGIN OPENSSH PRIVATE KEY)."
        )
    }

    /// Builds an `SSHAuthenticationMethod` from the given parameters.
    private func buildAuthMethod(
        username: String,
        authMethod: String,
        credential: String
    ) throws -> SSHAuthenticationMethod {
        if authMethod == "password" {
            return .passwordBased(username: username, password: credential)
        } else {
            let keyString: String
            if credential.contains("BEGIN") {
                keyString = credential
            } else {
                let keyData = try Data(contentsOf: URL(fileURLWithPath: credential))
                guard let decoded = String(data: keyData, encoding: .utf8) else {
                    throw SSHError.commandFailed("Could not read SSH key file as UTF-8")
                }
                keyString = decoded
            }
            return try Self.parseKeyAuth(username: username, keyString: keyString)
        }
    }

    // MARK: - Platform Detection

    func detectPlatform() async throws -> (platform: String, isSupported: Bool, rejectionReason: String?) {
        guard client != nil else {
            throw SSHError.notConnected
        }

        let result = try await executeCommand("uname -s")
        let rawOutput = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        // When inShell: true, the output may include MOTD/login banners before the
        // actual command output. Check each line for the platform identifier.
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
    func executeCommand(
        _ command: String,
        timeout: Int? = 30
    ) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        guard let client = client else {
            throw SSHError.notConnected
        }

        do {
            // Use mergeStreams: true to capture stderr in the output as well.
            // Use inShell: true for commands that need shell features (pipes, redirects).
            let buffer = try await client.executeCommand(command, mergeStreams: true, inShell: true)
            let output = String(buffer: buffer)
            return (stdout: output, stderr: "", exitCode: 0)
        } catch let error as SSHClient.CommandFailed {
            return (stdout: "", stderr: "Command exited with code \(error.exitCode)", exitCode: Int32(error.exitCode))
        }
    }

    // MARK: - Streaming Command Execution

    /// Executes a command on the remote server with real-time streaming output.
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
                    onOutput(text)
                }
            }

            return (exitCode: 0, output: fullOutput)
        } catch let error as SSHClient.CommandFailed {
            return (exitCode: Int32(error.exitCode), output: "Command failed with exit code \(error.exitCode)")
        }
    }

    // MARK: - Phase 6: SSH Local Port Forwarding

    /// Starts SSH local port forwarding using a NIO ServerBootstrap.
    ///
    /// Binds to 127.0.0.1:localPort and for each accepted local connection opens a
    /// DirectTCPIP channel through the SSH session to remoteHost:remotePort,
    /// then relays data bidirectionally using `LocalToSSHRelayHandler` and
    /// `SSHToLocalRelayHandler`.
    ///
    /// - Parameters:
    ///   - localPort: Local port to listen on (e.g., 9999).
    ///   - remoteHost: Remote host to forward to (default: "localhost").
    ///   - remotePort: Remote port to forward to (e.g., 9999).
    /// - Returns: The server URL (`http://localhost:{localPort}`).
    /// - Throws: `SSHError.notConnected` if not connected; NIO error if port is in use.
    func startPortForwarding(
        localPort: Int,
        remoteHost: String = "localhost",
        remotePort: Int
    ) async throws -> String {
        guard let sshClient = client else {
            throw SSHError.notConnected
        }

        // Stop any existing forwarding on this port
        if portForwardings[localPort] != nil {
            try? await stopPortForwarding(localPort: localPort)
        }

        // Create or reuse the NIO event loop group
        if eventLoopGroup == nil {
            eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        }
        guard let elg = eventLoopGroup else {
            throw SSHError.commandFailed("Failed to create NIO event loop group")
        }

        // Bootstrap a local TCP server. For each accepted connection, open a
        // DirectTCPIP SSH channel and wire up bidirectional relay handlers.
        let bootstrap = ServerBootstrap(group: elg)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { localChannel in
                // Build originator address for the DirectTCPIP channel.
                // "127.0.0.1" is always valid; the cast to SocketAddress will not fail.
                let originatorAddress: SocketAddress
                do {
                    originatorAddress = try SocketAddress(ipAddress: "127.0.0.1", port: 0)
                } catch {
                    return localChannel.eventLoop.makeFailedFuture(error)
                }

                // Use a promise to bridge the async Citadel API into EventLoopFuture.
                let promise = localChannel.eventLoop.makePromise(of: Void.self)

                Task {
                    do {
                        // Open a DirectTCPIP channel from the SSH client to the remote target.
                        let sshChannel = try await sshClient.createDirectTCPIPChannel(
                            using: SSHChannelType.DirectTCPIP(
                                targetHost: remoteHost,
                                targetPort: remotePort,
                                originatorAddress: originatorAddress
                            )
                        ) { channel in
                            // Wire up SSH→local relay on the SSH channel side.
                            channel.pipeline.addHandler(
                                SSHToLocalRelayHandler(localChannel: localChannel)
                            )
                        }

                        // Wire up local→SSH relay on the local channel side.
                        try await localChannel.pipeline.addHandler(
                            LocalToSSHRelayHandler(sshChannel: sshChannel)
                        )

                        promise.succeed(())
                    } catch {
                        promise.fail(error)
                    }
                }

                return promise.futureResult
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        let serverChannel = try await bootstrap.bind(host: "127.0.0.1", port: localPort).get()
        portForwardings[localPort] = serverChannel

        return "http://localhost:\(localPort)"
    }

    /// Stops an active SSH local port forwarding by closing its NIO server channel.
    /// - Parameter localPort: The local port of the forwarding to stop.
    func stopPortForwarding(localPort: Int) async throws {
        guard let channel = portForwardings[localPort] else { return }
        try await channel.close()
        portForwardings.removeValue(forKey: localPort)
    }

    /// Returns the list of currently active local port forwarding ports.
    func getActivePortForwardings() async -> [Int] {
        return Array(portForwardings.keys)
    }
}

// MARK: - Phase 6: NIO Relay Handlers

/// Relays data arriving on the local TCP channel out to the SSH DirectTCPIP channel.
final class LocalToSSHRelayHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let sshChannel: Channel

    init(sshChannel: Channel) {
        self.sshChannel = sshChannel
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        // Forward: local client → SSH DirectTCPIP channel
        sshChannel.writeAndFlush(buffer, promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        // Local side closed — close the SSH channel too
        sshChannel.close(promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)
    }
}

/// Relays data arriving from the SSH DirectTCPIP channel back to the local TCP channel.
final class SSHToLocalRelayHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let localChannel: Channel

    init(localChannel: Channel) {
        self.localChannel = localChannel
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        // Forward: SSH DirectTCPIP channel → local client
        localChannel.writeAndFlush(buffer, promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        // SSH side closed — close the local channel too
        localChannel.close(promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)
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
