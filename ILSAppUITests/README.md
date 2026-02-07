# ILS iOS UI Tests

Comprehensive functional UI test suite covering all major app features with backend integration.

## Quick Start

```bash
# From project root
./scripts/run_regression_tests.sh
```

## Test Structure

```
ILSAppUITests/
├── TestHelpers/
│   └── XCUITestBase.swift              # Base class with utilities
│
├── RegressionTests/                     # 🎯 Main test scenarios
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
│
└── [Legacy Tests]                       # Original basic tests
    ├── ValidationGateTests.swift
    ├── FeatureGateTests.swift
    ├── ErrorHandlingTests.swift
    └── NavigationTests.swift
```

## Key Features

### 🤖 Automated Backend Management
- Tests automatically start/stop backend
- Health check polling
- Connection recovery testing
- No manual setup required

### 📸 Screenshot Capture
- Every test step documented
- Automatic attachment to results
- Easy debugging of failures
- Pattern: `S{scenario}_{step}_{description}.png`

### 🎯 Comprehensive Coverage
- **Session Management:** Create, chat, fork, info
- **Navigation:** All 7 sections tested
- **Streaming:** SSE, batching, cancellation
- **Error Handling:** Connection loss, recovery, retries
- **Data Operations:** CRUD for projects, plugins, MCP, skills
- **Settings:** All configuration sections
- **Performance:** Large datasets (1527 skills, 371 projects)

### 🔧 Utilities (`XCUITestBase`)
```swift
// Backend management
startBackendIfNeeded()
stopBackendIfNeeded()
isBackendRunning()

// Navigation
navigateToSection(.dashboard)
openSidebar()
closeSidebar()

// Actions
tapElement(button, message: "Should exist")
typeText("hello", into: field)
clearAndType("new text", into: field)
waitForLoadingToComplete()

// Assertions
assertTextExists("Sessions", timeout: 5)
assertElementCount(cells, equals: 10)

// Debugging
takeScreenshot(named: "step_description")
```

## Test Scenarios Detail

### Scenario 1: Complete Session Lifecycle ✅
Tests the full session workflow from creation to forking.

**Steps:**
1. Launch app and wait for sessions list
2. Create new session with custom name
3. Send test message "What is 2+2?"
4. Wait for SSE streaming and Claude response
5. Verify message count and content
6. Open session info and verify details
7. Fork session and confirm
8. Navigate back to sessions list

**Validates:**
- ChatViewModel streaming logic
- SSEClient connection
- Message batching (75ms)
- Session CRUD operations
- Fork functionality

---

### Scenario 2: Multi-Section Navigation ✅
Comprehensive navigation through all app sections.

**Steps:**
1. Visit Dashboard, verify metrics load
2. Navigate to Projects, test search
3. Visit Skills, test search with 1527+ items
4. Check Plugins section
5. Verify MCP Servers list
6. Test Settings sections
7. Return to Sessions

**Validates:**
- Sidebar navigation
- Data loading in all sections
- Search functionality
- Tab state persistence
- Memory management

---

### Scenario 3: Streaming and Cancellation ✅
Deep testing of SSE streaming capabilities.

**Steps:**
1. Send long message to trigger extended streaming
2. Verify "Claude is responding..." indicator
3. Cancel mid-stream
4. Verify streaming stops
5. Send new message
6. Let stream complete
7. Test message scrolling

**Validates:**
- SSE connection state
- Message batching algorithm
- Cancel functionality
- Connection recovery
- UI responsiveness during streaming

---

### Scenario 4: Error Handling and Recovery ✅
Tests resilience to backend failures.

**Steps:**
1. Start with backend running
2. Kill backend process
3. Verify error banner appears
4. Attempt offline operations
5. Restart backend
6. Wait for automatic reconnection (5s polling)
7. Verify data reloads
8. Create session to confirm full recovery

**Validates:**
- Connection monitoring
- Error UI display
- Retry mechanism (5s intervals)
- Auto-reconnection
- Cache behavior
- Recovery flow

---

### Scenario 5: Project Management ✅
Project CRUD and relationship testing.

**Steps:**
1. Load projects list (371 items)
2. Create new project
3. View project details
4. Check project sessions
5. Test search functionality
6. Test context menu

**Validates:**
- ProjectsViewModel
- Project-session relationships
- Search performance
- List updates

