@testable import ILSBackend
@testable import ILSShared
import XCTVapor
import Fluent

final class AnalyticsControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
        try await app.autoMigrate()
    }

    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
    }

    // Test: Valid event creation returns HTTP 201
    func testCreateEvent_ValidRequest_Returns201Created() async throws {
        try await app.test(.POST, "/api/v1/analytics/events", beforeRequest: { req in
            try req.content.encode([
                "eventName": "test_event",
                "eventData": "{\"key\":\"value\"}",
                "deviceId": "test-device-001"
            ])
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .created)
            let response = try res.content.decode(APIResponse<CreatedResponse>.self)
            XCTAssertTrue(response.success)
            XCTAssertNotNil(response.data?.id)
            XCTAssertNotNil(response.data?.createdAt)
        })
    }

    // Test: Event persists to database
    func testCreateEvent_PersistsToDatabase() async throws {
        try await app.test(.POST, "/api/v1/analytics/events", beforeRequest: { req in
            try req.content.encode([
                "eventName": "app_launch",
                "eventData": "{\"version\":\"1.0.0\"}",
                "deviceId": "test-device-002"
            ])
        })

        let events = try await AnalyticsEventModel.query(on: app.db).all()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.eventName, "app_launch")
        XCTAssertEqual(events.first?.deviceId, "test-device-002")
    }

    // Test: Event with sessionId links correctly
    func testCreateEvent_WithSessionId_StoresSessionId() async throws {
        let sessionId = "test-session-123"

        try await app.test(.POST, "/api/v1/analytics/events", beforeRequest: { req in
            try req.content.encode([
                "eventName": "chat_started",
                "eventData": "{\"mode\":\"assistant\"}",
                "deviceId": "test-device-003",
                "sessionId": sessionId
            ])
        })

        let events = try await AnalyticsEventModel.query(on: app.db).all()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.sessionId, sessionId)
    }

    // Test: Invalid JSON in request returns 400
    func testCreateEvent_InvalidJSON_Returns400() async throws {
        try await app.test(.POST, "/api/v1/analytics/events", beforeRequest: { req in
            req.body = ByteBuffer(string: "invalid json")
            req.headers.contentType = .json
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    // Test: Missing required fields returns 400
    func testCreateEvent_MissingEventName_Returns400() async throws {
        try await app.test(.POST, "/api/v1/analytics/events", beforeRequest: { req in
            try req.content.encode([
                "eventData": "{\"key\":\"value\"}",
                "deviceId": "test-device-004"
            ])
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })
    }
}
