import Vapor
import ILSShared

/// Custom error middleware that returns structured JSON error responses.
///
/// Replaces Vapor's default ErrorMiddleware to ensure all errors return an
/// ``APIResponse``-compatible envelope: `{ success: false, data: null, error: { code, message } }`.
struct ILSErrorMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch let abort as Abort {
            return errorResponse(
                status: abort.status,
                code: httpStatusToCode(abort.status),
                message: abort.reason,
                on: request
            )
        } catch let error as DecodingError {
            let message: String
            switch error {
            case .keyNotFound(let key, _):
                message = "Missing required field: \(key.stringValue)"
            case .typeMismatch(let type, let context):
                message = "Type mismatch for \(context.codingPath.map(\.stringValue).joined(separator: ".")): expected \(type)"
            case .valueNotFound(_, let context):
                message = "Missing value for \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            default:
                message = "Invalid request body"
            }
            return errorResponse(
                status: .unprocessableEntity,
                code: "VALIDATION_ERROR",
                message: message,
                on: request
            )
        } catch {
            request.logger.error("Unhandled error: \(error.localizedDescription)")
            return errorResponse(
                status: .internalServerError,
                code: "INTERNAL_ERROR",
                message: "Something went wrong. Please try again.",
                on: request
            )
        }
    }

    private func errorResponse(status: HTTPResponseStatus, code: String, message: String, on request: Request) -> Response {
        let apiError = APIError(code: code, message: message)
        let body = APIResponse<String>(success: false, data: nil, error: apiError)
        let response = Response(status: status)
        do {
            response.headers.contentType = .json
            try response.content.encode(body)
        } catch {
            request.logger.error("Failed to encode error response: \(error)")
            response.body = .init(string: "{\"success\":false,\"data\":null,\"error\":{\"code\":\"INTERNAL_ERROR\",\"message\":\"Something went wrong.\",\"reason\":null}}")
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
        case .payloadTooLarge: return "PAYLOAD_TOO_LARGE"
        case .serviceUnavailable: return "SERVICE_UNAVAILABLE"
        default:
            if (400..<500).contains(Int(status.code)) {
                return "CLIENT_ERROR"
            }
            return "INTERNAL_ERROR"
        }
    }
}
