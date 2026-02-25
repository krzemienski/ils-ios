# Roadmap -- ILS iOS/macOS

## Milestones

- **v1.0 Cross-Platform Audit** - Phases 1-10 (shipped 2026-02-21)
- **v2.0 Performance Optimization Suite** - Phases 11-17 (shipped 2026-02-24)
- **v3.0 Comprehensive Audit Remediation** - Phases 18-24 (shipped 2026-02-23)
- **v1.5 All Audit Fixes** - Phases 25-32 (shipped 2026-02-24)
- **v3.1 Comprehensive Audit, Bug Fix & UX Overhaul** - Phases 33-39 (shipped 2026-02-25)
- **v3.5 Comprehensive Functional Validation (iOS & iPad)** - Phases 40-42 (started 2026-02-25)

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

- [x] **Phase 11: Launch & Baseline** - Remove artificial delay, defer non-critical init, establish Instruments baselines
- [x] **Phase 12: Service Layer Optimization** - Request deduplication, cache cost limits, memory pressure handling (completed 2026-02-23)
- [x] **Phase 13: ViewModel & Model Optimization** - Parallel data loading, SSE buffer flush, chat message windowing (completed 2026-02-23)
- [x] **Phase 14: SSE & Background Lifecycle** - Low Power Mode polling, background suspend/resume for SSE and WebSocket (completed 2026-02-23)
- [x] **Phase 15: View Layer Rendering** - 60fps session scrolling, chat virtualization, off-thread syntax highlighting, animation gating (completed 2026-02-23)
- [x] **Phase 16: Cross-Platform Verification** - macOS compilation, full v1.0 REQ regression check (completed 2026-02-23)
- [x] **Phase 17: Regression Test Infrastructure** - XCTest performance baselines, MetricKit production metrics (completed 2026-02-24)

## Phase Details

### Phase 11: Launch & Baseline
**Goal**: App cold-starts in under 1 second with non-critical initialization deferred to background
**Depends on**: Nothing (first phase of v2.0)
**Requirements**: LAUNCH-01, LAUNCH-02
**Success Criteria** (what must be TRUE):
  1. App shows interactive UI within 1 second of cold launch (measured via Instruments Time Profiler)
  2. TipKit, CacheService, and other non-critical services initialize after the first frame is visible
  3. Instruments baseline report exists documenting before/after launch time, memory allocation, and CPU profile
**Plans**: 2 plans

Plans:
- [x] 11-01-PLAN.md -- Remove artificial launch delay, defer non-critical init, capture before/after baseline
- [ ] 11-02-PLAN.md -- Gap closure: Capture Instruments baseline trace and structured report

---

### Phase 12: Service Layer Optimization
**Goal**: Network requests are deduplicated, caches are bounded, and the app handles memory pressure gracefully
**Depends on**: Phase 11 (baseline measurements inform priority)
**Requirements**: NET-01, NET-03, MEM-01
**Success Criteria** (what must be TRUE):
  1. Navigating rapidly between tabs does not fire duplicate GET requests for the same endpoint (visible in network log or Instruments)
  2. NSCache totalCostLimit is set and the app evicts cached data when receiving a memory warning
  3. App memory stays under 100MB during typical browsing of sessions, skills, and settings screens
**Plans**: 1 plan

Plans:
- [ ] 12-01-PLAN.md -- In-flight request coalescing, NSCache totalCostLimit, memory pressure observer (NET-01/NET-03/MEM-01 already resolved in v3.0)

---

### Phase 13: ViewModel & Model Optimization
**Goal**: Dashboard loads in parallel, SSE buffers are flushed after processing, and chat messages use windowed display for large histories
**Depends on**: Phase 12 (ViewModels compose the deduplicated APIClient and bounded caches)
**Requirements**: NET-02, MEM-02, MEM-03
**Success Criteria** (what must be TRUE):
  1. Dashboard stats and recent activity load simultaneously (observable as faster dashboard render vs sequential)
  2. After sending messages in a long chat session, memory does not grow unboundedly (SSE buffer flushed after ChatViewModel processes each batch)
  3. Opening a chat with 200+ messages shows the most recent ~50 messages immediately, with older messages loadable on scroll-up
**Plans**: 2 plans

Plans:
- [ ] 13-01-PLAN.md -- Verify NET-02/MEM-02 resolved, implement MEM-03 SystemMetricsViewModel deinit
- [ ] 13-02-PLAN.md -- Chat message windowing: backend total count, ChatViewModel pagination, load-more UI

---

### Phase 14: SSE & Background Lifecycle
**Goal**: Polling intervals adapt to Low Power Mode and all persistent connections suspend when the app enters background
**Depends on**: Phase 13 (SSEClient changes are high-risk and isolated; ViewModel flush must be stable first)
**Requirements**: BATT-01, BATT-02
**Success Criteria** (what must be TRUE):
  1. With Low Power Mode enabled, PollingManager and MetricsWebSocketClient poll at 2x their normal interval (e.g., 60s becomes 120s)
  2. When the app moves to background, SSE and WebSocket connections disconnect within 5 seconds
  3. When the app returns to foreground, SSE and WebSocket connections resume automatically and data is current
**Plans**: 1 plan

Plans:
- [ ] 14-01-PLAN.md -- LowPowerModeMonitor singleton, adaptive polling intervals (BATT-01), MetricsWebSocketClient background suspend/resume (BATT-02)

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
**Plans**: 3 plans

Plans:
- [ ] 15-01-PLAN.md -- Off-main-thread syntax highlighting: SyntaxHighlighter OSAllocatedUnfairLock, CodeBlockView Task.detached
- [ ] 15-02-PLAN.md -- Session list and chat optimization: SidebarView List migration, ChatMessageList stable identity + message windowing
- [ ] 15-03-PLAN.md -- Animation Low Power Mode gating: ShimmerModifier, StreamingIndicatorView, PulsingGlow, PulsingModifier

---

### Phase 16: Cross-Platform Verification
**Goal**: All optimizations compile and function correctly on macOS and all v1.0 audit REQs remain PASS
**Depends on**: Phase 15 (all code changes must be complete before verification sweep)
**Requirements**: COMPAT-01, COMPAT-02
**Success Criteria** (what must be TRUE):
  1. ILSMacApp scheme builds successfully on macOS 14+ with zero errors
  2. All 15 v1.0 audit REQs pass re-validation on iOS (sidebar navigation, settings inheritance, skills/plugins/hooks, system monitor, host profiles, quick actions, tooltips, themes, MCP servers, backend API, zero visual regressions, session consistency)
  3. Any iOS-only APIs used in optimization phases have macOS-appropriate guards or alternatives
**Plans**: 1 plan

Plans:
- [x] 16-01-PLAN.md -- Build all 3 targets (iOS, macOS, Backend), fix macOS compilation errors, re-validate 15 v1.0 REQs, spot-check macOS functionality

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
**Plans**: 2 plans

Plans:
- [ ] 17-01-PLAN.md -- XCTest performance baselines: launch (XCTApplicationLaunchMetric), memory (XCTMemoryMetric), scroll/CPU (XCTCPUMetric + XCTOSSignpostMetric), test plan config
- [ ] 17-02-PLAN.md -- MetricKit integration: PerformanceMonitor subscriber for production field metrics (launch, memory, diagnostics)

---

## v3.0 Comprehensive Audit Remediation

**Milestone Goal:** Eliminate all 165 issues found across 15 Axiom audits (13 CRITICAL, 49 HIGH, 73 MEDIUM, 30 LOW). Every v1.0 and v2.0 REQ must remain PASS at the end of Phase 24. No new features — code health only.

