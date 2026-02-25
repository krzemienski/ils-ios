# Requirements: ILS iOS/macOS v3.1

**Defined:** 2026-02-24
**Core Value:** Every screen works correctly, reflects the connected host's configuration, and provides a polished native experience

## v3.1 Requirements

Requirements for v3.1 milestone (Comprehensive Audit, Bug Fix & UX Overhaul). Each maps to roadmap phases starting at Phase 33. Source: `.planning/research/` (4 research files, 109KB, from 2026-02-24).

### Navigation & UX

- [x] **NAV-01**: Hamburger/side menu accessible from ALL screens — child views must not add conflicting `.topBarLeading` toolbar items
- [x] **NAV-02**: Chat session has a back button to return to sessions list — requires ActiveScreen push/pop instead of flat enum swap
- [x] **NAV-03**: Home screen layout polish — stats cards, quick actions ordering, consistent spacing
- [x] **NAV-04**: Sidebar shows active host name indicator below header
- [x] **NAV-05**: Deep link navigation works consistently across all registered `ils://` routes

### Host Profiles

- [ ] **HP-01**: Host activation propagates to `AppState.serverURL` — `HostProfilesViewModel` uses `AppState` injection, not standalone `APIClient()` (CRITICAL)
- [ ] **HP-02**: All ViewModels reload data on host switch — reactive invalidation via `AppState` observable change
- [ ] **HP-03**: Active profile indicator visible on list row and sidebar
- [ ] **HP-04**: Health status badges per host with colored dot
- [x] **HP-05**: Fleet → Host Profiles naming consistency in all UI strings and navigation

### Settings & Config Sync

- [ ] **CFG-01**: Display effective config values pulled from connected host CLI (`~/.claude/settings.json`)
- [ ] **CFG-02**: `InheritanceBadge` (Host Default / Custom) applied to ALL settings fields, not just model and two toggles
- [ ] **CFG-03**: Config auto-refresh on reconnect and host switch (`onChange(appState.isConnected)`)
- [ ] **CFG-04**: Explanatory tooltip (`SettingsInfoButton`) on every settings field — full coverage
- [ ] **CFG-05**: Write allowlist prevents CLI field deletion — `hooks`, `env`, `permissions`, `statusLine` never included in write payloads
- [ ] **CFG-06**: System prompt field displayed (read-only if inherited from host)
- [ ] **CFG-07**: Inline edit uses read-then-patch pattern — load fresh config, apply minimal delta, PUT back

### Browse, Skills & Plugins

- [ ] **BRW-01**: GitHub skill search returns results with name, description, stars, repo path
- [ ] **BRW-02**: Per-item install progress indicator (not global `isLoading` blocking entire list)
- [ ] **BRW-03**: Installed state badge on GitHub search result rows
- [ ] **BRW-04**: Plugin GitHub browse UI in Plugins tab (symmetry with skills tab)
- [ ] **BRW-05**: Enable/disable toggle inline on installed skill and plugin rows
- [ ] **BRW-06**: GitHub `fetchRawContent` branch detection — not hardcoded to `main`; try default branch
- [ ] **BRW-07**: Rate limit 429 shows actionable error: "GitHub limit reached. Set GITHUB_TOKEN on host."
- [ ] **BRW-08**: Uninstall from browse tab via context menu on installed items

### System Monitor & Themes

- [ ] **SYS-01**: System monitor displays real-time metrics from connected host
- [ ] **SYS-02**: Theme default loading works on fresh app launch
- [ ] **SYS-03**: Cross-platform theme consistency (iOS, iPadOS, macOS)

### Cross-Platform Validation

- [ ] **XP-01**: macOS builds with zero errors after all v3.1 changes
- [ ] **XP-02**: All v1.0 audit REQs (REQ-01 through REQ-15) remain PASS
- [ ] **XP-03**: iOS/iPadOS/macOS feature parity verified for all v3.1 changes

---

## v1.5 Requirements (COMPLETE)

<details>
<summary>v1.5 — All 50 requirements PASS (shipped 2026-02-24)</summary>

