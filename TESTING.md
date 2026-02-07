# ILS iOS App - Comprehensive Testing Guide

## Overview

This document describes the complete testing infrastructure for the ILS iOS application, including the unified workspace setup, backend integration, and 10 comprehensive regression test scenarios.

## 🏗️ Architecture

### Unified Workspace

The project now includes `ILSFullStack.xcworkspace` which provides:
- iOS app target (ILSApp)
- Backend server target (ILSBackend via Package.swift)
- Shared models (ILSShared)
- Unified build and test orchestration

### Test Infrastructure

```
ILSAppUITests/
├── TestHelpers/
│   └── XCUITestBase.swift          # Base class with utilities
├── RegressionTests/
│   ├── Scenario01_CompleteSessionLifecycle.swift
│   ├── Scenario02_MultiSectionNavigation.swift
│   ├── Scenario03_StreamingAndCancellation.swift
│   ├── Scenario04_ErrorHandlingAndRecovery.swift
│   ├── Scenario05_ProjectManagement.swift
│   ├── Scenario06_PluginOperations.swift
│   ├── Scenario07_MCPServerManagement.swift
│   ├── Scenario08_SettingsConfiguration.swift
│   ├── Scenario09_SkillsManagement.swift
│   └── Scenario10_DashboardAndAnalytics.swift
└── [Original Tests]
    ├── ValidationGateTests.swift
    ├── FeatureGateTests.swift
    ├── ErrorHandlingTests.swift
    └── NavigationTests.swift
```

## 🎯 Test Scenarios

### Scenario 1: Complete Session Lifecycle ✅
**What it tests:**
- Creating a new session with custom configuration
- Sending messages and receiving Claude responses
- SSE streaming with "Claude is responding..." indicator
- Message persistence and display
- Session info viewing (name, model, status, timestamps)
- Session forking functionality
- Navigation between sessions list and chat view

**Coverage:**
- ChatViewModel streaming logic
- SSEClient connection management
- Session creation flow
- Fork session API call
- Message history loading

**Duration:** ~60-90 seconds

---

### Scenario 2: Multi-Section Navigation ✅
**What it tests:**
- Navigation through all 7 main sections (Dashboard, Sessions, Projects, Skills, Plugins, MCP, Settings)
- Data loading in each section
- Search functionality across different views
- List rendering with varying data sizes
- Sidebar opening/closing
- Tab state persistence

**Coverage:**
- Navigation state management
- BaseListViewModel search
- Data fetching across all ViewModels
- UI responsiveness with large datasets

**Duration:** ~45-60 seconds

---

### Scenario 3: Streaming and Cancellation ✅
**What it tests:**
- SSE streaming with long responses
- Message batching (75ms intervals)
- Mid-stream cancellation
- Resuming streaming after cancel
- Smooth UI updates during streaming
- Message scrolling during active stream

**Coverage:**
- SSEClient streaming state
- ChatViewModel batching logic
- Cancel functionality
- Connection state transitions
- UI performance during streaming

**Duration:** ~60-90 seconds

---

### Scenario 4: Error Handling and Recovery ✅
**What it tests:**
- Connection loss detection
- Error banner display
- Offline mode handling
- Backend failure simulation
- Automatic reconnection (5s retry polling)
- Data reload after recovery
- Full functionality restoration

**Coverage:**
- AppState connection monitoring
- Health check polling
- Retry mechanism
- Error state UI
- Cache behavior during offline
- Recovery flow

**Duration:** ~90-120 seconds (includes backend restart)

---

### Scenario 5: Project Management ✅
**What it tests:**
- Project list display (371 projects from backend)
- Creating new projects
- Project detail view
- Project-session relationships
- Project search and filtering
- Context menu operations

**Coverage:**
- ProjectsViewModel CRUD operations
- Project detail navigation
- Search functionality
- List updates after creation

**Duration:** ~45-60 seconds

---

### Scenario 6: Plugin Operations ✅
**What it tests:**
- Plugin list display (78 plugins)
- Plugin search
- Enable/disable toggle functionality
- Plugin details view
- Marketplace search (if available)
- Category filtering

