# Project Research Summary

**Project:** ILS iOS/macOS -- Performance Optimization Suite (v2.0)
**Domain:** SwiftUI performance optimization for a production native app
**Researched:** 2026-02-22
**Confidence:** HIGH

## Executive Summary

ILS is a functionally complete SwiftUI iOS/macOS client for Claude Code (15/15 REQs PASS, zero crashes). The v2.0 milestone is purely about performance across five dimensions: launch time, memory, network efficiency, rendering, and battery. Research confirms this is a **surgical optimization project, not an architectural rewrite** -- the existing stack (actor-based APIClient, GRDB caching, LazyVStack, @Observable ViewModels, structured concurrency) is fundamentally sound. No new SPM packages are required. Every optimization uses Apple SDK APIs that ship with iOS 17+.

The single highest-impact change is removing a hardcoded 2.2-second `Task.sleep` in `ILSAppApp.swift` that artificially delays launch. Beyond that, the work divides cleanly into service-layer changes (request deduplication, Low Power Mode awareness, memory pressure handling, background suspension) and view-layer changes (Equatable diffing, view body decomposition, animation gating). The architecture research identified exactly 15 files to modify and only 2 new files to create, with a clear dependency-ordered build sequence across 7 internal phases.

The primary risk is **regression, not feasibility**. Every optimization touches a working system. The PITFALLS research identified 15 specific failure modes, with the top threats being: optimizing without profiling first (wasted effort), breaking SSE streaming via overzealous request deduplication (chat stops working), and LazyVStack-to-List migration breaking scroll/gesture contracts. Prevention is straightforward -- profile before changing, allowlist-only deduplication scoped to GET endpoints, and validate all v1.0 REQs after each phase.

## Key Findings

### Recommended Stack

The existing stack requires zero new dependencies. All performance work uses built-in Apple APIs.

**Core technologies (no additions, all confirmed present):**
- **NSCache + GRDB** (dual-layer caching): Already correct; needs `totalCostLimit` on NSCache and memory pressure eviction wiring
- **Swift actor-based APIClient**: Ideal insertion point for request deduplication via `[String: Task]` dictionary -- actor isolation makes this thread-safe
- **ProcessInfo.isLowPowerModeEnabled** (iOS 9+): Absent from codebase; needs integration into PollingManager, SSEClient, and animation components
- **XCTest measure(metrics:)** with XCTApplicationLaunchMetric/XCTMemoryMetric/XCTCPUMetric: New test target for regression baselines
- **MetricKit** (MXMetricManagerSubscriber): Production field metrics -- daily aggregated payloads with no third-party dependency
- **OSSignposter** (iOS 15+): Instruments-compatible signpost annotations for network/render phase profiling

**Explicitly rejected:** Nuke/Kingfisher (no images), Combine pipelines (already on @Observable), GraphQL (overkill for local backend), Core Data migration (GRDB is correct), third-party analytics.

### Expected Features

**Must have (table stakes):**
- Remove artificial 2.2s launch delay -- users expect native apps to launch instantly
- Pagination-backed session list -- 22K+ sessions cannot be loaded unbounded
- Message list virtualization for 200+ message histories
- NSCache cost limits to prevent unbounded memory growth
- Animation pause in background and Low Power Mode
- View body decomposition for large views (910-line NewSessionView, 475-line HomeView)

**Should have (differentiators):**
- Profiling-driven baseline report with Instruments (before/after numbers, not "felt faster")
- Request deduplication in APIClient actor
- Syntax highlighting off-main-thread for CodeBlockView
- Background prefetch on session open (prefetch messages before ChatView push)
- XCTest regression test infrastructure with committed baselines
- OSSignposter annotations at key boundaries

**Defer (v2+):**
- Static linking audit -- only if Instruments shows dylib load > 200ms
- List vs LazyVStack migration for sessions -- measure scroll hitches first; migration has gesture/animation risk
- Swift 6 strict concurrency `@Sendable` closure audit -- correctness work, not performance

### Architecture Approach

The optimization integrates into the existing component graph without restructuring it. AppState owns ConnectionManager (which owns APIClient and SSEClient), PollingManager, and NetworkMonitor. ViewModels are `@Observable @MainActor` classes created at view level via `@State`. CacheService and LocalDatabase are actor singletons backed by GRDB in WAL mode. The optimization adds 2 new service actors (RequestDeduplicator, MemoryPressureMonitor) and modifies 15 existing files across the service, ViewModel, model, and view layers.

