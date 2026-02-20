# Complete Skills & Pitfalls Map for ILS Comprehensive Audit

**Project:** ILS iOS/macOS Monorepo
**Researched:** 2026-02-19
**Overall confidence:** HIGH (sourced from project skills, CLAUDE.md, audit-backlog.md, and session memory)

---

## 1. Custom Project Skills

Three custom skills live in `.claude/skills/`. These are the primary orchestration layer for all work on this codebase.

### 1.1 `ils-ios-project` (Master Project Skill)

**File:** `.claude/skills/ils-ios-project/SKILL.md`
**Invoke:** `Skill("ils-ios-project")` -- EVERY session, before ANY work

| Section | Contents | Critical For |
|---------|----------|-------------|
| Architecture | iOS/macOS/Backend/Shared module map, target info | Understanding codebase structure |
| Code Patterns | ThemeSnapshot, @Observable+nonisolated(unsafe), API prefix, ClaudeModel enum, cleanedSessionTitle(), StreamMessage | Writing correct Swift code |
| Decision Trees | Bug fixes, new views, backend API changes, build failures | Choosing the right workflow |
| Pitfall Prevention | 14 documented pitfalls with causes and fixes | Avoiding known time-wasters |
| Skill Routing | 15+ task types mapped to specific skills | Knowing which skill to invoke |
| Mandatory Invocations | Concrete examples for every skill category | Actually using skills correctly |
| Verification Protocol | Parallel iOS/macOS/Backend builds | Proving work is correct |
| Endpoints & Deep Links | All /api/v1 routes, all ils:// deep links | Backend and navigation work |
| Theme System | 13 built-in themes, ThemeManager, font token rules | UI work |
| Audit Backlog Reference | Points to `references/audit-backlog.md` (39 items) | Prioritizing fixes |

### 1.2 `appstore-check` (App Store Readiness)

**File:** `.claude/skills/appstore-check/SKILL.md`
**Invoke:** `Skill("appstore-check")` -- before App Store submission, after major changes

| Check Category | Items | Pass Criteria |
|---------------|-------|---------------|
| Build verification | iOS, macOS, Backend builds | Exit 0 |
| Security scan | Secrets, hardcoded paths, git-tracked DBs | Zero results |
| Info.plist | CFBundleDisplayName, encryption declaration, network usage | All present |
| App icons | 1024x1024 PNG in both xcassets | Files exist |
| Screenshots | 5+ files at 1320x2868 in AppStoreMetadata | Files exist |
| Metadata | description.txt, keywords.txt, name.txt, subtitle.txt | All present |
| Privacy/Support URLs | GitHub Pages endpoints | HTTP 200 |
| Character limits | Name 30, Subtitle 30, Keywords 100, Description 4000 | Under limits |

### 1.3 `full-audit` (Comprehensive Cross-Platform Audit)

**File:** `.claude/skills/full-audit/SKILL.md`
**Invoke:** `Skill("full-audit")` -- pre-release validation, after major refactors

| Phase | Name | Parallelizable With | Key Validations |
|-------|------|---------------------|-----------------|
| 1 | Environment & Infrastructure | Phases 2, 3 | Swift toolchain, Xcode, simulator, SPM, clean builds (iOS/macOS/Backend), warning count |
| 2 | Backend API Validation | Phases 1, 3 | 12 endpoints, correct binary verification, camelCase keys, APIResponse wrappers |
| 3 | Shell Script Testing | Phases 1, 2 | setup.sh, install-backend-service.sh, run_regression_tests.sh, reinstall-plugins.sh |
| 4 | iOS UI Audit | Phases 5, 6 | 34 screens on iPhone 16 Pro Max, tap targets, text readability, entity colors |
| 5 | iPad UI Audit | Phases 4, 6 | Same 34 screens + size class, split view, touch targets, text scaling |
| 6 | macOS UI Audit | Phases 4, 5 | Window management, NavigationSplitView, menu bar, keyboard shortcuts |
| 7 | Cross-Platform Consistency | After 4-6 | Same data, consistent colors, no platform-exclusive bugs |
| 8 | Deep Link & Navigation | After 4-6 | All ils:// routes, back navigation, invalid link handling |
| 9 | Accessibility & Dynamic Type | After 4-6 | XXL text scaling, VoiceOver labels, contrast, no overlapping |
| 10 | Data Integrity & Edge Cases | After 4-6 | Empty states, 22K+ sessions, network resilience, state persistence, concurrency |

---

## 2. Axiom Skills (Invoke via `Skill()` tool)

Skills provide guidance, patterns, and diagnostic workflows. They do NOT execute code -- they inform HOW to execute.

### 2.1 Build & Debug

