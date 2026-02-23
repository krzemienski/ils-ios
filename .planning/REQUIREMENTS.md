# Requirements -- v3.0 Comprehensive Audit Remediation

**Milestone:** v3.0 Comprehensive Audit Remediation
**Created:** 2026-02-22
**Status:** Approved
**Audit Source:** scratch/audit-findings-2026-02-22.md (165 issues from 15 Axiom audits)

---

## Concurrency Safety (18 issues: 2 CRITICAL, 7 HIGH, 6 MEDIUM, 3 LOW)

- [x] **CONC-01** [CRITICAL]: Convert AppLogger from `@unchecked Sendable` to actor or `OSAllocatedUnfairLock` — `Services/AppLogger.swift:4`
- [x] **CONC-02** [CRITICAL]: Add `@MainActor` to SyntaxHighlighter enum, remove `nonisolated(unsafe)` on `highlighterCache` — `Utils/SyntaxHighlighter.swift:14`
- [x] **CONC-03** [HIGH]: Fix SkillsViewModel `nonisolated(unsafe)` on Task property — `ViewModels/SkillsViewModel.swift:39`
- [x] **CONC-04** [HIGH]: Fix MCPViewModel `nonisolated(unsafe)` on healthTimer — `ViewModels/MCPViewModel.swift:17`
- [x] **CONC-05** [HIGH]: Fix SystemMetricsViewModel `nonisolated(unsafe)` pattern — `ViewModels/SystemMetricsViewModel.swift:34`
- [x] **CONC-06** [HIGH]: Fix NotificationManager `@preconcurrency` delegate isolation mismatch — `ILSMacApp/Managers/NotificationManager.swift:151`
- [x] **CONC-07** [HIGH]: Fix WindowAccessor `DispatchQueue.main.async` accessing @MainActor state — `ILSMacApp/Views/SessionWindowView.swift:101`
- [x] **CONC-08** [HIGH]: Fix WindowFrameDelegate.debounceSave GCD accessing @MainActor — `ILSMacApp/Managers/WindowManager.swift:252`
- [x] **CONC-09** [HIGH]: Fix SSEClient `Task.detached` accessing @MainActor self — `Services/SSEClient.swift:130`
- [ ] **CONC-10** [MEDIUM]: Fix ClaudeExecutorService.readQueue access from nonisolated context
- [ ] **CONC-11** [MEDIUM]: Fix HostProfilesViewModel deinit accessing @MainActor properties
- [ ] **CONC-12** [MEDIUM]: Fix SpotlightIndexer callback footgun
- [ ] **CONC-13** [MEDIUM]: Fix SyncCoordinator notification observer Task pattern
- [ ] **CONC-14** [MEDIUM]: Fix DashboardViewModel Task.detached captures
- [ ] **CONC-15** [MEDIUM]: Fix SessionsViewModel Task.detached cache writes
- [ ] **CONC-16** [LOW]: Minor concurrency pattern improvement 1
- [ ] **CONC-17** [LOW]: Minor concurrency pattern improvement 2
- [ ] **CONC-18** [LOW]: Minor concurrency pattern improvement 3

## Energy Efficiency (18 issues: 3 CRITICAL, 4 HIGH, 7 MEDIUM, 4 LOW)

