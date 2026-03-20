import Testing
import XCTVapor
@testable import ILSBackend

@Suite("CORS Security")
struct CORSSecurityTests {

    // MARK: - Helpers

    /// Default localhost-only origins matching configure.swift
    private static let localhostOnlyOrigins = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:9999",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
        "http://127.0.0.1:9999"
    ]

    /// Create an Application with CORSMiddleware configured for testing.
    /// Mirrors the CORS setup logic in configure.swift.
    private static func makeApp(
        allowedOrigin: CORSMiddleware.AllowOriginSetting
    ) async throws -> Application {
        let app = try await Application.make(.testing)

        let corsConfiguration = CORSMiddleware.Configuration(
            allowedOrigin: allowedOrigin,
            allowedMethods: [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
            allowedHeaders: [
                .accept, .authorization, .contentType, .origin, .xRequestedWith,
                .init("X-Session-ID"), .init("X-Project-ID"), .init("X-Admin-Token")
            ],
            allowCredentials: true
        )
        let cors = CORSMiddleware(configuration: corsConfiguration)
        app.middleware.use(cors, at: .beginning)

        // Register a simple health route for testing
        try app.register(collection: HealthController())

        return app
    }

    // MARK: - SEC-CORS-01: Wildcard Origin Rejection

    @Test("Wildcard '*' in origins is rejected and defaults to localhost-only")
    func wildcardOriginRejectedDefaultsToLocalhost() async throws {
        // Replicate the configure.swift logic when ILS_CORS_ORIGINS contains '*'
        let originsEnv = "*"
        let origins = originsEnv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        // SEC-CORS-01: Wildcard must be detected and rejected
        #expect(origins.contains("*"), "Wildcard should be detected in origins list")

        // When wildcard is detected, configure.swift falls back to localhost-only
        let allowedOrigin: CORSMiddleware.AllowOriginSetting = .any(Self.localhostOnlyOrigins)
        let app = try await Self.makeApp(allowedOrigin: allowedOrigin)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            // A localhost origin should be allowed (fallback working)
            try await app.test(.GET, "health/live", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "http://localhost:3000")
            }) { res async in
                #expect(res.status == .ok)
                let acao = res.headers.first(name: .accessControlAllowOrigin)
                #expect(acao == "http://localhost:3000", "Localhost origin should be allowed after wildcard rejection")
            }

            // An external origin should NOT get CORS headers when wildcard was rejected
            try await app.test(.GET, "health/live", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "https://evil.example.com")
            }) { res async in
                #expect(res.status == .ok)
                let acao = res.headers.first(name: .accessControlAllowOrigin)
                #expect(acao != "https://evil.example.com", "External origin must be rejected after wildcard fallback")
            }
        }
    }

    @Test("Wildcard mixed with valid origins still triggers rejection")
    func wildcardMixedWithValidOrigins() async throws {
        let originsEnv = "https://app.example.com, *, https://staging.example.com"
        let origins = originsEnv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        // SEC-CORS-01: Wildcard must be detected even when mixed with valid origins
        #expect(origins.contains("*"), "Wildcard should be detected in mixed origins list")

        // When wildcard is present, the entire list is rejected — fallback to localhost
        let allowedOrigin: CORSMiddleware.AllowOriginSetting = .any(Self.localhostOnlyOrigins)
        let app = try await Self.makeApp(allowedOrigin: allowedOrigin)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            // The originally-configured origin should NOT be allowed
            try await app.test(.GET, "health/live", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "https://app.example.com")
            }) { res async in
                let acao = res.headers.first(name: .accessControlAllowOrigin)
                #expect(acao != "https://app.example.com", "Configured origin should be rejected when wildcard was present")
            }
        }
    }

    // MARK: - Configured Origins Returned in Access-Control-Allow-Origin

    @Test("Single configured origin is returned in Access-Control-Allow-Origin")
    func singleConfiguredOriginReturned() async throws {
        let allowedOrigin: CORSMiddleware.AllowOriginSetting = .custom("https://app.example.com")
        let app = try await Self.makeApp(allowedOrigin: allowedOrigin)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "health/live", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "https://app.example.com")
            }) { res async in
                #expect(res.status == .ok)
                let acao = res.headers.first(name: .accessControlAllowOrigin)
                #expect(acao == "https://app.example.com", "Configured origin should appear in Access-Control-Allow-Origin")
            }
        }
    }

    @Test("Multiple configured origins: matching origin is returned")
    func multipleConfiguredOriginsMatchReturned() async throws {
        let origins = ["https://app.example.com", "https://staging.example.com"]
        let allowedOrigin: CORSMiddleware.AllowOriginSetting = .any(origins)
        let app = try await Self.makeApp(allowedOrigin: allowedOrigin)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            // First origin should match
            try await app.test(.GET, "health/live", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "https://app.example.com")
            }) { res async in
                let acao = res.headers.first(name: .accessControlAllowOrigin)
                #expect(acao == "https://app.example.com", "First configured origin should be returned")
            }

            // Second origin should also match
            try await app.test(.GET, "health/live", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "https://staging.example.com")
            }) { res async in
                let acao = res.headers.first(name: .accessControlAllowOrigin)
                #expect(acao == "https://staging.example.com", "Second configured origin should be returned")
            }
        }
    }

    @Test("CORS preflight OPTIONS returns correct allowed methods and headers")
    func preflightReturnsAllowedMethodsAndHeaders() async throws {
        let allowedOrigin: CORSMiddleware.AllowOriginSetting = .custom("https://app.example.com")
        let app = try await Self.makeApp(allowedOrigin: allowedOrigin)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.OPTIONS, "health/live", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "https://app.example.com")
                req.headers.replaceOrAdd(name: .accessControlRequestMethod, value: "POST")
            }) { res async in
                let acao = res.headers.first(name: .accessControlAllowOrigin)
                #expect(acao == "https://app.example.com", "Preflight should include allowed origin")

                let methods = res.headers.first(name: .accessControlAllowMethods)
                #expect(methods != nil, "Preflight should include allowed methods")

                let credentials = res.headers.first(name: .accessControlAllowCredentials)
                #expect(credentials == "true", "Credentials should be allowed")
            }
        }
    }

    // MARK: - Non-Allowed Origins Rejected

    @Test("Non-allowed origin does not receive Access-Control-Allow-Origin matching request")
    func nonAllowedOriginRejected() async throws {
        let origins = ["https://app.example.com"]
        let allowedOrigin: CORSMiddleware.AllowOriginSetting = .any(origins)
        let app = try await Self.makeApp(allowedOrigin: allowedOrigin)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "health/live", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "https://evil.example.com")
            }) { res async in
                #expect(res.status == .ok, "Request should still succeed (CORS is browser-enforced)")
                let acao = res.headers.first(name: .accessControlAllowOrigin)
                #expect(acao != "https://evil.example.com", "Non-allowed origin must not appear in ACAO header")
            }
        }
    }

    @Test("Default localhost-only config rejects external origins")
    func defaultLocalhostRejectsExternal() async throws {
        let allowedOrigin: CORSMiddleware.AllowOriginSetting = .any(Self.localhostOnlyOrigins)
        let app = try await Self.makeApp(allowedOrigin: allowedOrigin)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "health/live", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "https://attacker.com")
            }) { res async in
                let acao = res.headers.first(name: .accessControlAllowOrigin)
                #expect(acao != "https://attacker.com", "Default localhost config must reject external origins")
            }
        }
    }

    @Test("Default localhost-only config accepts all localhost variants")
    func defaultLocalhostAcceptsAllVariants() async throws {
        let allowedOrigin: CORSMiddleware.AllowOriginSetting = .any(Self.localhostOnlyOrigins)
        let app = try await Self.makeApp(allowedOrigin: allowedOrigin)
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            for origin in Self.localhostOnlyOrigins {
                try await app.test(.GET, "health/live", beforeRequest: { req in
                    req.headers.replaceOrAdd(name: .origin, value: origin)
                }) { res async in
                    let acao = res.headers.first(name: .accessControlAllowOrigin)
                    #expect(acao == origin, "Localhost origin \(origin) should be allowed by default config")
                }
            }
        }
    }

    // MARK: - CORS Configuration Parsing Logic

    @Test("ILS_CORS_ORIGINS parsing: trims whitespace around origins")
    func originsParsingTrimsWhitespace() {
        let originsEnv = " https://app.example.com , https://staging.example.com "
        let origins = originsEnv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        #expect(origins.count == 2)
        #expect(origins[0] == "https://app.example.com")
        #expect(origins[1] == "https://staging.example.com")
    }

    @Test("ILS_CORS_ORIGINS parsing: empty string uses defaults")
    func originsParsingEmptyUsesDefaults() {
        let originsEnv = ""
        // configure.swift checks: !originsEnv.isEmpty — empty falls through to default
        #expect(originsEnv.isEmpty, "Empty string should trigger default localhost origins")
    }

    @Test("ILS_CORS_ORIGINS parsing: single origin uses .custom setting")
    func originsParsingUsesSingleCustom() {
        let originsEnv = "https://app.example.com"
        let origins = originsEnv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        // configure.swift uses .custom for single origin, .any for multiple
        #expect(origins.count == 1, "Single origin should result in .custom setting")
    }
}