| Skill | Invocation | When to Use | Audit Phase(s) |
|-------|-----------|-------------|----------------|
| `axiom:axiom-ios-build` | `Skill("axiom:axiom-ios-build")` | ANY xcodebuild failure -- structured error triage, cascading error handling | Phase 1 |
| `axiom:axiom-build-debugging` | `Skill("axiom:axiom-build-debugging")` | Build system issues (SPM, linker, module resolution) | Phase 1 |
| `axiom:axiom-xcode-debugging` | `Skill("axiom:axiom-xcode-debugging")` | Crash log analysis, LLDB patterns, runtime debugging | Phase 5, 8, 10 |
| `axiom:axiom-swiftui-debugging` | `Skill("axiom:axiom-swiftui-debugging")` | SwiftUI-specific bugs (view not updating, layout cycles, preview crashes) | Phase 4, 5, 6 |

### 2.2 SwiftUI & UI

| Skill | Invocation | When to Use | Audit Phase(s) |
|-------|-----------|-------------|----------------|
| `axiom:axiom-ios-ui` | `Skill("axiom:axiom-ios-ui")` | Any SwiftUI view creation or modification, general patterns | Phase 4, 5, 6 |
| `axiom:axiom-swiftui-nav` | `Skill("axiom:axiom-swiftui-nav")` | Navigation changes (NavigationStack, deep links, programmatic nav) | Phase 4, 5, 8 |
| `axiom:axiom-swiftui-layout` | `Skill("axiom:axiom-swiftui-layout")` | Layout debugging (GeometryReader, alignment, frame issues) | Phase 4, 5, 6 |
| `axiom:axiom-hig` | `Skill("axiom:axiom-hig")` | Human Interface Guidelines compliance (44pt targets, font sizes, spacing) | Phase 4, 9 |
| `axiom:axiom-swiftui-gestures` | `Skill("axiom:axiom-swiftui-gestures")` | Gesture handling (tap, swipe, long press conflicts) | Phase 4, 5 |

### 2.3 Quality & Compliance

| Skill | Invocation | When to Use | Audit Phase(s) |
|-------|-----------|-------------|----------------|
| `axiom:axiom-ios-accessibility` | `Skill("axiom:axiom-ios-accessibility")` | Accessibility audit (VoiceOver, Dynamic Type, contrast ratios) | Phase 4, 8, 9 |
| `axiom:axiom-ios-performance` | `Skill("axiom:axiom-ios-performance")` | Performance profiling (Instruments, Time Profiler, Allocations) | Phase 10 |
| `axiom:axiom-swift-performance` | `Skill("axiom:axiom-swift-performance")` | Swift-level optimization (COW, ARC, value vs reference types) | Phase 10 |
| `axiom:axiom-ios-concurrency` | `Skill("axiom:axiom-ios-concurrency")` | Swift concurrency (@Sendable, actor isolation, Task management) | Phase 10 |
| `axiom:axiom-energy` | `Skill("axiom:axiom-energy")` | Battery/energy audit (background tasks, timers, network polling) | Phase 10 |

### 2.4 Networking & Data

| Skill | Invocation | When to Use | Audit Phase(s) |
|-------|-----------|-------------|----------------|
| `axiom:axiom-ios-networking` | `Skill("axiom:axiom-ios-networking")` | Network layer review (URLSession, SSE, WebSocket patterns) | Phase 2, 7 |
| `axiom:axiom-codable` | `Skill("axiom:axiom-codable")` | JSON encoding/decoding patterns, Codable conformance | Phase 2, 7, 10 |

### 2.5 App Store & Release

| Skill | Invocation | When to Use | Audit Phase(s) |
|-------|-----------|-------------|----------------|
| `axiom:axiom-app-store-submission` | `Skill("axiom:axiom-app-store-submission")` | App Store submission checklist (icons, metadata, entitlements) | Phase 9 |
| `axiom:axiom-shipping` | `Skill("axiom:axiom-shipping")` | Release readiness (version bumps, changelogs, final checks) | Phase 9 |
| `axiom:axiom-privacy-ux` | `Skill("axiom:axiom-privacy-ux")` | Privacy UI patterns (permission dialogs, data handling disclosure) | Phase 9 |

### 2.6 Memory & Crash

| Skill | Invocation | When to Use | Audit Phase(s) |
|-------|-----------|-------------|----------------|
| `axiom:axiom-memory-debugging` | `Skill("axiom:axiom-memory-debugging")` | Memory leak investigation, retain cycle diagnosis | Phase 10 |

### 2.7 General

