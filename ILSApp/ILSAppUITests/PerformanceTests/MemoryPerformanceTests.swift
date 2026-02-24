import XCTest

/// Measures memory footprint during session browsing.
/// Uses XCTMemoryMetric(application:) to capture the physical memory footprint
/// while the user scrolls through the sessions list.
///
/// Note: XCTMemoryMetric may report 0 KB on some simulator configurations.
/// If the first run shows 0 KB, do not set a baseline -- MetricKit (Plan 02)
/// provides the production fallback for memory measurement.
final class MemoryPerformanceTests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = ["BACKEND_URL": "http://localhost:9999"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - Memory Footprint

    /// Measures physical memory footprint while browsing the sessions list.
    /// Scrolls up and down to simulate typical user browsing behavior.
    func testSessionBrowsingMemory() throws {
        // Wait for the sessions list to appear (List or ScrollView)
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
            return
        }

        measure(metrics: [XCTMemoryMetric(application: app)]) {
            sessionsList.swipeUp()
            sessionsList.swipeUp()
            sessionsList.swipeDown()
        }
    }
}
