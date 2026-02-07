import XCTest

/// SCENARIO 5: Project Management
/// Tests creating projects, linking to sessions, viewing project details,
/// and managing project-session relationships
final class Scenario05_ProjectManagement: XCUITestBase {
    
    func testProjectManagement() throws {
        app.launch()
        takeScreenshot(named: "S05_01_launched")
        
        // Navigate to Projects section
        navigateToSection(.projects)
        takeScreenshot(named: "S05_02_projects_section")
        
        waitForLoadingToComplete()
        let projectsList = app.collectionViews.firstMatch
        waitForElement(projectsList, timeout: 10)
        
        let initialProjectCount = projectsList.cells.count
        takeScreenshot(named: "S05_03_projects_loaded")
        
        // Test 1: Create new project
        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Create'")).firstMatch
        if createButton.exists {
            tapElement(createButton)
            takeScreenshot(named: "S05_04_create_project_sheet")
            
            // Fill in project details
            let nameField = app.textFields["projectNameField"]
            if nameField.exists {
                typeText("Test Project UI", into: nameField)
            }
            
            let pathField = app.textFields["projectPathField"]
            if pathField.exists {
                typeText("/Users/test/project", into: pathField)
            }
            
            let saveButton = app.buttons["saveButton"]
            if saveButton.exists {
                tapElement(saveButton)
                Thread.sleep(forTimeInterval: 2)
                takeScreenshot(named: "S05_05_project_created")
            }
        }
        
        // Test 2: Verify new project appears
        waitForLoadingToComplete()
        Thread.sleep(forTimeInterval: 1)
        
        let updatedProjectCount = projectsList.cells.count
        XCTAssertGreaterThan(updatedProjectCount, initialProjectCount,
                            "Should have more projects after creation")
        takeScreenshot(named: "S05_06_project_in_list")
        
        // Test 3: Tap on project to view details
        let newProject = projectsList.cells.firstMatch
        tapElement(newProject)
        takeScreenshot(named: "S05_07_project_details")
        
        // Verify project details view
        Thread.sleep(forTimeInterval: 1)
        assertTextExists("Sessions", timeout: 5)
        assertTextExists("Path", timeout: 3)
        takeScreenshot(named: "S05_08_details_loaded")
        
        // Test 4: View project sessions
        let sessionsTab = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Sessions'")).firstMatch
        if sessionsTab.exists {
            tapElement(sessionsTab)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S05_09_project_sessions")
        }
        
        // Test 5: Go back and search for project
        app.navigationBars.buttons.firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "S05_10_back_to_list")
        
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            typeText("Test Project", into: searchField)
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S05_11_search_results")
            
            // Verify filtered results
            let visibleCells = projectsList.cells
            XCTAssertGreaterThan(visibleCells.count, 0, "Search should show results")
            
            // Clear search
            let clearButton = searchField.buttons["Clear text"]
            if clearButton.exists {
                clearButton.tap()
            }
        }
        
        // Test 6: Test project context menu (if available)
        if newProject.exists {
            newProject.press(forDuration: 1.0)
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S05_12_context_menu")
            
            // Dismiss context menu
            let background = app.otherElements.firstMatch
            background.tap()
        }
        
        takeScreenshot(named: "S05_13_test_complete")
        print("✅ Scenario 5: Project Management - PASSED")
    }
}