### v1.5 Requirements Detail

Requirements for v1.5 milestone. Each maps to roadmap phases starting at Phase 25. Source: `scratch/audit-findings-2026-02-24.md` (70 issues from 16 parallel agents, 10 already fixed in commit c57690f).

### Testing

- [x] **TEST-01**: All sleep()/Thread.sleep() calls in tests replaced with condition-based waiting (XCTNSPredicateExpectation or poll loops)
- [x] **TEST-02**: ErrorHandlingTests sleep instances (15 sites) replaced with condition-based waiting
- [x] **TEST-03**: FeatureGateTests sleep instances (10 sites) replaced with condition-based waiting
- [x] **TEST-04**: Scenario03_StreamingAndCancellation sleep instances (6 sites) replaced with async expectations
- [x] **TEST-05**: UI test startup time reduced (shared XCUIApplication or test grouping to avoid 15-45s per test)
- [x] **TEST-06**: ILSBackendTests placeholder replaced with meaningful Swift Testing tests
- [x] **TEST-07**: ILSSharedTests placeholder replaced with meaningful Swift Testing tests
- [x] **TEST-08**: Swift Testing framework adopted for new test files (`import Testing`, `@Test`, `#expect`)
- [x] **TEST-09**: NavigationTests.swift instance var `app` moved to setUp
- [x] **TEST-10**: Test data factories/builders created for common test objects
- [x] **TEST-11**: Test parallelization configured in test plan

### Concurrency

- [x] **CONC-01**: TeamsExecutorService non-Sendable Process in Task.detached resolved (H-C1)
- [x] **CONC-02**: WebSocketService ws.onText Task uses [weak self] or Sendable capture (H-C2)
- [x] **CONC-03**: ProjectsViewModel unnecessary Task.detached replaced (MED-03)
- [x] **CONC-04**: SpotlightIndexer completion handler converted to async/await (MED-04)
- [x] **CONC-05**: PollingManager unowned reference design reviewed and documented (MED-01)
- [x] **CONC-06**: SubscriptionManager.init Tasks deferred until after full initialization (MED-06)
- [x] **CONC-07**: SystemMetricsService continuation double-resume risk eliminated (MED-07)
- [x] **CONC-08**: NotificationManager.checkAuthorizationStatus capture fixed (MED-05)
- [x] **CONC-09**: TunnelService terminationHandler capture uses [weak self] (MMED-01)
- [x] **CONC-10**: ClaudeExecutorService.useAgentSDK mutable static resolved (Swift 6 blocker) (MMED-02)
- [x] **CONC-11**: sendPermissionResponse isolation verified (MMED-03)
- [x] **CONC-12**: LowPowerModeMonitor nonisolated(unsafe) replaced (MMED-04)
- [x] **CONC-13**: AppLogger.recentLogs Task.detached pattern corrected (MED-08)
- [x] **CONC-14**: DashboardViewModel.loadAll informational pattern documented (MED-02)
- [x] **CONC-15**: @unchecked Sendable extensions for Vapor reviewed (LOW-C1)
- [x] **CONC-16**: IndexingService Sendable conformance compiler-verified (LOW-C2)
- [x] **CONC-17**: PollingManager @Observable intentional omission documented (LOW-C3)

### Energy

- [x] **ENRG-01**: ConnectionBanner .ultraThinMaterial over streaming content optimized (H-E3)
- [x] **ENRG-02**: SSEClient allowsConstrainedNetworkAccess properly configured (H-E4)
- [x] **ENRG-03**: Fleet health polling adds LPM interval doubling (MED-E1)
- [x] **ENRG-04**: AppLogger flush timer increased to 10s (MED-E2)
- [x] **ENRG-05**: GlowEffect double-shadow GPU passes reduced (MED-E3)
- [x] **ENRG-06**: macOS WindowManager UserDefaults throttled (MED-E4)
- [x] **ENRG-07**: AppLogger synchronous disk write path addressed (LOW-E1)
- [x] **ENRG-08**: SyncCoordinator debounce increased to 500ms (LOW-E2)

### Memory

