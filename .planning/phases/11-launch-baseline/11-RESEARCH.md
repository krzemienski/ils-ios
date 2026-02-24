# Phase 11: Launch & Baseline - Research

**Researched:** 2026-02-22
**Domain:** iOS App Launch Performance — SwiftUI initialization sequencing, Instruments profiling, XCTest performance baselines
**Confidence:** HIGH (code directly inspected; patterns verified against official docs and authoritative sources)

---

## Summary

The problem is fully diagnosed from source inspection. `ILSAppApp.swift` contains a hardcoded `Task.sleep(for: .seconds(2.2))` that unconditionally delays launch screen dismissal. This sleep runs AFTER `Tips.configure()` and `CacheService.shared.initialize()`, both of which are non-critical to displaying the first frame. The fix has two parts: (1) remove the artificial sleep and wire dismissal to content readiness, and (2) move TipKit + CacheService initialization off the launch path into a deferred background Task that runs after the first frame is visible.

Apple's official guidance (WWDC 2019 Session 423) targets first-frame rendering within 400ms. The current 2.2s+ artificial delay puts the app well outside best-practices territory. The 1-second success criterion in LAUNCH-01 is achievable without any architectural changes — only the initialization order needs correction.

The Instruments baseline requirement (LAUNCH-02) calls for a "before" capture using the App Launch Instruments template, then an "after" capture post-fix. `XCTApplicationLaunchMetric` / `XCTOSSignpostMetric.applicationLaunch` in a UI test target provides automated regression detection going forward. The `ILSAppUITests` target already exists and has a proper scheme configuration, so no project.yml changes are needed to add the performance test.

**Primary recommendation:** Remove the `Task.sleep(2.2)`, restructure `.task {}` in `ILSAppApp` to dismiss the launch screen immediately after the first frame (via `showLaunchScreen = false` in a `.task {}` on `SidebarRootView.onAppear`), then move TipKit + CacheService init into a `Task { ... }` block that fires after dismissal. Add `testLaunchPerformance()` to `ILSAppUITests` and capture Instruments trace before and after.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LAUNCH-01 | App cold-starts in under 1 second (remove 2.2s artificial delay, content-driven launch dismiss) | Root cause identified: `Task.sleep(2.2)` in `ILSAppApp.swift:52`. Removal + content-driven pattern brings dismiss time to ~150-300ms (GRDB init + animation frame). |
| LAUNCH-02 | Non-critical initialization (TipKit, CacheService) deferred to background after UI visible | Both `Tips.configure()` and `CacheService.shared.initialize()` run before the sleep. Moving them to a detached Task after `showLaunchScreen = false` satisfies this requirement. CacheService is an actor so it's thread-safe for background init. |
</phase_requirements>

---

## Standard Stack

### Core (No new dependencies — Apple SDK only)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| XCTest (XCTApplicationLaunchMetric) | Built-in (iOS 13+) | Automated launch time regression testing | Native Apple API; integrates with Xcode performance baselines; runs in CI |
| XCTOSSignpostMetric.applicationLaunch | Built-in (iOS 13+) | Alternative launch metric signpost | Same as above; measures from launch trigger to first frame |
| Instruments (App Launch template) | Built-in (Xcode 16) | Manual profiling and before/after baseline capture | Only tool that captures cold-start wall-clock time with call tree detail |
| TipKit (Tips.configure) | iOS 17+ | Already in use; needs deferral, not replacement | Already integrated; no change to API |
| GRDB (CacheService/LocalDatabase) | 7.0.0 | Already in use; already async-safe actor | Actor isolation means background init is safe |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| xcrun xctrace | Built-in macOS | Command-line profiling for CI/scripted baselines | When capturing Instruments data from scripts |
| Instruments "App Launch" template | Xcode 16 | Visual cold-start profiling | Required for LAUNCH-02 Instruments baseline report |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| XCTApplicationLaunchMetric | MetricKit MXAppLaunchMetric | MetricKit is field/production metrics; XCTest is CI-friendly. Phase 17 handles MetricKit (TEST-04). Do not add MetricKit here. |
| Manual Instruments capture | xcrun xctrace automation | Automation is harder to produce human-readable report; manual Instruments export to PDF or screenshot is sufficient for baseline doc |

---

## Architecture Patterns

### Current (Broken) Initialization Sequence

