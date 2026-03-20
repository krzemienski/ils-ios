import Vapor
import ILSShared

/// Middleware that enforces endpoint-level authorization based on security tiers.
///
/// Classifies each request by its endpoint security tier (via `SecurityConfigService`)
/// and enforces the corresponding policy:
/// - **public/standard**: Pass through (handled by global `APIKeyMiddleware`).
/// - **elevated**: Require valid `Authorization: Bearer <key>` or `X-Admin-Token` when
///   the backend is network-exposed (`ILS_LAN_ENABLED=true`) or a tunnel is active.
/// - **admin**: Always require valid `X-Admin-Token` (delegates to `AdminMiddleware` via route grouping).
///
/// When no API key or admin key is configured (development/local mode), all requests
/// pass through — preserving the open-access development experience.
///
/// ## Usage
/// ```swift
/// let elevated = api.grouped(SecurityPolicyMiddleware())
/// try elevated.register(collection: SSHController())
/// ```
struct SecurityPolicyMiddleware: AsyncMiddleware {
    /// The required API key for Bearer token validation.
    private let requiredAPIKey: String?

    /// The required admin key for X-Admin-Token validation.
    private let requiredAdminKey: String?

    /// Whether LAN mode is enabled (network-exposed).
    private let lanEnabled: Bool

    init() {
        self.requiredAPIKey = Environment.get("ILS_API_KEY")
        self.requiredAdminKey = Environment.get("ILS_ADMIN_KEY")
        self.lanEnabled = Environment.get("ILS_LAN_ENABLED") == "true"
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Determine the security tier for this endpoint
        let path = request.url.path
        let tier = classifyTier(for: path, using: request.application)

        switch tier {
        case .public, .standard:
            // Public and standard tiers are handled by global APIKeyMiddleware
            return try await next.respond(to: request)

        case .elevated:
            // Elevated endpoints require auth when network-exposed
            guard isNetworkExposed(request: request) else {
                // Localhost-only mode: pass through (development)
                return try await next.respond(to: request)
            }
            try validateAuthentication(request: request)
            return try await next.respond(to: request)

        case .admin:
            // Admin tier always requires authentication
            try validateAdminAuthentication(request: request)
            return try await next.respond(to: request)
        }
    }

    // MARK: - Private Helpers

    /// Classify the request path to a security tier using SecurityConfigService if available.
    private func classifyTier(for path: String, using app: Application) -> SecurityTier {
        if let configService = app.storage[SecurityConfigServiceKey.self] {
            return configService.securityTier(for: path)
        }

        // Fallback classification when SecurityConfigService is not registered
        let elevatedPrefixes = [
            "/api/v1/ssh", "/api/v1/terminal", "/api/v1/permissions",
            "/api/v1/automation", "/api/v1/agent-queue", "/api/v1/process"
        ]
        let adminPrefixes = [
            "/api/v1/config", "/api/v1/system", "/api/v1/tunnel", "/api/v1/erasure"
        ]

        for prefix in adminPrefixes where path.hasPrefix(prefix) {
            return .admin
        }
        for prefix in elevatedPrefixes where path.hasPrefix(prefix) {
            return .elevated
        }

        return .standard
    }

    /// Determine whether the backend is network-exposed (LAN enabled or tunnel active).
    private func isNetworkExposed(request: Request) -> Bool {
        if lanEnabled {
            return true
        }

        // Check for tunnel activity via X-Forwarded-For or similar proxy headers
        if request.headers.first(name: "X-Forwarded-For") != nil {
            return true
        }

        return false
    }

    /// Validate that the request carries a valid Bearer token or Admin token.
    ///
    /// For elevated endpoints, either authentication method is accepted.
    /// Throws 403 if neither is provided or valid.
    private func validateAuthentication(request: Request) throws {
        // If no keys are configured at all, allow through (no auth to enforce)
        guard hasAnyKeyConfigured() else {
            return
        }

        // Try Bearer token first
        if let authHeader = request.headers[.authorization].first {
            let parts = authHeader.split(separator: " ", maxSplits: 1)
            if parts.count == 2,
               parts[0].lowercased() == "bearer",
               let apiKey = requiredAPIKey,
               !apiKey.isEmpty,
               constantTimeEqual(String(parts[1]), apiKey) {
                return
            }
        }

        // Try Admin token
        if let adminToken = request.headers.first(name: "X-Admin-Token"),
           let adminKey = requiredAdminKey,
           !adminKey.isEmpty,
           constantTimeEqual(adminToken, adminKey) {
            return
        }

        // Neither valid auth method provided
        request.logger.warning("Security policy denied access to elevated endpoint \(request.url.path) from \(request.remoteAddress?.description ?? "unknown")")
        throw Abort(.forbidden, reason: "Access denied. This endpoint requires authentication when the server is network-exposed. Provide a valid 'Authorization: Bearer <api-key>' or 'X-Admin-Token' header.")
    }

    /// Validate admin-level authentication (X-Admin-Token only).
    ///
    /// Throws 403 if no valid admin token is provided.
    private func validateAdminAuthentication(request: Request) throws {
        // No admin key configured means open access (development mode)
        guard let adminKey = requiredAdminKey, !adminKey.isEmpty else {
            return
        }

        guard let providedKey = request.headers.first(name: "X-Admin-Token") else {
            throw Abort(.forbidden, reason: "Admin access required. Include 'X-Admin-Token' header.")
        }

        guard constantTimeEqual(providedKey, adminKey) else {
            request.logger.warning("Security policy denied admin access to \(request.url.path) from \(request.remoteAddress?.description ?? "unknown")")
            throw Abort(.forbidden, reason: "Invalid admin token.")
        }
    }

    /// Whether any authentication key is configured.
    private func hasAnyKeyConfigured() -> Bool {
        if let apiKey = requiredAPIKey, !apiKey.isEmpty {
            return true
        }
        if let adminKey = requiredAdminKey, !adminKey.isEmpty {
            return true
        }
        return false
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