| Skill | Invocation | When to Use | Audit Phase(s) |
|-------|-----------|-------------|----------------|
| `axiom:status` | `Skill("axiom:status")` | Check which Axiom skills/agents are currently available | Any (startup) |
| `axiom:ask` | `Skill("axiom:ask")` | General iOS guidance when no specific skill matches | Any |
| `axiom:axiom-apple-docs` | `Skill("axiom:axiom-apple-docs")` | Apple API references, framework documentation | Any |

---

## 3. Axiom Auditor Agents (Invoke via `Task()` tool, NOT `Skill()`)

Auditor agents actively analyze code, produce findings, and may suggest or apply fixes. They are heavier than skills but produce structured audit reports.

### 3.1 UI & Layout Agents

| Agent | Task Invocation | Capability | Audit Phase(s) |
|-------|----------------|-----------|----------------|
| `axiom:accessibility-auditor` | `Task(agent="axiom:accessibility-auditor")` | VoiceOver labels, Dynamic Type, contrast ratios, touch target sizes | Phase 4, 9 |
| `axiom:swiftui-nav-auditor` | `Task(agent="axiom:swiftui-nav-auditor")` | Navigation architecture, deep link integrity, back navigation | Phase 5, 8 |
| `axiom:swiftui-architecture-auditor` | `Task(agent="axiom:swiftui-architecture-auditor")` | Separation of concerns, MVVM compliance, view/model boundaries | Phase 7 |
| `axiom:swiftui-layout-auditor` | `Task(agent="axiom:swiftui-layout-auditor")` | Layout correctness across device sizes, adaptive layout | Phase 4, 5 |

### 3.2 Performance Agents

| Agent | Task Invocation | Capability | Audit Phase(s) |
|-------|----------------|-----------|----------------|
| `axiom:swiftui-performance-analyzer` | `Task(agent="axiom:swiftui-performance-analyzer")` | View body re-evaluation frequency, unnecessary redraws | Phase 10 |
| `axiom:swift-performance-analyzer` | `Task(agent="axiom:swift-performance-analyzer")` | Algorithm complexity, value type usage, ARC overhead | Phase 10 |
| `axiom:memory-auditor` | `Task(agent="axiom:memory-auditor")` | Retain cycles, leaked closures, unowned references | Phase 10 |
| `axiom:energy-auditor` | `Task(agent="axiom:energy-auditor")` | Battery drain patterns, wake frequency, background work | Phase 10 |

### 3.3 Code Quality Agents

| Agent | Task Invocation | Capability | Audit Phase(s) |
|-------|----------------|-----------|----------------|
| `axiom:concurrency-auditor` | `Task(agent="axiom:concurrency-auditor")` | Swift 6 concurrency compliance, data race detection | Phase 10 |
| `axiom:codable-auditor` | `Task(agent="axiom:codable-auditor")` | JSON anti-patterns, missing CodingKeys, decode failures | Phase 2, 7 |
| `axiom:modernization-helper` | `Task(agent="axiom:modernization-helper")` | Legacy pattern migration (ObservableObject to @Observable, etc.) | Phase 7 |
| `axiom:testing-auditor` | `Task(agent="axiom:testing-auditor")` | Test quality (NOTE: project uses functional validation only, no unit tests) | N/A |

### 3.4 Infrastructure Agents

| Agent | Task Invocation | Capability | Audit Phase(s) |
|-------|----------------|-----------|----------------|
| `axiom:build-fixer` | `Task(agent="axiom:build-fixer")` | Build failure resolution, dependency conflicts | Phase 1 |
| `axiom:crash-analyzer` | `Task(agent="axiom:crash-analyzer")` | Crash log analysis, stack trace interpretation | Phase 5, 10 |
| `axiom:security-privacy-scanner` | `Task(agent="axiom:security-privacy-scanner")` | Security vulnerabilities, privacy manifest compliance | Phase 2, 9 |
| `axiom:networking-auditor` | `Task(agent="axiom:networking-auditor")` | Deprecated networking APIs, transport security | Phase 2 |
| `axiom:simulator-tester` | `Task(agent="axiom:simulator-tester")` | Simulator testing workflows, device matrix coverage | Phase 1, 4, 5 |

---

## 4. Simulator & Automation Skills

These skills provide patterns for interacting with iOS Simulator programmatically.