```
ILSAppApp.body.task {
    Tips.configure(...)            // BLOCKS: Hits disk for TipKit datastore
    await CacheService.initialize() // BLOCKS: Opens GRDB, runs migrations
    try? await Task.sleep(2.2)    // ARTIFICIAL DELAY — this must go
    showLaunchScreen = false       // Dismiss only after all the above
}
```

**Problem:** All three steps run before the user sees the main UI. The sleep is the dominant cost, but even without it, putting GRDB init on the launch path adds ~50-150ms unnecessarily.

### Pattern 1: Content-Driven Launch Dismissal (Target Architecture)

**What:** Dismiss the launch screen as soon as `SidebarRootView` renders its first frame, then defer non-critical work to a background Task.

**When to use:** Any service that is not needed to display the initial screen content.

```swift
// ILSAppApp.swift — corrected .task block
var body: some Scene {
    WindowGroup {
        ZStack {
            SidebarRootView()
                .environment(appState)
                .environment(themeManager)
                .environment(\.theme, themeManager.currentSnapshot)
                .preferredColorScheme(computedColorScheme)
                .dynamicTypeSize(DynamicTypeSize.xSmall ... DynamicTypeSize.accessibility3)
                .onOpenURL { url in appState.handleURL(url) }
                // Dismiss launch screen on first frame of content
                .task {
                    // NO SLEEP. Dismiss immediately — content is ready to render.
                    withAnimation(.easeOut(duration: 0.4)) {
                        showLaunchScreen = false
                    }
                    // Non-critical init deferred to background AFTER dismissal
                    Task.detached(priority: .background) {
                        try? Tips.configure([
                            .displayFrequency(.daily),
                            .datastoreLocation(.applicationDefault)
                        ])
                        await CacheService.shared.initialize()
                    }
                }

            if showLaunchScreen {
                LaunchScreenView()
                    .environment(\.theme, themeManager.currentSnapshot)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhase(newPhase)
        }
    }
}
```

**Why `.task` on SidebarRootView (not on the ZStack):** The `.task` modifier fires when the view enters the view hierarchy. Attaching it to `SidebarRootView` means it fires after `SidebarRootView` is committed to render — not before the first frame. The outer ZStack `.task` also works but is semantically cleaner on the content view.

**Key constraint on Tips.configure():** `Tips.configure()` must be called before any `Tip` struct is queried. It does NOT need to complete before the first frame. Since tips are only displayed after user interaction (not on launch), deferring is safe. `Tips.configure()` is idempotent — multiple calls are no-ops after the first.

**Key constraint on CacheService:** `CacheService` is declared as a Swift `actor`, making it thread-safe. `initialize()` opens the GRDB `DatabasePool` and runs migrations. None of this is needed until a ViewModel requests cached data. ViewModels load data after they appear, well after first frame.

### Pattern 2: XCTApplicationLaunchMetric Performance Test

**What:** Automated UI test that measures cold launch time and establishes an XCTest performance baseline. Runs in `ILSAppUITests` target (already exists and configured in project.yml).

**When to use:** For CI regression detection after any change that could affect launch time.

```swift
// ILSAppUITests/LaunchPerformanceTests.swift — new file in existing target
import XCTest

final class LaunchPerformanceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Measures cold launch time using XCTApplicationLaunchMetric.
    /// Run 5 iterations; Xcode establishes a baseline on first run.
    /// Subsequent runs fail if launch degrades > 10% from baseline.
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    /// Alternative using OS signpost metric (iOS 14+).
    /// Measures from process launch to first frame displayed.
    func testLaunchPerformanceSignpost() throws {
        if #available(iOS 14.0, *) {
            measure(metrics: [XCTOSSignpostMetric.applicationLaunch]) {
                XCUIApplication().launch()
            }
        }
    }
}
```

**XCTest baseline mechanics:**
1. First run: Xcode runs 5 iterations, shows results but no pass/fail
2. Developer clicks "Set Baseline" in Xcode test results
3. Subsequent runs: fail if result exceeds baseline + 10% standard deviation
4. Baselines are stored in `.xcbaseline` files committed to the repo

**What XCTApplicationLaunchMetric measures:** From the moment the system launches the process to the moment the app's first frame is displayed (equivalent to `UIApplication.shared.delegate?.applicationDidBecomeActive` + first commit to CALayer). The metric does NOT include the system launch animation itself.

