# Testing Patterns

**Analysis Date:** 2026-02-19

## Test Framework

**Runner:**
- XCTest (Apple's native testing framework)
- Config: `ILSApp/ILSApp.xcodeproj` with test targets `ILSAppUITests`
- UI tests: `ILSApp/ILSAppUITests/` directory

**Assertion Library:**
- XCTest built-in assertions (XCTAssertTrue, XCTAssertNotNil, XCTAssert, etc.)
- No external assertion libraries

**Run Commands:**
```bash
# Run all UI tests
xcodebuild test -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14'

# Run specific test class
xcodebuild test -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -only-testing:ILSAppUITests/ValidationGateTests

# Run with coverage
xcodebuild test -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -enableCodeCoverage YES
```

## Test File Organization

**Location:**
- UI tests: `ILSApp/ILSAppUITests/` (co-located with main app, separate from source)
- Tests are organized by validation gate / feature scenario

**Naming:**
- Test classes: `final class <FeatureName>Tests: XCTestCase`
- Test methods: `func test<Gate/Feature><Detail>()` (e.g., `testGate1_SessionsListLoads()`)
- Validation gates: numbered sequentially (Gate 1, Gate 2, etc.)
- Examples: `ValidationGateTests.swift`, `FeatureGateTests.swift`, `ErrorHandlingTests.swift`

**Structure:**
```
ILSAppUITests/
├── ValidationGateTests.swift        # 7 validation gates (app launch to multi-turn chat)
├── FeatureGateTests.swift           # Feature-specific scenarios
├── ErrorHandlingTests.swift         # Error path testing
├── NavigationTests.swift            # Navigation flow testing
├── CISmokeTests.swift               # Quick CI/CD validation
├── TestHelpers/
│   └── XCUITestBase.swift          # Base class with common helper methods
└── RegressionTests/
    ├── Scenario01_CompleteSessionLifecycle.swift
    ├── Scenario02_MultiSectionNavigation.swift
    └── ... (11 scenario files total)
```

## Test Structure

**Suite Organization (from ValidationGateTests.swift):**
```swift
final class ValidationGateTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        if testRun?.failureCount ?? 0 > 0 {
            // Screenshot on failure
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Failure-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.terminate()
    }

    // MARK: - Helper Methods
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    // MARK: - GATE 1: Sessions List Loads
    func testGate1_SessionsListLoads() throws {
        let sessionsTitle = app.navigationBars["Sessions"]
        XCTAssertTrue(waitForElement(sessionsTitle, timeout: 15), "Sessions navigation title should appear")
        takeScreenshot(named: "Gate1-AfterLaunch")
        // ... assertions
    }
}
```

**Patterns:**
- One test app instance per test class
- Setup captures app in setUpWithError()
- Teardown terminates app and attaches failure screenshots
- Helper methods grouped under MARK sections
- Individual test methods test one validation gate or feature

## Mocking Strategy

**What IS Mocked:**
- UI Testing does NOT mock backend — tests run against real backend at localhost:9999
- Mock mode is optional and controlled by launch arguments (removed in recent sessions)

**What is NOT Mocked:**
- Network requests hit real backend
- Real Claude CLI execution (via Agent SDK or direct CLI)
- Real message streaming and responses
- Real session persistence

**Approach:**
- Functional/E2E testing preferred — real system validation
- Tests capture screenshots as evidence of validation
- Tests wait for real responses from backend (30-second timeout for streaming)

## Accessibility & Element Finding

**Accessibility Identifiers:**
- Used extensively for robust element location
- Examples: `"chat-input-field"`, `"send-button"`, `"add-session-button"`, `"sessions-list"`
- Accessibility labels and hints also provided for context

**Multi-Method Element Finding (resilience):**
- Try accessibility identifier first (most reliable)
- Try element type + predicate (e.g., collectionView cells with identifier predicate)
- Try element type alone (e.g., first button, first table)
- Fallback to coordinate-based interaction if needed

**Example from ValidationGateTests.swift (lines 149-198):**
```swift
private func findFirstSessionCell() -> XCUIElement? {
    // 1. Try cells in collectionViews (iOS 18.6+)
    let collectionView = app.collectionViews.firstMatch
    if collectionView.waitForExistence(timeout: 3) {
        let cellById = collectionView.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'session-'")).firstMatch
        if cellById.exists && cellById.isHittable { return cellById }
        let firstCell = collectionView.cells.firstMatch
        if firstCell.waitForExistence(timeout: 2) && firstCell.isHittable { return firstCell }
    }
    // 2. Try cells in tables (older iOS)
    // 3. Try any cell with session identifier
    // 4. Try any cell
    // 5. Last resort: find text matching session name
    return nil
}
```

**Wait Patterns:**
- `element.waitForExistence(timeout: TimeInterval)` for presence
- `NSPredicate`-based expectations for visibility changes
- `XCTWaiter` for complex wait conditions
- Defensive sleep(1-2) between major state changes

## Test Types

**Validation Gate Tests (ValidationGateTests.swift):**
- 7 gates covering critical app flows:
  1. Sessions list loads after app launch
  2. Session navigation to chat view works
  3. Message input field is accessible and send button appears
  4. Message sends and response streams from real backend
  5. Create new session from UI
  6. Multi-turn conversation with context preservation
  7. Pull-to-refresh functionality

- Scope: End-to-end happy path validation
- Approach: Real backend, real Claude execution
- Evidence: Screenshots at each gate transition

**Feature Gate Tests (FeatureGateTests.swift):**
- Feature-specific scenarios (Projects, Skills, Plugins, MCP, Settings, etc.)
- Each feature has dedicated gate tests
- Validates feature availability and interaction

**Error Handling Tests (ErrorHandlingTests.swift):**
- Tests error paths: network failures, invalid input, server errors
- Verifies error messages display correctly
- Tests recovery mechanisms

**Regression Tests (RegressionTests/ directory):**
- 11 scenario files covering complete workflows
- Scenarios include session lifecycle, navigation, skills, projects, plugins, MCP, settings, chat, teams, marketplace
- Example: `Scenario01_CompleteSessionLifecycle.swift`

**Navigation Tests (NavigationTests.swift):**
- Tab navigation between main sections
- Deep link routing (e.g., `ils://sessions/{uuid}`, `ils://settings`)
- Back button behavior

## Common Patterns

**Async Testing with waitForExistence:**
```swift
let sessionsTitle = app.navigationBars["Sessions"]
XCTAssertTrue(waitForElement(sessionsTitle, timeout: 15), "Sessions navigation title should appear")
```

**Screenshot Capture for Evidence:**
```swift
private func takeScreenshot(named name: String) {
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
}
```

**Text Input & Interaction:**
```swift
let chatInput = app.textFields["chat-input-field"]
chatInput.tap()
chatInput.typeText("What is 2+2?")
```

**Element Lifecycle Testing:**
```swift
let loadingIndicator = app.activityIndicators["loading-sessions-indicator"]
if loadingIndicator.exists {
    XCTAssertTrue(waitForElementToDisappear(loadingIndicator, timeout: 15), "Loading should complete")
}
```

**Multi-Path Element Finding with Fallback:**
```swift
let responseText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '4' OR label CONTAINS 'answer'")).firstMatch
let responseAppeared = responseText.waitForExistence(timeout: 30)
```

**Predicate-Based Element Queries:**
```swift
let cellById = table.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'session-'")).firstMatch
```

## Coverage & Best Practices

**Coverage Targets:**
- No explicit coverage percentage enforced in project
- Focus on validation gates and critical user flows
- All major features covered by scenario tests

**Test Naming:**
- Descriptive method names for readability (e.g., `testGate4_MessageSendsAndResponseStreams()`)
- Gate numbers map to validation order
- Clear assertion messages for debugging

**Robustness Patterns:**
- Accessibility identifiers for reliable element finding
- Multiple element detection strategies (fallback hierarchy)
- Generous timeouts (15-30s) for real backend responses
- Screenshot evidence at key transitions for debugging
- Defensive nil checks and exists checks before interaction

**CI/CD Integration:**
- CISmokeTests.swift for quick validation in CI pipelines
- Tests use dedicated simulator: iPhone 16 Pro Max, iOS 18.6, UDID `50523130-57AA-48B0-ABD0-4D59CE455F14`
- Test harness supports parallel test execution

## Validation Protocol

**Evidence-Driven Verification:**
- Every test captures screenshots at key points
- Screenshots attached to test results with meaningful names
- Test failures automatically capture failure screenshot
- Evidence files accessible in Xcode test results

**Real System Validation:**
- No mocks for network layer — tests hit real backend
- Real Claude CLI execution validates end-to-end flow
- Real database state used (sessions persisted)
- Real SSE streaming tested with real response timing

**Timeout Strategy:**
- Initial waits: 15 seconds (app launch, view transitions)
- Content waits: 10 seconds (chat view, input fields)
- Response waits: 30 seconds (for real Claude execution)
- Short checks: 2-3 seconds (intermediate state verification)

---

*Testing analysis: 2026-02-19*
