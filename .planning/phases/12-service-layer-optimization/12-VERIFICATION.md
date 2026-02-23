---
phase: 12-service-layer-optimization
verified: 2026-02-23T15:00:19Z
status: gaps_found
score: 5/6 must-haves verified
re_verification: false
gaps:
  - truth: "App memory stays under 100MB during typical browsing of sessions, skills, and settings screens"
    status: failed
    reason: "Deferred by plan. Phase 11 baseline is 273MB RSS (includes system frameworks). No Instruments profiling done to validate app-attributable memory. The plan explicitly defers this to a future profiling phase."
    artifacts: []
    missing:
      - "Instruments profiling to measure app-attributable memory (dirty + compressed footprint)"
      - "Determination of whether 100MB target is realistic after subtracting system framework overhead"
human_verification:
  - test: "Open the app, rapidly switch between Home, Browser (Skills, MCP, Plugins tabs), and Settings 10 times in quick succession"
    expected: "Only one network request per endpoint during rapid navigation (observable via Instruments Network profiler or backend access log)"
    why_human: "In-flight coalescing behavior requires concurrent requests to the same endpoint, which depends on timing. Cannot be verified by static code analysis alone."
  - test: "Simulate a memory warning via Xcode Debug Memory Graph or xcrun simctl trigger memory warning"
    expected: "Console output shows 'Memory pressure: caches evicted' log line from AppLogger"
    why_human: "Memory warning notification requires runtime trigger that cannot be invoked from static analysis"
---

# Phase 12: Service Layer Optimization Verification Report

**Phase Goal:** Network requests are deduplicated, caches are bounded, and the app handles memory pressure gracefully
**Verified:** 2026-02-23T15:00:19Z
**Status:** gaps_found
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Concurrent GET requests to the same API path share a single network call instead of firing duplicates | VERIFIED | `APIClient.swift` lines 18-20: `inFlightGETs` dictionary; lines 184-190: coalescing check before network call; lines 192-217: `Task<Any, Error>` wrapping with `defer` cleanup |
| 2 | NSCache has both countLimit (100) and totalCostLimit (10MB) set, providing memory-budget-based eviction | VERIFIED | `APIClient.swift` line 61: `cache.countLimit = 100`; line 62: `cache.totalCostLimit = 10 * 1024 * 1024` |
| 3 | Cache entries report estimated memory cost via MemoryLayout.stride | VERIFIED | `APIClient.swift` lines 153-159: `estimatedCost(for:)` method; lines 209-213: `cache.setObject(..., cost: cost)` |
| 4 | A POST/PUT/DELETE mutation cancels any in-flight GET for the affected path, preventing stale cache repopulation | VERIFIED | `APIClient.swift` lines 337-352: `invalidateCacheForMutation()` calls `inFlightGETs[path]?.cancel()` + removes entry; also handles parent list path. Called from `post()` line 244, `put()` line 264, `delete()` line 282, `rawRequest()` line 305 |
| 5 | On iOS, a memory pressure warning triggers proactive cache eviction with diagnostic logging | VERIFIED | `ILSAppApp.swift` lines 48-62: `#if os(iOS)` guard, `didReceiveMemoryWarningNotification` observer, calls `CacheService.shared.cleanupExpired()` + `AppLogger.shared.warning()` |
| 6 | App memory stays under 100MB during typical browsing (ROADMAP Success Criterion 3) | FAILED | Deferred by plan. Phase 11 baseline is 273MB RSS. No Instruments profiling performed. Plan documents this as requiring separate profiling phase. |

