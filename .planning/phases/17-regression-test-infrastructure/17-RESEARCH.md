# Phase 17: Regression Test Infrastructure - Research

**Researched:** 2026-02-23
**Domain:** XCTest Performance Baselines + MetricKit Production Metrics
**Confidence:** HIGH

## Summary

Phase 17 adds XCTest performance measurement tests and a MetricKit subscriber to the ILS iOS app. XCTest performance tests use `measure(metrics:)` with `XCTApplicationLaunchMetric`, `XCTMemoryMetric`, and `XCTCPUMetric` to establish CI-enforceable baselines for launch time, memory, and CPU. MetricKit provides a daily production feedback loop via `MXMetricManagerSubscriber`. All APIs are built into the Apple SDK -- zero new dependencies required.

The existing `ILSAppUITests` target (defined in `project.yml` as `bundle.ui-testing`) already contains regression tests, smoke tests, and validation gate tests. Performance measurement tests can be added directly to this target -- no new Xcode target is needed. The existing `ILSApp.xctestplan` can be extended with a "Performance Baselines" configuration.

**Primary recommendation:** Add performance test files to the existing `ILSAppUITests` target using `measure(metrics:)` with `XCTApplicationLaunchMetric` for launch, `XCTCPUMetric(application:)` for scroll CPU, and `XCTOSSignpostMetric.scrollingAndDecelerationMetric` for scroll hitches. For memory, use `XCTMemoryMetric(application:)` but validate it returns non-zero values on the dedicated simulator before setting a baseline. Add a standalone `PerformanceMonitor` service class conforming to `MXMetricManagerSubscriber` in the main app target for production metrics.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TEST-01 | XCTest launch time baseline using XCTApplicationLaunchMetric, fails if > 1.5s | `XCTApplicationLaunchMetric` API confirmed stable since iOS 13.4+; `measure(metrics:)` with 5+1 iterations; baseline set via Xcode UI or xctestplan |
| TEST-02 | XCTest memory baseline using XCTMemoryMetric, fails if > 120MB | `XCTMemoryMetric(application:)` confirmed but has known reliability issues (may report zero on some configurations); fallback to `XCTMemoryMetric()` without app parameter if needed |
| TEST-03 | XCTest CPU baseline using XCTCPUMetric for sessions list scroll/render | `XCTCPUMetric(application:)` measures CPU during scrolling; combine with `XCTOSSignpostMetric.scrollingAndDecelerationMetric` for hitch ratio |
| TEST-04 | MetricKit subscriber logs MXAppLaunchMetric, MXMemoryMetric in production | `MXMetricManagerSubscriber` protocol with `didReceive(_: [MXMetricPayload])` and `didReceive(_: [MXDiagnosticPayload])`; daily delivery; iOS 13+ |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| XCTest | Built-in (Xcode 16+) | Performance measurement baselines | Apple's only supported test framework; `measure(metrics:)` API stable since Xcode 11 / iOS 13.4 |
| MetricKit | Built-in (iOS 13+) | Production field performance metrics | Apple's only supported production metric collection framework; daily aggregated payloads |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| os.signpost / OSSignposter | Built-in (iOS 15+) | Custom instrumentation intervals | When measuring specific code paths (network, render) beyond built-in metrics; feeds into XCTOSSignpostMetric |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| XCTMemoryMetric | Instruments Memory Allocations trace | Instruments is not CI-automatable; XCTMemoryMetric integrates with xcodebuild test |
| MetricKit | Firebase Performance / Datadog RUM | Third-party SDKs add binary size and privacy concerns; MetricKit is zero-dependency and OS-integrated |
| XCTOSSignpostMetric.scrollingAndDecelerationMetric | Manual frame timing | Signpost metric gives hitch ratio and frame rate automatically; manual timing is error-prone |

**Installation:** None required -- all APIs are in the Apple SDK.

## Architecture Patterns

### Recommended Project Structure

