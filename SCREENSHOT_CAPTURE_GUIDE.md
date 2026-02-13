# Screenshot Capture & Chat Testing Guide

This guide explains the enhanced UI test infrastructure with automatic screenshot capture and real chat interaction testing.

---

## 🎯 Overview

The ILS UI test suite now includes:
- ✅ **Automatic screenshot capture** at key interaction points
- ✅ **Real chat message sending** with response waiting
- ✅ **Multi-turn conversation testing**
- ✅ **Streaming detection and waiting**
- ✅ **Message count verification**
- ✅ **Conversation persistence testing**

---

## 📸 Screenshot Capture

### Automatic Capture Points

Screenshots are automatically captured at:
1. **App launch**
2. **Before and after navigation**
3. **After sending each message**
4. **After receiving responses**
5. **During menu interactions**
6. **At conversation milestones**
7. **At test completion**

### Screenshot Naming Convention

```
S{scenario}_{step}_{description}.png
```

**Examples:**
- `S01_06_first_message_sent.png` - Scenario 1, step 6, first message sent
- `S11_18_documented_code.png` - Scenario 11, step 18, documented code received

### How to Use

```swift
// Capture screenshot with descriptive name
takeScreenshot(named: "S01_05_chat_view_opened")
```

---

## 💬 Chat Testing Features

### Send Message with Response Wait

```swift
// Send message and wait for Claude's response
sendChatMessage("What is 2+2?", waitForResponse: true, timeout: 30)
```

**What it does:**
1. Types message into input field
2. Taps send button
3. Waits for "Claude is responding..." indicator
4. Waits for indicator to disappear (response complete)
5. Times out after specified duration

### Send Message Without Waiting

```swift
// Send message without waiting for response
sendChatMessage("Hello!", waitForResponse: false)
```

### Wait for Streaming to Complete

```swift
// If response already started, wait for it to finish
waitForStreamingComplete(timeout: 30)
```

### Get Message Count

```swift
// Count messages in current conversation
let count = getChatMessageCount()
XCTAssertGreaterThanOrEqual(count, 6, "Should have at least 6 messages")
```

---

## 🧪 Test Scenarios

### Scenario 1: Complete Session Lifecycle

**File:** `Scenario01_CompleteSessionLifecycle.swift`

**What it tests:**
- Session creation
- **3 chat messages with responses**
- Message history verification
- Session info viewing
- Session forking
- Session persistence

**Screenshots:** 25 total
- Initial states
- Each message sent/received
- Conversation scrolling
- Menu interactions
- Final verification

**Chat exchanges:**
1. "What is 2+2?" - Simple math
2. "Can you explain how you calculated that?" - Follow-up
3. "Write a Python function to add two numbers." - Code generation

---

### Scenario 11: Extended Chat Conversation ⭐ NEW

**File:** `Scenario11_ExtendedChatConversation.swift`

**What it tests:**
- Extended multi-turn conversation (8 exchanges)
- Context retention across messages
- Code generation and modification
- Test writing
- Performance analysis
- Optimization requests
- Documentation generation
- Edge case discussion

**Screenshots:** 30 total
- Each message sent/received
- Conversation scrolling (top/middle/bottom)
- Search functionality (if available)
- Session info with message count
- Persistence verification

**Complete conversation flow:**
```
User:      "Hello! I need help creating a Swift function."
Assistant: [Greeting response]

User:      "I need a function that calculates factorial recursively."
Assistant: [Code with recursive factorial]

User:      "Can you add error handling for negative numbers?"
Assistant: [Modified code with error handling]

User:      "Now write unit tests for this function using XCTest."
Assistant: [Unit test code]

User:      "What's the time complexity of this recursive approach?"
Assistant: [Complexity analysis]

User:      "Can you show me an iterative version that's more efficient?"
Assistant: [Iterative implementation]

User:      "Add comprehensive documentation comments."
Assistant: [Documented code]

User:      "What edge cases should I consider?"
Assistant: [Edge case explanation]
```

---

## 🚀 Running Tests with Screenshots

### Run All Tests

```bash
cd <project-root>
./scripts/run_regression_tests.sh
```

### Run Specific Scenario

```bash
# Scenario 1 (original with chat)
xcodebuild test \
  -workspace ILSFullStack.xcworkspace \
  -scheme ILSApp \
  -destination 'generic/platform=iOS Simulator' \
  -only-testing:ILSAppUITests/Scenario01_CompleteSessionLifecycle

# Scenario 11 (extended conversation)
xcodebuild test \
  -workspace ILSFullStack.xcworkspace \
  -scheme ILSApp \
  -destination 'generic/platform=iOS Simulator' \
  -only-testing:ILSAppUITests/Scenario11_ExtendedChatConversation
```

---

## 📁 Finding Screenshots

Screenshots are automatically attached to test results and can be viewed in:

### Xcode
1. Run tests (⌘U)
2. Open Report Navigator (⌘9)
3. Select test run
4. Click on test method
5. View attachments in the right panel

**OR**

1. Right-click test result → "Jump to Report"
2. Expand test cases
3. Click on attachments

### Command Line
```bash
# After running tests, find result bundle
find ~/Library/Developer/Xcode/DerivedData -name "*.xcresult" -type d | head -1

# Open in Xcode
open [path-to-xcresult]
```

### Export Screenshots
```bash
xcrun xcresulttool get --format json --path [path-to-xcresult] > results.json
```