**Major modification targets:**
1. **ILSAppApp.swift** -- Replace 2.2s artificial delay with milestone-based launch; extend scenePhase for SSE/WebSocket suspension
2. **APIClient.swift** -- Add RequestDeduplicator hook before NSCache check; add memory pressure eviction
3. **SSEClient.swift** -- Add suspend/resumeIfNeeded for background lifecycle; Low Power watchdog scaling; flush processed messages
4. **PollingManager.swift** -- Low Power Mode observer (60s normal, 180s LPM); already correct on background
5. **ChatMessageList.swift** -- Virtual window for 200+ messages; Equatable-based diffing

**Architecture invariants that must NOT be violated:**
- `@MainActor` boundary on all ViewModels
- `APIClient` must remain a Swift actor (no nonisolated workarounds)
- `ThemeSnapshot` must remain a concrete struct (not class, not protocol)
- `NSCache` auto-eviction must be preserved (no custom dictionary replacement)
- GRDB WAL mode writes must not be cancelled mid-transaction
- All 15 v1.0 audit REQs must remain PASS

### Critical Pitfalls

1. **Optimizing without profiling first** -- Run Instruments (Time Profiler, Allocations, SwiftUI instrument) BEFORE any change. The artificial delay is obvious, but the remaining bottlenecks need measurement. If you cannot name the profiler trace that motivated a change, it is premature.

2. **Breaking SSE streaming with request deduplication** -- The chat POST/streaming endpoint MUST be excluded from deduplication. Scope deduplication strictly to GET requests on reference data endpoints (/skills, /mcp, /plugins, /themes, /stats). SSEClient manages its own URLSession -- keep it separate from APIClient.

3. **LazyVStack-to-List migration breaking gesture contracts** -- List and LazyVStack have different behaviors for ScrollViewReader, DragGesture, swipe actions, and custom row transitions. The jump-to-bottom FAB in ChatMessageList relies on ScrollView detection that List would break. Use List only for static large datasets (sessions); keep LazyVStack for streaming chat.

4. **Pagination race conditions in SessionsViewModel** -- Background prefetch tasks interleaved with delete/filter mutations cause phantom sessions. Use a generation counter pattern: each fetch captures generation at start; discard results if generation changed by completion.

5. **@Observable VM init() side effects causing memory leaks** -- `@State` with `@Observable` calls initializer on every view rebuild. Keep init() trivial. Move expensive setup (search cache pre-computation, GRDB queries) into `.task {}` modifiers which run once per view lifetime.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Profiling Baseline and Launch Fix
**Rationale:** Must measure before optimizing. The launch delay is the obvious first fix, but Instruments data is needed to prioritize everything else. Without baselines, you cannot prove any optimization worked.
**Delivers:** Instruments baseline report (Time Profiler, Allocations, SwiftUI). Launch time drops from ~2.7s to ~0.5s. Documented before/after measurements.
**Addresses:** PERF-01 (launch < 1s), foundation for all other PERF requirements
**Avoids:** Pitfall 1 (optimizing without profiling)
**Files:** `ILSAppApp.swift` (remove 2.2s sleep, milestone-based dismissal)

### Phase 2: Service Layer Optimization
**Rationale:** Service changes have no UI side effects and form the foundation for ViewModel and View optimizations. These can be built and verified independently before touching anything user-visible.
**Delivers:** Request deduplication (eliminates redundant network calls during launch), Low Power Mode awareness (polling intervals doubled in LPM), memory pressure handling (NSCache + GRDB eviction on system warning).
**Addresses:** PERF-03 (network dedup), PERF-06 (battery), PERF-02 (memory)
**Avoids:** Pitfall 3 (SSE streaming breakage -- GET-only dedup allowlist), Pitfall 7 (stale cache -- invalidation on writes)
**Files:** `APIClient.swift`, `PollingManager.swift`, new `RequestDeduplicator.swift`, new `MemoryPressureMonitor.swift`

### Phase 3: ViewModel and Model Optimization
**Rationale:** ViewModels compose services from Phase 2. Dashboard parallel loading depends on stable APIClient. ChatViewModel flush depends on stable SSEClient. ChatMessage Equatable conformance enables Phase 5 view optimization.
**Delivers:** Parallel dashboard loading (async let), ChatViewModel memory flush after SSE processing, ChatMessage Equatable conformance, pagination verification for Browser VMs.
**Addresses:** PERF-03 (batching), PERF-02 (memory), PERF-05 (chat rendering)
**Avoids:** Pitfall 4 (pagination races -- generation counter), Pitfall 5 (VM init side effects)
**Files:** `DashboardViewModel.swift`, `ChatViewModel.swift`, `ChatMessage.swift`, `SessionsViewModel.swift`, `MCPViewModel.swift`, `SkillsViewModel.swift`, `PluginsViewModel.swift`

