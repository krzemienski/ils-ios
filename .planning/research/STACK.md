# Technology Stack — Performance Optimization

**Project:** ILS iOS/macOS Performance Optimization Suite (v2.0)
**Researched:** 2026-02-22
**Mode:** Ecosystem + Feasibility (What needs to change vs. what already exists)

---

## Executive Summary

The ILS app already has a solid performance foundation: an actor-based `APIClient` with per-endpoint TTL caching, GRDB-backed `CacheService`, `LazyVStack` in `ChatMessageList`, search caching in `SessionsViewModel`, and structured concurrency throughout. The performance work is surgical, not architectural.

**What must change:** Eliminate the 2.2s artificial launch delay, add request deduplication to the actor layer, hook up Low Power Mode awareness, and add XCTest performance baseline infrastructure.

**What does NOT need to change:** The network stack (actor-based URLSession is correct), the GRDB caching layer (already well-structured), the `LazyVStack` in chat (already implemented), or the `@Observable` ViewModel pattern (already in place and correct for iOS 17+).

No new SPM packages are required. All performance APIs needed are in the Apple SDK.

---

## Current Stack — Confirmed Capabilities

| Component | File | Confirmed State |
|-----------|------|----------------|
| NSCache in-memory cache | `APIClient.swift` | Present, per-endpoint TTL, 100-entry limit |
| GRDB 7.0+ SQLite cache | `LocalDatabase.swift`, `CacheService.swift` | Present, full CRUD for sessions/messages/skills/MCP/plugins |
| `LazyVStack` in chat | `ChatMessageList.swift` | Present, with `ForEach(Array(messages.enumerated()))` |
| `@ScaledMetric` | `ChatMessageList.swift` (3 uses) | Present for message/sender spacing |
| `@Observable @MainActor` VMs | All ViewModels | Present, iOS 17+ pattern |
| Search precomputation cache | `SessionsViewModel.swift` | Present, `searchCache` array |
| Exponential backoff polling | `PollingManager.swift` | Present, 5s–60s cap |
| Retry queue (SyncCoordinator) | `SyncCoordinator.swift` | Present, max 3 retries |
| NetworkMonitor | `NetworkMonitor.swift` | Present |
| `accessibilityReduceMotion` | Multiple views | Present, respected in animations |
| **Artificial 2.2s launch delay** | `ILSAppApp.swift` line 52 | **BUG: `try? await Task.sleep(for: .seconds(2.2))`** |

---

## Recommended Stack Additions

### 1. Launch Optimization — Zero New Dependencies

**What:** Remove the `Task.sleep(for: .seconds(2.2))` in `ILSAppApp.swift` and replace it with a content-driven dismiss strategy.

**Why:** Apple targets 400ms first-frame render. The delay is entirely artificial — the PROJECT.md notes it was a known issue from prior audit. Removing it directly achieves PERF-01 (`< 1 second cold start`).

**Pattern to implement:**

```swift
// INSTEAD of Task.sleep(for: .seconds(2.2))
// Dismiss launch screen when CacheService.initialize() completes
.task {
    try? Tips.configure([.displayFrequency(.daily), .datastoreLocation(.applicationDefault)])
    await CacheService.shared.initialize()
    withAnimation(.easeOut(duration: 0.3)) {
        showLaunchScreen = false
    }
}
```

**Confidence:** HIGH — the bug is visible in the codebase; the fix is a one-line change.

---

### 2. Request Deduplication — No New Dependencies

**What:** Add in-flight request deduplication to `APIClient` using a Swift actor dictionary of `[String: Task<Data, Error>]`.

**Why:** When `HomeView`, `SidebarView`, and `DashboardViewModel` all wake simultaneously after the launch screen, they fire redundant `/sessions`, `/stats`, and `/health` requests. The actor isolation of `APIClient` makes this the right place — callers await the *same* Task instead of launching duplicates.

**Pattern to implement:**

```swift
// In APIClient (already an actor)
private var inflight: [String: Task<Data, Error>] = [:]

func fetch<T: Decodable>(_ path: String, ...) async throws -> T {
    let key = "\(path)"
    if let existing = inflight[key] {
        let data = try await existing.value
        return try decoder.decode(T.self, from: data)
    }
    let task = Task<Data, Error> {
        // existing fetch logic
        return rawData
    }
    inflight[key] = task
    defer { inflight.removeValue(forKey: key) }
    let data = try await task.value
    return try decoder.decode(T.self, from: data)
}
```

**Confidence:** HIGH — Swift actor re-entrancy makes this safe; the pattern is established for Swift structured concurrency.

