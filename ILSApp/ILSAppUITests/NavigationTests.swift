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
}
