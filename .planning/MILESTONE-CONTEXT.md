# Milestone Context: v4.0 Comprehensive Spec Compliance Audit & Remediation

**Source:** User's comprehensive audit specification (Feb 25, 2026)
**Gap Analysis:** Already completed as Quick Task 6 — see `.planning/quick/6-comprehensive-ils-audit-and-remediation-/GAP-ANALYSIS.md` (673 lines)

## Milestone Goal

Systematically close every gap between the 3 original ILS build specifications and the current application state, with evidence-backed verification at every step. Zero CRITICAL or HIGH gaps remaining. 20+ evidence artifacts collected. All gate checks PASS.

## Key Findings from Gap Analysis (Quick Task 6)

- **~78% strict compliance** across 103 top-level requirements from 3 specs
- **~87% effective compliance** when accounting for EVOLVED/EXCEEDED implementations
- **Zero CRITICAL or HIGH gaps** — all remaining are MEDIUM (7) or LOW (16)
- **50/50 backend endpoints PASS**, 23 iOS screens verified, 13 themes (exceeds spec's 12)
- **Top 3 quick wins** (~8 hours): Quick Settings toggles, HomeView Quick Actions, GitHub skill search UI wiring
- **Largest gap area:** macOS feature parity (drag-drop, Handoff, menus)

## Phase Structure (from user's audit spec)

1. **Gap Analysis** — DONE (Quick Task 6, GAP-ANALYSIS.md)
2. **CRITICAL Gap Remediation** — None identified (0 CRITICAL gaps)
3. **HIGH Gap Remediation** — None identified (0 HIGH gaps)
4. **MEDIUM Gap Remediation** — 7 items: Quick Settings toggles, HomeView Quick Actions, GitHub skill search wiring, SSH auth form specifics, raw JSON config editor polish, custom marketplace registration, additional settings UX
5. **LOW Gap Remediation** — 16 items: cosmetic/polish differences from spec
6. **Visual Audit** — All platforms (iPhone, iPad, Mac) with screenshot evidence
7. **Functional Audit** — Real data verification on all platforms
8. **Backend Audit** — cURL every endpoint, verify JSON structure matches spec
9. **Integration Validation** — Correlated backend+frontend evidence
10. **Proactive Bug Hunt** — Edge cases, offline, accessibility, memory

## FIX_PROTOCOL (from user's audit spec)

Every fix follows this protocol:
1. Activate the relevant axiom skill
2. Invoke `/axiom:ask` with: issue description, relevant code, and proposed fix
3. Wait for response before implementing
4. Log the response
5. Implement the fix
6. Rebuild → screenshot or cURL → visually confirm → document

## Success Criteria

1. Gap Analysis Matrix shows zero CRITICAL or HIGH gaps
2. All 20+ evidence artifacts from spec collected with PASS status
3. All gate checks PASS
4. Every screen on every platform visually matches specification
5. Every interactive element functions correctly with real data
6. Zero mocks, zero stubs, zero placeholder implementations
7. All fixes traceable through axiom:ask logs

## Three Spec Documents

1. `specs/ils-complete-rebuild/requirements.md` — 42 FRs, 18 USs
2. `specs/rebuild-ground-up/requirements.md` — 19 USs, 24 FRs
3. `.claude/plan/MASTER_ROADMAP.md` — 13 Phases, 130+ items

## Research Decision

Skip research — the Gap Analysis (Quick Task 6) already provides comprehensive codebase-to-spec mapping. Proceed directly to requirements definition.

## Coding Guidelines (from user)

- Avoid over-engineering. Only make changes directly requested or clearly necessary
- Don't add features, refactor code, or make "improvements" beyond what was asked
- Don't add error handling for scenarios that can't happen
- Don't create helpers or abstractions for one-time operations
- The right amount of complexity is the minimum needed for the current task
- NO mocks, stubs, test doubles, unit tests, or test files