---

### Scenario 6: Plugin Operations ✅
Plugin management and marketplace.

**Steps:**
1. Load plugins list (78 items)
2. Search for specific plugin
3. View plugin details
4. Toggle enable/disable
5. Test marketplace search (if available)
6. Test category filters

**Validates:**
- PluginsViewModel
- Toggle state management
- Marketplace integration
- Search/filter logic

---

### Scenario 7: MCP Server Management ✅
MCP server configuration testing.

**Steps:**
1. Load MCP servers (20 items)
2. Edit existing server
3. Create new MCP server
4. Test import/export functionality
5. Toggle server enable/disable
6. Test search

**Validates:**
- MCPViewModel
- Server configuration
- Import/export JSON
- CRUD operations

---

### Scenario 8: Settings Configuration ✅
Complete settings section coverage.

**Steps:**
1. Test server configuration
2. Create SSH connection
3. Test cloud sync toggles
4. Configure notification preferences
5. Check appearance settings
6. Test all settings navigation

**Validates:**
- Settings persistence
- SSH connection management
- Toggle states
- Form validation

---

### Scenario 9: Skills Management ✅
Large dataset handling and performance.

**Steps:**
1. Load 1527 skills
2. Test search performance
3. Apply category filters
4. View skill details
5. Rapid scrolling test
6. Test multi-select (if available)

**Validates:**
- Large list performance
- Search optimization
- Scrolling smoothness
- Memory management
- UI responsiveness

---

### Scenario 10: Dashboard and Analytics ✅
Metrics and analytics validation.

**Steps:**
1. Load dashboard metrics
2. Verify numeric stats display
3. Test metric navigation
4. Create session, verify metric updates
5. Test recent activity
6. Pull-to-refresh
7. Rapid navigation performance test

**Validates:**
- Dashboard metrics calculation
- Real-time updates
- Navigation from metrics
- Refresh logic
- Performance

---

## Running Tests

### All Tests
```bash
./scripts/run_regression_tests.sh
```

### Single Scenario (Xcode)
1. Open `ILSFullStack.xcworkspace`
2. Navigate to scenario file
3. Click diamond icon next to test method
4. OR press ⌘U to run all tests

### Command Line
```bash
xcodebuild test \
  -workspace ILSFullStack.xcworkspace \
  -scheme ILSApp \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:ILSAppUITests/RegressionTests
```

## Test Timing

| Scenario | Expected Time |
|----------|---------------|
| Total Suite | ~10-12 minutes |
| Individual Scenario | 45-120 seconds |
| Backend Startup | ~10 seconds |

## Debugging Failed Tests

1. **View Screenshots:**
   - Xcode → Report Navigator (⌘9)
   - Select test run
   - Click on test to see attachments

2. **Check Backend Logs:**
   ```bash
   tail -f backend_test.log
   ```

3. **Common Issues:**
   - Backend not running → Check port 9090
   - Element not found → Verify accessibility IDs
   - Timeout → Increase wait time in test

## Best Practices

✅ **DO:**
- Run tests before committing
- Add screenshots at key steps
- Use descriptive screenshot names
- Handle optional UI elements
- Test both happy and error paths
- Clean up test data

❌ **DON'T:**
- Hardcode timeouts too short
- Skip backend health checks
- Ignore flaky tests
- Test implementation details
- Leave test data behind

## Adding New Tests

1. Create new file in `RegressionTests/`
2. Extend `XCUITestBase`
3. Follow naming convention: `ScenarioXX_FeatureName`
4. Add comprehensive screenshots
5. Document what the test validates
6. Update this README

## CI/CD Integration

Tests are designed to run in CI:
- Automatic backend management
- Headless simulator support
- Result bundle generation
- Screenshot artifacts
- Exit codes for pass/fail

## Documentation

- [TESTING.md](../TESTING.md) - Full testing guide
- [TESTING_QUICK_START.md](../TESTING_QUICK_START.md) - Quick reference

## Metrics

- **Test Coverage:** ~60% (UI flows)
- **Total Test Count:** 10 comprehensive scenarios
- **Average Run Time:** ~10-12 minutes
- **Lines of Test Code:** ~5,000
- **Screenshots per Run:** ~150+

---

**Last Updated:** 2026-02-06
**Maintained By:** ILS Development Team