- [x] **ENRG-01** [CRITICAL]: Reduce Live Activity timer from 0.5s to 1.0s or SwiftUI animation — `LiveActivity/ILSLiveActivity.swift:182`
- [x] **ENRG-02** [CRITICAL]: Replace MCP health poll full server reload with lightweight health-only endpoint — `ViewModels/MCPViewModel.swift:175`
- [x] **ENRG-03** [CRITICAL]: Add exponential backoff to Teams 15s poll — `ViewModels/TeamsViewModel.swift:211`
- [ ] **ENRG-04** [HIGH]: Pause CyberpunkEffects PulsingGlow when view not visible
- [ ] **ENRG-05** [HIGH]: Close SSE connection on app background
- [ ] **ENRG-06** [HIGH]: Batch network requests on rapid navigation
- [ ] **ENRG-07** [HIGH]: Migrate HostProfilesViewModel Timer.scheduledTimer to Task
- [ ] **ENRG-08** [MEDIUM]: Pause WebSocket metrics when view not visible
- [ ] **ENRG-09** [MEDIUM]: Optimize Background URLSession configuration
- [ ] **ENRG-10** [MEDIUM]: Gate log viewer polling on visibility
- [ ] **ENRG-11** [MEDIUM]: Reduce animation complexity for Low Power Mode
- [ ] **ENRG-12** [MEDIUM]: Consolidate redundant health checks across ViewModels
- [ ] **ENRG-13** [MEDIUM]: Add adaptive polling based on battery level
- [ ] **ENRG-14** [MEDIUM]: Set Timer tolerance on all timers
- [ ] **ENRG-15** [LOW]: Minor energy pattern improvement 1
- [ ] **ENRG-16** [LOW]: Minor energy pattern improvement 2
- [ ] **ENRG-17** [LOW]: Minor energy pattern improvement 3
- [ ] **ENRG-18** [LOW]: Minor energy pattern improvement 4

## Swift Performance (18 issues: 1 CRITICAL, 5 HIGH, 8 MEDIUM, 4 LOW)

- [x] **SPERF-01** [CRITICAL]: MCPViewModel.checkHealth() calls full loadServers() every 30s (same root cause as ENRG-02) — `ViewModels/MCPViewModel.swift:175`
- [x] **SPERF-02** [HIGH]: Eliminate `any AppTheme` existential boxing in ThemeManager
- [x] **SPERF-03** [HIGH]: Reduce ChatMessage struct copy during streaming
- [x] **SPERF-04** [HIGH]: Parallelize sequential API calls in DashboardViewModel timer
- [x] **SPERF-05** [HIGH]: Optimize SessionsController sorting for 22K+ sessions
- [x] **SPERF-06** [HIGH]: MCPViewModel.checkHealth() full reload (deduplicates with SPERF-01)
- [ ] **SPERF-07** [MEDIUM]: Reduce String allocations in message rendering loop
- [ ] **SPERF-08** [MEDIUM]: Eliminate redundant dictionary lookups in sidebar
- [ ] **SPERF-09** [MEDIUM]: Fix Array copy in session filtering
- [ ] **SPERF-10** [MEDIUM]: Add generic specialization hints for non-specialized generic calls
- [ ] **SPERF-11** [MEDIUM]: Reduce unnecessary ARC overhead in closures
- [ ] **SPERF-12** [MEDIUM]: Cache Date formatting
- [ ] **SPERF-13** [MEDIUM]: Pre-compile Regex patterns (avoid compilation on each call)
- [ ] **SPERF-14** [MEDIUM]: Avoid re-sorting pre-sorted data
- [ ] **SPERF-15** [LOW]: Minor swift performance improvement 1
- [ ] **SPERF-16** [LOW]: Minor swift performance improvement 2
- [ ] **SPERF-17** [LOW]: Minor swift performance improvement 3
- [ ] **SPERF-18** [LOW]: Minor swift performance improvement 4

## SwiftUI Architecture (20 issues: 4 CRITICAL, 9 HIGH, 5 MEDIUM, 2 LOW)

