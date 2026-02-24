# Feature Landscape: SwiftUI Performance Optimization

**Domain:** Performance optimization for a production SwiftUI iOS/macOS app (ILS — Intelligent Local Server)
**Researched:** 2026-02-22
**Confidence:** HIGH (Apple official docs, Airbnb production case study, WWDC25 guidance, codebase analysis)

---

## Table Stakes

Features users expect in a "fast" native app. Missing any of these and the app noticeably underperforms Electron competitors — which defeats the entire purpose of this milestone.

| Feature | Why Expected | Complexity | Dependencies on ILS Codebase |
|---------|--------------|------------|------------------------------|
| Remove artificial launch delay | 2.2-second hardcoded `Task.sleep` at line 52 of `ILSAppApp.swift` destroys the cold-start story; users expect native apps to launch instantly | Low | `ILSAppApp.swift` — one line removal + launch screen dismissal condition change |
| Pagination-backed session list | 22K+ sessions exist; LazyVStack in `SidebarView` renders grouped sessions — without server-side pagination, the sidebar load is a memory/time bomb | Medium | `SidebarView.swift` + `SessionsViewModel.swift` — pagination exists on the VM, but sidebar grouping fetches full list per project group |
| Message list virtualization for large histories | Chat with 200+ messages; `ChatMessageList` already uses `LazyVStack` but lacks message count-based windowing — long sessions accumulate unbounded memory | Medium | `ChatMessageList.swift` — LazyVStack already in place; needs message windowing strategy |
| In-memory cache TTL enforcement | `APIClient.swift` has `NSCache<NSString, CacheEntryObject>` with per-endpoint TTLs (15s for sessions, 5min for skills) — correct structure, but no `totalCostLimit` means unbounded growth | Low | `APIClient.swift` lines 9–51 — add `totalCostLimit` and `countLimit` (already set to 100, but no cost-based eviction) |
| Animation pause in background | Shimmer, streaming indicator, and connection banner animations run even when app is backgrounded; `scenePhase` exists in `ILSAppApp.swift` but animation pausing is not wired to it | Low | `ShimmerModifier.swift`, `StreamingIndicatorView.swift`, `ConnectionBanner.swift` — check `scenePhase` handling |
| Low Power Mode animation throttle | `ProcessInfo.processInfo.isLowPowerModeEnabled` check is absent; shimmer and pulsing animations drain battery in Low Power Mode | Low | Same animation files — add `ProcessInfo` observer alongside existing `reduceMotion` checks |
| View body decomposition (Equatable diffing) | Large view bodies (e.g., `HomeView.swift` at 475 lines, `NewSessionView.swift` at 910 lines) re-evaluate all children on any state change — SwiftUI's reflection-based diffing hits every property | High | `HomeView.swift`, `NewSessionView.swift`, `SidebarView.swift` — break into smaller View structs with stable identity |
| 60fps scroll target for List views | Browser tabs (skills 3015 entries, plugins 84, MCP 20) and sidebar session list; standard SwiftUI `List` outperforms `LazyVStack` for dynamic-height rows per iOS 18 benchmarks | Medium | `SidebarView.swift` uses `LazyVStack` inside `ScrollView` — candidate for `List` migration |

---

## Differentiators

Features that visibly separate ILS from other Claude Code clients and create a "this app is fast" impression.

| Feature | Value Proposition | Complexity | Dependencies on ILS Codebase |
|---------|-------------------|------------|------------------------------|
| Profiling-driven baseline report | Run Instruments (Time Profiler + Hangs/Hitches + SwiftUI template) before any change; publish before/after numbers. Most teams skip this — having real data makes optimization credible and prevents "felt faster" placebo claims | Medium | Requires device + Instruments session; WWDC25 introduced new SwiftUI instrument in Xcode 26 |
| Request deduplication in `APIClient` | Multiple views calling the same endpoint simultaneously (sessions, stats, skills) during launch; deduplicate via in-flight task registry (Swift `async` task with `await` on existing task) | Medium | `APIClient.swift` — actor-isolated, ideal insertion point; add `[String: Task<Any, Error>]` in-flight tracker |
| Syntax highlighting off-main-thread | `CodeBlockView.swift` / `MarkdownTextView.swift` — syntax parsing is CPU-intensive; move to background `Task` and cache result by content hash | High | `CodeBlockView.swift` — determine current library (Highlightr or native); wrap in background Task, publish attributed string via `@State` |
| Background prefetch on session open | When user taps a session in the sidebar, prefetch its message history in the background before `ChatView` is pushed; eliminates loading state for most recent chats | Medium | `SidebarView.swift` `onSessionSelected` callback + `CacheService.swift` — cache message fetch triggered before navigation |
| XCTest regression test infrastructure | `XCTApplicationLaunchMetric`, `XCTMemoryMetric`, `XCTCPUMetric` baselines committed to repo; CI fails if launch > 1s or memory > 100MB | High | New `ILSAppPerformanceTests` target; requires real device (simulator metrics are unreliable for launch time) |
| Instruments signpost annotations | `os_signpost` markers at key boundaries (session load start/end, message render, cache hit/miss) give future developers free profiling integration points | Low | `CacheService.swift`, `SessionsViewModel.swift`, `APIClient.swift` — add `os_signpost` calls |
| `@Sendable` closure audit + actor isolation | Swift 6 strict concurrency — eliminate `@MainActor`-hopping in view models that currently bridge between actor contexts unnecessarily, causing extra queue hops during data loading | Medium | `SessionsViewModel.swift`, `ChatViewModel.swift`, all `@Observable @MainActor` VMs |

