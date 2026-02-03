@testable import ILSBackend
@testable import ILSShared
import XCTVapor
import Fluent
import FluentSQLiteDriver

final class AnalyticsMigrationTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    // Test: Migration creates analytics_events table
    func testCreateAnalyticsEvents_CreatesTable() async throws {
        let migration = CreateAnalyticsEvents()
        try await migration.prepare(on: app.db)

        // Verify table exists by attempting to query it
        let count = try await AnalyticsEventModel.query(on: app.db).count()
        XCTAssertEqual(count, 0) // Table exists but empty
    }

    // Test: Migration revert drops table
    func testCreateAnalyticsEvents_Revert_DropsTable() async throws {
        let migration = CreateAnalyticsEvents()

        // Prepare (create table)
        try await migration.prepare(on: app.db)

        // Revert (drop table)
        try await migration.revert(on: app.db)

        // Verify table is dropped by expecting query to fail
        do {
            _ = try await AnalyticsEventModel.query(on: app.db).all()
            XCTFail("Expected query to fail on dropped table")
        } catch {
            // Expected - table should not exist
        }
    }

    // Test: Table schema matches model
    func testTableSchema_MatchesModel() async throws {
        let migration = CreateAnalyticsEvents()
        try await migration.prepare(on: app.db)

        // Create test event to verify all fields
        let event = AnalyticsEventModel(
            eventName: "schema_test",
            eventData: "{}",
            deviceId: "device-schema",
            userId: UUID(),
            sessionId: "test-session-schema"
        )

        try await event.save(on: app.db)

        let retrieved = try await AnalyticsEventModel.query(on: app.db)
            .filter(\.$eventName == "schema_test")
            .first()

        XCTAssertNotNil(retrieved)
        XCTAssertNotNil(retrieved?.id)
        XCTAssertNotNil(retrieved?.createdAt)
    }
}
