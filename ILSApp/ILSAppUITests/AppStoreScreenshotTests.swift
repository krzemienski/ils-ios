import XCTest

/// App Store Screenshot Tests for ILS iOS App
/// Captures 5 key feature screens for App Store submission
/// Designed to be resilient — graceful fallbacks when content is absent
final class AppStoreScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment = [
            "BACKEND_URL": "http://localhost:9999"
        ]
        app.launch()

        // Wait for the app to present any UI before proceeding
        let anyUI = app.tabBars.firstMatch
        _ = anyUI.waitForExistence(timeout: 15)
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

    // MARK: - Private Helpers

    private func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Opens the sidebar sheet and waits for it to appear
    @discardableResult
    private func openSidebar() -> Bool {
        let sidebarButton = app.buttons["sidebarButton"]
        guard waitForElement(sidebarButton, timeout: 8) else { return false }
        sidebarButton.tap()
        let doneButton = app.buttons["sidebarDoneButton"]
        return waitForElement(doneButton, timeout: 5)
    }

    /// Navigates to a sidebar section and dismisses the sidebar
    @discardableResult
    private func navigateToSidebarItem(_ item: String) -> Bool {
        guard openSidebar() else { return false }

        // Try primary identifier (e.g. "sidebar_projects")
        let sidebarItem = app.buttons["sidebar_\(item)"]
        if waitForElement(sidebarItem, timeout: 5) {
            sidebarItem.tap()
        } else {
            // Fallback: match by capitalised label
            let rawValues = ["Sessions", "Projects", "Plugins", "MCP Servers", "Skills", "Settings"]
            for rawValue in rawValues where rawValue.lowercased().contains(item.lowercased()) {
                let label = app.staticTexts[rawValue]
                if label.waitForExistence(timeout: 3) {
                    label.tap()
                    break
                }
            }
        }

        let doneButton = app.buttons["sidebarDoneButton"]
        if doneButton.exists {
            doneButton.tap()
        }
        _ = waitForElementToDisappear(doneButton, timeout: 3)
        return true
    }

    /// Waits for any loading state to resolve
    private func waitForContentToLoad(timeout: TimeInterval = 8) {
        let loadingTexts = ["Loading...", "Loading sessions...", "Loading projects..."]
        for text in loadingTexts {
            let label = app.staticTexts[text]
            if label.exists {
                _ = waitForElementToDisappear(label, timeout: timeout)
                return
            }
        }
        let activityIndicator = app.activityIndicators.firstMatch
        if activityIndicator.exists {
            _ = waitForElementToDisappear(activityIndicator, timeout: timeout)
        }
    }

    // MARK: - Screenshot 1: Sessions List

    func testScreenshot_01_SessionsList() throws {
        // Navigate to Sessions tab or sidebar item
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 10) {
            let sessionsTab = tabBar.buttons["Sessions"]
            if sessionsTab.exists {
                sessionsTab.tap()
            }
        } else {
            navigateToSidebarItem("sessions")
        }

        waitForContentToLoad()

        // Accept any state: sessions list, empty state, or onboarding
        let navBar = app.navigationBars.firstMatch
        _ = navBar.waitForExistence(timeout: 5)

        takeScreenshot(named: "Screenshot_01_Sessions")
    }

    // MARK: - Screenshot 2: Active Chat Session

    func testScreenshot_02_ChatSession() throws {
        // Navigate to the Sessions tab first
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 10) {
            let sessionsTab = tabBar.buttons["Sessions"]
            if sessionsTab.exists {
                sessionsTab.tap()
            }
        } else {
            navigateToSidebarItem("sessions")
        }

        waitForContentToLoad()

        // Attempt to tap the first session cell to open a chat view
        let collectionView = app.collectionViews.firstMatch
        let tableView = app.tables.firstMatch

        let firstCell: XCUIElement?
        if collectionView.waitForExistence(timeout: 5) {
            firstCell = collectionView.cells.firstMatch
        } else if tableView.waitForExistence(timeout: 3) {
            firstCell = tableView.cells.firstMatch
        } else {
            firstCell = app.cells.firstMatch
        }

        if let cell = firstCell, cell.waitForExistence(timeout: 5), cell.isHittable {
            cell.tap()
            // Allow chat view to load
            _ = app.navigationBars.firstMatch.waitForExistence(timeout: 5)
        }

        takeScreenshot(named: "Screenshot_02_ChatSession")
    }

    // MARK: - Screenshot 3: Projects View

    func testScreenshot_03_ProjectsView() throws {
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 10) {
            let projectsTab = tabBar.buttons["Projects"]
            if projectsTab.exists {
                projectsTab.tap()
            } else {
                navigateToSidebarItem("projects")
            }
        } else {
            navigateToSidebarItem("projects")
        }

        waitForContentToLoad()

        // Wait for Projects navigation bar to confirm view loaded
        let projectsNav = app.navigationBars["Projects"]
        _ = projectsNav.waitForExistence(timeout: 8)

        takeScreenshot(named: "Screenshot_03_Projects")
    }

    // MARK: - Screenshot 4: Settings View

    func testScreenshot_04_SettingsView() throws {
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 10) {
            let settingsTab = tabBar.buttons["Settings"]
            if settingsTab.exists {
                settingsTab.tap()
            } else {
                navigateToSidebarItem("settings")
            }
        } else {
            navigateToSidebarItem("settings")
        }

        waitForContentToLoad()

        // Wait for Settings navigation bar to confirm view loaded
        let settingsNav = app.navigationBars["Settings"]
        _ = settingsNav.waitForExistence(timeout: 8)

        takeScreenshot(named: "Screenshot_04_Settings")
    }

    // MARK: - Screenshot 5: MCP Servers View

    func testScreenshot_05_MCPServersView() throws {
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 10) {
            let mcpTab = tabBar.buttons["MCP Servers"]
            if mcpTab.exists {
                mcpTab.tap()
            } else {
                navigateToSidebarItem("mcp")
            }
        } else {
            navigateToSidebarItem("mcp")
        }

        waitForContentToLoad()

        // Wait for MCP Servers navigation bar (fallback to any nav bar)
        let mcpNav = app.navigationBars["MCP Servers"]
        if !mcpNav.waitForExistence(timeout: 8) {
            _ = app.navigationBars.firstMatch.waitForExistence(timeout: 5)
        }

        takeScreenshot(named: "Screenshot_05_MCPServers")
    }
}