**Coverage:**
- PluginsViewModel
- Enable/disable API calls
- Search and filter logic
- Toggle state management

**Duration:** ~45-60 seconds

---

### Scenario 7: MCP Server Management ✅
**What it tests:**
- MCP server list (20 servers)
- Server configuration editing
- Creating new MCP servers
- Import/export functionality
- Server enable/disable
- Command and args configuration

**Coverage:**
- MCPViewModel
- Server CRUD operations
- Configuration persistence
- Import/export JSON handling

**Duration:** ~60-75 seconds

---

### Scenario 8: Settings Configuration ✅
**What it tests:**
- Server configuration (URL, port)
- SSH connection management
- Cloud sync settings
- Notification preferences
- Appearance settings
- All settings sections navigation

**Coverage:**
- SettingsView navigation
- SSH connection CRUD
- Toggle state management
- Configuration persistence

**Duration:** ~75-90 seconds

---

### Scenario 9: Skills Management ✅
**What it tests:**
- Large dataset handling (1527 skills)
- Skills search performance
- Category filtering
- Skill details view
- Rapid scrolling performance
- Multi-select (if available)

**Coverage:**
- SkillsViewModel
- Large list performance
- Search optimization
- Scrolling smoothness
- Memory management

**Duration:** ~60-75 seconds

---

### Scenario 10: Dashboard and Analytics ✅
**What it tests:**
- Dashboard metrics display
- Real-time metric updates
- Navigation from metrics to sections
- Quick actions
- Pull-to-refresh
- Performance with rapid navigation

**Coverage:**
- DashboardViewModel
- Metrics calculation
- Navigation from dashboard
- Data refresh logic
- UI responsiveness

**Duration:** ~60-90 seconds

---

## 🚀 Running Tests

### Option 1: Xcode GUI

1. Open `ILSFullStack.xcworkspace`
2. Select the `ILSApp` scheme
3. Select a simulator (iPhone 15 Pro recommended)
4. Product → Test (⌘U)
5. Or right-click specific test scenario → Run

### Option 2: Command Line

```bash
# Build backend first (optional if already running)
cd /Users/nick/Desktop/ils-ios
swift build

# Run backend in background
swift run ILSBackend &
BACKEND_PID=$!

# Wait for backend to start
sleep 5

# Run all tests
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
  -only-testing:ILSAppUITests/RegressionTests/Scenario01_CompleteSessionLifecycle

# Cleanup
kill $BACKEND_PID
```

### Option 3: Automated Script

Use the provided `scripts/run_regression_tests.sh`:

```bash
chmod +x scripts/run_regression_tests.sh
./scripts/run_regression_tests.sh
```

---

## 🔧 Test Base Class (`XCUITestBase`)

### Features

**Backend Management:**
- `startBackendIfNeeded()` - Launches backend if not running
- `stopBackendIfNeeded()` - Cleanup after tests
- `isBackendRunning()` - Health check
- `waitForBackend(timeout:)` - Wait for startup

**Navigation:**
- `openSidebar()` - Opens navigation sidebar
- `closeSidebar()` - Closes sidebar
- `navigateToSection(_:)` - Navigate to any app section

**Actions:**
- `waitForElement(_:timeout:message:)` - Wait with timeout
- `tapElement(_:timeout:message:)` - Tap with wait
- `typeText(_:into:)` - Type text into field
- `clearAndType(_:into:)` - Clear and type
- `scrollToElement(_:in:)` - Scroll to element

**Assertions:**
- `assertTextExists(_:timeout:)` - Assert text on screen
- `assertElementCount(_:equals:)` - Assert element count
- `waitForLoadingToComplete()` - Wait for loading indicators

**Utilities:**
- `takeScreenshot(named:)` - Capture screenshot with name
- All screenshots saved with test attachments

---

## 📊 Test Coverage Goals

