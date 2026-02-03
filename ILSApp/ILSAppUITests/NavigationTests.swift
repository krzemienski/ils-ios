import XCTest

final class NavigationTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testSessionNavigation() throws {
        // Wait for sessions to load
        let sessionsList = app.collectionViews.firstMatch
        XCTAssertTrue(sessionsList.waitForExistence(timeout: 5))

        // Tap first cell
        let firstCell = sessionsList.cells.firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            firstCell.tap()

            // Verify we're in chat view by looking for input field
            let textField = app.textFields.firstMatch
            XCTAssertTrue(textField.waitForExistence(timeout: 3), "Should navigate to chat view")
        }
    }

    func testCancelButtonDuringStreaming() throws {
        // Wait for sessions to load
        let sessionsList = app.collectionViews.firstMatch
        XCTAssertTrue(sessionsList.waitForExistence(timeout: 5))

        // Navigate to chat view
        let firstCell = sessionsList.cells.firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            firstCell.tap()

            // Wait for chat view to load
            let chatInputField = app.textFields["chat-input-field"]
            XCTAssertTrue(chatInputField.waitForExistence(timeout: 3), "Should be in chat view")

            // Type a message and send it
            chatInputField.tap()
            chatInputField.typeText("Hello, Claude!")

            let sendButton = app.buttons["send-button"]
            if sendButton.waitForExistence(timeout: 2) {
                sendButton.tap()

                // Verify streaming starts - cancel button should appear
                let cancelButton = app.buttons["cancel-button"]
                XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Cancel button should appear when streaming")

                // Tap cancel button
                cancelButton.tap()

                // Verify streaming stops - send button should reappear
                let sendButtonAfterCancel = app.buttons["send-button"]
                XCTAssertTrue(sendButtonAfterCancel.waitForExistence(timeout: 3), "Send button should reappear after cancellation")

                // Verify cancel button is gone
                XCTAssertFalse(cancelButton.exists, "Cancel button should be hidden after streaming stops")
            }
        }
    }
}
