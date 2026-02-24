# Phase 12: Service Layer Optimization - Research

**Researched:** 2026-02-23
**Domain:** Network request deduplication, NSCache cost management, and memory pressure handling in a SwiftUI iOS/macOS app
**Confidence:** HIGH (codebase directly inspected; patterns verified against Apple SDK docs and v3.0 audit outcomes)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| NET-01 | Replace SSH `.acceptAnything()` host key validator — `Services/CitadelSSHService.swift:54` | **ALREADY ADDRESSED in Phase 22 (v3.0).** NET-01 was documented as TOFU (Trust On First Use) with a 20-line rationale comment at lines 50-63 of `CitadelSSHService.swift`. Full known_hosts management was explicitly deferred. The v3.0 resolution marks this as accepted-with-documentation. **No further work required for Phase 12.** |
| NET-03 | Add network-state gate to PollingManager | **ALREADY ADDRESSED in Phase 23 (v3.0).** `PollingManager.swift` lines 19-33 and 45-49 gate on `NetworkMonitor.shared.isConnected` and observe `.networkDidBecomeAvailable` notification to resume polling. **No further work required for Phase 12.** |
| MEM-01 | Migrate HostProfilesViewModel Timer to Task — `ViewModels/HostProfilesViewModel.swift:72` | **ALREADY ADDRESSED in Phase 19 (v3.0).** `HostProfilesViewModel.swift` now uses `Task` with `Task.sleep(for:)` (lines 71-80) instead of `Timer.scheduledTimer`. Property is `@ObservationIgnored private var healthTask: Task<Void, Never>?` with proper deinit cancellation. **No further work required for Phase 12.** |
</phase_requirements>

---

## Summary

**All three original Phase 12 requirement IDs (NET-01, NET-03, MEM-01) have been resolved during the v3.0 Comprehensive Audit Remediation (Phases 18-24, completed 2026-02-23).** This fundamentally changes the scope of Phase 12.

However, the Phase 12 **Success Criteria** (from the roadmap) describe broader goals that are NOT fully satisfied by the v3.0 work:

1. **Request deduplication on rapid tab navigation** -- Partially addressed. `APIClient.swift` has TTL-based NSCache (lines 151-181) that serves cached responses on rapid navigation. The ENRG-06 comment documents this as the deduplication strategy. However, there is **no true in-flight request coalescing** -- two concurrent GET requests to the same endpoint before the first completes will both execute network requests. Only after the first completes and populates the cache will subsequent requests use the cached result.

2. **NSCache `totalCostLimit` is set and evicts on memory warning** -- NOT addressed. `APIClient.swift` sets `cache.countLimit = 100` (line 57) but **does NOT set `totalCostLimit`**. The `CacheEntryObject` stores `Any` (decoded model objects) without cost estimation. NSCache auto-evicts under system memory pressure (this is a built-in NSCache behavior), but without `totalCostLimit`, the cache has no application-level memory budget.

3. **App memory stays under 100MB during typical browsing** -- NOT measured or enforced. Phase 11 established a 273MB RSS baseline at cold start and 286MB steady state. There is no memory pressure observer or explicit cache eviction logic in the app. The 100MB target has never been validated.

**Primary recommendation:** Redefine Phase 12 around the two unmet success criteria: (A) add true in-flight request coalescing to `APIClient` so concurrent GET requests to the same path share a single network call, and (B) add `totalCostLimit` to the NSCache with cost estimation per cache entry. Defer the 100MB memory target to Phase 13 or later since it requires profiling with Instruments to determine where memory is actually spent (GRDB pool, decoded model arrays, SwiftUI view hierarchy, etc.).

---

## Current State Analysis

### What Already Works (from v3.0 audit)