| Component | Target | Current | Status |
|-----------|--------|---------|--------|
| ViewModels | 80% | TBD | 🟡 |
| Services | 80% | TBD | 🟡 |
| Views (UI Tests) | 70% | ~60% | 🟢 |
| Models | 90% | TBD | 🟡 |
| Integration | 100% | 90% | 🟢 |

---

## 🐛 Debugging Tests

### View Test Results

1. Xcode → Report Navigator (⌘9)
2. Select test run
3. View logs and screenshots
4. Click on any test to see failures

### Screenshots

All tests capture screenshots at key points:
- Pattern: `S{scenario}_{step}_{description}.png`
- Example: `S01_05_chat_view_opened.png`
- Automatically attached to test results

### Common Issues

**Backend not starting:**
```bash
# Check if port 9090 is in use
lsof -i :9090
kill -9 <PID>

# Manually start backend
swift run ILSBackend
```

**Tests timing out:**
- Increase timeout in test: `waitForElement(element, timeout: 20)`
- Check backend logs for errors
- Verify simulator has network access

**Element not found:**
- Check accessibility identifiers in source code
- Use `po app.debugDescription` in breakpoint
- Update element queries in test

---

## 📈 Performance Benchmarks

### Test Execution Times

| Scenario | Expected | Threshold |
|----------|----------|-----------|
| 01 - Session Lifecycle | 60-90s | 120s |
| 02 - Navigation | 45-60s | 90s |
| 03 - Streaming | 60-90s | 120s |
| 04 - Recovery | 90-120s | 180s |
| 05 - Projects | 45-60s | 90s |
| 06 - Plugins | 45-60s | 90s |
| 07 - MCP | 60-75s | 120s |
| 08 - Settings | 75-90s | 150s |
| 09 - Skills | 60-75s | 120s |
| 10 - Dashboard | 60-90s | 120s |
| **Total Suite** | **~10-12 min** | **20 min** |

---

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: UI Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app

      - name: Build Backend
        run: swift build

      - name: Start Backend
        run: |
          swift run ILSBackend &
          echo $! > backend.pid
          sleep 10

      - name: Run UI Tests
        run: |
          xcodebuild test \
            -workspace ILSFullStack.xcworkspace \
            -scheme ILSApp \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -only-testing:ILSAppUITests/RegressionTests \
            -resultBundlePath TestResults.xcresult

      - name: Stop Backend
        if: always()
        run: kill $(cat backend.pid) || true

      - name: Upload Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: TestResults.xcresult
```

---

## 🎓 Writing New Tests

### Template

```swift
import XCTest

/// SCENARIO XX: Description
/// Tests: feature1, feature2, feature3
final class ScenarioXX_FeatureName: XCUITestBase {

    func testFeatureName() throws {
        try startBackendIfNeeded()
        app.launch()
        takeScreenshot(named: "SXX_01_launched")

        // Your test steps here

        takeScreenshot(named: "SXX_XX_test_complete")
        print("✅ Scenario XX: Feature Name - PASSED")
    }
}
```

### Best Practices

1. **Always capture screenshots** at key steps
2. **Use descriptive names** for screenshots
3. **Wait for elements** before interacting
4. **Clean up state** between tests
5. **Handle optional UI** gracefully
6. **Test error paths** not just happy path
7. **Verify backend state** when relevant
8. **Use meaningful assertions** with messages

---

## 📚 Additional Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [UI Testing Best Practices](https://developer.apple.com/videos/play/wwdc2015/406/)
- [ILSApp Architecture](/docs/system-architecture.md)
- [Contributing Guidelines](/CONTRIBUTING.md)

---

## ✅ Checklist for New Features

When adding a new feature:

- [ ] Add unit tests for ViewModels
- [ ] Add UI test scenario if user-facing
- [ ] Update this documentation
- [ ] Add accessibility identifiers
- [ ] Test on multiple devices/orientations
- [ ] Verify offline behavior
- [ ] Test with backend failures
- [ ] Check memory leaks
- [ ] Verify smooth animations
- [ ] Update screenshot baselines

---

**Last Updated:** 2026-02-06
**Maintained By:** ILS Development Team
**Questions?** Open an issue or check the wiki
