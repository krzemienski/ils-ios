import Vapor

/// Middleware that enforces admin-level authorization on sensitive routes.
///
/// Checks for an `X-Admin-Token` header matching the `ILS_ADMIN_KEY` environment variable.
/// When no admin key is configured (development mode), all requests pass through — mirroring
/// the open-access pattern used by `APIKeyMiddleware`.
///
/// ## Usage
/// ```swift
/// let admin = api.grouped(AdminMiddleware())
/// try admin.register(collection: ConfigController(...))
/// ```
struct AdminMiddleware: AsyncMiddleware {
    /// The required admin key. When `nil`, admin authorization is disabled (open access).
    private let adminKey: String?

    init() {
        self.adminKey = Environment.get("ILS_ADMIN_KEY")
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Development mode: no admin key configured means open access
        guard let adminKey = adminKey, !adminKey.isEmpty else {
            return try await next.respond(to: request)
        }

        guard let providedKey = request.headers.first(name: "X-Admin-Token") else {
            throw Abort(.forbidden, reason: "Admin access required. Include 'X-Admin-Token' header.")
        }

        guard constantTimeEqual(providedKey, adminKey) else {
            request.logger.warning("Invalid admin token attempt from \(request.remoteAddress?.description ?? "unknown")")
            throw Abort(.forbidden, reason: "Invalid admin token.")
        }

        return try await next.respond(to: request)
    }

    /// Constant-time string comparison to prevent timing side-channel attacks.
    private func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)

        guard aBytes.count == bBytes.count else { return false }

        var result: UInt8 = 0
        for i in 0..<aBytes.count {
            result |= aBytes[i] ^ bBytes[i]
        }
        return result == 0
    }
}
