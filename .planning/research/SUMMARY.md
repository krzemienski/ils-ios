# Project Research Summary

**Project:** ILS Comprehensive Audit & Remediation
**Domain:** Native iOS/macOS client for Claude Code -- pre-App Store audit
**Researched:** 2026-02-19
**Confidence:** HIGH (all findings from direct codebase analysis of 244 Swift files)

## Executive Summary

ILS is a mature Swift monorepo (47,010 lines across 244 files) comprising an iOS app (153 files), macOS app (11 files), Vapor backend (53 files), and shared library (27 files). The application has completed multiple development cycles -- ground-up rebuild, alpha spec, design v2, multiple polish passes, reflexion gap analysis, HIG font compliance, and cross-platform quality remediation. It is functionally complete with 30 screens on iOS, 11 macOS-specific views, and 14 backend controllers. Only ONE feature gap existed (AddMCPServerView) and it has already been implemented. The comprehensive audit is the final validation gate before App Store submission.

The audit plan (10 phases, 1,370 lines) demands 105+ evidence artifacts: 78+ screenshots, 22 JSON/text files, and 5 other artifacts. The primary risk is NOT missing features -- it is evidence discipline. Previous audit sessions scored 1.5-3.1/5.0 on reflexion because agents claimed PASS without reading screenshots. Every screenshot MUST be read with the Read tool and visually inspected before marking PASS. The secondary risk is scope creep: a 39-item audit backlog (9 CRITICAL, 13 HIGH, 15 MEDIUM, 2 LOW) exists from prior Axiom auditor runs. These should be fixed opportunistically during the relevant audit phase, not as a separate remediation pass.

The project has an extensive skill infrastructure (3 custom project skills, 25+ Axiom skills, 15+ Axiom auditor agents, 7 simulator/automation skills, 6 validation skills) that MUST be invoked at the correct phase. Skipping skills leads to repeated mistakes that have cost hours in past sessions. The phase-to-skill mapping matrix in SKILLS.md is the definitive reference.

## Key Findings

### Tech Stack

Swift 6.2.4 / Xcode 26.3 monorepo with three independent build targets. iOS (min 17.0, `com.ils.app`), macOS (min 14.0, `com.ils.mac`), and Vapor backend on port 9999. All three builds are independent and MUST run in parallel for efficiency.

**Core technologies:**
- **SwiftUI + @Observable:** All 17 ViewModels use `@Observable @MainActor` with deferred `configure(client:)` pattern
- **Vapor 4.121.1:** Backend framework with 14 RouteCollection controllers (all value-type structs)
- **Fluent + SQLite:** ORM with 5 models, 7 migrations, `toShared()`/`from()` bridging to ILSShared types
- **Python SDK wrapper:** `scripts/sdk-wrapper.py` wraps Claude CLI via `claude-agent-sdk` for chat streaming
- **ThemeSnapshot:** Concrete struct replacing `any AppTheme` existential -- 43 stored properties, zero-cost access in view bodies

**Critical version/config requirements:**
- Dedicated simulator UDID: `50523130-57AA-48B0-ABD0-4D59CE455F14` (iPhone 16 Pro Max, iOS 18.6) -- NEVER use any other
- Backend port: 9999 (8080 is ralph-mobile)
- API prefix: `/api/v1` added by APIClient.swift -- never include in route strings
- Privacy manifests required for BOTH iOS and macOS targets

### Feature Scope

**30 iOS screens implemented** (9 spec-defined + 21 beyond-spec). All screens render with real data from the backend. The audit is VERIFY-with-evidence work, not implementation work.

**Must verify (audit mandates -- 9 sub-tasks):**
- GitHub Skill Search/Install, MCP Server Creation, ConfigEditor scope+validation
- SkillDetailView features, Settings inheritance badges, Fleet-to-Hosts rename
- System Monitor pipeline, Hooks Management, Plugin GitHub Search

**Must audit visually (3 platforms):**
- iPhone: 19 screens
- iPad: 4 screens (verify adaptive layout, no dedicated pass)
- macOS: 5 screens (verify existing views, no parity push)

