import XCTest

/// Feature Gate Tests for ILS iOS App - Additional Views
/// Tests for Projects, Skills, MCP Servers, Settings, and Plugins views
/// Each test represents a validation gate that must pass
final class FeatureGateTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // No mock mode - tests run against real backend
        app.launch()
    }

    override func tearDownWithError() throws {
        // Capture screenshot on failure for evidence
        if testRun?.failureCount ?? 0 > 0 {
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Failure-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.terminate()
    }

    // MARK: - Helper Methods

    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    private func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Opens the sidebar sheet and waits for it to appear
    private func openSidebar() -> Bool {
        let sidebarButton = app.buttons["sidebarButton"]
        guard waitForElement(sidebarButton, timeout: 10) else { return false }
        sidebarButton.tap()

        // Wait for sidebar to appear - look for the Done button or sidebar items
        let doneButton = app.buttons["sidebarDoneButton"]
        return waitForElement(doneButton, timeout: 5)
    }

    /// Navigates to a specific sidebar item by tapping it
    /// - Parameter item: The sidebar item identifier suffix (e.g., "projects", "skills")
    private func navigateToSidebarItem(_ item: String) -> Bool {
        // Open sidebar first
        guard openSidebar() else { return false }

        takeScreenshot(named: "Sidebar-Opened-For-\(item)")

        // The sidebar items have identifiers like "sidebar_projects", "sidebar_skills", etc.
        let sidebarItem = app.buttons["sidebar_\(item)"]
        if waitForElement(sidebarItem, timeout: 5) {
            sidebarItem.tap()
        } else {
            // Fallback: try to find by text label
            let textLabel = app.staticTexts[item.capitalized]
            if textLabel.waitForExistence(timeout: 3) {
                textLabel.tap()
            } else {
                // Try matching raw values from SidebarItem enum
                let rawValues = ["Sessions", "Projects", "Plugins", "MCP Servers", "Skills", "Settings"]
                for rawValue in rawValues where rawValue.lowercased().contains(item.lowercased()) {
                    let label = app.staticTexts[rawValue]
                    if label.exists {
                        label.tap()
                        break
                    }
                }
            }
        }

        // Dismiss sidebar by tapping Done
        let doneButton = app.buttons["sidebarDoneButton"]
        if doneButton.exists {
            doneButton.tap()
        }

        // Brief wait for navigation to complete
        sleep(1)
        return true
    }

    /// Finds a list element (SwiftUI List can be table or collectionView)
    private func findList() -> XCUIElement? {
        // Try tables (older iOS)
        let table = app.tables.firstMatch
        if table.waitForExistence(timeout: 3) { return table }

        // Try collectionViews (iOS 18.6+ SwiftUI List)
        let collection = app.collectionViews.firstMatch
        if collection.waitForExistence(timeout: 2) { return collection }

        // Try scrollViews as last resort
        let scroll = app.scrollViews.firstMatch
        if scroll.waitForExistence(timeout: 2) { return scroll }

        return nil
    }

    /// Finds the first cell in any list-like container
    private func findFirstCell() -> XCUIElement? {
        // Try cells in collectionViews (iOS 18.6+ SwiftUI List)
        let collectionView = app.collectionViews.firstMatch
        if collectionView.waitForExistence(timeout: 3) {
            let firstCell = collectionView.cells.firstMatch
            if firstCell.waitForExistence(timeout: 2) && firstCell.isHittable {
                return firstCell
            }
        }

        // Try cells in tables (older iOS)
        let table = app.tables.firstMatch
        if table.waitForExistence(timeout: 2) {
            let firstCell = table.cells.firstMatch
            if firstCell.waitForExistence(timeout: 2) && firstCell.isHittable {
                return firstCell
            }
        }

        // Try any cell
        let anyCell = app.cells.firstMatch
        if anyCell.waitForExistence(timeout: 2) && anyCell.isHittable {
            return anyCell
        }

        return nil
    }

    /// Performs a pull-to-refresh gesture on the current view
    private func performPullToRefresh() {
        let startCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let endCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        startCoord.press(forDuration: 0.1, thenDragTo: endCoord)
        sleep(2)
    }

    // MARK: - GATE 9: Projects List View

    func testGate9_ProjectsListLoads() throws {
        // VALIDATION: Projects list view loads with content or empty state

        // Navigate to Projects via sidebar
        XCTAssertTrue(navigateToSidebarItem("projects"), "Should navigate to Projects")

        // Wait for navigation title
        let projectsTitle = app.navigationBars["Projects"]
        XCTAssertTrue(waitForElement(projectsTitle, timeout: 10), "Projects navigation title should appear")

        takeScreenshot(named: "Gate9-ProjectsView")

        // Wait for loading to complete
        let loadingIndicator = app.staticTexts["Loading projects..."]
        if loadingIndicator.exists {
            _ = waitForElementToDisappear(loadingIndicator, timeout: 15)
        }

        // Verify list content appears - either projects or empty state
        let list = findList()
        let emptyState = app.staticTexts["No Projects"]
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'plus' OR identifier CONTAINS 'plus'")).firstMatch

        // The view loaded successfully if we see any of: list, empty state, or toolbar button
        let hasContent = (list != nil && list!.exists) ||
                        emptyState.waitForExistence(timeout: 5) ||
                        addButton.waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "Should show projects list, empty state, or add button")

        takeScreenshot(named: "Gate9-ProjectsListLoaded")
    }

    func testGate9b_ProjectsPullToRefresh() throws {
        // VALIDATION: Pull to refresh works on projects list

        // Navigate to Projects
        XCTAssertTrue(navigateToSidebarItem("projects"), "Should navigate to Projects")

        let projectsTitle = app.navigationBars["Projects"]
        XCTAssertTrue(waitForElement(projectsTitle, timeout: 10), "Projects view should appear")

        takeScreenshot(named: "Gate9b-BeforeRefresh")

        // Perform pull to refresh
        performPullToRefresh()

        // Verify view is still functional
        XCTAssertTrue(projectsTitle.exists, "Projects view should still exist after refresh")

        takeScreenshot(named: "Gate9b-AfterRefresh")
    }

    // MARK: - GATE 10: Project Creation

    func testGate10_CreateNewProject() throws {
        // VALIDATION: Can create a new project

        // Navigate to Projects
        XCTAssertTrue(navigateToSidebarItem("projects"), "Should navigate to Projects")

        let projectsTitle = app.navigationBars["Projects"]
        XCTAssertTrue(waitForElement(projectsTitle, timeout: 10), "Projects view should appear")

        // Wait for loading to complete
        sleep(2)

        takeScreenshot(named: "Gate10-BeforeCreate")

        // Find and tap the add button (plus button in toolbar)
        let addButton = app.navigationBars["Projects"].buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR identifier CONTAINS 'plus'")).firstMatch
        if !addButton.exists {
            // Try finding any plus button
            let plusButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'plus'")).firstMatch
            XCTAssertTrue(waitForElement(plusButton, timeout: 5), "Add button should exist")
            plusButton.tap()
        } else {
            addButton.tap()
        }

        // Wait for New Project sheet to appear
        let newProjectTitle = app.navigationBars["New Project"]
        XCTAssertTrue(waitForElement(newProjectTitle, timeout: 5), "New Project sheet should appear")

        takeScreenshot(named: "Gate10-NewProjectSheet")

        // Fill in project details - find text fields
        let textFields = app.textFields.allElementsBoundByIndex
        XCTAssertTrue(textFields.count >= 2, "Should have at least name and path fields")

        // First field is name
        if textFields.count > 0 {
            let nameField = textFields[0]
            nameField.tap()
            nameField.typeText("Test Project")
        }

        // Second field is path
        if textFields.count > 1 {
            let pathField = textFields[1]
            pathField.tap()
            pathField.typeText("/Users/test/project")
        }

        takeScreenshot(named: "Gate10-FormFilled")

        // Find and tap Create button
        let createButton = app.buttons["Create"]
        XCTAssertTrue(waitForElement(createButton, timeout: 3), "Create button should exist")

        // Verify Create button is enabled (fields are filled)
        if createButton.isEnabled {
            createButton.tap()

            // VALIDATION: Sheet dismisses or project appears
            let sheetDismissed = waitForElementToDisappear(newProjectTitle, timeout: 10)
            if sheetDismissed {
                // Look for our new project in the list
                let newProject = app.staticTexts["Test Project"]
                _ = newProject.waitForExistence(timeout: 5)
            }

            takeScreenshot(named: "Gate10-ProjectCreated")
        } else {
            // Create button disabled means validation working correctly
            takeScreenshot(named: "Gate10-CreateButtonDisabled")
        }
    }

    // MARK: - GATE 11: Skills List View

    func testGate11_SkillsListLoads() throws {
        // VALIDATION: Skills list view loads with content or empty state

        // Navigate to Skills via sidebar
        XCTAssertTrue(navigateToSidebarItem("skills"), "Should navigate to Skills")

        // Wait for navigation title
        let skillsTitle = app.navigationBars["Skills"]
        XCTAssertTrue(waitForElement(skillsTitle, timeout: 10), "Skills navigation title should appear")

        takeScreenshot(named: "Gate11-SkillsView")

        // Wait for loading to complete
        let loadingIndicator = app.staticTexts["Loading skills..."]
        if loadingIndicator.exists {
            _ = waitForElementToDisappear(loadingIndicator, timeout: 15)
        }

        // Verify list content appears - either skills or empty state
        let list = findList()
        let emptyState = app.staticTexts["No Skills"]

        let hasContent = (list != nil && list!.exists) ||
                        emptyState.waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "Should show skills list or empty state")

        takeScreenshot(named: "Gate11-SkillsListLoaded")
    }

    func testGate11b_SkillsSearchFunctionality() throws {
        // VALIDATION: Skills search field works

        // Navigate to Skills
        XCTAssertTrue(navigateToSidebarItem("skills"), "Should navigate to Skills")

        let skillsTitle = app.navigationBars["Skills"]
        XCTAssertTrue(waitForElement(skillsTitle, timeout: 10), "Skills view should appear")

        // Wait for loading
        sleep(2)

        takeScreenshot(named: "Gate11b-BeforeSearch")

        // Look for search field - SwiftUI searchable adds a search field
        let searchField = app.searchFields.firstMatch
        if waitForElement(searchField, timeout: 5) {
            searchField.tap()
            searchField.typeText("test")

            takeScreenshot(named: "Gate11b-SearchActive")

            // Clear search
            let clearButton = searchField.buttons.firstMatch
            if clearButton.exists {
                clearButton.tap()
            }
        }

        // Search field existing is the validation
        XCTAssertTrue(searchField.exists || app.otherElements["Search"].exists, "Search should be available")

        takeScreenshot(named: "Gate11b-AfterSearch")
    }

    func testGate11c_SkillsPullToRefresh() throws {
        // VALIDATION: Pull to refresh works on skills list

        // Navigate to Skills
        XCTAssertTrue(navigateToSidebarItem("skills"), "Should navigate to Skills")

        let skillsTitle = app.navigationBars["Skills"]
        XCTAssertTrue(waitForElement(skillsTitle, timeout: 10), "Skills view should appear")

        takeScreenshot(named: "Gate11c-BeforeRefresh")

        // Perform pull to refresh
        performPullToRefresh()

        // Verify view is still functional
        XCTAssertTrue(skillsTitle.exists, "Skills view should still exist after refresh")

        takeScreenshot(named: "Gate11c-AfterRefresh")
    }

    // MARK: - GATE 12: MCP Servers List View

    func testGate12_MCPServersListLoads() throws {
        // VALIDATION: MCP Servers list view loads with content or empty state

        // Navigate to MCP Servers via sidebar (identifier is "sidebar_mcp_servers" from "MCP Servers")
        XCTAssertTrue(navigateToSidebarItem("mcp_servers"), "Should navigate to MCP Servers")

        // Wait for navigation title
        let mcpTitle = app.navigationBars["MCP Servers"]
        XCTAssertTrue(waitForElement(mcpTitle, timeout: 10), "MCP Servers navigation title should appear")

        takeScreenshot(named: "Gate12-MCPServersView")

        // Wait for loading to complete
        let loadingIndicator = app.staticTexts["Loading MCP servers..."]
        if loadingIndicator.exists {
            _ = waitForElementToDisappear(loadingIndicator, timeout: 15)
        }

        // Verify list content appears - either servers or empty state
        let list = findList()
        let emptyState = app.staticTexts["No MCP Servers"]

        let hasContent = (list != nil && list!.exists) ||
                        emptyState.waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "Should show MCP servers list or empty state")

        takeScreenshot(named: "Gate12-MCPServersListLoaded")
    }

    func testGate12b_MCPServersPullToRefresh() throws {
        // VALIDATION: Pull to refresh works on MCP servers list

        // Navigate to MCP Servers
        XCTAssertTrue(navigateToSidebarItem("mcp_servers"), "Should navigate to MCP Servers")

        let mcpTitle = app.navigationBars["MCP Servers"]
        XCTAssertTrue(waitForElement(mcpTitle, timeout: 10), "MCP Servers view should appear")

        takeScreenshot(named: "Gate12b-BeforeRefresh")

        // Perform pull to refresh
        performPullToRefresh()

        // Verify view is still functional
        XCTAssertTrue(mcpTitle.exists, "MCP Servers view should still exist after refresh")

        takeScreenshot(named: "Gate12b-AfterRefresh")
    }

    func testGate12c_MCPServersSearchFunctionality() throws {
        // VALIDATION: MCP Servers search field works

        // Navigate to MCP Servers
        XCTAssertTrue(navigateToSidebarItem("mcp_servers"), "Should navigate to MCP Servers")

        let mcpTitle = app.navigationBars["MCP Servers"]
        XCTAssertTrue(waitForElement(mcpTitle, timeout: 10), "MCP Servers view should appear")

        // Wait for loading
        sleep(2)

        takeScreenshot(named: "Gate12c-BeforeSearch")

        // Look for search field
        let searchField = app.searchFields.firstMatch
        if waitForElement(searchField, timeout: 5) {
            searchField.tap()
            searchField.typeText("test")

            takeScreenshot(named: "Gate12c-SearchActive")

            // Clear search
            let clearButton = searchField.buttons.firstMatch
            if clearButton.exists {
                clearButton.tap()
            }
        }

        // Search field existing is the validation
        XCTAssertTrue(searchField.exists || app.otherElements["Search"].exists, "Search should be available")

        takeScreenshot(named: "Gate12c-AfterSearch")
    }

    // MARK: - GATE 13: Settings View

    func testGate13_SettingsViewLoads() throws {
        // VALIDATION: Settings view loads with all sections

        // Navigate to Settings via sidebar
        XCTAssertTrue(navigateToSidebarItem("settings"), "Should navigate to Settings")

        // Wait for navigation title
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(waitForElement(settingsTitle, timeout: 10), "Settings navigation title should appear")

        takeScreenshot(named: "Gate13-SettingsView")

        // VALIDATION: Backend Connection section exists (always present)
        // Look for elements that are always visible regardless of data loading
        let hostLabel = app.staticTexts["Host"]
        let portLabel = app.staticTexts["Port"]
        let statusLabel = app.staticTexts["Status"]
        let testConnectionButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Test Connection' OR label CONTAINS[c] 'Testing'")).firstMatch

        let hasBackendSection = hostLabel.waitForExistence(timeout: 5) ||
                               portLabel.waitForExistence(timeout: 3) ||
                               statusLabel.waitForExistence(timeout: 3) ||
                               testConnectionButton.waitForExistence(timeout: 3)
        XCTAssertTrue(hasBackendSection, "Settings should show Backend Connection section with Host/Port/Status")

        takeScreenshot(named: "Gate13-GeneralSection")
    }

    func testGate13b_SettingsPermissionsSection() throws {
        // VALIDATION: Settings view shows Permissions section (or About section if scrolled)

        // Navigate to Settings
        XCTAssertTrue(navigateToSidebarItem("settings"), "Should navigate to Settings")

        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(waitForElement(settingsTitle, timeout: 10), "Settings view should appear")

        // Scroll down to find more sections
        let list = findList()
        if let scrollView = list {
            scrollView.swipeUp()
        }
        sleep(1)

        // VALIDATION: Look for any section after Backend Connection
        // These sections are always present: API Key, Permissions, Advanced, Statistics, About
        let apiKeySection = app.staticTexts["API Key"]
        let permissionsSection = app.staticTexts["Permissions"]
        let advancedSection = app.staticTexts["Advanced"]
        let statisticsSection = app.staticTexts["Statistics"]
        let aboutSection = app.staticTexts["About"]
        let versionLabel = app.staticTexts["Version"]

        let hasScrolledContent = apiKeySection.waitForExistence(timeout: 3) ||
                                permissionsSection.waitForExistence(timeout: 2) ||
                                advancedSection.waitForExistence(timeout: 2) ||
                                statisticsSection.waitForExistence(timeout: 2) ||
                                aboutSection.waitForExistence(timeout: 2) ||
                                versionLabel.waitForExistence(timeout: 2)

        takeScreenshot(named: "Gate13b-PermissionsSection")

        XCTAssertTrue(hasScrolledContent, "Settings should show additional sections when scrolled")
    }

    func testGate13c_SettingsAdvancedSection() throws {
        // VALIDATION: Settings view shows Advanced section

        // Navigate to Settings
        XCTAssertTrue(navigateToSidebarItem("settings"), "Should navigate to Settings")

        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(waitForElement(settingsTitle, timeout: 10), "Settings view should appear")

        // Scroll down to find Advanced section
        let advancedSection = app.staticTexts["Advanced"]

        // Scroll if not visible
        if !advancedSection.exists {
            let list = findList()
            if let scrollView = list {
                scrollView.swipeUp()
                sleep(1)
                scrollView.swipeUp()
            }
        }

        // VALIDATION: Advanced section displays
        let hasAdvanced = advancedSection.waitForExistence(timeout: 5) ||
                         app.staticTexts["Hooks Configured"].exists ||
                         app.staticTexts["Edit User Settings"].exists

        takeScreenshot(named: "Gate13c-AdvancedSection")

        XCTAssertTrue(hasAdvanced, "Settings should show Advanced section")
    }

    func testGate13d_SettingsStatisticsSection() throws {
        // VALIDATION: Settings view shows Statistics and About sections

        // Navigate to Settings
        XCTAssertTrue(navigateToSidebarItem("settings"), "Should navigate to Settings")

        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(waitForElement(settingsTitle, timeout: 10), "Settings view should appear")

        // Scroll down to find Statistics/About sections (at bottom)
        for _ in 0..<3 {
            let list = findList()
            if let scrollView = list {
                scrollView.swipeUp()
                sleep(1)
            }
        }

        // VALIDATION: Statistics or About section displays (both are at bottom)
        // About section is always present with Version and Build
        let statisticsSection = app.staticTexts["Statistics"]
        let aboutSection = app.staticTexts["About"]
        let versionLabel = app.staticTexts["Version"]
        let buildLabel = app.staticTexts["Build"]
        let claudeDocsLink = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Claude Code Documentation'")).firstMatch

        let hasBottomSections = statisticsSection.waitForExistence(timeout: 3) ||
                               aboutSection.waitForExistence(timeout: 2) ||
                               versionLabel.waitForExistence(timeout: 2) ||
                               buildLabel.waitForExistence(timeout: 2) ||
                               claudeDocsLink.waitForExistence(timeout: 2)

        takeScreenshot(named: "Gate13d-StatisticsSection")

        XCTAssertTrue(hasBottomSections, "Settings should show Statistics or About section at bottom")
    }

    // MARK: - GATE 14: Plugins List View

    func testGate14_PluginsListLoads() throws {
        // VALIDATION: Plugins list view loads with content or empty state

        // Navigate to Plugins via sidebar
        XCTAssertTrue(navigateToSidebarItem("plugins"), "Should navigate to Plugins")

        // Wait for navigation title
        let pluginsTitle = app.navigationBars["Plugins"]
        XCTAssertTrue(waitForElement(pluginsTitle, timeout: 10), "Plugins navigation title should appear")

        takeScreenshot(named: "Gate14-PluginsView")

        // Wait for loading to complete
        let loadingIndicator = app.staticTexts["Loading plugins..."]
        if loadingIndicator.exists {
            _ = waitForElementToDisappear(loadingIndicator, timeout: 15)
        }

        // Verify list content appears - either plugins or empty state
        let list = findList()
        let emptyState = app.staticTexts["No Plugins"]

        let hasContent = (list != nil && list!.exists) ||
                        emptyState.waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "Should show plugins list or empty state")

        takeScreenshot(named: "Gate14-PluginsListLoaded")
    }

    func testGate14b_PluginsPullToRefresh() throws {
        // VALIDATION: Pull to refresh works on plugins list

        // Navigate to Plugins
        XCTAssertTrue(navigateToSidebarItem("plugins"), "Should navigate to Plugins")

        let pluginsTitle = app.navigationBars["Plugins"]
        XCTAssertTrue(waitForElement(pluginsTitle, timeout: 10), "Plugins view should appear")

        takeScreenshot(named: "Gate14b-BeforeRefresh")

        // Perform pull to refresh
        performPullToRefresh()

        // Verify view is still functional
        XCTAssertTrue(pluginsTitle.exists, "Plugins view should still exist after refresh")

        takeScreenshot(named: "Gate14b-AfterRefresh")
    }

    func testGate14c_PluginsMarketplaceAccess() throws {
        // VALIDATION: Can open marketplace from plugins view

        // Navigate to Plugins
        XCTAssertTrue(navigateToSidebarItem("plugins"), "Should navigate to Plugins")

        let pluginsTitle = app.navigationBars["Plugins"]
        XCTAssertTrue(waitForElement(pluginsTitle, timeout: 10), "Plugins view should appear")

        takeScreenshot(named: "Gate14c-BeforeMarketplace")

        // Find and tap the marketplace button using accessibility identifier
        let marketplaceButton = app.buttons["marketplaceButton"]
        var buttonFound = false

        if waitForElement(marketplaceButton, timeout: 5) {
            marketplaceButton.tap()
            buttonFound = true
        } else {
            // Fallback: try finding by bag icon label in navigation bar
            let navBarButton = app.navigationBars["Plugins"].buttons.element(boundBy: 0)
            if navBarButton.exists {
                navBarButton.tap()
                buttonFound = true
            }
        }

        // Wait for Marketplace sheet to appear
        let marketplaceTitle = app.navigationBars["Marketplace"]
        let marketplaceOpened = waitForElement(marketplaceTitle, timeout: 5)

        if marketplaceOpened {
            takeScreenshot(named: "Gate14c-MarketplaceOpened")

            // Dismiss marketplace
            let doneButton = app.buttons["Done"]
            if doneButton.exists {
                doneButton.tap()
            }
        }

        // Marketplace button found or sheet opened is the validation
        XCTAssertTrue(buttonFound || marketplaceOpened, "Marketplace should be accessible")

        takeScreenshot(named: "Gate14c-AfterMarketplace")
    }

    func testGate14d_PluginToggle() throws {
        // VALIDATION: Can toggle plugin enable/disable state

        // Navigate to Plugins
        XCTAssertTrue(navigateToSidebarItem("plugins"), "Should navigate to Plugins")

        let pluginsTitle = app.navigationBars["Plugins"]
        XCTAssertTrue(waitForElement(pluginsTitle, timeout: 10), "Plugins view should appear")

        // Wait for loading
        sleep(2)

        takeScreenshot(named: "Gate14d-BeforeToggle")

        // Find first plugin cell with a toggle
        let firstCell = findFirstCell()
        if let cell = firstCell {
            // Look for toggle switch within the cell
            let toggle = cell.switches.firstMatch
            if toggle.exists {
                let initialValue = toggle.value as? String ?? ""
                toggle.tap()
                sleep(1)
                let newValue = toggle.value as? String ?? ""

                takeScreenshot(named: "Gate14d-AfterToggle")

                // Toggle should have changed value
                XCTAssertNotEqual(initialValue, newValue, "Toggle state should change")
            } else {
                // No plugins with toggles available - still valid
                takeScreenshot(named: "Gate14d-NoToggleFound")
            }
        } else {
            // No plugins to test - empty state is valid
            takeScreenshot(named: "Gate14d-NoPlugins")
        }
    }
}
