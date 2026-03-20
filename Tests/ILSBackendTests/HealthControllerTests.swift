import Testing
import XCTVapor
@testable import ILSBackend

@Suite("Health Controller")
struct HealthControllerTests {

    @Test("GET /health/live returns 200 with alive status")
    func liveEndpointReturns200() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        // Register only the HealthController (no DB needed for /health/live)
        try app.register(collection: HealthController())

        // Suppress XCTVapor swift-testing context warning (app.testing() not available in this Vapor version)
        try await XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try await app.test(.GET, "health/live") { res async in
                #expect(res.status == .ok)

                let data = Data(buffer: res.body)
                let decoded = try? JSONDecoder().decode(LiveResponse.self, from: data)
                #expect(decoded?.status == "alive")
            }
        }
    }

    @Test("LiveResponse Codable round-trip")
    func liveResponseCodable() throws {
        let response = LiveResponse(status: "alive")
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(LiveResponse.self, from: data)
        #expect(decoded.status == "alive")
    }

    @Test("ReadyResponse Codable round-trip")
    func readyResponseCodable() throws {
        let response = ReadyResponse(status: "ready")
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ReadyResponse.self, from: data)
        #expect(decoded.status == "ready")
    }

    @Test("HealthDetail Codable round-trip")
    func healthDetailCodable() throws {
        let detail = HealthDetail(
            status: "healthy",
            uptime: 3600,
            version: "1.0.0",
            checks: HealthChecks(database: "ok", filesystem: "ok", claudeCLI: "ok"),
            disk: DiskInfo(totalGB: 500.0, freeGB: 200.0, usedPercent: 60.0)
        )
        let data = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(HealthDetail.self, from: data)

        #expect(decoded.status == "healthy")
        #expect(decoded.uptime == 3600)
        #expect(decoded.version == "1.0.0")
        #expect(decoded.checks.database == "ok")
        #expect(decoded.checks.filesystem == "ok")
        #expect(decoded.disk?.totalGB == 500.0)
        #expect(decoded.disk?.freeGB == 200.0)
        #expect(decoded.disk?.usedPercent == 60.0)
    }

    @Test("HealthDetail Codable with nil disk")
    func healthDetailNilDisk() throws {
        let detail = HealthDetail(
            status: "degraded",
            uptime: 60,
            version: "1.0.0",
            checks: HealthChecks(database: "error", filesystem: "ok", claudeCLI: "ok"),
            disk: nil
        )
        let data = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(HealthDetail.self, from: data)

        #expect(decoded.status == "degraded")
        #expect(decoded.disk == nil)
        #expect(decoded.checks.database == "error")
    }
}
