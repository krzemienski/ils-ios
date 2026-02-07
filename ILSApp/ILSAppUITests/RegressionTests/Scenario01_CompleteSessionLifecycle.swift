import XCTest

/// SCENARIO 1: Complete Session Lifecycle
/// Tests creating a new session, sending messages, receiving responses,
/// forking the session, and verifying session info
final class Scenario01_CompleteSessionLifecycle: XCUITestBase {
    
    func testCompleteSessionLifecycle() throws {
        // Start backend if needed
        
        // Launch app
        app.launch()
        takeScreenshot(named: "S01_01_app_launched")
        
        // Step 1: Wait for sessions list to load
        let sessionsList = app.collectionViews.firstMatch
        XCTAssertTrue(waitForElement(sessionsList, timeout: 10, 
                                     message: "Sessions list should load"))
        waitForLoadingToComplete()
        takeScreenshot(named: "S01_02_sessions_list_loaded")
        
        // Step 2: Create new session
        let fab = app.buttons["createSessionButton"]
        tapElement(fab, timeout: 5, message: "FAB should exist")
        takeScreenshot(named: "S01_03_fab_tapped")
        
        // Step 3: Fill in session details
        let nameField = app.textFields["sessionNameField"]
        if nameField.exists {
            typeText("UI Test Session", into: nameField)
        }
        
        let modelPicker = app.buttons["modelPicker"]
        if modelPicker.exists {
            tapElement(modelPicker)
            // Select Sonnet model
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Sonnet'")).firstMatch.tap()
        }
        
        let createButton = app.buttons["createButton"]
        tapElement(createButton, message: "Create button should exist")
        takeScreenshot(named: "S01_04_session_created")
        
        // Step 4: Verify we're in ChatView
        let inputField = app.textFields.firstMatch
        XCTAssertTrue(waitForElement(inputField, timeout: 5, 
                                     message: "Should navigate to chat view"))
        takeScreenshot(named: "S01_05_chat_view_opened")
        
        // Step 5: Send first message - simple math
        print("📤 Sending first message: Simple math question")
        sendChatMessage("What is 2+2?", waitForResponse: true, timeout: 30)
        takeScreenshot(named: "S01_06_first_message_sent")
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "S01_07_first_response_received")
        
        // Step 6: Send second message - follow-up question
        print("📤 Sending second message: Follow-up question")
        sendChatMessage("Can you explain how you calculated that?", waitForResponse: true, timeout: 30)
        takeScreenshot(named: "S01_08_second_message_sent")
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "S01_09_second_response_received")
        
        // Step 7: Send third message - code request
        print("📤 Sending third message: Code generation")
        sendChatMessage("Write a Python function to add two numbers.", waitForResponse: true, timeout: 30)
        takeScreenshot(named: "S01_10_third_message_sent")
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "S01_11_third_response_received")
        
        // Step 8: Verify message history
        let messageCount = getChatMessageCount()
        print("📊 Total messages in chat: \(messageCount)")
        XCTAssertGreaterThanOrEqual(messageCount, 6, "Should have at least 6 messages (3 user + 3 assistant)")
        takeScreenshot(named: "S01_12_full_conversation")
        
        // Step 9: Scroll through conversation history
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeDown()
            takeScreenshot(named: "S01_13_scrolled_to_top")
            Thread.sleep(forTimeInterval: 0.5)
            scrollView.swipeUp()
            takeScreenshot(named: "S01_14_scrolled_to_bottom")
        }
        
        // Step 10: Open session menu
        let menuButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'more'")).firstMatch
        if menuButton.exists {
            tapElement(menuButton)
            takeScreenshot(named: "S01_15_menu_opened")
            
            // Step 11: View session info
            let infoButton = app.buttons["Session Info"]
            if infoButton.exists {
                tapElement(infoButton)
                takeScreenshot(named: "S01_16_session_info")
                
                // Verify session info displays
                assertTextExists("Name", timeout: 3)
                assertTextExists("Model", timeout: 3)
                assertTextExists("Status", timeout: 3)
                
                // Close session info
                app.buttons["Done"].tap()
                takeScreenshot(named: "S01_17_session_info_closed")
            }
            
            // Step 12: Fork session
            menuButton.tap()
            Thread.sleep(forTimeInterval: 0.3)
            takeScreenshot(named: "S01_18_menu_reopened")
            
            let forkButton = app.buttons["Fork Session"]
            if forkButton.exists {
                tapElement(forkButton)
                takeScreenshot(named: "S01_19_fork_triggered")
                
                // Wait for fork alert
                let alert = app.alerts["Session Forked"]
                XCTAssertTrue(alert.waitForExistence(timeout: 5), "Fork alert should appear")
                takeScreenshot(named: "S01_20_fork_alert")
                alert.buttons["OK"].tap()
                takeScreenshot(named: "S01_21_fork_confirmed")
            }
        }
        
        // Step 13: Navigate back to sessions list
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(sessionsList.waitForExistence(timeout: 3), 
                     "Should return to sessions list")
        takeScreenshot(named: "S01_22_back_to_sessions")
        
        // Step 14: Verify new session exists
        waitForLoadingToComplete()
        let sessionCells = sessionsList.cells
        XCTAssertGreaterThan(sessionCells.count, 0, "Should have at least one session")
        takeScreenshot(named: "S01_23_sessions_list_updated")
        
        // Step 15: Open the test session again to verify it persisted
        let testSession = sessionCells.firstMatch
        tapElement(testSession, message: "Should be able to reopen session")
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Should navigate back to chat")
        takeScreenshot(named: "S01_24_session_reopened")
        
        // Verify messages are still there
        let finalMessageCount = getChatMessageCount()
        XCTAssertEqual(finalMessageCount, messageCount, "Message count should be preserved")
        takeScreenshot(named: "S01_25_test_complete")
        
        print("✅ Scenario 1: Complete Session Lifecycle - PASSED")
    }
}
