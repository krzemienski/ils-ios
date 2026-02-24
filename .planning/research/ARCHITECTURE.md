# Architecture Patterns: Performance Optimization Integration

**Domain:** SwiftUI iOS/macOS app performance optimization
**Project:** ILS — Intelligent Local Server client
**Researched:** 2026-02-22
**Confidence:** HIGH (based on direct codebase inspection)

---

## Existing Architecture Map

Before documenting integration points, here is the actual component graph as read from source:

```
ILSAppApp.swift
  ├── AppState (@Observable @MainActor)
  │     ├── ConnectionManager (@Observable @MainActor)
  │     │     ├── APIClient (actor)
  │     │     └── SSEClient (@Observable @MainActor)
  │     ├── PollingManager (@MainActor)
  │     └── NetworkMonitor (@Observable @MainActor, singleton)
  │
  ├── ThemeManager
  │
  └── SidebarRootView (root SwiftUI view)
        ├── SessionsViewModel (@Observable @MainActor, @State)
        ├── HomeView
        │     └── DashboardViewModel (@Observable @MainActor, @State)
        ├── ChatView
        │     └── ChatViewModel (@Observable @MainActor, @State)
        │           └── SSEClient (reference from AppState)
        ├── BrowserView
        │     ├── MCPViewModel
        │     ├── SkillsViewModel
        │     └── PluginsViewModel
        └── [other screen views...]

Services (singletons):
  CacheService (actor)
    └── LocalDatabase (actor) — GRDB SQLite, WAL mode
  SyncCoordinator (actor)
```

---

## Performance Optimization Integration Points

### 1. Launch Deferral

**Problem identified:** `ILSAppApp.swift` line 52 has a hardcoded `Task.sleep(for: .seconds(2.2))` artificial delay before dismissing the launch screen. `CacheService.shared.initialize()` (which runs GRDB migrations) also executes inline in the launch `.task`.

**Current flow:**
```
App launches → LaunchScreenView shown → .task fires:
  1. Tips.configure()          [~10ms]
  2. CacheService.initialize() [~50ms — GRDB migrations]
  3. Task.sleep(2.2s)          [ARTIFICIAL DELAY — the main target]
  4. withAnimation: hide launch screen
```

**Integration approach — MODIFY `ILSAppApp.swift`:**

Replace the hardcoded 2.2s sleep with milestone-based dismissal. The launch screen should hide as soon as the minimum useful work is done — specifically after `ConnectionManager.init()` completes and either (a) a cached health check confirms the server is up, or (b) a 0.3s minimum display time elapses (prevents flash-of-content on fast devices).

```swift
// REPLACE this block in ILSAppApp.swift .task:
try? await Task.sleep(for: .seconds(2.2))
withAnimation(.easeOut(duration: 0.5)) {
    showLaunchScreen = false
}

// WITH milestone-based dismissal:
let minDisplay = Task.detached { try? await Task.sleep(for: .seconds(0.3)) }
await CacheService.shared.initialize() // already here, keep it
_ = try? await appState.apiClient.healthCheck() // warm the connection
await minDisplay.value
withAnimation(.easeOut(duration: 0.4)) {
    showLaunchScreen = false
}
```

**Downstream effects:** None. `showLaunchScreen` is purely local `@State`. `SidebarRootView` is already rendering behind the launch screen overlay (`zIndex(1)`) — it starts loading immediately. Dismissing the overlay sooner exposes an already-rendered UI.

**File to modify:** `ILSApp/ILSApp/ILSAppApp.swift`
**Lines affected:** 42–56 (the `.task` block)

---

### 2. Lazy Loading — Sessions List (500+ sessions at 60fps)

**Problem identified:** `SessionsViewModel.loadSessions()` loads page 1 (50 items) eagerly. The `ChatMessageList` already uses `LazyVStack` (correct). The sessions sidebar (`SidebarView`) renders `SidebarSessionRow` items inside a `List` or `LazyVStack` — need to verify.

**Current pagination flow (already exists):**
- `pageSize = 50`, `currentPage` incremented by `loadMore()`
- `loadMore()` is triggered by caller — need to verify it is wired to list onAppear for the last visible item

**Inspect `SidebarView.swift`** to confirm `loadMore()` is triggered at the bottom of the sessions list. If not wired, this is a modification target.