| Component | Current State | Evidence |
|-----------|--------------|----------|
| `APIClient.swift` NSCache | `countLimit = 100`, per-endpoint TTL (15s-5min), decoded-value caching avoids re-parsing JSON on cache hit | Lines 15-52, 151-181 |
| `APIClient.swift` cache invalidation | POST/PUT/DELETE invalidate exact path + parent list endpoint | `invalidateCacheForMutation()` lines 290-299 |
| `APIClient.swift` retry with backoff | 3 attempts, exponential backoff (0.5s, 1s, 2s), transient-error-only | `performWithRetry()` lines 311-336 |
| `PollingManager.swift` network gate | Checks `NetworkMonitor.shared.isConnected`, observes `.networkDidBecomeAvailable` | Lines 19-33, 45-49 |
| `PollingManager.swift` background suspend | `handleScenePhase(.background)` stops both health and retry polling | Lines 135-145 |
| `MetricsWebSocketClient.swift` reconnect cap | `maxReconnectAttempts = 10`, exponential backoff (1s-30s) | Lines 29-31, 205-222 |
| `MetricsWebSocketClient.swift` disconnect/cleanup | `disconnect()` resets all state (failure count, reconnect attempts, fallback flag) | Lines 74-90 |
| `HostProfilesViewModel.swift` Task-based polling | `Task.sleep(for:)` loop with `[weak self]` and cancellation check | Lines 71-80 |
| `CitadelSSHService.swift` NET-01 | TOFU documentation (20-line comment, lines 50-63) | Phase 22 resolution |
| `DashboardViewModel.swift` parallel loading | `async let` for stats + recent activity | Lines 58-64 |
| `CacheService.swift` TTL cleanup | `cleanupExpired(olderThan:)` on init, 24hr TTL for reference data, 1hr for sessions | Lines 11-12, 22-31 |
| `LocalDatabase.swift` GRDB WAL | Write-ahead logging enabled for concurrent access | Line 259 |

### What Is Missing

| Gap | Impact | File(s) |
|-----|--------|---------|
| **No in-flight request coalescing** | Two concurrent GET requests to `/sessions` both hit the network; only after the first completes does the cache prevent duplicates | `APIClient.swift` |
| **No `totalCostLimit` on NSCache** | Cache bounded only by count (100 entries), not by memory; large decoded arrays (22K sessions, 3K skills) counted as 1 entry each | `APIClient.swift` line 57 |
| **No `CacheEntryObject` cost estimation** | NSCache cost-based eviction requires each entry to report its cost; currently `CacheEntryObject` reports no cost | `APIClient.swift` lines 26-38 |
| **No memory pressure observer** | App has no `UIApplication.didReceiveMemoryWarningNotification` handler to proactively evict caches | Missing entirely |
| **No cache size metrics** | No logging/instrumentation of cache hit rate, entry count, or estimated memory usage | `APIClient.swift` |

---

## Standard Stack

### Core (No new dependencies -- Apple SDK only)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `NSCache` | Foundation (built-in) | Already in use; needs `totalCostLimit` and cost reporting per entry | Apple's recommended in-memory cache; auto-evicts under system memory pressure |
| Swift `actor` isolation | Swift 5.10+ | `APIClient` is already an actor; in-flight task registry is naturally thread-safe | Actor isolation eliminates concurrency bugs in the deduplication dictionary |
| `NotificationCenter` | Foundation (built-in) | Memory pressure observer via `UIApplication.didReceiveMemoryWarningNotification` | Standard iOS pattern; no overhead when not firing |
| `MemoryLayout.stride` | Swift stdlib | Approximate cost estimation for cached decoded values | Zero-overhead compile-time operation for primitive sizes |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSCache + cost estimation | Custom `Dictionary` with manual eviction | Loses automatic system memory pressure eviction; more code to maintain |
| In-flight `Task` dictionary | Combine publisher sharing (`.share()`) | Already migrated away from Combine; adds framework dependency for one use case |
| `didReceiveMemoryWarningNotification` | MetricKit `MXMemoryMetric` | MetricKit is for production aggregated data (daily payloads); not suitable for real-time reactive eviction |

---

## Architecture Patterns

### Pattern 1: In-Flight Request Coalescing via Actor Task Dictionary

**What:** When a GET request arrives for a path that already has an in-flight network request, return the existing `Task`'s result instead of starting a new request.

**When to use:** On GET requests only. Never on POST/PUT/DELETE (mutations must execute independently).

**Implementation location:** Inside `APIClient.get<T>()`, after the cache check but before the network call.

