# Quick Start - ILS iOS Testing

## TL;DR - Run All Tests

```bash
cd <project-root>
./scripts/run_regression_tests.sh
```

That's it! The script will:
1. ✅ Start the backend automatically
2. ✅ Run all 11 regression test scenarios (including extended chat tests)
3. ✅ **Capture 200+ screenshots** at key interaction points
4. ✅ **Test real chat conversations** with multiple exchanges
5. ✅ Generate a detailed report
6. ✅ Clean up after itself

## 🎯 New Features

### Screenshot Capture
Tests now automatically capture screenshots at:
- App launch and navigation
- Before/after each chat message
- Conversation scrolling
- Menu interactions
- Final verification states

**Example:** Scenario 11 captures 30 screenshots documenting an 8-message conversation!

### Real Chat Testing
Tests send actual messages to Claude and verify responses:
- Wait for streaming to complete
- Verify message count
- Test context retention
- Validate conversation persistence

See **[SCREENSHOT_CAPTURE_GUIDE.md](SCREENSHOT_CAPTURE_GUIDE.md)** for details.

---

## Individual Test Execution

### Via Xcode (Recommended for Development)

1. **Open workspace:**
   ```bash
   open ILSFullStack.xcworkspace
   ```

2. **Start backend manually** (in separate terminal):
   ```bash
   swift run ILSBackend
   ```

3. **Run tests:**
   - Press `⌘U` to run all tests
   - OR right-click any test → "Run"
   - OR click the diamond next to a test method

### Via Command Line

```bash
# Run all regression tests
xcodebuild test \
  -workspace ILSFullStack.xcworkspace \
  -scheme ILSApp \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:ILSAppUITests/RegressionTests

# Run specific scenario
xcodebuild test \
  -workspace ILSFullStack.xcworkspace \
  -scheme ILSApp \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:ILSAppUITests/RegressionTests/Scenario01_CompleteSessionLifecycle/testCompleteSessionLifecycle
```

---

## The 10 Scenarios At a Glance

| # | Name | What It Tests | Duration |
|---|------|---------------|----------|
| 1 | **Session Lifecycle** | Create session, send message, fork, session info | 60-90s |
| 2 | **Multi-Section Nav** | Navigate all sections, search, data loading | 45-60s |
| 3 | **Streaming** | SSE streaming, cancellation, batching | 60-90s |
| 4 | **Error Recovery** | Connection loss, reconnection, offline mode | 90-120s |
| 5 | **Projects** | CRUD operations, search, 371 projects | 45-60s |
| 6 | **Plugins** | Enable/disable, search, 78 plugins | 45-60s |
| 7 | **MCP Servers** | Server config, import/export, 20 servers | 60-75s |
| 8 | **Settings** | All settings sections, SSH, cloud sync | 75-90s |
| 9 | **Skills** | Large dataset (1527), search, performance | 60-75s |
| 10 | **Dashboard** | Metrics, analytics, real-time updates | 60-90s |

**Total: ~10-12 minutes**

---

## Quick Debugging

### Test Failed?

1. **Check screenshots** (automatically captured):
   - Xcode → Report Navigator (⌘9)
   - Click failed test → View screenshots

2. **Check backend logs**:
   ```bash
   tail -f backend_test.log
   ```

3. **Common fixes**:
   ```bash
   # Backend not responding
   lsof -i :9090  # Check what's on port 9090
   kill -9 <PID>  # Kill it

   # Simulator issues
   xcrun simctl shutdown all
   xcrun simctl erase all
   ```

### Test Taking Too Long?

- Default timeouts: 5-30s depending on operation
- Backend startup: 30s max
- Streaming response: 30s max
- If tests timeout, check backend is actually running:
  ```bash
  curl http://localhost:9090/health
  ```

---

## Understanding Test Output

### Success ✅
```
✅ Scenario 1: Complete Session Lifecycle - PASSED
Test Case '-[ILSAppUITests.Scenario01_CompleteSessionLifecycle testCompleteSessionLifecycle]' passed (62.5 seconds).
```

### Failure ❌
```
❌ Scenario 3: Streaming and Cancellation - FAILED
XCTAssertTrue failed: Streaming should stop after cancel
```

### Screenshot Pattern
```
S01_05_chat_view_opened.png
│ │  │  └─ Description
│ │  └─── Step number (05)
│ └────── Scenario number (01)
└──────── Scenario prefix
```

---

## CI/CD Integration

Add to `.github/workflows/ios-tests.yml`:

```yaml
name: iOS Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run Tests
        run: ./scripts/run_regression_tests.sh
      - name: Upload Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: TestResults_*.xcresult
```

---

## Workspace Structure

```
ILSFullStack.xcworkspace        ← Open this!
├── ILSApp.xcodeproj            ← iOS app
└── Package.swift               ← Backend + shared code

Tests are in:
ILSApp/ILSAppUITests/RegressionTests/
```

---

## Environment Setup

### First Time?

1. **Install Xcode 15.2+**
2. **Install Xcode Command Line Tools:**
   ```bash
   xcode-select --install
   ```
3. **Verify Swift:**
   ```bash
   swift --version
   ```
4. **Build backend once:**
   ```bash
   swift build
   ```

---

## Advanced Usage

### Run With Custom Options

```bash
# Use existing backend (don't start new one)
./scripts/run_regression_tests.sh --keep-backend

# Use different device
./scripts/run_regression_tests.sh --device "iPhone 14 Pro"

# Show help
./scripts/run_regression_tests.sh --help
```

### Manual Backend Management

```bash
# Start
swift run ILSBackend

# Stop
lsof -i :9090 | grep LISTEN | awk '{print $2}' | xargs kill

# Check health
curl http://localhost:9090/health
```

---

## Performance Monitoring

Tests automatically measure:
- ✅ Time to load each section
- ✅ Streaming performance
- ✅ Search response time
- ✅ Large list scrolling (1527 skills)
- ✅ Navigation transitions

Check test results for timing data!

---

## Need Help?

- 📖 Full docs: [TESTING.md](TESTING.md)
- 🐛 Found a bug? Open an issue
- 💬 Questions? Check the wiki

---

**Pro Tip:** Run tests before every commit to catch regressions early! ⚡
