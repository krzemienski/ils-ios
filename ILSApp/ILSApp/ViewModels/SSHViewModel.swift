import Foundation
import ILSShared

@MainActor
final class SSHViewModel: ObservableObject {
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var platform: String?
    @Published var connectionError: String?
    @Published var connectedAt: Date?

    private let sshService = CitadelSSHService()

    func connect(host: String, port: Int, username: String, authMethod: String, credential: String) async {
        isConnecting = true
        connectionError = nil
        defer { isConnecting = false }

        do {
            isConnected = try await sshService.connect(
                host: host,
                port: port,
                username: username,
                authMethod: authMethod,
                credential: credential
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
        await sshService.disconnect()
        isConnected = false
        platform = nil
        connectedAt = nil
    }

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

    func refreshStatus() async {
        let status = await sshService.getStatus()
        isConnected = status.connected
        connectedAt = status.connectedAt
    }
    
    func executeCommand(_ command: String, timeout: Int? = 30) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        return try await sshService.executeCommand(command, timeout: timeout)
    }
}
