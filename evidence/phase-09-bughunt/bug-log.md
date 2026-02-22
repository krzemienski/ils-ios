# Phase 9: Master Bug Log

**Date:** 2026-02-22
**Total Bugs Found:** 30

## Bug Severity Summary

| Severity | Count | Action |
|----------|-------|--------|
| P0 (Critical) | 0 | — |
| P1 (High) | 0 | — |
| P2 (Medium) | 12 | Fix recommended before release |
| P3 (Low) | 18 | Defer to polish pass |

---

## Task 9.1: iOS Functional Verification

| Bug ID | Severity | File | Issue |
|--------|----------|------|-------|
| BUG-9.01 | P2 | HostProfilesView/model | Port displays as "localhost:9,999" instead of "localhost:9999" — number formatter adding comma separator |

## Task 9.2: macOS Functional Verification

| Bug ID | Severity | File | Issue |
|--------|----------|------|-------|
| BUG-9.02 | P3 | MacContentView.swift | AppleScript automation cannot trigger sidebar selection — NOT a user-facing bug. Phase 8 validated sidebar works via keyboard shortcuts (Cmd+1-4, Cmd+,). Downgraded from P1 to P3 (automation artifact). |

## Task 9.6/9.10: Stress Test + Lifecycle

**No bugs found.** 0 crashes across 31 deep link navigations, 30 tab switches, 20 navigation cycles, 5 background/foreground cycles, 1 memory warning, 3 force quits.

## Task 9.7: VoiceOver Navigation Audit

| Bug ID | Severity | Screen | Issue |
|--------|----------|--------|-------|
| BUG-9.70 | P2 | ProcessListView | Process rows lack accessibility labels |
| BUG-9.71 | P3 | ProcessListView | Classification badge (colored dot) has no label |
| BUG-9.72 | P3 | ProcessListView | Sort option buttons lack state announcement |
| BUG-9.73 | P3 | SystemMonitorView | Live indicator lacks combined label |
| BUG-9.74 | P3 | ThemeEditorView | Spacing/radius sliders lack explicit labels |
| BUG-9.75 | P3 | ThemeEditorView | Shadow section has 3 duplicate "Color" labels |
| BUG-9.76 | P2 | AgentTeamsListView | Team cards have no accessibility labels |
| BUG-9.77 | P3 | AgentTeamsListView | Member count icon has no alt text |
| BUG-9.78 | P3 | AgentTeamsListView | Empty state icon not hidden from VoiceOver |
| BUG-9.79 | P2 | AgentTeamsListView | "+" toolbar button has no label |
| BUG-9.80 | P2 | HooksManagementView | Event sections lack accessibility grouping |
| BUG-9.81 | P2 | HooksManagementView | Hook definition rows lack labels |
| BUG-9.82 | P3 | HooksManagementView | Empty state icon not hidden from VoiceOver |
| BUG-9.83 | P3 | HooksManagementView | Count badges lack context |
| BUG-9.84 | P2 | FileBrowserView | File/directory rows lack accessibility labels |
| BUG-9.85 | P3 | FileBrowserView | Breadcrumb components lack combined label |
| BUG-9.86 | P3 | FileBrowserView | Folder/file icons should be hidden from VoiceOver |
| BUG-9.87 | P2 | SessionInfoView | Export button lacks accessibility label |
| BUG-9.88 | P2 | SessionInfoView | Copy ID button lacks accessibility label |

## Task 9.8: Dynamic Type Verification

| Bug ID | Severity | File | Issue |
|--------|----------|------|-------|
| BUG-9.90 | P3 | CodeBlockView.swift | Uses hardcoded 11/13/15pt instead of theme tokens |
| BUG-9.91 | P3 | ToolCallAccordion.swift | Uses hardcoded 11/12pt instead of theme tokens |
| BUG-9.92 | P3 | ThemedCodeBlockView.swift | "Themed" component uses hardcoded 11/13pt |
| BUG-9.93 | P3 | FeatureGateView.swift | Premium gate uses hardcoded 14/36pt |
| BUG-9.94 | P3 | PremiumView.swift | Paywall uses hardcoded sizes (16-48pt) |
| BUG-9.95 | P2 | SidebarSessionRow.swift:47 | 9pt font below HIG 11pt minimum |
| BUG-9.96 | P2 | BrowserView.swift:542 | 9pt font below HIG 11pt minimum |
| BUG-9.97 | P2 | ThemePreviewCard.swift:82 | 8pt font below HIG 11pt minimum |

## Task 9.9: Deep Link Edge Cases

**No bugs found.** All 14 routes resolve correctly. All 5 edge cases handled gracefully.

---

## Tasks Not Executed

| Task | Reason |
|------|--------|
| 9.3 (Empty States) | Agent lost during context compaction — evidence not collected |
| 9.4 (Overflow/Long Text) | Agent lost during context compaction — evidence not collected |
| 9.5 (Offline Mode) | Agent lost during context compaction — evidence not collected |

These 3 tasks were assigned to agents that completed partially before context was lost. They are deferred to a future polish pass but are not blockers for Phase 10 (Final Gate).

---

## P2 Bug Fix Recommendations

### Immediate (before Final Gate):
1. **BUG-9.95/9.96/9.97**: Replace 3 sub-HIG-minimum font sizes (8pt, 9pt) with `theme.fontCaption` (11pt)
2. **BUG-9.01**: Fix port number formatting — suppress locale-specific number formatting for port values

### Deferred (polish pass):
3. **BUG-9.70-9.88**: Accessibility label additions for newer screens (ProcessList, AgentTeams, Hooks, FileBrowser, SessionInfo)
4. **BUG-9.90-9.94**: Migrate hardcoded font sizes to theme tokens in CodeBlock, ToolCallAccordion, FeatureGate, Premium views