```
ILSApp/
├── ILSAppUITests/
│   ├── PerformanceTests/
│   │   ├── LaunchPerformanceTests.swift     # TEST-01: XCTApplicationLaunchMetric
│   │   ├── MemoryPerformanceTests.swift     # TEST-02: XCTMemoryMetric
│   │   └── ScrollPerformanceTests.swift     # TEST-03: XCTCPUMetric + scroll
│   ├── RegressionTests/          # (existing)
│   ├── TestHelpers/              # (existing)
│   ├── CISmokeTests.swift        # (existing)
│   └── ValidationGateTests.swift # (existing)
├── ILSApp/
│   └── Services/
│       └── PerformanceMonitor.swift  # TEST-04: MetricKit subscriber
```

### Pattern 1: XCTest Performance Measurement (UI Test Target)

**What:** Use `measure(metrics:)` in the existing `ILSAppUITests` target to record app-level performance baselines.
**When to use:** For all three XCTest performance requirements (TEST-01, TEST-02, TEST-03).
**Why UI test target:** XCTApplicationLaunchMetric, XCTMemoryMetric(application:), and XCTCPUMetric(application:) require an `XCUIApplication` instance, which is only available in UI test targets.

```swift
// Source: Apple XCTest documentation + verified community patterns
import XCTest

final class LaunchPerformanceTests: XCTestCase {
    func testAppLaunchTime() throws {
        // XCTApplicationLaunchMetric measures wall-clock launch time
        // Default: 5 measurement iterations + 1 discarded warm-up
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
        // After first run, set baseline in Xcode (gray diamond icon)
        // Baseline is stored in .xcresult / test plan
        // Future runs fail if metric exceeds baseline + allowed stddev
    }
}
```

### Pattern 2: Scroll Performance with Manual Stop (UI Test Target)

**What:** Measure CPU and scroll hitch metrics during a controlled swipe gesture, using `manuallyStop` to exclude reset operations.
**When to use:** For TEST-03 (scroll/render CPU baseline).

```swift
// Source: dev.to/mtmorozov + Apple WWDC19 session 417
import XCTest

final class ScrollPerformanceTests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = ["BACKEND_URL": "http://localhost:9999"]
        app.launch()
    }

    func testSessionsListScrollPerformance() throws {
        // Navigate to sessions list (it's the default screen)
        let collection = app.collectionViews.firstMatch
        guard collection.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list did not appear")
            return
        }

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]

        measure(
            metrics: [
                XCTCPUMetric(application: app),
                XCTOSSignpostMetric.scrollingAndDecelerationMetric
            ],
            options: options
        ) {
            collection.swipeUp(velocity: .fast)
            stopMeasuring()
            collection.swipeDown(velocity: .fast)
        }
    }
}
```

### Pattern 3: MetricKit Subscriber (Main App Target)

**What:** A standalone `NSObject` subclass conforming to `MXMetricManagerSubscriber` that logs daily payloads.
**When to use:** For TEST-04 (production field metrics).

```swift
// Source: SwiftLee + Swift with Majid MetricKit guides
import MetricKit

final class PerformanceMonitor: NSObject, MXMetricManagerSubscriber {
    static let shared = PerformanceMonitor()

    func start() {
        MXMetricManager.shared.add(self)
    }

    func stop() {
        MXMetricManager.shared.remove(self)
    }

    // Called at most once per day with previous 24h of data
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            if let launch = payload.applicationLaunchMetrics {
                AppLogger.shared.info(
                    "MetricKit launch: \(launch.histogrammedTimeToFirstDraw)",
                    category: "performance"
                )
            }
            if let memory = payload.memoryMetrics {
                AppLogger.shared.info(
                    "MetricKit memory: peak=\(memory.peakMemoryUsage)",
                    category: "performance"
                )
            }
            // Full JSON for archival
            AppLogger.shared.info(
                "MetricKit payload: \(payload.jsonRepresentation())",
                category: "performance"
            )
        }
    }

    // Crash diagnostics, hangs, CPU exceptions
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            AppLogger.shared.error(
                "MetricKit diagnostic: \(payload.jsonRepresentation())",
                category: "performance"
            )
        }
    }
}
```