- [x] **ARCH-01** [CRITICAL]: Route MacChatView API calls through SessionsViewModel — `ILSMacApp/Views/MacChatView.swift:75-87`
- [x] **ARCH-02** [CRITICAL]: Add do/catch to MacChatView unhandled Task error — `ILSMacApp/Views/MacChatView.swift:75-77`
- [x] **ARCH-03** [CRITICAL]: Extract NewSessionView 3 inline async flows to NewSessionViewModel — `Views/Sessions/NewSessionView.swift:794-870`
- [x] **ARCH-04** [CRITICAL]: Add `private` to MacSettingsView @State — `ILSMacApp/Views/MacSettingsView.swift:32,35`
- [x] **ARCH-05** [HIGH]: Extract CommandPaletteView dual computed properties to ViewModel — `Views/Chat/CommandPaletteView.swift:139-146`
- [x] **ARCH-06** [HIGH]: Extract NewSessionView.filteredRecentSessions — `Views/Sessions/NewSessionView.swift:352-360`
- [x] **ARCH-07** [HIGH]: Extract SidebarRootView dictionary construction — `Views/Root/SidebarRootView.swift:122`
- [x] **ARCH-08** [HIGH]: Remove PollingManager SwiftUI import (testability violation) — `Services/PollingManager.swift:1`
- [x] **ARCH-09** [HIGH]: Fix async operations in Binding setters in SettingsConfigSection — `Views/Settings/SettingsConfigSection.swift:43-48,83-87,104-108`
- [x] **ARCH-10** [HIGH]: Route SettingsView.testConnection() through ViewModel — `Views/Settings/SettingsView.swift:100-104`
- [x] **ARCH-11** [HIGH]: Extract SettingsConfigSection.hookEventBreakdown — `Views/Settings/SettingsConfigSection.swift:451-458`
- [x] **ARCH-12** [HIGH]: Extract FileBrowserView.sortedEntries — `Views/System/FileBrowserView.swift:146-152`
- [x] **ARCH-13** [HIGH]: Extract PermissionRequestModal.formatToolInput() — `Views/Chat/PermissionRequestModal.swift:191-201`
- [ ] **ARCH-14** [MEDIUM]: Consider splitting SessionsViewModel (24 properties)
- [ ] **ARCH-15** [MEDIUM]: Remove redundant ProjectsViewModel in NewSessionView
- [ ] **ARCH-16** [MEDIUM]: Convert fire-and-forget Tasks to .task modifier
- [ ] **ARCH-17** [MEDIUM]: Deduplicate toast timer pattern across 5 views
- [ ] **ARCH-18** [MEDIUM]: Make helper functions on View structs non-public
- [ ] **ARCH-19** [LOW]: Minor architecture improvement 1
- [ ] **ARCH-20** [LOW]: Minor architecture improvement 2

## SwiftUI Performance (14 issues: 2 CRITICAL, 4 HIGH, 7 MEDIUM, 1 LOW)

- [x] **UIPERF-01** [CRITICAL]: Cache SyntaxHighlighter in CodeBlockView with @State + .task(id:) — `Views/Chat/CodeBlockView.swift:156`
- [x] **UIPERF-02** [CRITICAL]: Pre-compute Set for ThemePickerView.availableThemes — `Views/Settings/ThemePickerView.swift:203`
- [x] **UIPERF-03** [HIGH]: Convert SyntaxHighlighter keyword arrays to Set for O(1) lookup — `Utils/SyntaxHighlighter.swift` (17+ sites)
- [x] **UIPERF-04** [HIGH]: Pre-compute classifyProcess() in ViewModel — `Views/System/ProcessListView.swift:114,169`
- [x] **UIPERF-05** [HIGH]: Move Data(contentsOf:) off main thread in ThemeMarketplaceView — `Views/Themes/ThemeMarketplaceView.swift:278`
- [x] **UIPERF-06** [HIGH]: Cache cascading computed properties in CodeBlockView — `Views/Chat/CodeBlockView.swift:17-32`
- [ ] **UIPERF-07** [MEDIUM]: Reduce ThemeEditorView 50+ @State properties
- [ ] **UIPERF-08** [MEDIUM]: Cache logColor() per row in LogViewerView
- [ ] **UIPERF-09** [MEDIUM]: Eliminate duplicate SessionsViewModel in MacDashboardView
- [ ] **UIPERF-10** [MEDIUM]: Eliminate duplicate SessionsViewModel in MacSessionsListView
- [ ] **UIPERF-11** [MEDIUM]: Cache CommandPaletteView skills fetch
- [ ] **UIPERF-12** [MEDIUM]: Fix ForEach using id: \.offset in several views
- [ ] **UIPERF-13** [MEDIUM]: Cache expandedSections evaluation per DisclosureGroup
- [ ] **UIPERF-14** [LOW]: Minor SwiftUI performance improvement

