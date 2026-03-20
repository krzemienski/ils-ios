import Testing
import XCTVapor
@testable import ILSBackend

/// Tests proving deny-by-default security policy across all tiers:
/// - Public (health): always accessible
/// - Standard: requires valid API key when ILS_API_KEY is set
/// - Elevated: requires auth when network-exposed (LAN or tunnel)
/// - Admin: always requires X-Admin-Token when ILS_ADMIN_KEY is set
@Suite("Security Policy — Deny by Default", .serialized)
struct SecurityPolicyTests {

    /// Clean all security-related env vars to prevent cross-test leakage.
    private func cleanEnv() {
        unsetenv("ILS_API_KEY")
        unsetenv("ILS_ADMIN_KEY")
        unsetenv("ILS_LAN_ENABLED")
    }

    // MARK: - Health Endpoints Always Accessible

    @Test("GET /health/live is accessible without any authentication")
    func healthLiveAlwaysAccessible() async throws {
        cleanEnv()
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        try app.register(collection: HealthController())
        app.middleware.use(APIKeyMiddleware(apiKey: "test-api-key-12345"))

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "health/live") { res async in
                #expect(res.status == .ok)
            }
        }
    }

    @Test("GET /health/live is accessible when ILS_API_KEY is set globally")
    func healthBypassesAPIKeyMiddleware() async throws {
        cleanEnv()
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        try app.register(collection: HealthController())
        app.middleware.use(APIKeyMiddleware(apiKey: "super-secret-key-99"))

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "health/live") { res async in
                #expect(res.status == .ok)

                let data = Data(buffer: res.body)
                let decoded = try? JSONDecoder().decode(LiveResponse.self, from: data)
                #expect(decoded?.status == "alive")
            }
        }
    }

    // MARK: - APIKeyMiddleware Deny-by-Default (Standard Tier)

    @Test("Standard endpoint returns 401 when ILS_API_KEY is set but no token provided")
    func standardEndpointDeniedWithoutToken() async throws {
        cleanEnv()
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        app.middleware.use(APIKeyMiddleware(apiKey: "test-api-key-12345"))
        app.get("api", "v1", "sessions", "test") { _ in "ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/sessions/test") { res async in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test("Standard endpoint returns 401 with invalid Bearer token")
    func standardEndpointDeniedWithInvalidToken() async throws {
        cleanEnv()
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        app.middleware.use(APIKeyMiddleware(apiKey: "correct-key-abc123"))
        app.get("api", "v1", "sessions", "test") { _ in "ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/sessions/test", headers: [
                "Authorization": "Bearer wrong-key-xyz789"
            ]) { res async in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test("Standard endpoint passes with valid Bearer token")
    func standardEndpointPassesWithValidToken() async throws {
        cleanEnv()
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let validKey = "correct-key-abc123"
        app.middleware.use(APIKeyMiddleware(apiKey: validKey))
        app.get("api", "v1", "sessions", "test") { _ in "ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/sessions/test", headers: [
                "Authorization": "Bearer \(validKey)"
            ]) { res async in
                #expect(res.status == .ok)
            }
        }
    }

    @Test("Standard endpoint passes when no ILS_API_KEY is configured (dev mode)")
    func standardEndpointOpenAccessDevMode() async throws {
        cleanEnv()
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        app.middleware.use(APIKeyMiddleware(apiKey: nil))
        app.get("api", "v1", "sessions", "test") { _ in "ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/sessions/test") { res async in
                #expect(res.status == .ok)
            }
        }
    }

    // MARK: - AdminMiddleware Deny-by-Default (Admin Tier)

    @Test("Admin endpoint returns 403 when ILS_ADMIN_KEY is set but no X-Admin-Token provided")
    func adminEndpointDeniedWithoutToken() async throws {
        cleanEnv()
        setenv("ILS_ADMIN_KEY", "admin-secret-key-456", 1)
        defer { unsetenv("ILS_ADMIN_KEY") }

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let admin = app.grouped(AdminMiddleware())
        admin.get("api", "v1", "config", "test") { _ in "admin-ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/config/test") { res async in
                #expect(res.status == .forbidden)
            }
        }
    }

    @Test("Admin endpoint returns 403 with invalid X-Admin-Token")
    func adminEndpointDeniedWithInvalidToken() async throws {
        cleanEnv()
        setenv("ILS_ADMIN_KEY", "admin-secret-key-456", 1)
        defer { unsetenv("ILS_ADMIN_KEY") }

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let admin = app.grouped(AdminMiddleware())
        admin.get("api", "v1", "config", "test") { _ in "admin-ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/config/test", headers: [
                "X-Admin-Token": "wrong-admin-key"
            ]) { res async in
                #expect(res.status == .forbidden)
            }
        }
    }

    @Test("Admin endpoint passes with valid X-Admin-Token")
    func adminEndpointPassesWithValidToken() async throws {
        cleanEnv()
        let adminKey = "admin-secret-key-456"
        setenv("ILS_ADMIN_KEY", adminKey, 1)
        defer { unsetenv("ILS_ADMIN_KEY") }

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let admin = app.grouped(AdminMiddleware())
        admin.get("api", "v1", "config", "test") { _ in "admin-ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/config/test", headers: [
                "X-Admin-Token": adminKey
            ]) { res async in
                #expect(res.status == .ok)
            }
        }
    }

    @Test("Admin endpoint passes when no ILS_ADMIN_KEY is configured (dev mode)")
    func adminEndpointOpenAccessDevMode() async throws {
        cleanEnv()

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let admin = app.grouped(AdminMiddleware())
        admin.get("api", "v1", "config", "test") { _ in "admin-ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/config/test") { res async in
                #expect(res.status == .ok)
            }
        }
    }

    // MARK: - SecurityPolicyMiddleware — Elevated Tier

    @Test("Elevated endpoint returns 403 when network-exposed with API key set but no token")
    func elevatedEndpointDeniedWhenNetworkExposed() async throws {
        cleanEnv()
        setenv("ILS_API_KEY", "elevated-api-key-789", 1)
        setenv("ILS_LAN_ENABLED", "true", 1)
        defer { cleanEnv() }

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let elevated = app.grouped(SecurityPolicyMiddleware())
        elevated.get("api", "v1", "ssh", "test") { _ in "elevated-ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/ssh/test") { res async in
                #expect(res.status == .forbidden)
            }
        }
    }

    @Test("Elevated endpoint passes with valid Bearer token when network-exposed")
    func elevatedEndpointPassesWithValidTokenNetworkExposed() async throws {
        cleanEnv()
        let apiKey = "elevated-api-key-789"
        setenv("ILS_API_KEY", apiKey, 1)
        setenv("ILS_LAN_ENABLED", "true", 1)
        defer { cleanEnv() }

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let elevated = app.grouped(SecurityPolicyMiddleware())
        elevated.get("api", "v1", "ssh", "test") { _ in "elevated-ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/ssh/test", headers: [
                "Authorization": "Bearer \(apiKey)"
            ]) { res async in
                #expect(res.status == .ok)
            }
        }
    }

    @Test("Elevated endpoint passes with valid X-Admin-Token when network-exposed")
    func elevatedEndpointPassesWithAdminTokenNetworkExposed() async throws {
        cleanEnv()
        let adminKey = "admin-key-for-elevated"
        setenv("ILS_ADMIN_KEY", adminKey, 1)
        setenv("ILS_LAN_ENABLED", "true", 1)
        defer { cleanEnv() }

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let elevated = app.grouped(SecurityPolicyMiddleware())
        elevated.get("api", "v1", "terminal", "test") { _ in "elevated-ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/terminal/test", headers: [
                "X-Admin-Token": adminKey
            ]) { res async in
                #expect(res.status == .ok)
            }
        }
    }

    @Test("Elevated endpoint passes without token when not network-exposed (localhost dev)")
    func elevatedEndpointOpenAccessLocalhost() async throws {
        cleanEnv()
        setenv("ILS_API_KEY", "some-key", 1)
        // ILS_LAN_ENABLED is NOT set — localhost-only mode
        defer { cleanEnv() }

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let elevated = app.grouped(SecurityPolicyMiddleware())
        elevated.get("api", "v1", "ssh", "test") { _ in "elevated-ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/ssh/test") { res async in
                // Not network-exposed, so elevated tier passes through
                #expect(res.status == .ok)
            }
        }
    }

    @Test("Elevated endpoint denied when X-Forwarded-For header present (tunnel-detected)")
    func elevatedEndpointDeniedViaTunnelProxy() async throws {
        cleanEnv()
        setenv("ILS_API_KEY", "tunnel-api-key", 1)
        // ILS_LAN_ENABLED is NOT set but tunnel detected via X-Forwarded-For
        defer { cleanEnv() }

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let elevated = app.grouped(SecurityPolicyMiddleware())
        elevated.get("api", "v1", "permissions", "test") { _ in "elevated-ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/permissions/test", headers: [
                "X-Forwarded-For": "203.0.113.50"
            ]) { res async in
                #expect(res.status == .forbidden)
            }
        }
    }

    // MARK: - SecurityPolicyMiddleware — Admin Tier (Fallback Classification)

    @Test("Admin-tier path returns 403 via SecurityPolicyMiddleware when admin key set but missing")
    func adminTierViaSecurityPolicyDenied() async throws {
        cleanEnv()
        setenv("ILS_ADMIN_KEY", "sp-admin-key-999", 1)
        defer { cleanEnv() }

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let secured = app.grouped(SecurityPolicyMiddleware())
        secured.get("api", "v1", "config", "test") { _ in "admin-ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/config/test") { res async in
                #expect(res.status == .forbidden)
            }
        }
    }

    @Test("Admin-tier path passes via SecurityPolicyMiddleware with valid admin token")
    func adminTierViaSecurityPolicyPasses() async throws {
        cleanEnv()
        let adminKey = "sp-admin-key-999"
        setenv("ILS_ADMIN_KEY", adminKey, 1)
        defer { cleanEnv() }

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let secured = app.grouped(SecurityPolicyMiddleware())
        secured.get("api", "v1", "system", "test") { _ in "admin-ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/system/test", headers: [
                "X-Admin-Token": adminKey
            ]) { res async in
                #expect(res.status == .ok)
            }
        }
    }

    // MARK: - SecurityConfigService Tier Classification

    @Test("SecurityConfigService classifies health endpoints as public tier")
    func classifyHealthAsPublic() throws {
        let logger = Logger(label: "test")
        let config = SecurityConfigService(logger: logger)

        #expect(config.securityTier(for: "/health") == .public)
        #expect(config.securityTier(for: "/health/live") == .public)
        #expect(config.securityTier(for: "/health/ready") == .public)
    }

    @Test("SecurityConfigService classifies standard endpoints correctly")
    func classifyStandardEndpoints() throws {
        let logger = Logger(label: "test")
        let config = SecurityConfigService(logger: logger)

        #expect(config.securityTier(for: "/api/v1/sessions") == .standard)
        #expect(config.securityTier(for: "/api/v1/projects") == .standard)
        #expect(config.securityTier(for: "/api/v1/chat") == .standard)
        #expect(config.securityTier(for: "/api/v1/themes") == .standard)
        #expect(config.securityTier(for: "/api/v1/stats") == .standard)
    }

    @Test("SecurityConfigService classifies elevated endpoints correctly")
    func classifyElevatedEndpoints() throws {
        let logger = Logger(label: "test")
        let config = SecurityConfigService(logger: logger)

        #expect(config.securityTier(for: "/api/v1/ssh") == .elevated)
        #expect(config.securityTier(for: "/api/v1/terminal") == .elevated)
        #expect(config.securityTier(for: "/api/v1/permissions") == .elevated)
        #expect(config.securityTier(for: "/api/v1/automation") == .elevated)
        #expect(config.securityTier(for: "/api/v1/agent-queue") == .elevated)
        #expect(config.securityTier(for: "/api/v1/process") == .elevated)
    }

    @Test("SecurityConfigService classifies admin endpoints correctly")
    func classifyAdminEndpoints() throws {
        let logger = Logger(label: "test")
        let config = SecurityConfigService(logger: logger)

        #expect(config.securityTier(for: "/api/v1/config") == .admin)
        #expect(config.securityTier(for: "/api/v1/system") == .admin)
        #expect(config.securityTier(for: "/api/v1/tunnel") == .admin)
        #expect(config.securityTier(for: "/api/v1/erasure") == .admin)
    }

    @Test("SecurityConfigService defaults unknown API paths to standard tier")
    func classifyUnknownPathsAsStandard() throws {
        let logger = Logger(label: "test")
        let config = SecurityConfigService(logger: logger)

        #expect(config.securityTier(for: "/api/v1/unknown-endpoint") == .standard)
        #expect(config.securityTier(for: "/api/v1/some/nested/path") == .standard)
    }

    @Test("SecurityConfigService classifies root and non-API paths as public")
    func classifyNonAPIPaths() throws {
        let logger = Logger(label: "test")
        let config = SecurityConfigService(logger: logger)

        #expect(config.securityTier(for: "/") == .public)
        #expect(config.securityTier(for: "") == .public)
        #expect(config.securityTier(for: "/static/style.css") == .public)
    }

    // MARK: - Combined Middleware Stack

    @Test("Standard endpoint behind APIKeyMiddleware denies then accepts correctly")
    func combinedMiddlewareStackDeniesStandard() async throws {
        cleanEnv()
        let apiKey = "combined-test-key"

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        app.middleware.use(APIKeyMiddleware(apiKey: apiKey))
        app.get("api", "v1", "projects", "test") { _ in "ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            // No auth header → denied by APIKeyMiddleware
            try await app.test(.GET, "api/v1/projects/test") { res async in
                #expect(res.status == .unauthorized)
            }

            // Valid auth header → passes
            try await app.test(.GET, "api/v1/projects/test", headers: [
                "Authorization": "Bearer \(apiKey)"
            ]) { res async in
                #expect(res.status == .ok)
            }
        }
    }

    @Test("Authorization header format must be 'Bearer <token>'")
    func authHeaderFormatValidation() async throws {
        cleanEnv()
        let apiKey = "format-test-key"

        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        app.middleware.use(APIKeyMiddleware(apiKey: apiKey))
        app.get("api", "v1", "test") { _ in "ok" }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            // Missing "Bearer" prefix
            try await app.test(.GET, "api/v1/test", headers: [
                "Authorization": apiKey
            ]) { res async in
                #expect(res.status == .unauthorized)
            }

            // Wrong auth scheme
            try await app.test(.GET, "api/v1/test", headers: [
                "Authorization": "Basic \(apiKey)"
            ]) { res async in
                #expect(res.status == .unauthorized)
            }
        }
    }
}