- [x] **MEM-01**: PollingManager unowned reference crash risk resolved (H-M2)
- [x] **MEM-02**: NSWindow delegate cycle in WindowManager broken (MED-M1)
- [x] **MEM-03**: NotificationManager UNUserNotificationCenter delegate lifecycle (MED-M2)
- [x] **MEM-04**: SyncCoordinator observer singleton cleanup (MED-M3)
- [x] **MEM-05**: SSEClient observer removal in cleanup() (MED-M4)
- [x] **MEM-06**: TeamsExecutorService NSTask held 5s post-termination (LOW-M1)
- [x] **MEM-07**: DispatchWorkItem timeout NSTask/Pipe 300s without cancel (LOW-M2)
- [x] **MEM-08**: AppLogger flush timer false positive documented (LOW-M3)

### SwiftUI Performance

- [x] **UIPERF-01**: TunnelSettingsView CIFilter QR generation verified off-thread (H-SP2)
- [x] **UIPERF-02**: MacSessionsListView local computed filter cached (MED-SP1)
- [x] **UIPERF-03**: MacProjectsListView local computed filter cached (MED-SP2)
- [x] **UIPERF-04**: ToolCallAccordion repeated .contains() per tick replaced (MED-SP3)
- [x] **UIPERF-05**: BrowserView non-lazy VStack converted to lazy (MED-SP4)
- [x] **UIPERF-06**: Duplicate formatModelName() uses shared ClaudeModel.displayName (LOW-SP1)

### Swift 6 Preparation

- [x] **SWIFT6-01**: ClaudeExecutorService.useAgentSDK mutable static var resolved for strict concurrency
- [x] **SWIFT6-02**: TeamsExecutorService.shutdownTeammate non-Sendable Process crossing resolved
- [x] **SWIFT6-03**: Build verified with -strict-concurrency=targeted (no new errors introduced)

**v1.5 Coverage:** 50/50 requirements complete (shipped 2026-02-24)

</details>

## Out of Scope (v3.1)

| Feature | Reason |
|---------|--------|
| App Store submission | Separate milestone |
| Android/web platform support | Not applicable |
| Full Swift 6 strict mode | Already at `targeted` level |
| Backend rewrite | Incremental changes only as needed |
| Scope waterfall visualiser | Deferred to v3.2+ (needs significant new API) |
| GitHub README preview before install | Deferred to v3.1.x (needs new endpoint) |
| Install progress with backend log streaming | Deferred to v3.2+ (needs SSE endpoint) |

## Traceability (v3.1)

| Requirement | Phase | Status |
|-------------|-------|--------|
| NAV-01 | 33 | Open |
| NAV-02 | 33 | Open |
| NAV-03 | 33 | Open |
| NAV-04 | 33 | Open |
| NAV-05 | 33 | Open |
| HP-01 | 34 | Open |
| HP-02 | 34 | Open |
| HP-03 | 34 | Open |
| HP-04 | 34 | Open |
| HP-05 | 34 | Open |
| CFG-01 | 35 | Open |
| CFG-02 | 35 | Open |
| CFG-03 | 35 | Open |
| CFG-04 | 35 | Open |
| CFG-05 | 35 | Open |
| CFG-06 | 35 | Open |
| CFG-07 | 35 | Open |
| BRW-01 | 36 | Open |
| BRW-02 | 36 | Open |
| BRW-03 | 36 | Open |
| BRW-04 | 36 | Open |
| BRW-05 | 36 | Open |
| BRW-06 | 36 | Open |
| BRW-07 | 36 | Open |
| BRW-08 | 36 | Open |
| SYS-01 | 37 | Open |
| SYS-02 | 37 | Open |
| SYS-03 | 37 | Open |
| XP-01 | 38 | Open |
| XP-02 | 38 | Open |
| XP-03 | 38 | Open |

**Coverage:**
- v3.1 requirements: 31 total
- Mapped to phases: 31/31 (100%)
- Complete: 0
- Open: 31

---
*Requirements defined: 2026-02-24*
*Last updated: 2026-02-24 — v3.1 milestone started*
