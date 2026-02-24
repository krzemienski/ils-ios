# Requirements: ILS iOS/macOS v1.5

**Defined:** 2026-02-24
**Core Value:** Ship-ready code quality — every audit finding resolved, tests reliable and meaningful, Swift 6 concurrency on a clear migration path

## v1.5 Requirements

Requirements for v1.5 milestone. Each maps to roadmap phases starting at Phase 25. Source: `scratch/audit-findings-2026-02-24.md` (70 issues from 16 parallel agents, 10 already fixed in commit c57690f).

### Testing

- [ ] **TEST-01**: All sleep()/Thread.sleep() calls in tests replaced with condition-based waiting (XCTNSPredicateExpectation or poll loops)
- [ ] **TEST-02**: ErrorHandlingTests sleep instances (5 sites) replaced with async expectations
- [ ] **TEST-03**: FeatureGateTests sleep instances (5 sites) replaced with async expectations
- [ ] **TEST-04**: Scenario03_StreamingAndCancellation sleep instances (6 sites) replaced with async expectations
- [ ] **TEST-05**: UI test startup time reduced (shared XCUIApplication or test grouping to avoid 15-45s per test)
- [ ] **TEST-06**: ILSBackendTests placeholder replaced with meaningful Swift Testing tests
- [ ] **TEST-07**: ILSSharedTests placeholder replaced with meaningful Swift Testing tests
- [ ] **TEST-08**: Swift Testing framework adopted for new test files (`import Testing`, `@Test`, `#expect`)
- [ ] **TEST-09**: NavigationTests.swift instance var `app` moved to setUp
- [ ] **TEST-10**: Test data factories/builders created for common test objects
- [ ] **TEST-11**: Test parallelization configured in test plan

### Concurrency

- [x] **CONC-01**: TeamsExecutorService non-Sendable Process in Task.detached resolved (H-C1)
- [x] **CONC-02**: WebSocketService ws.onText Task uses [weak self] or Sendable capture (H-C2)
- [ ] **CONC-03**: ProjectsViewModel unnecessary Task.detached replaced (MED-03)
- [ ] **CONC-04**: SpotlightIndexer completion handler converted to async/await (MED-04)
- [ ] **CONC-05**: PollingManager unowned reference design reviewed and documented (MED-01)
- [ ] **CONC-06**: SubscriptionManager.init Tasks deferred until after full initialization (MED-06)
- [x] **CONC-07**: SystemMetricsService continuation double-resume risk eliminated (MED-07)
- [ ] **CONC-08**: NotificationManager.checkAuthorizationStatus capture fixed (MED-05)
- [ ] **CONC-09**: TunnelService terminationHandler capture uses [weak self] (MMED-01)
- [x] **CONC-10**: ClaudeExecutorService.useAgentSDK mutable static resolved (Swift 6 blocker) (MMED-02)
- [ ] **CONC-11**: sendPermissionResponse isolation verified (MMED-03)
- [ ] **CONC-12**: LowPowerModeMonitor nonisolated(unsafe) replaced (MMED-04)
- [ ] **CONC-13**: AppLogger.recentLogs Task.detached pattern corrected (MED-08)
- [ ] **CONC-14**: DashboardViewModel.loadAll informational pattern documented (MED-02)
- [ ] **CONC-15**: @unchecked Sendable extensions for Vapor reviewed (LOW-C1)
- [ ] **CONC-16**: IndexingService Sendable conformance compiler-verified (LOW-C2)
- [ ] **CONC-17**: PollingManager @Observable intentional omission documented (LOW-C3)

### Energy

- [ ] **ENRG-01**: ConnectionBanner .ultraThinMaterial over streaming content optimized (H-E3)
- [ ] **ENRG-02**: SSEClient allowsConstrainedNetworkAccess properly configured (H-E4)
- [ ] **ENRG-03**: Fleet health polling adds LPM interval doubling (MED-E1)
- [ ] **ENRG-04**: AppLogger flush timer increased to 10s (MED-E2)
- [ ] **ENRG-05**: GlowEffect double-shadow GPU passes reduced (MED-E3)
- [ ] **ENRG-06**: macOS WindowManager UserDefaults throttled (MED-E4)
- [ ] **ENRG-07**: AppLogger synchronous disk write path addressed (LOW-E1)
- [ ] **ENRG-08**: SyncCoordinator debounce increased to 500ms (LOW-E2)

### Memory