**For BrowserView (1,500+ skills / 84 plugins):**
`BrowserView` already uses `LazyVStack` inside `ScrollView`. Each segment's content renders rows lazily. The segment VMs (MCPViewModel, SkillsViewModel, PluginsViewModel) should be confirmed to use pagination — if they load all items at once, add server-side pagination with `?page=1&limit=50`.

**Files to potentially modify:**
- `ILSApp/ILSApp/Views/Root/SidebarView.swift` — wire `loadMore()` trigger
- `ILSApp/ILSApp/ViewModels/MCPViewModel.swift` — add pagination if absent
- `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` — add pagination if absent
- `ILSApp/ILSApp/ViewModels/PluginsViewModel.swift` — add pagination if absent

**For ChatMessageList (200+ messages at 60fps):**
`ChatMessageList.swift` already uses `LazyVStack` (line 119). The remaining rendering cost is `AssistantCard` and `UserMessageCard` complexity. If messages contain large markdown blocks or code, `MarkdownTextView` and `CodeBlockView` should be measured with Instruments.

**Optimization pattern — equatable message identity:**
`ChatMessage` should conform to `Equatable` so SwiftUI's diffing engine can skip re-rendering unchanged messages. This is a surgical addition to `ILSApp/ILSApp/Models/ChatMessage.swift`.

---

### 3. Request Batching and Deduplication

**Problem identified:** `DashboardViewModel.loadAll()` makes two sequential awaited requests: `GET /stats` then `GET /stats/recent`. `HomeView.task` also calls `sessionsVM.loadSessions(refresh: true)` — a third request. These fire sequentially on HomeView appear.

`APIClient` is an `actor` with an `NSCache`-backed in-memory cache. The cache deduplicates identical GET paths within their TTL, but does NOT batch concurrent identical requests (two concurrent `GET /sessions` calls will both fire).

**Integration approach — NEW component: `RequestDeduplicator`:**

Create `ILSApp/ILSApp/Services/RequestDeduplicator.swift` as a Swift `actor`. It maintains a dictionary of `[String: Task<Data, Error>]` keyed by URL path. When a second call arrives for an in-flight path, it awaits the existing Task instead of creating a new one.

```
RequestDeduplicator (actor) — NEW FILE
  - inflight: [String: Task<Data, Error>]
  - func deduplicated(path:fetch:) async throws -> Data
```

Integrate into `APIClient.get()` — before the NSCache check, check `RequestDeduplicator`. The actor boundary makes this thread-safe without locks.

**For parallel Dashboard loading:** Modify `DashboardViewModel.loadAll()` to use `async let` for concurrent stats + recent activity fetches:

```swift
// REPLACE sequential in DashboardViewModel.loadAll():
await loadStats()
await loadRecentActivity()

// WITH parallel:
async let statsTask: Void = loadStats()
async let activityTask: Void = loadRecentActivity()
_ = await (statsTask, activityTask)
```

**Files to modify:**
- `ILSApp/ILSApp/Services/APIClient.swift` — add deduplication hook
- `ILSApp/ILSApp/ViewModels/DashboardViewModel.swift` — async let parallelism

**New file:**
- `ILSApp/ILSApp/Services/RequestDeduplicator.swift`

---

### 4. Memory Pressure Handling

**Problem identified:** `APIClient` has an `NSCache<NSString, CacheEntryObject>` with `countLimit = 100`. `NSCache` already evicts under memory pressure automatically — this is correct behavior. However, `SSEClient` accumulates `messages: [StreamMessage]` unboundedly during long streams. `ChatViewModel.messages: [ChatMessage]` also grows without bound.

**For SSEClient — MODIFY:**
`SSEClient.messages` is read by `ChatViewModel.setupBindings()` via `withObservationTracking`. After ChatViewModel processes messages (via `processStreamMessages`), the raw `SSEClient.messages` array is no longer needed. Add a `flushProcessedMessages()` call that clears `sseClient.messages` after ChatViewModel drains them, preventing the raw stream buffer from growing across the session lifetime.

**For ChatViewModel.messages — virtual windowing:**
For conversations with 200+ messages, only the visible viewport needs to be in the render tree. Implement a virtual window: keep all messages in the data model but render only a window of ~50 around the scroll position, using `LazyVStack` + `onAppear`/`onDisappear` anchors to expand the window. This is a targeted modification to `ChatMessageList.swift`.

