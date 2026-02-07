import XCTest

/// SCENARIO 6: Plugin Operations
/// Tests viewing plugins, searching, enabling/disabling plugins,
/// and marketplace search
final class Scenario06_PluginOperations: XCUITestBase {
    
    func testPluginOperations() throws {
        app.launch()
        takeScreenshot(named: "S06_01_launched")
        
        // Navigate to Plugins section
        navigateToSection(.plugins)
        takeScreenshot(named: "S06_02_plugins_section")
        
        waitForLoadingToComplete()
        let pluginsList = app.collectionViews.firstMatch
        waitForElement(pluginsList, timeout: 10)
        takeScreenshot(named: "S06_03_plugins_loaded")
        
        // Test 1: Verify plugins display
        let pluginCells = pluginsList.cells
        XCTAssertGreaterThan(pluginCells.count, 0, "Should have plugins")
        
        let initialCount = pluginCells.count
        print("Found \(initialCount) plugins")
        takeScreenshot(named: "S06_04_plugins_count")
        
        // Test 2: Search for specific plugin
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            typeText("git", into: searchField)
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S06_05_search_results")
            
            let filteredCount = pluginsList.cells.count
            XCTAssertLessThanOrEqual(filteredCount, initialCount,
                                    "Filtered results should be <= total")
            
            // Clear search
            let clearButton = searchField.buttons["Clear text"]
            if clearButton.exists {
                clearButton.tap()
                Thread.sleep(forTimeInterval: 1)
            }
        }
        
        // Test 3: Tap on a plugin to view details
        let firstPlugin = pluginCells.firstMatch
        if firstPlugin.exists {
            tapElement(firstPlugin)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S06_06_plugin_details")
            
            // Go back
            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Test 4: Test plugin enable/disable toggle
        let toggleSwitch = pluginCells.firstMatch.switches.firstMatch
        if toggleSwitch.exists {
            let initialValue = toggleSwitch.value as? String
            takeScreenshot(named: "S06_07_before_toggle")
            
            toggleSwitch.tap()
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S06_08_after_toggle")
            
            let newValue = toggleSwitch.value as? String
            XCTAssertNotEqual(initialValue, newValue, "Toggle should change state")
            
            // Toggle back
            toggleSwitch.tap()
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S06_09_toggled_back")
        }
        
        // Test 5: Access marketplace (if button exists)
        let marketplaceButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Marketplace'")).firstMatch
        if marketplaceButton.exists {
            tapElement(marketplaceButton)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S06_10_marketplace")
            
            // Test marketplace search
            let marketplaceSearch = app.searchFields.firstMatch
            if marketplaceSearch.exists {
                typeText("database", into: marketplaceSearch)
                Thread.sleep(forTimeInterval: 2)
                takeScreenshot(named: "S06_11_marketplace_search")
            }
            
            // Go back
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
            }
        }
        
        // Test 6: Test category filter (if available)
        let categoryButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Category'")).firstMatch
        if categoryButton.exists {
            tapElement(categoryButton)
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S06_12_category_menu")
            
            // Select a category
            let categoryOption = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Development'")).firstMatch
            if categoryOption.exists {
                categoryOption.tap()
                Thread.sleep(forTimeInterval: 1)
                takeScreenshot(named: "S06_13_filtered_by_category")
            }
        }
        
        takeScreenshot(named: "S06_14_test_complete")
        print("✅ Scenario 6: Plugin Operations - PASSED")
    }
}