**39 backlog items to triage during audit:**
- 9 CRITICAL: reduce-motion violations (C1-C3, H12), UIScreen.main.bounds iPad break (C4), un-cached MarkdownParser (C5), un-cached filteredThemes (C6), forced dark mode (C7), custom sidebar blocking gestures (C8), inconsistent nav bar titles (C9)
- 13 HIGH: inaccessible segmented control, 24pt touch targets, hardcoded fonts, data race risks
- 15 MEDIUM + 2 LOW: SSEClient still ObservableObject, 8pt font in Hooks, non-lazy VStacks

**Anti-features (do NOT build during audit):**
- Unit tests, mocks, stubs, test files
- iPad dedicated layout redesign
- macOS feature parity push
- MCP env var editor (security decision D3)
- Architecture redesign

### Architecture Highlights

MVVM with `@Observable @MainActor` ViewModels, actor-based APIClient with caching, SSE streaming for chat, WebSocket for system metrics. iOS uses overlay sidebar + NavigationStack (with iPad NavigationSplitView fork). macOS uses 3-column NavigationSplitView. Both platforms share `AppState` but it is DUPLICATED (not shared) -- changes to one must be manually applied to the other.

**Module boundaries:**
1. **ILSApp (iOS)** -- 153 files, SwiftUI views organized by feature domain, 17 ViewModels, 15 services
2. **ILSMacApp (macOS)** -- 11 files, Mac-specific views + managers, shares many iOS views directly
3. **ILSShared** -- 27 files, all types crossing iOS/macOS/Backend boundary, single source of truth for API contracts
4. **ILSBackend** -- 53 files, 14 controllers + 18 services + 5 Fluent models, Claude CLI orchestration

**Navigation routing:** `ActiveScreen` enum with associated values, `@SceneStorage` persistence, deep links via `ils://` URL scheme (12 routes).

**Code patterns that MUST be followed:**

| Pattern | Correct | Wrong |
|---------|---------|-------|
| Theme access | `@Environment(\.theme) var theme: ThemeSnapshot` | `any AppTheme` existential |
| Task in @Observable | `nonisolated(unsafe) private var task` | plain `nonisolated` |
| API paths | `/sessions` | `/api/v1/sessions` (double prefix) |
| File writes | `Data.write(to:options:.atomic)` | `Data.write(to:)` |
| Font sizes | `theme.fontCaption` (11pt min) | `size: 10` |
| Hashing | `import CryptoKit` | `import Crypto` (resolves to BoringSSL in Vapor) |

## Skill Execution Matrix

This is the most operationally critical section. Every phase has mandatory skills.

### Pre-Audit (Every Session)
```
Skill("ils-ios-project")           -- ALWAYS FIRST
Skill("axiom:status")              -- check available capabilities
lsof -i :9999 -P -n               -- verify correct backend binary
```

### Phase 0: Build Verification
| Skill | Purpose |
|-------|---------|
| `Skill("axiom:axiom-ios-build")` | Build error triage |
| `Task(agent="axiom:build-fixer")` | Resolve persistent failures |

### Phase 1: Screen Inventory + Before-State
| Skill | Purpose |
|-------|---------|
| `Skill("ios-simulator-control")` | Boot, install, manage simulator |
| `Skill("xclaude-plugin:simulator-workflows")` | Screenshot capture |
| `Skill("ios-ui-automation")` | idb tap/describe for navigation |
| `Skill("xclaude-plugin:ui-automation-workflows")` | Automation patterns |

### Phase 2-3: Gap Verification + Mandates
| Skill | Purpose |
|-------|---------|
| `Skill("axiom:axiom-ios-ui")` | SwiftUI patterns |
| `Skill("axiom:axiom-hig")` | HIG compliance |
| `Skill("functional-validation")` | No-mock validation protocol |
| `Skill("ios-validation-gate")` | 3-gate evidence protocol |
| `Skill("gate-validation-discipline")` | Evidence-based completion |
| `Skill("verification-before-completion")` | Pre-completion checklist |

### Phase 4-5: Visual + Functional Audit
| Skill | Purpose |
|-------|---------|
| `Skill("axiom:axiom-ios-accessibility")` | Accessibility audit |
| `Skill("axiom:axiom-swiftui-layout")` | Layout debugging |
| `Skill("axiom:axiom-swiftui-nav")` | Navigation correctness |
| `Task(agent="axiom:swiftui-layout-auditor")` | Layout across devices |
| `Task(agent="axiom:accessibility-auditor")` | VoiceOver, Dynamic Type |
| `Task(agent="axiom:swiftui-nav-auditor")` | Deep link + nav integrity |

