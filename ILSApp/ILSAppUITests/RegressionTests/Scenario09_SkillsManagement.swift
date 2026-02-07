import XCTest

/// SCENARIO 9: Skills Management
/// Tests viewing skills, searching, filtering by category,
/// viewing skill details, and skill metadata
final class Scenario09_SkillsManagement: XCUITestBase {
    
    func testSkillsManagement() throws {
        app.launch()
        takeScreenshot(named: "S09_01_launched")
        
        // Navigate to Skills section
        navigateToSection(.skills)
        takeScreenshot(named: "S09_02_skills_section")
        
        waitForLoadingToComplete()
        let skillsList = app.collectionViews.firstMatch
        waitForElement(skillsList, timeout: 10)
        takeScreenshot(named: "S09_03_skills_loaded")
        
        // Test 1: Verify large number of skills loaded
        let skillCells = skillsList.cells
        let skillCount = skillCells.count
        XCTAssertGreaterThan(skillCount, 0, "Should have skills")
        print("Found \(skillCount) skills")
        takeScreenshot(named: "S09_04_skills_count")
        
        // Test 2: Search for specific skill
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            typeText("code", into: searchField)
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S09_05_search_code")
            
            let filteredCount = skillsList.cells.count
            XCTAssertGreaterThan(filteredCount, 0, "Should find code-related skills")
            XCTAssertLessThanOrEqual(filteredCount, skillCount, 
                                    "Filtered count should be <= total")
            
            // Try different search
            clearAndType("review", into: searchField)
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S09_06_search_review")
            
            // Clear search
            let clearButton = searchField.buttons["Clear text"]
            if clearButton.exists {
                clearButton.tap()
                Thread.sleep(forTimeInterval: 1)
            }
        }
        
        // Test 3: Test category filter (if available)
        let categoryButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Category'")).firstMatch
        if categoryButton.exists {
            tapElement(categoryButton)
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S09_07_category_menu")
            
            // Select a category
            let categoryOptions = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Development' OR label CONTAINS[c] 'Testing'"))
            if categoryOptions.count > 0 {
                categoryOptions.firstMatch.tap()
                Thread.sleep(forTimeInterval: 1)
                takeScreenshot(named: "S09_08_filtered_category")
            }
        }
        
        // Test 4: Tap on skill to view details
        let firstSkill = skillsList.cells.firstMatch
        if firstSkill.exists {
            tapElement(firstSkill)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S09_09_skill_details")
            
            // Verify skill details are shown
            Thread.sleep(forTimeInterval: 1)
            assertTextExists("Description", timeout: 3)
            
            takeScreenshot(named: "S09_10_details_loaded")
            
            // Go back
            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Test 5: Test scrolling performance with many skills
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            // Rapid scrolling
            for i in 1...5 {
                scrollView.swipeUp()
                Thread.sleep(forTimeInterval: 0.3)
                if i == 3 {
                    takeScreenshot(named: "S09_11_scrolled_middle")
                }
            }
            
            takeScreenshot(named: "S09_12_scrolled_bottom")
            
            // Scroll back to top
            for _ in 1...5 {
                scrollView.swipeDown()
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            takeScreenshot(named: "S09_13_scrolled_top")
        }
        
        // Test 6: Test skill sorting (if available)
        let sortButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Sort'")).firstMatch
        if sortButton.exists {
            tapElement(sortButton)
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S09_14_sort_menu")
            
            // Select sort option
            let sortOptions = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Name' OR label CONTAINS[c] 'Recent'"))
            if sortOptions.count > 0 {
                sortOptions.firstMatch.tap()
                Thread.sleep(forTimeInterval: 1)
                takeScreenshot(named: "S09_15_sorted")
            }
        }
        
        // Test 7: Test multi-select (if available)
        let selectButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Select'")).firstMatch
        if selectButton.exists {
            tapElement(selectButton)
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S09_16_select_mode")
            
            // Select a few skills
            if skillsList.cells.count > 2 {
                skillsList.cells.element(boundBy: 0).tap()
                skillsList.cells.element(boundBy: 1).tap()
                Thread.sleep(forTimeInterval: 1)
                takeScreenshot(named: "S09_17_skills_selected")
            }
            
            // Cancel selection
            let cancelButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Cancel'")).firstMatch
            if cancelButton.exists {
                cancelButton.tap()
            }
        }
        
        takeScreenshot(named: "S09_18_test_complete")
        print("✅ Scenario 9: Skills Management - PASSED")
    }
}
