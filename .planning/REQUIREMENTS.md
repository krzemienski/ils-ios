# Requirements — v2.0 Performance Optimization Suite

**Milestone:** v2.0 Performance Optimization Suite
**Created:** 2026-02-22
**Status:** Approved

---

## Launch Time

- [ ] **LAUNCH-01**: App cold-starts in under 1 second (remove 2.2s artificial delay, content-driven launch dismiss)
- [ ] **LAUNCH-02**: Non-critical initialization (TipKit, CacheService) deferred to background after UI visible

## Memory

- [ ] **MEM-01**: App memory stays under 100MB during typical sessions (cache cost limits, memory pressure handling)
- [ ] **MEM-02**: SSEClient stream buffer flushed after ChatViewModel processes messages (prevents unbounded growth)
- [ ] **MEM-03**: Chat messages windowed to ~50 visible + on-demand expansion for 200+ message histories

## Network

- [ ] **NET-01**: Concurrent identical GET requests deduplicated via in-flight task registry in APIClient
- [ ] **NET-02**: DashboardViewModel loads stats and recent activity in parallel (async let)
- [ ] **NET-03**: NSCache `totalCostLimit` set to prevent unbounded memory growth

## Rendering

- [ ] **RENDER-01**: Sessions list (500+ items) scrolls at 60fps with LazyVStack + pagination
- [ ] **RENDER-02**: Chat with 200+ messages renders without jank (Equatable conformance on ChatMessage, virtual windowing)
- [ ] **RENDER-03**: Syntax highlighting for large code blocks runs off-main-thread with cached results

## Battery

- [ ] **BATT-01**: Polling intervals double in Low Power Mode (PollingManager, MetricsWebSocketClient)
- [ ] **BATT-02**: SSE and WebSocket connections suspended on app background, resumed on foreground
- [ ] **BATT-03**: Animations throttled/paused in Low Power Mode and background (CyberpunkEffects, ShimmerModifier)

## Regression Infrastructure

- [ ] **TEST-01**: XCTest performance baselines for launch time (XCTApplicationLaunchMetric)
- [ ] **TEST-02**: XCTest performance baselines for memory usage (XCTMemoryMetric)
- [ ] **TEST-03**: XCTest performance baselines for scroll/render (XCTCPUMetric)
- [ ] **TEST-04**: MetricKit integration for production field metrics

## Cross-Platform

- [ ] **COMPAT-01**: All optimizations compile and function on macOS 14+ (ILSMacApp target)
- [ ] **COMPAT-02**: All 15 v1.0 audit REQs remain PASS after optimization

---

## Future Requirements (deferred)

- Static linking audit (only if Instruments shows dylib load time > 200ms)
- List vs LazyVStack migration for sessions (measure scroll hitches first)
- Server-side full-text search for 22K sessions (server-side search already partially implemented)
- Background fetch framework (PollingManager + SyncCoordinator sufficient)

## Out of Scope

- New feature development beyond performance
- App Store submission (separate milestone)
- Android/web platform support
- Server-side performance optimization (Vapor backend already fast)
- UI redesign or architectural changes
- Third-party analytics SDK (MetricKit is sufficient)

---

## Traceability

| REQ | Phase | Status |
|-----|-------|--------|
| LAUNCH-01 | — | Pending |
| LAUNCH-02 | — | Pending |
| MEM-01 | — | Pending |
| MEM-02 | — | Pending |
| MEM-03 | — | Pending |
| NET-01 | — | Pending |
| NET-02 | — | Pending |
| NET-03 | — | Pending |
| RENDER-01 | — | Pending |
| RENDER-02 | — | Pending |
| RENDER-03 | — | Pending |
| BATT-01 | — | Pending |
| BATT-02 | — | Pending |
| BATT-03 | — | Pending |
| TEST-01 | — | Pending |
| TEST-02 | — | Pending |
| TEST-03 | — | Pending |
| TEST-04 | — | Pending |
| COMPAT-01 | — | Pending |
| COMPAT-02 | — | Pending |

---

*20 requirements | 6 categories | All approved 2026-02-22*