---

## 🎨 Screenshot Examples

### Conversation Flow
```
S11_05_greeting_sent.png          → User message visible
S11_06_greeting_response.png      → Assistant response visible
S11_07_requirement_sent.png       → Next user message
S11_08_code_generated.png         → Code snippet in response
S11_09_modification_sent.png      → Modification request
S11_10_modified_code.png          → Updated code
...continues for 8 full exchanges
```

### Conversation Scrolling
```
S11_21_conversation_top.png       → Scrolled to beginning
S11_22_conversation_middle.png    → Mid-conversation view
S11_23_conversation_bottom.png    → Latest messages
```

### UI States
```
S11_27_session_info.png           → Session details with message count
S11_29_session_reopened.png       → Persistence verification
S11_30_test_complete.png          → Final state
```

---

## ⏱️ Test Timing

| Scenario | Expected Duration | Screenshots | Chat Messages |
|----------|-------------------|-------------|---------------|
| Scenario 1 | 3-5 minutes | 25 | 6 messages (3 exchanges) |
| Scenario 11 | 6-10 minutes | 30 | 16 messages (8 exchanges) |

**Note:** Timing depends on backend response speed and streaming performance.

---

## 🛠️ Helper Functions Reference

### Screenshot
```swift
takeScreenshot(named: "description")
```

### Chat
```swift
// Send with wait
sendChatMessage("message", waitForResponse: true, timeout: 30)

// Send without wait
sendChatMessage("message", waitForResponse: false)

// Wait for streaming
waitForStreamingComplete(timeout: 30)

// Get count
let count = getChatMessageCount()
```

### Navigation
```swift
navigateToSection(.sessions)
openSidebar()
closeSidebar()
```

### Actions
```swift
tapElement(button, timeout: 5, message: "Button should exist")
typeText("text", into: field)
clearAndType("new text", into: field)
waitForLoadingToComplete()
```

### Assertions
```swift
assertTextExists("Sessions", timeout: 5)
assertElementCount(cells, equals: 10)
```

---

## 🧩 Creating New Chat Tests

### Template

```swift
import XCTest

final class ScenarioXX_YourTest: XCUITestBase {
    func testYourScenario() throws {
        app.launch()
        takeScreenshot(named: "SXX_01_launched")

        // Navigate to chat
        // ... navigation code ...

        // Chat exchange 1
        sendChatMessage("Your message", waitForResponse: true)
        takeScreenshot(named: "SXX_XX_message_sent")
        Thread.sleep(forTimeInterval: 1)
        takeScreenshot(named: "SXX_XX_response_received")

        // More exchanges...

        // Verify results
        let messageCount = getChatMessageCount()
        XCTAssertGreaterThanOrEqual(messageCount, expectedCount)

        takeScreenshot(named: "SXX_XX_complete")
    }
}
```

---

## ✅ Validation Checklist

When creating chat tests:
- [ ] Each message has a screenshot before sending
- [ ] Each response has a screenshot after completion
- [ ] Message count is verified
- [ ] Wait timeouts are reasonable (30s for normal, 60s for complex)
- [ ] Screenshots have clear, descriptive names
- [ ] Test includes context retention verification
- [ ] Final state is captured

---

## 🐛 Troubleshooting

### Screenshots Not Appearing
- Check test failed/passed status
- Verify `attachment.lifetime = .keepAlways` in `takeScreenshot()`
- Look in Xcode Report Navigator

### Chat Messages Not Sending
- Verify backend is running on port 9090
- Check input field accessibility identifier
- Increase timeout if responses are slow
- Check for keyboard covering send button

### Message Count Mismatch
- Verify UI element identifiers match actual implementation
- Check if messages are in cells vs. other elements
- Add debug print: `print("Found \(getChatMessageCount()) messages")`

---

## 📊 Test Coverage

| Feature | Scenario 1 | Scenario 11 | Other Scenarios |
|---------|-----------|-------------|-----------------|
| Message Sending | ✅ 3 msgs | ✅ 8 msgs | Various |
| Response Waiting | ✅ | ✅ | ✅ |
| Screenshot Capture | ✅ 25 | ✅ 30 | ✅ 150+ |
| Context Retention | ✅ | ✅ | ✅ |
| Streaming Detection | ✅ | ✅ | ✅ |
| Message Count | ✅ | ✅ | - |
| Scroll Testing | ✅ | ✅ | - |
| Persistence | ✅ | ✅ | - |

---

## 🎯 Best Practices

1. **Always capture before and after major actions**
   ```swift
   takeScreenshot(named: "before_action")
   performAction()
   takeScreenshot(named: "after_action")
   ```

2. **Add delays between screenshots for clarity**
   ```swift
   sendChatMessage("message")
   Thread.sleep(forTimeInterval: 1)  // Let UI settle
   takeScreenshot(named: "response_received")
   ```

3. **Use descriptive screenshot names**
   - ✅ Good: `S11_08_code_generated`
   - ❌ Bad: `screenshot_8`

4. **Verify state before capturing final screenshots**
   ```swift
   XCTAssertEqual(count, expectedCount)
   takeScreenshot(named: "verified_state")
   ```

5. **Group related screenshots with clear numbering**
   - 01-05: Setup
   - 06-20: Main actions
   - 21-25: Verification

---

**Created:** February 6, 2026
**For:** ILS iOS UI Test Suite
**Features:** Screenshot capture + Real chat testing