---

### 3. Low Power Mode Awareness — No New Dependencies

**What:** Subscribe to `NSProcessInfoPowerStateDidChange` notification and reduce polling frequency and animations in Low Power Mode.

**Why:** The `MetricsWebSocketClient` runs heartbeats every 15 seconds and `PollingManager` retries up to every 5 seconds. In Low Power Mode these intervals should double. This is a critical path to PERF-06 (battery "Low" rating).

**APIs (all iOS 9+, zero additional packages):**

```swift
// In AppState or a dedicated BatteryMonitor service
import Foundation

ProcessInfo.processInfo.isLowPowerModeEnabled // Bool, current state

NotificationCenter.default.addObserver(
    forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
    object: nil,
    queue: .main
) { _ in
    let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    // Adjust polling intervals, suppress non-essential animations
}
```

**Integration points:**
- `PollingManager`: extend minimum retry interval from 5s → 10s in Low Power Mode
- `MetricsWebSocketClient`: extend heartbeat from 15s → 30s
- `SidebarRootView` / `HomeView`: respect `accessibilityReduceMotion` (already present) and additionally check `isLowPowerModeEnabled` before `.animation()` calls
- `FeatureGate`: optionally gate `advancedMonitoring` polling in Low Power Mode

**Note:** Low Power Mode is iPhone-only. iPad always returns `false`. macOS: use `NSProcessInfo.processInfo.isLowPowerModeEnabled` (available macOS 12+).

**Confidence:** HIGH — stable API since iOS 9; pattern is documented and widely used.

---

### 4. Memory Pressure Handling — No New Dependencies

**What:** Subscribe to `UIApplication.didReceiveMemoryWarningNotification` and purge NSCache + GRDB caches under memory pressure.

**Why:** The in-memory `NSCache` in `APIClient` (100-entry limit) and GRDB's query cache can accumulate. When the system sends a memory warning, the right response is to clear the NSCache and mark non-critical data as expired.

**APIs:**

```swift
// In APIClient (already has NSCache)
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: nil
) { [weak self] _ in
    Task { await self?.evictCache() }
}

func evictCache() {
    cache.removeAllObjects() // NSCache.removeAllObjects()
}
```

```swift
// In CacheService
func handleMemoryPressure() async {
    // Keep sessions (user-visible), drop reference data
    try? await db.clearSkills()
    try? await db.clearPlugins()
    AppLogger.shared.warning("Memory pressure: evicted reference data", category: "cache")
}
```

**Confidence:** HIGH — standard iOS pattern; `UIApplication.didReceiveMemoryWarningNotification` is stable since iOS 2.

---

### 5. XCTest Performance Baseline Infrastructure — No New Dependencies, New Test Target

**What:** Add a UI test target (or use the existing `ILSAppTests` scheme) with `measure(metrics:)` blocks using `XCTApplicationLaunchMetric`, `XCTMemoryMetric`, `XCTCPUMetric`, and `XCTOSSignpostMetric`.

**Why:** PERF-07 requires regression test infrastructure. Without baselines stored in `.xcresult`, future optimizations can silently regress. XCTest's `measure(metrics:)` API stores baselines in the test plan and fails when a metric exceeds its threshold by more than the allowed standard deviation.

**APIs (all built-in to XCTest, iOS 13.4+):**

```swift
import XCTest

final class LaunchPerformanceTests: XCTestCase {
    // Measures wall-clock app launch time (warm launches, 5 iterations)
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

final class ScrollPerformanceTests: XCTestCase {
    // Measures CPU and memory during scrolling through 500 sessions
    func testSessionListScrollPerformance() throws {
        let app = XCUIApplication()
        app.launch()
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            // scroll sessions list
        }
    }
}
```

**Signpost-based custom instrumentation (for network and render phases):**

```swift
import os.signpost

// In APIClient
let signposter = OSSignposter(subsystem: "com.ils.app", category: "Network")
let state = signposter.beginInterval("fetchSessions")
defer { signposter.endInterval("fetchSessions", state) }
```

These `os_signpost` intervals appear in Instruments Time Profiler and can be targeted by `XCTOSSignpostMetric` for regression tests.

**Confidence:** HIGH for XCTest metrics (stable since Xcode 11); MEDIUM for `OSSignposter` — available iOS 15+, which is within the app's iOS 17+ target.

**Implementation note:** Baselines are stored per-device inside `.xcresult` and should be committed. Running `xcodebuild test` on CI checks against stored baselines. The UDID constraint (`50523130-57AA-48B0-ABD0-4D59CE455F14`) means baselines must be recorded on that specific simulator.