## SwiftUI Navigation (13 issues: 0 CRITICAL, 4 HIGH, 6 MEDIUM, 3 LOW)

- [ ] **NAV-01** [HIGH]: Remove dead NavigationPath with no destinations — `Views/Root/SidebarRootView.swift:64,186`
- [ ] **NAV-02** [HIGH]: Fix nested NavigationStack in sheet presentations
- [ ] **NAV-03** [HIGH]: Add NavigationStack to macOS detail column — `ILSMacApp/Views/MacContentView.swift`
- [ ] **NAV-04** [HIGH]: Add macOS hooks screen routing — `ILSMacApp/Views/MacContentView.swift`
- [ ] **NAV-05** [MEDIUM]: Add missing navigationDestination for several types
- [ ] **NAV-06** [MEDIUM]: Harmonize iOS/macOS navigation patterns
- [ ] **NAV-07** [MEDIUM]: Validate all deep link routes
- [ ] **NAV-08** [MEDIUM]: Add proper sheet dismiss handling
- [ ] **NAV-09** [MEDIUM]: Persist tab selection
- [ ] **NAV-10** [MEDIUM]: Preserve navigation state on orientation change
- [ ] **NAV-11** [LOW]: Minor navigation improvement 1
- [ ] **NAV-12** [LOW]: Minor navigation improvement 2
- [ ] **NAV-13** [LOW]: Minor navigation improvement 3

## Codable & Error Handling (13 issues: 0 CRITICAL, 6 HIGH, 5 MEDIUM, 2 LOW)

- [ ] **CODBL-01** [HIGH]: Convert `try?` to `do/catch` in APIClient — `Services/APIClient.swift`
- [ ] **CODBL-02** [HIGH]: Convert `try?` to `do/catch` in CacheService — `Services/CacheService.swift`
- [ ] **CODBL-03** [HIGH]: Convert `try?` to `do/catch` in AuthService (Keychain) — `Services/AuthService.swift`
- [ ] **CODBL-04** [HIGH]: Set explicit dateDecodingStrategy on JSONDecoders
- [ ] **CODBL-05** [HIGH]: Replace manual JSON building with Codable in backend controllers
- [ ] **CODBL-06** [HIGH]: Add validation for string-based enum decoding in DTOs
- [ ] **CODBL-07** [MEDIUM]: Replace manual date string parsing with DateFormatter
- [ ] **CODBL-08** [MEDIUM]: Standardize error handling in decoders
- [ ] **CODBL-09** [MEDIUM]: Add CodingKeys for snake_case mapping
- [ ] **CODBL-10** [MEDIUM]: Replace optional chaining hiding missing required fields
- [ ] **CODBL-11** [MEDIUM]: Add validation of decoded values
- [ ] **CODBL-12** [LOW]: Minor codable improvement 1
- [ ] **CODBL-13** [LOW]: Minor codable improvement 2

## Build Optimization (8 issues: 0 CRITICAL, 2 HIGH, 3 MEDIUM, 3 LOW)

- [ ] **BUILD-01** [HIGH]: Optimize dSYM format for debug builds — project.pbxproj
- [ ] **BUILD-02** [HIGH]: Enable ONLY_ACTIVE_ARCH for debug — project.pbxproj
- [ ] **BUILD-03** [MEDIUM]: Enable type-checking timing flags
- [ ] **BUILD-04** [MEDIUM]: Fix macOS target compiling all iOS files
- [ ] **BUILD-05** [MEDIUM]: Enable link-time optimization for release
- [ ] **BUILD-06** [LOW]: Minor build improvement 1
- [ ] **BUILD-07** [LOW]: Minor build improvement 2
- [ ] **BUILD-08** [LOW]: Minor build improvement 3

