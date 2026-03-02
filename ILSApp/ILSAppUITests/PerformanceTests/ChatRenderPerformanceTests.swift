import XCTest

/// Measures CPU usage and render time during chat message list rendering.
/// Uses XCTCPUMetric to capture CPU time and XCTOSSignpostMetric.scrollingAndDecelerationMetric
/// for the OS-level hitch time ratio while scrolling through chat messages.
///
/// The manuallyStop option ensures only the active scroll gesture is measured,
/// not the reset swipe back to the original position.
final class ChatRenderPerformanceTests: XCTestCase {

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

    // MARK: - Chat Render Performance

    /// Measures CPU usage and hitch ratio while rendering and scrolling a chat message list.
    /// Opens a session to load the chat view, then scrolls through messages to exercise
    /// the message rendering pipeline.
    ///
    /// Uses manuallyStop so only the measured swipeUp is captured; the reset
    /// swipeDown occurs outside the measurement window.
    func testChatMessageListRenderPerformance() throws {
        // Wait for the sessions list to appear
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
            return
        }

        // Tap the first session to open the chat view
        let firstSession = sessionsList.cells.firstMatch
        guard firstSession.waitForExistence(timeout: 10) else {
            XCTFail("No sessions available to open")
            return
        }
        firstSession.tap()

        // Wait for the chat message list to appear
        let chatScrollView = app.scrollViews.firstMatch
        guard chatScrollView.waitForExistence(timeout: 15) else {
            XCTFail("Chat message list did not appear within 15 seconds")
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
            chatScrollView.swipeUp(velocity: .fast)
            stopMeasuring()
            chatScrollView.swipeDown(velocity: .fast)
        }
    }

    /// Measures CPU usage while the chat view initially renders a conversation.
    /// Captures the rendering cost of loading and displaying the first screenful of messages.
    func testChatViewInitialRenderPerformance() throws {
        // Wait for the sessions list to appear
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
            return
        }

        measure(metrics: [XCTCPUMetric(application: app)]) {
            // Tap first session to trigger chat render
            let firstSession = sessionsList.cells.firstMatch
            if firstSession.exists {
                firstSession.tap()
            }

            // Wait for chat content to render
            let chatScrollView = app.scrollViews.firstMatch
            _ = chatScrollView.waitForExistence(timeout: 10)

            // Navigate back to reset for next iteration
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
            }

            // Wait for sessions list to reappear
            _ = sessionsList.waitForExistence(timeout: 10)
        }
    }
}