**Coverage:** 165/165 requirements mapped across Phases 18-23. Phase 24 validates all prior phases.

- [x] **Phase 18: CRITICAL Fixes** - 13 CRITICAL issues: data races, energy waste, architecture violations, performance bottlenecks, database safety (completed 2026-02-22)
- [x] **Phase 19: Concurrency + Memory HIGH** - 9 HIGH issues: nonisolated(unsafe) patterns, GCD-to-Task migration, Timer-to-Task, window cleanup (completed 2026-02-22)
- [x] **Phase 20: Architecture + Performance HIGH** - 17 HIGH issues: logic-in-view extractions, Set conversions, async file I/O, process classification, backend sorts (completed 2026-02-22)
- [x] **Phase 21: Navigation + Codable HIGH** - 10 HIGH issues: dead path cleanup, macOS navigation parity, try?-to-do/catch conversions, Codable best practices (completed 2026-02-22)
- [x] **Phase 22: Energy + Build + Accessibility + Networking HIGH** - 13 HIGH issues: animation lifecycle, SSE background suspend, build flags, Dynamic Type, SSH validation, migration safety, layout (completed 2026-02-22)
- [x] **Phase 23: All MEDIUM + LOW Issues** - 103 remaining issues grouped by file proximity for efficient editing (completed 2026-02-22)
- [x] **Phase 24: Validation + Documentation** - Build verification, functional validation, audit re-run (completed 2026-02-23)

---

### Phase 18: CRITICAL Fixes
**Goal**: Every CRITICAL finding is resolved — data races are eliminated, energy-wasteful polling patterns are corrected, architecture violations are patched, and the database enforces foreign keys across all connections
**Depends on**: Phase 11 (baseline established; builds pass)
**Requirements**: CONC-01, CONC-02, ENRG-01, ENRG-02, ENRG-03, SPERF-01, ARCH-01, ARCH-02, ARCH-03, ARCH-04, UIPERF-01, UIPERF-02, DB-01
**Success Criteria** (what must be TRUE):
  1. AppLogger is an actor (or uses OSAllocatedUnfairLock) and SyntaxHighlighter is @MainActor — Swift compiler accepts these files with strict sendability and no nonisolated(unsafe) workarounds
  2. Live Activity timer fires at 1.0s or greater; MCP health check calls a lightweight endpoint (not full loadServers()); Teams polling applies exponential backoff — observable via Instruments Energy or code review
  3. MacChatView API calls are routed through SessionsViewModel with do/catch; NewSessionView's three async creation flows live in NewSessionViewModel; MacSettingsView @State properties are private
  4. CodeBlockView caches syntax highlighting with @State + .task(id: code) so tokenization does not run on every body evaluation; ThemePickerView pre-computes an availableThemes Set
  5. configure.swift sets PRAGMA foreign_keys via pool configuration callback so all pooled connections enforce FK constraints
**Plans**: 4 plans

Plans:
- [x] 18-01-PLAN.md -- Concurrency safety: AppLogger OSAllocatedUnfairLock, SyntaxHighlighter @MainActor, CodeBlockView highlight caching
- [x] 18-02-PLAN.md -- Energy efficiency: Live Activity timer 1.0s, MCP lightweight health check, Teams exponential backoff
- [x] 18-03-PLAN.md -- Architecture + DB: MacChatView do/catch, MacSettingsView private @State, ThemePickerView Set, SQLite FK pool config
- [x] 18-04-PLAN.md -- NewSessionView ViewModel extraction: three async creation flows to NewSessionViewModel

---

### Phase 19: Concurrency + Memory HIGH
**Goal**: All nonisolated(unsafe) patterns on Task and Timer properties are replaced with correct actor-isolated equivalents, GCD-to-@MainActor crossings in macOS managers are eliminated, SSEClient uses structured concurrency, and the last legacy Timer in ViewModel layer is migrated to Task
**Depends on**: Phase 18 (CRITICAL concurrency fixes must be stable before touching related files)
**Requirements**: CONC-03, CONC-04, CONC-05, CONC-06, CONC-07, CONC-08, CONC-09, MEM-01, MEM-02
**Success Criteria** (what must be TRUE):
  1. SkillsViewModel, MCPViewModel, and SystemMetricsViewModel have no nonisolated(unsafe) declarations — their Task/Timer properties use actor-safe storage (@MainActor var or stored in isolated context)
  2. NotificationManager compiles without @preconcurrency delegate suppression; WindowAccessor and WindowFrameDelegate use MainActor.run or Task { @MainActor in } instead of DispatchQueue.main.async
  3. SSEClient's Task.detached closure captures only Sendable values and does not access @MainActor self directly
  4. HostProfilesViewModel uses Task instead of Timer.scheduledTimer — Timer is gone from all ViewModel files
  5. WindowFrameDelegate registers a window close notification and cancels its debounce Task when the OS closes the window
**Plans**: 3 plans

Plans:
- [ ] 19-01-PLAN.md -- iOS ViewModel nonisolated(unsafe) removal + Timer-to-Task migration
- [ ] 19-02-PLAN.md -- macOS GCD-to-Task migration + window close cleanup
- [ ] 19-03-PLAN.md -- SSEClient Task.detached isolation fix

---

### Phase 20: Architecture + Performance HIGH
**Goal**: Business logic is extracted from view bodies into ViewModels across six views, PollingManager no longer imports SwiftUI, Binding setters contain no async operations, SyntaxHighlighter keyword arrays are replaced with Sets, process classification is pre-computed in the ViewModel, and file I/O is moved off the main thread
**Depends on**: Phase 19 (concurrency patterns must be correct before refactoring ViewModels they touch)
**Requirements**: ARCH-05, ARCH-06, ARCH-07, ARCH-08, ARCH-09, ARCH-10, ARCH-11, ARCH-12, ARCH-13, SPERF-02, SPERF-03, SPERF-04, SPERF-05, SPERF-06, UIPERF-03, UIPERF-04, UIPERF-05, UIPERF-06
**Success Criteria** (what must be TRUE):
  1. CommandPaletteView, NewSessionView, SidebarRootView, SettingsConfigSection, SettingsView, FileBrowserView, and PermissionRequestModal have no computed properties or async work in their view bodies — all moved to their respective ViewModels
  2. PollingManager.swift has no SwiftUI import; Binding setters in SettingsConfigSection call synchronous ViewModel methods only (no await in setter body)
  3. SyntaxHighlighter keyword arrays are Set<String> at all 17+ call sites — O(1) lookup replaces O(n) Array.contains
  4. ProcessListView pre-computes classifyProcess() results in the ViewModel before ForEach iteration; ThemeMarketplaceView reads theme files via async Task, not Data(contentsOf:) on the main thread
  5. ChatMessage streaming produces fewer struct copies (value type optimization or @Observable reference); DashboardViewModel stats calls are parallelized with async let; SessionsController backend sort is indexed or paginated
**Plans**: 4 plans

Plans:
- [ ] 20-01-PLAN.md -- View body logic extractions: CommandPaletteView, CodeBlockView, NewSessionView, SidebarRootView, PermissionRequestModal
- [ ] 20-02-PLAN.md -- Settings/FileBrowser architecture: PollingManager SwiftUI removal, Binding setter fixes, hookEventBreakdown, sortedEntries
- [ ] 20-03-PLAN.md -- Performance: ProcessListView pre-computation, ThemeMarketplaceView async I/O, DashboardViewModel parallelization, ChatMessage optimization, SPERF-02 documentation
- [ ] 20-04-PLAN.md -- Backend: SessionsController sort optimization, SPERF-06 Set verification

