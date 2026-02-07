import XCTest

/// SCENARIO 7: MCP Server Management
/// Tests viewing MCP servers, server configuration, import/export,
/// and server status monitoring
final class Scenario07_MCPServerManagement: XCUITestBase {
    
    func testMCPServerManagement() throws {
        app.launch()
        takeScreenshot(named: "S07_01_launched")
        
        // Navigate to MCP Servers section
        navigateToSection(.mcp)
        takeScreenshot(named: "S07_02_mcp_section")
        
        waitForLoadingToComplete()
        let serversList = app.collectionViews.firstMatch
        waitForElement(serversList, timeout: 10)
        takeScreenshot(named: "S07_03_servers_loaded")
        
        // Test 1: Verify servers display with status
        let serverCells = serversList.cells
        XCTAssertGreaterThan(serverCells.count, 0, "Should have MCP servers")
        
        let initialCount = serverCells.count
        print("Found \(initialCount) MCP servers")
        takeScreenshot(named: "S07_04_servers_count")
        
        // Test 2: Tap on server to edit
        let firstServer = serverCells.firstMatch
        if firstServer.exists {
            tapElement(firstServer)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S07_05_server_edit")
            
            // Verify edit fields are present
            assertTextExists("Name", timeout: 3)
            assertTextExists("Command", timeout: 3)
            
            // Go back without saving
            let cancelButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Cancel'")).firstMatch
            if cancelButton.exists {
                cancelButton.tap()
            } else {
                app.navigationBars.buttons.firstMatch.tap()
            }
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Test 3: Create new MCP server
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '+'")).firstMatch
        if addButton.exists {
            tapElement(addButton)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S07_06_new_server_form")
            
            // Fill in server details
            let nameField = app.textFields["serverNameField"]
            if nameField.exists {
                typeText("Test MCP Server", into: nameField)
            }
            
            let commandField = app.textFields["serverCommandField"]
            if commandField.exists {
                typeText("npx test-server", into: commandField)
            }
            
            let argsField = app.textFields["serverArgsField"]
            if argsField.exists {
                typeText("--port 3000", into: argsField)
            }
            
            takeScreenshot(named: "S07_07_server_form_filled")
            
            // Save server
            let saveButton = app.buttons["saveButton"]
            if saveButton.exists {
                tapElement(saveButton)
                Thread.sleep(forTimeInterval: 2)
                takeScreenshot(named: "S07_08_server_created")
            }
        }
        
        // Test 4: Verify new server appears
        waitForLoadingToComplete()
        let updatedCount = serversList.cells.count
        XCTAssertGreaterThan(updatedCount, initialCount, 
                            "Should have more servers after creation")
        takeScreenshot(named: "S07_09_updated_list")
        
        // Test 5: Test import/export functionality
        let importExportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Import'")).firstMatch
        if importExportButton.exists {
            tapElement(importExportButton)
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S07_10_import_export")
            
            // Test export
            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
            if exportButton.exists {
                tapElement(exportButton)
                Thread.sleep(forTimeInterval: 2)
                takeScreenshot(named: "S07_11_export_sheet")
                
                // Dismiss
                let dismissButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Done'")).firstMatch
                if dismissButton.exists {
                    dismissButton.tap()
                }
            }
            
            // Close import/export view
            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Test 6: Test server enable/disable
        let toggleSwitch = serverCells.firstMatch.switches.firstMatch
        if toggleSwitch.exists {
            takeScreenshot(named: "S07_12_before_toggle")
            
            toggleSwitch.tap()
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(named: "S07_13_after_toggle")
            
            // Toggle back
            toggleSwitch.tap()
            Thread.sleep(forTimeInterval: 2)
        }
        
        // Test 7: Test search/filter
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            typeText("test", into: searchField)
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(named: "S07_14_search_results")
            
            // Clear search
            let clearButton = searchField.buttons["Clear text"]
            if clearButton.exists {
                clearButton.tap()
            }
        }
        
        takeScreenshot(named: "S07_15_test_complete")
        print("✅ Scenario 7: MCP Server Management - PASSED")
    }
}