### Phase 6-7: Backend + Integration
| Skill | Purpose |
|-------|---------|
| `Skill("axiom:axiom-ios-networking")` | Network layer review |
| `Skill("axiom:axiom-codable")` | JSON patterns |
| `Skill("spec-compliance")` | Spec adherence checking |
| `Task(agent="axiom:security-privacy-scanner")` | MCP env masking verification |
| `Task(agent="axiom:codable-auditor")` | Codable anti-patterns |

### Phase 8: Edge Cases + Performance + Accessibility
| Skill | Purpose |
|-------|---------|
| `Skill("axiom:axiom-ios-performance")` | Performance profiling |
| `Skill("axiom:axiom-ios-concurrency")` | Swift concurrency review |
| `Skill("axiom:axiom-energy")` | Battery drain |
| `Task(agent="axiom:memory-auditor")` | Memory leak detection |
| `Task(agent="axiom:concurrency-auditor")` | Data race detection |
| `Task(agent="axiom:energy-auditor")` | Background task audit |

### Phase 9: Report + App Store Readiness
| Skill | Purpose |
|-------|---------|
| `Skill("appstore-check")` | Full App Store readiness check |
| `Skill("axiom:axiom-app-store-submission")` | Submission checklist |
| `Skill("axiom:axiom-shipping")` | Release readiness |
| `Skill("axiom:axiom-privacy-ux")` | Privacy manifest verification |
| `Task(agent="axiom:security-privacy-scanner")` | Final security scan |

### Task Completion (Every Phase)
```
Skill("functional-validation")          -- no-mock methodology
Skill("ios-validation-gate")            -- 3-gate protocol
Skill("gate-validation-discipline")     -- evidence requirement
Skill("verification-before-completion") -- final checklist
```

## Critical Pitfalls (Top 5)

1. **Wrong backend binary** -- An old backend at `/Users/nick/ils/ILSBackend/` returns raw arrays with snake_case. Run `lsof -i :9999 -P -n` at session start. Path MUST contain `ils-ios/`.

2. **Claiming PASS without reading evidence** -- Previous sessions scored 1.5-3.1/5.0 because agents reported PASS without verifying screenshots. ALWAYS use Read tool on every screenshot. "17/21 verified" is 4 failures, not a pass.

3. **Over-planning, under-executing** -- 6 plans created over 10 days with incomplete validation in past sessions. The audit plan already exists (1,370 lines). Execute it. One change, one verify.

4. **Cross-platform drift** -- Fix in iOS but not macOS (or vice versa). After EVERY code change, build BOTH platforms. The duplicated `AppState` class is the highest-risk drift point.

5. **Claude CLI subprocess hangs** -- `CLAUDECODE=1` env vars trigger nesting detection. Must be stripped in `ClaudeExecutorService.swift:executeWithSDK()`. Chat requests that never complete indicate this pitfall.

## Key Constraints

- **No mocks/stubs/tests:** Global mandate. Validate through real UI + screenshots + curl only.
- **Evidence-based:** Every PASS requires screenshot/JSON/terminal evidence. Read and verify before claiming.
- **Cross-platform parity:** After any iOS fix, check and fix macOS. Build all 3 targets.
- **Dedicated simulator only:** UDID `50523130-57AA-48B0-ABD0-4D59CE455F14`. Others belong to other AI sessions.
- **Immediate execution:** No multi-session planning. Implement, verify, move on.
- **Parallel builds:** iOS + macOS + Backend builds are independent. Always run in parallel with `run_in_background: true`.

## Implications for Roadmap

### Parallel Execution Strategy

```
Group A (parallel): Phase 0 + Phase 1 + Phase 2
  Gate: all 3 builds green, before-state captured, AddMCPServerView verified

Group B (parallel): Phase 3 + Phase 4 + Phase 5
  Gate: all mandates verified, visual audit complete, functional audit complete

Group C (sequential): Phase 6 -> Phase 7 -> Phase 8 -> Phase 9
  Rationale: each depends on prior phase results
```

