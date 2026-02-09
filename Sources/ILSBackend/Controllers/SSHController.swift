import Vapor
import ILSShared

struct SSHController: RouteCollection {
    let sshService: SSHService

    func boot(routes: RoutesBuilder) throws {
        let ssh = routes.grouped("ssh")
        ssh.post("connect", use: connect)
        ssh.post("disconnect", use: disconnect)
        ssh.get("status", use: status)
        ssh.post("execute", use: execute)
        ssh.get("platform", use: platform)
    }

    @Sendable
    func connect(req: Request) async throws -> APIResponse<ConnectionResponse> {
        let input = try req.content.decode(SSHConnectRequest.self)
        let authMethod: ServerConnection.AuthMethod =
            input.authMethod == "sshKey" ? .sshKey : .password
        let result = try await sshService.connect(
            host: input.host,
            port: input.port,
            username: input.username,
            authMethod: authMethod,
            credential: input.credential
        )
        return APIResponse(success: result.success, data: result)
    }

    @Sendable
    func disconnect(req: Request) async throws -> APIResponse<AcknowledgedResponse> {
        await sshService.disconnect()
        return APIResponse(success: true, data: AcknowledgedResponse())
    }

    @Sendable
    func status(req: Request) async throws -> APIResponse<SSHStatusResponse> {
        let status = await sshService.getStatus()
        return APIResponse(success: true, data: status)
    }

    @Sendable
    func execute(req: Request) async throws -> APIResponse<SSHExecuteResponse> {
        let input = try req.content.decode(SSHExecuteRequest.self)
        let result = try await sshService.executeCommand(input.command)
        return APIResponse(
            success: true,
            data: SSHExecuteResponse(
                stdout: result.stdout,
                stderr: result.stderr,
                exitCode: result.exitCode
            )
        )
    }

    @Sendable
    func platform(req: Request) async throws -> APIResponse<SSHPlatformResponse> {
        let platform = try await sshService.detectPlatform()
        return APIResponse(success: true, data: platform)
    }
}