### Pattern 3: Instruments Baseline Report

**What:** A before-and-after snapshot using the Instruments "App Launch" template. This is a manual artifact committed as the LAUNCH-02 evidence.

**Instruments "App Launch" template captures:**
- Time to first frame (ms)
- App launch phases: dyld, main, UIKit/SwiftUI init, first frame
- CPU usage during launch
- Memory allocations at launch

**Workflow for before capture (run BEFORE code changes):**
```bash
# 1. Install app on dedicated simulator
xcrun simctl install 50523130-57AA-48B0-ABD0-4D59CE455F14 \
    ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app

# 2. Capture with xctrace (App Launch template, 3 iterations)
xcrun xctrace record \
    --device 50523130-57AA-48B0-ABD0-4D59CE455F14 \
    --template "App Launch" \
    --launch com.ils.app \
    --time-limit 10s \
    --output before-launch.trace

# 3. Open trace in Instruments for screenshot / export
open before-launch.trace
```

**After capture:** Run same command post-fix, save as `after-launch.trace`. Screenshot both in Instruments showing time-to-first-frame and include in phase evidence.

**Alternative (no xctrace):** Launch Instruments from Xcode > Product > Profile, select "App Launch" template, run the app on the dedicated simulator, stop after first frame, screenshot the summary row showing "Launch Time: X ms".

### Anti-Patterns to Avoid

- **Never block the main thread during launch:** Any synchronous file I/O, database open, or network call in `AppDelegate`/`App.init()` or `.task` before frame 1 directly adds to cold start time.
- **Never use `Task.sleep` as a branding delay:** Launch screens must dismiss content-driven, not timer-driven.
- **Never put TipKit configure in App.init():** `init()` runs before SwiftUI processes the body; if configure() hits disk, it adds to pre-frame time.
- **Do not use `measureOptions: .startupTime` without checking iOS version:** `XCTMeasureOptions` with `.startupTime` is iOS 16+; use the simpler `measure(metrics:)` form shown above for iOS 17+ minimum deployment.
- **Do not run performance tests on Simulator for official baselines:** Simulator launch times do not correlate with real device times. For the LAUNCH-02 baseline report, the dedicated simulator is acceptable for tracking relative improvement, but note this in the report.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Launch time measurement | Custom Date-based timer in AppDelegate | XCTApplicationLaunchMetric | Handles multi-iteration averaging, standard deviation, baseline storage automatically |
| Background initialization queue | Custom OperationQueue or GCD wrapper | `Task.detached(priority: .background)` | Swift Concurrency integrates with actors cleanly; CacheService is already an actor |
| Cold-start detection | Custom "is first launch" flag | Instruments + XCTest metrics | Tools already solve this; custom solutions introduce measurement error |

**Key insight:** The entire fix is a code deletion + reordering exercise. Zero new infrastructure is required. The GRDB actor handles thread safety; TipKit handles its own concurrency. The planner should not introduce any new service layers.

---

## Common Pitfalls

### Pitfall 1: Dismissing Launch Screen Before SidebarRootView Renders

**What goes wrong:** If `showLaunchScreen = false` fires in the WindowGroup `.task` before `SidebarRootView` has committed its first layout pass, the user sees a flash of unrendered UI.

**Why it happens:** WindowGroup `.task` and SidebarRootView's first layout can race. The WindowGroup `.task` fires when the scene is active, not necessarily when the content view has rendered.

**How to avoid:** Attach the `.task` that sets `showLaunchScreen = false` directly to `SidebarRootView` (or use `.onAppear` + `Task { ... }`). This guarantees it fires after the view enters the hierarchy and begins layout.

**Warning signs:** White flash or blank frame between launch screen fade-out and content appearing.

### Pitfall 2: Tips.configure() Called After Tip Is Queried

**What goes wrong:** If any `Tip` struct's `rules` or `.parameter` getters are evaluated before `Tips.configure()` completes, TipKit logs warnings and tips may not display correctly.

**Why it happens:** `SidebarRootView.task` runs concurrently with `Task.detached { Tips.configure() }`. If TipKit-using views appear and query tips before configure completes, there's a race.