---

### 6. MetricKit for Production Field Metrics — No New Dependencies

**What:** Conform `AppDelegate` (or use a dedicated `PerformanceMonitor` service) to `MXMetricManagerSubscriber` to receive daily metric payloads in production.

**Why:** XCTest measures lab performance. MetricKit measures real-user performance. Without MetricKit, you cannot validate that lab baselines match field conditions. This is the feedback loop for PERF-01 through PERF-06 after App Store release.

**APIs:**

```swift
import MetricKit

// In AppState or a lightweight service at app launch
final class PerformanceMonitor: NSObject, MXMetricManagerSubscriber {
    static let shared = PerformanceMonitor()

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            // payload.applicationLaunchMetrics — MXAppLaunchMetric
            // payload.memoryMetrics — MXMemoryMetric
            // payload.cpuMetrics — MXCPUMetric
            // payload.applicationExitMetrics — MXAppExitMetric
            AppLogger.shared.info(
                "MetricKit payload: \(payload.jsonRepresentation())",
                category: "performance"
            )
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // Crash diagnostics, hangs, CPU exceptions
    }
}
```

**Delivery cadence:** Daily (system-aggregated from previous 24h). Payloads cannot be triggered on-demand in production — only in Xcode debug builds via the Metrics section in the Debug Navigator.

**Confidence:** HIGH — available iOS 13+; stable API.

---

### 7. Rendering Optimization — Zero New Dependencies, Code Pattern Only

**What:** Apply `equatable()` modifier to stable message card views in `ChatMessageList`, eliminate `Array(messages.enumerated())` anti-pattern, and add `id:` stability to `ForEach`.

**Why:** The current `ChatMessageList` uses `ForEach(Array(messages.enumerated()), id: \.element.id)` — the `Array(messages.enumerated())` wrapper defeats SwiftUI's diffing because it creates a new array on every render. With 200+ messages, this causes unnecessary body recomputes.

**Recommended pattern:**

```swift
// Current (causes unnecessary re-evaluation):
ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in

// Recommended (stable identity, SwiftUI can diff correctly):
ForEach(messages, id: \.id) { message in
    MessageView(message: message)
        .equatable() // skip body if message hasn't changed
}
```

For `MessageView` to benefit from `.equatable()`, `ChatMessage` must conform to `Equatable`. Check `ILSShared/Models/` — if not already conforming, add it.

**List vs LazyVStack for sessions:** For the sessions list (500+ items), `List` backed by `UICollectionView` provides smoother scrolling than `LazyVStack` at high scroll velocity. However, switching from `LazyVStack` to `List` would require redesigning the row appearance (List imposes its own insets and separators). Given the existing design investment, keep `LazyVStack` but ensure `ChatMessage` is `Equatable` and rows use `.equatable()`. If scroll jank persists after optimization, consider `List` for the sessions screen only.

