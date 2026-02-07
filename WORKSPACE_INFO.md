# ILS Full Stack Workspace

## Location

```
/Users/nick/Desktop/ils-ios/ILSFullStack.xcworkspace
```

## Opening the Workspace

```bash
cd /Users/nick/Desktop/ils-ios
open ILSFullStack.xcworkspace
```

## Workspace Contents

The workspace includes:

1. **ILSApp.xcodeproj** - iOS Application
   - Location: `ILSApp/ILSApp.xcodeproj`
   - Contains: iOS app, UI tests, test helpers

2. **Package.swift** - Swift Backend
   - Location: Root directory
   - Contains: ILSBackend, ILSShared targets

## Available Schemes

| Scheme | Purpose | Build Command |
|--------|---------|---------------|
| **ILSApp** | iOS Application + Tests | `xcodebuild -scheme ILSApp` |
| **ILSBackend** | Swift Backend Server | `swift build --product ILSBackend` |
| **ILSShared** | Shared Models | `swift build --product ILSShared` |

## Building

### Build iOS App
```bash
xcodebuild -workspace ILSFullStack.xcworkspace \
           -scheme ILSApp \
           -sdk iphonesimulator \
           -destination 'generic/platform=iOS Simulator' \
           build
```

### Build Backend
```bash
cd /Users/nick/Desktop/ils-ios
swift build --product ILSBackend
```

### Build Tests
```bash
xcodebuild -workspace ILSFullStack.xcworkspace \
           -scheme ILSApp \
           -sdk iphonesimulator \
           -destination 'generic/platform=iOS Simulator' \
           build-for-testing
```

## Running Tests

### All Tests
```bash
./scripts/run_regression_tests.sh
```

### Via Xcode
1. Open workspace: `open ILSFullStack.xcworkspace`
2. Select ILSApp scheme
3. Press ⌘U to run tests

### Specific Test
```bash
xcodebuild test \
  -workspace ILSFullStack.xcworkspace \
  -scheme ILSApp \
  -destination 'generic/platform=iOS Simulator' \
  -only-testing:ILSAppUITests/Scenario11_ExtendedChatConversation
```

## Test Scenarios

The workspace includes 11 UI test scenarios:
1. Scenario01 - Complete Session Lifecycle (with 3 chat exchanges)
2. Scenario02 - Multi-Section Navigation
3. Scenario03 - Streaming and Cancellation
4. Scenario04 - Error Handling and Recovery
5. Scenario05 - Project Management
6. Scenario06 - Plugin Operations
7. Scenario07 - MCP Server Management
8. Scenario08 - Settings Configuration
9. Scenario09 - Skills Management
10. Scenario10 - Dashboard and Analytics
11. **Scenario11 - Extended Chat Conversation** (NEW - 8 exchanges, 30 screenshots)

## Workspace Structure

```
ILSFullStack.xcworkspace/
└── contents.xcworkspacedata    ← Workspace definition

Components:
├── ILSApp/
│   └── ILSApp.xcodeproj        ← iOS project
│       ├── ILSApp/             ← iOS app source
│       └── ILSAppUITests/      ← UI tests (11 scenarios)
│
└── Package.swift               ← Swift Package (Backend + Shared)
    ├── ILSBackend target       ← Server
    └── ILSShared target        ← Models
```

## Verification

### Check Workspace is Valid
```bash
xcodebuild -list -workspace ILSFullStack.xcworkspace
```

Expected output:
```
Information about workspace "ILSFullStack":
    Schemes:
        ILSApp
        ILSBackend
        ILSShared
```

### Check Tests Compile
```bash
xcodebuild -workspace ILSFullStack.xcworkspace \
           -scheme ILSApp \
           -sdk iphonesimulator \
           -destination 'generic/platform=iOS Simulator' \
           build-for-testing

# Should output: ** TEST BUILD SUCCEEDED **
```

## Status

✅ Workspace created and verified
✅ All 3 schemes available
✅ iOS app builds successfully
✅ All 11 test scenarios compile
✅ Ready to run tests

## Next Steps

1. **Run full test suite:**
   ```bash
   ./scripts/run_regression_tests.sh
   ```

2. **Open in Xcode:**
   ```bash
   open ILSFullStack.xcworkspace
   ```

3. **Run tests in Xcode:**
   - Press ⌘U
   - View results in Report Navigator (⌘9)
   - Screenshots automatically attached

---

**Created:** February 6, 2026
**Status:** ✅ Working
**Build Status:** ✅ TEST BUILD SUCCEEDED