## Accessibility (8 issues: 0 CRITICAL, 3 HIGH, 5 MEDIUM, 0 LOW)

- [ ] **A11Y-01** [HIGH]: Replace fixed font sizes with Dynamic Type in PremiumView — `Views/Premium/PremiumView.swift`
- [ ] **A11Y-02** [HIGH]: Replace fixed font sizes with Dynamic Type in LaunchScreenView — `Views/Launch/LaunchScreenView.swift`
- [ ] **A11Y-03** [HIGH]: Replace fixed font sizes with Dynamic Type in ScreenshotView — `Views/Screenshots/ScreenshotView.swift`
- [ ] **A11Y-04** [MEDIUM]: Add reduce motion checks on animations
- [ ] **A11Y-05** [MEDIUM]: Fix insufficient contrast ratios in some themes
- [ ] **A11Y-06** [MEDIUM]: Add accessibility labels on icon buttons
- [ ] **A11Y-07** [MEDIUM]: Optimize VoiceOver reading order
- [ ] **A11Y-08** [MEDIUM]: Test Dynamic Type at all sizes

## Database Schema (7 issues: 1 CRITICAL, 2 HIGH, 4 MEDIUM, 0 LOW)

- [x] **DB-01** [CRITICAL]: Set PRAGMA foreign_keys via pool configuration callback — `Sources/ILSBackend/App/configure.swift:79-81`
- [ ] **DB-02** [HIGH]: Remove DROP TABLE from all revert() functions — All migration files
- [ ] **DB-03** [HIGH]: Add FK constraints data validation
- [ ] **DB-04** [MEDIUM]: Add indexes on frequently queried columns
- [ ] **DB-05** [MEDIUM]: Implement migration versioning strategy
- [ ] **DB-06** [MEDIUM]: Standardize column naming conventions
- [ ] **DB-07** [MEDIUM]: Add missing NOT NULL constraints

## Networking (7 issues: 0 CRITICAL, 1 HIGH, 4 MEDIUM, 2 LOW)

- [x] **NET-01** [HIGH]: Replace SSH `.acceptAnything()` host key validator — `Services/CitadelSSHService.swift:54`
- [x] **NET-02** [MEDIUM]: Add reconnection timeout to MetricsWebSocketClient
- [x] **NET-03** [MEDIUM]: Add network-state gate to PollingManager
- [ ] **NET-04** [MEDIUM]: Implement request retry with exponential backoff
- [ ] **NET-05** [MEDIUM]: Add certificate pinning
- [ ] **NET-06** [LOW]: Minor networking improvement 1
- [ ] **NET-07** [LOW]: Minor networking improvement 2

## Security (5 issues: 0 CRITICAL, 0 HIGH, 2 MEDIUM, 3 LOW)

- [ ] **SEC-01** [MEDIUM]: Review localhost hardcoding in several files
- [ ] **SEC-02** [MEDIUM]: Surface Keychain migration errors to user
- [ ] **SEC-03** [LOW]: Minor security improvement 1
- [ ] **SEC-04** [LOW]: Minor security improvement 2
- [ ] **SEC-05** [LOW]: Minor security improvement 3

## Memory Lifecycle (4 issues: 0 CRITICAL, 1 HIGH, 2 MEDIUM, 1 LOW)

- [x] **MEM-01** [HIGH]: Migrate HostProfilesViewModel Timer to Task — `ViewModels/HostProfilesViewModel.swift:72`
- [x] **MEM-02** [MEDIUM]: Clean up WindowFrameDelegate when OS closes window
- [x] **MEM-03** [MEDIUM]: Add SystemMetricsViewModel deinit cancellation
- [ ] **MEM-04** [LOW]: Minor memory lifecycle improvement

## SwiftUI Layout (4 issues: 0 CRITICAL, 1 HIGH, 3 MEDIUM, 0 LOW)

