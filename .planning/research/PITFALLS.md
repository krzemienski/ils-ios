# Domain Pitfalls: SwiftUI Performance Optimization

**Domain:** Adding performance optimizations to an existing, working SwiftUI iOS/macOS app
**Project:** ILS iOS/macOS — v2.0 Performance Optimization Suite
**Researched:** 2026-02-22
**Confidence:** HIGH (cross-referenced Apple docs, WWDC content, community post-mortems, and ILS codebase inspection)

---

## Context

The ILS app is functionally correct (15/15 REQs PASS, v1.0 audit complete). This milestone adds
performance — launch time, memory, network efficiency, rendering, battery. The primary risk is not
"will optimization work" but "will optimization break what already works." Every pitfall below is
oriented around that constraint.

---

## Critical Pitfalls

Mistakes that cause rewrites, regressions, or audit failures.

---

### Pitfall 1: Optimizing Without Profiling First

**What goes wrong:** Developers guess where the bottleneck is and optimize the wrong thing.
The artificial 2.2s launch delay mentioned in PROJECT.md is already fixed; the remaining bottleneck
may be in a different subsystem entirely (e.g., GRDB initialization, APIClient actor setup, theme
snapshot construction).

**Why it happens:** Intuition about "slow code" is notoriously unreliable. Profiling is skipped to
save time, then the optimization makes no measurable difference while introducing risk.

**Consequences:**
- Changes to hot paths that were not actually slow
- Regression in v1.0 audit REQs from unnecessary refactoring
- Wasted implementation effort, false performance claims

**Prevention:**
- Instrument first: Xcode Instruments (Time Profiler, Allocations, SwiftUI instrument from Xcode 16/WWDC25),
  then pick the one bottleneck with the highest impact
- Establish baselines with `measure {}` in XCTest before any change
- Document the measured before/after for every optimization attempt

**Detection:** If you cannot name the profiler trace that motivated a change, it is premature.

---

### Pitfall 2: Replacing LazyVStack with List Without Verifying Animation Contracts

**What goes wrong:** The sessions list (22K+ sessions) and chat messages (200+ in history) currently
use `LazyVStack`. Switching to `List` for its superior view recycling and memory behavior can silently
break:

- Row swipe actions (delete, fork) — `List` exposes `.swipeActions` but its behavior differs
- Custom row transitions and animations — `List` restricts which transition types work on rows
- `ScrollViewReader` / `.scrollTo()` — `List` and `LazyVStack` behave differently with `ScrollViewProxy`
- The `DragGesture`-based user-scroll detection in `ChatMessageList` relies on the `ScrollView` wrapper;
  `List` wraps its own `ScrollView` internally, breaking this detection

**Why it happens:** The memory and scrolling performance of `List` is clearly superior for large
datasets (research shows LazyVStack took 52.3s vs List's 5.53s to scroll to bottom in a large set),
so the switch seems like a pure win. The animation/gesture contracts are invisible until tested.

**Consequences:** Jump-to-bottom FAB stops working during SSE streaming; swipe-to-delete silently
disappears; context menus misfire.

**Prevention:**
- Test every gesture and animation interaction after switching container type
- Never switch both the container type and the data strategy in the same commit
- Prefer `List` for `SessionsView` (static rows, large dataset), keep `LazyVStack` for `ChatMessageList`
  (dynamic streaming content, needs precise scroll control)

**Detection:** v1.0 audit REQs include session navigation and chat functionality — re-run the full
REQ checklist after any container change.

---

### Pitfall 3: Breaking SSE Streaming with Request Deduplication or Throttling

**What goes wrong:** Adding global request deduplication or throttling to `APIClient` to reduce
network calls inadvertently captures the SSE streaming endpoint or the chat POST.

**Specific risk in ILS:** `SSEClient` uses a long-lived URLSession with 5-minute request timeout
and 1-hour resource timeout. If a deduplication layer in `APIClient` treats the chat stream URL as
a "duplicate in-flight request" and suppresses it, streaming silently fails — the UI may show
"connecting" indefinitely.

Additionally, Swift's async throttled sequences have documented "lost updates" semantics (Swift Forums
2023): if a new event arrives within the throttle window, it is simply dropped, not queued. Applied
to real-time streaming, this drops messages.

**Why it happens:** Deduplication is implemented at the `APIClient` actor level without carving out
an exception for streaming endpoints. The SSE call looks like a regular POST from the deduplication
layer's perspective.