---

### Phase 21: Navigation + Codable HIGH
**Goal**: Dead navigation paths are removed, nested NavigationStack in sheets is eliminated, macOS gains a NavigationStack in its detail column and a hooks screen route, and all silent try? failure sites in APIClient, CacheService, and AuthService are replaced with do/catch error logging
**Depends on**: Phase 20 (ViewModel extractions must be complete before navigation paths that reference them are cleaned up)
**Requirements**: NAV-01, NAV-02, NAV-03, NAV-04, CODBL-01, CODBL-02, CODBL-03, CODBL-04, CODBL-05, CODBL-06
**Success Criteria** (what must be TRUE):
  1. SidebarRootView.navigationPath and its associated NavigationStack are removed; no NavigationStack is nested inside a .sheet presentation in any file
  2. MacContentView's detail column is wrapped in a NavigationStack; MacContentView includes a route for the hooks screen that shows the hooks management UI
  3. APIClient, CacheService, and AuthService have zero try? at JSON decode and Keychain operation sites — all failures are caught and logged with the specific error
  4. All JSONDecoders in the app have an explicit dateDecodingStrategy set; backend controllers that build JSON manually are replaced with Codable-conforming response types
  5. String-backed enum types in DTOs validate input on decode and throw a meaningful DecodingError for unrecognized values
Plans:
- [x] 21-01-PLAN.md -- Navigation: dead NavigationPath, nested NavigationStack in sheets, macOS detail NavigationStack, hooks route
- [x] 21-02-PLAN.md -- Codable: APIClient try? documentation, .iso8601 dateDecodingStrategy, backend do/catch logging, 20 enum validating init(from:)

---

### Phase 22: Energy + Build + Accessibility + Networking HIGH
**Goal**: Animations pause when views are not visible, SSE disconnects on background, build settings are optimized for debug speed, fixed font sizes in three views are replaced with Dynamic Type, SSH host key validation is non-trivial, dangerous migration reverts are removed, and the SidebarRootView size-class switch preserves view identity
**Depends on**: Phase 21 (navigation must be stable before touching views that depend on it; Codable changes must be in before database migration work)
**Requirements**: ENRG-04, ENRG-05, ENRG-06, ENRG-07, BUILD-01, BUILD-02, A11Y-01, A11Y-02, A11Y-03, NET-01, DB-02, DB-03, LAYOUT-01
**Success Criteria** (what must be TRUE):
  1. CyberpunkEffects PulsingGlow reads isActive from environment or a @State flag tied to onAppear/onDisappear and stops its animation loop when the view is off-screen; SSEClient disconnects within 5 seconds of scenePhase moving to background
  2. project.pbxproj sets DEBUG_INFORMATION_FORMAT = dwarf (not dwarf-with-dsym) and ONLY_ACTIVE_ARCH = YES for debug configurations — incremental build time visibly faster
  3. PremiumView, LaunchScreenView, and ScreenshotView use Dynamic Type text styles or font(_:) with a TextStyle argument — zero hardcoded point sizes remain in those files
  4. CitadelSSHService uses known_hosts or a user-presented fingerprint confirmation instead of .acceptAnything()
  5. All migration revert() functions use IF EXISTS table drops or are empty stubs — no DROP TABLE that destroys production data on accidental revert; FK constraint data validation is added to at least one migration; SidebarRootView uses a single stable root view with conditional content rather than branching between two NavigationStack instances
Plans:
- [x] 22-01-PLAN.md -- Energy: PulsingGlow/PulsingModifier animation lifecycle (ENRG-04), SSE background disconnect (ENRG-05), request batching docs (ENRG-06)
- [x] 22-02-PLAN.md -- Build+A11Y+Layout: BUILD-01/02 verified correct, PremiumView Dynamic Type (A11Y-01), LaunchScreenView Dynamic Type (A11Y-02), A11Y-03 resolved-by-absence, LAYOUT-01 documentation
- [x] 22-03-PLAN.md -- Net+DB: SSH TOFU documentation (NET-01), migration revert no-ops (DB-02), PRAGMA foreign_key_check (DB-03), ENRG-07 verified resolved

---

### Phase 23: All MEDIUM + LOW Issues
**Goal**: Every MEDIUM and LOW finding is resolved or explicitly documented as accepted (with rationale) — code health across concurrency, energy, performance, architecture, navigation, Codable, build, accessibility, database, networking, security, memory, layout, and modernization reaches the standard set by the CRITICAL and HIGH phases
**Depends on**: Phase 22 (all HIGH issues resolved; MEDIUM fixes build on corrected foundations)
**Requirements**: CONC-10, CONC-11, CONC-12, CONC-13, CONC-14, CONC-15, CONC-16, CONC-17, CONC-18, ENRG-08, ENRG-09, ENRG-10, ENRG-11, ENRG-12, ENRG-13, ENRG-14, ENRG-15, ENRG-16, ENRG-17, ENRG-18, SPERF-07, SPERF-08, SPERF-09, SPERF-10, SPERF-11, SPERF-12, SPERF-13, SPERF-14, SPERF-15, SPERF-16, SPERF-17, SPERF-18, ARCH-14, ARCH-15, ARCH-16, ARCH-17, ARCH-18, ARCH-19, ARCH-20, UIPERF-07, UIPERF-08, UIPERF-09, UIPERF-10, UIPERF-11, UIPERF-12, UIPERF-13, UIPERF-14, NAV-05, NAV-06, NAV-07, NAV-08, NAV-09, NAV-10, NAV-11, NAV-12, NAV-13, CODBL-07, CODBL-08, CODBL-09, CODBL-10, CODBL-11, CODBL-12, CODBL-13, BUILD-03, BUILD-04, BUILD-05, BUILD-06, BUILD-07, BUILD-08, A11Y-04, A11Y-05, A11Y-06, A11Y-07, A11Y-08, DB-04, DB-05, DB-06, DB-07, NET-02, NET-03, NET-04, NET-05, NET-06, NET-07, SEC-01, SEC-02, SEC-03, SEC-04, SEC-05, MEM-03, MEM-04, LAYOUT-02, LAYOUT-03, LAYOUT-04, MOD-01, MOD-02, MOD-03, MOD-04, MOD-05, MOD-06, MOD-07, MOD-08
**Success Criteria** (what must be TRUE):
  1. All concurrency MEDIUM patterns are resolved: ClaudeExecutorService.readQueue, HostProfilesViewModel deinit, SpotlightIndexer, SyncCoordinator, DashboardViewModel Task.detached, and SessionsViewModel Task.detached cache writes use correct isolation
  2. All energy MEDIUM patterns are addressed: WebSocket metrics gate on view visibility, log viewer gates on visibility, animations check Low Power Mode, Timer tolerance is set on all timers, adaptive polling by battery level is implemented or explicitly deferred with rationale
  3. All architecture MEDIUM patterns are resolved: SessionsViewModel split consideration is documented, redundant ProjectsViewModel removed from NewSessionView, fire-and-forget Tasks converted to .task modifier where applicable, toast timer deduplication extracted to shared modifier, view helper functions marked private
  4. All navigation, Codable, build, accessibility, database, networking, security, memory, layout, and modernization MEDIUM and LOW items are either fixed or have a documented acceptance note in the code — zero silent deferrals
  5. Both iOS and macOS build successfully with zero warnings introduced by the MEDIUM/LOW fixes
