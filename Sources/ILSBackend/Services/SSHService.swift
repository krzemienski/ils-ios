import Foundation
import Vapor
import Fluent
import ILSShared
import NIOCore
import NIOPosix
import NIOSSH

/// SSH service error types
enum SSHServiceError: Error {
    case connectionFailed(String)
    case authenticationFailed(String)
    case commandExecutionFailed(String)
    case invalidCredentials
    case timeout
    case serverNotFound
}

/// Service for SSH connection management and remote command execution
struct SSHService {

    /// Default connection timeout in seconds
    private let connectionTimeout: TimeInterval = 30

    /// Default command execution timeout in seconds
    private let commandTimeout: TimeInterval = 60

    // MARK: - Connection Testing

    /// Test SSH connection with provided credentials
    /// - Parameters:
    ///   - host: SSH server hostname or IP address
    ///   - port: SSH server port (default: 22)
    ///   - username: SSH username
    ///   - authType: Authentication type (password or key)
    ///   - credential: Password string or private key string based on authType
    /// - Returns: True if connection succeeds, throws error otherwise
    func testConnection(
        host: String,
        port: Int,
        username: String,
        authType: SSHAuthType,
        credential: String
    ) async throws -> Bool {
        // Basic validation
        guard !host.isEmpty, !username.isEmpty, !credential.isEmpty else {
            throw SSHServiceError.invalidCredentials
        }

        guard port > 0, port <= 65535 else {
            throw SSHServiceError.connectionFailed("Invalid port number")
        }

        // For now, return a mock success response
        // TODO: Implement actual SSH connection using NIOSSH
        // This will be implemented in the next iteration with proper channel setup
        return true
    }

    // MARK: - Command Execution

    /// Execute a command on a remote SSH server
    /// - Parameters:
    ///   - server: SSH server configuration
    ///   - credential: Password or private key string
    ///   - command: Command to execute
    ///   - timeout: Execution timeout (default: commandTimeout)
    /// - Returns: Command output and exit code
    func executeCommand(
        server: SSHServer,
        credential: String,
        command: String,
        timeout: TimeInterval? = nil
    ) async throws -> (output: String, exitCode: Int) {
        // Validate inputs
        guard !command.isEmpty else {
            throw SSHServiceError.commandExecutionFailed("Command cannot be empty")
        }

        guard !credential.isEmpty else {
            throw SSHServiceError.invalidCredentials
        }

        // For now, return a mock response
        // TODO: Implement actual SSH command execution using NIOSSH
        // This will establish connection, open exec channel, execute command, and capture output
        // The timeout parameter will be used when implementing the actual connection
        _ = timeout ?? commandTimeout
        return (output: "", exitCode: 0)
    }

    /// Execute a command on a remote server by server ID
    /// - Parameters:
    ///   - serverId: SSH server UUID
    ///   - credential: Password or private key string
    ///   - command: Command to execute
    ///   - db: Database connection
    /// - Returns: Command output and exit code
    func executeCommand(
        serverId: UUID,
        credential: String,
        command: String,
        on db: Database
    ) async throws -> (output: String, exitCode: Int) {
        // Fetch server from database
        guard let serverModel = try await SSHServerModel.query(on: db)
            .filter(\.$id == serverId)
            .first() else {
            throw SSHServiceError.serverNotFound
        }

        let server = serverModel.toShared()

        // Execute command
        return try await executeCommand(
            server: server,
            credential: credential,
            command: command
        )
    }

    // MARK: - Claude Code Detection

    /// Detect Claude Code CLI installation and version on remote server
    /// - Parameters:
    ///   - server: SSH server configuration
    ///   - credential: Password or private key string
    /// - Returns: Claude Code version string if detected, nil otherwise
    func detectClaudeCode(
        server: SSHServer,
        credential: String
    ) async throws -> String? {
        // Try to execute 'claude --version' command
        do {
            let (output, exitCode) = try await executeCommand(
                server: server,
                credential: credential,
                command: "claude --version"
            )

            // Check if command succeeded
            guard exitCode == 0, !output.isEmpty else {
                return nil
            }

            // Parse version from output
            // Expected format: "claude version X.Y.Z" or "X.Y.Z"
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed
        } catch {
            // Claude Code CLI not found or not accessible
            return nil
        }
    }