### Phase Ordering Rationale

- Phases 0-2 establish the baseline: clean builds, before-state screenshots, and the one gap verified. Without these, no subsequent phase can produce trustworthy evidence.
- Phases 3-5 are the audit core: mandate verification proves spec compliance, visual audit catches UI defects, functional audit catches interaction bugs. These three can run in parallel because they test different dimensions.
- Phase 6-7 require backend to be running and producing correct data, which Phase 0 verifies. Integration validation (Phase 7) needs both backend curl results AND app screenshots, so it follows Phase 6.
- Phase 8 is proactive bug hunting beyond the spec -- empty states, edge cases, a11y, offline recovery. It goes late because it benefits from all prior fixes.
- Phase 9 is the final report. It depends on everything else being complete.

### Research Flags

**Phases needing careful execution (not more research -- the plan is complete):**
- **Phase 4:** iPad Split View break (C4) and reduce-motion violations (C1-C3) are the highest-impact backlog items. Fix these during visual audit.
- **Phase 5:** Deep link testing via `xcrun simctl openurl` may trigger "Open in ILSApp?" system dialog. Use `idb_describe` to find the confirm button.
- **Phase 6:** MCP env masking is security-critical. Verify `maskSensitiveEnv()` in `MCPController.swift` lines 21-43 produces `***masked***` for ALL env values.
- **Phase 8:** Dynamic Type at XXL and VoiceOver testing may reveal issues not visible in standard screenshots.

**Phases with standard patterns (execute directly):**
- **Phase 0:** Build verification is mechanical. Run 3 builds in parallel, check exit codes.
- **Phase 1:** Screenshot capture follows established `idb_describe` + `xcrun simctl screenshot` workflow.
- **Phase 9:** Report generation is a documentation task using evidence already collected.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Direct analysis of Package.swift, Package.resolved, project.yml, 244 Swift files |
| Features | HIGH | Full glob of all view files, spec cross-reference, AddMCPServerView verified as implemented |
| Architecture | HIGH | Read 40+ source files, all patterns verified with line-number references |
| Skills | HIGH | Complete inventory from CLAUDE.md, MEMORY.md, skill files, phase mapping verified |
| Pitfalls | HIGH | 14 documented pitfalls from 10+ real sessions, all with causes and fixes |
| Audit Plan | HIGH | Read full 1,370-line plan, 10 phases with evidence manifests |

**Overall confidence:** HIGH

### Gaps to Address During Execution

- **iPad simulator UDID:** Plan references `C074375B-2CB2-4F95-A55C-972F2FF35041` for iPad. Verify this simulator exists before Phase 4/5.
- **macOS screenshot automation:** `screencapture -l` needs CGWindowID. May need fallback to full-screen capture or manual Cmd+Shift+4.
- **GitHub search 401 handling:** Skills and Plugins GitHub search returns 401 without `GITHUB_TOKEN`. Document as expected behavior, not failure.
- **Backlog triage boundary:** The 39 backlog items may not all be fixable within audit scope. Prioritize CRITICAL items (C1-C9) during visual audit phases; defer MEDIUM/LOW if they risk scope creep.
- **`SSEClient` ObservableObject migration (M5):** Only remaining `ObservableObject` in the codebase. Low risk but notable for modernization.

## Sources

### Primary (HIGH confidence -- direct code reading)
- `Package.swift`, `Package.resolved`, `ILSApp/project.yml` -- build system and dependencies
- 40+ Swift source files across all 4 modules -- architecture patterns and code conventions
- `docs/ils.md` (~4,300 lines) -- master build orchestration specification
- `.omc/plans/ils-comprehensive-audit-remediation.md` (1,370 lines) -- audit plan v3
- `.claude/skills/ils-ios-project/references/audit-backlog.md` -- 39 prioritized findings

### Secondary (HIGH confidence -- project memory)
- `CLAUDE.md` -- project instructions, common pitfalls, build commands
- `MEMORY.md` -- session memory with lessons learned from 10+ sessions
- `.claude/skills/` -- 3 custom skills (ils-ios-project, appstore-check, full-audit)

---
*Research completed: 2026-02-19*
*Ready for roadmap: yes*
