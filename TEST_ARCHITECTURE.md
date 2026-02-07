# Test Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                  ILSFullStack.xcworkspace                   │
│                                                             │
│  ┌────────────────────┐         ┌─────────────────────┐   │
│  │   ILSApp.xcodeproj │         │   Package.swift     │   │
│  │   (iOS Frontend)   │◄───────►│   (Swift Backend)   │   │
│  │                    │         │                     │   │
│  │  - Views           │         │  - ILSBackend       │   │
│  │  - ViewModels      │         │  - ILSShared        │   │
│  │  - Services        │         │  - Vapor Routes     │   │
│  │  - UI Tests ✅     │         │  - Database         │   │
│  └────────────────────┘         └─────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Test Execution Flow

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  1. ./scripts/run_regression_tests.sh                       │
│                                                              │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  2. Check if backend running (port 9090)                    │
│     │                                                        │
│     ├─ Yes → Use existing                                   │
│     └─ No  → swift run ILSBackend (start in background)    │
│                                                              │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  3. Wait for backend health check                           │
│     curl http://localhost:9090/health                       │
│     (max 30s timeout)                                        │
│                                                              │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  4. xcodebuild test                                          │
│     -workspace ILSFullStack.xcworkspace                      │
│     -scheme ILSApp                                           │
│     -destination 'platform=iOS Simulator,name=iPhone 15 Pro'│
│     -only-testing:ILSAppUITests/RegressionTests             │
│                                                              │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  5. Run 10 Scenarios (in order)                             │
│     │                                                        │
│     ├─ Scenario 01: Session Lifecycle                       │
│     ├─ Scenario 02: Multi-Section Navigation                │
│     ├─ Scenario 03: Streaming and Cancellation             │
│     ├─ Scenario 04: Error Recovery                          │
│     ├─ Scenario 05: Project Management                      │
│     ├─ Scenario 06: Plugin Operations                       │
│     ├─ Scenario 07: MCP Server Management                   │
│     ├─ Scenario 08: Settings Configuration                  │
│     ├─ Scenario 09: Skills Management                       │
│     └─ Scenario 10: Dashboard and Analytics                 │
│                                                              │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  6. Generate Test Results                                    │
│     - TestResults_YYYYMMDD_HHMMSS.xcresult                  │
│     - Screenshots (150+)                                     │
│     - Test summary                                           │
│     - JSON report                                            │
│                                                              │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  7. Cleanup                                                  │
│     - Stop backend (if started by script)                   │
│     - Remove temp files                                      │
│     - Exit with success/failure code                        │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Test Hierarchy

```
XCTestCase
    │
    ├── XCUITestBase (Base Class)
    │   │
    │   ├── Backend Management
    │   │   ├── startBackendIfNeeded()
    │   │   ├── stopBackendIfNeeded()
    │   │   ├── isBackendRunning()
    │   │   └── waitForBackend(timeout:)
    │   │
    │   ├── Navigation Helpers
    │   │   ├── openSidebar()
    │   │   ├── closeSidebar()
    │   │   └── navigateToSection(_:)
    │   │
    │   ├── Action Utilities
    │   │   ├── waitForElement(_:timeout:)
    │   │   ├── tapElement(_:timeout:)
    │   │   ├── typeText(_:into:)
    │   │   ├── clearAndType(_:into:)
    │   │   └── waitForLoadingToComplete()
    │   │
    │   ├── Assertions
    │   │   ├── assertTextExists(_:timeout:)
    │   │   └── assertElementCount(_:equals:)
    │   │
    │   └── Debugging
    │       └── takeScreenshot(named:)
    │
    └── Test Scenarios
        │
        ├── Scenario01_CompleteSessionLifecycle
        │   └── testCompleteSessionLifecycle()
        │
        ├── Scenario02_MultiSectionNavigation
        │   └── testMultiSectionNavigation()
        │
        ├── Scenario03_StreamingAndCancellation
        │   └── testStreamingAndCancellation()
        │
        ├── Scenario04_ErrorHandlingAndRecovery
        │   └── testErrorHandlingAndRecovery()
        │
        ├── Scenario05_ProjectManagement
        │   └── testProjectManagement()
        │
        ├── Scenario06_PluginOperations
        │   └── testPluginOperations()
        │
        ├── Scenario07_MCPServerManagement
        │   └── testMCPServerManagement()
        │
        ├── Scenario08_SettingsConfiguration
        │   └── testSettingsConfiguration()
        │
        ├── Scenario09_SkillsManagement
        │   └── testSkillsManagement()
        │
        └── Scenario10_DashboardAndAnalytics
            └── testDashboardAndAnalytics()
```

