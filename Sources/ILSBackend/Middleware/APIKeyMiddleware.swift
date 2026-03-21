import Vapor
import ILSShared

/// Storage key for the resolved authorization level attached by `APIKeyMiddleware`.
///
/// Downstream middleware (e.g., `AuthorizationMiddleware`) and controllers can read
/// `request.storage[AuthLevelKey.self]` to determine the caller's access scope.
struct AuthLevelKey: StorageKey {
    typealias Value = AuthorizationLevel
}

/// Authentication middleware that validates API key from the `Authorization: Bearer <key>` header.
///
/// Behavior:
/// - If no API key is configured (no master key loaded), all requests pass through (development mode).
/// - If an API key is configured, requests must include a valid `Authorization: Bearer <key>` header.
/// - The token is validated against the master key (admin), scoped tokens (read/write/admin),
///   and during rotation, the old key and its scoped tokens.
/// - The resolved `AuthorizationLevel` is stored in `request.storage[AuthLevelKey.self]` for downstream use.
/// - The `/health` endpoint is always exempt from authentication.
/// - Returns 401 Unauthorized with structured JSON on failure.
/// - Failed authentication attempts are logged with source IP, path, and failure reason.
struct APIKeyMiddleware: AsyncMiddleware {
    /// The API key storage service for token validation.
    private let storageService: APIKeyStorageService

    /// Legacy: The required API key for simple string comparison (backward compatibility).
    private let legacyKey: String?

    /// Creates middleware backed by the `APIKeyStorageService` actor for scoped token validation.
    init(storageService: APIKeyStorageService) {
        self.storageService = storageService
        self.legacyKey = nil
    }

    /// Legacy initializer for explicit key injection (backward compatibility with configure.swift).
    init(apiKey: String?) {
        self.legacyKey = apiKey
        self.storageService = APIKeyStorageService.shared
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Determine if authentication is required.
        let currentKey = await storageService.currentKey()
        let hasKey = legacyKey != nil || currentKey != nil

        // Development mode: no key configured means open access.
        guard hasKey else {
            // Grant admin access in dev mode so downstream authorization checks pass.
            request.storage[AuthLevelKey.self] = .admin
            return try await next.respond(to: request)
        }

        // Health endpoints are always exempt.
        if request.url.path.hasPrefix("/health") {
            return try await next.respond(to: request)
        }

        // Extract bearer token from Authorization header.
        guard let authHeader = request.headers[.authorization].first else {
            logFailedAttempt(request: request, reason: "Missing Authorization header")
            // Report auth failure to AbuseDetectionService
            if let abuseService = request.application.storage[AbuseDetectionServiceKey.self] {
                let ip = request.peerAddress?.ipAddress ?? request.remoteAddress?.ipAddress ?? "unknown"
                await abuseService.recordAuthFailure(
                    ip: ip,
                    path: request.url.path,
                    reason: "missing_authorization_header",
                    logger: request.logger
                )
            }
            throw Abort(.unauthorized, reason: "Missing Authorization header. Include 'Authorization: Bearer <api-key>'.")
        }

        // Parse "Bearer <token>" format.
        let parts = authHeader.split(separator: " ", maxSplits: 1)
        guard parts.count == 2,
              parts[0].lowercased() == "bearer" else {
            logFailedAttempt(request: request, reason: "Invalid Authorization format")
            throw Abort(.unauthorized, reason: "Invalid Authorization format. Use 'Bearer <api-key>'.")
        }

        let providedToken = String(parts[1])

        // Validate via the storage service (supports master key, scoped tokens, and rotation).
        if let level = await storageService.validateToken(providedToken) {
            request.storage[AuthLevelKey.self] = level
            return try await next.respond(to: request)
        }

        // Fallback: legacy string comparison against the injected key (admin level).
        if let key = legacyKey, !key.isEmpty, constantTimeEqual(providedToken, key) {
            request.storage[AuthLevelKey.self] = .admin
            return try await next.respond(to: request)
        }

        // Token is invalid.
        logFailedAttempt(request: request, reason: "Invalid API key or scoped token")
        throw Abort(.unauthorized, reason: "Invalid API key.")
    }

    // MARK: - Logging

    /// Log a failed authentication attempt with source IP and request path.
    private func logFailedAttempt(request: Request, reason: String) {
        let sourceIP = resolveSourceIP(request: request)
        let path = "\(request.method.rawValue) \(request.url.path)"
        request.logger.warning(
            "Auth failed: \(reason) | ip=\(sourceIP) path=\(path)"
        )
    }

    /// Resolve the client's source IP, preferring `X-Forwarded-For` for proxied requests.
    private func resolveSourceIP(request: Request) -> String {
        // X-Forwarded-For may contain multiple IPs; the first is the original client.
        if let forwarded = request.headers.first(name: "X-Forwarded-For") {
            let firstIP = forwarded.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) }
            if let ip = firstIP, !ip.isEmpty {
                return ip
            }
        }
        return request.remoteAddress?.description ?? "unknown"
    }

    // MARK: - Helpers

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
