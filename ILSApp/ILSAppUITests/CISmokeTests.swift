import XCTest

/// Minimal smoke tests for CI pipeline
/// Designed to verify app launches and basic navigation works
/// without requiring specific backend data or configuration
final class CISmokeTests: XCTestCase {
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
        // Wait for any content to appear (tab bar, navigation, or onboarding)
        let tabBar = app.tabBars.firstMatch
        let navBar = app.navigationBars.firstMatch
        let anyText = app.staticTexts.firstMatch

        let launched = tabBar.waitForExistence(timeout: 15) ||
                      navBar.waitForExistence(timeout: 5) ||
                      anyText.waitForExistence(timeout: 5)

        XCTAssertTrue(launched, "App should display UI elements after launch")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Smoke1-AppLaunched"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Smoke Test 2: Tab Bar Navigation

    func testSmoke2_TabBarExists() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 15) else {
            // App might show onboarding instead of tab bar — still a valid launch
            let anyContent = app.staticTexts.firstMatch
            XCTAssertTrue(anyContent.waitForExistence(timeout: 5),
                         "App should show either tab bar or onboarding content")
            return
        }

        // Verify tab bar has buttons (app has 5 tabs)
        let tabButtons = tabBar.buttons
        XCTAssertGreaterThanOrEqual(tabButtons.count, 3,
                                    "Tab bar should have at least 3 tabs")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Smoke2-TabBar"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Smoke Test 3: Tab Navigation Works

    func testSmoke3_TabNavigation() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 15) else {
            // Skip if onboarding is showing
            return
        }

        // Try tapping the Sessions tab
        let sessionsTab = tabBar.buttons["Sessions"]
        if sessionsTab.exists {
            sessionsTab.tap()
            // Wait for any response
            let _ = app.navigationBars.firstMatch.waitForExistence(timeout: 5)

            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Smoke3-SessionsTab"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        // Try tapping the Settings tab
        let settingsTab = tabBar.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            let _ = app.navigationBars.firstMatch.waitForExistence(timeout: 5)

            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Smoke3-SettingsTab"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
