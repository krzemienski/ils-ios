import Vapor
import ILSShared

struct SetupController: RouteCollection {
    let setupService: SetupService

    func boot(routes: RoutesBuilder) throws {
        let setup = routes.grouped("setup")
        setup.post("start", use: start)
        setup.get("progress", use: progress)
    }

    @Sendable
    func start(req: Request) async throws -> Response {
        let input = try req.content.decode(StartSetupRequest.self)

        let headers = HTTPHeaders([
            ("Content-Type", "text/event-stream"),
            ("Cache-Control", "no-cache"),
            ("Connection", "keep-alive"),
        ])

        let response = Response(status: .ok, headers: headers)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        response.body = .init(asyncStream: { writer in
            do {
                try await setupService.runSetup(
                    backendPort: input.backendPort,
                    repositoryURL: input.repositoryURL,
                    progressCallback: { progress in
                        if let data = try? encoder.encode(progress),
                           let json = String(data: data, encoding: .utf8) {
                            try? await writer.write(.buffer(.init(string: "data: \(json)\n\n")))
                        }
                    }
                )
                try await writer.write(.buffer(.init(string: "data: {\"done\":true}\n\n")))
            } catch {
                let errorJSON = "{\"error\":\"\(error.localizedDescription)\"}"
                try? await writer.write(.buffer(.init(string: "data: \(errorJSON)\n\n")))
            }
            try await writer.write(.end)
        })

        return response
    }

    @Sendable
    func progress(req: Request) async throws -> APIResponse<SetupProgress> {
        guard let progress = await setupService.getCurrentProgress() else {
            return APIResponse(success: true, data: SetupProgress(step: .connectSSH, status: .pending, message: "No setup in progress"))
        }
        return APIResponse(success: true, data: progress)
    }
}
