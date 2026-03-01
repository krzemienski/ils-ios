import XCTest

/// Minimal smoke tests for CI pipeline (macOS)
/// Designed to verify app launches and basic navigation works
/// without requiring specific backend data or configuration
final class MacSmokeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment = [
            "BACKEND_URL": "http://localhost:9999"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        if testRun?.failureCount ?? 0 > 0 {
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Failure-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.terminate()
    }

    // MARK: - Smoke Test 1: App Launches Successfully

    func testSmoke1_AppLaunches() throws {
        // The app should launch without crashing
        // Wait for any content to appear (toolbar, sidebar, or any window content)
        let window = app.windows.firstMatch
        let anyText = app.staticTexts.firstMatch
        let anyButton = app.buttons.firstMatch

        let launched = window.waitForExistence(timeout: 15) ||
                      anyText.waitForExistence(timeout: 5) ||
                      anyButton.waitForExistence(timeout: 5)

        XCTAssertTrue(launched, "App should display UI elements after launch")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "MacSmoke1-AppLaunched"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Smoke Test 2: Main Window Exists

    func testSmoke2_MainWindowExists() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15),
                      "Main window should exist after launch")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "MacSmoke2-MainWindow"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Smoke Test 3: Sidebar or Navigation Exists

    func testSmoke3_NavigationExists() throws {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 15) else {
            XCTFail("Main window should exist after launch")
            return
        }

        // macOS apps may have a sidebar, outline, or toolbar for navigation
        let sidebar = app.outlines.firstMatch
        let toolbar = app.toolbars.firstMatch
        let anyContent = app.staticTexts.firstMatch

        let hasNavigation = sidebar.waitForExistence(timeout: 5) ||
                           toolbar.waitForExistence(timeout: 5) ||
                           anyContent.waitForExistence(timeout: 5)

        XCTAssertTrue(hasNavigation, "App should show navigation or content")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "MacSmoke3-Navigation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
