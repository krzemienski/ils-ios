import XCTest
import Foundation

/// Base class for all UI tests with common setup and utilities
/// Note: Backend must be running before tests start (use run_regression_tests.sh)
class XCUITestBase: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Set launch arguments for test environment
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = [
            "UITEST_MODE": "1",
            "BACKEND_URL": "http://localhost:9999"
        ]

        // Verify backend is running before starting tests
        XCTAssertTrue(isBackendRunning(), "Backend server must be running on port 9999. Run: PORT=9999 swift run ILSBackend")
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Backend Health Check
    
    /// Check if backend is responding
    func isBackendRunning() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var isRunning = false
        
        guard let url = URL(string: "http://localhost:9999/health") else { return false }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                isRunning = true
            }
            semaphore.signal()
        }
        task.resume()
        
        _ = semaphore.wait(timeout: .now() + 2)
        return isRunning
    }
    
    /// Wait for backend to become available
    func waitForBackend(timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if isBackendRunning() {
                print("✅ Backend is ready")
                return
            }
            Thread.sleep(forTimeInterval: 1)
        }
        
        throw TestError.backendNotAvailable
    }
    
    // MARK: - Common Actions
    
    /// Wait for element to exist and be hittable
    @discardableResult
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5, message: String? = nil) -> Bool {
        let exists = element.waitForExistence(timeout: timeout)
        if !exists, let message = message {
            XCTFail(message)
        }
        return exists
    }
    
    /// Tap element with wait
    func tapElement(_ element: XCUIElement, timeout: TimeInterval = 5, message: String? = nil) {
        XCTAssertTrue(waitForElement(element, timeout: timeout, message: message), 
                      "Element should exist: \(message ?? "")")
        element.tap()
    }
    
    /// Type text into element
    func typeText(_ text: String, into element: XCUIElement, timeout: TimeInterval = 5) {
        XCTAssertTrue(waitForElement(element, timeout: timeout), "Input element should exist")
        element.tap()
        element.typeText(text)
    }
    
    /// Clear text field and type new text
    func clearAndType(_ text: String, into element: XCUIElement) {
        element.tap()
        
        // Select all and delete
        if let stringValue = element.value as? String, !stringValue.isEmpty {
            element.tap()
            element.press(forDuration: 1.2)
            app.menuItems["Select All"].tap()
            element.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        
        element.typeText(text)
    }
    
    /// Scroll to element in collection
    func scrollToElement(_ element: XCUIElement, in collection: XCUIElement) {
        while !element.isHittable && collection.exists {
            collection.swipeUp()
        }
    }
    
    /// Wait for loading to complete
    func waitForLoadingToComplete(timeout: TimeInterval = 10) {
        let loadingIndicator = app.activityIndicators.firstMatch
        if loadingIndicator.exists {
            let disappeared = NSPredicate(format: "exists == false")
            expectation(for: disappeared, evaluatedWith: loadingIndicator, handler: nil)
            waitForExpectations(timeout: timeout)
        }
    }
    
    // MARK: - Navigation Helpers
    
    /// Open sidebar
    func openSidebar() {
        let sidebarButton = app.buttons["sidebarButton"]
        if !sidebarButton.exists {
            // Try tap target overlay
            let tapTarget = app.buttons["sidebarTapTarget"]
            tapElement(tapTarget, message: "Sidebar button should exist")
        } else {
            tapElement(sidebarButton, message: "Sidebar button should exist")
        }
        
        // Wait for sidebar to appear
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 2), "Sidebar should open")
    }
    
    /// Close sidebar
    func closeSidebar() {
        let doneButton = app.buttons["Done"]
        if doneButton.exists {
            doneButton.tap()
        }
    }
    
    /// Navigate to section via sidebar
    func navigateToSection(_ section: AppSection) {
        openSidebar()
        
        let button = app.buttons[section.rawValue]
        tapElement(button, message: "\(section.rawValue) button should exist in sidebar")
        
        // Sidebar should auto-close after selection
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    // MARK: - Assertion Helpers
    
    /// Assert text exists somewhere on screen
    func assertTextExists(_ text: String, timeout: TimeInterval = 5) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let element = app.staticTexts.containing(predicate).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), 
                      "Text '\(text)' should exist on screen")
    }
    
    /// Assert element count
    func assertElementCount(_ query: XCUIElementQuery, equals count: Int, timeout: TimeInterval = 5) {
        let element = query.firstMatch
        _ = element.waitForExistence(timeout: timeout)
        XCTAssertEqual(query.count, count, "Should have \(count) elements")
    }
    
    /// Take screenshot with name
    func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    // MARK: - Chat Helpers
    
    /// Send a message in chat and wait for response
    func sendChatMessage(_ message: String, waitForResponse: Bool = true, timeout: TimeInterval = 30) {
        // Find message input field
        let messageField = app.textFields["messageInput"].firstMatch
        if !messageField.exists {
            // Try textViews for multiline
            let textView = app.textViews["messageInput"].firstMatch
            XCTAssertTrue(textView.exists, "Message input field should exist")
            textView.tap()
            textView.typeText(message)
        } else {
            messageField.tap()
            messageField.typeText(message)
        }
        
        // Find and tap send button
        let sendButton = app.buttons["sendButton"].firstMatch
        if !sendButton.exists {
            // Try alternative identifiers
            let sendBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'send'")).firstMatch
            XCTAssertTrue(sendBtn.exists, "Send button should exist")
            sendBtn.tap()
        } else {
            sendButton.tap()
        }
        
        if waitForResponse {
            // Wait for "Claude is responding..." indicator to appear and disappear
            let respondingIndicator = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'responding'")).firstMatch
            if respondingIndicator.waitForExistence(timeout: 5) {
                // Wait for it to disappear (response complete)
                let disappeared = NSPredicate(format: "exists == false")
                expectation(for: disappeared, evaluatedWith: respondingIndicator, handler: nil)
                waitForExpectations(timeout: timeout)
            }
        }
    }
    
    /// Wait for streaming to complete
    func waitForStreamingComplete(timeout: TimeInterval = 30) {
        // Look for streaming indicator
        let streamingIndicator = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'responding' OR label CONTAINS[c] 'typing'")).firstMatch
        
        if streamingIndicator.exists {
            let disappeared = NSPredicate(format: "exists == false")
            expectation(for: disappeared, evaluatedWith: streamingIndicator, handler: nil)
            waitForExpectations(timeout: timeout)
        }
    }
    
    /// Count messages in chat
    func getChatMessageCount() -> Int {
        // Messages are typically in cells or rows
        let messageCells = app.cells.matching(NSPredicate(format: "identifier CONTAINS[c] 'message'"))
        if messageCells.count > 0 {
            return messageCells.count
        }
        
        // Alternative: look for message bubbles
        let messageViews = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] 'messageView'"))
        return messageViews.count
    }
}

// MARK: - App Sections

enum AppSection: String {
    case dashboard = "Dashboard"
    case sessions = "Sessions"
    case projects = "Projects"
    case plugins = "Plugins"
    case mcp = "MCP Servers"
    case skills = "Skills"
    case settings = "Settings"
}

// MARK: - Test Errors

enum TestError: Error {
    case backendNotAvailable
    case elementNotFound(String)
    case timeoutExceeded
}