**Registration point:** Call `PerformanceMonitor.shared.start()` in `ILSAppApp.swift` inside the `.task` modifier (alongside TipKit init and CacheService init).

### Anti-Patterns to Avoid

- **Adding a new Xcode target for performance tests:** The existing `ILSAppUITests` target is already configured as `bundle.ui-testing` with the correct `TEST_TARGET_NAME: ILSApp` dependency. Adding a separate target creates build complexity for no benefit.
- **Using XCTMemoryMetric() without application parameter:** Reports memory of the test runner process, not the app under test. Always pass `XCTMemoryMetric(application: app)`.
- **Hardcoding absolute baseline thresholds in code:** Xcode manages baselines per-device. Use the Xcode UI (gray diamond icon in test navigator) or xctestplan to set baselines. Code should only call `measure(metrics:)`.
- **Running performance tests in random order:** Performance tests should run sequentially to avoid interference. Use a dedicated test plan configuration with `testExecutionOrdering: sequential`.
- **Calling MetricKit subscriber registration before first frame:** Register in `.task` (after first frame) to avoid blocking launch.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Launch time measurement | Manual `CFAbsoluteTimeGetCurrent()` timing | `XCTApplicationLaunchMetric` | Apple's metric uses OS-level signposts with precise first-frame detection; manual timing misses dyld, pre-main, and first-frame boundaries |
| Memory baseline | Manual `task_info` / `mach_task_basic_info` calls | `XCTMemoryMetric(application:)` | Metric captures physical footprint, dirty memory, and peak values across iterations automatically |
| Scroll hitch detection | Manual CADisplayLink frame counting | `XCTOSSignpostMetric.scrollingAndDecelerationMetric` | OS signpost captures hitch time ratio, frame rate, and frame count without custom code |
| Production metrics collection | Custom analytics for CPU/memory | MetricKit `MXMetricManagerSubscriber` | OS-aggregated, battery-friendly, no custom collection overhead; provides histogrammed data |

**Key insight:** Every performance measurement problem in this phase has a first-party Apple API. Custom solutions are strictly worse because they lack OS-level visibility into process lifecycle events (dyld load, first frame, scroll compositor hitches).

## Common Pitfalls

### Pitfall 1: XCTMemoryMetric Reports Zero

**What goes wrong:** `XCTMemoryMetric(application: app)` returns 0 KB in some Xcode versions and simulator configurations. Developers on Apple Developer Forums have reported this consistently.
**Why it happens:** The metric queries the target app's physical memory footprint via XPC; some Xcode/simulator combinations fail to establish the XPC connection properly.
**How to avoid:** (1) Verify on the dedicated simulator (UDID `50523130-57AA-48B0-ABD0-4D59CE455F14`) that values are non-zero before setting a baseline. (2) If zero, fall back to `XCTMemoryMetric()` (measures test runner process -- less accurate but non-zero). (3) Consider supplementing with MetricKit field data (TEST-04) as the authoritative memory measurement.
**Warning signs:** Baseline shows "0.000 kB" in Xcode test results.

### Pitfall 2: Simulator vs Device Baseline Mismatch

**What goes wrong:** Baselines set on the simulator do not match device performance. Launch time may be 2-3x faster on simulator than real hardware (or vice versa depending on Mac specs).
**Why it happens:** Simulator uses host CPU/memory; device has its own constraints.
**How to avoid:** (1) Use simulator baselines for CI regression detection (relative comparison). (2) Set generous thresholds (1.5s launch, 120MB memory) that accommodate simulator variance. (3) Use MetricKit (TEST-04) for absolute production targets.
**Warning signs:** Tests that pass on CI but field data shows regressions, or tests that are flaky across different CI machines.

### Pitfall 3: Performance Test Flakiness

