# ILS iOS App UI Tests

Comprehensive E2E test suite for the ILS iOS application.

## Test Structure

### Test Classes

1. **ValidationGateTests** (8 tests)
   - Core chat flow validation
   - Session management
   - Message sending and streaming
   - Multi-turn conversations

2. **FeatureGateTests** (17 tests)
   - Projects list and creation
   - Skills list and search
   - MCP Servers list and search
   - Settings view sections
   - Plugins list and marketplace

3. **NavigationTests** (1 test)
   - Basic navigation flows

## Test Plan Configurations

The `ILSApp.xctestplan` file defines 6 test configurations:

### 1. Default Configuration
- **Purpose**: Standard test run for CI/CD
- **Language**: English (US)
- **Features**:
  - Random test ordering
  - Screenshots on failure only
  - Video recording on failure
- **Use when**: Running tests in CI or development

### 2. Quick Smoke Tests
- **Purpose**: Fast validation of core functionality
- **Duration**: ~2-3 minutes
- **Tests included**:
  - `ValidationGateTests/testGate1_SessionsListLoads`
  - `FeatureGateTests/testGate9_ProjectsListLoads`
  - `FeatureGateTests/testGate11_SkillsListLoads`
  - `FeatureGateTests/testGate13_SettingsViewLoads`
  - `FeatureGateTests/testGate14_PluginsListLoads`
- **Use when**: Pre-commit validation, quick sanity checks

### 3. Full Regression
- **Purpose**: Comprehensive testing with retry on failure
- **Features**:
  - All 26 tests
  - Up to 3 retry attempts on failure
  - Parallel execution enabled
  - Keep all screenshots and videos
- **Use when**: Pre-release validation, major refactoring

### 4-6. Localization Testing
- **German (de-DE)**
- **Japanese (ja-JP)**
- **Arabic (ar-SA)** - Tests RTL layout
- **Use when**: Internationalization validation

## Running Tests

### Using Xcode

1. Open `ILSApp.xcodeproj`
2. Select the `ILSApp` scheme
3. Product → Test (⌘U)
4. Choose a test plan configuration in the scheme editor

### Using Command Line

#### Quick Smoke Tests
```bash
./scripts/run-ui-tests.sh --quick
```

#### Full Regression Suite
```bash
./scripts/run-ui-tests.sh --full
```

#### Specific Configuration
```bash
./scripts/run-ui-tests.sh --config "Localization Testing - German"
```

#### Custom Device
```bash
./scripts/run-ui-tests.sh --device "iPad Pro (12.9-inch) (6th generation)"
```

#### Parallel Execution
```bash
./scripts/run-ui-tests.sh --parallel --full
```

### Script Options

```
-c, --config NAME       Test configuration to run
-q, --quick            Run quick smoke tests
-f, --full             Run full regression suite
-d, --device DEVICE    Device to test on
-o, --output DIR       Custom output directory
-p, --parallel         Enable parallel execution
-v, --verbose          Verbose output
-h, --help             Show help message
```

## Test Results

Results are saved to `test-results/` directory:
- `TestResults_TIMESTAMP.xcresult` - Full result bundle
- `summary_TIMESTAMP.json` - JSON summary
- `screenshots_TIMESTAMP/` - Exported screenshots

Open results in Xcode:
```bash
open test-results/TestResults_TIMESTAMP.xcresult
```

## Test Architecture

### Accessibility Identifiers

Tests rely on accessibility identifiers for element location:

**Navigation**
- `sidebarButton` - Sidebar toggle
- `sidebarDoneButton` - Sidebar dismiss
- `sidebar_sessions`, `sidebar_projects`, etc.

**Sessions View**
- `sessions-list` - Sessions list container
- `session-{id}` - Individual session cells
- `add-session-button` - New session button
- `loading-sessions-indicator` - Loading state

**Chat View**
- `chat-input-field` - Message input field
- `chat-input-bar` - Input container
- `send-button` - Send message button
- `streaming-indicator` - Streaming status

### Helper Methods

**Element Finders**
- `findSessionsList()` - Locates list across iOS versions
- `findFirstSessionCell()` - Finds tappable session cell
- `findChatInput()` - Locates chat input (TextField/TextView)
- `findSendButton()` - Locates send button
- `findList()` - Generic list finder
- `findFirstCell()` - Generic cell finder

**Wait Utilities**
- `waitForElement(_:timeout:)` - Wait for element to exist
- `waitForElementToDisappear(_:timeout:)` - Wait for removal
- `waitForChatViewToAppear(timeout:)` - Multi-strategy chat view detection

**Navigation**
- `openSidebar()` - Opens sidebar sheet
- `navigateToSidebarItem(_:)` - Navigate to section
- `performPullToRefresh()` - Pull-to-refresh gesture

### Screenshot Strategy

- **On Failure**: Automatic screenshot attachment
- **Named Screenshots**: Key validation points
- **Naming Convention**: `Gate{N}-{Description}`

Examples:
- `Gate1-SessionsListLoaded`
- `Gate4-ResponseReceived`
- `Gate14c-MarketplaceOpened`

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Run UI Tests
  run: |
    ./scripts/run-ui-tests.sh --quick --verbose

- name: Upload Test Results
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: test-results/
```

### Fastlane Integration

```ruby
lane :test_ui do
  run_tests(
    project: "ILSApp.xcodeproj",
    scheme: "ILSApp",
    testplan: "ILSApp",
    configuration: "Default Configuration",
    devices: ["iPhone 15 Pro"],
    result_bundle: true
  )
end
```

## Troubleshooting

### Tests Fail to Find Elements

1. **Check iOS version compatibility**: SwiftUI List rendering changed in iOS 18.6+
2. **Verify accessibility identifiers**: Ensure all views use `.accessibilityIdentifier()`
3. **Increase timeouts**: Network-dependent tests may need longer waits

### Sidebar Navigation Issues

- **iPhone vs iPad**: Sidebar is a sheet on iPhone, persistent on iPad
- **Solution**: Tests handle both cases with fallback strategies

### Chat Input Detection

- **Issue**: SwiftUI `TextField(axis: .vertical)` exposes as different types
- **Solution**: Tests try `textField`, `textView`, and coordinate-based approaches

### Session Cell Tapping

- **Issue**: iOS 18.6+ uses `collectionView` cells instead of `table` cells
- **Solution**: Tests query multiple container types

## Maintenance

### Adding New Tests

1. Add test method to appropriate test class
2. Use `testGateN_Description` naming convention
3. Add accessibility identifiers to views
4. Include screenshots at key validation points
5. Update this README with test description

### Updating Test Plan

Edit `ILSApp.xctestplan` to:
- Add new configurations
- Modify test selection for smoke tests
- Adjust timeout values
- Add new localization targets

## Performance Guidelines

| Configuration | Expected Duration |
|--------------|------------------|
| Quick Smoke Tests | 2-3 minutes |
| Default Configuration | 8-12 minutes |
| Full Regression | 15-20 minutes |
| Localization Testing | 10-15 minutes each |

## Known Limitations

1. **Backend Dependency**: Tests require running backend server
2. **Network Timing**: Streaming tests may be flaky with slow connections
3. **iOS Version Differences**: Element hierarchy varies across iOS versions
4. **Simulator Only**: Tests designed for simulator, not physical devices

## Future Enhancements

- [ ] Add performance testing (launch time, memory usage)
- [ ] Implement visual regression testing
- [ ] Add network condition simulation
- [ ] Create test data fixtures
- [ ] Add accessibility audit tests
- [ ] Implement screenshot diffing