**How to avoid:** `HomeView` and `SettingsConnectionSection` use `TipView` — these are shown after the launch screen is already gone and after user navigation, not on first frame. The race window is negligible. If needed, use `Tips.configure()` synchronously in a non-blocking context before the first TipView appears (e.g., in SidebarRootView's `.task` but after a yield: `await Task.yield()`).

**Warning signs:** Console output: `Tips.configure() has not been called` or tips never displaying.

### Pitfall 3: XCTest Performance Baseline Not Committed

**What goes wrong:** Performance test runs but no baseline is set. Tests always pass (no comparison reference) and provide no regression protection.

**Why it happens:** After first run, developer must manually click "Set Baseline" in Xcode test navigator. Easy to forget.

**How to avoid:** After first successful run, explicitly set baseline in Xcode and commit the `.xcbaseline` file to the repo. The baseline file is at `ILSApp/ILSApp.xcodeproj/xcshareddata/xcbaselines/`.

**Warning signs:** Test results show "No baseline" in the Xcode test report.

### Pitfall 4: CacheService Initialization Failure Breaks Cold-Start Silently

**What goes wrong:** If GRDB fails to open (e.g., disk full, permissions error), `CacheService.initialize()` currently logs and returns silently. In the deferred pattern this is fine — the app still works, just without caching.

**Why it happens:** `LocalDatabase.initialize()` uses `try` internally but `CacheService.initialize()` wraps it in `do/catch` with logging only.

**How to avoid:** No change needed — the error handling is already correct for this non-critical path.

---

## Code Examples

### Before: The Problem (ILSAppApp.swift current state)

```swift
// Source: /ILSApp/ILSApp/ILSAppApp.swift lines 42-55
.task {
    // Configure TipKit onboarding system
    try? Tips.configure([
        .displayFrequency(.daily),
        .datastoreLocation(.applicationDefault)
    ])

    // Initialize local cache database
    await CacheService.shared.initialize()

    try? await Task.sleep(for: .seconds(2.2))  // <- THE PROBLEM
    withAnimation(.easeOut(duration: 0.5)) {
        showLaunchScreen = false
    }
}
```

### After: The Fix (corrected ILSAppApp.swift)

```swift
// Attach to SidebarRootView — fires after content is in hierarchy
SidebarRootView()
    // ... existing environment/modifier chain ...
    .task {
        // Dismiss launch screen immediately — content is ready to render.
        // No sleep. No blocking init.
        withAnimation(.easeOut(duration: 0.4)) {
            showLaunchScreen = false
        }
        // Non-critical services initialize after first frame is visible.
        Task.detached(priority: .background) {
            try? Tips.configure([
                .displayFrequency(.daily),
                .datastoreLocation(.applicationDefault)
            ])
            await CacheService.shared.initialize()
        }
    }
```

### Performance Test (new file in ILSAppUITests)

```swift
// Source pattern: XCTest documentation + SwiftAnthropic example in checkouts
import XCTest

final class LaunchPerformanceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testLaunchPerformance() throws {
        // Runs 5 iterations; set baseline in Xcode after first run.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `instruments` CLI command | `xcrun xctrace record` | macOS 10.15 | Modern tool; old `instruments` binary deprecated |
| `XCTOSSignpostMetric.applicationLaunch` | `XCTApplicationLaunchMetric()` | Xcode 12/iOS 14 | Both still valid; XCTApplicationLaunchMetric is the simpler, preferred form |
| Fixed-delay splash screens | Content-driven dismissal | WWDC 2019 guidance | Apple has considered timer-based splash screens an anti-pattern since 2019 |
| `DispatchQueue.global()` for background init | `Task.detached(priority: .background)` | Swift 5.5+ | Swift Concurrency integrates with actors; GCD works but is less composable |

**Deprecated/outdated:**
- `Task.sleep(2.2)` as a launch screen delay: Anti-pattern. Apple guidelines prohibit artificial delays that extend launch time.
- Synchronous CacheService/TipKit init on main thread during launch: Should be background after first frame.

---

## Open Questions

1. **Does `SidebarRootView.task` race with TipView rendering?**
   - What we know: `HomeView` and `SettingsConnectionSection` use `TipView`. They are children of `SidebarRootView` and load after navigation.
   - What's unclear: Exact timing between `Task.detached { Tips.configure() }` completing and TipView rendering on a cold launch path.
   - Recommendation: Proceed with the deferred pattern. If TipKit warnings appear in testing, move `Tips.configure()` into a synchronous call before `showLaunchScreen = false` (adds ~20-40ms, still well under 1s).

2. **What is the real GRDB init time on the dedicated simulator?**
   - What we know: GRDB WAL mode + migrations + file protection setting. First-open involves PRAGMA setup.
   - What's unclear: Actual ms cost. Could be 10ms or 150ms depending on cold storage state.
   - Recommendation: The Instruments "before" trace will reveal this. If GRDB init takes > 200ms even deferred, that's a separate concern for Phase 12.

3. **Does `XCTApplicationLaunchMetric` capture the launch SCREEN animation time?**
   - What we know: The metric ends at first frame committed, which in ILS is when `SidebarRootView` renders underneath the launch screen overlay.
   - What's unclear: Whether the `.opacity` transition of the launch screen overlay extends the "launch" window as measured by the metric.
   - Recommendation: Use `showLaunchScreen = false` before animation (so SwiftUI commits the main view) and animate within the existing `withAnimation` wrapper. The XCTest metric should capture the SwiftUI frame commit, not the animation duration.

---

## Sources

### Primary (HIGH confidence)

- Direct source inspection: `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/ILSAppApp.swift` — root cause confirmed (line 52 artificial sleep)
- Direct source inspection: `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Services/CacheService.swift` — actor-based, safe for background init
- Direct source inspection: `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Services/LocalDatabase.swift` — GRDB actor with WAL mode
- Direct source inspection: `/Users/nick/Desktop/ils-ios/ILSApp/project.yml` — `ILSAppUITests` target exists with correct config; no new targets needed
- XCTApplicationLaunchMetric pattern — verified via `.build/ios/SourcePackages/checkouts/SwiftAnthropic/Examples/.../SwiftAnthropicExampleUITests.swift` (real working usage in codebase)
- [useyourloaf.com - Testing App Launch Time](https://useyourloaf.com/blog/testing-app-launch-time/) — XCTOSSignpostMetric.applicationLaunch pattern confirmed; 400ms first frame target cited
- [avanderlee.com - App Launch Time: 7 tips](https://www.avanderlee.com/optimization/launch-time-performance-optimization/) — XCTApplicationLaunchMetric with `waitUntilResponsive: true`, DYLD analysis, defer non-critical pattern

### Secondary (MEDIUM confidence)

- [holyswift.app - Animated Launch Screen in SwiftUI](https://holyswift.app/animated-launch-screen-in-swiftui/) — Content-driven dismissal pattern; state machine approach; verified matches Apple best practices
- [Hackingwithswift.com - XCTOSSignpostMetric.applicationLaunch](https://www.hackingwithswift.com/example-code/testing/how-to-benchmark-app-launch-time-using-xctossignpostmetricapplicationlaunch) — baseline creation mechanics; 5-iteration averaging
- [avanderlee.com - Detached Tasks](https://www.avanderlee.com/concurrency/detached-tasks/) — Task.detached priority and isolation behavior
- [oneclickitsolution.com - Strategies for Optimizing iOS App Launch Time](https://www.oneclickitsolution.com/centerofexcellence/ios/strategies-for-optimizing-ios-app-launch-time) — defer non-critical tasks, lazy loading, Instruments tool guidance
- [moldstud.com - Instruments Guide](https://moldstud.com/articles/p-mastering-xcodes-instruments-a-comprehensive-guide-to-performance-analysis-in-ios-apps) — xcrun xctrace template list confirmed

### Tertiary (LOW confidence — validated by cross-reference)

- WWDC 2019 Session 423 "Optimizing App Launch" — 400ms first-frame target, content-driven dismissal philosophy (cited by multiple HIGH sources; session URL: https://developer.apple.com/videos/play/wwdc2019/423/)

---

## Metadata

**Confidence breakdown:**
- Root cause diagnosis: HIGH — source code directly inspected; sleep is line 52 of ILSAppApp.swift
- Fix pattern (content-driven dismissal): HIGH — pattern verified via official Apple guidance + multiple sources
- XCTApplicationLaunchMetric usage: HIGH — working example found in codebase checkouts; API stable since iOS 13
- Instruments baseline workflow: MEDIUM — xcrun xctrace confirmed; specific "App Launch" template behavior inferred from documentation
- TipKit deferral safety: MEDIUM — no official statement that deferred configure is safe; mitigated by noting tips only display after navigation

**Research date:** 2026-02-22
**Valid until:** 2026-05-22 (stable Apple SDK APIs; 90-day horizon)