**What goes wrong:** Performance tests fail intermittently due to system load, background processes, or thermal throttling on CI machines.
**Why it happens:** `measure(metrics:)` runs 5 iterations and compares against baseline with 10% standard deviation by default. System variance can exceed this.
**How to avoid:** (1) Set baseline standard deviation to 20-25% for CI stability. (2) Use the xctestplan "Performance Baselines" configuration with `testRepetitionMode: retryOnFailure` and `maximumTestRepetitions: 2`. (3) Avoid running performance tests alongside other heavyweight tests.
**Warning signs:** Tests pass locally but fail on CI, or pass 4/5 runs.

### Pitfall 4: MetricKit Payloads Not Received in Debug

**What goes wrong:** `didReceive(_:)` never fires during development.
**Why it happens:** MetricKit delivers payloads once per day in production. In debug, you must use Xcode's Debug Navigator > Metrics to manually trigger a simulated payload.
**How to avoid:** (1) Test MetricKit integration using Xcode's Debug Navigator "Simulate MetricKit Payload" feature. (2) Log subscriber registration to confirm `start()` was called. (3) Do not expect real-time metric delivery.
**Warning signs:** `PerformanceMonitor.start()` is called but `didReceive` is never invoked in debug sessions.

### Pitfall 5: Backend Must Be Running for Performance Tests

**What goes wrong:** Performance tests time out or crash because the app can't connect to the backend.
**Why it happens:** The ILS app requires a backend at localhost:9999 for sessions list data. Without it, the sessions list is empty and scroll tests have nothing to scroll.
**How to avoid:** (1) Use the existing `XCUITestBase` pattern that checks `isBackendRunning()`. (2) Set `app.launchEnvironment = ["BACKEND_URL": "http://localhost:9999"]`. (3) Document in test plan that `PORT=9999 swift run ILSBackend` must be running.
**Warning signs:** Tests fail with empty list or timeout waiting for collection view.

## Code Examples

### Complete Launch Performance Test

```swift
import XCTest

final class LaunchPerformanceTests: XCTestCase {
    func testColdLaunchPerformance() throws {
        // XCTApplicationLaunchMetric measures from process start to first frame
        // Baseline target: 1.5 seconds (Phase 11 measured 838ms, generous margin)
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    func testWarmLaunchPerformance() throws {
        // waitUntilResponsive: true measures until app is interactive
        if #available(iOS 14.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
                XCUIApplication().launch()
            }
        }
    }
}
```

### Complete Memory Performance Test

```swift
import XCTest

final class MemoryPerformanceTests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = ["BACKEND_URL": "http://localhost:9999"]
        app.launch()
    }

    func testSessionBrowsingMemory() throws {
        // Baseline target: 120MB during typical browsing
        // Phase 11 measured 273MB RSS at cold start -- this metric captures
        // physical footprint which is lower than RSS
        let sessions = app.collectionViews.firstMatch
        guard sessions.waitForExistence(timeout: 15) else {
            XCTFail("Sessions list not found")
            return
        }

        measure(metrics: [XCTMemoryMetric(application: app)]) {
            // Browse through sessions
            sessions.swipeUp()
            sessions.swipeUp()
            sessions.swipeDown()
        }
    }
}
```

### Complete MetricKit Subscriber

```swift
import MetricKit
#if canImport(UIKit)
import UIKit
#endif

final class PerformanceMonitor: NSObject, MXMetricManagerSubscriber {
    static let shared = PerformanceMonitor()

    private override init() {
        super.init()
    }

    func start() {
        MXMetricManager.shared.add(self)
        AppLogger.shared.info("MetricKit subscriber registered", category: "performance")
    }

    func stop() {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            // MXAppLaunchMetric
            if let launch = payload.applicationLaunchMetrics {
                AppLogger.shared.info(
                    "MetricKit launch: timeToFirstDraw=\(launch.histogrammedTimeToFirstDraw)",
                    category: "performance"
                )
            }

            // MXMemoryMetric
            if let memory = payload.memoryMetrics {
                AppLogger.shared.info(
                    "MetricKit memory: peak=\(memory.peakMemoryUsage)",
                    category: "performance"
                )
            }

            // Full JSON for structured logging / future analytics
            if let jsonData = try? JSONSerialization.data(
                withJSONObject: payload.dictionaryRepresentation(),
                options: .prettyPrinted
            ), let jsonString = String(data: jsonData, encoding: .utf8) {
                AppLogger.shared.info(
                    "MetricKit full payload:\n\(jsonString)",
                    category: "performance"
                )
            }
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            if let jsonData = try? JSONSerialization.data(
                withJSONObject: payload.dictionaryRepresentation(),
                options: .prettyPrinted
            ), let jsonString = String(data: jsonData, encoding: .utf8) {
                AppLogger.shared.error(
                    "MetricKit diagnostic:\n\(jsonString)",
                    category: "performance"
                )
            }
        }
    }
}
```