**For memory pressure notifications — NEW component:**
Create `ILSApp/ILSApp/Services/MemoryPressureMonitor.swift` that observes `UIApplication.didReceiveMemoryWarningNotification`. On warning: call `APIClient.invalidateCache()`, trim `SSEClient.messages` to last 10, and optionally trim `ChatViewModel.messages` to last 50 visible.

Wire into `AppState.init()` by holding a reference to `MemoryPressureMonitor`.

**Files to modify:**
- `ILSApp/ILSApp/Services/SSEClient.swift` — add `flushProcessedMessages()`
- `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` — call flush after processing
- `ILSApp/ILSApp/Views/Chat/ChatMessageList.swift` — virtual window for 200+ messages
- `ILSApp/ILSApp/ILSAppApp.swift` — hold MemoryPressureMonitor reference

**New file:**
- `ILSApp/ILSApp/Services/MemoryPressureMonitor.swift`

---

### 5. Low Power Mode Integration

**Problem identified:** The existing codebase has no Low Power Mode awareness. `PollingManager.startHealthPolling()` polls every 60 seconds regardless. `SSEClient`'s `allowsConstrainedNetworkAccess = false` handles Low Data Mode (cellular cost) but not Low Power Mode (battery).

**Architecture — MODIFY `PollingManager`:**

`ProcessInfo.processInfo.isLowPowerModeEnabled` is synchronously readable on iOS. `NSProcessInfoPowerStateDidChangeNotification` fires when the user toggles Low Power Mode.

Modify `PollingManager` to observe this notification and adjust the health poll interval:

```
Normal mode:     60s health poll interval
Low Power Mode:  180s health poll interval (3 minutes)
```

**Architecture — MODIFY `SSEClient`:**

`SSEClient` should check `ProcessInfo.processInfo.isLowPowerModeEnabled` when deciding whether to enable the 45s heartbeat watchdog. In Low Power Mode, extend the watchdog to 120s (less aggressive reconnection = less radio activity).

**Architecture — Theme animations:**

`CyberpunkEffects.swift` and other animated theme components (shimmer, pulsing indicators) should check `@Environment(\.accessibilityReduceMotion)` — which already exists in many views. For Low Power Mode specifically, `ProcessInfo.processInfo.isLowPowerModeEnabled` should be read at the `ThemeManager` level and exposed as a published property, so animated components can opt-out.

**Files to modify:**
- `ILSApp/ILSApp/Services/PollingManager.swift` — variable poll interval
- `ILSApp/ILSApp/Services/SSEClient.swift` — watchdog interval scaling
- `ILSApp/ILSApp/Theme/CyberpunkEffects.swift` — animation gating
- `ILSApp/ILSApp/Theme/Components/ShimmerModifier.swift` — animation gating
- `ILSApp/ILSApp/Theme/Components/StreamingIndicatorView.swift` — animation gating

**No new files required.** The existing `NetworkMonitor` pattern (singleton observing system state) can be replicated inline in `PollingManager` rather than requiring a separate `LowPowerMonitor` class.

---

### 6. Background Suspension

**Problem identified:** `AppState.handleScenePhase()` delegates to `PollingManager.handleScenePhase()`. That method stops all polling on `.background` — correct. However, it does NOT: (1) cancel in-flight `SSEClient` streams, (2) flush `CacheService` pending writes, or (3) suspend `MetricsWebSocketClient` if active.

**`PollingManager.handleScenePhase` current behavior:**
```swift
case .background:
    stopHealthPolling()    // ✓ correct
    stopRetryPolling()     // ✓ correct
    // Missing: SSEClient suspension, WebSocket suspension, cache flush
```

**Integration approach — extend `AppState.handleScenePhase()`:**

```swift
// In AppState.handleScenePhase():
func handleScenePhase(_ phase: ScenePhase) {
    pollingManager.handleScenePhase(phase)
    switch phase {
    case .background:
        // Suspend SSE (user can't read anyway; resume on foreground)
        sseClient.suspend()     // NEW method on SSEClient
        // Flush any pending cache writes
        Task { await CacheService.shared.flush() }
    case .active:
        // Resume SSE only if a chat session was active
        sseClient.resumeIfNeeded()  // NEW method on SSEClient
    default: break
    }
}
```