- [ ] **MEM-01**: PollingManager unowned reference crash risk resolved (H-M2)
- [ ] **MEM-02**: NSWindow delegate cycle in WindowManager broken (MED-M1)
- [ ] **MEM-03**: NotificationManager UNUserNotificationCenter delegate lifecycle (MED-M2)
- [ ] **MEM-04**: SyncCoordinator observer singleton cleanup (MED-M3)
- [ ] **MEM-05**: SSEClient observer removal in cleanup() (MED-M4)
- [ ] **MEM-06**: TeamsExecutorService NSTask held 5s post-termination (LOW-M1)
- [ ] **MEM-07**: DispatchWorkItem timeout NSTask/Pipe 300s without cancel (LOW-M2)
- [ ] **MEM-08**: AppLogger flush timer false positive documented (LOW-M3)

### SwiftUI Performance

- [ ] **UIPERF-01**: TunnelSettingsView CIFilter QR generation verified off-thread (H-SP2)
- [ ] **UIPERF-02**: MacSessionsListView local computed filter cached (MED-SP1)
- [ ] **UIPERF-03**: MacProjectsListView local computed filter cached (MED-SP2)
- [ ] **UIPERF-04**: ToolCallAccordion repeated .contains() per tick replaced (MED-SP3)
- [ ] **UIPERF-05**: BrowserView non-lazy VStack converted to lazy (MED-SP4)
- [ ] **UIPERF-06**: Duplicate formatModelName() uses shared ClaudeModel.displayName (LOW-SP1)

### Swift 6 Preparation

- [x] **SWIFT6-01**: ClaudeExecutorService.useAgentSDK mutable static var resolved for strict concurrency
- [x] **SWIFT6-02**: TeamsExecutorService.shutdownTeammate non-Sendable Process crossing resolved
- [ ] **SWIFT6-03**: Build verified with -strict-concurrency=targeted (no new errors introduced)

## Future Requirements

### Deferred from v2.0

- **PERF-02**: Memory usage stays under 100MB for typical sessions
- **PERF-06**: Battery impact rated "Low" by iOS Energy Organizer

## Out of Scope

| Feature | Reason |
|---------|--------|
| New feature development | Code health only — no new capabilities |
| App Store submission | Separate milestone after quality gate |
| Full Swift 6 strict mode | Target `targeted` level, not `complete` |
| UI/UX redesign | No visual changes — internal code quality |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CONC-01 | 25 | Planned |
| CONC-02 | 25 | Planned |
| CONC-07 | 25 | Planned |
| CONC-10 | 25 | Planned |
| SWIFT6-01 | 25, 31 | Planned |
| SWIFT6-02 | 25, 31 | Planned |
| CONC-03 | 26 | Planned |
| CONC-04 | 26 | Planned |
| CONC-05 | 26 | Planned |
| CONC-06 | 26 | Planned |
| CONC-08 | 26 | Planned |
| CONC-09 | 26 | Planned |
| CONC-11 | 26 | Planned |
| CONC-12 | 26 | Planned |
| CONC-13 | 26 | Planned |
| CONC-14 | 26 | Planned |
| CONC-15 | 26 | Planned |
| CONC-16 | 26 | Planned |
| CONC-17 | 26 | Planned |
| ENRG-01 | 27 | Planned |
| ENRG-02 | 27 | Planned |
| ENRG-03 | 27 | Planned |
| ENRG-04 | 27 | Planned |
| ENRG-05 | 27 | Planned |
| ENRG-06 | 27 | Planned |
| ENRG-07 | 27 | Planned |
| ENRG-08 | 27 | Planned |
| MEM-01 | 27 | Planned |
| MEM-02 | 27 | Planned |
| MEM-03 | 27 | Planned |
| MEM-04 | 27 | Planned |
| MEM-05 | 27 | Planned |
| MEM-06 | 27 | Planned |
| MEM-07 | 27 | Planned |
| MEM-08 | 27 | Planned |
| UIPERF-01 | 28 | Planned |
| UIPERF-02 | 28 | Planned |
| UIPERF-03 | 28 | Planned |
| UIPERF-04 | 28 | Planned |
| UIPERF-05 | 28 | Planned |
| UIPERF-06 | 28 | Planned |
| TEST-01 | 29 | Planned |
| TEST-02 | 29 | Planned |
| TEST-03 | 29 | Planned |
| TEST-04 | 29 | Planned |
| TEST-05 | 30 | Planned |
| TEST-06 | 30 | Planned |
| TEST-07 | 30 | Planned |
| TEST-08 | 30 | Planned |
| TEST-09 | 30 | Planned |
| TEST-10 | 30 | Planned |
| TEST-11 | 30 | Planned |
| SWIFT6-03 | 31 | Planned |

**Coverage:**
- v1.5 requirements: 50 total (+ 2 shared: SWIFT6-01/02 in Phase 25 and 31)
- Mapped to phases: 50/50 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-02-24*
*Last updated: 2026-02-24 — all requirements mapped to phases 25-32*