**Consequences:** Chat stops working; SSE stream silently never fires; existing v1.0 E2E chat
validation fails.

**Prevention:**
- Scope deduplication strictly to `GET` requests on reference data endpoints (`/skills`, `/mcp`,
  `/plugins`, `/themes`, `/stats`) — never to `POST` endpoints
- The `SSEClient` is already isolated from `APIClient` and manages its own URLSession; keep it that
  way — do not merge them for efficiency
- Write an explicit allowlist of deduplicatable paths: `ttl(for:)` in `APIClient.swift` already
  contains this logic; expand it rather than replacing it with a blanket deduplicator

**Detection:** After any networking change, verify with `curl -N http://localhost:9999/api/v1/chat/stream`
that streaming still works end-to-end.

---

### Pitfall 4: Lazy Loading Race Conditions in SessionsViewModel

**What goes wrong:** Adding lazy loading or pagination optimizations to `SessionsViewModel` creates
TOCTOU (time-of-check to time-of-use) races. Specifically:

- Prefetch triggers a background load for page N+1
- User simultaneously deletes a session or filters by search
- The prefetch result arrives and overwrites the post-delete state
- A session that was deleted re-appears in the list

**Current risk surface:** `SessionsViewModel` already has `projectPages`, `loadingProjects: Set`,
`projectHasMore: [String: Bool]`, and `searchCache`. A performance optimization that adds background
prefetch tasks runs on the `@MainActor` but tasks dispatched with `Task {}` can be interleaved at
suspension points.

**Why it happens:** Pagination state is mutable shared state. Async tasks that fetch additional
pages and tasks that mutate the list (delete, create, search reset) are not serialized. At any
`await` point, another task can run and change `currentPage` or `sessions`.

**Consequences:** Phantom sessions appear after delete; search results flicker; pagination counter
drifts (hasMore shows false when more exist, or vice versa).

**Prevention:**
- Introduce a `loadingTask: Task?` sentinel — cancel it before starting any mutation operation
- Use a generation counter pattern: each fetch captures the generation at start; discard results if
  generation changed by the time they arrive
- Never write to `sessions`, `currentPage`, or `hasMore` from two concurrent tasks without a guard

**Detection:** Test: load first page → delete a session → immediately scroll to trigger load of page
2 → verify deleted session is absent from page 2 result.

---

### Pitfall 5: @Observable Memory Leak via @State Initialization Side Effects

**What goes wrong:** The app already uses `@Observable @MainActor class` ViewModels. If a performance
optimization adds expensive initialization work inside the VM's `init()` (e.g., pre-warming a GRDB
query, pre-populating a search cache), it gets executed every time SwiftUI rebuilds the parent view —
not just once.

**Why it happens:** `@State` with `@Observable` calls the initializer on every view rebuild. SwiftUI
preserves the original @State value but the new instances linger in memory. If those instances register
notification observers, start Timer tasks, or allocate large caches, memory grows unboundedly.

**Specific ILS risk:** `SessionsViewModel` pre-computes `searchCache` and `cachedGroupedSessions`.
If this pre-computation is moved to `init()` as an optimization (to avoid the first-use delay), it
runs on every view rebuild. With 22K sessions, this is expensive.

**Consequences:** Memory usage climbs session after session; notification handlers fire multiple
times for one event; the < 100MB memory target (PERF-02) is missed.

**Prevention:**
- Keep `@Observable` VM `init()` free of I/O, database access, network calls, and notification
  registration
- Move expensive one-time setup into `.task {}` modifier or `onAppear` — these run once per view
  lifetime, not once per rebuild
- Store long-lived VMs at `App` struct level using `@State`, not at individual view level

**Detection:** Allocations instrument with "Generation Analysis" — watch for multiple live
`SessionsViewModel` instances simultaneously.

---

### Pitfall 6: Theme Snapshot Causing Spurious Full-Tree Re-renders

**What goes wrong:** `ThemeSnapshot` is passed via `@Environment(\.theme)`. Any optimization that
causes a new `ThemeSnapshot` to be created (e.g., debouncing theme saves, adding a new computed
property that touches theme) triggers re-renders of every view in the hierarchy that reads `theme`.