**`SSEClient` needs two new methods:**
- `suspend()`: cancels `streamTask` but preserves `currentRequest` for resume
- `resumeIfNeeded()`: if `currentRequest` is non-nil and `connectionState == .disconnected`, restarts the stream

This is a nuanced change — the stream must only be resumed if the user was actively in a ChatView when they backgrounded. `ChatViewModel` should track this and call `sseClient.resumeIfNeeded()` from its own `scenePhase` handler.

**MetricsWebSocketClient suspension:**
`MetricsWebSocketClient.swift` manages a WebSocket for system metrics. It should observe `scenePhase` directly and disconnect on `.background`, reconnect on `.active`. Verify whether it already does this — the file exists in Services but was not read in detail.

**Files to modify:**
- `ILSApp/ILSApp/ILSAppApp.swift` — extend `onChange(of: scenePhase)` to cover SSE suspension
- `ILSApp/ILSApp/Services/SSEClient.swift` — add `suspend()` / `resumeIfNeeded()`
- `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` — observe scenePhase for stream resume
- `ILSApp/ILSApp/Services/MetricsWebSocketClient.swift` — verify/add background disconnect

---

## Component Modification vs Creation Summary

### Modify (existing files, targeted changes)

| File | Optimization | Change Type |
|------|-------------|-------------|
| `ILSApp/ILSApp/ILSAppApp.swift` | Launch deferral, background suspension | Replace 2.2s sleep; extend scenePhase handler |
| `ILSApp/ILSApp/Services/APIClient.swift` | Request deduplication | Add deduplicator hook before NSCache check |
| `ILSApp/ILSApp/Services/PollingManager.swift` | Low Power Mode, background | Add NSProcessInfoPowerStateDidChangeNotification observer |
| `ILSApp/ILSApp/Services/SSEClient.swift` | Memory pressure, background, Low Power | Add `suspend()`/`resumeIfNeeded()`, flush, watchdog scaling |
| `ILSApp/ILSApp/Services/MetricsWebSocketClient.swift` | Background suspension | Add scenePhase disconnect if not present |
| `ILSApp/ILSApp/ViewModels/DashboardViewModel.swift` | Request batching | Replace sequential await with async let parallel |
| `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` | Memory pressure, background | Call flush after processing; scenePhase resume |
| `ILSApp/ILSApp/Views/Chat/ChatMessageList.swift` | Lazy loading (200+ messages) | Virtual window for large histories |
| `ILSApp/ILSApp/Models/ChatMessage.swift` | List diffing | Add `Equatable` conformance |
| `ILSApp/ILSApp/Theme/CyberpunkEffects.swift` | Low Power Mode | Gate animations on LPM |
| `ILSApp/ILSApp/Theme/Components/ShimmerModifier.swift` | Low Power Mode | Gate shimmer animation |
| `ILSApp/ILSApp/Views/Root/SidebarView.swift` | Lazy loading (sessions) | Wire `loadMore()` to list bottom onAppear |
| `ILSApp/ILSApp/ViewModels/MCPViewModel.swift` | Lazy loading | Verify/add server-side pagination |
| `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` | Lazy loading | Verify/add server-side pagination |
| `ILSApp/ILSApp/ViewModels/PluginsViewModel.swift` | Lazy loading | Verify/add server-side pagination |

### Create New (minimal surface area)

| File | Purpose | Why New |
|------|---------|---------|
| `ILSApp/ILSApp/Services/RequestDeduplicator.swift` | In-flight request deduplication | Orthogonal to APIClient; actor pattern for thread safety |
| `ILSApp/ILSApp/Services/MemoryPressureMonitor.swift` | UIApplication memory warning observer | Singleton observer; coordinates cache trimming |

**Total: 15 modified files, 2 new files.**

---

## Data Flow Changes

### Launch Sequence (after optimization)

```
Before: App → LaunchScreen → 2.2s sleep → Show UI (2.7s total)
After:  App → LaunchScreen → CacheInit + healthCheck (parallel) → min(0.3s) → Show UI (~0.5s)
```

The critical insight: `SidebarRootView` and its `@State` ViewModels are constructed immediately (they are behind the launch screen overlay). Their `.task` modifiers fire immediately. The optimization only removes the artificial gate that prevents showing the already-rendered UI.

### Network Request Flow (after deduplication)

