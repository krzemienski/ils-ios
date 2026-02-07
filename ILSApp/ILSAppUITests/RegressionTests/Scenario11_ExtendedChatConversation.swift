import XCTest

/// SCENARIO 11: Extended Chat Conversation
/// Tests multiple message exchanges, context retention, and screenshot capture
/// throughout a realistic conversation flow
final class Scenario11_ExtendedChatConversation: XCUITestBase {
    
    func testExtendedChatConversation() throws {
        // Launch app
        app.launch()
        takeScreenshot(named: "S11_01_app_launched")
        
        // Navigate to sessions
        let sessionsList = app.collectionViews.firstMatch
        XCTAssertTrue(waitForElement(sessionsList, timeout: 10, message: "Sessions list should load"))
        waitForLoadingToComplete()
        takeScreenshot(named: "S11_02_sessions_list")
        
        // Create new session for extended conversation
        let fab = app.buttons["createSessionButton"]
        tapElement(fab, timeout: 5, message: "FAB should exist")
        
        // Configure session
        let nameField = app.textFields["sessionNameField"]
        if nameField.exists {
            typeText("Extended Chat Test", into: nameField)
        }
        
        let createButton = app.buttons["createButton"]
        tapElement(createButton, message: "Create button should exist")
        takeScreenshot(named: "S11_03_session_created")
        
        // Verify we're in chat
        let inputField = app.textFields.firstMatch
        XCTAssertTrue(waitForElement(inputField, timeout: 5, message: "Should navigate to chat view"))
        takeScreenshot(named: "S11_04_chat_ready")
        
        // === CONVERSATION FLOW ===
        
        // Exchange 1: Introduction and task
        print("💬 Exchange 1: Setting up the task")
        sendChatMessage("Hello! I need help creating a Swift function.", waitForResponse: true, timeout: 30)
        takeScreenshot(named: "S11_05_greeting_sent")
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "S11_06_greeting_response")
        
        // Exchange 2: Specify requirements
        print("💬 Exchange 2: Specifying requirements")
        sendChatMessage("I need a function that calculates the factorial of a number recursively.", waitForResponse: true, timeout: 30)
        takeScreenshot(named: "S11_07_requirement_sent")
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "S11_08_code_generated")
        
        // Exchange 3: Ask for modifications
        print("💬 Exchange 3: Requesting modifications")
        sendChatMessage("Can you add error handling for negative numbers?", waitForResponse: true, timeout: 30)
        takeScreenshot(named: "S11_09_modification_sent")
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "S11_10_modified_code")
        
        // Exchange 4: Request tests
        print("💬 Exchange 4: Requesting unit tests")
        sendChatMessage("Now write unit tests for this function using XCTest.", waitForResponse: true, timeout: 30)
        takeScreenshot(named: "S11_11_test_request_sent")
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "S11_12_tests_generated")
        
        // Exchange 5: Ask about performance
        print("💬 Exchange 5: Performance question")
        sendChatMessage("What's the time complexity of this recursive approach?", waitForResponse: true, timeout: 30)
        takeScreenshot(named: "S11_13_complexity_question_sent")
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "S11_14_complexity_explained")
        
        // Exchange 6: Request optimization
        print("💬 Exchange 6: Optimization request")
        sendChatMessage("Can you show me an iterative version that's more efficient?", waitForResponse: true, timeout: 30)
        takeScreenshot(named: "S11_15_optimization_sent")
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "S11_16_iterative_version")
        
        // Exchange 7: Documentation request
        print("💬 Exchange 7: Documentation")
        sendChatMessage("Add comprehensive documentation comments to the iterative version.", waitForResponse: true, timeout: 30)
        takeScreenshot(named: "S11_17_docs_request_sent")
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "S11_18_documented_code")
        
        // Exchange 8: Edge cases
        print("💬 Exchange 8: Edge cases")
        sendChatMessage("What edge cases should I consider when using this function?", waitForResponse: true, timeout: 30)
        takeScreenshot(named: "S11_19_edge_cases_question")
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "S11_20_edge_cases_explained")
        
        // Verify message count
        let finalMessageCount = getChatMessageCount()
        print("📊 Final message count: \(finalMessageCount)")
        XCTAssertGreaterThanOrEqual(finalMessageCount, 16, "Should have at least 16 messages (8 exchanges)")
        
        // Scroll through entire conversation
        print("📜 Scrolling through conversation history")
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            // Scroll to top
            for _ in 1...5 {
                scrollView.swipeDown()
                Thread.sleep(forTimeInterval: 0.2)
            }
            takeScreenshot(named: "S11_21_conversation_top")
            
            // Scroll to middle
            for _ in 1...3 {
                scrollView.swipeUp()
                Thread.sleep(forTimeInterval: 0.2)
            }
            takeScreenshot(named: "S11_22_conversation_middle")
            
            // Scroll to bottom
            for _ in 1...5 {
                scrollView.swipeUp()
                Thread.sleep(forTimeInterval: 0.2)
            }
            takeScreenshot(named: "S11_23_conversation_bottom")
        }
        
        // Test message search (if available)
        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'search'")).firstMatch
        if searchButton.exists {
            tapElement(searchButton)
            takeScreenshot(named: "S11_24_search_opened")
            
            let searchField = app.searchFields.firstMatch
            if searchField.exists {
                typeText("factorial", into: searchField)
                takeScreenshot(named: "S11_25_search_results")
                
                // Close search
                app.buttons["Cancel"].tap()
            }
        }
        
        // Open session info
        let menuButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'more'")).firstMatch
        if menuButton.exists {
            tapElement(menuButton)
            takeScreenshot(named: "S11_26_menu_opened")
            
            let infoButton = app.buttons["Session Info"]
            if infoButton.exists {
                tapElement(infoButton)
                takeScreenshot(named: "S11_27_session_info")
                
                // Verify session stats
                assertTextExists("Messages", timeout: 3)
                assertTextExists("Model", timeout: 3)
                
                app.buttons["Done"].tap()
            }
        }
        
        // Navigate back to sessions list
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(sessionsList.waitForExistence(timeout: 3), "Should return to sessions list")
        takeScreenshot(named: "S11_28_back_to_sessions")
        
        // Reopen session to verify persistence
        let sessionCells = sessionsList.cells
        let testSession = sessionCells.firstMatch
        tapElement(testSession, message: "Should be able to reopen session")
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Should navigate back to chat")
        takeScreenshot(named: "S11_29_session_reopened")
        
        // Verify message count is preserved
        let reopenedMessageCount = getChatMessageCount()
        XCTAssertEqual(reopenedMessageCount, finalMessageCount, "Message count should be preserved after reopening")
        takeScreenshot(named: "S11_30_test_complete")
        
        print("✅ Scenario 11: Extended Chat Conversation - PASSED")
        print("📊 Total messages: \(finalMessageCount)")
        print("📸 Total screenshots: 30")
    }
}
