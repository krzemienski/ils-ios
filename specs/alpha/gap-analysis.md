# ILS iOS — Comprehensive Gap Analysis

Generated: 2026-02-07 | Branch: `design/v2-redesign` | 80 commits on branch

---

## Summary Table

| # | Spec | Phase Reached | Tasks Done/Total | % Complete | Commits | Key Gaps |
|---|------|--------------|------------------|------------|---------|----------|
| 1 | **rebuild-ground-up** | COMPLETE | 46/46 | 100% | ~30 | None — fully validated with 46 evidence screenshots |
| 2 | **app-enhancements** | Tasks (executed) | 38/39 | 97% | ~18 | Missing: visual evidence capture (5P.3) |
| 3 | **remaining-audit-fixes** | Tasks (executed) | 23/29 | 79% | ~8 | Missing: CI/PR/final AC checklist (quality gates only) |
| 4 | **ios-app-polish** | COMPLETE | 20/20 | 100% | 3 | None — 13 scenarios validated with 42 screenshots |
| 5 | **ios-app-polish2** | Tasks (partial) | 36/63 | 57% | ~13 | 27 unchecked tasks BUT most were completed by rebuild-ground-up |
| 6 | **polish-again** | Tasks (partial) | 35/53 | 66% | ~8 | 18 remaining: 10 chat scenarios, CI, PR, audits |
| 7 | **agent-teams** | Tasks (planned) | 0/38 | 0% | 0 | Entirely unimplemented — new feature |
| 8 | **ils-complete-rebuild** | Tasks (partial) | 3/42 | 7% | 3 | Largely superseded by other specs |
| 9 | **app-improvements** | Research only | 0/0 | 0% | 0 | Abandoned at research phase |
| 10 | **finish-app** | Empty | N/A | 0% | 0 | Empty directory, no files |

---

## Detailed Findings Per Spec

### 1. rebuild-ground-up — COMPLETE (46/46)

**What was planned:** Complete front-end rebuild with cyberpunk theme, sidebar navigation, 12 themes, AI Assistant Cards for chat, iPad layout, and component library.

**What was implemented:**
- 12-theme system (10 dark + 2 light) with AppTheme protocol, 42 design tokens
- Sidebar-first navigation replacing TabView
- Full ChatView rebuild with UserMessageCard/AssistantCard pattern
- CodeBlockView, MarkdownTextView, ToolCallAccordion, ThinkingSection rebuilt
- HomeView dashboard, SystemMonitorView, BrowserView, SettingsView rebuilt
- ThemePickerView with live switching
- iPad persistent sidebar layout
- 13 dead files deleted, models extracted
- 46 evidence screenshots captured

**Gaps:** None. This is the most complete and validated spec.

**Commits:** c63334bc0 through 7fd8b7a64 (30+ commits, Feb 7)

---

### 2. app-enhancements — NEAR-COMPLETE (38/39)

**What was planned:** Chat rendering overhaul (MarkdownUI + HighlightSwift), streaming hardening (SSE event IDs, exponential backoff), backend robustness (ErrorMiddleware, pagination, DI), and audit fix absorption.

**What was implemented (all committed):**
- MarkdownUI replaces 299-line custom parser
- HighlightSwift replaces keyword-based syntax highlighting with line numbers
- ILSCodeHighlighter bridge for MarkdownUI code blocks
- Enhanced ToolCallAccordion (structured inputs, output truncation)
- Enhanced ThinkingSection (markdown rendering, char count)
- Message context menu (copy/retry/delete) + expand-all button
- SSE event IDs + ring buffer replay on backend
- Exponential backoff in SSEClient (was linear)
- Timer replaced with Task-based batching in ChatViewModel
- Auto-scroll tracking + jump-to-bottom FAB + streaming stats
- ILSErrorMiddleware for structured JSON errors
- Request validation in ChatController
- Sessions pagination
- ProjectsController.show() optimization
- print()/debugLog() replaced with structured Logger (backend)
- print() replaced with AppLogger (iOS)
- DispatchQueue.asyncAfter replaced with Task.sleep everywhere
- Concurrency safety audit ([weak self], decoder isolation)
- DateFormatters namespace extraction
- Hardcoded fonts replaced with ILSTheme
- Accessibility labels added (8+)
- FileSystemService DI across 7 controllers
- UnsafeMutablePointer replaced with actor in SystemController

**Gaps:**
- **5P.3**: Visual evidence capture not done (code changes are all committed and verified via build)

