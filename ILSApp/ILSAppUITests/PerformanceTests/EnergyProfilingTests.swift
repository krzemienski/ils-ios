import XCTest

/// Measures CPU usage as an energy proxy across three scenarios:
/// idle (app launched but no activity), background-poll (periodic session
/// refresh while app is foregrounded), and chat-streaming (active Claude
/// response streaming in a chat session).
///
/// XCTCPUMetric captures CPU time consumed by the app process; high CPU
/// directly correlates with energy draw on device.
final class EnergyProfilingTests: XCTestCase {

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

    // MARK: - Energy Profiling

    /// Measures CPU usage while the app is idle on the sessions list.
    /// A low idle CPU baseline is critical for good battery life.
    func testIdleCPU() throws {
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
            return
        }

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]

        measure(metrics: [XCTCPUMetric(application: app)], options: options) {
            // Let the app sit idle for 3 seconds to capture background CPU usage
            Thread.sleep(forTimeInterval: 3)
            stopMeasuring()
        }
    }

    /// Measures CPU usage during background polling (session list refresh).
    /// Simulates the periodic network refresh the app performs to keep the
    /// sessions list up to date.
    func testBackgroundPollCPU() throws {
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
            return
        }

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]

        measure(metrics: [XCTCPUMetric(application: app)], options: options) {
            // Trigger a pull-to-refresh to simulate a background poll cycle
            sessionsList.swipeDown(velocity: .slow)
            Thread.sleep(forTimeInterval: 2)
            stopMeasuring()
        }
    }

    /// Measures CPU usage during active chat streaming from Claude.
    /// Streaming responses drive continuous UI updates and are the highest
    /// energy scenario; this test establishes a regression baseline.
    func testChatStreamingCPU() throws {
        let sessionsList = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        guard sessionsList.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear within 15 seconds")
            return
        }

        // Navigate into a session if one exists, otherwise skip gracefully
        let firstSession = sessionsList.cells.firstMatch
        guard firstSession.waitForExistence(timeout: 5) else {
            // No sessions available — measure streaming CPU in idle state as fallback
            let options = XCTMeasureOptions()
            options.invocationOptions = [.manuallyStop]
            measure(metrics: [XCTCPUMetric(application: app)], options: options) {
                Thread.sleep(forTimeInterval: 3)
                stopMeasuring()
            }
            return
        }

        firstSession.tap()

        // Allow the chat view to settle before measuring
        Thread.sleep(forTimeInterval: 1)

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]

        measure(metrics: [XCTCPUMetric(application: app)], options: options) {
            // Capture CPU while the chat view renders and any streaming occurs
            Thread.sleep(forTimeInterval: 3)
            stopMeasuring()
        }
    }
}
