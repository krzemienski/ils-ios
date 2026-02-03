@testable import ILSBackend
@testable import ILSShared
import XCTVapor
import Fluent

final class AnalyticsServiceTests: XCTestCase {
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

    // Test: createEvent creates valid model
    func testCreateEvent_ValidData_CreatesModel() async throws {
        let request = CreateAnalyticsEventRequest(
            eventName: "test_event",
            eventData: "{\"test\":\"data\"}",
            deviceId: "device-001"
        )

        let event = try await AnalyticsService.createEvent(from: request, on: app.db)

        XCTAssertNotNil(event.id)
        XCTAssertEqual(event.eventName, "test_event")
        XCTAssertEqual(event.eventData, "{\"test\":\"data\"}")
        XCTAssertEqual(event.deviceId, "device-001")
        XCTAssertNotNil(event.createdAt)
    }

    // Test: createEvent with optional fields
    func testCreateEvent_WithOptionalFields_SavesCorrectly() async throws {
        let userId = UUID()
        let sessionId = "test-session-123"

        let request = CreateAnalyticsEventRequest(
            eventName: "message_sent",
            eventData: "{\"length\":42}",
            deviceId: "device-002",
            userId: userId,
            sessionId: sessionId
        )

        let event = try await AnalyticsService.createEvent(from: request, on: app.db)

        XCTAssertEqual(event.userId, userId)
        XCTAssertEqual(event.sessionId, sessionId)
    }

    // Test: queryEvents retrieves events
    func testQueryEvents_ReturnsStoredEvents() async throws {
        // Create test events
        for i in 1...3 {
            let request = CreateAnalyticsEventRequest(
                eventName: "event_\(i)",
                eventData: "{}",
                deviceId: "device-query-test"
            )
            _ = try await AnalyticsService.createEvent(from: request, on: app.db)
        }

        let events = try await AnalyticsEventModel.query(on: app.db)
            .filter(\.$deviceId == "device-query-test")
            .all()

        XCTAssertEqual(events.count, 3)
    }
}
