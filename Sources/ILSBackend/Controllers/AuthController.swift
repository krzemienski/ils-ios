import Vapor
import ILSShared

/// Storage key for shared SSHService instance
struct SSHServiceKey: StorageKey {
    typealias Value = SSHService
}

extension Application {
    var sshService: SSHService {
        get {
            if let existing = self.storage[SSHServiceKey.self] {
                return existing
            }
            let service = SSHService(eventLoopGroup: self.eventLoopGroup)
            self.storage[SSHServiceKey.self] = service
            return service
        }
        set {
            self.storage[SSHServiceKey.self] = newValue
        }
    }
}

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("connect", use: connect)
        auth.post("disconnect", use: disconnect)
    }

    /// POST /auth/connect - Connect to remote server via SSH
    @Sendable
    func connect(req: Request) async throws -> APIResponse<ConnectionResponse> {
        let connectRequest = try req.content.decode(SSHConnectRequest.self)

        let authMethod: ServerConnection.AuthMethod
        switch connectRequest.authMethod.lowercased() {
        case "password":
            authMethod = .password
        case "sshkey", "ssh_key", "key":
            authMethod = .sshKey
        default:
            authMethod = .password
        }

        let response = try await req.application.sshService.connect(
            host: connectRequest.host,
            port: connectRequest.port,
            username: connectRequest.username,
            authMethod: authMethod,
            credential: connectRequest.credential
        )

        return APIResponse(success: response.success, data: response)
    }

    /// POST /auth/disconnect - Disconnect from current server
    @Sendable
    func disconnect(req: Request) async throws -> APIResponse<AcknowledgedResponse> {
        await req.application.sshService.disconnect()
        return APIResponse(success: true, data: AcknowledgedResponse(acknowledged: true))
    }
}