**Example:**
```swift
// Inside APIClient actor
private var inFlightGETs: [String: Task<Any, Error>] = [:]

func get<T: Decodable>(_ path: String, cacheTTL: TimeInterval? = nil) async throws -> T {
    let cacheKey = path as NSString
    let effectiveTTL = cacheTTL ?? ttl(for: path)

    // 1. Check cache first (existing behavior)
    if let entry = cache.object(forKey: cacheKey),
       entry.isValid(ttl: effectiveTTL),
       let cached = entry.value as? T {
        return cached
    }

    // 2. Coalesce with in-flight request if one exists
    if let existingTask = inFlightGETs[path] {
        let result = try await existingTask.value
        if let typed = result as? T { return typed }
        // Type mismatch means different callsite; fall through to new request
    }

    // 3. Create new request and register it
    let task = Task<Any, Error> {
        defer { inFlightGETs[path] = nil }
        // ... existing network + decode logic ...
        let decoded: T = try decoder.decode(T.self, from: data)
        cache.setObject(CacheEntryObject(value: decoded, timestamp: Date()), forKey: cacheKey)
        return decoded as Any
    }
    inFlightGETs[path] = task

    let result = try await task.value
    guard let typed = result as? T else {
        throw APIError.decodingError(DecodingError.typeMismatch(T.self, ...))
    }
    return typed
}
```

**Key constraints:**
- The dictionary key is the path string (not including baseURL -- paths are already unique within the actor)
- `defer { inFlightGETs[path] = nil }` ensures cleanup on both success and failure
- POST/PUT/DELETE methods MUST NOT use this dictionary
- SSEClient is completely separate from APIClient -- no risk of capturing streaming requests

**Source:** Standard actor-based request coalescing pattern. Apple's `URLSession` does not deduplicate at the transport layer for different `URLRequest` instances even to the same URL.

### Pattern 2: NSCache Cost Estimation

**What:** Set `totalCostLimit` on the NSCache and report approximate memory cost per cached entry.

**When to use:** When cache entries vary dramatically in size (a cached `StatsResponse` is ~500 bytes, but a `PaginatedResponse<ChatSession>` with 50 sessions is ~50KB).

**Example:**
```swift
// In APIClient.init()
cache.totalCostLimit = 10 * 1024 * 1024  // 10MB ceiling

// When storing:
let estimatedCost = MemoryLayout<T>.stride * max(1, estimatedCount)
cache.setObject(entry, forKey: cacheKey, cost: estimatedCost)
```

**Cost estimation strategy:**
- For arrays (`[ChatSession]`, `[Skill]`, etc.): `MemoryLayout<Element>.stride * array.count`
- For single objects: `MemoryLayout<T>.stride`
- This is an approximation -- String heap allocations are not captured. But NSCache uses cost as a relative priority, not an exact byte count. Relative correctness matters more than absolute accuracy.

**Why 10MB:** The 100-entry `countLimit` already bounds the number of entries. At 10MB `totalCostLimit`, even if every entry were a 50-session page (~50KB), the cache would hold ~200 pages before cost-based eviction. In practice, most entries are small (stats, config, single-entity responses), so the 100-entry limit will trigger before the 10MB limit for most workloads. The `totalCostLimit` acts as a safety valve for the worst case (many large paginated responses cached simultaneously).

### Pattern 3: Memory Pressure Observer

**What:** Register for `UIApplication.didReceiveMemoryWarningNotification` (iOS) and evict volatile caches proactively.

**When to use:** When the system is under memory pressure and the app should shed non-critical data.

**Example:**
```swift
// In AppState or a dedicated MemoryPressureMonitor
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { _ in
    Task {
        // APIClient NSCache auto-evicts under pressure (built-in NSCache behavior)
        // Explicitly clear GRDB persistent cache for aggressive memory recovery
        await CacheService.shared.cleanupExpired()
        AppLogger.shared.warning("Memory warning: caches cleaned", category: "memory")
    }
}
```

**Key insight:** NSCache already auto-evicts under system memory pressure -- this is a built-in Foundation behavior. The explicit observer is primarily for:
1. Logging that pressure occurred (diagnostics)
2. Clearing the GRDB persistent cache (which NSCache does NOT touch)
3. Any future in-memory data structures that are not NSCache-backed

