import Testing
import XCTVapor
@testable import ILSBackend

@Suite("Request Validation Middleware")
struct RequestValidationTests {

    // MARK: - Helpers

    /// Creates a test application with RequestValidationMiddleware and simple routes.
    private func makeApp() async throws -> Application {
        let app = try await Application.make(.testing)

        app.middleware.use(RequestValidationMiddleware())

        // Routes for testing
        app.post("api", "v1", "sessions") { req -> String in
            return "created"
        }
        app.put("api", "v1", "sessions", "update") { req -> String in
            return "updated"
        }
        app.get("api", "v1", "sessions") { _ in "ok" }
        app.get("health", "live") { _ in "ok" }

        return app
    }

    // MARK: - POST without Content-Type returns 415

    @Test("POST with body but no Content-Type returns 415")
    func postWithoutContentTypeReturns415() async throws {
        let app = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.POST, "api/v1/sessions", beforeRequest: { req async throws in
                // Set a body without Content-Type header
                let body = #"{"name":"test"}"#
                req.body = .init(string: body)
                // Ensure no content-type is set
                req.headers.remove(name: .contentType)
            }) { res async in
                #expect(res.status == .unsupportedMediaType)
            }
        }
    }

    @Test("POST with wrong Content-Type returns 415")
    func postWithWrongContentTypeReturns415() async throws {
        let app = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.POST, "api/v1/sessions", beforeRequest: { req async throws in
                req.headers.contentType = .xml
                let body = "<data>test</data>"
                req.body = .init(string: body)
            }) { res async in
                #expect(res.status == .unsupportedMediaType)
            }
        }
    }

    // MARK: - POST with malformed JSON returns 400

    @Test("POST with malformed JSON body returns 400")
    func postWithMalformedJSONReturns400() async throws {
        let app = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.POST, "api/v1/sessions", beforeRequest: { req async throws in
                req.headers.contentType = .json
                let malformed = #"{invalid json: }"#
                req.body = .init(string: malformed)
            }) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test("POST with valid JSON succeeds")
    func postWithValidJSONSucceeds() async throws {
        let app = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.POST, "api/v1/sessions", beforeRequest: { req async throws in
                req.headers.contentType = .json
                let validJSON = #"{"name":"test"}"#
                req.body = .init(string: validJSON)
            }) { res async in
                #expect(res.status == .ok)
            }
        }
    }

    // MARK: - GET requests bypass content-type checks

    @Test("GET requests succeed without Content-Type header")
    func getBypassesContentTypeCheck() async throws {
        let app = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/sessions") { res async in
                #expect(res.status == .ok)
            }
        }
    }

    @Test("GET requests succeed even with non-JSON Content-Type")
    func getSucceedsWithAnyContentType() async throws {
        let app = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/sessions", headers: ["Content-Type": "text/plain"]) { res async in
                #expect(res.status == .ok)
            }
        }
    }

    // MARK: - PUT also requires Content-Type validation

    @Test("PUT with wrong Content-Type returns 415")
    func putWithWrongContentTypeReturns415() async throws {
        let app = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.PUT, "api/v1/sessions/update", beforeRequest: { req async throws in
                req.headers.contentType = .plainText
                req.body = .init(string: "hello")
            }) { res async in
                #expect(res.status == .unsupportedMediaType)
            }
        }
    }

    // MARK: - Suspicious headers

    @Test("Request with X-Original-URL header is rejected")
    func suspiciousHeaderRejected() async throws {
        let app = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/sessions", headers: ["X-Original-URL": "/admin"]) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }

    // MARK: - Health endpoints exempt

    @Test("Health endpoints bypass validation")
    func healthBypassesValidation() async throws {
        let app = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            // Health endpoint should work even without Content-Type on POST-like scenario
            try await app.test(.GET, "health/live") { res async in
                #expect(res.status == .ok)
            }
        }
    }

    // MARK: - Query string validation

    @Test("Oversized query string is rejected")
    func oversizedQueryStringRejected() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        app.middleware.use(RequestValidationMiddleware(maxQueryStringLength: 50))
        app.get("api", "v1", "sessions") { _ in "ok" }

        let longQuery = String(repeating: "a", count: 51)

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/sessions?\(longQuery)") { res async in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test("Normal query string is accepted")
    func normalQueryStringAccepted() async throws {
        let app = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "api/v1/sessions?page=1&limit=20") { res async in
                #expect(res.status == .ok)
            }
        }
    }

    // MARK: - POST with empty body succeeds (Content-Length: 0)

    @Test("POST with no body passes validation")
    func postWithNoBodyPasses() async throws {
        let app = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.POST, "api/v1/sessions", beforeRequest: { req async throws in
                req.headers.replaceOrAdd(name: .contentLength, value: "0")
            }) { res async in
                // Should not fail validation — empty body is allowed
                #expect(res.status != .unsupportedMediaType)
            }
        }
    }
}