### Phase 4: SSE and Background Lifecycle
**Rationale:** SSEClient is the most complex stateful service. Changes affect streaming, background suspension, and Low Power Mode. Isolating it ensures chat still works before touching the app entry point.
**Delivers:** SSE suspend/resume for background lifecycle, watchdog interval scaling for LPM, processed message flushing, MetricsWebSocket background disconnect.
**Addresses:** PERF-06 (battery -- stop network in background), PERF-02 (memory -- flush stream buffers)
**Avoids:** Pitfall 3 (SSE breakage -- careful state machine modifications), Pitfall 12 (scenePhase handling bugs)
**Files:** `SSEClient.swift`, `ILSAppApp.swift` (extend scenePhase), `MetricsWebSocketClient.swift`

### Phase 5: View Layer Optimization
**Rationale:** Views are the highest-risk layer (auto-build hook fires on every edit, visual regressions possible). Do these after all service/VM changes are stable. Each edit triggers a build cycle, so batch related changes.
**Delivers:** Equatable-based diffing in ChatMessageList, virtual window for 200+ messages, loadMore wiring in SidebarView, animation gating for Low Power Mode in theme components.
**Addresses:** PERF-04 (60fps scrolling), PERF-05 (chat rendering), PERF-06 (animation battery drain)
**Avoids:** Pitfall 2 (LazyVStack/List contract -- keep LazyVStack for chat), Pitfall 6 (ThemeSnapshot re-renders -- keep struct, use .animation with value:), Pitfall 10 (ForEach identity churn -- UUID-based id only)
**Files:** `SidebarView.swift`, `ChatMessageList.swift`, `CyberpunkEffects.swift`, `ShimmerModifier.swift`, `StreamingIndicatorView.swift`

### Phase 6: Cross-Platform Verification
**Rationale:** Every optimization must compile and function on macOS 14+. The auto-build hook only checks the edited target; macOS needs explicit verification. This phase also validates all 15 v1.0 REQs still pass.
**Delivers:** Confirmed iOS + macOS builds. Full v1.0 REQ re-validation. Platform-specific guards where needed.
**Addresses:** Backward compatibility constraint, Pitfall 8 (cross-platform build breaks)
**Avoids:** Pitfall 8 (iOS-only APIs in shared code)

### Phase 7: Regression Test Infrastructure
**Rationale:** Build this LAST so baselines capture the optimized state. Building it first would produce targets that cannot yet be met.
**Delivers:** XCTest performance test target with XCTApplicationLaunchMetric, XCTMemoryMetric, XCTCPUMetric baselines. MetricKit integration for production field metrics. OSSignposter annotations at key boundaries.
**Addresses:** PERF-07 (regression prevention)
**Avoids:** Pitfall 11 (simulator measurement unreliability -- use relative comparisons; device for absolute gates)

### Phase Ordering Rationale

- **Dependencies flow downward**: Services (Phase 2) before ViewModels (Phase 3) before Views (Phase 5). Each layer depends on the one below being stable.
- **Risk isolation**: SSEClient (Phase 4) is the highest-risk single component. Isolating it between VM and View work prevents cascading failures.
- **Profiling bookends the work**: Baseline measurement (Phase 1) proves the starting point; regression tests (Phase 7) lock in the ending point.
- **Cross-platform check (Phase 6) gates the view layer**: Catching macOS build breaks before regression test authoring prevents wasted test effort.
- **Launch fix first for morale**: The 2.2s delay removal is a one-line fix with the biggest user-visible impact. Shipping it immediately proves the milestone is delivering value.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4 (SSE and Background Lifecycle):** SSEClient's state machine is complex. The suspend/resume logic needs careful design to avoid duplicate messages or missed reconnections. Research the exact `scenePhase` transition timing bugs documented by Jesse Squires.
- **Phase 5 (View Layer -- ChatMessageList virtual window):** Message windowing in a LazyVStack with streaming content and scroll-to-bottom behavior is non-trivial. May need to prototype and measure before committing to an approach.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Launch Fix):** The fix is literally removing one line of code. No research needed.
- **Phase 2 (Service Layer):** Actor-based dedup, NSCache limits, ProcessInfo observers are all well-documented patterns with official Apple sample code.
- **Phase 3 (ViewModel):** `async let` parallelism and Equatable conformance are standard Swift patterns.
- **Phase 7 (Regression Tests):** XCTest metrics API is stable and well-documented since Xcode 11.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Zero new dependencies needed; all APIs are built-in Apple SDK. Confirmed by codebase inspection and official Apple documentation. |
| Features | HIGH | Feature priorities derived from measured codebase state (2.2s delay confirmed at exact line number, 22K sessions confirmed, LazyVStack confirmed). Airbnb production case study validates Equatable approach. |
| Architecture | HIGH | Every integration point verified against actual source code. File paths, line numbers, and method signatures confirmed by direct inspection. Component graph is accurate. |
| Pitfalls | HIGH | Cross-referenced Apple WWDC content, community post-mortems (Airbnb, Jesse Squires), Swift Forums async semantics discussions, and direct code review. All 15 pitfalls grounded in specific ILS code paths. |

