import Vapor

/// Custom error middleware that returns structured JSON error responses.
///
/// Replaces Vapor's default ErrorMiddleware to ensure all errors
/// return consistent `{error: true, code: "...", reason: "..."}` format.
struct ILSErrorMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch let abort as Abort {
            return errorResponse(
                status: abort.status,
                code: httpStatusToCode(abort.status),
                reason: abort.reason ?? abort.status.reasonPhrase,
                on: request
            )
        } catch let error as DecodingError {
            let reason: String
            switch error {
            case .keyNotFound(let key, _):
                reason = "Missing required field: \(key.stringValue)"
            case .typeMismatch(let type, let context):
                reason = "Type mismatch for \(context.codingPath.map(\.stringValue).joined(separator: ".")): expected \(type)"
            case .valueNotFound(_, let context):
                reason = "Missing value for \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            default:
                reason = "Invalid request body"
            }
            return errorResponse(
                status: .unprocessableEntity,
                code: "VALIDATION_ERROR",
                reason: reason,
                on: request
            )
        } catch {
            request.logger.error("Unhandled error: \(error.localizedDescription)")
            return errorResponse(
                status: .internalServerError,
                code: "INTERNAL_ERROR",
                reason: "Something went wrong. Please try again.",
                on: request
            )
        }
    }

    private func errorResponse(status: HTTPResponseStatus, code: String, reason: String, on request: Request) -> Response {
        let body = ErrorBody(success: false, error: reason, code: code, reason: reason)
        let response = Response(status: status)
        do {
            response.headers.contentType = .json
            try response.content.encode(body)
        } catch {
            request.logger.error("Failed to encode error response: \(error)")
            response.body = .init(string: "{\"success\":false,\"error\":\"Something went wrong.\",\"code\":\"INTERNAL_ERROR\",\"reason\":\"Something went wrong.\"}")
            response.headers.contentType = .json
        }
        return response
    }

    private func httpStatusToCode(_ status: HTTPResponseStatus) -> String {
        switch status {
        case .badRequest: return "BAD_REQUEST"
        case .unauthorized: return "UNAUTHORIZED"
        case .forbidden: return "FORBIDDEN"
        case .notFound: return "NOT_FOUND"
        case .unprocessableEntity: return "VALIDATION_ERROR"
        case .conflict: return "CONFLICT"
        case .tooManyRequests: return "RATE_LIMITED"
        case .serviceUnavailable: return "SERVICE_UNAVAILABLE"
        default:
            if (400..<500).contains(Int(status.code)) {
                return "CLIENT_ERROR"
            }
            return "INTERNAL_ERROR"
        }
    }
}

/// Structured error response body.
///
/// Format: `{ success: false, error: "message", code: "ERROR_CODE" }`
/// Also includes `reason` for backward compatibility.
struct ErrorBody: Content {
    let success: Bool
    let error: String
    let code: String
    let reason: String
}