```
Before: VM1.load() + VM2.load() → 2x GET /sessions → 2 network round-trips
After:  VM1.load() + VM2.load() → RequestDeduplicator → 1 GET /sessions → 1 round-trip; VM2 awaits VM1's result
```

`RequestDeduplicator` sits inside `APIClient.get()` before the NSCache check. The cache handles TTL-based deduplication; the deduplicator handles concurrent in-flight deduplication.

### Memory Pressure Response Flow

```
UIApplication.didReceiveMemoryWarningNotification
  → MemoryPressureMonitor
    → APIClient.invalidateCache()       [clears NSCache]
    → CacheService.trimSessions(to:50) [optional: trim GRDB if large]
    → SSEClient.flushProcessedMessages() [clears raw stream buffer]
    → ChatViewModel.trimMessages(to:50)  [keeps recent context visible]
```

### Background Suspension Flow

```
scenePhase → .background
  → PollingManager: stopHealthPolling(), stopRetryPolling()
  → SSEClient: suspend() [cancel streamTask, keep currentRequest]
  → MetricsWebSocketClient: disconnect()
  → CacheService: flush() [ensure pending GRDB writes complete]

scenePhase → .active
  → PollingManager: checkConnection()
  → ChatViewModel: resumeIfNeeded() → SSEClient.resumeIfNeeded()
  → MetricsWebSocketClient: reconnect() (if SystemMonitorView is visible)
```

---

## Build Order (Dependency-Ordered)

Build order matters because later components depend on earlier ones being stable.

### Phase 1: Foundation (no UI changes, pure service layer)

**Build first — these have no dependencies on UI:**

1. **`RequestDeduplicator.swift`** (new) — pure Swift actor, no imports
2. **`APIClient.swift`** — add deduplicator hook; affects all VMs that call `.get()`
3. **`MemoryPressureMonitor.swift`** (new) — UIKit notification observer, no SwiftUI
4. **`PollingManager.swift`** — add Low Power Mode observer; no UI dependencies

*Rationale: These changes are self-contained in the Services layer. Build and verify each one compiles before touching ViewModels.*

### Phase 2: ViewModel Optimizations (depend on Phase 1 services)

5. **`DashboardViewModel.swift`** — async let parallelism; depends on stable APIClient
6. **`ChatViewModel.swift`** — memory flush + scenePhase resume; depends on stable SSEClient
7. **`SessionsViewModel.swift`** — verify loadMore() is correctly wired (possibly no change)
8. **`MCPViewModel.swift`**, **`SkillsViewModel.swift`**, **`PluginsViewModel.swift`** — pagination

*Rationale: ViewModels compose services. Changes here affect Views but don't cascade to other services.*

### Phase 3: Model Layer

9. **`ChatMessage.swift`** — add Equatable conformance
   *Rationale: This enables SwiftUI diffing. Safe to do at any point but cleanest before View changes.*

### Phase 4: SSEClient (deserves its own phase — high risk)

10. **`SSEClient.swift`** — add `suspend()`, `resumeIfNeeded()`, `flushProcessedMessages()`, Low Power watchdog scaling

*Rationale: SSEClient is the most complex stateful service. Its changes affect ChatViewModel and ILSAppApp. Isolate it to verify streaming still works correctly before touching the entry point.*

### Phase 5: Entry Point and Background Lifecycle

11. **`ILSAppApp.swift`** — replace 2.2s sleep; extend scenePhase to cover SSE + MetricsWebSocket
12. **`MetricsWebSocketClient.swift`** — add background disconnect (verify or add)

*Rationale: Entry point changes affect all app startup behavior. Do this after services are stable. MetricsWebSocket change is adjacent to the scenePhase changes in ILSAppApp.*

### Phase 6: Views (highest risk — auto-build hook fires on every edit)

13. **`SidebarView.swift`** — wire loadMore() trigger to last visible session row
14. **`ChatMessageList.swift`** — virtual window for 200+ messages
15. **`CyberpunkEffects.swift`**, **`ShimmerModifier.swift`** — Low Power Mode animation gating

*Rationale: View changes trigger the auto-build hook on every edit. Do these last to avoid repeated build cycles while service layer is still in flux. Each view change should be followed by a simulator screenshot validation.*

### Phase 7: Regression Infrastructure

16. **XCTest performance metrics** — `XCTMetric`, `measure(metrics:)` for launch time, memory, rendering