Plans:
- [x] 23-01-PLAN.md -- Concurrency + Energy remaining MEDIUM (6 issues: readQueue, Task.detached, WebSocket visibility, health check docs, adaptive polling docs)
- [x] 23-02-PLAN.md -- SwiftUI Architecture MEDIUM (5 issues: ProjectsViewModel removal, toast dedup modifier, private helpers, SessionsViewModel docs)
- [x] 23-03-PLAN.md -- SwiftUI Performance MEDIUM (6 issues: macOS duplicate VMs, ForEach identity, skills cache, logColor, ThemeEditor docs)
- [x] 23-04-PLAN.md -- Codable + Navigation MEDIUM (8 issues: date handling, decoder errors, value validation, deep link validation, nav architecture docs)
- [x] 23-05-PLAN.md -- Accessibility + Modernization + Build MEDIUM (8 issues: a11y labels, VoiceOver grouping, String(describing:), protocol cleanup, type-check flags)
- [x] 23-06-PLAN.md -- Database + Networking + Security + Layout MEDIUM (9 issues: migration versioning, reconnect limit, network gate, localhost constants, Keychain UX, spacing, macOS frames)
- [x] 23-07-PLAN.md -- LOW sweep + Swift Perf remaining + Modernization (search cache, sidebar lookups, type annotations, deprecation audit, doc comments)

---

### Phase 24: Validation + Documentation
**Goal**: The full codebase builds cleanly on all three targets (iOS, macOS, Backend), all v1.0 audit REQs remain PASS, a representative functional test pass confirms no regressions, and the audit findings document is updated to reflect the resolved state
**Depends on**: Phase 23 (all 165 issues must be addressed before final validation)
**Requirements**: (validates all 165 REQ-IDs from Phases 18-23 — no new requirement IDs)
**Success Criteria** (what must be TRUE):
  1. `xcodebuild` for ILSApp scheme and ILSMacApp scheme both exit 0 with zero errors; `swift build` for ILSBackend exits 0 with zero errors
  2. All 15 v1.0 audit REQs (REQ-01 through REQ-15) re-validated as PASS on the simulator: sidebar navigation, settings inheritance, skills/plugins/hooks, system monitor, host profiles, quick actions, tooltips, themes, MCP servers, backend API, zero visual regressions, session consistency
  3. A re-run of the 15 Axiom audits (or a representative subset of CRITICAL/HIGH checks) confirms zero CRITICAL findings remain open
  4. scratch/audit-findings-2026-02-22.md is updated with a resolution column showing the phase and commit that addressed each finding
Plans:
- [x] 24-01-PLAN.md -- Build verification (3 targets), Axiom audit re-run (6 audits), resolution document, state updates

---

---

## v1.5 All Audit Fixes

**Milestone Goal:** Resolve all 60 remaining audit findings from the 2026-02-24 fresh audit (70 total minus 10 already fixed in c57690f). Focus areas: concurrency safety, energy/memory lifecycle, SwiftUI performance, test infrastructure modernization, and Swift 6 preparation. No new features — code health only.

**Source Data:** `scratch/audit-findings-2026-02-24.md` (70 issues from 16 parallel agents)
**Prior Fixes:** commit c57690f (10 CRITICAL/HIGH issues across 9 files)

- [x] **Phase 25: Concurrency HIGH + Swift 6 Blockers** — 4 dangerous concurrency defects: non-Sendable Process, WebSocket capture, continuation double-resume, mutable static var (completed 2026-02-24)
- [x] **Phase 26: Concurrency MEDIUM + LOW** — 15 remaining concurrency issues: Task.detached patterns, completion-to-async, nonisolated(unsafe), isolation verification (completed 2026-02-24)
- [x] **Phase 27: Energy + Memory** — 16 issues: material overhead, constrained network, LPM polling, flush timers, GPU passes, delegate cycles, observer cleanup (completed 2026-02-24)
- [x] **Phase 28: SwiftUI Performance** — 6 issues: CIFilter verification, computed filter caching, .contains() per tick, lazy VStack, duplicate formatModelName (completed 2026-02-24)
- [x] **Phase 29: Testing CRITICAL — Sleep Replacement** — 4 requirement groups covering 18 sleep() instances across 3 test files (completed 2026-02-24)
- [x] **Phase 30: Testing Infrastructure** — 7 issues: UI test startup, placeholder tests, Swift Testing migration, test data factories, parallelization (completed 2026-02-24)
- [x] **Phase 31: Swift 6 Preparation** — 3 requirements: resolve 2 compile-error blockers, verify -strict-concurrency=targeted (completed 2026-02-24)
- [x] **Phase 32: Final Validation** — Cross-cutting build verification, functional validation, audit re-run confirming zero open issues (completed 2026-02-24)

### Phase 25: Concurrency HIGH + Swift 6 Blockers
**Goal**: The 4 most dangerous concurrency defects are eliminated — non-Sendable Process no longer crosses actor boundary, WebSocket captures use [weak self], continuation cannot double-resume, and the mutable static var blocker for Swift 6 is resolved
**Depends on**: Nothing (first phase of v1.5; 10 CRITICAL/HIGH already fixed in c57690f)
**Requirements**: CONC-01, CONC-02, CONC-07, CONC-10, SWIFT6-01, SWIFT6-02
**Success Criteria** (what must be TRUE):
  1. `TeamsExecutorService.shutdownTeammate` no longer passes non-Sendable `Process` into `Task.detached` — either extracts Sendable values before the boundary or uses a Sendable wrapper
  2. `WebSocketService.ws.onText` Task closure uses `[weak self]` or captures only Sendable values
  3. `SystemMetricsService` continuation double-resume risk is eliminated with a guard or `CheckedContinuation`
  4. `ClaudeExecutorService.useAgentSDK` mutable static var is resolved for strict concurrency (nonisolated static let, actor-isolated access, or @TaskLocal)
  5. Both iOS and macOS build with zero errors after all changes
**Plans**: 2 plan(s)

Plans:
- [ ] 25-01-PLAN.md -- TeamsExecutorService non-Sendable Process + SystemMetricsService continuation safety
- [ ] 25-02-PLAN.md -- WebSocket Task capture + ClaudeExecutorService mutable static var

---

### Phase 26: Concurrency MEDIUM + LOW
**Goal**: All remaining concurrency patterns are corrected or documented — Task.detached replaced where unnecessary, completion handlers converted to async/await, nonisolated(unsafe) eliminated where possible, and informational patterns documented
**Depends on**: Phase 25 (Swift 6 blockers resolved first)
**Requirements**: CONC-03, CONC-04, CONC-05, CONC-06, CONC-08, CONC-09, CONC-11, CONC-12, CONC-13, CONC-14, CONC-15, CONC-16, CONC-17
**Success Criteria** (what must be TRUE):
  1. `ProjectsViewModel` no longer uses `Task.detached` — replaced with plain `Task` with correct isolation
  2. `SpotlightIndexer` completion handler pattern converted to async/await
  3. `SubscriptionManager.init` defers Task spawning until after full initialization
  4. `LowPowerModeMonitor` nonisolated(unsafe) replaced with actor-safe alternative
  5. `AppLogger.recentLogs` Task.detached pattern corrected; all LOW concurrency items documented or fixed
  6. Both iOS and macOS build with zero errors
**Plans**: 2 plans

