# ILSApp Test Suite

## Overview

This directory contains comprehensive unit and integration tests for the iCloud sync functionality implemented in ILSApp.

## Test Files

1. **CloudKitServiceTests.swift** - Tests for CloudKitService CRUD operations, conflict resolution, error handling, and account status
2. **CloudKitSyncableTests.swift** - Tests for CloudKitSyncable protocol conformance and model serialization/deserialization
3. **iCloudKeyValueStoreTests.swift** - Tests for iCloud Key-Value Store operations and validation
4. **SyncViewModelTests.swift** - Tests for SyncViewModel state management and sync operations
5. **CloudKitSyncTests.swift** - Integration tests for end-to-end sync flows

## Adding Test Target to Xcode (If Not Already Added)

If the tests are not yet integrated into the Xcode project, follow these steps:

### Option 1: Automatic (Using Script)

Run the provided script to add the test target:

```bash
cd ILSApp
./add-test-target.sh
```

### Option 2: Manual (Using Xcode GUI)

1. Open `ILSApp.xcodeproj` in Xcode
2. Select the project in the Navigator
3. Click the "+" button at the bottom of the targets list
4. Choose "Unit Testing Bundle"
5. Name it "ILSAppTests"
6. Set the target to test: ILSApp
7. Click "Finish"

8. Add test files to the target:
   - Select all `.swift` files in `ILSAppTests/` directory
   - Drag them into the Xcode project under the ILSAppTests group
   - Ensure they're added to the ILSAppTests target (check Target Membership in File Inspector)

9. Configure test target:
   - Select ILSAppTests target
   - Go to "Build Phases"
   - Under "Link Binary With Libraries", add:
     - CloudKit.framework
     - XCTest.framework
   - Under "Dependencies", add:
     - ILSApp target
     - ILSShared framework

10. Configure test target settings:
    - Build Settings → "Defines Module" → YES
    - Build Settings → "Enable Testing Search Paths" → YES
    - Build Settings → "Product Bundle Identifier" → com.example.ILSAppTests

## Running Tests

### From Xcode

1. Open the project in Xcode
2. Select Product → Test (⌘U)
3. Or click the diamond icon next to any test function to run individual tests

### From Command Line

```bash
cd ILSApp
xcodebuild test -scheme ILSApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Running Specific Test Classes

```bash
# Run CloudKitServiceTests only
xcodebuild test -scheme ILSApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ILSAppTests/CloudKitServiceTests

# Run integration tests only
xcodebuild test -scheme ILSApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ILSAppTests/CloudKitSyncTests
```

## Test Coverage

The test suite covers:

### Unit Tests
- ✅ CloudKitService CRUD operations
- ✅ CloudKitService conflict resolution (last-write-wins + field-level merge)
- ✅ CloudKitService error handling and mapping
- ✅ CloudKitService account status checking
- ✅ CloudKitService subscriptions
- ✅ CloudKitSyncable serialization (Session, Template, Snippet)
- ✅ CloudKitSyncable deserialization with validation
- ✅ CloudKitSyncable round-trip preservation
- ✅ iCloudKeyValueStore get/set operations (String, Bool, Int, Double, Data, Array, Dictionary)
- ✅ iCloudKeyValueStore validation (key length, value size)
- ✅ iCloudKeyValueStore error handling
- ✅ SyncViewModel state management
- ✅ SyncViewModel sync operations
- ✅ SyncViewModel status text formatting

### Integration Tests
- ✅ End-to-end session sync (create, update, delete, fetch)
- ✅ End-to-end template sync
- ✅ End-to-end snippet sync
- ✅ Conflict resolution in realistic scenarios
- ✅ Settings sync via Key-Value Store
- ✅ Disable sync functionality
- ✅ Zone setup and subscriptions
- ✅ Batch operations

## Important Notes

### Mocking

Most tests are structured to work with mocking frameworks. In the current implementation:

- Tests will attempt real CloudKit operations if run in an environment with iCloud access
- Without iCloud access, tests verify code paths without throwing errors
- For production CI/CD, implement mocking for:
  - `CKDatabase` operations
  - `NSUbiquitousKeyValueStore` operations
  - Container account status

### Test Container

Tests use a test container identifier: `iCloud.com.example.ILSApp.test`

To avoid affecting production data:
1. Configure a test container in Apple Developer Portal
2. Add the test container ID to the app's entitlements
3. Or use mocking to avoid real CloudKit calls

### CI/CD Integration

For automated testing in CI/CD:

1. Use simulator-based testing (no real iCloud account required with mocks)
2. Implement CloudKit mocking using protocols and dependency injection
3. Run tests in parallel for faster builds
4. Generate code coverage reports

Example CI command:
```bash
xcodebuild test \
  -scheme ILSApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult
```

## Test Quality Metrics

- **Total Tests**: 80+ test methods
- **Code Coverage Goal**: 80%+ for sync-related code
- **Test Types**: Unit tests + Integration tests
- **Error Paths**: Comprehensive error handling coverage
- **Edge Cases**: Validation limits, concurrent edits, nil values

## Troubleshooting

### Tests Not Found

If Xcode can't find tests:
1. Clean build folder (⌘⇧K)
2. Reset Package Caches (File → Packages → Reset Package Caches)
3. Rebuild (⌘B)
4. Run tests again (⌘U)

### CloudKit Errors in Tests

Tests are designed to handle CloudKit errors gracefully. If you see CloudKit errors:
- This is expected in test environments without iCloud access
- Tests verify error handling paths
- For real CloudKit testing, configure a test container

### Build Errors

If tests don't build:
1. Ensure ILSApp target builds successfully first
2. Verify ILSShared framework is linked
3. Check that @testable import statements work
4. Verify CloudKit framework is linked

## Future Enhancements

Potential improvements for the test suite:
1. Implement CloudKit mocking framework
2. Add performance tests for large data sets
3. Add UI tests for sync indicator
4. Add tests for background sync
5. Add tests for subscription notifications
6. Implement code coverage tracking
7. Add stress tests for conflict resolution