**Current risk:** `ThemeSnapshot` is a concrete struct (replaced from `any AppTheme` existential in
the v1.0 audit — 58 occurrences, 48 views). If the optimization incorrectly makes `ThemeSnapshot`
an `@Observable class` or adds `@Published` properties, it stops being Equatable and SwiftUI can
no longer diff it, causing every theme read site to re-render on any state change anywhere.

**Specific animation risk:** The 13 built-in themes include animation tokens. If performance work
adds `.animation(.default)` without `value:` parameter (deprecated form) anywhere in a theme-reading
view, it causes all animatable properties in that entire subtree to animate on every state change —
including non-animated data updates like session count changes.

**Why it happens:** `.animation(.easeInOut)` without a `value:` parameter is the implicit animation
modifier — deprecated since iOS 15 but still compiles. It attaches to every animatable change in
the subtree.

**Consequences:** List rows animate during search filtering; pagination load indicators animate
erratically; the streaming indicator pulses at wrong times.

**Prevention:**
- Keep `ThemeSnapshot` as a struct with value semantics — never convert to a class for performance
- Always use `.animation(.easeInOut, value: someSpecificValue)` — never the valueless form
- When adding animation to performance code (e.g., lazy-load shimmer), scope it to the shimmer view
  only, not to a parent container

**Detection:** `View._printChanges()` in debug builds — if theme is listed as changed when you did
not change the theme, the ThemeSnapshot is being recreated unnecessarily.

---

## Moderate Pitfalls

---

### Pitfall 7: NSCache in APIClient Serving Stale Data After Mutations

**What goes wrong:** `APIClient` already has an `NSCache`-backed in-memory cache with per-endpoint
TTLs (15s for sessions, 5min for reference data). A performance optimization that extends these TTLs
or adds a second cache layer (e.g., prefetching into GRDB `CacheService` on top of the existing
`NSCache`) can serve stale data after the user performs a write operation.

**Specific scenario:** User renames a session → `PUT /sessions/{id}` succeeds → sessions list reads
from NSCache (still 15s TTL) → old name shown for up to 15 more seconds. Extending TTL to 60s makes
this worse.

**Prevention:**
- Implement cache invalidation by key: any write to `/sessions/{id}` must call `cache.removeObject(forKey: "/sessions")`
- Never add a second cache layer on top of an existing one without auditing all write paths
- The dual-layer (NSCache in APIClient + GRDB in CacheService) is already a smell — for this
  milestone, extend TTLs on read-only reference endpoints only; leave sessions at 15s or shorter

**Detection:** Perform a rename → immediately reload the list → verify new name appears.

---

### Pitfall 8: Over-aggressive Lazy Loading Breaking Cross-Platform Builds

**What goes wrong:** Lazy loading optimizations written for iOS (e.g., using `LazyVGrid` or iOS 17
`scrollTargetLayout`) may not compile on macOS 14 without conditional compilation. The auto-build
hook fires on every `.swift` edit — a build failure on macOS blocks further development.

**Current macOS surface:** `ILSMacApp/` has 14 Swift files. Any shared code in `ILSShared/` or
views that are referenced from both targets must compile and function on both platforms.

**Prevention:**
- Run both `xcodebuild ILSApp` and `xcodebuild ILSMacApp` after every optimization change
- Use `#if os(iOS)` guards for iOS-only APIs rather than introducing compile errors
- Prefer APIs available on both platforms (e.g., `ScrollView` + `LazyVStack` is cross-platform;
  `List.listStyle(.insetGrouped)` is iOS-only)

**Detection:** The auto-build hook catches this immediately for the edited target. Run the second
target's build check manually after any shared-code change.

---

### Pitfall 9: Metrics Sliding-Window History Growing Unboundedly Under Optimization

**What goes wrong:** `MetricsWebSocketClient` maintains sliding windows of 60 data points each for
CPU, memory, disk, and network history. A performance optimization that increases the WebSocket
polling rate (to make charts smoother) or reduces the aggregation interval will overflow the 60-item
cap faster, and if the cap logic has an off-by-one it grows unboundedly.

**Prevention:**
- Do not change `maxHistorySize` without also verifying the cap logic under high-frequency updates
- Verify with Instruments Allocations that the MetricsWebSocketClient array memory stays flat during
  extended monitoring sessions
- If polling rate increases for battery optimization reasons, reduce history window to compensate

---

### Pitfall 10: ForEach with Array.enumerated() Causing Identity Churn

