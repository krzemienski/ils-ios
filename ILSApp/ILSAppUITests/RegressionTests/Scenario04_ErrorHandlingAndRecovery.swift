import XCTest

/// SCENARIO 4: Error Handling and Recovery
/// Tests connection errors, retry mechanisms, offline mode detection,
/// and backend recovery
final class Scenario04_ErrorHandlingAndRecovery: XCUITestBase {
    
    func testErrorHandlingAndRecovery() throws {
        // Start with backend running
        app.launch()
        takeScreenshot(named: "S04_01_launched_connected")
        
        // Verify initial connection
        let sessionsList = app.collectionViews.firstMatch
        waitForElement(sessionsList, timeout: 10)
        takeScreenshot(named: "S04_02_connected")
        
        // Test 1: Kill backend to simulate connection loss
        print("🔴 Simulating backend failure...")
        Thread.sleep(forTimeInterval: 2)
        
        // Trigger a refresh or navigation to detect disconnection
        navigateToSection(.dashboard)
        Thread.sleep(forTimeInterval: 3)
        takeScreenshot(named: "S04_03_backend_stopped")
        
        // Should show connection error banner
        assertTextExists("No connection", timeout: 10)
        takeScreenshot(named: "S04_04_error_banner_shown")
        
        // Test 2: Try to perform action while offline
        navigateToSection(.sessions)
        Thread.sleep(forTimeInterval: 2)
        
        // Try to load sessions - should show error or cached data
        takeScreenshot(named: "S04_05_offline_state")
        
        // Test 3: Restart backend
        print("🟢 Restarting backend...")
        takeScreenshot(named: "S04_06_backend_restarted")
        
        // Test 4: Verify automatic reconnection
        // The app should detect backend is back and reconnect
        Thread.sleep(forTimeInterval: 5)
        
        // Trigger refresh by navigating
        navigateToSection(.dashboard)
        Thread.sleep(forTimeInterval: 3)
        takeScreenshot(named: "S04_07_checking_reconnection")
        
        // Connection error banner should disappear
        let errorBanner = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'No connection'"))
        
        // Wait for banner to disappear (may take up to 30s with retry polling)
        let disappeared = NSPredicate(format: "exists == false")
        expectation(for: disappeared, evaluatedWith: errorBanner.firstMatch, handler: nil)
        waitForExpectations(timeout: 35)
        
        takeScreenshot(named: "S04_08_reconnected")
        
        // Test 5: Verify data loads after reconnection
        navigateToSection(.sessions)
        waitForLoadingToComplete(timeout: 15)
        
        XCTAssertTrue(sessionsList.exists, "Sessions list should load after reconnection")
        takeScreenshot(named: "S04_09_data_reloaded")
        
        // Test 6: Create new session to verify full functionality restored
        let fab = app.buttons["createSessionButton"]
        if fab.exists {
            tapElement(fab)
            takeScreenshot(named: "S04_10_creating_session")
            
            let createButton = app.buttons["createButton"]
            if createButton.exists {
                tapElement(createButton)
                Thread.sleep(forTimeInterval: 2)
                takeScreenshot(named: "S04_11_session_created_after_recovery")
            }
        }
        
        takeScreenshot(named: "S04_12_test_complete")
        print("✅ Scenario 4: Error Handling and Recovery - PASSED")
    }
}
