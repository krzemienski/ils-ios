import Foundation
import Observation
import ILSShared

@MainActor
@Observable
final class SSHViewModel {
    // MARK: - Connection State

    var isConnected = false
    var isConnecting = false
    var platform: String?
    var connectionError: String?
    var connectedAt: Date?

    // MARK: - Phase 3: Reconnection State

    /// `true` while an automatic reconnection attempt is in progress.
    var isReconnecting = false
    /// `true` while the background connection health monitor is running.
    var isMonitoringConnection = false

    // MARK: - Phase 2: Saved Connection Profiles

    /// All saved SSH connection profiles (no credentials — stored in Keychain).
    var savedProfiles: [CachedServerConnection] = []

    // MARK: - Private

    private let sshService = CitadelSSHService()
    private let database = LocalDatabase.shared
    private let keychain = KeychainService.shared

    // MARK: - Connection

    func connect(
        host: String,
        port: Int,
        username: String,
        authMethod: String,
        credential: String,
        agentForwarding: Bool = false
    ) async {
        isConnecting = true
        connectionError = nil
        defer { isConnecting = false }

        do {
            isConnected = try await sshService.connect(
                host: host,
                port: port,
                username: username,
                authMethod: authMethod,
                credential: credential,
                agentForwarding: agentForwarding
            )

            if isConnected {
                let status = await sshService.getStatus()
                connectedAt = status.connectedAt
            }
        } catch {
            connectionError = error.localizedDescription
            isConnected = false
        }
    }

    func disconnect() async {
        await stopConnectionMonitoring()
        await sshService.disconnect()
        isConnected = false
        platform = nil
        connectedAt = nil
    }

    // MARK: - Phase 3: Connection Monitoring

    /// Starts background health monitoring. Sets `isReconnecting` if the SSH link drops.
    func startConnectionMonitoring() async {
        isMonitoringConnection = true
        await sshService.setReconnectionHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.isReconnecting = true
            }
        }
        await sshService.startConnectionMonitoring()
    }

    /// Stops background health monitoring.
    func stopConnectionMonitoring() async {
        await sshService.stopConnectionMonitoring()
        isMonitoringConnection = false
        isReconnecting = false
    }

    // MARK: - Phase 2: Profile Management

    /// Saves a new SSH connection profile.
    ///
    /// The credential is stored in the Keychain under key `"ssh_credential_{id}"`.
    /// Only non-sensitive fields are persisted in the local database.
    ///
    /// - Parameters:
    ///   - host: Hostname or IP address of the remote server.
    ///   - port: SSH port (default: 22).
    ///   - username: SSH username.
    ///   - authMethod: Authentication method ("password" or "privateKey").
    ///   - credential: Password or private key content (stored securely in Keychain).
    ///   - label: Optional human-readable label for the profile.
    func saveProfile(
        host: String,
        port: Int = 22,
        username: String,
        authMethod: String,
        credential: String,
        label: String? = nil
    ) async {
        let profileId = UUID()
        let keychainKey = "ssh_credential_\(profileId.uuidString)"

        // Store credential securely in Keychain
        do {
            try await keychain.saveCredential(key: keychainKey, value: credential)
        } catch {
            connectionError = "Failed to save credential to Keychain: \(error.localizedDescription)"
            return
        }

        // Save non-sensitive profile data to database
        let record = CachedServerConnection(
            id: profileId.uuidString,
            host: host,
            port: port,
            username: username,
            authMethod: authMethod,
            label: label,
            lastConnected: nil,
            cachedAt: Date()
        )

        do {
            try await database.saveServerConnection(record)
        } catch {
            // Clean up Keychain entry if database save fails
            try? await keychain.deleteCredential(key: keychainKey)
            connectionError = "Failed to save profile: \(error.localizedDescription)"
            return
        }

        await loadProfiles()
    }

    /// Loads all saved SSH connection profiles from the local database.
    func loadProfiles() async {
        do {
            savedProfiles = try await database.fetchServerConnections()
        } catch {
            connectionError = "Failed to load profiles: \(error.localizedDescription)"
        }
    }

    /// Deletes a saved SSH connection profile and its Keychain credential.
    /// - Parameter id: UUID of the profile to delete.
    func deleteProfile(id: UUID) async {
        let keychainKey = "ssh_credential_\(id.uuidString)"

        // Remove credential from Keychain
        try? await keychain.deleteCredential(key: keychainKey)

        // Remove profile from database
        do {
            try await database.deleteServerConnection(byId: id.uuidString)
        } catch {
            connectionError = "Failed to delete profile: \(error.localizedDescription)"
            return
        }

        await loadProfiles()
    }

    /// Retrieves the stored credential for a saved profile.
    /// - Parameter profileId: UUID of the profile.
    /// - Returns: The credential string, or `nil` if not found.
    func getCredential(forProfileId profileId: UUID) async -> String? {
        let keychainKey = "ssh_credential_\(profileId.uuidString)"
        return try? await keychain.getCredential(key: keychainKey)
    }

    /// Connects using a saved profile, fetching its credential from Keychain.
    /// - Parameter id: UUID of the profile to connect with.
    func connectWithProfile(id: UUID) async {
        guard let profile = try? await database.fetchServerConnection(byId: id.uuidString) else {
            connectionError = "Profile not found"
            return
        }

        guard let credential = await getCredential(forProfileId: id) else {
            connectionError = "Credential not found for profile. Please re-enter your credentials."
            return
        }

        await connect(
            host: profile.host,
            port: profile.port,
            username: profile.username,
            authMethod: profile.authMethod,
            credential: credential
        )

        // Update lastConnected timestamp on success
        if isConnected {
            var updated = profile
            updated.lastConnected = Date()
            try? await database.saveServerConnection(updated)
            await loadProfiles()
        }
    }

    // MARK: - Platform Detection

    func detectPlatform() async -> SSHPlatformResponse? {
        do {
            let (platformName, isSupported, rejectionReason) = try await sshService.detectPlatform()
            platform = platformName
            return SSHPlatformResponse(
                platform: platformName,
                isSupported: isSupported,
                rejectionReason: rejectionReason
            )
        } catch {
            connectionError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Status

    func refreshStatus() async {
        let status = await sshService.getStatus()
        isConnected = status.connected
        connectedAt = status.connectedAt
    }

    func executeCommand(_ command: String, timeout: Int? = 30) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        return try await sshService.executeCommand(command, timeout: timeout)
    }
}
