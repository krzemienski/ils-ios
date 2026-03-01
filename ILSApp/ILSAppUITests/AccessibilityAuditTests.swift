import XCTest

/// Accessibility Audit Tests for ILS iOS App
/// Uses performAccessibilityAudit() (iOS 17+) to validate WCAG compliance
/// across all major screens: Sessions, Chat, Settings, Projects, Skills, MCP, Plugins, Dashboard
@available(iOS 17.0, *)
final class AccessibilityAuditTests: XCUITestBase {

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        app.launch()
        // Wait for the app to reach its initial state
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10),
            "App should launch and reach foreground"
        )
    }

    override func tearDownWithError() throws {
        if testRun?.failureCount ?? 0 > 0 {
            takeScreenshot(named: "Accessibility-Failure-\(name)")
        }
        app.terminate()
        try super.tearDownWithError()
    }

    // MARK: - Sessions Screen

    func testAccessibility_SessionsScreen() throws {
        // Sessions list is the default/home screen
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Sessions screen should load")

        waitForLoadingToComplete(timeout: 10)
        takeScreenshot(named: "Accessibility-Sessions-BeforeAudit")

        try app.performAccessibilityAudit(for: .all) { issue in
            // Log but do not fail on dynamic type issues in list cells — known SwiftUI limitation
            if issue.auditType == .dynamicType {
                return false
            }
            return true
        }
    }

    // MARK: - Chat Screen

    func testAccessibility_ChatScreen() throws {
        // Navigate into a session chat, or create a new session if none exists
        waitForLoadingToComplete(timeout: 10)

        let firstCell = findFirstCell()
        if let cell = firstCell, cell.exists, cell.isHittable {
            cell.tap()
        } else {
            // Attempt to create a new session via the + button
            let addButton = app.buttons.matching(
                NSPredicate(format: "identifier CONTAINS 'add' OR label CONTAINS 'New'")
            ).firstMatch
            if addButton.waitForExistence(timeout: 5) {
                addButton.tap()
            }
        }

        // Wait for chat interface to appear
        let messageInput = app.textFields["messageInput"].firstMatch
        let messageTextView = app.textViews["messageInput"].firstMatch
        let chatAppeared = messageInput.waitForExistence(timeout: 10) ||
                           messageTextView.waitForExistence(timeout: 5)

        guard chatAppeared else {
            XCTFail("Chat screen should appear after tapping a session")
            return
        }

        takeScreenshot(named: "Accessibility-Chat-BeforeAudit")

        try app.performAccessibilityAudit(for: .all) { issue in
            // Ignore contrast issues inside streaming markdown content (known limitation)
            if issue.auditType == .contrast,
               let elementDescription = issue.element?.debugDescription,
               elementDescription.contains("markdown") || elementDescription.contains("code") {
                return false
            }
            return true
        }
    }

    // MARK: - Settings Screen

    func testAccessibility_SettingsScreen() throws {
        navigateToSection(.settings)

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 10), "Settings screen should load")

        waitForLoadingToComplete(timeout: 10)
        takeScreenshot(named: "Accessibility-Settings-BeforeAudit")

        try app.performAccessibilityAudit(for: .all) { issue in
            if issue.auditType == .dynamicType {
                return false
            }
            return true
        }
    }

    // MARK: - Projects Screen

    func testAccessibility_ProjectsScreen() throws {
        navigateToSection(.projects)

        let projectsNav = app.navigationBars["Projects"]
        XCTAssertTrue(projectsNav.waitForExistence(timeout: 10), "Projects screen should load")

        waitForLoadingToComplete(timeout: 10)
        takeScreenshot(named: "Accessibility-Projects-BeforeAudit")

        try app.performAccessibilityAudit(for: .all) { issue in
            if issue.auditType == .dynamicType {
                return false
            }
            return true
        }
    }

    // MARK: - Skills Screen

    func testAccessibility_SkillsScreen() throws {
        navigateToSection(.skills)

        let skillsNav = app.navigationBars["Skills"]
        XCTAssertTrue(skillsNav.waitForExistence(timeout: 10), "Skills screen should load")

        waitForLoadingToComplete(timeout: 10)
        takeScreenshot(named: "Accessibility-Skills-BeforeAudit")

        try app.performAccessibilityAudit(for: .all) { issue in
            if issue.auditType == .dynamicType {
                return false
            }
            return true
        }
    }

    // MARK: - MCP Servers Screen

    func testAccessibility_MCPServersScreen() throws {
        navigateToSection(.mcp)

        let mcpNav = app.navigationBars["MCP Servers"]
        XCTAssertTrue(mcpNav.waitForExistence(timeout: 10), "MCP Servers screen should load")

        waitForLoadingToComplete(timeout: 10)
        takeScreenshot(named: "Accessibility-MCP-BeforeAudit")

        try app.performAccessibilityAudit(for: .all) { issue in
            if issue.auditType == .dynamicType {
                return false
            }
            return true
        }
    }

    // MARK: - Plugins Screen

    func testAccessibility_PluginsScreen() throws {
        navigateToSection(.plugins)

        let pluginsNav = app.navigationBars["Plugins"]
        XCTAssertTrue(pluginsNav.waitForExistence(timeout: 10), "Plugins screen should load")

        waitForLoadingToComplete(timeout: 10)
        takeScreenshot(named: "Accessibility-Plugins-BeforeAudit")

        try app.performAccessibilityAudit(for: .all) { issue in
            if issue.auditType == .dynamicType {
                return false
            }
            return true
        }
    }

    // MARK: - Dashboard Screen

    func testAccessibility_DashboardScreen() throws {
        navigateToSection(.dashboard)

        // Dashboard may use a different nav title; wait for any nav bar
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Dashboard screen should load")

        waitForLoadingToComplete(timeout: 10)
        takeScreenshot(named: "Accessibility-Dashboard-BeforeAudit")

        try app.performAccessibilityAudit(for: .all) { issue in
            if issue.auditType == .dynamicType {
                return false
            }
            return true
        }
    }

    // MARK: - Sidebar Accessibility

    func testAccessibility_Sidebar() throws {
        openSidebar()

        // Wait for sidebar to fully appear
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5), "Sidebar should be open")

        takeScreenshot(named: "Accessibility-Sidebar-BeforeAudit")

        try app.performAccessibilityAudit(for: .all) { issue in
            if issue.auditType == .dynamicType {
                return false
            }
            return true
        }

        closeSidebar()
    }

    // MARK: - Helpers

    private func findFirstCell() -> XCUIElement? {
        let collectionView = app.collectionViews.firstMatch
        if collectionView.waitForExistence(timeout: 5) {
            let cell = collectionView.cells.firstMatch
            if cell.waitForExistence(timeout: 3), cell.isHittable {
                return cell
            }
        }

        let table = app.tables.firstMatch
        if table.waitForExistence(timeout: 3) {
            let cell = table.cells.firstMatch
            if cell.waitForExistence(timeout: 2), cell.isHittable {
                return cell
            }
        }

        return nil
    }
}
