import XCTest

/// Measures CPU usage and scroll hitch ratio during sessions list scrolling.
/// Uses XCTCPUMetric for CPU time and XCTOSSignpostMetric.scrollingAndDecelerationMetric
/// for the OS-level hitch time ratio during scroll deceleration.
///
/// The manuallyStop option ensures only the active scroll gesture is measured,
/// not the reset swipe back to the original position.
final class ScrollPerformanceTests: XCTestCase {

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

    // MARK: - Scroll Performance

    /// Measures CPU usage and hitch ratio during a fast scroll of the sessions list.
    /// Uses manuallyStop so only the measured swipeUp is captured; the reset
    /// swipeDown occurs outside the measurement window.
    func testSessionsListScrollPerformance() throws {
        // Wait for the sessions list to appear
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
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
            stopMeasuring()
            sessionsList.swipeDown(velocity: .fast)
        }
    }
}