### Anti-Patterns to Avoid

- **Do NOT replace NSCache with a custom Dictionary + manual eviction.** NSCache has kernel-level integration for memory pressure that custom code cannot replicate.
- **Do NOT deduplicate POST/PUT/DELETE requests.** Mutations must execute independently. The `invalidateCacheForMutation()` path must remain untouched.
- **Do NOT merge SSEClient's URLSession with APIClient.** SSEClient manages a long-lived streaming connection with different timeout semantics. Sharing a session configuration would break streaming.
- **Do NOT add `Equatable` conformance to cache entries for comparison.** NSCache stores entries by key identity, not value equality. Adding Equatable to model types for cache purposes adds maintenance burden with no benefit.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Memory pressure detection | Custom RSS polling via `mach_task_info` | `UIApplication.didReceiveMemoryWarningNotification` | Apple's notification fires at the right threshold and is the only signal that prevents OOM jetsam |
| Request deduplication | Combine `.share()` publisher chain | Actor-internal `Task` dictionary | APIClient is already an actor; Combine adds framework dependency for one pattern |
| Cache cost estimation | Precise `malloc_size()` per allocation | `MemoryLayout<T>.stride * count` approximation | NSCache uses cost as relative priority, not absolute bytes; precision is wasted effort |
| Network reachability | Custom `NWPathMonitor` wrapper | `NetworkMonitor.shared.isConnected` (already exists) | v3.0 already built this in Phase 23 |

---

## Common Pitfalls

### Pitfall 1: In-Flight Task Type Erasure

**What goes wrong:** The in-flight dictionary stores `Task<Any, Error>` because different callsites may decode different types from the same path. If a generic `Task<T, Error>` is stored, the dictionary type varies per callsite.

**Why it happens:** Swift generics are resolved at compile time; the dictionary must have a single value type.

**How to avoid:** Use `Task<Any, Error>` and cast the result back. The cast is safe because the same path always returns the same type (enforced by the API contract). If the cast fails (programming error, not runtime ambiguity), fall through to a new request rather than crashing.

**Warning signs:** `fatalError` or forced unwrap `as!` in the cast path -- always use `as?` with fallback.

### Pitfall 2: In-Flight Dictionary Leaking on Error

**What goes wrong:** If the network request throws an error, the in-flight dictionary entry is never removed. All subsequent requests to that path await the failed task and immediately get the cached error.

**How to avoid:** Use `defer { inFlightGETs[path] = nil }` at the start of the task body, BEFORE any throwing code. This guarantees cleanup regardless of success or failure.

### Pitfall 3: Cost Estimation Overflow for Large Arrays

**What goes wrong:** A `/sessions` response with 22K sessions multiplied by `MemoryLayout<ChatSession>.stride` could report a cost larger than `Int.max` on 32-bit platforms.

**How to avoid:** Cap the estimated cost at the `totalCostLimit` value itself. An entry whose estimated cost exceeds the limit is stored with `cost = totalCostLimit` -- this triggers immediate eviction of other entries but keeps the large entry accessible until the next insertion.

**Reality check:** The 22K sessions are paginated (50 per page), so the actual cached entry is 50 sessions, not 22K. This pitfall is theoretical but the cap is cheap to add.

### Pitfall 4: Memory Warning Observer on macOS

**What goes wrong:** `UIApplication.didReceiveMemoryWarningNotification` does not exist on macOS. The app is a cross-platform target.

**How to avoid:** Use `#if os(iOS)` guard around the notification observer. On macOS, NSCache's built-in eviction is sufficient -- macOS has more generous memory limits and virtual memory swapping that iOS does not.

### Pitfall 5: Breaking Cache Semantics with Stale In-Flight Results

**What goes wrong:** A POST mutation invalidates the cache for `/sessions`, but an in-flight GET for `/sessions` is still running. The GET completes and re-populates the cache with stale data after the invalidation.

**How to avoid:** `invalidateCacheForMutation()` should also cancel and remove the in-flight task for the affected path. This ensures the next GET after a mutation always hits the network.

---

## Code Examples

### Example 1: Adding In-Flight Coalescing to APIClient

