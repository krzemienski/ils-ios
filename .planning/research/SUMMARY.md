# Project Research Summary

**Project:** ILS iOS/macOS — v3.1 Comprehensive Audit, Bug Fix & UX Overhaul
**Domain:** Product quality overhaul — config sync, GitHub browse/install, Host Profiles, navigation/UX
**Researched:** 2026-02-24
**Confidence:** HIGH (all findings grounded in direct codebase inspection)

---

## Executive Summary

The v3.1 milestone shifts from code health to product quality. Research across Stack, Features, Architecture, and Pitfalls reveals the codebase is far more ready than expected — **no new packages needed**, **backend endpoints are 70-80% complete**, and **most UI patterns already exist** but need broader application. The highest-risk item is Host Profile activation, which is architecturally broken for multi-host switching.

---

## Key Findings (Cross-Research Synthesis)

### 1. No New Dependencies Required
All four feature areas are implementable with the existing stack. GitHubService, ConfigFileService, CitadelSSHService, FleetController, and NavigationStack patterns all exist. (STACK.md)

### 2. Backend Is More Complete Than Expected
- Skills: `GET /skills/search`, `POST /skills/install` — fully implemented
- Plugins: `POST /plugins/install`, enable/disable/uninstall — fully implemented
- Config: `GET /config?scope=user` reads host's `~/.claude/settings.json`
- Fleet: CRUD + atomic `POST /fleet/:id/activate`
- **Only 2 new endpoints needed:** `GET /config/defaults` (merged config) and `GET /fleet/:id/config` (remote host config proxy)
(ARCHITECTURE.md)

### 3. Host Profile Activation Is Architecturally Broken (CRITICAL)
`HostProfilesViewModel` creates its own `APIClient()` disconnected from `AppState`. Activating a profile never updates `appState.serverURL`. All other screens silently continue hitting the previous host. **This must be fixed before any other feature work.** (PITFALLS.md, FEATURES.md)

### 4. Config Sync Write-Back Will Delete CLI Fields
`SettingsViewModel.saveConfig()` does a full struct round-trip PUT. Optional fields like `hooks`, `env`, `permissions` round-trip as JSON omission — the app will silently drop them. **Write allowlist mandatory before any config save UI ships.** (PITFALLS.md)

### 5. Chat Back Button Requires Architectural Change
`ActiveScreen` is a flat enum swap, not a NavigationPath push. Adding a back button conflicts with `@SceneStorage("lastChatSessionId")`. This should be its own phase. (FEATURES.md)

### 6. GitHub Integration Has Three Known Bugs
- Hardcoded `main` branch in `fetchRawContent()` — fails on `master` repos
- Global `isLoading` in SkillsViewModel blocks list during install (PluginsVM already solved this)
- Rate limit 429 surfaces as opaque error with no guidance
(PITFALLS.md)

### 7. Navigation Fix Is Simpler Than Expected
The hamburger is already at the NavigationStack level. The issue is child views adding conflicting `.topBarLeading` items. Fix = audit and remove conflicts. (ARCHITECTURE.md)

---

## Recommended Phase Order

Based on dependency analysis across all four research documents:

| Order | Phase | Rationale |
|-------|-------|-----------|
| 1 | Navigation & UX Overhaul | Zero backend risk, unblocks comfortable development |
| 2 | Host Profiles Fix + Redesign | CRITICAL prerequisite — broken activation blocks all other features |
| 3 | Settings & Config Sync | Lowest-risk feature; patterns exist, needs broader application |
| 4 | Browse, Skills & Plugins | Backend complete; pure iOS UI work against existing endpoints |
| 5 | System Monitor & Themes | Restoration work, lower dependency on other phases |
| 6 | Cross-Platform Validation | Final gate — iOS, iPadOS, macOS parity check |

**Key constraint:** Phase 2 (Host Profiles) MUST complete before Phase 3-4 can be validated, because config sync and GitHub install both depend on targeting the correct host.

---

## Risk Matrix

| Risk | Severity | Mitigation |
|------|----------|------------|
| Host switch doesn't propagate to AppState | CRITICAL | Fix HostProfilesViewModel injection in Phase 2 |
| Config save drops CLI fields | HIGH | Implement write allowlist before any save UI |
| GitHub install orphaned on navigation | MEDIUM | Lift SkillsVM to SidebarRootView or use Task tracking |
| Chat back button conflicts with @SceneStorage | MEDIUM | Separate phase; design before implementation |
| macOS build breaks from iOS-only APIs | LOW | Every phase DOD includes `xcodebuild ILSMacApp` |

---

## Research Files

| File | Lines | Focus |
|------|-------|-------|
| STACK.md | 236 | Technology recommendations — what exists, what to build, what NOT to add |
| FEATURES.md | 334 | Feature landscape — table stakes, differentiators, anti-features, priority matrix |
| ARCHITECTURE.md | 411 | Integration analysis — components, data flows, build order |
| PITFALLS.md | 431 | Codebase-specific pitfall catalog — 15 pitfalls with prevention strategies |

---

*Research complete. Ready for requirements definition.*
