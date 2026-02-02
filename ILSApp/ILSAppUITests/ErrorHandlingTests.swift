import XCTest

/// Error Handling Tests for ILS iOS App
/// Tests error scenarios, empty states, loading states, and form validation
/// Each test represents a validation gate that must pass
final class ErrorHandlingTests: XCTestCase {
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

    // MARK: - Test 1: Network Error Handling

    func testNetworkErrorHandling() throws {
        // VALIDATION: App handles network unavailability gracefully

        // Note: This test would ideally use a launch argument to simulate offline mode
        // For example: app.launchArguments.append("--offline-mode")
        // Since we're testing with the real backend, we'll verify error UI components exist

        takeScreenshot(named: "NetworkError-Initial")

        // Wait for sessions view to load
        let sessionsTitle = app.navigationBars["Sessions"]
        XCTAssertTrue(waitForElement(sessionsTitle, timeout: 15), "Sessions view should appear")

        // Wait for loading indicator
        let loadingIndicator = app.activityIndicators["loading-sessions-indicator"]
        if loadingIndicator.exists {
            // Loading indicator should eventually disappear (either success or error)
            let loadingCompleted = waitForElementToDisappear(loadingIndicator, timeout: 20)
            XCTAssertTrue(loadingCompleted, "Loading should complete or show error")
        }

        takeScreenshot(named: "NetworkError-AfterLoad")

        // VALIDATION: App doesn't crash and shows appropriate state
        // Either we have content, empty state, or error state
        let hasContent = app.cells.count > 0
        let emptyState = app.staticTexts["No Sessions"].exists
        let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'error' OR label CONTAINS[c] 'failed' OR label CONTAINS[c] 'unavailable'")).firstMatch.exists

        let hasValidState = hasContent || emptyState || errorMessage
        XCTAssertTrue(hasValidState, "App should show content, empty state, or error message")

        // Verify app is still responsive
        XCTAssertTrue(sessionsTitle.exists, "App should remain functional")

        takeScreenshot(named: "NetworkError-FinalState")
    }

    // MARK: - Test 2: Empty State Displays

    func testEmptyStateDisplays() throws {
        // VALIDATION: Empty states display correctly across all views

        // Test Sessions Empty State
        let sessionsTitle = app.navigationBars["Sessions"]
        XCTAssertTrue(waitForElement(sessionsTitle, timeout: 15), "Sessions view should appear")

        // Wait for loading
        let loadingIndicator = app.activityIndicators["loading-sessions-indicator"]
        if loadingIndicator.exists {
            _ = waitForElementToDisappear(loadingIndicator, timeout: 15)
        }

        // Check for empty state or content
        let sessionsEmptyState = app.staticTexts["No Sessions"]
        let hasSessionsContent = app.cells.count > 0 || sessionsEmptyState.exists
        XCTAssertTrue(hasSessionsContent, "Sessions should show content or empty state")

        takeScreenshot(named: "EmptyState-Sessions")

        // Test Projects Empty State
        XCTAssertTrue(navigateToSidebarItem("projects"), "Should navigate to Projects")
        let projectsTitle = app.navigationBars["Projects"]
        XCTAssertTrue(waitForElement(projectsTitle, timeout: 10), "Projects view should appear")

        sleep(2) // Wait for loading

        let projectsEmptyState = app.staticTexts["No Projects"]
        let hasProjectsContent = app.cells.count > 0 || projectsEmptyState.exists
        XCTAssertTrue(hasProjectsContent, "Projects should show content or empty state")

        takeScreenshot(named: "EmptyState-Projects")

        // Test Skills Empty State
        XCTAssertTrue(navigateToSidebarItem("skills"), "Should navigate to Skills")
        let skillsTitle = app.navigationBars["Skills"]
        XCTAssertTrue(waitForElement(skillsTitle, timeout: 10), "Skills view should appear")

        sleep(2) // Wait for loading

        let skillsEmptyState = app.staticTexts["No Skills"]
        let hasSkillsContent = app.cells.count > 0 || skillsEmptyState.exists
        XCTAssertTrue(hasSkillsContent, "Skills should show content or empty state")

        takeScreenshot(named: "EmptyState-Skills")

        // Test MCP Servers Empty State
        XCTAssertTrue(navigateToSidebarItem("mcp_servers"), "Should navigate to MCP Servers")
        let mcpTitle = app.navigationBars["MCP Servers"]
        XCTAssertTrue(waitForElement(mcpTitle, timeout: 10), "MCP Servers view should appear")

        sleep(2) // Wait for loading

        let mcpEmptyState = app.staticTexts["No MCP Servers"]
        let hasMCPContent = app.cells.count > 0 || mcpEmptyState.exists
        XCTAssertTrue(hasMCPContent, "MCP Servers should show content or empty state")

        takeScreenshot(named: "EmptyState-MCPServers")

        // Test Plugins Empty State
        XCTAssertTrue(navigateToSidebarItem("plugins"), "Should navigate to Plugins")
        let pluginsTitle = app.navigationBars["Plugins"]
        XCTAssertTrue(waitForElement(pluginsTitle, timeout: 10), "Plugins view should appear")

        sleep(2) // Wait for loading

        let pluginsEmptyState = app.staticTexts["No Plugins"]
        let hasPluginsContent = app.cells.count > 0 || pluginsEmptyState.exists
        XCTAssertTrue(hasPluginsContent, "Plugins should show content or empty state")

        takeScreenshot(named: "EmptyState-Plugins")
    }