| Skill | Invocation | Capability | Audit Phase(s) |
|-------|-----------|-----------|----------------|
| `ios-simulator-control` | `Skill("ios-simulator-control")` | Boot, install, screenshot, manage simulator lifecycle | Phase 1, 4, 5 |
| `xclaude-plugin:simulator-workflows` | `Skill("xclaude-plugin:simulator-workflows")` | xclaude MCP integration for screenshot capture | Phase 1, 4, 5 |
| `ios-ui-automation` | `Skill("ios-ui-automation")` | idb tap/describe/swipe patterns for programmatic navigation | Phase 4, 5, 8, 9 |
| `xclaude-plugin:ui-automation-workflows` | `Skill("xclaude-plugin:ui-automation-workflows")` | xclaude idb integration for UI automation | Phase 4, 5 |
| `xclaude-plugin:accessibility-testing` | `Skill("xclaude-plugin:accessibility-testing")` | Accessibility testing workflows via xclaude | Phase 9 |
| `xclaude-plugin:crash-debugging` | `Skill("xclaude-plugin:crash-debugging")` | Crash debugging workflows via xclaude | Phase 5, 10 |
| `xclaude-plugin:performance-profiling` | `Skill("xclaude-plugin:performance-profiling")` | Performance profiling workflows via xclaude | Phase 10 |

### Simulator Constants (NEVER deviate)

| Property | Value |
|----------|-------|
| Dedicated UDID | `50523130-57AA-48B0-ABD0-4D59CE455F14` |
| Device | iPhone 16 Pro Max |
| iOS Version | 18.6 |
| Logical Resolution | 440x956 points |
| Other simulators | NEVER TOUCH -- belong to other AI sessions |

### Navigation Techniques (ordered by reliability)

1. **`idb_describe operation:all`** -- get accessibility tree with exact centerX/centerY coordinates (MOST RELIABLE)
2. **`idb_tap` at described coordinates** -- tap at exact positions from accessibility tree
3. **Deep links** -- `xcrun simctl openurl booted 'ils://sessions/{lowercase-uuid}'`
4. **Swipe gestures** -- `idb ui swipe 5 500 300 500 --duration 0.3` (open sidebar from left edge)
5. **@State default modification** -- for toolbar buttons unreachable via tap: modify default, rebuild, capture, revert (LAST RESORT)

### Sidebar Navigation Coordinates (x=80)

| Item | y-coordinate |
|------|-------------|
| Home | ~198 |
| System Monitor | ~233 |
| Browse | ~268 |
| Agent Teams | ~303 |
| Fleet | ~338 |
| Settings | ~393 |

---

## 5. Validation & Completion Skills (MANDATORY for EVERY task)

These are non-negotiable. Every task completion MUST invoke all four.

| Skill | Invocation | Purpose | When |
|-------|-----------|---------|------|
| `functional-validation` | `Skill("functional-validation")` | No-mock validation methodology. Build and run real system, capture evidence. | Every validation |
| `ios-validation-gate` | `Skill("ios-validation-gate")` | 3-gate iOS validation protocol (build, install, screenshot evidence) | Every iOS task |
| `gate-validation-discipline` | `Skill("gate-validation-discipline")` | Evidence-based completion -- no claiming PASS without proof | Every task completion |
| `verification-before-completion` | `Skill("verification-before-completion")` | Pre-completion checklist -- ensures nothing was skipped | Before marking PASS |
| `no-mocking-validation-gates` | `Skill("no-mocking-validation-gates")` | Enforce no test doubles, no mocks, no stubs | All validation |
| `spec-compliance` | `Skill("spec-compliance")` | Spec adherence checking -- compare output against specification | All tasks with specs |

### Validation Rules

- **NEVER** write mocks, stubs, test doubles, unit tests, or test files
- **NEVER** use test frameworks (XCTest, Quick/Nimble)
- **ALWAYS** build and run the real system
- **ALWAYS** validate through actual user interfaces (simulator screenshots, curl output)
- **ALWAYS** capture evidence (screenshots, terminal output, JSON responses)
- **ALWAYS** read and verify evidence before claiming completion
- "17/21 verified" is NOT passing -- it is 4 failures
- After ANY fix or refactor, re-validate from scratch -- do not trust prior results

---

## 6. Known Pitfalls (14 Documented, from Real Sessions)

### Critical Pitfalls (cause hours of wasted time)