*Rationale: Infrastructure should be built after the optimizations are complete, so the tests capture the baseline that must be preserved. Building this first would produce targets that can't yet be met.*

---

## Architecture Invariants to Preserve

These constraints from the existing architecture must not be violated by any optimization:

1. **`@MainActor` boundary**: All `@Observable` ViewModels are `@MainActor`. Any background work must use `Task.detached` or actors. Memory pressure callbacks arrive on an arbitrary queue — `MemoryPressureMonitor` must dispatch to `@MainActor` before touching VM state.

2. **`APIClient` actor isolation**: `APIClient` is a Swift `actor`. The `RequestDeduplicator` must also be an `actor` to integrate without data races. Do not add `nonisolated` workarounds.

3. **`ThemeSnapshot` is a concrete struct**: Not a protocol. Low Power Mode gating in theme components must read from an `@Environment` value or a passed-in Bool — not from a new protocol extension on ThemeSnapshot.

4. **`NSCache` auto-eviction is intentional**: Do not replace NSCache with a custom dictionary. The system's memory pressure eviction is a feature. `MemoryPressureMonitor` supplements this by also trimming the SQLite cache and stream buffers.

5. **GRDB WAL mode**: `LocalDatabase` uses `DatabasePool` in WAL mode. Writes from `CacheService` are already non-blocking. The background suspension flush (`CacheService.flush()`) should wait for any in-progress write transaction to complete, not cancel it.

6. **All v1.0 audit REQs must remain PASS**: The 15 validated REQs cover navigation, settings inheritance, chat functionality, system monitor, themes, and MCP. Performance optimizations that alter data loading timing (lazy loading, deduplication) must not break these behaviors. The risk area is sessions list — ensure pagination still shows all 22K+ sessions when scrolled.

---

## Risk Assessment per Optimization

| Optimization | Risk | Mitigation |
|-------------|------|------------|
| Launch deferral (remove 2.2s sleep) | LOW — UI already renders behind overlay | Validate: app shows live content within 1s cold start |
| Parallel Dashboard loading (async let) | LOW — independent endpoints, both can fail gracefully | Validate: DashboardView still shows on partial load failure |
| RequestDeduplicator | MEDIUM — new concurrency path; potential deadlock if actor re-entrancy mishandled | Validate: concurrent identical requests return same result, no timeout |
| Memory pressure trimming | LOW — additive observer; existing NSCache eviction unchanged | Validate: no crash under memory warning in Simulator |
| Low Power Mode polling | LOW — only changes interval, not behavior | Validate: health polling resumes at normal interval when LPM disabled |
| SSEClient suspend/resume | HIGH — stateful streaming; resume timing is nuanced | Validate: stream resumes correctly after background return; no duplicate messages |
| ChatMessageList virtual window | MEDIUM — scroll position can jump if window size wrong | Validate: scroll position preserved through window expansion |
| Browser pagination | MEDIUM — backend must support it; UX regression if "load more" UX is poor | Validate: all 1500+ skills accessible via pagination |

---

## Sources

All findings based on direct code inspection of:
- `ILSApp/ILSApp/ILSAppApp.swift` (launch sequence, scenePhase handling)
- `ILSApp/ILSApp/Services/APIClient.swift` (caching architecture, request flow)
- `ILSApp/ILSApp/Services/SSEClient.swift` (streaming state machine)
- `ILSApp/ILSApp/Services/CacheService.swift` + `LocalDatabase.swift` (persistence layer)
- `ILSApp/ILSApp/Services/PollingManager.swift` (health polling intervals)
- `ILSApp/ILSApp/Services/NetworkMonitor.swift` (connectivity observation pattern)
- `ILSApp/ILSApp/Services/SyncCoordinator.swift` (actor patterns, offline queue)
- `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` (stream message batching)
- `ILSApp/ILSApp/ViewModels/SessionsViewModel.swift` (pagination, search cache)
- `ILSApp/ILSApp/ViewModels/DashboardViewModel.swift` (sequential loading)
- `ILSApp/ILSApp/Views/Chat/ChatMessageList.swift` (LazyVStack, scroll management)
- `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` (navigation architecture)
- `ILSApp/ILSApp/Views/Browser/BrowserView.swift` (LazyVStack segment rendering)
- `.planning/PROJECT.md` (performance targets and constraints)

Confidence: HIGH — all integration points verified against actual source code, not inferred.