**What goes wrong:** `ChatMessageList` currently uses `ForEach(Array(messages.enumerated()), id: \.element.id)`.
This is correct. A well-intentioned optimization that switches to `id: \.offset` (using the index
as identity) causes full re-renders of the entire message list whenever any message is inserted,
because index identity changes for all items after the insertion point.

**Prevention:**
- Always use `id: \.element.id` (the message's stable UUID) — never the index as identity
- When adding virtualization or windowing to the message list, preserve the UUID-based identity
- Swift 6.2 / iOS 26 adds `RandomAccessCollection` conformance to `EnumeratedSequence` — this is
  safe to adopt if targeting iOS 26+, but index-as-id is still wrong

---

### Pitfall 11: Simulator Performance Measurements Not Matching Device

**What goes wrong:** XCTest `measure {}` performance tests run in the simulator. Simulator does not
replicate the CPU throttling, memory pressure, or thermal constraints of a physical iPhone 16 Pro Max.
A baseline established in the simulator can show the optimization "passes" while the device still
shows jank.

**Prevention:**
- Run Instruments on the dedicated simulator (UDID: 50523130-57AA-48B0-ABD0-4D59CE455F14) for
  relative measurements (before vs after), not for absolute guarantees
- For PERF-01 (launch under 1s) and PERF-04 (60fps scrolling), validate on physical hardware as
  a final gate — simulator can be 2-5x faster or slower depending on the metric
- XCTest `measure` runs the block 10 times and reports average ± stddev. A high stddev (>20% of mean)
  means the measurement is unreliable — increase warmup iterations or isolate the measured operation

**Detection:** Stddev > 20% of mean in `measure {}` output is a red flag. Discard that baseline.

---

### Pitfall 12: Battery Optimization Breaking ScenePhase Handling

**What goes wrong:** Battery work typically involves stopping timers, cancelling WebSocket connections,
and pausing animations when the app enters background. The `PollingManager.handleScenePhase()` already
does this correctly. A performance optimization that adds additional periodic tasks (prefetch timers,
cleanup schedulers, metrics aggregation) may not hook into `scenePhase` correctly.

**Known issue:** `ScenePhase` has documented bugs in SwiftUI — the boundary between `.inactive` and
`.background` is unreliable, and a rapid foreground → background → foreground cycle can leave a
task running when it should have been cancelled.

**Prevention:**
- Every new Timer or repeating Task must have a corresponding `scenePhase == .background` cancellation
- Use `Task { }` with structured cancellation (task stored in a property, cancelled in `deinit` or
  `onDisappear`) rather than detached tasks
- Test the background cancellation by sending the app to background via home button and checking
  that network activity stops (use Charles or Console.app network logs)

---

## Minor Pitfalls

---

### Pitfall 13: Image/Asset Optimization Changing Theme Visual Parity

**What goes wrong:** Optimizing asset sizes or switching from `Image("name")` to `Image(systemName:)`
for smaller bundle size changes the visual appearance. The 13 themes have specific icon styles
configured. SF Symbol variants (filled, outline, multicolor) may not match the original assets.

**Prevention:** Screenshot-compare after any asset optimization. The v1.0 audit evidence in
`evidence/final/` provides the baseline.

---

### Pitfall 14: Caching 22K Session Titles in Memory for Search

**What goes wrong:** `SessionsViewModel.searchCache` pre-computes lowercased search strings for each
session. With 22K sessions (all loaded from backend), this array holds 22K `(ChatSession, String)`
tuples. Rebuilding this cache on every search text change (even with debounce) while simultaneously
holding the full `sessions` array doubles the memory footprint for sessions.

**Prevention:**
- The search cache should only be built for the currently-loaded page (50 sessions per page), not
  the full 22K corpus
- Server-side search (already partially implemented via `searchQuery` in `SessionsViewModel`) is the
  correct solution for 22K sessions — do not replace it with a client-side full-corpus cache

---

### Pitfall 15: GRDB Write Amplification from CacheService

**What goes wrong:** `CacheService.cacheMessages()` deletes all messages for a session then re-inserts
them all. On a 200-message chat history, this is 200 deletes + 200 inserts on every cache update.
An optimization that calls this more frequently (e.g., after every SSE token) causes write amplification
that increases battery drain, not decreases it.

**Prevention:**
- Cache messages once at session load, not during active streaming
- During SSE streaming, buffer tokens in memory only; persist to GRDB only when stream completes
  (the `done` SSE event)

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|----------------|------------|
| Launch time optimization | Pitfall 5 — expensive VM init() moved earlier instead of eliminated | Profile with Time Profiler; eliminate work, don't shift it |
| Session list virtualization | Pitfall 2 — LazyVStack → List breaks gesture/scroll contracts | Test swipe actions, scroll detection, jump-to-bottom after switch |
| Network batching / dedup | Pitfall 3 — SSE stream accidentally deduplicated | Allowlist-only dedup; never touch POST /chat/stream |
| Lazy loading / prefetch | Pitfall 4 — pagination race with concurrent mutations | Generation counter; cancel prefetch on any write |
| Memory < 100MB target | Pitfall 5, 7, 14 — multiple overlapping caches | One source of truth per data type; audit with Allocations |
| 60fps chat rendering | Pitfall 10 — identity churn on ForEach | UUID-based id only; avoid index-as-id |
| Battery optimization | Pitfall 12 — new tasks skip scenePhase cancellation | Every task must have scenePhase .background cancel |
| Regression test infra | Pitfall 11 — simulator baselines are unreliable for absolute values | Use relative (before/after) comparisons; validate on device for PERF-01/04 |
| Theme animations | Pitfall 6 — valueless .animation() modifier added during perf work | Use .animation(.x, value: y) always; check with _printChanges() |
| macOS cross-platform | Pitfall 8 — iOS-only APIs sneak into shared code | Build both targets after every shared-code change |

---

## Anti-Pattern Summary

| Anti-Pattern | Correct Pattern |
|--------------|-----------------|
| Optimize based on intuition | Profile with Instruments first |
| Extend all cache TTLs to reduce network | Extend read-only reference TTLs only; keep write-adjacent TTLs short |
| Add deduplication to all requests | Allowlist specific GET endpoints; exclude all POST/streaming |
| Move expensive setup into VM init() | Keep init() trivial; use `.task {}` for async setup |
| Switch LazyVStack → List everywhere | Use List for large static data; keep LazyVStack for streaming/dynamic |
| Build in-memory full-corpus search cache | Use server-side search for > 1K items |
| Use .animation() without value: parameter | Always use .animation(x, value: y) |
| Add periodic tasks without scenePhase hooks | Every recurring task gets cancelled on .background |
| Measure performance in simulator only | Simulator for relative; device for absolute gates |

---

## Sources

- Apple Developer: [Understanding and Improving SwiftUI Performance](https://developer.apple.com/documentation/Xcode/understanding-and-improving-swiftui-performance)
- Apple WWDC25: [Optimize SwiftUI performance with Instruments](https://developer.apple.com/videos/play/wwdc2025/306/)
- Apple WWDC25: [Explore concurrency in SwiftUI](https://developer.apple.com/videos/play/wwdc2025/266/)
- fatbobman: [List or LazyVStack — Choosing the Right Lazy Container](https://fatbobman.com/en/posts/list-or-lazyvstack/) — HIGH confidence
- fatbobman: [Memory Usage Optimization for SwiftUI + Core Data](https://fatbobman.com/en/posts/memory-usage-optimization/) — HIGH confidence
- Jesse Squires: [@Observable is not a drop-in replacement for ObservableObject](https://www.jessesquires.com/blog/2024/09/09/swift-observable-macro/) — HIGH confidence
- Swift Forums: [Surprising semantics of throttled sequences](https://forums.swift.org/t/surprising-semantics-of-throttled-sequences/65409) — HIGH confidence
- Jesse Squires: [SwiftUI app lifecycle: issues with ScenePhase](https://www.jessesquires.com/blog/2024/06/29/swiftui-scene-phase/) — MEDIUM confidence
- SwiftUI @Observable pitfall: [Performance increase over ObservableObject](https://www.avanderlee.com/swiftui/observable-macro-performance-increase-observableobject/) — HIGH confidence
- Airbnb Engineering: [Understanding and Improving SwiftUI Performance](https://medium.com/airbnb-engineering/understanding-and-improving-swiftui-performance-37b77ac61896) — MEDIUM confidence (paywalled)
- ILS codebase inspection: `CacheService.swift`, `SSEClient.swift`, `ChatMessageList.swift`, `SessionsViewModel.swift`, `APIClient.swift`, `PollingManager.swift`, `MetricsWebSocketClient.swift` — HIGH confidence (direct code review)