- [ ] **LAYOUT-01** [HIGH]: Fix size class identity loss in SidebarRootView — `Views/Root/SidebarRootView.swift`
- [ ] **LAYOUT-02** [MEDIUM]: Fix fixed frames in macOS sheet presentations
- [ ] **LAYOUT-03** [MEDIUM]: Reduce GeometryReader usage in overlay
- [ ] **LAYOUT-04** [MEDIUM]: Replace hardcoded spacing values

## Modernization (8 issues: 0 CRITICAL, 0 HIGH, 6 MEDIUM, 2 LOW)

- [ ] **MOD-01** [MEDIUM]: Framework-required widget patterns (cannot change — document)
- [ ] **MOD-02** [MEDIUM]: Fix minor API deprecation warnings
- [ ] **MOD-03** [MEDIUM]: Modernize legacy string interpolation patterns
- [ ] **MOD-04** [MEDIUM]: Update old-style error handling
- [ ] **MOD-05** [MEDIUM]: Remove unused protocol conformances
- [ ] **MOD-06** [MEDIUM]: Remove redundant type annotations
- [ ] **MOD-07** [LOW]: Minor modernization improvement 1
- [ ] **MOD-08** [LOW]: Minor modernization improvement 2

---

## Cross-Audit Correlations (Shared Root Causes)

These issues span multiple audits and a single fix addresses multiple REQs:

1. **MCPViewModel.checkHealth()** — ENRG-02 + SPERF-01 + SPERF-06 (3 REQs, 1 fix)
2. **SyntaxHighlighter** — CONC-02 + UIPERF-01 + UIPERF-03 (3 REQs, 1 refactor)
3. **CodeBlockView** — UIPERF-01 + UIPERF-06 + SPERF-07 (3 REQs, 1 refactor)
4. **macOS ViewModels** — UIPERF-09 + UIPERF-10 + ARCH-01 (3 REQs, shared fix pattern)
5. **NewSessionView** — ARCH-03 + ARCH-06 (2 REQs, 1 extraction)
6. **HostProfilesViewModel Timer** — MEM-01 + ENRG-07 (2 REQs, 1 migration)

## Severity Summary