    /// Detect Claude Code CLI installation by server ID
    /// - Parameters:
    ///   - serverId: SSH server UUID
    ///   - credential: Password or private key string
    ///   - db: Database connection
    /// - Returns: Claude Code version string if detected, nil otherwise
    func detectClaudeCode(
        serverId: UUID,
        credential: String,
        on db: Database
    ) async throws -> String? {
        // Fetch server from database
        guard let serverModel = try await SSHServerModel.query(on: db)
            .filter(\.$id == serverId)
            .first() else {
            throw SSHServiceError.serverNotFound
        }

        let server = serverModel.toShared()

        // Detect Claude Code
        return try await detectClaudeCode(
            server: server,
            credential: credential
        )
    }

    // MARK: - Remote File Operations

    /// Read a file from remote server
    /// - Parameters:
    ///   - server: SSH server configuration
    ///   - credential: Password or private key string
    ///   - path: Remote file path
    /// - Returns: File contents as string
    func readRemoteFile(
        server: SSHServer,
        credential: String,
        path: String
    ) async throws -> String {
        // Execute 'cat' command to read file
        let (output, exitCode) = try await executeCommand(
            server: server,
            credential: credential,
            command: "cat '\(path)'"
        )

        guard exitCode == 0 else {
            throw SSHServiceError.commandExecutionFailed("Failed to read file: \(path)")
        }

        return output
    }

    /// Write a file to remote server
    /// - Parameters:
    ///   - server: SSH server configuration
    ///   - credential: Password or private key string
    ///   - path: Remote file path
    ///   - content: Content to write
    func writeRemoteFile(
        server: SSHServer,
        credential: String,
        path: String,
        content: String
    ) async throws {
        // Escape single quotes in content
        let escapedContent = content.replacingOccurrences(of: "'", with: "'\\''")

        // Use echo with redirection to write file
        let (_, exitCode) = try await executeCommand(
            server: server,
            credential: credential,
            command: "echo '\(escapedContent)' > '\(path)'"
        )

        guard exitCode == 0 else {
            throw SSHServiceError.commandExecutionFailed("Failed to write file: \(path)")
        }
    }