**Commits:** 1c85d8fc8 through 3363b8b43 (18 commits)

---

### 3. remaining-audit-fixes — MOSTLY COMPLETE (23/29)

**What was planned:** Fix all MEDIUM + LOW severity issues from 6-domain audit (concurrency, memory, architecture, performance, networking, accessibility). 43 issues across 28 files.

**What was implemented (all committed):**
- APIClient: scoped cache invalidation, skip final retry sleep
- SSEClient: exponential backoff, print to AppLogger
- ILSAppApp: weak capture, didSet to method, remove objectWillChange
- ChatViewModel: Timer to Task, cancellables cleanup
- SystemMetricsViewModel: dedicated URLSession
- TunnelSettingsView: DispatchQueue to Task, accessibility labels
- SessionsListView: static formatters namespace, font theme
- SkillsViewModel: didSet to method
- ChatView: DispatchQueue to Task
- MetricsWebSocketClient: WebSocket fallback reset timer
- Hardcoded fonts replaced (6 occurrences)
- StatusBadge augmented with icon for WCAG
- CommandPaletteView print() removed
- AppLogger categories normalized
- Task cancellation paths verified
- Build + install + screenshot validation passed

**Gaps (all quality gate/PR tasks, no code remaining):**
- 4.1: Full local CI with strict warnings
- 4.2: Create PR and verify CI
- 4.3: AC checklist verification
- 5.1-5.3: PR lifecycle (monitor CI, address reviews, final validation)

**Note:** No git remote configured, so PR tasks were skipped by design.

**Commits:** bc1d2c610 through 233bf2039 (audit fixes), then merged into app-enhancements commits

---

### 4. ios-app-polish — COMPLETE (20/20)

**What was planned:** Comprehensive functional polish fixing broken flows. 13 user scenarios (first launch, sessions, chat, fork, MCP, settings, plugins, skills, projects, config, cancel).

**What was implemented (3 commits):**
- ServerSetupSheet for first-run onboarding
- Deterministic project IDs (CryptoKit SHA256)
- Real plugin install via git clone
- Cancel button wired to backend
- Session creation auto-navigates to ChatView
- Dashboard recent sessions tappable
- Fork alert with "Open Fork" auto-navigate
- Marketplace search: client-side filtering
- Disconnected banner improvements
- 14 dead files deleted (SSH, Fleet, Config mocks)
- Settings/Projects cleaned up
- Connection logic centralized

**Gaps:** None. All 13 scenarios validated with 42 screenshots. All 10 acceptance criteria confirmed programmatically.

**Evidence:** `.omc/evidence/ios-app-polish/` (42 files)

---

### 5. ios-app-polish2 — PARTIALLY COMPLETE (36/63)

**What was planned:** 63 tasks across 12 phases — navigation overhaul (TabView), feature parity, system monitoring, Cloudflare tunnel, chat rendering, onboarding, UI/UX redesign, cleanup, accessibility, validation.

**What was implemented (13 commits):**
- 5-tab TabView navigation (Dashboard/Sessions/Projects/System/Settings)
- System monitoring (CPU/Memory/Disk/Network charts, processes, file browser)
- Cloudflare tunnel integration (TunnelService + TunnelSettingsView)
- Chat rendering (markdown, CodeBlockView, ToolCallAccordion, ThinkingSection)
- Enhanced onboarding (Local/Remote/Tunnel modes with ConnectionSteps)
- Entity color system (6 types)
- StatCard/SparklineChart/EmptyEntityState/SkeletonRow/ShimmerModifier
- Session rename, export, advanced creation options
- Accessibility labels + reduce motion support
- 6 dead files removed

**27 unchecked tasks analysis:** Most of these were SUPERSEDED by later specs:
- Phase 0 (EntityType, ClaudeCodeSDK removal, dark mode, health check) — **superseded by rebuild-ground-up** which rebuilt the entire theme
- Phase 1.4-1.5, 2.8 (verify checkpoints) — skipped, covered by later builds
- Phase 3 (system monitoring backend) — **was implemented** (commits exist for SystemController, WebSocket metrics), tasks just not checked off
- Phase 4.6, 5.5, 6.6, 7.4 (verify checkpoints) — skipped
- Phase 9 (cleanup/accessibility) — **superseded by remaining-audit-fixes and rebuild-ground-up**
- Phase 10-11 (validation, PR) — not executed (no remote)

**Effective completion: ~85%** (most unchecked items were done by later specs or are verify/PR tasks)

