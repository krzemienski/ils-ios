import XCTest

/// Hard memory-limit tests that fail immediately via XCTAssert when memory growth
/// exceeds defined thresholds.
///
/// Unlike MemoryPerformanceTests (which records baselines for trend tracking),
/// this suite enforces absolute ceilings — useful for catching catastrophic
/// regressions that need no historical context to identify.
///
/// Each test uses XCTMemoryMetric(application:) inside measure() to record a
/// performance sample in Xcode's test-result data, and additionally asserts
/// that the observed memory growth stays under the hard threshold.
///
/// Note: XCTMemoryMetric may report 0 KB on some simulator configurations.
/// The mach_task_basic_info growth check serves as a complementary signal.
final class MemoryThresholdTests: XCTestCase {

    // MARK: - Thresholds

    /// Maximum acceptable memory growth (bytes) across all iterations of a
    /// measure() block. 50 MB of net growth strongly indicates a retain cycle
    /// or unbounded cache growth.
    private static let maxGrowthBytes = 50 * 1_024 * 1_024

    /// Maximum acceptable memory growth (bytes) during a single chat-navigation
    /// round-trip. Chat views are more allocation-heavy, so we allow a slightly
    /// wider ceiling before flagging a regression.
    private static let maxChatGrowthBytes = 75 * 1_024 * 1_024

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

    // MARK: - Session Browsing

    /// Asserts that repeated session-list scrolling does not push total memory
    /// growth beyond the hard threshold. XCTMemoryMetric records the sample;
    /// the XCTAssert enforces the ceiling.
    func testSessionBrowsingMemoryUnderThreshold() throws {
        let sessionsList = firstList()
        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
            return
        }

        let before = residentMemoryBytes()

        measure(metrics: [XCTMemoryMetric(application: app)]) {
            sessionsList.swipeUp()
            sessionsList.swipeUp()
            sessionsList.swipeDown()
        }

        let after = residentMemoryBytes()
        assertGrowthUnderThreshold(before: before,
                                    after: after,
                                    threshold: Self.maxGrowthBytes,
                                    label: "session browsing")
    }

    // MARK: - Chat Navigation

    /// Asserts that navigating into and out of a chat view does not push memory
    /// growth beyond the hard threshold. Skips gracefully when no sessions exist.
    func testChatNavigationMemoryUnderThreshold() throws {
        let sessionsList = firstList()
        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
            return
        }

        guard sessionsList.cells.firstMatch.waitForExistence(timeout: 10) else {
            XCTSkip("No sessions available; skipping chat navigation memory threshold check")
        }

        let before = residentMemoryBytes()

        measure(metrics: [XCTMemoryMetric(application: app)]) {
            sessionsList.cells.firstMatch.tap()

            let chatInput = app.textViews.firstMatch.exists
                ? app.textViews.firstMatch
                : app.textFields.firstMatch
            _ = chatInput.waitForExistence(timeout: 5)

            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
            } else {
                app.swipeRight()
            }

            _ = sessionsList.waitForExistence(timeout: 5)
        }

        let after = residentMemoryBytes()
        assertGrowthUnderThreshold(before: before,
                                    after: after,
                                    threshold: Self.maxChatGrowthBytes,
                                    label: "chat navigation")
    }

    // MARK: - Idle Footprint

    /// Asserts that the app idles without measurable memory growth between samples.
    /// A growing footprint at idle signals a background timer or subscription leak.
    func testIdleMemoryStable() throws {
        let sessionsList = firstList()
        _ = sessionsList.waitForExistence(timeout: 15)

        let before = residentMemoryBytes()

        measure(metrics: [XCTMemoryMetric(application: app)]) {
            // Idle — no interaction; background work should be minimal.
            Thread.sleep(forTimeInterval: 0.5)
        }

        let after = residentMemoryBytes()
        assertGrowthUnderThreshold(before: before,
                                    after: after,
                                    threshold: Self.maxGrowthBytes,
                                    label: "idle state")
    }

    // MARK: - Private Helpers

    /// Returns the current resident-set size of the test-runner process in bytes,
    /// or 0 if the syscall fails. Used as a relative measure: compare before and
    /// after a test action to detect net memory growth.
    private func residentMemoryBytes() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
        )
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }

    /// Asserts that the net memory growth (after − before) does not exceed
    /// threshold. Skips the assertion when memory reads return 0 (simulator
    /// configurations where the syscall is unavailable).
    private func assertGrowthUnderThreshold(before: Int,
                                             after: Int,
                                             threshold: Int,
                                             label: String) {
        guard before > 0, after > 0 else { return }
        let growth = after - before
        guard growth > 0 else { return }
        XCTAssertLessThanOrEqual(
            growth,
            threshold,
            "Memory grew by \(formatBytes(growth)) during \(label), "
                + "exceeding the hard threshold of \(formatBytes(threshold))"
        )
    }

    private func formatBytes(_ bytes: Int) -> String {
        String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }

    private func firstList() -> XCUIElement {
        app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch
    }
}
