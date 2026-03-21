import Vapor
import ILSShared

/// Middleware that enforces a minimum authorization level on a route group.
///
/// Reads the `AuthorizationLevel` stored by `APIKeyMiddleware` in
/// `request.storage[AuthLevelKey.self]` and rejects requests that do not meet
/// the required level with a 403 Forbidden response.
///
/// ## Usage
/// ```swift
/// let readRoutes = api.grouped(AuthorizationMiddleware(minimumLevel: .read))
/// let writeRoutes = api.grouped(AuthorizationMiddleware(minimumLevel: .write))
/// let adminRoutes = api.grouped(AuthorizationMiddleware(minimumLevel: .admin))
/// ```
struct AuthorizationMiddleware: AsyncMiddleware {
    /// The minimum authorization level required for routes protected by this middleware.
    private let minimumLevel: AuthorizationLevel

    /// Creates middleware that enforces the specified minimum authorization level.
    /// - Parameter minimumLevel: The lowest `AuthorizationLevel` that is permitted.
    init(minimumLevel: AuthorizationLevel) {
        self.minimumLevel = minimumLevel
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let resolvedLevel = request.storage[AuthLevelKey.self] else {
            request.logger.warning(
                "Authorization check failed: no auth level resolved | path=\(request.method.rawValue) \(request.url.path)"
            )
            throw Abort(.forbidden, reason: "Access denied. No authentication credentials resolved.")
        }

        guard resolvedLevel.satisfies(minimumLevel) else {
            request.logger.warning(
                "Insufficient authorization: required=\(minimumLevel.rawValue) resolved=\(resolvedLevel.rawValue) | path=\(request.method.rawValue) \(request.url.path)"
            )
            throw Abort(
                .forbidden,
                reason: "Insufficient authorization. Required: \(minimumLevel.rawValue), granted: \(resolvedLevel.rawValue)."
            )
        }

        return try await next.respond(to: request)
    }
}