---

### 6. polish-again — IN PROGRESS (35/53)

**What was planned:** 53 tasks across 11 phases — critical bug fixes, architecture refactoring, medium/low fixes, 10 complex chat scenarios, CI/PR.

**What was implemented (8+ commits):**
- Theme ID fix (ghost -> ghost-protocol, electric -> electric-grid) with UserDefaults migration
- Dead properties removed (isServerConnected, serverConnectionInfo)
- AppState decomposed into ConnectionManager + PollingManager
- SettingsView split into 5 focused files
- MCPServerItem/PluginItem unified to ILSShared types
- ShareSheet extracted to shared location
- ConnectionBanner consolidated
- Sidebar wired, dead code deleted
- NotificationPreferences persistence fixed
- FileBrowser migrated to APIClient
- StreamingIndicator timer leak fixed
- EntityType.color/gradient dead code removed
- Contrast/colors/labels documentation fixes

**18 remaining tasks:**
- **10 chat scenarios (CS1-CS10):** Basic send/receive, streaming cancellation, tool call rendering, error recovery, fork+navigate, rapid-fire, theme switching during chat, long message with code blocks, external session browsing, session rename+export — ALL UNVALIDATED
- **3 CI/audit tasks:** Full build, grep audit (dead code/duplicates), file size audit
- **2 meta tasks:** Evidence index, AC checklist
- **2 PR tasks:** Create PR, verify
- **1 verify checkpoint**

**Key insight:** The most critical remaining work from this spec is the **10 chat scenarios** — these are the only comprehensive end-to-end chat validation tests planned across ALL specs, and none have been executed.

---

### 7. agent-teams — NOT STARTED (0/38)

**What was planned:** 38 tasks across 5 phases — backend (shared models, TeamsFileService, TeamsExecutorService, TeamsController, SSHController, FleetController), stub fixes (14 identified stubs), iOS UI (ViewModels, views, navigation, settings), functional validation, PR.

**What was implemented:** Nothing. Design and task planning were completed and approved, but execution never started.

**Key features not built:**
- Agent Teams create/manage/monitor UI
- Team task list with CRUD
- Inter-agent messaging view
- Teammate spawn/shutdown
- Real SSH testing (replacing simulated testConnection)
- Fleet management with real API data
- Config profiles/overrides/history from API
- Session templates from API
- Real plugin install (already done in ios-app-polish, may still need verification)
- Extended Thinking / Co-Author toggles wired to backend
- Config History restore functionality
- "Coming Soon" markers for CloudSync/Automation/Notifications

**Note:** This is the only spec with an entirely NEW feature (Agent Teams). All other specs improve/fix existing functionality.

---

### 8. ils-complete-rebuild — LARGELY SUPERSEDED (3/42)

**What was planned:** 42 tasks for full spec compliance — SSH foundation (Citadel), design tokens, GitHub integration, enhanced views, model alignment. Gap analysis against original `ils.md` and `ils-spec.md` documents.

**What was implemented (3 tasks):**
- 1.1: Citadel dependency + shared models added
- 1.4: Backend SSHService created
- 1.5: AuthController + server/status wired

**Analysis:** This spec was created when the app was much less complete. Since then, ios-app-polish, ios-app-polish2, rebuild-ground-up, and app-enhancements have implemented most of the needed functionality. The remaining 39 tasks include:
- SSH features (still relevant but deprioritized)
- GitHub integration for skills/plugins (partially done)
- Design token alignment (done by rebuild-ground-up)
- View enhancements (done by multiple specs)
- Model alignment (partially done by polish-again)

**What's still relevant from this spec:**
- GitHub skill search/install backend improvements
- Config scope write (user/project/local)
- App Store preparation (Privacy Manifest, metadata)
- Full spec endpoint parity analysis

---

### 9. app-improvements — ABANDONED (0/0)

**What was planned:** General UX improvements and polish.

**Status:** Only reached research phase. No requirements, design, or tasks were ever created. Superseded by the more focused ios-app-polish and ios-app-polish2 specs.

---

### 10. finish-app — EMPTY (N/A)

**What was planned:** Unknown — directory exists but contains no files.

---

## Overall Assessment

### What's Been Done (Cumulative)

The ILS iOS app has undergone massive development across 80+ commits on `design/v2-redesign`:

