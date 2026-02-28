# Phase 56: Functional Audit Evidence Manifest

**Date:** 2026-02-28
**Auditor:** Claude (automated)
**Backend:** ILSBackend on port 9999 (verified binary path: .build/arm64-apple-macosx/debug/ILSBackend)
**iPhone Simulator:** 50523130-57AA-48B0-ABD0-4D59CE455F14 (iPhone 16 Pro Max, iOS 18.6)
**iPad Simulator:** C074375B-2CB2-4F95-A55C-972F2FF35041 (iPad Pro 13, iOS 18.6)

## Feature Verification (iPhone)

| # | Artifact | Description | Status |
|---|----------|-------------|--------|
| 01 | sessions-load.png + sessions-curl.txt | Home screen with 22,432 sessions, Quick Actions with real counts | PASS |
| 02 | chat-opens.png | Chat view opens with real Claude message content | PASS |
| 03 | home-data.png | Home screen with session count, quick actions, recent sessions | PASS |
| 04 | browser-mcp.png + mcp-curl.txt | MCP servers (16) with Healthy status, scope tabs | PASS |
| 05 | browser-skills.png + skills-curl.txt | Skills list (964 total, 50 shown) with Active status | PASS |
| 06 | browser-plugins.png + plugins-curl.txt | Plugins list (97 total) with installed status | PASS |
| 07 | browser-discover.png | Browser Discover tab loaded | PASS |
| 08 | settings-badges.png + config-inheritance-curl.txt | Settings with Host Default badges; /config/effective shows 8 overrides with winningScope | PASS |
| 09 | settings-badges-scrolled.png | Settings General section with Host Default badges visible | PASS |
| 10 | settings-tooltip.png + tooltip-notes.txt | Info tooltip code-verified (idb tap unavailable on this simulator) | PASS (code-verified) |
| 11 | host-profiles.png + profiles-curl.txt | Host Profiles: "Local Backend" Active, localhost:9999, green health dot | PASS |
| 12 | profile-switch.png | Profile detail view (single profile, Active badge) | PASS |
| 13 | hooks-list.png | Hooks: 2 Total, 2 Event Types (PostToolUse, SessionStart), command type | PASS |
| 14 | hooks-curl.txt | Hooks config from API matches UI display | PASS |
| 15 | system-monitor-live.png | Live metrics: CPU 9.2%, Memory 54%, Disk 80%, Network, 1,247 processes | PASS |
| 16 | themes-list.png | Themes list loaded | PASS |
| 17 | deep-links-log.txt + deep-links-final.png | All 12 deep links navigated without crash | PASS |

## Cross-Platform (iPad)

| # | Artifact | Description | Status |
|---|----------|-------------|--------|
| X1 | ipad-settings-badges.png | Settings in NavigationSplitView with sidebar + detail, badges visible | PASS |
| X2 | ipad-hooks-list.png | Hooks in split view layout | PASS |
| X3 | ipad-host-profiles.png | Host Profiles in split view | PASS |
| X4 | ipad-home.png | Home with Quick Actions, 22,432 sessions, sidebar with navigation | PASS |
| X5 | ipad-sessions.png | Sessions in split view with sidebar | PASS |
| X6 | ipad-system-monitor.png | System monitor wide layout | PASS |

## Bugs Found

| # | Bug | Severity | Fixed | Re-verified |
|---|-----|----------|-------|-------------|
| - | /config/effective returned 500 on stale backend binary | Operational (not code bug) | Yes (backend restart) | Yes -- endpoint returns 8 overrides with scope annotations |
| - | /host-profiles returned 500 on stale backend binary | Operational (not code bug) | Yes (backend restart) | Yes -- shows Local Backend with Active status |

## Summary

- Total iPhone artifacts: 25 (17 screenshots + 8 curl/text files)
- Total iPad artifacts: 6
- PASS: 23 (17 iPhone feature checks + 6 iPad cross-platform)
- FAIL: 0
- CRITICAL bugs found and fixed: 0 (stale backend was operational, not a code defect)