### Test Plan Configuration Addition

```json
{
  "id": "PERF-TEST-0001-0002-0003-0004-000000000001",
  "name": "Performance Baselines",
  "options": {
    "language": "en",
    "region": "US",
    "testExecutionOrdering": "sequential",
    "uiTestingScreenshotsLifetime": "deleteOnSuccess",
    "videoRecordingMode": "recordOnFailure",
    "maximumTestRepetitions": 2,
    "testRepetitionMode": "retryOnFailure"
  },
  "testTargets": [
    {
      "target": {
        "containerPath": "container:ILSApp.xcodeproj",
        "identifier": "ILSAppUITests",
        "name": "ILSAppUITests"
      },
      "selectedTests": [
        "LaunchPerformanceTests",
        "MemoryPerformanceTests",
        "ScrollPerformanceTests"
      ]
    }
  ]
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `XCTPerformanceMetric` (single wall-clock metric) | `XCTMetric` protocol + `measure(metrics:)` | Xcode 11 / iOS 13 (2019) | Multiple metrics per test, typed metric classes |
| `XCTOSSignpostMetric.applicationLaunch` only | `XCTApplicationLaunchMetric(waitUntilResponsive:)` | Xcode 12 / iOS 14 (2020) | Responsive launch measurement, not just first frame |
| No scroll hitch metrics | `XCTOSSignpostMetric.scrollingAndDecelerationMetric` | Xcode 12 / iOS 14 (2020) | Automatic hitch time ratio, frame rate capture |
| Manual performance logging | MetricKit `MXMetricManagerSubscriber` | iOS 13 (2019) | OS-aggregated daily payloads, zero collection overhead |

**Deprecated/outdated:**
- `measureMetrics(_:automaticallyStartMeasuring:for:)`: Old API; replaced by `measure(metrics:options:)` with `XCTMeasureOptions`
- Manual `CFAbsoluteTimeGetCurrent()` timing: Replaced by `XCTApplicationLaunchMetric` which captures OS-level launch boundaries

## Open Questions

1. **XCTMemoryMetric reliability on dedicated simulator**
   - What we know: Known issue where `XCTMemoryMetric(application:)` returns zero on some configurations
   - What's unclear: Whether it works on the specific simulator UDID `50523130-57AA-48B0-ABD0-4D59CE455F14` with iOS 18.6
   - Recommendation: First task should verify XCTMemoryMetric returns non-zero values. If zero, document as known limitation and rely on MetricKit for memory field data (TEST-04 covers production memory).

2. **Baseline storage and CI integration**
   - What we know: Baselines are stored per-device in `.xcresult` bundles and Xcode test plans
   - What's unclear: Whether `xcodebuild test` on CI can enforce baselines set via Xcode UI without manual intervention
   - Recommendation: Set baselines via Xcode UI on first run, commit any generated baseline plist files. Verify `xcodebuild test` respects them on re-run.

3. **Phase 11 baseline discrepancy**
   - What we know: Phase 11 measured 838ms cold-start and 273MB RSS via Instruments
   - What's unclear: How XCTApplicationLaunchMetric's measurement compares to Instruments Time Profiler (different measurement boundaries)
   - Recommendation: Run the XCTest launch measurement first, compare with 838ms Instruments baseline, then set the XCTest baseline from actual measured value (not the Instruments value).

## Existing Infrastructure (Reuse)

The project already has substantial test infrastructure that Phase 17 builds on:

| Asset | Location | Reuse Strategy |
|-------|----------|----------------|
| UI test target | `ILSAppUITests` in `project.yml` | Add performance test files to existing target |
| Test base class | `TestHelpers/XCUITestBase.swift` | Reuse `isBackendRunning()` check pattern |
| Test plan | `ILSApp.xctestplan` | Add "Performance Baselines" configuration |
| CI smoke tests | `CISmokeTests.swift` | Reference launch pattern for performance test setup |
| Regression tests | `RegressionTests/` directory | Co-locate performance tests in `PerformanceTests/` sibling directory |
| AppLogger | `Services/AppLogger.swift` | MetricKit subscriber logs via AppLogger |
| App entry point | `ILSAppApp.swift` | Register PerformanceMonitor in `.task` modifier |

**No AppDelegate exists** in the iOS target (pure SwiftUI `@main` struct). The `PerformanceMonitor` must be a standalone `NSObject` subclass, not an `AppDelegate` extension. Register it via `PerformanceMonitor.shared.start()` in the existing `.task` block in `ILSAppApp.swift`.

## Sources

### Primary (HIGH confidence)
- [Apple XCTApplicationLaunchMetric documentation](https://developer.apple.com/documentation/xctest/xctapplicationlaunchmetric) - API structure, initializers
- [Apple XCTest Performance Tests documentation](https://developer.apple.com/documentation/xctest/performance-tests) - measure(metrics:) API
- [Apple MXMetricManager documentation](https://developer.apple.com/documentation/metrickit/mxmetricmanager) - MetricKit subscriber pattern
- [Apple WWDC19 Session 417 - Improving Battery Life and Performance](https://developer.apple.com/videos/play/wwdc2019/417/) - XCTest metrics introduction

### Secondary (MEDIUM confidence)
- [Performance testing in Swift using XCTest - Swift with Majid](https://swiftwithmajid.com/2023/03/15/performance-testing-in-swift-using-xctest-framework/) - Code patterns verified against Apple docs
- [Using MetricKit to monitor launch times - SwiftLee](https://www.avanderlee.com/swift/metrickit-launch-time/) - MetricKit subscriber pattern, payload structure, delivery cadence
- [Monitoring app performance with MetricKit - Swift with Majid](https://swiftwithmajid.com/2025/12/09/monitoring-app-performance-with-metrickit/) - Updated 2025 MetricKit patterns
- [Discovering UI Performance testing - Scrolling Performance](https://dev.to/mtmorozov/discovering-ui-performance-testing-with-xctest-scrolling-performance-pon) - XCTOSSignpostMetric.scrollingAndDecelerationMetric usage
- [Performance testing with XCTest - ChimeHQ](https://www.chimehq.com/blog/xctest-performance) - XCTMemoryMetric zero-value pitfall documented
- [Performance testing using XCTMetric - Augmented Code](https://augmentedcode.io/2019/12/22/performance-testing-using-xctmetric/) - XCTCPUMetric, XCTMemoryMetric, XCTStorageMetric patterns

### Tertiary (LOW confidence)
- [Apple Developer Forums thread 675561](https://developer.apple.com/forums/thread/675561) - XCTMemoryMetric/XCTCPUMetric zero-value reports (community-reported, not officially confirmed as bug)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All APIs are first-party Apple SDK, stable since iOS 13-14
- Architecture: HIGH - Existing UI test target confirmed, project.yml and pbxproj analyzed, patterns verified from multiple sources
- Pitfalls: MEDIUM - XCTMemoryMetric zero-value issue is community-reported but not officially documented; requires validation on dedicated simulator

**Research date:** 2026-02-23
**Valid until:** 2026-04-23 (stable APIs, unlikely to change)