1. **Complete front-end rebuild** with 12-theme cyberpunk design system (rebuild-ground-up)
2. **Chat rendering overhaul** with MarkdownUI + HighlightSwift (app-enhancements)
3. **Streaming hardening** — SSE event IDs, exponential backoff, Task-based batching (app-enhancements)
4. **Backend robustness** — ErrorMiddleware, pagination, DI, structured logging (app-enhancements)
5. **System monitoring** — CPU/Memory/Disk/Network with charts, process list, file browser (ios-app-polish2)
6. **Cloudflare tunnel integration** (ios-app-polish2)
7. **Architecture improvements** — AppState decomposition, SettingsView split, model unification (polish-again)
8. **Audit fixes** — 43 issues across 6 domains (remaining-audit-fixes)
9. **Functional validation** — 13 scenarios with 42+ screenshots (ios-app-polish)
10. **Accessibility** — labels, WCAG compliance, reduce motion (remaining-audit-fixes + rebuild-ground-up)

### What's NOT Been Done (Critical Gaps)

| Priority | Gap | Source Spec | Impact |
|----------|-----|-------------|--------|
| **P0** | 10 chat scenarios never validated | polish-again | No E2E proof chat actually works end-to-end |
| **P0** | Visual evidence for app-enhancements features | app-enhancements | MarkdownUI, HighlightSwift, tool calls not screenshot-validated |
| **P1** | Agent Teams feature | agent-teams | Entire new feature not built (38 tasks) |
| **P1** | 14 stub fixes (SSH test, Fleet, Config, Toggles) | agent-teams | User-facing buttons/toggles that do nothing |
| **P2** | GitHub skill/plugin discovery backend | ils-complete-rebuild | Search works but install reliability unverified |
| **P2** | Full grep audit for dead code/duplicates | polish-again | May have residual dead code |
| **P2** | File size audit (no file >500 lines) | polish-again | Some files may still be oversized |
| **P3** | SSH remote management | ils-complete-rebuild | Backend SSHService exists, iOS never calls it |
| **P3** | App Store preparation | ils-complete-rebuild | Privacy Manifest, screenshots, metadata |
| **P3** | iCloud sync | multiple | Not implemented anywhere |

### Key Observations

1. **Spec proliferation problem**: 10 specs were created over 10 days, with significant overlap. rebuild-ground-up superseded ios-app-polish2's UI work. app-enhancements absorbed remaining-audit-fixes. polish-again overlaps with multiple specs.

2. **Validation debt**: The most critical gap is that **no spec has ever validated the complete chat flow end-to-end** with the new MarkdownUI/HighlightSwift rendering against a live backend. The 10 chat scenarios from polish-again are the most important unfinished work.

3. **Stub/mock debt from agent-teams audit**: 14 stubs were identified (SSH test simulated, Fleet hardcoded, Config views with sample data, toggles that do nothing). These exist regardless of whether Agent Teams ships.

4. **Architecture is solid**: The cumulative refactoring (AppState decomposition, SettingsView split, model unification, DI injection, structured logging) has significantly improved code quality.

5. **Theme system is complete**: 12 themes with 42 design tokens, live switching, iPad layout — this is production-ready.

---

## Recommendations for Alpha Spec

### Must Carry Forward (P0)

1. **10 chat scenarios from polish-again** (CS1-CS10) — These are the single most important validation gap. Every chat feature (streaming, cancellation, tool calls, error recovery, fork, export, rename) needs E2E proof.

2. **Visual evidence capture** — Screenshot validation of MarkdownUI rendering, HighlightSwift code blocks, tool call accordions, thinking sections against live backend.

3. **Stub fix subset** — At minimum fix the 3 CRITICAL stubs: Extended Thinking toggle (does nothing), Co-Author toggle (does nothing), Config History restore (does nothing). These deceive users.

### Should Carry Forward (P1)

4. **Agent Teams** — If this feature is still desired, the 38-task plan from agent-teams spec is ready to execute. Could be phased: backend first, then iOS UI.

5. **Remaining stub fixes** — Wire Fleet, Config views, Session Templates to real APIs. Mark CloudSync/Automation/Notifications as "Coming Soon."

6. **Final code quality audit** — grep for dead code, file size audit, ensure no file >500 lines.

### Can Defer (P2/P3)

7. **SSH remote management** — Backend SSHService exists but iOS never uses it. Low user value for v1.
8. **App Store preparation** — Privacy Manifest, screenshots, metadata. Important but not alpha-blocking.
9. **iCloud sync** — No implementation exists anywhere. Future feature.
10. **GitHub integration improvements** — Skill search/install works, just needs reliability polish.