Plans:
- [ ] 26-01-PLAN.md — Fix concurrency patterns: Task.detached, SubscriptionManager init, nonisolated(unsafe), AppLogger timer
- [ ] 26-02-PLAN.md — Document resolved/intentional concurrency patterns (deleted files, Vapor Sendable, PollingManager design)





---

### Phase 27: Energy + Memory
**Goal**: All energy waste patterns are eliminated and all memory lifecycle issues are resolved — material overhead reduced, constrained network properly configured, LPM-aware polling added, flush timers optimized, GPU double-shadow eliminated, delegate cycles broken, observer cleanup completed
**Depends on**: Phase 26 (concurrency patterns must be correct before touching lifecycle code)
**Requirements**: ENRG-01, ENRG-02, ENRG-03, ENRG-04, ENRG-05, ENRG-06, ENRG-07, ENRG-08, MEM-01, MEM-02, MEM-03, MEM-04, MEM-05, MEM-06, MEM-07, MEM-08
**Success Criteria** (what must be TRUE):
  1. `ConnectionBanner` .ultraThinMaterial is replaced or documented as acceptable; `SSEClient` allowsConstrainedNetworkAccess is correctly configured
  2. Fleet health polling doubles interval in Low Power Mode; `AppLogger` flush timer increased to 10s
  3. `GlowEffect` double-shadow GPU passes reduced to single pass; macOS `WindowManager` UserDefaults writes throttled
  4. `PollingManager` unowned crash risk resolved; `NSWindow` delegate cycle in `WindowManager` broken
  5. `NotificationManager` UNUserNotificationCenter delegate lifecycle correct; `SSEClient` observer removed in cleanup()
  6. All LOW memory items (NSTask hold, DispatchWorkItem timeout, flush timer false positive) resolved or documented
  7. Both iOS and macOS build with zero errors
**Plans**: 3 plans

Plans:
- [ ] 27-01-PLAN.md -- Energy: UI + Network (ConnectionBanner material, SSEClient config/cleanup, Fleet LPM polling, GlowEffect single-shadow)
- [x] 27-02-PLAN.md -- Energy + Memory: Services (AppLogger flush timer, SyncCoordinator debounce/observer, PollingManager docs)
- [ ] 27-03-PLAN.md -- macOS + Backend Memory (WindowManager delegate cycle, NotificationManager lifecycle, TeamsExecutorService NSTask cleanup)

---

### Phase 28: SwiftUI Performance
**Goal**: All SwiftUI performance anti-patterns are eliminated — off-thread CIFilter verified, computed filter vars cached, per-tick .contains() replaced, non-lazy VStack converted, duplicate utility functions consolidated
**Depends on**: Phase 27 (energy/memory lifecycle must be stable before view layer optimization)
**Requirements**: UIPERF-01, UIPERF-02, UIPERF-03, UIPERF-04, UIPERF-05, UIPERF-06
**Success Criteria** (what must be TRUE):
  1. `TunnelSettingsView` CIFilter QR generation is verified running off main thread (or moved off if not)
  2. `MacSessionsListView` and `MacProjectsListView` computed filter vars are cached in @State or ViewModel
  3. `ToolCallAccordion` per-tick .contains() replaced with pre-computed Set
  4. `BrowserView` non-lazy VStack converted to LazyVStack where appropriate
  5. Duplicate `formatModelName()` consolidated to use shared `ClaudeModel.displayName`
  6. Both iOS and macOS build with zero errors
**Plans**: 2 plans

Plans:
- [x] 28-01-PLAN.md — iOS: off-thread QR generation, ToolCallAccordion Set-based classification, BrowserView LazyVStack verification (completed 2026-02-24)
- [ ] 28-02-PLAN.md — macOS: cached filter vars in MacSessionsListView/MacProjectsListView, formatModelName consolidation

---

### Phase 29: Testing CRITICAL — Sleep Replacement
**Goal**: All 18 sleep()/Thread.sleep() instances across 3 test files are replaced with condition-based waiting, eliminating the primary source of test flakiness
**Depends on**: Phase 28 (all production code fixes must be stable before touching test infrastructure)
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04
**Success Criteria** (what must be TRUE):
  1. `ErrorHandlingTests.swift` — all 5 sleep sites replaced with XCTNSPredicateExpectation or async poll loops
  2. `FeatureGateTests.swift` — all 5 sleep sites replaced with condition-based waiting
  3. `Scenario03_StreamingAndCancellation.swift` — all 6 sleep sites replaced with condition-based waiting
  4. Zero `sleep()` or `Thread.sleep()` calls remain in any test file
  5. All replaced tests pass when run via `xcodebuild test`
**Plans**: 2 plan(s)

Plans:
- [x] 29-01-PLAN.md -- ErrorHandlingTests + FeatureGateTests sleep replacement (completed 2026-02-24)
- [x] 29-02-PLAN.md -- Scenario03_StreamingAndCancellation sleep replacement + zero-sleep verification (completed 2026-02-24)

---

### Phase 30: Testing Infrastructure
**Goal**: Test infrastructure is modernized — UI test startup optimized, placeholder tests replaced with meaningful Swift Testing tests, test data factories created, and test parallelization configured
**Depends on**: Phase 29 (sleep replacement must be done before broader test infrastructure changes)
**Requirements**: TEST-05, TEST-06, TEST-07, TEST-08, TEST-09, TEST-10, TEST-11
**Success Criteria** (what must be TRUE):
  1. UI test startup time reduced via shared XCUIApplication or test grouping
  2. `ILSBackendTests.swift` placeholder replaced with meaningful Swift Testing tests (`import Testing`, `@Test`, `#expect`)
  3. `ILSSharedTests.swift` placeholder replaced with meaningful Swift Testing tests
  4. `NavigationTests.swift` instance var `app` moved to setUp method
  5. Test data factories/builders exist for common test objects (Session, Project, Message)
  6. Test parallelization configured in test plan
  7. All tests pass when run via `xcodebuild test`
**Plans**: 2 plans
Plans:

- [x] 30-01-PLAN.md -- Swift Testing migration: ILSSharedTests + ILSBackendTests placeholders replaced, test data factories, Codable/enum tests (completed 2026-02-24)
- [x] 30-02-PLAN.md -- UI test infrastructure: NavigationTests setUp fix, test parallelization config, startup optimization (completed 2026-02-24)

---

### Phase 31: Swift 6 Preparation
**Goal**: The codebase compiles cleanly with -strict-concurrency=targeted and the path to Swift 6 complete mode is documented with remaining blockers identified
**Depends on**: Phase 26 (concurrency fixes in Phase 25-26 resolve the 2 compile-error blockers)
**Requirements**: SWIFT6-01, SWIFT6-02, SWIFT6-03
**Success Criteria** (what must be TRUE):
  1. `ClaudeExecutorService.useAgentSDK` mutable static var resolved (validated in Phase 25, confirmed here)
  2. `TeamsExecutorService.shutdownTeammate` non-Sendable Process resolved (validated in Phase 25, confirmed here)
  3. `xcodebuild` with `-strict-concurrency=targeted` produces zero new warnings beyond baseline
  4. Remaining blockers for `-strict-concurrency=complete` are documented with migration path
  5. Both iOS and macOS build with zero errors
**Plans**: 2 plans

Plans:
- [x] 31-01-PLAN.md -- Verify Phase 25 Swift 6 blocker fixes, enable -strict-concurrency=targeted across all targets, fix new warnings (completed 2026-02-24)
- [ ] 31-02-PLAN.md -- Document remaining -strict-concurrency=complete blockers with migration path, final cross-platform verification