**Score:** 5/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ILSApp/ILSApp/Services/APIClient.swift` | In-flight coalescing dictionary, totalCostLimit, cost estimation, mutation cancellation | VERIFIED | Contains `inFlightGETs` (line 20), `totalCostLimit` (line 62), `estimatedCost(for:)` (lines 153-159), cancellation in `invalidateCacheForMutation()` (lines 339-340, 348-349). 545 lines total, substantive implementation. |
| `ILSApp/ILSApp/ILSAppApp.swift` | Memory pressure notification observer (iOS only) | VERIFIED | Lines 48-62: `#if os(iOS)` guarded `NotificationCenter.default.addObserver` for `didReceiveMemoryWarningNotification`. Calls real `CacheService.shared.cleanupExpired()` and `AppLogger.shared.warning()`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `APIClient.get()` | `inFlightGETs` dictionary | Actor-isolated dictionary lookup before network call | WIRED | Line 185: `if let existingTask = inFlightGETs[path]`; line 217: `inFlightGETs[path] = task` |
| `APIClient.invalidateCacheForMutation()` | `inFlightGETs` dictionary | Cancel and remove in-flight task on mutation | WIRED | Lines 339-340: `inFlightGETs[path]?.cancel()` + `removeValue`; lines 348-349: same for parent list path |
| `ILSAppApp .task` | `CacheService.shared.cleanupExpired()` | NotificationCenter memory warning observer | WIRED | `ILSAppApp.swift` lines 52-58: observer registered, calls `await CacheService.shared.cleanupExpired()`. `CacheService.swift` line 213 confirms method exists. |
| `estimatedCost(for:)` | `cache.setObject` | cost parameter in cache storage | WIRED | Line 209: `let cost = self.estimatedCost(for: decoded)`; lines 210-214: `cache.setObject(..., cost: cost)` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-----------|-------------|--------|----------|
| NET-01 | 12-01-PLAN | Replace SSH `.acceptAnything()` host key validator | SATISFIED (Phase 22) | `CitadelSSHService.swift` lines 50-68: TOFU documentation comment. REQUIREMENTS.md line 386 confirms Phase 22 completion. |
| NET-03 | 12-01-PLAN | Add network-state gate to PollingManager | SATISFIED (Phase 23) | `PollingManager.swift` line 26: `.networkDidBecomeAvailable` observer; line 46: `NetworkMonitor.shared.isConnected` gate. REQUIREMENTS.md line 388 confirms Phase 23 completion. |
| MEM-01 | 12-01-PLAN | Migrate HostProfilesViewModel Timer to Task | SATISFIED (Phase 19) | `HostProfilesViewModel.swift` line 14: `healthTask: Task<Void, Never>?`; line 75: `Task.sleep(for: .seconds(interval))`. REQUIREMENTS.md line 398 confirms Phase 19 completion. |

No orphaned requirements found. All three IDs mapped to Phase 12 in ROADMAP are accounted for (resolved in earlier v3.0 phases).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | -- | -- | -- | No TODO, FIXME, placeholder, or stub patterns found in either modified file |

### Commit Verification

| Commit | Exists | Message | Files |
|--------|--------|---------|-------|
| `56d80b2` | Yes | feat(12-01): add in-flight request coalescing and memory-bounded caching to APIClient | `APIClient.swift` (+66/-13) |
| `06d9715` | Yes | feat(12-01): add iOS memory pressure observer for proactive cache eviction | `ILSAppApp.swift` (+18) |

### Human Verification Required

### 1. Request Coalescing Under Rapid Navigation

**Test:** Open the app, rapidly switch between Home, Browser (Skills, MCP, Plugins tabs), and Settings 10 times in quick succession.
**Expected:** Only one network request per endpoint during rapid navigation (observable via Instruments Network profiler or backend access log). Subsequent navigation within the TTL window should serve cached results.
**Why human:** In-flight coalescing behavior requires concurrent requests to the same endpoint, which depends on timing. Cannot be verified by static code analysis alone.

### 2. Memory Pressure Observer Activation

**Test:** While the app is running, trigger a simulated memory warning via Xcode (Debug > Simulate Memory Warning) or `xcrun simctl trigger-memory-warning 50523130-57AA-48B0-ABD0-4D59CE455F14`.
**Expected:** Console output shows "Memory pressure: caches evicted" log line from AppLogger in the memory category.
**Why human:** Memory warning notification requires runtime trigger that cannot be invoked from static analysis.

### 3. macOS Build Unaffected

**Test:** Build and run the macOS target (`ILSMacApp` scheme).
**Expected:** Build succeeds with no compilation errors. The `#if os(iOS)` guard correctly excludes the memory warning observer on macOS.
**Why human:** Cross-platform compilation correctness is best verified by actual build, though commits claim BUILD SUCCEEDED.

### Gaps Summary

One gap was identified:

**ROADMAP Success Criterion 3** ("App memory stays under 100MB during typical browsing") is explicitly deferred. The research document and plan both note that Phase 11 measured 273MB RSS at cold start, which includes system framework overhead (UIKit, SwiftUI, GRDB). The 100MB target cannot be meaningfully validated without Instruments profiling to determine app-attributable memory (dirty + compressed footprint vs. shared framework pages). The plan's position -- that the NSCache totalCostLimit and memory pressure observer are necessary preconditions but not sufficient to validate the 100MB target -- is technically sound.

This is a **documented, intentional deferral** rather than an implementation failure. The two implemented success criteria (request deduplication, memory-bounded caching with pressure handling) are fully verified. The deferred criterion requires a separate profiling phase with Instruments.

All new code is clean: no TODOs, no stubs, no placeholders, no empty implementations. Both modified files are substantive and fully wired. All three requirement IDs (NET-01, NET-03, MEM-01) are confirmed resolved in their respective earlier phases.

---

_Verified: 2026-02-23T15:00:19Z_
_Verifier: Claude (gsd-verifier)_