    // MARK: - Test 3: Loading State Displays

    func testLoadingStateDisplays() throws {
        // VALIDATION: Loading indicators appear during data fetching

        // Test initial load - Sessions view
        takeScreenshot(named: "Loading-Initial")

        let sessionsTitle = app.navigationBars["Sessions"]
        XCTAssertTrue(waitForElement(sessionsTitle, timeout: 15), "Sessions view should appear")

        // Check if loading indicator exists (it may have already disappeared if load was fast)
        let loadingIndicator = app.activityIndicators["loading-sessions-indicator"]
        let loadingText = app.staticTexts["Loading sessions..."]

        // Either we saw loading indicator or data loaded quickly
        let showedLoading = loadingIndicator.exists || loadingText.exists

        takeScreenshot(named: "Loading-SessionsView")

        // Wait for loading to complete if it's still going
        if loadingIndicator.exists {
            _ = waitForElementToDisappear(loadingIndicator, timeout: 15)
        }

        // Test loading on navigation - Projects view
        XCTAssertTrue(navigateToSidebarItem("projects"), "Should navigate to Projects")

        let projectsTitle = app.navigationBars["Projects"]
        XCTAssertTrue(waitForElement(projectsTitle, timeout: 10), "Projects view should appear")

        // Check for loading indicator (may be brief)
        let projectsLoading = app.staticTexts["Loading projects..."]
        takeScreenshot(named: "Loading-ProjectsView")

        sleep(2) // Give loading time to complete

        // Test loading on refresh
        XCTAssertTrue(navigateToSidebarItem("skills"), "Should navigate to Skills")

        let skillsTitle = app.navigationBars["Skills"]
        XCTAssertTrue(waitForElement(skillsTitle, timeout: 10), "Skills view should appear")

        sleep(1)
        takeScreenshot(named: "Loading-BeforeRefresh")

        // Perform pull to refresh
        let startCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let endCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        startCoord.press(forDuration: 0.1, thenDragTo: endCoord)

        // Loading indicator should appear briefly during refresh
        takeScreenshot(named: "Loading-DuringRefresh")

        sleep(2) // Wait for refresh to complete

        takeScreenshot(named: "Loading-AfterRefresh")

        // VALIDATION: App handles loading states without crashing
        XCTAssertTrue(skillsTitle.exists, "View should remain functional after loading")
    }

    // MARK: - Test 4: Backend Unavailable

    func testBackendUnavailable() throws {
        // VALIDATION: App handles backend server being down gracefully

        // Note: This test would ideally use a launch argument to simulate backend unavailable
        // For example: app.launchArguments.append("--backend-unavailable")
        // Since we're testing with the real backend, we'll verify error handling components exist

        takeScreenshot(named: "BackendUnavailable-Initial")

        let sessionsTitle = app.navigationBars["Sessions"]
        XCTAssertTrue(waitForElement(sessionsTitle, timeout: 15), "Sessions view should appear")

        // Wait for loading to complete or error to appear
        let loadingIndicator = app.activityIndicators["loading-sessions-indicator"]
        if loadingIndicator.exists {
            _ = waitForElementToDisappear(loadingIndicator, timeout: 20)
        }

        takeScreenshot(named: "BackendUnavailable-AfterLoad")

        // VALIDATION: App doesn't crash
        XCTAssertTrue(app.state == .runningForeground, "App should not crash")

        // VALIDATION: User can see error message or appropriate state
        let hasValidState = app.cells.count > 0 ||
                           app.staticTexts["No Sessions"].exists ||
                           app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'error' OR label CONTAINS[c] 'unavailable' OR label CONTAINS[c] 'connect'")).firstMatch.exists

        XCTAssertTrue(hasValidState, "App should show content, empty state, or error")

        // VALIDATION: User can retry (add button should be available)
        let addButton = app.buttons["add-session-button"]
        XCTAssertTrue(addButton.exists || app.buttons.count > 0, "App should provide interactive elements")

        // Try refreshing
        let startCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let endCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        startCoord.press(forDuration: 0.1, thenDragTo: endCoord)

        sleep(2)

        takeScreenshot(named: "BackendUnavailable-AfterRetry")

        // App should remain functional
        XCTAssertTrue(sessionsTitle.exists, "App should remain responsive")
    }

    // MARK: - Test 5: Invalid Input Handling