    /// List directory contents on remote server
    /// - Parameters:
    ///   - server: SSH server configuration
    ///   - credential: Password or private key string
    ///   - path: Remote directory path
    /// - Returns: Array of file/directory names
    func listRemoteDirectory(
        server: SSHServer,
        credential: String,
        path: String
    ) async throws -> [String] {
        let (output, exitCode) = try await executeCommand(
            server: server,
            credential: credential,
            command: "ls -1 '\(path)'"
        )

        guard exitCode == 0 else {
            throw SSHServiceError.commandExecutionFailed("Failed to list directory: \(path)")
        }

        // Parse output into array of filenames
        return output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Remote Session Management

    /// List Claude Code sessions on remote server
    /// - Parameters:
    ///   - server: SSH server configuration
    ///   - credential: Password or private key string
    /// - Returns: Array of ChatSession objects from remote server
    func listRemoteSessions(
        server: SSHServer,
        credential: String
    ) async throws -> [ChatSession] {
        // Execute 'claude sessions list' command
        let (output, exitCode) = try await executeCommand(
            server: server,
            credential: credential,
            command: "claude sessions list"
        )

        // If command fails, return empty array (Claude Code might not be installed)
        guard exitCode == 0 else {
            return []
        }

        // Parse the output to extract session information
        // Expected format (example):
        // ID                                    NAME            PROJECT         LAST ACTIVE
        // abc-123-def                          My Session      /path/to/proj   2 hours ago
        // xyz-456-ghi                          Another One     /other/path     1 day ago

        var sessions: [ChatSession] = []
        let lines = output.split(separator: "\n").map { String($0) }

        // Skip header line(s) and parse each session line
        for (index, line) in lines.enumerated() {
            // Skip header line (first line typically contains column names)
            guard index > 0, !line.isEmpty else { continue }

            // Simple parsing - extract session ID from first column
            // In production, this would need more robust parsing based on actual CLI output format
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            guard columns.count > 0 else { continue }

            let sessionId = String(columns[0])

            // Create a ChatSession with available information
            // Most fields will be nil/default since remote CLI output is limited
            let session = ChatSession(
                id: UUID(), // Generate new UUID for local tracking
                claudeSessionId: sessionId,
                name: columns.count > 1 ? String(columns[1]) : nil,
                projectId: nil,
                projectName: columns.count > 2 ? String(columns[2]) : nil,
                model: "sonnet", // Default, not available from CLI output
                permissionMode: .default,
                status: .active,
                messageCount: 0,
                totalCostUSD: nil,
                source: .external, // Mark as external since it's from remote server
                forkedFrom: nil,
                createdAt: Date(), // Default, not available from CLI output
                lastActiveAt: Date() // Default, would need to parse from CLI output
            )

            sessions.append(session)
        }

        return sessions
    }

    /// List Claude Code sessions on remote server by server ID
    /// - Parameters:
    ///   - serverId: SSH server UUID
    ///   - credential: Password or private key string
    ///   - db: Database connection
    /// - Returns: Array of ChatSession objects from remote server
    func listRemoteSessions(
        serverId: UUID,
        credential: String,
        on db: Database
    ) async throws -> [ChatSession] {
        // Fetch server from database
        guard let serverModel = try await SSHServerModel.query(on: db)
            .filter(\.$id == serverId)
            .first() else {
            throw SSHServiceError.serverNotFound
        }

        let server = serverModel.toShared()

        // List remote sessions
        return try await listRemoteSessions(
            server: server,
            credential: credential
        )
    }

    // MARK: - Remote Configuration

    /// Read Claude Code configuration from remote server
    /// - Parameters:
    ///   - server: SSH server configuration
    ///   - credential: Password or private key string
    ///   - scope: Configuration scope (user, project, workspace)
    /// - Returns: ConfigInfo object with remote configuration
    func readRemoteConfig(
        server: SSHServer,
        credential: String,
        scope: String
    ) async throws -> ConfigInfo {
        // Determine config file path based on scope
        let configPath: String
        switch scope {
        case "user":
            configPath = "~/.config/claude/config.json"
        case "project":
            configPath = "./.claude/config.json"
        case "workspace":
            configPath = "./.claude/workspace.json"
        default:
            configPath = "~/.config/claude/config.json"
        }

        // Read the remote config file
        do {
            let content = try await readRemoteFile(
                server: server,
                credential: credential,
                path: configPath
            )

            // Parse JSON into ClaudeConfig
            let decoder = JSONDecoder()
            let config = try decoder.decode(ClaudeConfig.self, from: Data(content.utf8))

            return ConfigInfo(
                scope: scope,
                path: configPath,
                content: config,
                isValid: true,
                errors: nil
            )
        } catch {
            // If file doesn't exist or can't be parsed, return empty config
            return ConfigInfo(
                scope: scope,
                path: configPath,
                content: ClaudeConfig(),
                isValid: false,
                errors: ["Failed to read config: \(error.localizedDescription)"]
            )
        }
    }

    /// Read Claude Code configuration from remote server by server ID
    /// - Parameters:
    ///   - serverId: SSH server UUID
    ///   - credential: Password or private key string
    ///   - scope: Configuration scope (user, project, workspace)
    ///   - db: Database connection
    /// - Returns: ConfigInfo object with remote configuration
    func readRemoteConfig(
        serverId: UUID,
        credential: String,
        scope: String,
        on db: Database
    ) async throws -> ConfigInfo {
        // Fetch server from database
        guard let serverModel = try await SSHServerModel.query(on: db)
            .filter(\.$id == serverId)
            .first() else {
            throw SSHServiceError.serverNotFound
        }

        let server = serverModel.toShared()

        // Read remote config
        return try await readRemoteConfig(
            server: server,
            credential: credential,
            scope: scope
        )
    }
}
