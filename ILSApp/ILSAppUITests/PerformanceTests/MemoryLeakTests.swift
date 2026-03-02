import XCTest

/// Detects retain cycles and memory leaks caused by repeated navigation.
/// Uses XCTMemoryMetric(application:) to capture physical memory footprint
/// across multiple session-browse and chat-navigation cycles.
///
/// A monotonically growing footprint across iterations is a strong signal
/// of a retain cycle or unbounded cache growth in the navigation stack.
///
/// Note: XCTMemoryMetric may report 0 KB on some simulator configurations.
/// If the first run shows 0 KB, do not set a baseline -- MetricKit (Plan 02)
/// provides the production fallback for memory measurement.
final class MemoryLeakTests: XCTestCase {

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

    // MARK: - Retain Cycle Detection

    /// Detects retain cycles in the sessions list by repeatedly scrolling
    /// and returning to the top. Memory should stabilise after the first
    /// iteration if all view models are correctly released.
    func testSessionBrowsingRetainCycles() throws {
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
            return
        }

        measure(metrics: [XCTMemoryMetric(application: app)]) {
            // Simulate a complete browse cycle: scroll down then back up.
            // Repeating inside measure() exercises the retain-cycle path
            // multiple times per measurement sample.
            for _ in 0..<3 {
                sessionsList.swipeUp()
                sessionsList.swipeDown()
            }
        }
    }

    /// Detects retain cycles triggered by navigating into and out of the
    /// chat view. Each iteration opens the first available session (if
    /// present) and navigates back, mirroring a real user session-switch.
    func testChatNavigationRetainCycles() throws {
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
            return
        }

        // Skip the test gracefully when no sessions exist in the test
        // environment so CI doesn't mark it as a spurious failure.
        guard sessionsList.cells.firstMatch.waitForExistence(timeout: 10) else {
            XCTSkip("No sessions available to navigate into; skipping chat retain-cycle check")
        }

        measure(metrics: [XCTMemoryMetric(application: app)]) {
            // Navigate into the first session's chat view.
            sessionsList.cells.firstMatch.tap()

            // Allow the chat view to settle before going back.
            let chatInput = app.textViews.firstMatch.exists
                ? app.textViews.firstMatch
                : app.textFields.firstMatch
            _ = chatInput.waitForExistence(timeout: 5)

            // Return to the sessions list via the back button or swipe.
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
            } else {
                app.swipeRight()
            }

            _ = sessionsList.waitForExistence(timeout: 5)
        }
    }
}