**Overall confidence:** HIGH

### Gaps to Address

- **Actual Instruments profiling data is absent.** Research identifies the 2.2s delay and architectural patterns but has not run Time Profiler. Phase 1 MUST produce real measurements before Phase 2 begins. The remaining bottleneck after removing the delay is unknown -- it could be GRDB init, theme construction, or something else entirely.
- **Scroll hitch severity is unmeasured.** PERF-04 (60fps) assumes jank exists in the session list and chat, but no hitch rate has been measured. If scroll performance is already acceptable, the LazyVStack/List decision and Equatable work can be deprioritized.
- **Battery impact rating methodology.** PERF-06 targets "Low" in iOS Energy Organizer, but this requires sustained real-device usage over 24+ hours. The optimization work (LPM, background suspension, animation gating) is correct regardless, but validating the "Low" rating requires a dedicated device test.
- **Backend pagination for Browser VMs.** The architecture research flags that SkillsViewModel, MCPViewModel, and PluginsViewModel may load all items at once. Whether the Vapor backend supports `?page=&limit=` on those endpoints needs verification during Phase 3 planning.

## Sources

### Primary (HIGH confidence)
- Apple Developer: [Understanding and Improving SwiftUI Performance](https://developer.apple.com/documentation/Xcode/understanding-and-improving-swiftui-performance)
- Apple WWDC25: [Optimize SwiftUI Performance with Instruments (Session 306)](https://developer.apple.com/videos/play/wwdc2025/306/)
- Apple WWDC25: [Explore Concurrency in SwiftUI (Session 266)](https://developer.apple.com/videos/play/wwdc2025/266/)
- Apple WWDC22: [Link Fast: Improve Build and Launch Times](https://developer.apple.com/videos/play/wwdc2022/110362/)
- Apple WWDC23: [Analyze Hangs with Instruments (Session 10248)](https://developer.apple.com/videos/play/wwdc2023/10248/)
- Apple Developer Documentation: XCTMemoryMetric, XCTClockMetric, XCTApplicationLaunchMetric, NSCache, ProcessInfo.isLowPowerModeEnabled
- Apple Energy Efficiency Guide: [Low Power Mode](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/LowPowerMode.html), [Defer Networking](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/DeferNetworking.html)
- Direct codebase inspection: 20+ source files analyzed (ILSAppApp.swift, APIClient.swift, CacheService.swift, SSEClient.swift, ChatMessageList.swift, SessionsViewModel.swift, PollingManager.swift, and others)

### Secondary (MEDIUM confidence)
- Airbnb Engineering: [Understanding and Improving SwiftUI Performance](https://airbnb.tech/uncategorized/understanding-and-improving-swiftui-performance/) -- production case study, 15% scroll hitch reduction
- fatbobman: [List or LazyVStack](https://fatbobman.com/en/posts/list-or-lazyvstack/), [Memory Usage Optimization](https://fatbobman.com/en/posts/memory-usage-optimization/)
- Jesse Squires: [@Observable pitfalls](https://www.jessesquires.com/blog/2024/09/09/swift-observable-macro/), [ScenePhase issues](https://www.jessesquires.com/blog/2024/06/29/swiftui-scene-phase/)
- Swift Forums: [Surprising semantics of throttled sequences](https://forums.swift.org/t/surprising-semantics-of-throttled-sequences/65409)
- SwiftLee: [App Launch Time Optimization](https://www.avanderlee.com/optimization/launch-time-performance-optimization/), [Observable Macro Performance](https://www.avanderlee.com/swiftui/observable-macro-performance-increase-observableobject/)
- Jacob's Tech Tavern: [SwiftUI Scroll Performance: The 120fps Challenge](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps)
- GetStream.io: [Build Message List in SwiftUI](https://getstream.io/blog/build-message-list-swiftui/) -- production chat SDK case study

### Tertiary (LOW confidence)
- Medium: [Cut iOS App Launch Time by 50% in 2025](https://medium.com/@vrxrszsb/cut-ios-app-launch-time-by-50-in-2025-advanced-strategies-with-xcode-16-static-linking-and-bfb8997af3d0) -- unverified claims about @StaticDependency; needs validation

---
*Research completed: 2026-02-22*
*Ready for roadmap: yes*
