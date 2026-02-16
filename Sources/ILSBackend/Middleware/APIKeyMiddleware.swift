import Vapor

/// Authentication middleware that validates API key from the `Authorization: Bearer <key>` header.
///
/// Behavior:
/// - If no API key is configured (environment variable `ILS_API_KEY` not set), all requests pass through (development mode).
/// - If an API key is configured, requests must include a valid `Authorization: Bearer <key>` header.
/// - The `/health` endpoint is always exempt from authentication.
/// - Returns 401 Unauthorized with structured JSON on failure.
struct APIKeyMiddleware: AsyncMiddleware {
    /// The required API key. When `nil`, authentication is disabled (open access).
    private let requiredKey: String?

    init() {
        self.requiredKey = Environment.get("ILS_API_KEY")
    }

    /// Designated initializer for explicit key injection (useful for configuration).
    init(apiKey: String?) {
        self.requiredKey = apiKey
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Development mode: no key configured means open access
        guard let requiredKey = requiredKey, !requiredKey.isEmpty else {
            return try await next.respond(to: request)
        }

        // Health endpoints are always exempt
        if request.url.path.hasPrefix("/health") {
            return try await next.respond(to: request)
        }

        // Extract bearer token from Authorization header
        guard let authHeader = request.headers[.authorization].first else {
            throw Abort(.unauthorized, reason: "Missing Authorization header. Include 'Authorization: Bearer <api-key>'.")
        }

        // Parse "Bearer <token>" format
        let parts = authHeader.split(separator: " ", maxSplits: 1)
        guard parts.count == 2,
              parts[0].lowercased() == "bearer" else {
            throw Abort(.unauthorized, reason: "Invalid Authorization format. Use 'Bearer <api-key>'.")
        }

        let providedKey = String(parts[1])

        // Constant-time comparison to prevent timing attacks
        guard constantTimeEqual(providedKey, requiredKey) else {
            request.logger.warning("Invalid API key attempt from \(request.remoteAddress?.description ?? "unknown")")
            throw Abort(.unauthorized, reason: "Invalid API key.")
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
