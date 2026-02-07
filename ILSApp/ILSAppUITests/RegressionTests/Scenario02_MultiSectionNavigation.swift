import XCTest

/// SCENARIO 2: Multi-Section Navigation
/// Tests navigating through all major sections, verifying data loads,
/// and testing search functionality in each section
final class Scenario02_MultiSectionNavigation: XCUITestBase {
    
    func testMultiSectionNavigation() throws {
        app.launch()
        takeScreenshot(named: "S02_01_launched")
        
        // Section 1: Dashboard
        navigateToSection(.dashboard)
        takeScreenshot(named: "S02_02_dashboard")
        waitForLoadingToComplete()
        
        // Verify dashboard stats load
        assertTextExists("Sessions", timeout: 5)
        assertTextExists("Projects", timeout: 3)
        takeScreenshot(named: "S02_03_dashboard_loaded")
        
        // Section 2: Projects
        navigateToSection(.projects)
        takeScreenshot(named: "S02_04_projects")
        waitForLoadingToComplete()
        
        let projectsList = app.collectionViews.firstMatch
        XCTAssertTrue(waitForElement(projectsList, timeout: 10))
        takeScreenshot(named: "S02_05_projects_loaded")
        
        // Test project search
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            typeText("test", into: searchField)
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S02_06_projects_search")
            
            // Clear search
            let clearButton = searchField.buttons["Clear text"]
            if clearButton.exists {
                clearButton.tap()
            }
        }
        
        // Section 3: Skills
        navigateToSection(.skills)
        takeScreenshot(named: "S02_07_skills")
        waitForLoadingToComplete()
        
        let skillsList = app.collectionViews.firstMatch
        XCTAssertTrue(waitForElement(skillsList, timeout: 10))
        takeScreenshot(named: "S02_08_skills_loaded")
        
        // Test skills search
        if searchField.exists {
            typeText("code", into: searchField)
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S02_09_skills_search")
        }
        
        // Section 4: Plugins
        navigateToSection(.plugins)
        takeScreenshot(named: "S02_10_plugins")
        waitForLoadingToComplete()
        takeScreenshot(named: "S02_11_plugins_loaded")
        
        // Section 5: MCP Servers
        navigateToSection(.mcp)
        takeScreenshot(named: "S02_12_mcp")
        waitForLoadingToComplete()
        takeScreenshot(named: "S02_13_mcp_loaded")
        
        // Section 6: Settings
        navigateToSection(.settings)
        takeScreenshot(named: "S02_14_settings")
        
        // Verify settings sections exist
        assertTextExists("Server Configuration", timeout: 5)
        assertTextExists("Appearance", timeout: 3)
        takeScreenshot(named: "S02_15_settings_loaded")
        
        // Section 7: Back to Sessions
        navigateToSection(.sessions)
        takeScreenshot(named: "S02_16_back_to_sessions")
        
        let sessionsList = app.collectionViews.firstMatch
        XCTAssertTrue(waitForElement(sessionsList, timeout: 5))
        takeScreenshot(named: "S02_17_test_complete")
        
        print("✅ Scenario 2: Multi-Section Navigation - PASSED")
    }
}
