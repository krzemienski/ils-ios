import Testing
import XCTVapor
@testable import ILSBackend
@testable import ILSShared

@Suite("Rate Limit Middleware")
struct RateLimitTests {

    // MARK: - Helpers

    /// Creates a test application with RateLimitMiddleware configured with low limits for testing.
    private func makeApp(
        standardLimit: Int = 3,
        elevatedLimit: Int = 2,
        adminLimit: Int = 2,
        chatSendLimit: Int = 1,
        windowSeconds: TimeInterval = 60
    ) async throws -> Application {
        let app = try await Application.make(.testing)

        let storage = RateLimitStorage()
        app.middleware.use(RateLimitMiddleware(
            storage: storage,
            standardLimit: standardLimit,
            elevatedLimit: elevatedLimit,
            adminLimit: adminLimit,
            chatSendLimit: chatSendLimit,
            windowSeconds: windowSeconds
        ))

        // Register a simple route for each group
        app.get("api", "v1", "sessions") { _ in "ok" }
        app.post("api", "v1", "chat", "send") { _ in "ok" }
        app.get("api", "v1", "config") { _ in "ok" }
        app.get("api", "v1", "ssh", "keys") { _ in "ok" }
        app.get("health", "live") { _ in "ok" }

        return app
    }

    // MARK: - Requests within limit succeed with correct X-RateLimit-* headers

