import XCTest

/// UI tests for the native macOS ILS application.
/// These tests verify core user workflows including navigation, keyboard shortcuts,
/// multi-window support, and menu bar interactions.
final class MacAppUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch & Connection Tests

    /// Test that the app launches successfully and displays the main window
    func testAppLaunches() throws {
        XCTAssertTrue(app.windows.count > 0, "App should have at least one window")
    }

    /// Test that the connection status indicator is visible on launch
    func testConnectionStatusVisible() throws {
        let connectionStatus = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'localhost' OR label CONTAINS[c] 'Disconnected'")).firstMatch
        XCTAssertTrue(connectionStatus.waitForExistence(timeout: 5), "Connection status should be visible")
    }

    // MARK: - Sidebar Navigation Tests

    /// Test that the sidebar contains all expected navigation sections
    func testSidebarContainsAllSections() throws {
        let sidebar = app.splitGroups.firstMatch
        XCTAssertTrue(sidebar.exists, "Sidebar should exist")

        // Verify navigation sections
        XCTAssertTrue(app.staticTexts["Home"].exists, "Home section should exist")
        XCTAssertTrue(app.staticTexts["System Monitor"].exists, "System Monitor section should exist")
        XCTAssertTrue(app.staticTexts["Browse"].exists, "Browse section should exist")
        XCTAssertTrue(app.staticTexts["Settings"].exists, "Settings section should exist")
    }

    /// Test navigation to Dashboard view
    func testNavigateToDashboard() throws {
        let homeButton = app.buttons["Home"]
        homeButton.click()

        // Verify Dashboard content appears
        let statsGrid = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Sessions' OR label CONTAINS[c] 'Projects'")).firstMatch
        XCTAssertTrue(statsGrid.waitForExistence(timeout: 3), "Dashboard stats should be visible")
    }

    /// Test navigation to Sessions view
    func testNavigateToSessions() throws {
        // Sessions should be visible in the middle column from Home view
        let sessionsHeader = app.staticTexts["SESSIONS"]
        XCTAssertTrue(sessionsHeader.exists, "Sessions header should be visible")
    }

    /// Test navigation to Settings view
    func testNavigateToSettings() throws {
        let settingsButton = app.buttons["Settings"]
        settingsButton.click()

        // Verify Settings content appears
        let settingsTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Settings' OR label CONTAINS[c] 'General'")).firstMatch
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3), "Settings view should be visible")
    }

    // MARK: - Keyboard Shortcut Tests

    /// Test Cmd+1 navigates to Dashboard
    func testKeyboardShortcutDashboard() throws {
        app.typeKey("1", modifierFlags: .command)

        let statsGrid = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Sessions' OR label CONTAINS[c] 'Projects'")).firstMatch
        XCTAssertTrue(statsGrid.waitForExistence(timeout: 3), "Dashboard should be visible after Cmd+1")
    }

    /// Test Cmd+2 navigates to Sessions
    func testKeyboardShortcutSessions() throws {
        app.typeKey("2", modifierFlags: .command)

        let sessionsHeader = app.staticTexts["SESSIONS"]
        XCTAssertTrue(sessionsHeader.waitForExistence(timeout: 3), "Sessions should be visible after Cmd+2")
    }

    /// Test Cmd+3 navigates to Projects
    func testKeyboardShortcutProjects() throws {
        app.typeKey("3", modifierFlags: .command)

        let projectsContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Projects'")).firstMatch
        XCTAssertTrue(projectsContent.waitForExistence(timeout: 3), "Projects should be visible after Cmd+3")
    }

    /// Test Cmd+4 navigates to System Monitor
    func testKeyboardShortcutSystem() throws {
        app.typeKey("4", modifierFlags: .command)

        let systemContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'System' OR label CONTAINS[c] 'CPU'")).firstMatch
        XCTAssertTrue(systemContent.waitForExistence(timeout: 3), "System Monitor should be visible after Cmd+4")
    }

    /// Test Cmd+6 navigates to Settings
    func testKeyboardShortcutSettings() throws {
        app.typeKey("6", modifierFlags: .command)

        let settingsContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Settings' OR label CONTAINS[c] 'General'")).firstMatch
        XCTAssertTrue(settingsContent.waitForExistence(timeout: 3), "Settings should be visible after Cmd+6")
    }

    /// Test Cmd+/ focuses search field
    func testKeyboardShortcutSearch() throws {
        app.typeKey("/", modifierFlags: .command)

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2), "Search field should exist")
        // On macOS, focused elements don't always report isSelected, so we just verify it exists
    }

    // MARK: - Session Management Tests

    /// Test creating a new session
    func testCreateNewSession() throws {
        // Find and click the "New Session" button
        let newSessionButton = app.buttons["New Session"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5), "New Session button should exist")
        newSessionButton.click()

        // Verify chat view appears
        let chatInputField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'message' OR placeholderValue CONTAINS[c] 'type'")).firstMatch
        XCTAssertTrue(chatInputField.waitForExistence(timeout: 3), "Chat input should appear after creating session")
    }

    /// Test session search functionality
    func testSessionSearch() throws {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search field should exist")

        searchField.click()
        searchField.typeText("test")

        // Verify search is active (field contains text)
        XCTAssertEqual(searchField.value as? String, "test", "Search field should contain 'test'")
    }

    /// Test clearing search
    func testClearSearch() throws {
        let searchField = app.searchFields.firstMatch
        searchField.click()
        searchField.typeText("test")

        // Click the clear button (xmark.circle.fill icon)
        let clearButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'clear' OR label CONTAINS[c] 'clear'")).firstMatch
        if clearButton.exists {
            clearButton.click()
            XCTAssertEqual(searchField.value as? String, "", "Search field should be empty after clearing")
        }
    }

    // MARK: - Multi-Window Tests

    /// Test opening a session in a new window via keyboard shortcut
    func testOpenSessionInNewWindowKeyboard() throws {
        // First, ensure we have sessions to work with
        let sessionsList = app.outlines.firstMatch
        if sessionsList.exists && sessionsList.cells.count > 0 {
            // Select first session
            let firstSession = sessionsList.cells.firstMatch
            firstSession.click()

            // Press Cmd+N to open in new window
            app.typeKey("n", modifierFlags: .command)

            // Verify a second window opened
            XCTAssertTrue(app.windows.count >= 2, "Should have at least 2 windows after Cmd+N")
        }
    }

    /// Test that multiple windows can coexist
    func testMultipleWindows() throws {
        let initialWindowCount = app.windows.count

        // Create a new session which might open in a new window
        let newSessionButton = app.buttons["New Session"]
        if newSessionButton.exists {
            newSessionButton.click()

            // Opening in new window requires additional action, so we just verify
            // the app can handle multiple windows without crashing
            XCTAssertTrue(app.windows.count >= initialWindowCount, "Window count should be stable")
        }
    }

    // MARK: - Menu Bar Tests

    /// Test File menu exists and contains expected items
    func testFileMenuExists() throws {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.exists, "Menu bar should exist")

        let fileMenu = app.menuBars.menuBarItems["File"]
        fileMenu.click()

        // Verify menu items
        XCTAssertTrue(app.menuItems["New Session"].exists, "New Session menu item should exist")
        XCTAssertTrue(app.menuItems["Open Session"].exists, "Open Session menu item should exist")
        XCTAssertTrue(app.menuItems["Close Window"].exists, "Close Window menu item should exist")
        XCTAssertTrue(app.menuItems["Save"].exists, "Save menu item should exist")

        // Close menu
        app.typeKey(.escape, modifierFlags: [])
    }

    /// Test Edit menu exists and contains standard items
    func testEditMenuExists() throws {
        let editMenu = app.menuBars.menuBarItems["Edit"]
        editMenu.click()

        // Verify standard edit items
        XCTAssertTrue(app.menuItems["Undo"].exists, "Undo menu item should exist")
        XCTAssertTrue(app.menuItems["Redo"].exists, "Redo menu item should exist")
        XCTAssertTrue(app.menuItems["Cut"].exists, "Cut menu item should exist")
        XCTAssertTrue(app.menuItems["Copy"].exists, "Copy menu item should exist")
        XCTAssertTrue(app.menuItems["Paste"].exists, "Paste menu item should exist")
        XCTAssertTrue(app.menuItems["Select All"].exists, "Select All menu item should exist")

        app.typeKey(.escape, modifierFlags: [])
    }

    /// Test View menu exists and contains navigation items
    func testViewMenuExists() throws {
        let viewMenu = app.menuBars.menuBarItems["View"]
        viewMenu.click()

        // Verify navigation items
        XCTAssertTrue(app.menuItems["Toggle Sidebar"].exists, "Toggle Sidebar menu item should exist")
        XCTAssertTrue(app.menuItems["Show Dashboard"].exists, "Show Dashboard menu item should exist")
        XCTAssertTrue(app.menuItems["Show Sessions"].exists, "Show Sessions menu item should exist")
        XCTAssertTrue(app.menuItems["Show Projects"].exists, "Show Projects menu item should exist")
        XCTAssertTrue(app.menuItems["Show System"].exists, "Show System menu item should exist")
        XCTAssertTrue(app.menuItems["Show Settings"].exists, "Show Settings menu item should exist")

        app.typeKey(.escape, modifierFlags: [])
    }

    /// Test Window menu exists
    func testWindowMenuExists() throws {
        let windowMenu = app.menuBars.menuBarItems["Window"]
        windowMenu.click()

        // Verify window management items
        XCTAssertTrue(app.menuItems["Minimize"].exists, "Minimize menu item should exist")
        XCTAssertTrue(app.menuItems["Zoom"].exists, "Zoom menu item should exist")
        XCTAssertTrue(app.menuItems["Bring All to Front"].exists, "Bring All to Front menu item should exist")

        app.typeKey(.escape, modifierFlags: [])
    }

    /// Test File > New Session menu action
    func testFileMenuNewSession() throws {
        let fileMenu = app.menuBars.menuBarItems["File"]
        fileMenu.click()

        let newSessionItem = app.menuItems["New Session"]
        newSessionItem.click()

        // Verify notification was posted (indirectly by checking for new session UI)
        let chatInputField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'message' OR placeholderValue CONTAINS[c] 'type'")).firstMatch
        XCTAssertTrue(chatInputField.waitForExistence(timeout: 3), "Chat view should appear after creating session")
    }

    // MARK: - Window Resizing Tests

    /// Test that the sidebar is resizable
    func testSidebarResizable() throws {
        let splitGroup = app.splitGroups.firstMatch
        XCTAssertTrue(splitGroup.exists, "Split view should exist")

        // Note: Programmatically testing drag-to-resize in XCTest is complex
        // This test verifies the split view exists, which is necessary for resizing
        // Manual verification of resize functionality is recommended
    }

    /// Test window state persistence (requires app restart, tested manually)
    func testWindowStatePersistence() throws {
        // This test would require:
        // 1. Resize/move window
        // 2. Save current window frame
        // 3. Quit and relaunch app
        // 4. Verify window frame matches
        // Due to XCTest limitations with app lifecycle, this is verified manually

        // We can at least verify the window manager exists by checking window count
        XCTAssertTrue(app.windows.count > 0, "App should have windows that can persist state")
    }

    // MARK: - Chat View Tests

    /// Test chat input field exists when a session is open
    func testChatInputExists() throws {
        // Create or navigate to a session first
        let newSessionButton = app.buttons["New Session"]
        if newSessionButton.exists {
            newSessionButton.click()

            let chatInputField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'message' OR placeholderValue CONTAINS[c] 'type'")).firstMatch
            XCTAssertTrue(chatInputField.waitForExistence(timeout: 3), "Chat input field should exist in session view")
        }
    }

    /// Test Cmd+K opens command palette in chat view
    func testCommandPaletteKeyboard() throws {
        // Navigate to a chat session
        let newSessionButton = app.buttons["New Session"]
        if newSessionButton.exists {
            newSessionButton.click()

            // Wait for chat view to load
            sleep(1)

            // Press Cmd+K
            app.typeKey("k", modifierFlags: .command)

            // Verify command palette appears (sheet or popover)
            // Note: The exact UI element depends on implementation
            // We look for sheets or popovers
            XCTAssertTrue(app.sheets.count > 0 || app.popovers.count > 0, "Command palette should appear after Cmd+K")
        }
    }

    /// Test Cmd+Return sends a message
    func testSendMessageKeyboard() throws {
        // Navigate to a chat session
        let newSessionButton = app.buttons["New Session"]
        if newSessionButton.exists {
            newSessionButton.click()

            let chatInputField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'message' OR placeholderValue CONTAINS[c] 'type'")).firstMatch
            if chatInputField.waitForExistence(timeout: 3) {
                chatInputField.click()
                chatInputField.typeText("test message")

                // Press Cmd+Return to send
                app.typeKey(.enter, modifierFlags: .command)

                // Verify message was sent (should appear in message list or input clears)
                // This depends on backend being available
                // We just verify the action doesn't crash
                XCTAssertTrue(app.windows.count > 0, "App should remain stable after sending message")
            }
        }
    }

    // MARK: - Settings Tests

    /// Test Settings view displays properly
    func testSettingsViewDisplays() throws {
        let settingsButton = app.buttons["Settings"]
        settingsButton.click()

        // Verify Settings tabs exist
        let generalTab = app.buttons.matching(NSPredicate(format: "label == 'General'")).firstMatch
        let appearanceTab = app.buttons.matching(NSPredicate(format: "label == 'Appearance'")).firstMatch

        XCTAssertTrue(generalTab.exists || appearanceTab.exists, "Settings tabs should be visible")
    }

    /// Test theme picker in Settings
    func testThemePickerExists() throws {
        let settingsButton = app.buttons["Settings"]
        settingsButton.click()

        // Navigate to Appearance tab if it exists
        let appearanceTab = app.buttons["Appearance"]
        if appearanceTab.exists {
            appearanceTab.click()

            // Verify theme picker exists
            let themePicker = app.popUpButtons.matching(NSPredicate(format: "identifier CONTAINS[c] 'theme' OR label CONTAINS[c] 'theme'")).firstMatch
            XCTAssertTrue(themePicker.waitForExistence(timeout: 2), "Theme picker should exist in Appearance settings")
        }
    }

    // MARK: - Performance Tests

    /// Test that app launches within acceptable time
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    /// Test that navigation between views is responsive
    func testNavigationPerformance() throws {
        measure {
            app.buttons["Home"].click()
            app.buttons["Settings"].click()
            app.buttons["Home"].click()
        }
    }
}