```swift
// APIClient.swift - additions to the actor

/// In-flight GET request tasks, keyed by path.
/// Used for request coalescing: concurrent GET requests to the same path
/// share a single network call. Actor isolation makes this dictionary thread-safe.
private var inFlightGETs: [String: Task<Any, Error>] = [:]

/// Updated invalidateCacheForMutation to also cancel in-flight GETs
private func invalidateCacheForMutation(path: String) {
    cache.removeObject(forKey: path as NSString)
    // Cancel any in-flight GET that would re-populate stale data
    inFlightGETs[path]?.cancel()
    inFlightGETs.removeValue(forKey: path)

    let components = path.split(separator: "/")
    if components.count >= 1 {
        let listPath = "/\(components[0])"
        cache.removeObject(forKey: listPath as NSString)
        inFlightGETs[listPath]?.cancel()
        inFlightGETs.removeValue(forKey: listPath)
    }
}
```

### Example 2: Adding totalCostLimit and Cost Reporting

```swift
// APIClient.init() - add after countLimit
cache.totalCostLimit = 10 * 1024 * 1024  // 10MB

// Helper to estimate cache entry cost
private func estimatedCost<T>(for value: T) -> Int {
    let stride = MemoryLayout<T>.stride
    // For collections, multiply by element count
    if let array = value as? any Collection {
        return max(stride, stride * array.count)
    }
    return stride
}

// In get<T>() when storing:
let cost = estimatedCost(for: decoded)
cache.setObject(
    CacheEntryObject(value: decoded, timestamp: Date()),
    forKey: cacheKey,
    cost: cost
)
```

### Example 3: Memory Pressure Observer

```swift
// In AppState.swift or ILSAppApp.swift

#if os(iOS)
private var memoryWarningObserver: NSObjectProtocol?

func setupMemoryPressureHandling() {
    memoryWarningObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didReceiveMemoryWarningNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task {
            // NSCache auto-evicts (built-in); we additionally clean GRDB
            await CacheService.shared.cleanupExpired()
            // Optionally clear the entire in-memory API cache for aggressive recovery
            await self?.apiClient.invalidateCache()
            AppLogger.shared.warning("Memory pressure: caches evicted", category: "memory")
        }
    }
}
#endif
```

---

## State of the Art

| Old Approach (v2.0 original plan) | Current State (post-v3.0) | When Changed | Impact |
|-------------------------------------|---------------------------|--------------|--------|
| Create new `RequestDeduplicator.swift` actor | Integrate directly into `APIClient` actor (simpler, fewer files) | Research finding | One less file; actor isolation already provides thread safety |
| Create new `MemoryPressureMonitor.swift` | Use `NotificationCenter` observer in `AppState` | Research finding | Monitor class was overkill; one observer is sufficient |
| NET-01: Replace `.acceptAnything()` SSH validator | Documented as TOFU in Phase 22; accepted posture | v3.0 Phase 22 | No Phase 12 work needed |
| NET-03: Add network gate to PollingManager | Already implemented with `NetworkMonitor.shared.isConnected` | v3.0 Phase 23 | No Phase 12 work needed |
| MEM-01: Timer-to-Task migration | Already migrated in `HostProfilesViewModel` | v3.0 Phase 19 | No Phase 12 work needed |

---

## Open Questions

1. **Is the 100MB memory target realistic?**
   - What we know: Phase 11 measured 273MB RSS cold start, 286MB steady state. This includes the SwiftUI framework, GRDB database pool, and all loaded view hierarchies.
   - What's unclear: How much of that 273MB is the app's responsibility vs. shared system frameworks. `footprint` (dirty + compressed) is a better metric than RSS for iOS memory budgets. The 100MB target may need to be revised upward after profiling.
   - Recommendation: Defer the 100MB validation to Phase 13 or Phase 16 (Cross-Platform Verification). Phase 12 should add the `totalCostLimit` and memory pressure observer as defensive measures, but not claim the 100MB target is met without Instruments profiling.