---

### Phase 32: Final Validation
**Goal**: The full codebase builds cleanly on all three targets, a fresh audit confirms zero open CRITICAL/HIGH issues, and the v1.5 milestone is ready for closure
**Depends on**: Phases 25-31 (all fixes must be complete before final validation)
**Requirements**: (validates all 50 REQ-IDs from Phases 25-31 — no new requirement IDs)
**Success Criteria** (what must be TRUE):
  1. `xcodebuild` for ILSApp scheme and ILSMacApp scheme both exit 0 with zero errors; `swift build` for ILSBackend exits 0 with zero errors
  2. A fresh run of the 5 primary Axiom audits (concurrency, memory, energy, swiftui-performance, testing) confirms zero CRITICAL and zero HIGH findings remain
  3. All v1.0 audit REQs (REQ-01 through REQ-15) remain PASS
  4. `scratch/audit-findings-2026-02-24.md` is updated with resolution status for all 70 issues
  5. All tests pass when run via `xcodebuild test`
**Plans**: 1 plan(s)

Plans:
- [x] 32-01-PLAN.md -- Build verification, test suite, 5 Axiom audits, v1.0 REQ spot-check (completed 2026-02-24)
- [x] 32-02-PLAN.md -- Audit findings resolution update, milestone closure (completed 2026-02-24)


<details>
<summary>v3.1 Comprehensive Audit, Bug Fix & UX Overhaul (Phases 33-39) -- SHIPPED 2026-02-25</summary>


**Milestone Goal:** Systematically audit every screen, fix broken functionality, restore missing features (GitHub skill/plugin browsing, host config sync, hooks management), redesign Fleet into Host Profiles, and ensure consistent UX across iOS, iPadOS, and macOS. Shift from code health to product quality.

**Research:** `.planning/research/` (STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md — 109KB)
**Key Constraint:** Phase 34 (Host Profiles) MUST complete before Phases 35-36 can be validated — config sync and GitHub install depend on targeting the correct host.

- [x] **Phase 33: Navigation & UX Overhaul** — Side menu accessibility, chat back button, home layout, sidebar host indicator, deep link consistency (completed 2026-02-25)
- [x] **Phase 34: Host Profiles Fix + Redesign** — CRITICAL AppState propagation, ViewModel reload on switch, Fleet→Host Profiles rename (completed 2026-02-25)
- [x] **Phase 35: Settings & Config Sync** — Host CLI inheritance display, InheritanceBadge full coverage, write allowlist, system prompt, tooltips (completed 2026-02-25)
- [x] **Phase 36: Browse, Skills & Plugins** — GitHub search/install, per-item progress, plugin browse UI, branch detection, rate limit UX (completed 2026-02-25)
- [x] **Phase 37: System Monitor & Themes** — Real-time metrics restoration, theme loading fixes, cross-platform consistency (completed 2026-02-25)
- [x] **Phase 38: Cross-Platform Validation** — macOS build, v1.0 REQ regression, iOS/iPadOS/macOS parity
- [ ] **Phase 39: Gap Closure & Milestone Finalization** — macOS custom theme cold-load fix, traceability table sync

---

### Phase 33: Navigation & UX Overhaul
**Goal**: Side menu is accessible from every screen, chat has a back button, home screen is polished, sidebar shows active host, and deep links work consistently
**Depends on**: Nothing (first phase of v3.1; zero backend risk)
**Requirements**: NAV-01, NAV-02, NAV-03, NAV-04, NAV-05
**Plans:** 3/3 plans complete
Plans:
- [x] 33-01-PLAN.md — Inline nav titles on 4 missing screens + Home layout polish (NAV-01, NAV-03)
- [ ] 33-02-PLAN.md — Chat back button via previousScreen tracking + sidebar host indicator (NAV-02, NAV-04)
- [ ] 33-03-PLAN.md — Deep link browser segment routing + back button integration (NAV-05)
**Success Criteria** (what must be TRUE):
  1. Hamburger menu button is visible and functional on ALL screens — no child view adds a conflicting `.topBarLeading` toolbar item that hides the hamburger
  2. Chat view has a back button that returns to the sessions list without losing the active session's @SceneStorage state
  3. Home screen stats cards and quick actions are consistently spaced and ordered
  4. Sidebar header area shows the active host profile name (or "Local" if no profile active)
  5. All registered `ils://` deep link routes navigate correctly without stale state

---

### Phase 34: Host Profiles Fix + Redesign
**Goal**: Host activation propagates through AppState so all ViewModels target the correct host, and the Fleet UI is redesigned as Host Profiles with consistent naming
**Depends on**: Phase 33 (navigation must be stable before host switching triggers full-app reloads)
**Requirements**: HP-01, HP-02, HP-03, HP-04, HP-05
**Success Criteria** (what must be TRUE):
  1. `HostProfilesViewModel` receives `AppState` (not a standalone `APIClient()`) — activation calls `appState.updateServerURL()` which recreates APIClient and SSEClient in ConnectionManager
  2. After switching hosts, BrowserView, SettingsView, and SystemMonitorView all show data from the NEW host (not stale data from the previous host)
  3. Active profile indicator is visible on the host list row and in the sidebar
  4. Health status badges (colored dot) display per host with polling
  5. All UI strings say "Host Profiles" (not "Fleet") — navigation title, sidebar item, settings references
**Plans**: 3 plans

Plans:
- [x] 34-01-PLAN.md — Core AppState injection into HostProfilesViewModel, activate() propagation, activeHostName persistence (HP-01, HP-03, HP-04)
- [x] 34-02-PLAN.md — Reactive ViewModel reconfiguration via .onChange(of: appState.serverURL) on all views (HP-02)
- [x] 34-03-PLAN.md — Delete dead Fleet* files, update doc comments for naming consistency (HP-05)

---

### Phase 35: Settings & Config Sync
**Goal**: Settings display the connected host's effective config with per-field inheritance badges, write operations use a safe allowlist, and all fields have explanatory tooltips
**Depends on**: Phase 34 (correct host must be targeted before config sync is meaningful)
**Requirements**: CFG-01, CFG-02, CFG-03, CFG-04, CFG-05, CFG-06, CFG-07
**Success Criteria** (what must be TRUE):
  1. Settings screen shows effective config values from the connected host's `~/.claude/settings.json`
  2. Every settings field has an `InheritanceBadge` showing "Host Default" or "Custom" based on whether the value is inherited or overridden
  3. Config auto-refreshes on reconnect and host switch via `onChange(appState.isConnected)` trigger
  4. Every settings field has a `SettingsInfoButton` tooltip with explanatory text
  5. Config write operations use a read-then-patch pattern with an allowlist — `hooks`, `env`, `permissions`, `statusLine` are never included in write payloads
  6. System prompt field is displayed (read-only if inherited from host default)
  7. Inline edits of user-scope settings save immediately via minimal-delta PUT
**Plans:** 2/2 plans complete

Plans:
- [ ] 35-01-PLAN.md -- Safe config write (read-then-patch) and reconnect auto-refresh
- [ ] 35-02-PLAN.md -- InheritanceBadge + tooltip coverage on all fields, system prompt info section

---