---

## Anti-Features

Features to explicitly avoid. Each one has been proposed in generic performance guides but is wrong for this specific project.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Static linking all SPM packages | ILS uses Vapor backend (SPM), ILSShared, and TipKit — static-linking all dylibs gives 35% launch benefit for apps with 50+ dylibs, but ILS has very few external dependencies; the engineering cost outweighs 20–50ms gain | Profile actual dylib count with `DYLD_PRINT_LIBRARIES` first; only pursue if dylib count > 15 |
| Replacing `List` with `UICollectionView` UIViewRepresentable | `List` is UICollectionView-backed since iOS 16 — a custom wrapper duplicates Apple's work and creates a long-term maintenance burden | Use `List` directly where `LazyVStack` underperforms; customize via `listRowBackground`, `listStyle` |
| Image asset lazy loading system | ILS is a data/text app — there are no remote images to load; building an image caching pipeline (Kingfisher, Nuke) would be pure overhead | Skip entirely; `AsyncImage` is fine for the rare SF Symbol-based avatar placeholder |
| GraphQL or batched JSON multi-query endpoint | Backend is Vapor + SQLite, fast for reads; adding GraphQL to batch queries introduces new schema maintenance, resolver complexity, and a new SPM dependency | Use Swift `async let` to fire parallel URLSession requests instead; achieves batching without protocol change |
| Server-Side Rendering / WebView chat renderer | Using WKWebView for markdown/syntax highlighting (common iOS pattern) loses native scroll performance, accessibility, Dynamic Type, and theming integration | Optimize native `MarkdownTextView` and `CodeBlockView` instead |
| Core Data migration | App already has `LocalDatabase.swift` (SQLite via CacheService); migrating to Core Data adds NSManagedObjectContext complexity with no performance benefit for this read-heavy, cache-invalidation-simple use case | Optimize existing SQLite queries and add indexes if needed |
| Global `equatable()` modifier on all views | Adding `.equatable()` to reference-type `@Observable` views causes SwiftUI to compare object identity, making views freeze at initial state (documented Airbnb anti-pattern) | Apply `Equatable` conformance only to value-type view structs with closure properties; audit each case |
| Disabling animations entirely for performance | Users' `reduceMotion` preference already exists; killing all animations degrades the polished feel that differentiates native from Electron | Throttle, pause when backgrounded, and honor system preferences — never unconditionally disable |

---

## Feature Dependencies

```
Remove launch delay → Profiling baseline (must have real launch time to validate)
Profiling baseline → All other optimizations (baseline required to measure improvement)

Request deduplication → In-flight task registry in APIClient (no new dependencies)
In-flight task registry → Background prefetch (prefetch reuses deduplicated request)

View body decomposition → Equatable diffing audit (decomposition creates testable boundaries)
Equatable diffing audit → XCTest regression infra (regression tests validate diffing correctness)

Pagination enforcement → Memory limit (pagination is required to stay under 100MB with 22K sessions)
NSCache cost limits → Memory limit (cache eviction prevents unbounded growth)

Syntax highlighting off-main-thread → Background prefetch (shares Task + cache patterns)

XCTest regression infra → All PERF-0x requirements (tests validate the claims)
```

---

## MVP Recommendation

Prioritize these in this exact order for maximum ROI:

1. **Remove artificial launch delay** — one line of code, biggest single user-visible impact (2.2s → ~0.3s cold start immediately)
2. **Profiling baseline** — run Instruments before any further change to establish real numbers; prevents wasted effort on non-bottlenecks
3. **NSCache cost limits** — add `totalCostLimit` to `APIClient.cache`; prevents memory growth during long sessions with minimal code change
4. **Animation pause (background + Low Power Mode)** — 5 files, small changes, directly addresses PERF-06 battery rating
5. **View body decomposition** — `NewSessionView.swift` at 910 lines and `HomeView.swift` at 475 lines are the highest-risk for unnecessary re-renders; decompose into stable child View structs
6. **Request deduplication** — parallel launch requests currently hit the same endpoints; in-flight task registry in `APIClient` actor is the right insertion point
7. **Syntax highlighting off-main-thread** — `CodeBlockView` / `MarkdownTextView` are blocking the main thread during message render; move to background Task
8. **XCTest regression infrastructure** — install `XCTApplicationLaunchMetric` + `XCTMemoryMetric` baselines so future contributors cannot regress perf silently

Defer:
- **Static linking audit** — only worth doing if Instruments shows dylib load time > 200ms; measure first
- **`List` vs `LazyVStack` migration** — iOS 18 parity is close; measure actual scroll hitches with Instruments before migrating; migration is low-risk but requires visual regression check on all list screens

---

## Complexity Reference

| Feature | Complexity | Rationale |
|---------|------------|-----------|
| Remove launch delay | Low | 1 line + condition logic change |
| NSCache cost limits | Low | 2–3 lines in `APIClient.swift` |
| Animation pause (background/LPM) | Low | Add `scenePhase`/`ProcessInfo` check to 3–4 files |
| OS Signpost annotations | Low | Additive, no behavior change |
| Profiling baseline | Medium | Requires Instruments session, device, data interpretation |
| Request deduplication | Medium | New in-flight task dictionary in actor-isolated `APIClient` |
| Background prefetch | Medium | Coordinate `SidebarView` → `CacheService` before navigation |
| List vs LazyVStack migration | Medium | Functional equivalent but needs visual regression evidence |
| View body decomposition | High | 3 large views (910, 475 lines); careful struct extraction to preserve @Binding chains |
| Syntax highlighting off-main-thread | High | Library-specific; attributed string caching; async publish pattern |
| XCTest regression infra | High | New test target, CI integration, device required for accurate metrics |

---

## Sources

- [Apple WWDC25: Optimize SwiftUI performance with Instruments](https://developer.apple.com/videos/play/wwdc2025/306/) — HIGH confidence (official)
- [Apple WWDC22: Link fast: Improve build and launch times](https://developer.apple.com/videos/play/wwdc2022/110362/) — HIGH confidence (official)
- [Airbnb Engineering: Understanding and Improving SwiftUI Performance](https://airbnb.tech/uncategorized/understanding-and-improving-swiftui-performance/) — HIGH confidence (production case study, measured 15% scroll hitch reduction)
- [SwiftUI Scroll Performance: The 120FPS Challenge](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps) — MEDIUM confidence (independent benchmark, iOS 18 List vs LazyVStack)
- [Apple NSCache Documentation](https://developer.apple.com/documentation/foundation/nscache) — HIGH confidence (official)
- [SwiftUI List Performance: Smooth Scrolling for 10,000+ Items](https://medium.com/@chandra.welim/swiftui-list-performance-smooth-scrolling-for-10-000-items-c64116dc276f) — MEDIUM confidence (WebSearch, December 2025)
- [GetStream.io: How Our iOS Team Built the SwiftUI SDK Message List](https://getstream.io/blog/build-message-list-swiftui/) — MEDIUM confidence (production chat SDK case study)
- [Cut iOS App Launch Time by 50% in 2025](https://medium.com/@vrxrszsb/cut-ios-app-launch-time-by-50-in-2025-advanced-strategies-with-xcode-16-static-linking-and-bfb8997af3d0) — LOW confidence (WebSearch, unverified claims about @StaticDependency)
- [XCTest Performance Tests Documentation](https://developer.apple.com/documentation/xctest/performance-tests) — HIGH confidence (official)
- [iOS Memory Management & Performance Optimization: Complete Guide 2025](https://www.alimertgulec.com/en/blog/ios-memory-management-performance-2025) — MEDIUM confidence (WebSearch, 2025)
- [Battery Consumption in iOS Apps](https://medium.com/@chandra.welim/battery-consumption-in-ios-apps-what-drains-battery-and-how-to-fix-it-72693e19de22) — MEDIUM confidence (January 2026)
- [Apple Energy Efficiency Guide: Low Power Mode](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/LowPowerMode.html) — HIGH confidence (official)
- Codebase analysis: `ILSAppApp.swift`, `APIClient.swift`, `CacheService.swift`, `ChatMessageList.swift`, `SidebarView.swift`, `SessionsViewModel.swift` — HIGH confidence (direct source inspection)
