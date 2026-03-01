import XCTest

/// Measures scroll performance of the sessions list with large mock data sets.
/// The data set size is controlled by the PERF_ITEM_COUNT environment variable:
///   - 100   → small data set, baseline measurement
///   - 1000  → medium data set, typical production scale
///   - 10000 → large data set, stress test
///
/// Run with different counts to detect O(n) rendering regressions:
///   PERF_ITEM_COUNT=1000 xcodebuild test ...
///
/// Uses XCTCPUMetric to capture CPU overhead and
/// XCTOSSignpostMetric.scrollingAndDecelerationMetric to capture hitch ratio
/// across three scroll passes. manuallyStop isolates only the measured swipe
/// from the reset swipe back to the top.
final class LargeListRenderTests: XCTestCase {

    let app = XCUIApplication()

    /// Parsed from PERF_ITEM_COUNT env var; defaults to 100 if unset or invalid.
    private var itemCount: Int {
        if let raw = ProcessInfo.processInfo.environment["PERF_ITEM_COUNT"],
           let count = Int(raw), count > 0 {
            return count
        }
        return 100
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = [
            "BACKEND_URL": "http://localhost:9999",
            "PERF_ITEM_COUNT": "\(itemCount)"
        ]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - Large List Render Performance

    /// Measures CPU usage and hitch ratio while scrolling a sessions list
    /// populated with the number of mock items specified by PERF_ITEM_COUNT.
    ///
    /// Three successive swipeUp passes cover progressively deeper list content,
    /// after which a single swipeDown resets position outside the measurement
    /// window so the next iteration starts at the top.
    func testLargeListScrollPerformance() throws {
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds (PERF_ITEM_COUNT=\(itemCount))")
            return
        }

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]

        measure(
            metrics: [
                XCTCPUMetric(application: app),
                XCTOSSignpostMetric.scrollingAndDecelerationMetric
            ],
            options: options
        ) {
            sessionsList.swipeUp(velocity: .fast)
            sessionsList.swipeUp(velocity: .fast)
            sessionsList.swipeUp(velocity: .fast)
            stopMeasuring()
            // Reset outside measurement window
            sessionsList.swipeDown(velocity: .fast)
            sessionsList.swipeDown(velocity: .fast)
            sessionsList.swipeDown(velocity: .fast)
        }
    }

    /// Measures memory footprint while scrolling through a large mock data set.
    /// Verifies that memory does not grow unboundedly as new cells are rendered
    /// and off-screen cells are recycled.
    func testLargeListScrollMemory() throws {
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds (PERF_ITEM_COUNT=\(itemCount))")
            return
        }

        measure(metrics: [XCTMemoryMetric(application: app)]) {
            sessionsList.swipeUp(velocity: .fast)
            sessionsList.swipeUp(velocity: .fast)
            sessionsList.swipeDown(velocity: .fast)
            sessionsList.swipeDown(velocity: .fast)
        }
    }
}
