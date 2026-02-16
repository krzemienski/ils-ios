import Vapor

/// Middleware that logs every HTTP request with method, path, status code, and duration.
///
/// Logging levels:
/// - `.info` for 2xx/3xx responses
/// - `.warning` for 4xx responses
/// - `.error` for 5xx responses
///
/// Sensitive data (Authorization headers, request bodies) is never logged.
struct RequestLoggingMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let start = DispatchTime.now()

        let response: Response
        do {
            response = try await next.respond(to: request)
        } catch {
            let duration = durationMs(from: start)
            let status: UInt = (error as? Abort)?.status.code ?? 500
            logRequest(
                logger: request.logger,
                method: request.method.string,
                path: request.url.path,
                status: status,
                durationMs: duration
            )
            throw error
        }

        let duration = durationMs(from: start)
        logRequest(
            logger: request.logger,
            method: request.method.string,
            path: request.url.path,
            status: UInt(response.status.code),
            durationMs: duration
        )

        return response
    }

    private func durationMs(from start: DispatchTime) -> Double {
        let end = DispatchTime.now()
        let nanos = end.uptimeNanoseconds - start.uptimeNanoseconds
        return Double(nanos) / 1_000_000
    }

    private func logRequest(
        logger: Logger,
        method: String,
        path: String,
        status: UInt,
        durationMs: Double
    ) {
        let message = "\(method) \(path) \(status) \(String(format: "%.1f", durationMs))ms"

        switch status {
        case 500...:
            logger.error("\(message)")
        case 400..<500:
            logger.warning("\(message)")
        default:
            logger.info("\(message)")
        }
    }
}
