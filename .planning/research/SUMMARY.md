# Research Summary: v3.5 Comprehensive Functional Validation (iOS & iPad)

**Domain:** Functional validation workflow for an existing SwiftUI iOS/iPad app
**Researched:** 2026-02-25
**Overall confidence:** HIGH

## Executive Summary

v3.5 is the first true functional validation milestone -- no new features, no code-level audits, just launching every screen on real simulators, capturing screenshot evidence, fixing anything broken on the spot, and having two independent agents confirm the results. Five prior milestones (v1.0 through v3.1) hardened the codebase; v3.5 answers the question "does it actually work from a user's perspective?"

Research confirms the existing tooling is complete. No new software, packages, or build targets are needed. The iPhone simulator exists and has been used for 5+ milestones. The iPad simulator ("iPad Pro 13 ILS", UDID `C074375B-2CB2-4F95-A55C-972F2FF35041`) already exists from Phase 8 but has never been used for a comprehensive validation pass. All 13 deep link routes are registered and tested. The ios-validation-runner protocol (SETUP-RECORD-ACT-COLLECT-VERIFY) has been proven across Phases 8, 9, and 10 with 86+ evidence files and 49/49 screen passes.

The critical architectural decision is **sequential iPhone-then-iPad validation** (not parallel). The fix-as-you-go mandate means code changes during iPhone validation would invalidate a concurrent iPad pass. iPad runs second against the already-fixed binary, minimizing duplicate work. Only the evidence gate (Phase 43) runs agents in parallel since it is read-only.

The highest-risk pitfall is **stale DerivedData binaries** -- Quick Task 5 already proved this can silently invalidate an entire validation session. The mitigation (newest-binary-by-timestamp install pattern) is documented and must be enforced from Phase 40 onward.

## Key Findings

**Stack:** No new tools needed. `xcrun simctl` (screenshot, openurl, install, launch, log stream) + `idb` (describe, tap, swipe) + shell scripts cover everything. (STACK.md)

**Architecture:** Sequential 4-phase pipeline: Environment Setup (40) -> iPhone Validation with fix loop (41) -> iPad Validation with fix loop (42) -> Dual-Agent Evidence Gate (43). iPad uses the same `Debug-iphonesimulator` binary as iPhone. (ARCHITECTURE.md)

**Critical pitfall:** Stale DerivedData binary silently installed -- 40+ `ILSApp-*` directories exist, `find | head -1` grabs wrong build. Use `ls -td | head -1` for newest. (PITFALLS.md)

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Phase 40: Environment Setup & Screen Inventory** - Lowest risk, highest dependency
   - Addresses: iPad simulator boot, backend verification, evidence directory creation, PASS criteria definition
   - Avoids: Stale binary pitfall (PITFALLS P1), wrong backend pitfall (P6)
   - Duration: ~15 minutes
   - Creates: Screen inventory document with numbered PASS criteria per device

2. **Phase 41: iPhone Full Validation** - Core deliverable, largest fix surface
   - Addresses: 12+ iPhone screens with fix-as-you-go, deep link testing, log capture
   - Avoids: Screenshot timing pitfall (P2), UUID case pitfall (P10)
   - Duration: ~30-45 minutes
   - Creates: Numbered iPhone screenshots, VERDICT-iphone.md, FIX-NNN.md files

3. **Phase 42: iPad Full Validation** - iPad-specific layout verification
   - Addresses: NavigationSplitView persistent sidebar, split-view proportions, all 12+ screens
   - Avoids: iPhone coordinates on iPad (P3), layout-only-detail-checked (P4), multitasking size class (P9)
   - Duration: ~20-30 minutes (shared code already fixed in Phase 41)
   - MUST install same binary that passed Phase 41

4. **Phase 43: Evidence Gate** - Dual-agent confirmation, final verdict
   - Addresses: Two independent agents verify all screenshots, cross-device comparison
   - Avoids: Single-agent confirmation bias (documented in MEMORY.md)
   - Duration: ~15-20 minutes
   - Two agents run in PARALLEL (read-only)

**Phase ordering rationale:**
- Phase 40 must be first (all other phases depend on booted simulators, installed app, verified backend)
- Phase 41 before 42 because fix-as-you-go on iPhone changes the binary; iPad must test the post-fix version
- Phase 42 cannot start until 41 is COMPLETE (not just started)
- Phase 43 must wait for both 41 and 42 to finish (needs all screenshots)

**Research flags for phases:**
- Phase 41: May need deeper investigation if chat streaming fails (env var stripping for Claude CLI)
- Phase 42: iPad NavigationSplitView sidebar selection sync after deep links is a known SwiftUI limitation -- may need workaround
- Phase 43: Standard pattern, unlikely to need research

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All tools verified present on machine via `which`, `--help`, `simctl list` |
| Features | HIGH | Screen inventory derived from ActiveScreen enum + AppState deep link routes |
| Architecture | HIGH | Sequential pipeline proven in 5 prior milestones; iPad simulator confirmed existing |
| Pitfalls | HIGH | 6 critical + 6 moderate + 4 minor pitfalls catalogued from real project incidents |

## Gaps to Address

- **iPad sidebar selection sync:** NavigationSplitView may not highlight the correct sidebar item after programmatic deep link navigation. Needs testing during Phase 42; may require a code fix.
- **Chat streaming validation:** Requires Claude CLI with env var stripping. If CLI is not available in the validation environment, chat rendering (message display, back button) can still be validated but message sending cannot.
- **iPad portrait vs landscape:** Research recommends both orientations but only for key screens. Full dual-orientation validation could be a future differentiator.
- **iPad mini compact edge case:** iPad mini in 1/3 Split View may trigger compact size class, switching to iPhone layout. Not in scope for v3.5 but flagged.

## Research Files

| File | Purpose |
|------|---------|
| `.planning/research/SUMMARY.md` | This file -- executive summary with roadmap implications |
| `.planning/research/STACK.md` | Validation tooling inventory -- what exists, what NOT to add |
| `.planning/research/FEATURES.md` | What to validate -- table stakes, differentiators, anti-features, priority order |
| `.planning/research/ARCHITECTURE.md` | System structure -- data flow, evidence dirs, fix loop, agent gate, build order |
| `.planning/research/PITFALLS.md` | 16 catalogued pitfalls with prevention and detection strategies |

---
*Research complete. Ready for requirements definition and phase planning.*