| # | Symptom | Root Cause | Fix | Detection |
|---|---------|-----------|-----|-----------|
| 1 | API returns raw arrays, snake_case | Wrong backend binary running (old one at `/Users/nick/ils/ILSBackend/`) | `lsof -i :9999 -P -n` -- path MUST contain `ils-ios/` | Check immediately when backend responses look wrong |
| 2 | Claude CLI subprocess hangs indefinitely | `CLAUDECODE=1` and `CLAUDE_CODE_*` env vars trigger nesting detection | Strip these env vars in `ClaudeExecutorService.swift:executeWithSDK()` before spawning subprocess | Chat requests that never complete |
| 3 | SDK publisher never emits events | RunLoop not pumped by NIO (Vapor's event loop) | Use direct `Process` + `DispatchQueue` for stdout reads, NOT ClaudeCodeSDK | SSE stream starts but no messages arrive |
| 4 | NSInvalidArgumentException on process exit | `process.terminationStatus` accessed before `waitUntilExit()` | Always call `process.waitUntilExit()` first | Runtime crash on chat completion |
| 7 | @ObservationTracked macro compile error | Plain `nonisolated` on mutable Task property | Use `nonisolated(unsafe)` instead -- compiler misleadingly suggests wrong fix | Build error in @Observable @MainActor classes |
| 8 | SHA256 produces wrong hash in Vapor | `import Crypto` resolves to Vapor's Crypto, not Apple's | Use `import CryptoKit` explicitly | Hash mismatch, auth failures |
| 11 | App Store rejection | Missing PrivacyInfo.xcprivacy | Both iOS AND macOS targets need their own privacy manifest | App Store Connect rejection email |

### Moderate Pitfalls (cause confusion or rework)

| # | Symptom | Root Cause | Fix | Detection |
|---|---------|-----------|-----|-----------|
| 5 | App installed but shows old code | Using wrong DerivedData path or stale binary | Use `~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/` | Visual differences from expected changes |
| 6 | idb_tap misses toolbar buttons | SwiftUI toolbar items not in accessibility tree | Use `idb_describe operation:all` for exact coordinates | Tap has no effect on toolbar |
| 9 | macOS works but iOS broken (or vice versa) | Cross-platform drift -- separate view layers | ALWAYS check and fix both platforms after any change | One platform passes, other fails |
| 10 | Config file corrupted after crash | Non-atomic file write (`Data.write` without `.atomic`) | Use `Data.write(to:options:.atomic)` | Config resets or app fails to launch |
| 12 | Deep link silently fails | Uppercase UUID in deep link URL | Deep link UUIDs MUST be lowercase | `xcrun simctl openurl` does nothing |
| 13 | Stale tunnel URL after reinstall | UserDefaults cached old serverURL | Fresh install (`simctl uninstall + install`) clears UserDefaults | App connects to wrong server |

### Process Pitfall

| # | Symptom | Root Cause | Fix | Detection |
|---|---------|-----------|-----|-----------|
| 14 | Plans created but never executed | Over-planning habit (6 plans in 10 days, incomplete validation) | Implement immediately -- user explicitly rejects over-planning | Multiple .md files with no code changes |

---

## 7. Phase-to-Skill Mapping Matrix

This is the definitive reference for which skills and agents to invoke at each audit phase.

### Phase 0: Pre-Audit Setup

| Action | Tool |
|--------|------|
| Load project context | `Skill("ils-ios-project")` |
| Check available Axiom skills | `Skill("axiom:status")` |
| Boot simulator | `Skill("ios-simulator-control")` |
| Verify backend binary | `lsof -i :9999 -P -n` |

### Phase 1: Environment & Infrastructure

| Action | Tool |
|--------|------|
| Build failures | `Skill("axiom:axiom-ios-build")` |
| Build system issues | `Skill("axiom:axiom-build-debugging")` |
| Resolve build failures | `Task(agent="axiom:build-fixer")` |
| Simulator setup | `Skill("ios-simulator-control")` |
| Device matrix | `Task(agent="axiom:simulator-tester")` |

### Phase 2: Backend API Validation

| Action | Tool |
|--------|------|
| Network layer review | `Skill("axiom:axiom-ios-networking")` |
| JSON patterns | `Skill("axiom:axiom-codable")` |
| Codable anti-patterns | `Task(agent="axiom:codable-auditor")` |
| Deprecated APIs | `Task(agent="axiom:networking-auditor")` |
| Security scan | `Task(agent="axiom:security-privacy-scanner")` |

### Phase 3: Shell Script Testing

| Action | Tool |
|--------|------|
| General guidance | `Skill("axiom:ask")` |

### Phase 4: iOS UI Audit (iPhone)

| Action | Tool |
|--------|------|
| SwiftUI patterns | `Skill("axiom:axiom-ios-ui")` |
| Layout debugging | `Skill("axiom:axiom-swiftui-layout")` |
| HIG compliance | `Skill("axiom:axiom-hig")` |
| Accessibility | `Skill("axiom:axiom-ios-accessibility")` |
| UI automation | `Skill("ios-ui-automation")` |
| Screenshots | `Skill("xclaude-plugin:simulator-workflows")` |
| Layout audit | `Task(agent="axiom:swiftui-layout-auditor")` |
| Accessibility audit | `Task(agent="axiom:accessibility-auditor")` |

### Phase 5: iPad UI Audit

| Action | Tool |
|--------|------|
| Same as Phase 4, plus: | |
| Navigation architecture | `Skill("axiom:axiom-swiftui-nav")` |
| Nav audit | `Task(agent="axiom:swiftui-nav-auditor")` |
| Crash analysis | `Skill("axiom:axiom-xcode-debugging")` |
| Crash logs | `Task(agent="axiom:crash-analyzer")` |

### Phase 6: macOS UI Audit

| Action | Tool |
|--------|------|
| SwiftUI patterns | `Skill("axiom:axiom-ios-ui")` |
| Layout debugging | `Skill("axiom:axiom-swiftui-layout")` |
| SwiftUI debugging | `Skill("axiom:axiom-swiftui-debugging")` |

### Phase 7: Cross-Platform Consistency

| Action | Tool |
|--------|------|
| Architecture audit | `Task(agent="axiom:swiftui-architecture-auditor")` |
| Codable consistency | `Task(agent="axiom:codable-auditor")` |
| Legacy migration | `Task(agent="axiom:modernization-helper")` |
| Networking review | `Skill("axiom:axiom-ios-networking")` |

### Phase 8: Deep Link & Navigation

| Action | Tool |
|--------|------|
| Navigation patterns | `Skill("axiom:axiom-swiftui-nav")` |
| Nav audit | `Task(agent="axiom:swiftui-nav-auditor")` |
| UI automation | `Skill("ios-ui-automation")` |
| Accessibility testing | `Skill("xclaude-plugin:accessibility-testing")` |

### Phase 9: Accessibility & Dynamic Type

| Action | Tool |
|--------|------|
| Accessibility patterns | `Skill("axiom:axiom-ios-accessibility")` |
| HIG compliance | `Skill("axiom:axiom-hig")` |
| Accessibility audit | `Task(agent="axiom:accessibility-auditor")` |
| App Store readiness | `Skill("axiom:axiom-app-store-submission")` |
| Shipping checklist | `Skill("axiom:axiom-shipping")` |
| Privacy UX | `Skill("axiom:axiom-privacy-ux")` |
| Security scan | `Task(agent="axiom:security-privacy-scanner")` |

### Phase 10: Data Integrity & Edge Cases

| Action | Tool |
|--------|------|
| Performance profiling | `Skill("axiom:axiom-ios-performance")` |
| Swift performance | `Skill("axiom:axiom-swift-performance")` |
| Concurrency review | `Skill("axiom:axiom-ios-concurrency")` |
| Energy audit | `Skill("axiom:axiom-energy")` |
| Memory debugging | `Skill("axiom:axiom-memory-debugging")` |
| View performance | `Task(agent="axiom:swiftui-performance-analyzer")` |
| Swift performance | `Task(agent="axiom:swift-performance-analyzer")` |
| Memory audit | `Task(agent="axiom:memory-auditor")` |
| Energy audit | `Task(agent="axiom:energy-auditor")` |
| Concurrency audit | `Task(agent="axiom:concurrency-auditor")` |
| Crash analysis | `Task(agent="axiom:crash-analyzer")` |
| Crash debugging | `Skill("xclaude-plugin:crash-debugging")` |
| Performance profiling | `Skill("xclaude-plugin:performance-profiling")` |

---

## 8. Audit Backlog (39 Open Issues)

Sourced from `.claude/skills/ils-ios-project/references/audit-backlog.md`. These are findings from previous Axiom auditor runs that have NOT yet been fixed.

### CRITICAL (9 issues -- fix before App Store)

| ID | File | Issue | Fix Required |
|----|------|-------|-------------|
| C1 | `ILSAppApp.swift:56` | Launch animation ignores reduce motion | Gate `withAnimation` on `accessibilityReduceMotion` |
| C2 | `ProgressRing.swift:44` | Ring animation ignores reduce motion | Same pattern |
| C3 | `StatCard.swift:59` | Press scale animation ignores reduce motion | Same pattern |
| C4 | `UserMessageCard.swift:15` | `UIScreen.main.bounds` breaks iPad Split View | Use `containerRelativeFrame(.horizontal)` |
| C5 | `MessageView.swift:226` | `MarkdownParser.parse()` runs every body eval | Cache in `@State` + `.task(id: text)` |
| C6 | `ThemeMarketplaceView.swift:230` | `filteredThemes` computed every body eval | Memoize into `@State` + `.onChange` |
| C7 | `ILSAppApp.swift` | Forced `.colorScheme(.dark)` throughout app | Remove, let theme colors handle appearance |
| C8 | `SidebarRootView.swift` | Custom hamburger sidebar blocks system gestures | Consider NavigationSplitView on iPhone |
| C9 | Multiple files | Inconsistent `navigationBarTitleDisplayMode` | Standardize to `.inline` across all views |

### HIGH (13 issues -- fix for quality)

| ID | File | Issue | Fix Required |
|----|------|-------|-------------|
| H1 | `BrowserView.swift:82` | Custom segmented control not accessible | Replace with `Picker(.segmented)` or add accessibility traits |
| H2 | `SidebarSessionRow.swift:52` | Touch target ~24pt, below 44pt HIG minimum | `.frame(minHeight: 44).contentShape(Rectangle())` |
| H3 | `HomeView.swift:242` | Custom `relativeTime()` not localized | Use `DateFormatters.relativeDateTime` |
| H4 | 50+ files | Hardcoded font sizes bypass theme typography | Replace with `theme.font*` equivalents |
| H5 | `SidebarRootView.swift` | Size class fork doesn't handle iPhone Pro Max landscape | Add `UIDevice.userInterfaceIdiom` check |
| H6 | `BrowserView.swift` | `.contains()` on arrays for row selection | Use `Set<String>` for O(1) lookup |
| H7 | `ThemePickerView.swift` | O(n^2) contains check | Use Set |
| H8 | `MetricsWebSocketClient.swift:30-32` | `nonisolated(unsafe)` Task properties -- data race risk | Remove annotation, all access is @MainActor |
| H9 | `SubscriptionManager.swift:80` | Fire-and-forget init Task with no handle | Store and cancel on deinit |
| H10 | `PluginsViewModel.swift:27` | `nonisolated(unsafe)` search task | Remove annotation |
| H11 | `SkillsViewModel.swift:43` | `nonisolated(unsafe)` search task | Remove annotation |
| H12 | `ScreenshotProtectionModifier.swift` | Animation without reduce motion check | Add `accessibilityReduceMotion` gate |
| H13 | `ShimmerModifier.swift` | GeometryReader in overlay | Monitor performance, consider alternatives |

### MEDIUM (15 issues -- address for polish)

| ID | File | Issue |
|----|------|-------|
| M1 | `SSHSetupView.swift` | Fixed 300pt height frame |
| M2 | `FleetManagementView.swift` | Non-lazy VStack for server list |
| M3 | `SidebarRootView.swift` | Hardcoded 280pt sidebar width |
| M4 | Log viewers | `ForEach` with `id:\.offset` anti-pattern |
| M5 | `SSEClient.swift` | Still uses `ObservableObject` (only holdout) |
| M6 | `HomeView.swift` | Non-lazy VStack for dashboard |
| M7 | Multiple sheets | Missing `presentationDetents` |
| M8 | `BrowserView.swift` | Custom search bar instead of `.searchable` |
| M9 | `HooksManagementView.swift:158` | 8pt font -- illegible |
| M10 | `PremiumView.swift` | Forces CyberpunkTheme -- hardcoded override |
| M11 | `SystemMonitorView.swift:128` | `onAppear { Task {} }` -- use `.task` instead |
| M12 | `SessionWindowView.swift:58` | Unstructured Task in onAppear |
| M13 | `DashboardViewModel.swift:64` | Fire-and-forget cache Task |
| M14 | 109 instances | VStack/HStack without explicit spacing |
| M15 | `ThemeMarketplaceView.swift` | File I/O on main thread during import |

### LOW (2 issues)

| ID | File | Issue |
|----|------|-------|
| L1 | `NotificationManager.swift:22` | UNUserNotificationCenter delegate (benign) |
| L2 | `SSHSetupView.swift` | Log terminal uses raw color values |

---

## 9. Skill Evaluation Checklist (Run Before EVERY Task)

This is the mandatory pre-flight check. Go through each question. If YES, invoke the skill.

| # | Question | If YES, Invoke |
|---|----------|---------------|
| 1 | Working on this project at all? | `Skill("ils-ios-project")` |
| 2 | iOS build needed or failed? | `Skill("axiom:axiom-ios-build")` |
| 3 | Simulator work (boot, install, screenshot)? | `Skill("ios-simulator-control")` + `Skill("xclaude-plugin:simulator-workflows")` |
| 4 | UI automation (tap, describe, swipe)? | `Skill("ios-ui-automation")` + `Skill("xclaude-plugin:ui-automation-workflows")` |
| 5 | Marking task as complete? | `Skill("functional-validation")` + `Skill("ios-validation-gate")` + `Skill("gate-validation-discipline")` + `Skill("verification-before-completion")` |
| 6 | Dispatching parallel agents? | `Skill("dispatching-parallel-agents")` |
| 7 | Accessibility work? | `Skill("axiom:axiom-ios-accessibility")` + `Skill("xclaude-plugin:accessibility-testing")` |
| 8 | Build error to fix? | `Skill("axiom:axiom-ios-build")` + `Task(agent="axiom:build-fixer")` |
| 9 | App crashed? | `Skill("axiom:axiom-xcode-debugging")` + `Task(agent="axiom:crash-analyzer")` |
| 10 | SwiftUI layout issue? | `Skill("axiom:axiom-swiftui-layout")` + `Skill("axiom:axiom-ios-ui")` |
| 11 | Navigation change? | `Skill("axiom:axiom-swiftui-nav")` + `Task(agent="axiom:swiftui-nav-auditor")` |
| 12 | Performance concern? | `Skill("axiom:axiom-ios-performance")` + `Task(agent="axiom:swiftui-performance-analyzer")` |
| 13 | Memory leak suspected? | `Skill("axiom:axiom-memory-debugging")` + `Task(agent="axiom:memory-auditor")` |
| 14 | HIG compliance needed? | `Skill("axiom:axiom-hig")` |
| 15 | App Store submission? | `Skill("appstore-check")` + `Skill("axiom:axiom-app-store-submission")` + `Skill("axiom:axiom-shipping")` |
| 16 | Security review needed? | `Task(agent="security-reviewer")` + `Task(agent="axiom:security-privacy-scanner")` |
| 17 | Concurrency/async work? | `Skill("axiom:axiom-ios-concurrency")` + `Task(agent="axiom:concurrency-auditor")` |
| 18 | Running full audit? | `Skill("full-audit")` |

---

## 10. Agent Fix-Then-Validate Mandate

ALL agents that capture screenshots or run validation MUST follow this protocol:

```
1. CAPTURE   -- Take screenshot / run validation / execute curl
2. VERIFY    -- Read the screenshot, check it shows the correct screen and data
3. DIAGNOSE  -- If broken: identify root cause in code
4. FIX       -- Apply code fix
5. REBUILD   -- Build all affected targets (iOS, macOS, Backend)
6. REINSTALL -- Install updated binary on simulator
7. RE-CAPTURE -- Take new screenshot
8. RE-VERIFY -- Confirm fix resolved the issue
9. REPORT    -- Only THEN mark as PASS with evidence path
```

**Violations of this mandate:**
- Claiming PASS based on "expected behavior" without evidence
- Reporting a screenshot without reading/verifying it
- Skipping re-validation after a fix
- Batching 5 fixes without intermediate build checks

---

## 11. Parallel Execution Strategy

### Independent Phase Groups (run in parallel)

```
Group A (parallel): Phase 1 + Phase 2 + Phase 3
  Wait for Group A completion
Group B (parallel): Phase 4 + Phase 5 + Phase 6
  Wait for Group B completion
Group C (sequential): Phase 7 -> Phase 8 -> Phase 9 -> Phase 10
  (Each depends on prior phases' results)
```

### Within-Phase Parallelism

| Phase | Parallel Opportunities |
|-------|----------------------|
| Phase 1 | iOS build + macOS build + Backend build (3 parallel) |
| Phase 2 | Endpoint validation (batch 4 curls at a time) |
| Phase 4 | Multiple Axiom auditor agents on different file groups |
| Phase 9 | Accessibility auditor + security scanner + App Store check |
| Phase 10 | Memory auditor + energy auditor + concurrency auditor + performance analyzer |

### Agent Dispatch Limits

- Maximum 4 parallel auditor agents per phase (resource contention)
- Always run builds with `run_in_background: true`
- Gate all screenshot capture behind simulator availability (only 1 simulator)

---

## 12. Quick Reference Card

### Session Startup Sequence

```
1. Skill("ils-ios-project")           -- Load project context (ALWAYS FIRST)
2. Skill("axiom:status")              -- Check available Axiom capabilities
3. Skill("ios-simulator-control")     -- If simulator work needed
4. lsof -i :9999 -P -n               -- Verify correct backend binary
5. [Domain-specific skills per task]  -- See checklist above
```

### Task Completion Sequence

```
1. Skill("functional-validation")          -- No-mock methodology
2. Skill("ios-validation-gate")            -- 3-gate protocol
3. Skill("gate-validation-discipline")     -- Evidence requirement
4. Skill("verification-before-completion") -- Final checklist
5. Capture evidence (screenshot/curl/log)
6. Read and verify evidence
7. Report with file paths
```

### Emergency Reference

| Situation | Immediate Action |
|-----------|-----------------|
| Build fails | `Skill("axiom:axiom-ios-build")` then read FULL error output |
| App crashes | `Skill("axiom:axiom-xcode-debugging")` then check crash log |
| Wrong data from API | `lsof -i :9999 -P -n` to verify backend binary |
| Simulator not responding | `xcrun simctl shutdown all && xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14` |
| Deep link fails | Check UUID is lowercase, app is installed, url.host matches route |
| idb_tap misses | `idb_describe operation:all` for exact coordinates |