### Phase 36: Browse, Skills & Plugins
**Goal**: GitHub browse and install works for both skills and plugins with per-item progress, status badges, branch detection, and graceful rate limiting
**Depends on**: Phase 34 (browse must target the correct host's backend)
**Requirements**: BRW-01, BRW-02, BRW-03, BRW-04, BRW-05, BRW-06, BRW-07, BRW-08
**Success Criteria** (what must be TRUE):
  1. GitHub skill search returns results with name, description, star count, and repo path displayed
  2. Install uses per-item spinner (`installingSkills: Set<String>`) — list remains browsable during install
  3. Installed skills show an "Installed" badge on their GitHub search result row
  4. Plugins tab has a GitHub browse section (symmetric with skills tab)
  5. Installed skills and plugins have an inline enable/disable toggle
  6. `fetchRawContent` tries the repo's default branch (not hardcoded `main`)
  7. Rate limit 429 shows: "GitHub search limit reached. Set GITHUB_TOKEN on host to increase limits."
  8. Installed items can be uninstalled via `.contextMenu` "Remove" action from browse tab
**Plans:** 3/3 plans complete

Plans:
- [ ] 36-01-PLAN.md — Backend: branch detection, rate limit messaging, skill enable/disable routes, plugin GitHub search endpoint
- [ ] 36-02-PLAN.md — Frontend: per-item install tracking, installed badges, context menus, rate limit error banner
- [ ] 36-03-PLAN.md — Frontend: plugin GitHub browse section, inline enable/disable toggles

---

### Phase 37: System Monitor & Themes
**Goal**: System monitor shows real-time metrics from the connected host, themes load correctly on fresh launch, and theme appearance is consistent across platforms
**Depends on**: Phase 34 (system monitor needs correct host connection)
**Requirements**: SYS-01, SYS-02, SYS-03
**Plans:** 2/2 plans complete
Plans:
- [x] 37-01-PLAN.md — Fix system monitor to use active host URL for WebSocket + REST
- [x] 37-02-PLAN.md — Verify theme default loading and cross-platform injection parity
**Success Criteria** (what must be TRUE):
  1. System monitor screen displays real-time CPU, memory, disk, and network metrics from the connected host
  2. Default theme loads correctly on fresh app installation (no blank/broken theme state)
  3. Theme colors and typography are consistent between iOS, iPadOS, and macOS

---

### Phase 38: Cross-Platform Validation
**Goal**: All v3.1 changes verified on iOS, iPadOS, and macOS; all v1.0 audit REQs remain PASS; zero regressions
**Depends on**: Phases 33-37 (all feature work complete)
**Requirements**: XP-01, XP-02, XP-03
**Success Criteria** (what must be TRUE):
  1. `xcodebuild` for ILSApp and ILSMacApp both exit 0 with zero errors; `swift build` for backend exits 0
  2. All 15 v1.0 audit REQs (REQ-01 through REQ-15) re-validated as PASS
  3. Feature parity verified across iOS, iPadOS, and macOS for all v3.1 changes (navigation, host profiles, settings, browse, system monitor, themes)
**Plans:** 2/2 plans complete

Plans:
- [x] 38-01-PLAN.md — Build all three targets, fix compilation errors, platform guard audit (XP-01)
- [x] 38-02-PLAN.md — Fix macOS parity gaps, re-validate 15 v1.0 REQs, document feature parity (XP-02, XP-03)

### Phase 39: Gap Closure & Milestone Finalization
**Goal**: Close the 1 low-severity integration gap and sync documentation traceability table for milestone completion
**Depends on**: Phase 38 (audit identifies gaps)
**Requirements**: SYS-03 (integration gap closure)
**Gap Closure:** Closes gaps from v3.1-MILESTONE-AUDIT.md
**Success Criteria** (what must be TRUE):
  1. macOS `MacContentView.swift` `.task` calls `themeManager.loadAndRegisterCustomThemes(client:)` on cold start (parity with iOS)
  2. REQUIREMENTS.md traceability table shows 31/31 Complete, 0 Open
**Plans:** 0/0 (direct fix — no plan needed for 1-line code change + doc sync)

---

</details>


---

## v3.5 Comprehensive Functional Validation (iOS & iPad)

**Milestone Goal:** Launch every screen on iPhone and iPad simulators, capture screenshot evidence, verify logs, fix any issue found on the spot, and have two independent agent teammates confirm all evidence is accurate. First true functional validation -- no code-level verification shortcuts.

**Research:** `.planning/research/` (SUMMARY.md, STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md)
**Key Constraint:** Phases are STRICTLY SEQUENTIAL -- iPhone validation must complete before iPad (fix-as-you-go changes the binary).
**Embedded Evidence Gates:** Each phase includes its own dual-agent verification gate. Issues are caught and fixed in the phase where they belong -- no pile-up of rework at the end.

- [x] **Phase 40: Environment Setup & Screen Inventory** -- Simulators booted, app installed, backend verified, evidence directories created, PASS criteria defined, dual-agent verification of setup correctness (DONE 2026-02-25)
- [x] **Phase 41: iPhone Full Validation + Deep Links** -- All 12+ screens validated with fix-as-you-go, deep links tested, screenshots organized, dual-agent review of all iPhone evidence before proceeding (completed 2026-02-25)
- [ ] **Phase 42: iPad Full Validation** -- All screens validated in split-view layout, sidebar sync verified, screenshots organized, dual-agent review of all iPad evidence, cross-device comparison

---

### Phase 40: Environment Setup & Screen Inventory
**Goal**: Both simulators are booted with the newest binary, backend is verified running from the correct path, evidence directories exist, a PASS criteria document defines what success looks like for every screen, and two independent agents confirm the setup is correct before validation begins
**Depends on**: Nothing (first phase of v3.5)
**Requirements**: ENV-01, ENV-02, ENV-03, ENV-04, ENV-05, ENV-06, GATE-05
**Success Criteria** (what must be TRUE):
  1. iPhone simulator (50523130) shows the ILS app home screen after fresh install from the newest DerivedData binary (verified by `ls -td` timestamp, not `find | head`)
  2. iPad simulator (C074375B) shows the ILS app home screen after install of the same binary used on iPhone
  3. `curl http://localhost:9999/health` returns success and `lsof -i :9999` confirms the binary path contains `ils-ios/`
  4. `/tmp/v3.5-evidence/iphone/` and `/tmp/v3.5-evidence/ipad/` directories exist and are empty
  5. A PASS criteria document lists every screen with numbered verification points for both devices
  6. **Evidence gate:** Two independent agents confirm setup is correct (simulators responsive, backend healthy, correct binary installed, evidence dirs ready) -- 2/2 agreement required before proceeding to Phase 41
**Plans**: 40-01 (infrastructure setup), 40-02 (PASS criteria), 40-03 (dual-agent gate)
**Status**: COMPLETE (2026-02-25) -- All 7 requirements met, GATE-05 passed with 2/2 agent agreement

---

### Phase 41: iPhone Full Validation + Deep Links
**Goal**: Every screen on iPhone is launched, visually verified, and captured as numbered screenshot evidence; every deep link route navigates correctly; any issue found is fixed immediately and re-validated; all iPhone screenshots are reviewed by two independent agents who must agree on every screen before proceeding to iPad
**Depends on**: Phase 40 (setup verified by dual-agent gate)
**Requirements**: IPH-01, IPH-02, IPH-03, IPH-04, IPH-05, IPH-06, IPH-07, IPH-08, IPH-09, IPH-10, IPH-11, IPH-12, IPH-13, DL-01, DL-02, DL-03, DL-04, DL-05, DL-06, GATE-01, GATE-03
**Success Criteria** (what must be TRUE):
  1. All 12+ iPhone screens have numbered screenshots in `/tmp/v3.5-evidence/iphone/` showing correct data rendering (stats cards, session rows, chat messages, MCP health indicators, metrics graphs, settings badges, profile rows, theme previews, sidebar items)
  2. All `ils://` deep link routes (`home`, `sessions`, `sessions/{uuid}`, `browser`, `mcp`, `skills`, `plugins`, `settings`, `system`, `fleet`, `themes`) navigate to the correct screen without crashes
  3. Console log stream captured during validation shows zero crashes and zero unhandled errors
  4. Every issue found during validation has a corresponding fix commit, rebuild, and re-validation screenshot
  5. Sidebar navigation is accessible from every screen and the active item is highlighted
  6. All iPhone screenshots are organized with numbered naming (`01-home.png`, `02-sessions.png`, etc.) in the evidence directory
  7. **Evidence gate:** Agent A produces an independent verdict document with PASS/FAIL per iPhone screen; Agent B produces an independent verdict document with PASS/FAIL per iPhone screen; 2/2 agreement required on every screen -- any disagreement triggers re-investigation, fix, and re-validation within this phase before proceeding to Phase 42
**Plans**: 7 plans
Plans:
- [x] 41-01-PLAN.md -- Validate core screens 01-06 (Home, Sessions, Chat, MCP, Skills, Plugins)
- [x] 41-02-PLAN.md -- Validate screens 07-13 (System, Settings, Fleet, Teams, Themes, Hooks, Sidebar)
- [x] 41-03-PLAN.md -- Deep link sweep + log analysis
- [x] 41-04-PLAN.md -- Agent A gate review (13/13 PASS)
- [x] 41-05-PLAN.md -- Agent B gate review (GATE PASS)
- [ ] 41-06-PLAN.md -- Gap closure: fix Hooks buttons, Home nav title, Sessions search, Themes routing
- [ ] 41-07-PLAN.md -- Gap closure: rebuild, re-screenshot 4 screens, update verification

---

### Phase 42: iPad Full Validation
**Goal**: Every screen on iPad renders correctly in the split-view layout, sidebar selection syncs with the active screen, iPad-specific layout issues are fixed on the spot, all iPad screenshots are reviewed by two independent agents, and cross-device comparison confirms parity between iPhone and iPad evidence
**Depends on**: Phase 41 (iPhone validation complete and evidence gate passed -- the post-fix binary is what iPad tests against)
**Requirements**: IPAD-01, IPAD-02, IPAD-03, IPAD-04, IPAD-05, IPAD-06, IPAD-07, GATE-02, GATE-04
**Success Criteria** (what must be TRUE):
  1. NavigationSplitView persistent sidebar is visible on iPad with all expected navigation items
  2. All 12+ screens render correctly in the iPad detail column without stretched, compressed, or overlapping elements
  3. Sidebar selection highlight updates correctly when switching screens (including after deep link navigation)
  4. Chat view uses the full detail column width appropriately -- message bubbles, input field, and toolbar are properly sized
  5. Any iPad-specific layout fix has a corresponding commit, rebuild on both simulators, and re-validation screenshot
  6. All iPad screenshots are organized with numbered naming in the evidence directory
  7. **Evidence gate:** Agent A produces an independent verdict document with PASS/FAIL per iPad screen; Agent B produces an independent verdict document with PASS/FAIL per iPad screen; 2/2 agreement required on every screen -- any disagreement triggers re-investigation, fix, and re-validation within this phase
  8. Cross-device comparison: agents confirm no regression between iPhone evidence (from Phase 41) and iPad evidence -- layout differences are intentional (split-view vs stack), not bugs


## Progress

**v2.0 Execution Order:** Phase 11 -> 12 -> 13 -> 14 -> 15 -> 16 -> 17

**v3.0 Execution Order:** Phase 18 -> 19 -> 20 -> 21 -> 22 -> 23 -> 24

**v1.5 Execution Order:** Phase 25 -> 26 -> 27 -> 28 -> 29 -> 30 -> 31 -> 32

**v3.1 Execution Order:** Phase 33 -> 34 -> 35 -> 36 -> 37 -> 38

**v3.5 Execution Order:** Phase 40 -> 41 -> 42

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-10 | v1.0 | 10/10 | Complete | 2026-02-21 |
| 11. Launch & Baseline | v2.0 | 2/2 | Complete | 2026-02-22 |
| 12. Service Layer | v2.0 | 1/1 | Complete | 2026-02-23 |
| 13. ViewModel & Model | v2.0 | 2/2 | Complete | 2026-02-23 |
| 14. SSE & Background | v2.0 | 1/1 | Complete | 2026-02-23 |
| 15. View Layer Rendering | v2.0 | 3/3 | Complete | 2026-02-23 |
| 16. Cross-Platform Verify | v2.0 | 1/1 | Complete | 2026-02-23 |
| 17. Regression Tests | v2.0 | 2/2 | Complete | 2026-02-24 |
| 18. CRITICAL Fixes | v3.0 | 4/4 | Complete | 2026-02-22 |
| 19. Concurrency + Memory HIGH | v3.0 | 3/3 | Complete | 2026-02-22 |
| 20. Architecture + Performance HIGH | v3.0 | 4/4 | Complete | 2026-02-22 |
| 21. Navigation + Codable HIGH | v3.0 | 2/2 | Complete | 2026-02-22 |
| 22. Energy + Build + A11Y + Networking HIGH | v3.0 | 3/3 | Complete | 2026-02-22 |
| 23. All MEDIUM + LOW Issues | v3.0 | 7/7 | Complete | 2026-02-22 |
| 24. Validation + Documentation | v3.0 | 1/1 | Complete | 2026-02-23 |
| 25. Concurrency HIGH + Swift 6 Blockers | v1.5 | 2/2 | Complete | 2026-02-24 |
| 26. Concurrency MEDIUM + LOW | v1.5 | 2/2 | Complete | 2026-02-24 |
| 27. Energy + Memory | v1.5 | 3/3 | Complete | 2026-02-24 |
| 28. SwiftUI Performance | v1.5 | 2/2 | Complete | 2026-02-24 |
| 29. Testing CRITICAL -- Sleep Replacement | v1.5 | 2/2 | Complete | 2026-02-24 |
| 30. Testing Infrastructure | v1.5 | 2/2 | Complete | 2026-02-24 |
| 31. Swift 6 Preparation | v1.5 | 2/2 | Complete | 2026-02-24 |
| 32. Final Validation | v1.5 | 2/2 | Complete | 2026-02-24 |
| 33. Navigation & UX Overhaul | v3.1 | 3/3 | Complete | 2026-02-25 |
| 34. Host Profiles Fix + Redesign | v3.1 | 3/3 | Complete | 2026-02-25 |
| 35. Settings & Config Sync | v3.1 | 2/2 | Complete | 2026-02-25 |
| 36. Browse, Skills & Plugins | v3.1 | 3/3 | Complete | 2026-02-25 |
| 37. System Monitor & Themes | v3.1 | 2/2 | Complete | 2026-02-25 |
| 38. Cross-Platform Validation | v3.1 | 2/2 | Complete | 2026-02-25 |
| 39. Gap Closure | v3.1 | 0/0 | Complete | 2026-02-25 |
| 40. Environment Setup & Screen Inventory | v3.5 | 0/0 | Not started | - |
| 41. iPhone Full Validation + Deep Links | 5/5 | Complete   | 2026-02-25 | - |
| 42. iPad Full Validation | v3.5 | 0/0 | Not started | - |