    @Test("Requests within limit succeed with X-RateLimit-* headers")
    func requestsWithinLimitSucceed() async throws {
        let app = try await makeApp(standardLimit: 5)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/sessions") { res async in
                #expect(res.status == .ok)
                #expect(res.headers.first(name: "X-RateLimit-Limit") == "5")
                #expect(res.headers.first(name: "X-RateLimit-Remaining") == "4")
                #expect(res.headers.first(name: "X-RateLimit-Group") == "standard")
            }
        }
    }

    @Test("Remaining count decrements on successive requests")
    func remainingCountDecrements() async throws {
        let app = try await makeApp(standardLimit: 3)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            // First request
            try await app.test(.GET, "api/v1/sessions") { res async in
                #expect(res.status == .ok)
                #expect(res.headers.first(name: "X-RateLimit-Remaining") == "2")
            }
            // Second request
            try await app.test(.GET, "api/v1/sessions") { res async in
                #expect(res.status == .ok)
                #expect(res.headers.first(name: "X-RateLimit-Remaining") == "1")
            }
            // Third request (last within limit)
            try await app.test(.GET, "api/v1/sessions") { res async in
                #expect(res.status == .ok)
                #expect(res.headers.first(name: "X-RateLimit-Remaining") == "0")
            }
        }
    }

    // MARK: - Exceeding limit returns 429 with Retry-After and error schema

    @Test("Exceeding limit returns 429 with Retry-After and error body")
    func exceedingLimitReturns429() async throws {
        let app = try await makeApp(standardLimit: 1)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            // First request succeeds
            try await app.test(.GET, "api/v1/sessions") { res async in
                #expect(res.status == .ok)
            }
            // Second request exceeds limit
            try await app.test(.GET, "api/v1/sessions") { res async in
                #expect(res.status == .tooManyRequests)

                // Retry-After header must be present and positive
                let retryAfter = res.headers.first(name: "Retry-After")
                #expect(retryAfter != nil)
                if let value = retryAfter.flatMap(Int.init) {
                    #expect(value > 0)
                }

                // X-RateLimit-Remaining must be 0
                #expect(res.headers.first(name: "X-RateLimit-Remaining") == "0")
                #expect(res.headers.first(name: "X-RateLimit-Limit") == "1")
                #expect(res.headers.first(name: "X-RateLimit-Group") == "standard")

                // Body must follow RateLimitErrorResponse schema
                let data = Data(buffer: res.body)
                let decoded = try? JSONDecoder().decode(RateLimitErrorResponse.self, from: data)
                #expect(decoded != nil)
                #expect(decoded?.code == "rate_limit_exceeded")
                #expect(decoded?.retryAfterSeconds ?? 0 > 0)
                #expect(decoded?.tier == "standard")
            }
        }
    }

    // MARK: - Different endpoint groups have different limits

    @Test("Different endpoint groups have independent rate limits")
    func differentGroupsHaveIndependentLimits() async throws {
        let app = try await makeApp(standardLimit: 1, adminLimit: 1)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            // Exhaust standard limit
            try await app.test(.GET, "api/v1/sessions") { res async in
                #expect(res.status == .ok)
            }
            try await app.test(.GET, "api/v1/sessions") { res async in
                #expect(res.status == .tooManyRequests)
            }

            // Admin endpoint should still work (different group)
            try await app.test(.GET, "api/v1/config") { res async in
                #expect(res.status == .ok)
                #expect(res.headers.first(name: "X-RateLimit-Group") == "admin")
            }
        }
    }

    @Test("Chat send group is reported correctly")
    func chatSendGroupReported() async throws {
        let app = try await makeApp(chatSendLimit: 2)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.POST, "api/v1/chat/send") { res async in
                #expect(res.status == .ok)
                #expect(res.headers.first(name: "X-RateLimit-Group") == "chat_send")
                #expect(res.headers.first(name: "X-RateLimit-Limit") == "2")
            }
        }
    }

    @Test("Elevated endpoint group uses elevated limit")
    func elevatedGroupLimit() async throws {
        let app = try await makeApp(elevatedLimit: 1)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/ssh/keys") { res async in
                #expect(res.status == .ok)
                #expect(res.headers.first(name: "X-RateLimit-Group") == "elevated")
                #expect(res.headers.first(name: "X-RateLimit-Limit") == "1")
            }
            // Exceeding elevated limit
            try await app.test(.GET, "api/v1/ssh/keys") { res async in
                #expect(res.status == .tooManyRequests)
            }
        }
    }

    // MARK: - Rate limit state is per-IP

    @Test("Rate limit state is per-IP via X-Forwarded-For")
    func perIPRateLimiting() async throws {
        let app = try await makeApp(standardLimit: 1)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            // First IP exhausts its limit
            try await app.test(.GET, "api/v1/sessions", headers: ["X-Forwarded-For": "10.0.0.1"]) { res async in
                #expect(res.status == .ok)
            }
            try await app.test(.GET, "api/v1/sessions", headers: ["X-Forwarded-For": "10.0.0.1"]) { res async in
                #expect(res.status == .tooManyRequests)
            }

            // Different IP should still be allowed
            try await app.test(.GET, "api/v1/sessions", headers: ["X-Forwarded-For": "10.0.0.2"]) { res async in
                #expect(res.status == .ok)
            }
        }
    }

    // MARK: - Health endpoints are exempt

    @Test("Health endpoints are exempt from rate limiting")
    func healthExempt() async throws {
        let app = try await makeApp(standardLimit: 1)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            // Multiple health requests should all succeed
            for _ in 0..<5 {
                try await app.test(.GET, "health/live") { res async in
                    #expect(res.status == .ok)
                    // Health responses should NOT have rate limit headers
                    #expect(res.headers.first(name: "X-RateLimit-Limit") == nil)
                }
            }
        }
    }

    // MARK: - RateLimitGroup resolution

    @Test("RateLimitGroup resolves standard for general endpoints")
    func groupResolvesStandard() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let request = Request(application: app, method: .GET, url: "/api/v1/sessions", on: app.eventLoopGroup.next())
        let group = RateLimitGroup.resolve(for: request)
        #expect(group == .standard)
    }

    @Test("RateLimitGroup resolves chatSend for POST to /api/v1/chat/")
    func groupResolvesChatSend() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let request = Request(application: app, method: .POST, url: "/api/v1/chat/send", on: app.eventLoopGroup.next())
        let group = RateLimitGroup.resolve(for: request)
        #expect(group == .chatSend)
    }

    @Test("RateLimitGroup resolves admin for config endpoints")
    func groupResolvesAdmin() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let request = Request(application: app, method: .GET, url: "/api/v1/config/profiles", on: app.eventLoopGroup.next())
        let group = RateLimitGroup.resolve(for: request)
        #expect(group == .admin)
    }

    @Test("RateLimitGroup resolves elevated for SSH endpoints")
    func groupResolvesElevated() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let request = Request(application: app, method: .GET, url: "/api/v1/ssh/keys", on: app.eventLoopGroup.next())
        let group = RateLimitGroup.resolve(for: request)
        #expect(group == .elevated)
    }

    @Test("RateLimitGroup resolves health for /health paths")
    func groupResolvesHealth() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        let request = Request(application: app, method: .GET, url: "/health/live", on: app.eventLoopGroup.next())
        let group = RateLimitGroup.resolve(for: request)
        #expect(group == .health)
    }
}