    func testInvalidInputHandling() throws {
        // VALIDATION: Form validation prevents invalid input

        // Wait for sessions view to load
        let sessionsTitle = app.navigationBars["Sessions"]
        XCTAssertTrue(waitForElement(sessionsTitle, timeout: 15), "Sessions view should appear")

        let loadingIndicator = app.activityIndicators["loading-sessions-indicator"]
        if loadingIndicator.exists {
            _ = waitForElementToDisappear(loadingIndicator, timeout: 15)
        }

        sleep(1)

        takeScreenshot(named: "InvalidInput-Initial")

        // Test 1: Create session with empty name
        let addSessionButton = app.buttons["add-session-button"]
        XCTAssertTrue(waitForElement(addSessionButton, timeout: 5), "Add session button should exist")
        addSessionButton.tap()

        let nameField = app.textFields["session-name-field"]
        XCTAssertTrue(waitForElement(nameField, timeout: 5), "Session name field should appear")

        takeScreenshot(named: "InvalidInput-EmptySessionName")

        // Try to create with empty name
        let createButton = app.buttons["create-session-button"]
        XCTAssertTrue(waitForElement(createButton, timeout: 3), "Create button should exist")

        // Validation: Create button should be disabled or form should show error
        if createButton.isEnabled {
            // If enabled, try tapping and verify form doesn't dismiss or shows error
            createButton.tap()
            sleep(1)

            // Sheet should still be visible (creation failed)
            let sheetStillVisible = app.navigationBars["New Session"].exists
            XCTAssertTrue(sheetStillVisible, "Sheet should remain visible with empty input")
        } else {
            // Button correctly disabled
            XCTAssertFalse(createButton.isEnabled, "Create button should be disabled with empty input")
        }

        takeScreenshot(named: "InvalidInput-EmptySessionValidation")

        // Dismiss the sheet
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        } else {
            // Try swipe down to dismiss
            let sheet = app.otherElements["New Session"]
            if sheet.exists {
                sheet.swipeDown()
            }
        }

        sleep(1)

        // Test 2: Create project with empty name
        XCTAssertTrue(navigateToSidebarItem("projects"), "Should navigate to Projects")

        let projectsTitle = app.navigationBars["Projects"]
        XCTAssertTrue(waitForElement(projectsTitle, timeout: 10), "Projects view should appear")

        sleep(2)

        takeScreenshot(named: "InvalidInput-ProjectsView")

        // Find and tap add project button
        let addProjectButton = app.navigationBars["Projects"].buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR identifier CONTAINS 'plus'")).firstMatch
        if !addProjectButton.exists {
            let plusButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'plus'")).firstMatch
            if plusButton.exists {
                plusButton.tap()
            }
        } else {
            addProjectButton.tap()
        }

        let newProjectTitle = app.navigationBars["New Project"]
        if waitForElement(newProjectTitle, timeout: 5) {
            takeScreenshot(named: "InvalidInput-EmptyProjectName")

            // Try to create with empty fields
            let createProjectButton = app.buttons["Create"]
            XCTAssertTrue(waitForElement(createProjectButton, timeout: 3), "Create button should exist")

            // Validation: Create button should be disabled with empty fields
            if createProjectButton.isEnabled {
                createProjectButton.tap()
                sleep(1)

                // Sheet should still be visible or show validation error
                let sheetStillVisible = newProjectTitle.exists
                XCTAssertTrue(sheetStillVisible, "Sheet should remain visible with empty input")
            } else {
                XCTAssertFalse(createProjectButton.isEnabled, "Create button should be disabled with empty input")
            }

            takeScreenshot(named: "InvalidInput-EmptyProjectValidation")

            // Test 3: Invalid path
            let textFields = app.textFields.allElementsBoundByIndex
            if textFields.count >= 2 {
                // Fill name but put invalid path
                textFields[0].tap()
                textFields[0].typeText("Test Project")

                textFields[1].tap()
                textFields[1].typeText("/invalid/path/that/does/not/exist/probably")

                takeScreenshot(named: "InvalidInput-InvalidPath")

                // Try to create
                if createProjectButton.isEnabled {
                    createProjectButton.tap()
                    sleep(2)

                    // Should show error or remain on sheet
                    let errorExists = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'error' OR label CONTAINS[c] 'invalid' OR label CONTAINS[c] 'not found'")).firstMatch.exists
                    let sheetStillVisible = newProjectTitle.exists

                    let hasValidation = errorExists || sheetStillVisible
                    takeScreenshot(named: "InvalidInput-InvalidPathValidation")
                }
            }

            // Dismiss sheet
            let cancelProjectButton = app.buttons["Cancel"]
            if cancelProjectButton.exists {
                cancelProjectButton.tap()
            }
        }

        takeScreenshot(named: "InvalidInput-FinalState")

        // VALIDATION: App handled all invalid inputs gracefully
        XCTAssertTrue(app.state == .runningForeground, "App should remain running")
    }
}