## Data Flow During Tests

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│             │  HTTP   │             │  SQL    │             │
│  iOS App    │◄───────►│  Backend    │◄───────►│  SQLite DB  │
│  (Simulator)│  REST   │  (Port 9090)│  Fluent │  (ils.sqlite)│
│             │  SSE    │             │         │             │
└──────┬──────┘         └─────────────┘         └─────────────┘
       │
       │ XCUITest
       │ Automation
       ▼
┌─────────────────────────────────────────────┐
│                                             │
│  Test Scenario                              │
│  ├─ Tap UI elements                         │
│  ├─ Enter text                              │
│  ├─ Verify UI state                         │
│  ├─ Check data loaded                       │
│  └─ Capture screenshots                     │
│                                             │
└─────────────────────────────────────────────┘
```

## Screenshot Naming Convention

```
S{scenario}_{step}_{description}.png
│     │       │          └─ Human-readable description
│     │       └─────────── Step number (01, 02, ...)
│     └─────────────────── Scenario number (01-10)
└───────────────────────── Scenario prefix

Examples:
  S01_01_app_launched.png
  S01_05_chat_view_opened.png
  S03_07_streaming_started.png
  S04_08_backend_restarted.png
  S09_13_scrolled_top.png
```

## Test State Management

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  Test Lifecycle                                         │
│                                                         │
│  1. setUpWithError()                                    │
│     ├─ Initialize XCUIApplication                       │
│     ├─ Set launch arguments                             │
│     └─ Set launch environment                           │
│                                                         │
│  2. testMethod()                                        │
│     ├─ startBackendIfNeeded()                          │
│     ├─ app.launch()                                     │
│     ├─ [Test steps...]                                  │
│     └─ Assertions + Screenshots                         │
│                                                         │
│  3. tearDownWithError()                                 │
│     ├─ Cleanup app reference                            │
│     └─ stopBackendIfNeeded()                           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Backend Health Check Logic

```
┌──────────────────────────────────────────┐
│                                          │
│  isBackendRunning()                      │
│  │                                       │
│  ├─ Attempt: GET /health                │
│  │  └─ Timeout: 2 seconds               │
│  │                                       │
│  ├─ Success (200 OK)                    │
│  │  └─ return true                      │
│  │                                       │
│  └─ Failure/Timeout                     │
│     └─ return false                     │
│                                          │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│                                          │
│  waitForBackend(timeout: 30s)            │
│  │                                       │
│  ├─ Loop every 1 second                 │
│  │  │                                    │
│  │  ├─ Call isBackendRunning()          │
│  │  │  │                                 │
│  │  │  ├─ true  → Success! Exit         │
│  │  │  └─ false → Continue loop         │
│  │  │                                    │
│  │  └─ After 30s → throw error          │
│  │                                       │
│  └─ Backend ready!                      │
│                                          │
└──────────────────────────────────────────┘
```

## CI/CD Integration Points

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  GitHub Actions Workflow                                │
│                                                         │
│  1. Checkout code                                       │
│  2. Install dependencies                                │
│  3. Build backend: swift build                          │
│  4. Start backend: swift run ILSBackend &              │
│  5. Run tests: ./scripts/run_regression_tests.sh       │
│  6. Upload artifacts: TestResults.xcresult              │
│  7. Cleanup: Kill backend process                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Error Recovery Test Flow (Scenario 4)

```
┌──────────────────────────────────────────────────────────┐
│  State: Backend Running                                  │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│  Action: Kill Backend Process                            │
│  (Simulates real-world failure)                          │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│  Expected: App detects disconnection                     │
│  - Shows error banner                                    │
│  - Starts retry polling (5s intervals)                   │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│  Action: Restart Backend                                 │
│  (swift run ILSBackend)                                  │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│  Expected: App auto-reconnects                           │
│  - Detects backend is back (via retry polling)           │
│  - Error banner disappears                               │
│  - Data reloads                                          │
│  - Full functionality restored                           │
└──────────────────────────────────────────────────────────┘
```

## Performance Testing Approach

```
Scenario 9: Skills Management
├─ Load 1527 skills
├─ Measure: Time to display
├─ Test: Search responsiveness
├─ Test: Rapid scrolling (5 swipes)
├─ Verify: No lag, no crashes
└─ Result: Pass if smooth at 60fps
```

---

**This architecture enables:**
- ✅ True integration testing
- ✅ Automatic backend management
- ✅ Real-world error simulation
- ✅ Performance validation
- ✅ CI/CD compatibility