2. **Should cost estimation account for String heap allocations?**
   - What we know: `MemoryLayout<ChatSession>.stride` captures the struct's inline storage but not the heap-allocated String contents (session name, model name, first prompt).
   - What's unclear: Whether the inaccuracy matters for NSCache's eviction priority.
   - Recommendation: Use stride-based estimation. NSCache cost is relative, not absolute. If session A has 50 elements and session B has 5 elements, the 10x ratio is correct even if the absolute byte count is underestimated. Perfect accuracy is not required.

3. **Should BrowserView's loadAll() be deduplicated?**
   - What we know: `BrowserView.swift` lines 67-73 call `mcpVM.loadServers()`, `skillsVM.loadSkills()`, `pluginsVM.loadPlugins()` in parallel via `async let`. Each VM calls `APIClient.get()`. If the user rapidly switches to and from the Browser tab, `.task {}` fires multiple times (once per appearance).
   - What's unclear: Whether SwiftUI's `.task {}` cancels the previous task before starting a new one (it does -- `.task` is tied to view identity and cancelled on disappear).
   - Recommendation: No additional work needed. SwiftUI `.task` cancellation + APIClient TTL-based caching already prevent redundant loads. The in-flight coalescing in APIClient provides an additional safety net for the brief window where two tasks overlap during rapid tab switching.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection: `APIClient.swift` (491 lines), `CacheService.swift` (223 lines), `LocalDatabase.swift` (558 lines), `PollingManager.swift` (146 lines), `MetricsWebSocketClient.swift` (252 lines), `NetworkMonitor.swift` (91 lines), `HostProfilesViewModel.swift` (98 lines), `CitadelSSHService.swift` (301 lines), `DashboardViewModel.swift` (128 lines), `SessionsViewModel.swift` (337 lines)
- Apple NSCache documentation: `totalCostLimit`, `countLimit`, automatic eviction under memory pressure
- Apple `UIApplication.didReceiveMemoryWarningNotification` documentation
- Project v3.0 audit findings: `.planning/REQUIREMENTS.md` (165 issues, all resolved)
- Phase 11 baseline: 273MB RSS cold start, 286MB steady state, 838ms cold launch
- v2.0 research: `.planning/research/SUMMARY.md`, `.planning/research/FEATURES.md`, `.planning/research/PITFALLS.md`

### Secondary (MEDIUM confidence)
- v2.0 research recommendation for `RequestDeduplicator.swift` and `MemoryPressureMonitor.swift` as separate actors -- superseded by simpler integrated approach based on current codebase state

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all Apple built-in APIs, no new dependencies, patterns verified in codebase
- Architecture: HIGH -- APIClient actor is the natural insertion point; code examples directly reference existing method signatures and line numbers
- Pitfalls: HIGH -- cross-referenced with v2.0 PITFALLS.md research and validated against current codebase state post-v3.0

**Research date:** 2026-02-23
**Valid until:** 2026-03-23 (stable patterns; no external dependency version sensitivity)

---

## Revised Scope Summary for Planner

Since all three original requirement IDs (NET-01, NET-03, MEM-01) are already resolved, the planner should focus Phase 12 on the **two unmet success criteria**:

**Success Criterion 1: Request deduplication on rapid tab navigation**
- Add in-flight request coalescing dictionary to `APIClient` actor
- Update `invalidateCacheForMutation()` to cancel in-flight GETs
- Files: `APIClient.swift` only
- Risk: LOW (actor isolation handles thread safety; GET-only scope prevents SSE/mutation interference)

**Success Criterion 2: NSCache bounded by cost and app handles memory pressure**
- Add `totalCostLimit = 10MB` to NSCache in `APIClient.init()`
- Add cost estimation to `cache.setObject()` calls
- Add `didReceiveMemoryWarningNotification` observer (iOS only)
- Files: `APIClient.swift`, `ILSAppApp.swift` or `AppState.swift`
- Risk: LOW (NSCache cost is additive to existing countLimit; memory observer is passive)

**Success Criterion 3: Memory under 100MB**
- DEFER to Phase 13/16. Requires Instruments profiling to determine where memory is actually spent. The NSCache and memory pressure changes in criteria 1-2 are necessary preconditions but not sufficient to validate the 100MB target. Phase 11 measured 273MB RSS which includes system framework overhead.

**Estimated scope:** 2 files modified, 0 new files, ~80 lines of net new code.
