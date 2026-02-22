# Roadmap -- ILS iOS/macOS

## Milestones

- **v1.0 Cross-Platform Audit** - Phases 1-10 (shipped 2026-02-21)
- **v2.0 Performance Optimization Suite** - Phases 11-17 (in progress)

## Phases

<details>
<summary>v1.0 Cross-Platform Audit (Phases 1-10) -- SHIPPED 2026-02-21</summary>

### Phase 1: Discovery & Research -- COMPLETE
**Goal**: Complete codebase analysis, technical research, and UX spec research in parallel.
**Duration**: 11min | **Tasks**: 4/4 | **Files**: 4 created

### Phase 2: Navigation + Layout -- COMPLETE
**Goal**: Fix home sidebar, session navigation, quick actions ordering, sessions consistency.
**Duration**: 40min | **Tasks**: 6/6 | **Files**: 8 modified

### Phase 3: Settings & Config Inheritance -- COMPLETE
**Goal**: Trace config flow, build inheritance UI, fix 8 individual settings items.
**Duration**: ~3hrs | **Tasks**: 6/6 | **Files**: 3 modified + 32 evidence

### Phase 4: Skills, Plugins, Hooks & Theming -- COMPLETE
**Goal**: Fix MCP backend, skills data source, add status indicators, GitHub browse/install, hooks screen, themes.
**Duration**: ~90min | **Tasks**: 7/7 | **Files**: 9 modified + 1 created

### Phase 5: System Monitor + Profiles -- COMPLETE
**Goal**: Fix SSH pipeline for system monitor, replace Fleet with Host/Backend Profiles.

### Phase 6: Backend API Audit -- COMPLETE
**Goal**: Enumerate, verify, and fix all API endpoints.

### Phase 7: Convergence & Cross-Stream Regression -- COMPLETE
**Goal**: Full regression sweep across all streams.

### Phase 8: Full Platform Validation -- COMPLETE
**Goal**: Visual audit on all 4 platforms in parallel.

### Phase 9: Functional Audit + Bug Hunt -- COMPLETE
**Goal**: Complete functional verification and edge case testing.

### Phase 10: Final Gate -- COMPLETE
**Goal**: Complete final validation against all 20+ PASS criteria.
**Result**: 15/15 REQs PASS | 0 crashes | HIGH confidence

</details>

---

## v2.0 Performance Optimization Suite

**Milestone Goal:** Optimize all five performance dimensions (launch, memory, network, rendering, battery) to production-quality baselines with regression test infrastructure. Every optimization must preserve all 15 v1.0 audit REQs.

- [ ] **Phase 11: Launch & Baseline** - Remove artificial delay, defer non-critical init, establish Instruments baselines
- [ ] **Phase 12: Service Layer Optimization** - Request deduplication, cache cost limits, memory pressure handling
- [ ] **Phase 13: ViewModel & Model Optimization** - Parallel data loading, SSE buffer flush, chat message windowing
- [ ] **Phase 14: SSE & Background Lifecycle** - Low Power Mode polling, background suspend/resume for SSE and WebSocket
- [ ] **Phase 15: View Layer Rendering** - 60fps session scrolling, chat virtualization, off-thread syntax highlighting, animation gating
- [ ] **Phase 16: Cross-Platform Verification** - macOS compilation, full v1.0 REQ regression check
- [ ] **Phase 17: Regression Test Infrastructure** - XCTest performance baselines, MetricKit production metrics

## Phase Details

### Phase 11: Launch & Baseline
**Goal**: App cold-starts in under 1 second with non-critical initialization deferred to background
**Depends on**: Nothing (first phase of v2.0)
**Requirements**: LAUNCH-01, LAUNCH-02
**Success Criteria** (what must be TRUE):
  1. App shows interactive UI within 1 second of cold launch (measured via Instruments Time Profiler)
  2. TipKit, CacheService, and other non-critical services initialize after the first frame is visible
  3. Instruments baseline report exists documenting before/after launch time, memory allocation, and CPU profile
**Plans**: TBD

Plans:
- [ ] 11-01: TBD

---

### Phase 12: Service Layer Optimization
**Goal**: Network requests are deduplicated, caches are bounded, and the app handles memory pressure gracefully
**Depends on**: Phase 11 (baseline measurements inform priority)
**Requirements**: NET-01, NET-03, MEM-01
**Success Criteria** (what must be TRUE):
  1. Navigating rapidly between tabs does not fire duplicate GET requests for the same endpoint (visible in network log or Instruments)
  2. NSCache totalCostLimit is set and the app evicts cached data when receiving a memory warning
  3. App memory stays under 100MB during typical browsing of sessions, skills, and settings screens
**Plans**: TBD

Plans:
- [ ] 12-01: TBD

---