**Confidence:** HIGH for `Equatable` conformance + `.equatable()` modifier; MEDIUM for List vs LazyVStack recommendation (depends on measured jank that hasn't been profiled yet).

---

### 8. `@ScaledMetric` Extension — Zero New Dependencies

**What:** Audit all hardcoded `CGFloat` spacing and icon sizes in high-frequency views and replace with `@ScaledMetric`.

**Why:** The codebase already uses `@ScaledMetric` in `ChatMessageList` (3 properties) but the audit remediation from v1.0 eliminated `size: 10` hardcoded fonts. The performance angle is different: `@ScaledMetric` values are computed once per Dynamic Type change (not per render), whereas computed `CGFloat` expressions in view bodies compute on every render. This is a micro-optimization but adds up in `LazyVStack` rows.

**Scope:** Primarily `SidebarSessionRow`, `AssistantCard`, `UserMessageCard` — these render per-row in the large list.

**Confidence:** HIGH — `@ScaledMetric` is iOS 14+, fully stable.

---

## What NOT to Add

| Rejected Addition | Reason |
|-------------------|--------|
| Nuke / Kingfisher image caching | ILS has no image-heavy screens — system URLSession cache is sufficient |
| Combine-based reactive pipeline | Already migrated to `@Observable`; adding Combine would create two competing reactivity systems |
| New caching layer / Redis client | GRDB + NSCache already provides two-tier caching (in-memory + persistent) |
| Pagination library (Infinite Scroll, etc.) | `SessionsViewModel` already implements manual pagination with `currentPage`/`pageSize`/`hasMore` |
| Background fetch framework | PollingManager + SyncCoordinator covers this; background fetch adds complexity without benefit for a locally-connected app |
| Any third-party analytics SDK | MetricKit provides production metrics without a third-party dependency or data sharing |
| Swift Charts for performance dashboards | Out of scope — SystemMonitorView already has metrics display |

---

## Integration Points with Existing `@Observable` Pattern

All performance additions integrate cleanly with the existing `@Observable @MainActor` pattern:

| Addition | Integration |
|----------|-------------|
| Launch delay removal | `ILSAppApp.swift` — single call site, no VM changes |
| Request deduplication | `APIClient` (already actor) — transparent to callers |
| Low Power Mode | New `@Observable` `BatteryMonitor` service, passed via `@Environment` |
| Memory pressure | `APIClient` + `CacheService` — internal to services, no VM changes |
| XCTest baselines | New test target — zero production code changes |
| MetricKit | New `PerformanceMonitor` singleton, initialized in `AppState.init()` |
| Equatable views | `ILSShared` model conformance + `.equatable()` modifier in views |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Launch time | Remove artificial delay + content-driven dismiss | Add splash screen animation | Animations add perceived time, not remove it |
| Request deduplication | Actor `[String: Task]` dictionary | Combine `.share()` | App uses zero Combine; introducing it for one pattern adds cognitive overhead |
| Memory pressure | `UIApplication.didReceiveMemoryWarningNotification` | `os_proc_available_memory()` polling | Notification is push-based (efficient); polling wastes CPU |
| Performance regression | `XCTest measure(metrics:)` with baselines | Third-party Pulse / DataDog | No external dependency needed; XCTest baselines commit with the codebase |
| Production monitoring | MetricKit | Custom timing infrastructure | MetricKit is free, private, OS-managed; custom infra requires a backend |
| Scroll performance | `.equatable()` on existing LazyVStack | Migrate to List | List redesign is scope creep; equatable fix is surgical |

---

## Sources

- [App Launch Time Optimization — SwiftLee](https://www.avanderlee.com/optimization/launch-time-performance-optimization/) — MEDIUM confidence
- [SwiftUI Scroll Performance: The 120fps Challenge — Jacob's Tech Tavern](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps) — MEDIUM confidence (practical benchmarks)
- [Monitoring App Performance with MetricKit — Swift with Majid (Dec 2025)](https://swiftwithmajid.com/2025/12/09/monitoring-app-performance-with-metrickit/) — MEDIUM confidence
- [XCTMemoryMetric — Apple Developer Documentation](https://developer.apple.com/documentation/xctest/xctmemorymetric) — HIGH confidence (official)
- [XCTClockMetric — Apple Developer Documentation](https://developer.apple.com/documentation/xctest/xctclockmetric) — HIGH confidence (official)
- [isLowPowerModeEnabled — Apple Developer Documentation](https://developer.apple.com/documentation/foundation/processinfo/islowpowermodeenabled) — HIGH confidence (official)
- [Understanding and Improving SwiftUI Performance — Apple Developer Documentation](https://developer.apple.com/documentation/Xcode/understanding-and-improving-swiftui-performance) — HIGH confidence (official)
- [Optimize SwiftUI Performance with Instruments — WWDC25 Session 306](https://developer.apple.com/videos/play/wwdc2025/306/) — HIGH confidence (official, 2025)
- [Analyze Hangs with Instruments — WWDC23 Session 10248](https://developer.apple.com/videos/play/wwdc2023/10248/) — HIGH confidence (official)
- [Exploring SwiftUI Equatable — Optimizing Views — Swift with Majid](https://swiftwithmajid.com/2020/01/22/optimizing-views-in-swiftui-using-equatableview/) — MEDIUM confidence
- [Performance Testing with XCTest — AugmentedCode](https://augmentedcode.io/2019/12/22/performance-testing-using-xctmetric/) — MEDIUM confidence
- [Tips and Considerations for Lazy Containers — FatBobman](https://fatbobman.com/en/posts/tips-and-considerations-for-using-lazy-containers-in-swiftui/) — MEDIUM confidence
- [Energy Efficiency Guide — Defer Networking — Apple](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/DeferNetworking.html) — HIGH confidence (official)
- [Analyzing Battery Use — Apple Developer Documentation](https://developer.apple.com/documentation/xcode/analyzing-your-app-s-battery-use) — HIGH confidence (official)
- Codebase analysis: `ILSAppApp.swift`, `APIClient.swift`, `CacheService.swift`, `ChatMessageList.swift`, `SessionsViewModel.swift`, `PollingManager.swift` — HIGH confidence (direct inspection)