| Severity | Count | Target |
|----------|-------|--------|
| CRITICAL | 13 | Must fix — data races, energy waste, architecture violations |
| HIGH | 49 | Should fix — production quality issues |
| MEDIUM | 73 | Nice to fix — code health improvements |
| LOW | 30 | Optional — informational, minor patterns |
| **Total** | **165** | **All targeted for v3.0** |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CONC-01 | Phase 18 | Complete |
| CONC-02 | Phase 18 | Complete |
| CONC-03 | Phase 19 | Complete |
| CONC-04 | Phase 19 | Complete |
| CONC-05 | Phase 19 | Complete |
| CONC-06 | Phase 19 | Complete |
| CONC-07 | Phase 19 | Complete |
| CONC-08 | Phase 19 | Complete |
| CONC-09 | Phase 19 | Complete |
| CONC-10 | Phase 23 | Pending |
| CONC-11 | Phase 23 | Pending |
| CONC-12 | Phase 23 | Pending |
| CONC-13 | Phase 23 | Pending |
| CONC-14 | Phase 23 | Pending |
| CONC-15 | Phase 23 | Pending |
| CONC-16 | Phase 23 | Pending |
| CONC-17 | Phase 23 | Pending |
| CONC-18 | Phase 23 | Pending |
| ENRG-01 | Phase 18 | Complete |
| ENRG-02 | Phase 18 | Complete |
| ENRG-03 | Phase 18 | Complete |
| ENRG-04 | Phase 22 | Pending |
| ENRG-05 | Phase 22 | Pending |
| ENRG-06 | Phase 22 | Pending |
| ENRG-07 | Phase 22 | Pending |
| ENRG-08 | Phase 23 | Pending |
| ENRG-09 | Phase 23 | Pending |
| ENRG-10 | Phase 23 | Pending |
| ENRG-11 | Phase 23 | Pending |
| ENRG-12 | Phase 23 | Pending |
| ENRG-13 | Phase 23 | Pending |
| ENRG-14 | Phase 23 | Pending |
| ENRG-15 | Phase 23 | Pending |
| ENRG-16 | Phase 23 | Pending |
| ENRG-17 | Phase 23 | Pending |
| ENRG-18 | Phase 23 | Pending |
| SPERF-01 | Phase 18 | Complete |
| SPERF-02 | Phase 20 | Complete |
| SPERF-03 | Phase 20 | Complete |
| SPERF-04 | Phase 20 | Complete |
| SPERF-05 | Phase 20 | Complete |
| SPERF-06 | Phase 20 | Complete |
| SPERF-07 | Phase 23 | Pending |
| SPERF-08 | Phase 23 | Pending |
| SPERF-09 | Phase 23 | Pending |
| SPERF-10 | Phase 23 | Pending |
| SPERF-11 | Phase 23 | Pending |
| SPERF-12 | Phase 23 | Pending |
| SPERF-13 | Phase 23 | Pending |
| SPERF-14 | Phase 23 | Pending |
| SPERF-15 | Phase 23 | Pending |
| SPERF-16 | Phase 23 | Pending |
| SPERF-17 | Phase 23 | Pending |
| SPERF-18 | Phase 23 | Pending |
| ARCH-01 | Phase 18 | Complete |
| ARCH-02 | Phase 18 | Complete |
| ARCH-03 | Phase 18 | Complete |
| ARCH-04 | Phase 18 | Complete |
| ARCH-05 | Phase 20 | Complete |
| ARCH-06 | Phase 20 | Complete |
| ARCH-07 | Phase 20 | Complete |
| ARCH-08 | Phase 20 | Complete |
| ARCH-09 | Phase 20 | Complete |
| ARCH-10 | Phase 20 | Complete |
| ARCH-11 | Phase 20 | Complete |
| ARCH-12 | Phase 20 | Complete |
| ARCH-13 | Phase 20 | Complete |
| ARCH-14 | Phase 23 | Pending |
| ARCH-15 | Phase 23 | Pending |
| ARCH-16 | Phase 23 | Pending |
| ARCH-17 | Phase 23 | Pending |
| ARCH-18 | Phase 23 | Pending |
| ARCH-19 | Phase 23 | Pending |
| ARCH-20 | Phase 23 | Pending |
| UIPERF-01 | Phase 18 | Complete |
| UIPERF-02 | Phase 18 | Complete |
| UIPERF-03 | Phase 20 | Complete |
| UIPERF-04 | Phase 20 | Complete |
| UIPERF-05 | Phase 20 | Complete |
| UIPERF-06 | Phase 20 | Complete |
| UIPERF-07 | Phase 23 | Pending |
| UIPERF-08 | Phase 23 | Pending |
| UIPERF-09 | Phase 23 | Pending |
| UIPERF-10 | Phase 23 | Pending |
| UIPERF-11 | Phase 23 | Pending |
| UIPERF-12 | Phase 23 | Pending |
| UIPERF-13 | Phase 23 | Pending |
| UIPERF-14 | Phase 23 | Pending |
| NAV-01 | Phase 21 | Pending |
| NAV-02 | Phase 21 | Pending |
| NAV-03 | Phase 21 | Pending |
| NAV-04 | Phase 21 | Pending |
| NAV-05 | Phase 23 | Pending |
| NAV-06 | Phase 23 | Pending |
| NAV-07 | Phase 23 | Pending |
| NAV-08 | Phase 23 | Pending |
| NAV-09 | Phase 23 | Pending |
| NAV-10 | Phase 23 | Pending |
| NAV-11 | Phase 23 | Pending |
| NAV-12 | Phase 23 | Pending |
| NAV-13 | Phase 23 | Pending |
| CODBL-01 | Phase 21 | Pending |
| CODBL-02 | Phase 21 | Pending |
| CODBL-03 | Phase 21 | Pending |
| CODBL-04 | Phase 21 | Pending |
| CODBL-05 | Phase 21 | Pending |
| CODBL-06 | Phase 21 | Pending |
| CODBL-07 | Phase 23 | Pending |
| CODBL-08 | Phase 23 | Pending |
| CODBL-09 | Phase 23 | Pending |
| CODBL-10 | Phase 23 | Pending |
| CODBL-11 | Phase 23 | Pending |
| CODBL-12 | Phase 23 | Pending |
| CODBL-13 | Phase 23 | Pending |
| BUILD-01 | Phase 22 | Pending |
| BUILD-02 | Phase 22 | Pending |
| BUILD-03 | Phase 23 | Pending |
| BUILD-04 | Phase 23 | Pending |
| BUILD-05 | Phase 23 | Pending |
| BUILD-06 | Phase 23 | Pending |
| BUILD-07 | Phase 23 | Pending |
| BUILD-08 | Phase 23 | Pending |
| A11Y-01 | Phase 22 | Pending |
| A11Y-02 | Phase 22 | Pending |
| A11Y-03 | Phase 22 | Pending |
| A11Y-04 | Phase 23 | Pending |
| A11Y-05 | Phase 23 | Pending |
| A11Y-06 | Phase 23 | Pending |
| A11Y-07 | Phase 23 | Pending |
| A11Y-08 | Phase 23 | Pending |
| DB-01 | Phase 18 | Complete |
| DB-02 | Phase 22 | Pending |
| DB-03 | Phase 22 | Pending |
| DB-04 | Phase 23 | Pending |
| DB-05 | Phase 23 | Pending |
| DB-06 | Phase 23 | Pending |
| DB-07 | Phase 23 | Pending |
| NET-01 | Phase 22 | Complete |
| NET-02 | Phase 23 | Complete |
| NET-03 | Phase 23 | Complete |
| NET-04 | Phase 23 | Pending |
| NET-05 | Phase 23 | Pending |
| NET-06 | Phase 23 | Pending |
| NET-07 | Phase 23 | Pending |
| SEC-01 | Phase 23 | Pending |
| SEC-02 | Phase 23 | Pending |
| SEC-03 | Phase 23 | Pending |
| SEC-04 | Phase 23 | Pending |
| SEC-05 | Phase 23 | Pending |
| MEM-01 | Phase 19 | Complete |
| MEM-02 | Phase 19 | Complete |
| MEM-03 | Phase 23 | Complete |
| MEM-04 | Phase 23 | Pending |
| LAYOUT-01 | Phase 22 | Pending |
| LAYOUT-02 | Phase 23 | Pending |
| LAYOUT-03 | Phase 23 | Pending |
| LAYOUT-04 | Phase 23 | Pending |
| MOD-01 | Phase 23 | Pending |
| MOD-02 | Phase 23 | Pending |
| MOD-03 | Phase 23 | Pending |
| MOD-04 | Phase 23 | Pending |
| MOD-05 | Phase 23 | Pending |
| MOD-06 | Phase 23 | Pending |
| MOD-07 | Phase 23 | Pending |
| MOD-08 | Phase 23 | Pending |

---

## Deferred (v2.0 Performance — resume after v3.0)

- [ ] PERF-01: App launches in under 1 second (Phase 11 DONE)
- [ ] PERF-02: Memory usage under 100MB
- [ ] PERF-03: Network requests batched/deduplicated
- [ ] PERF-04: 500+ sessions scroll at 60fps
- [ ] PERF-05: 200+ messages render without jank
- [ ] PERF-06: Battery impact rated "Low"
- [ ] PERF-07: Performance regression tests

## Out of Scope

- New feature development
- App Store submission (separate milestone)
- Android/web platform support
- Full Swift 6 strict mode migration (fix data races but don't enable strict concurrency)
- v2.0 phases 12-17 (deferred, overlapping issues absorbed into v3.0)

---

*165 requirements | 15 categories | All approved 2026-02-22*
*Traceability added 2026-02-22 | 165/165 mapped to Phases 18-23*