### Phase 13: ViewModel & Model Optimization
**Goal**: Dashboard loads in parallel, SSE buffers are flushed after processing, and chat messages use windowed display for large histories
**Depends on**: Phase 12 (ViewModels compose the deduplicated APIClient and bounded caches)
**Requirements**: NET-02, MEM-02, MEM-03
**Success Criteria** (what must be TRUE):
  1. Dashboard stats and recent activity load simultaneously (observable as faster dashboard render vs sequential)
  2. After sending messages in a long chat session, memory does not grow unboundedly (SSE buffer flushed after ChatViewModel processes each batch)
  3. Opening a chat with 200+ messages shows the most recent ~50 messages immediately, with older messages loadable on scroll-up
**Plans**: TBD

Plans:
- [ ] 13-01: TBD

---

### Phase 14: SSE & Background Lifecycle
**Goal**: Polling intervals adapt to Low Power Mode and all persistent connections suspend when the app enters background
**Depends on**: Phase 13 (SSEClient changes are high-risk and isolated; ViewModel flush must be stable first)
**Requirements**: BATT-01, BATT-02
**Success Criteria** (what must be TRUE):
  1. With Low Power Mode enabled, PollingManager and MetricsWebSocketClient poll at 2x their normal interval (e.g., 60s becomes 120s)
  2. When the app moves to background, SSE and WebSocket connections disconnect within 5 seconds
  3. When the app returns to foreground, SSE and WebSocket connections resume automatically and data is current
**Plans**: TBD

Plans:
- [ ] 14-01: TBD

---

### Phase 15: View Layer Rendering
**Goal**: Large lists scroll at 60fps, chat with 200+ messages renders without jank, and animations respect Low Power Mode
**Depends on**: Phase 14 (all service and ViewModel changes must be stable before touching views; auto-build hook fires on every .swift edit)
**Requirements**: RENDER-01, RENDER-02, RENDER-03, BATT-03
**Success Criteria** (what must be TRUE):
  1. Scrolling through 500+ sessions in the sessions list maintains 60fps with no visible hitches (measurable via Instruments SwiftUI instrument)
  2. Chat view with 200+ messages scrolls smoothly and scroll-to-bottom works without frame drops
  3. Code blocks with 100+ lines in chat render syntax highlighting without blocking the main thread (highlighting computed off-main-thread with cached results)
  4. CyberpunkEffects, ShimmerModifier, and StreamingIndicatorView animations are paused when Low Power Mode is active or the app is in background
**Plans**: TBD

Plans:
- [ ] 15-01: TBD

---

### Phase 16: Cross-Platform Verification
**Goal**: All optimizations compile and function correctly on macOS and all v1.0 audit REQs remain PASS
**Depends on**: Phase 15 (all code changes must be complete before verification sweep)
**Requirements**: COMPAT-01, COMPAT-02
**Success Criteria** (what must be TRUE):
  1. ILSMacApp scheme builds successfully on macOS 14+ with zero errors
  2. All 15 v1.0 audit REQs pass re-validation on iOS (sidebar navigation, settings inheritance, skills/plugins/hooks, system monitor, host profiles, quick actions, tooltips, themes, MCP servers, backend API, zero visual regressions, session consistency)
  3. Any iOS-only APIs used in optimization phases have macOS-appropriate guards or alternatives
**Plans**: TBD

Plans:
- [ ] 16-01: TBD

---

### Phase 17: Regression Test Infrastructure
**Goal**: XCTest performance baselines and MetricKit integration prevent future performance degradation
**Depends on**: Phase 16 (tests capture the verified, optimized state; building tests before optimization produces wrong baselines)
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04
**Success Criteria** (what must be TRUE):
  1. XCTest performance test target exists with a launch time baseline using XCTApplicationLaunchMetric that fails if launch exceeds 1.5 seconds
  2. XCTest memory baseline using XCTMemoryMetric captures typical session memory and fails if it exceeds 120MB
  3. XCTest CPU baseline using XCTCPUMetric captures scroll/render performance for the sessions list
  4. MetricKit subscriber is integrated and logs MXAppLaunchMetric, MXMemoryMetric payloads for production field analysis
**Plans**: TBD

Plans:
- [ ] 17-01: TBD

---

## Progress

**Execution Order:** Phase 11 -> 12 -> 13 -> 14 -> 15 -> 16 -> 17

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-10 | v1.0 | 10/10 | Complete | 2026-02-21 |
| 11. Launch & Baseline | v2.0 | 0/? | Not started | - |
| 12. Service Layer | v2.0 | 0/? | Not started | - |
| 13. ViewModel & Model | v2.0 | 0/? | Not started | - |
| 14. SSE & Background | v2.0 | 0/? | Not started | - |
| 15. View Layer Rendering | v2.0 | 0/? | Not started | - |
| 16. Cross-Platform Verify | v2.0 | 0/? | Not started | - |
| 17. Regression Tests | v2.0 | 0/? | Not started | - |
