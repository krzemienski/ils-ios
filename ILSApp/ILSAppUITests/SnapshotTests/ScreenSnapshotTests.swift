import XCTest

/// Snapshot Tests for ILS iOS App — Major Screens
///
/// Captures pixel-level reference snapshots for 8 major screens:
/// SessionsList, ChatView, SettingsView, ProjectsView, SkillsBrowserView,
/// MCPView, PluginsView, Dashboard
///
/// Usage:
///   - First run: set `isRecordingSnapshots = true` to record baseline references
///   - Subsequent runs: leave `isRecordingSnapshots = false` (default) to compare
final class ScreenSnapshotTests: SnapshotTestBase {

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10),
            "App should launch and reach foreground"
        )
    }

    override func tearDownWithError() throws {
        if testRun?.failureCount ?? 0 > 0 {
            takeScreenshot(named: "Snapshot-Failure-\(name)")
        }
        app.terminate()
        try super.tearDownWithError()
    }

    // MARK: - Sessions List

    func testSnapshot_SessionsList() throws {
        // Sessions list is the default/home screen
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Sessions screen should load")

        waitForLoadingToComplete(timeout: 10)

        assertSnapshot(named: "SessionsList")
    }

    // MARK: - Chat View

    func testSnapshot_ChatView() throws {
        waitForLoadingToComplete(timeout: 10)

        // Navigate into an existing session, or create a new one
        if let cell = findFirstCell(), cell.isHittable {
            cell.tap()
        } else {
            let addButton = app.buttons.matching(
                NSPredicate(format: "identifier CONTAINS 'add' OR label CONTAINS 'New'")
            ).firstMatch
            if addButton.waitForExistence(timeout: 5) {
                addButton.tap()
            }
        }

        // Wait for the chat input to appear
        let chatInputTextField = app.textFields["chat-input-field"]
        let chatInputTextView = app.textViews["chat-input-field"]
        let chatInputBar = app.otherElements["chat-input-bar"]
        let messageTextField = app.textFields["messageInput"]
        let messageTextView = app.textViews["messageInput"]

        let chatVisible =
            chatInputTextField.waitForExistence(timeout: 10) ||
            chatInputTextView.waitForExistence(timeout: 5) ||
            chatInputBar.waitForExistence(timeout: 5) ||
            messageTextField.waitForExistence(timeout: 5) ||
            messageTextView.waitForExistence(timeout: 5)

        guard chatVisible else {
            XCTFail("Chat screen should appear after tapping a session")
            return
        }

        assertSnapshot(named: "ChatView")
    }

    // MARK: - Settings View

    func testSnapshot_SettingsView() throws {
        navigateToSection(.settings)

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 10), "Settings screen should load")

        waitForLoadingToComplete(timeout: 10)

        assertSnapshot(named: "SettingsView")
    }

    // MARK: - Projects View

    func testSnapshot_ProjectsView() throws {
        navigateToSection(.projects)

        let projectsNav = app.navigationBars["Projects"]
        XCTAssertTrue(projectsNav.waitForExistence(timeout: 10), "Projects screen should load")

        waitForLoadingToComplete(timeout: 10)

        assertSnapshot(named: "ProjectsView")
    }

    // MARK: - Skills Browser View

    func testSnapshot_SkillsBrowserView() throws {
        navigateToSection(.skills)

        let skillsNav = app.navigationBars["Skills"]
        XCTAssertTrue(skillsNav.waitForExistence(timeout: 10), "Skills screen should load")

        waitForLoadingToComplete(timeout: 10)

        assertSnapshot(named: "SkillsBrowserView")
    }

    // MARK: - MCP Servers View

    func testSnapshot_MCPView() throws {
        navigateToSection(.mcp)

        let mcpNav = app.navigationBars["MCP Servers"]
        XCTAssertTrue(mcpNav.waitForExistence(timeout: 10), "MCP Servers screen should load")

        waitForLoadingToComplete(timeout: 10)

        assertSnapshot(named: "MCPView")
    }

    // MARK: - Plugins View

    func testSnapshot_PluginsView() throws {
        navigateToSection(.plugins)

        let pluginsNav = app.navigationBars["Plugins"]
        XCTAssertTrue(pluginsNav.waitForExistence(timeout: 10), "Plugins screen should load")

        waitForLoadingToComplete(timeout: 10)

        assertSnapshot(named: "PluginsView")
    }

    // MARK: - Dashboard

    func testSnapshot_Dashboard() throws {
        navigateToSection(.dashboard)

        // Dashboard may use a custom nav title; wait for any nav bar
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Dashboard screen should load")

        waitForLoadingToComplete(timeout: 10)

        assertSnapshot(named: "Dashboard")
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
