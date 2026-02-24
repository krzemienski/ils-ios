import XCTest

/// Measures cold-start and warm launch performance baselines.
/// Uses XCTApplicationLaunchMetric to capture time from process start to first frame
/// (cold) and time until the app is interactive (warm).
///
/// No backend dependency -- launch tests only measure app startup time.
final class LaunchPerformanceTests: XCTestCase {

    // MARK: - Cold Launch

    /// Measures cold launch time: process start to first rendered frame.
    /// Default: 5 measurement iterations + 1 warm-up iteration.
    func testColdLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Warm Launch

    /// Measures warm launch time: process start until the app is interactive
    /// (waitUntilResponsive). This captures the full time until the user can
    /// interact, not just the first frame render.
    func testWarmLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
            XCUIApplication().launch()
        }
    }
}
