# Feature Research

**Domain:** Native iOS/macOS client for Claude Code CLI — v3.1 new feature areas
**Researched:** 2026-02-24
**Confidence:** HIGH (grounded in existing codebase + Claude Code docs + iOS HIG + web research)

---

## Scope Framing

This research covers the **four new feature areas** added in v3.1. Existing functionality (chat,
sessions, themes, system monitor, etc.) is already built and out of scope here. The question
per feature area is: what does the user expect, what differentiates us, and what should we
explicitly not build?

Feature areas researched:
1. Host CLI config sync with inheritance indicators
2. GitHub skill/plugin browse-and-install
3. Host Profiles redesign (multi-host switching, context reload)
4. Navigation/UX overhaul (side menu, back button, home layout)

---

## Feature Landscape

### 1. Host CLI Config Sync / Inheritance

#### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Display current effective config values pulled from host | App showing settings that differ from the CLI loses user trust immediately | LOW | Backend `/config?scope=user` exists; `SettingsViewModel.loadConfig()` already fetches it |
| Show which scope owns each value (user / project / enterprise) | Claude Code has a 6-level precedence chain (Enterprise > CLI > Local Project > Shared Project > User > Defaults); users need to know why a value is what it is | MEDIUM | `ConfigInfo` already carries `scope` and `path`; need to surface per-field, not just per-file |
| "Host Default" badge on inherited (nil) fields | Signals "this is not your override" at a glance without requiring docs | LOW | `InheritanceBadge` already exists in `SettingsConfigSection`; pattern needs to be applied consistently to ALL settings fields, not only model and two toggles |
| "Custom" badge on overridden fields | Signals "you changed this" so user can find and revert their overrides | LOW | Same `InheritanceBadge` component, `isInherited: false` branch already styled |
| Refresh config on reconnect / host switch | Settings must reload when the active host changes or connection drops/recovers | LOW | `loadConfig()` already called in `loadAll()` on `.task`; needs `onChange(appState.isConnected)` trigger consistently |
| Explanatory tooltip per setting | Users unfamiliar with Claude Code CLI options need context for each field | LOW | `SettingsInfoButton` popover already built; coverage is partial — needs to reach every field |

#### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| System prompt field displayed (read-only if inherited) | System prompt is the most impactful config key for power users; it is not rendered in Settings at all today | MEDIUM | `ClaudeConfig.systemPrompt` exists in `ILSShared`; add a read-only text block with InheritanceBadge |
| Inline edit of user-scope settings with immediate round-trip save | Write-back closes the "read-only observer" gap; users expect iOS Settings to be editable, not just a mirror | MEDIUM | `saveConfig()` and `saveConfigToggle()` already exist; need to wire remaining fields (system prompt, env vars, status line) |
| Project-scope config section alongside user-scope | Power CLI users work in multiple projects with different settings; seeing both scopes is expected by anyone who uses `claude config --project` | MEDIUM | `loadConfig(scope: "project")` already takes a scope param; need a scope-picker tab or dual-section layout in SettingsConfigSection |
| Scope waterfall visualiser — show all three layers for one key with override arrows | Makes the inheritance chain tangible; no other Claude Code client does this | HIGH | Needs backend to return merged + per-scope values simultaneously; significant new API work; defer to v3.2+ |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| API key editing from the iOS app | Users want a single pane of glass | Security: API keys must not transit through ILS backend in plaintext; Keychain storage on the host is correct | Show masked key + source (env var, config file); provide the `claude config set apiKey` terminal command hint |
| Full raw JSON editor as the primary config UI | Power users want direct access | Raw JSON is error-prone with no schema validation; one syntax error silently breaks Claude Code sessions | Keep existing `ConfigEditorView` as an advanced opt-in; default UI uses structured fields with badges |
| Automatic config write-back without confirmation | Seamless experience | Silently overwriting project-scope config (checked into git) affects teammates | Show confirmation sheet noting scope and file path before saving; distinguish user vs project scope writes |

---

### 2. GitHub Skill/Plugin Browse and Install

#### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Search GitHub for skills by keyword | Users expect to find skills the way they find npm packages — search first, browse second | LOW | `SkillsViewModel.searchGitHub()` → `GET /skills/search?q=` already implemented; UI section `githubBrowseSection` exists in `BrowserView` |
| Display result name, description, star count, repo path | Same metadata pattern as App Store or npm; stars = social proof | LOW | `GitHubSearchResult` model carries all four fields; `gitHubResultRow()` renders them |
| One-tap install with per-item progress indicator | Friction-free install is the baseline expectation; a multi-step wizard is a differentiator, not a requirement | MEDIUM | `installFromGitHub()` → `POST /skills/install` exists; currently uses global `isLoading` flag, blocking the entire list during any install |
| Per-item install spinner (not global spinner) | If the spinner blocks the entire list, users cannot browse while installing | MEDIUM | Need `installingSkills: Set<String>` in `SkillsViewModel` — mirrors the `installingPlugins: Set<String>` pattern already in `PluginsViewModel` |
| Post-install "Installed" state badge on result row | User needs confirmation without leaving the browse list | MEDIUM | No installed-state tracking on `gitHubResultRow()`; compare result.repository against installed `skills` array |
| Plugin GitHub browse (not just skills) | Plugins and skills both come from GitHub repos; users expect symmetry between the two tabs | MEDIUM | `PluginsViewModel.searchMarketplace()` and `addMarketplace()` exist; no GitHub browse UI in the Plugins tab yet — skills tab has it, plugins do not |
| Enable/disable installed skill or plugin from Browse | After install, users want to control active state without navigating to a separate detail screen | LOW | Skill toggle: `toggleSkillActive()` exists. Plugin enable/disable: `enablePlugin()/disablePlugin()` exist. Both need an inline toggle in the row or detail sheet |

#### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Uninstall from Browse tab via context menu | Closes the install/uninstall loop without requiring the detail view | LOW | `deleteSkill()` and `uninstallPlugin()` exist; add `.contextMenu` with "Remove" on installed rows |
| Trending / featured skills list (stars-sorted default query) | Discovery without search intent — browse mode for users who do not know what they want | MEDIUM | Backend can return a default query (e.g. `topic:claude-skill sort:stars`); no new GitHub API work required |
| GitHub repo README preview before install | Reduces blind installs — user can see what the skill does before committing | HIGH | Needs new backend endpoint to fetch README markdown; render using existing `MarkdownTextView`; defer to v3.1.x |
| Install progress with backend log streaming | Long-running git clone shows real progress instead of a blocking spinner | HIGH | Requires SSE endpoint for install operations; significant backend work; defer to v3.2+ |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| App Store-style review/rating system for skills | Makes the marketplace feel legitimate | Requires a hosted review backend, moderation, and accounts — out of scope for a dev tool client | Show GitHub stars as social proof; link to GitHub Issues for community feedback |
| Automatic update checks for installed skills | "Keep skills up to date" sounds good | Silently pulling new skill versions can break saved prompts; Claude Code CLI treats skills as local files the user owns | Surface "newer version available" badge and let user pull manually |
| Browse arbitrary GitHub repos as a general file browser | Power users want raw GitHub access | Scope creep that duplicates GitHub.com; adds complexity without native value | Keep scope to repos tagged for Claude Code skills/plugins |

---

### 3. Host Profiles Redesign (Multi-Host Switching)

#### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Active profile indicator visible on the list row | Users need instant visual confirmation of "which host am I on" | LOW | `HostProfilesView.hostProfileRow()` already shows an "Active" capsule badge when `host.id == viewModel.activeHostId` — this is done |
| One-tap host switch with immediate feedback | Switching hosts is a primary action; it must not require navigating into detail | LOW | `viewModel.activate(id)` fires `POST /fleet/{id}/activate` and updates `activeHostId` locally — this is done |
| App-wide context reload on host switch | After switching hosts, sessions, skills, plugins, and config must all reflect the new host | HIGH | Critical missing piece: `activate()` updates the backend but `AppState.apiClient` still points to the old host URL; need to propagate the switch to `AppState` and trigger reload of all ViewModels |
| Health status badge per host | Users with multiple hosts need to see which are reachable before switching | LOW | Health polling already works (`startHealthPolling()` / `refreshAllHealth()`); colored dot renders via `healthBadge()` |
| Add new host flow | Without adding hosts, the screen is an empty state | LOW | `SSHSetupView` exists and is linked from the toolbar `+` button |
| Remove host with destructive confirmation | Accidental deletions are not recoverable | LOW | `viewModel.remove(id)` exists in context menu; no confirmation sheet today |
| Empty state with onboarding prompt | First-launch experience when no hosts exist | LOW | `EmptyEntityState` already renders with "Add a host profile" description |

#### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Quick-switch from sidebar header or persistent toolbar | Switching hosts is a cross-cutting concern; burying it behind a screen is a UX tax on power users with many hosts | MEDIUM | Add a host-picker `Menu` to the sidebar header; no new ViewModel needed, surface `activate()` from an always-accessible point |
| Per-host config preview on profile detail | Show a read-only summary of the target host's effective Claude Code config before committing the switch | MEDIUM | Needs a temporary `APIClient` pointed at the new host's URL to fetch `/config` before activating |
| Connection test before switch ("Can I reach this host?") | Prevents switching to an unreachable host and being stuck in an error state | LOW | `HostProfileDetailView` has lifecycle Start/Stop/Restart; a health check ping before `activate()` is straightforward |
| Last-connected timestamp per host | Surfaces which hosts are actively used vs stale | LOW | `lastHealthCheck` already on `FleetHost`; show "Last seen: 3 min ago" on each row |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Simultaneous multi-host view (merged sessions from all hosts) | "See everything at once" | Requires multiplexed API clients, cross-host identity disambiguation, and data model changes — massive complexity | Show sessions filtered to the active host; let users switch to browse another host's sessions |
| Auto-switch to the fastest or healthiest host | Intelligent routing | Silently switching active hosts mid-session is disorienting; users lose track of where their work lives | Surface health status prominently; let users manually switch with one tap |
| Host groups or tags | Organisation for power users with many hosts | Adds UI complexity that benefits very few users at current scale | Sort hosts alphabetically with active host always first |

---

### 4. Navigation / UX Overhaul

#### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Hamburger menu accessible from every screen at every navigation depth | If a user navigates deep into a Chat view, they expect to reach the sidebar without back-tapping through the entire stack | LOW | `SidebarRootView` adds the hamburger to the `NavigationStack` toolbar; the issue is that `ChatView` can push sub-views (e.g. `SkillDetailView`) onto the stack, where the toolbar back button visually competes with the hamburger — needs verification and fix at all depths |
| Back button in ChatView returning to the originating screen | Users navigate into Chat from Home or Sessions; tapping back should return them there, not swap to a blank home state | HIGH | `ActiveScreen` is a flat enum — there is no navigation history between screens; switching `activeScreen` to `.chat(session)` loses the origin; requires NavigationPath approach |
| Home screen layout correct and current | Home is the entry point; stale stats or broken layout degrades first impressions | LOW | `HomeView` exists; layout audit needed for spacing, empty states, and stat card accuracy |
| Session list count on Home matches actual data | The stat card must match `/sessions` endpoint count | LOW | `DashboardViewModel` loads from `/stats`; verify against actual session count |
| Side menu swipe gesture from left edge on all screens | iOS users expect the left-edge swipe to open the sidebar — it is a platform convention | LOW | `edgeSwipeGesture` already implemented in `SidebarRootView` with 30pt edge zone; verify it works from within ChatView and nested sub-views |
| Consistent `.inlineNavigationBarTitle()` on all screens | Large title vs inline title mismatch between screens looks unpolished and unintentional | LOW | Most screens already call `.inlineNavigationBarTitle()`; audit for missing instances in the nine `ActiveScreen` destinations |

#### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| NavigationPath-based chat navigation (chat as a pushed view, not a screen swap) | Enables a real "back to sessions" system back button instead of the current screen-swap model; matches iOS platform feel exactly | HIGH | Requires changing `ActiveScreen.chat` from a root-level enum case to a `navigationPath.append()` push; affects `SidebarRootView`, `HomeView`, `ChatView`; `@SceneStorage` chat restoration logic (`lastChatSessionId`) must be rethought |
| Quick-action in Chat to start new session or switch project | Reduces round-trips from Chat back to Home | MEDIUM | Chat toolbar already has a menu; extend rather than redesign |
| macOS keyboard shortcuts for sidebar navigation (Cmd+1…Cmd+9) | macOS users expect keyboard navigation as a first-class interaction | LOW | `.keyboardShortcut()` on sidebar items; macOS `NavigationSplitView` is already persistent |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Tab bar replacing the sidebar | "Tabs are more discoverable" | The app has 9+ screens; iOS tab bar supports 5 before "More" degrades UX; sidebar was deliberately chosen for this app's information architecture | Keep sidebar; improve discoverability by showing screen names alongside icons in the sidebar |
| Breadcrumb trail across navigation levels | Users want to know "where they are" | Breadcrumbs duplicate what NavigationStack's title and back button already communicate; adds visual clutter | Use inline navigation titles consistently; back button label shows the parent screen name automatically |
| Swipe-left/right to navigate between peer screens | "Feels fluid" | Peer-level swipe conflicts with list swipe-to-delete, scroll views, and the sidebar swipe gesture — creates gesture ambiguity | Sidebar handles peer-level navigation; swipe is reserved for within-screen actions |

---

## Feature Dependencies

```
[GitHub Skills Install — Per-item State]
    └──requires──> [SkillsViewModel.installingSkills: Set<String>]
                       └──mirrors──> [PluginsViewModel.installingPlugins — already exists]

[GitHub Plugin Browse UI]
    └──requires──> [Browse section added to BrowserView.pluginsContent]
                       └──reuses──> [PluginsViewModel.searchMarketplace() — already exists]

[Host Switch — Context Reload]
    └──requires──> [AppState.serverURL update on activate()]
                       └──requires──> [All ViewModels reload on isConnected change]
                                          └──pattern exists in──> [BrowserView.onChange(appState.isConnected)]

[NavigationPath Chat Navigation]
    └──requires──> [Chat pushed onto NavigationStack path, not ActiveScreen root swap]
                       └──conflicts──> [@SceneStorage("lastChatSessionId") restoration]
                                          └──must resolve before adopting NavigationPath]

[Config Sync — Project Scope Section]
    └──requires──> [Scope switcher UI in SettingsConfigSection]
                       └──reuses──> [loadConfig(scope: "project") — already in SettingsViewModel]

[InheritanceBadge on all config fields]
    └──requires──> [Backend returning per-field nil vs explicit values — already the contract]
                       └──enhances──> [Scope waterfall visualiser — future differentiator, v3.2+]

[Quick-switch from Sidebar]
    └──requires──> [HostProfilesViewModel accessible from SidebarView]
                       └──requires──> [HostProfilesViewModel or AppState exposes host list]
```

### Dependency Notes

- **GitHub install requires per-item state:** The global `isLoading` flag in `SkillsViewModel` blocks the entire list during install. `PluginsViewModel` already uses `installingPlugins: Set<String>` — replicate this exact pattern in `SkillsViewModel`.
- **Host switch context reload is the highest-risk dependency:** `HostProfilesViewModel.activate()` fires the API call and updates local state but does not update `AppState.serverURL`. The app-wide reload (sessions, settings, browser data) will not happen without wiring these. This is the most architecturally impactful change in v3.1.
- **NavigationPath chat conflicts with @SceneStorage:** Moving chat from a root screen to a pushed view breaks the current `@SceneStorage("lastChatSessionId")` restoration pattern. This must be designed before implementation, not discovered during it.
- **Config project-scope section enhances but does not block config sync:** Showing user-scope config with InheritanceBadges (already largely wired) is the v3.1 baseline. Project-scope is a follow-on within the same milestone if time permits.

---

## MVP Definition

### Launch With (v3.1 baseline — all four areas must ship)

**Config Sync:**
- [ ] InheritanceBadge applied consistently to ALL settings fields (not just model + two toggles) — LOW complexity, high visibility
- [ ] System prompt field displayed in Settings (read-only if inherited from host config) — MEDIUM complexity, critical for power users
- [ ] Config reload on host switch and on reconnect — LOW complexity, correctness requirement

**GitHub Browse / Install:**
- [ ] Per-item `installingSkills: Set<String>` in `SkillsViewModel` — MEDIUM complexity, fixes blocking UX bug
- [ ] Post-install "Installed" state badge on GitHub result rows — MEDIUM complexity, closes the install feedback loop
- [ ] GitHub browse section added to Plugins tab — MEDIUM complexity, symmetry expectation with Skills tab

**Host Profiles:**
- [ ] App-wide context reload when host is switched (`activate()` → `AppState` → reload trigger) — HIGH complexity, correctness requirement
- [ ] Remove host destructive confirmation sheet — LOW complexity, prevents accidental data loss
- [ ] Quick-switch from sidebar header Menu — MEDIUM complexity, discoverability improvement

**Navigation:**
- [ ] Hamburger button visible and tappable from ChatView and all ChatView sub-views — LOW complexity, accessibility bug fix
- [ ] Home screen layout audit and fix — LOW complexity
- [ ] Consistent `.inlineNavigationBarTitle()` across all nine ActiveScreen destinations — LOW complexity

### Add After Validation (v3.1.x)

- [ ] NavigationPath-based Chat navigation (real back button to sessions list) — HIGH complexity; own dedicated phase after baseline ships
- [ ] System prompt inline edit from Settings — MEDIUM complexity
- [ ] Per-host config preview before switching — MEDIUM complexity
- [ ] README preview before skill install — HIGH complexity; requires new backend endpoint

### Future Consideration (v3.2+)

- [ ] Scope waterfall visualiser (all three config layers for one key) — HIGH complexity + new backend API
- [ ] Install progress SSE streaming — HIGH complexity + new backend endpoint
- [ ] macOS keyboard shortcuts for sidebar navigation — LOW complexity but low value until macOS user base grows
- [ ] Automatic "newer version available" badge for installed skills — MEDIUM complexity + GitHub polling

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| InheritanceBadge on all settings fields | HIGH | LOW | P1 |
| System prompt display in Settings | HIGH | MEDIUM | P1 |
| Config reload on host switch | HIGH | LOW | P1 |
| Per-item install spinner (skills) | HIGH | MEDIUM | P1 |
| Post-install state badge on GitHub rows | HIGH | MEDIUM | P1 |
| GitHub browse section in Plugins tab | HIGH | MEDIUM | P1 |
| App-wide context reload on host switch | HIGH | HIGH | P1 |
| Hamburger accessible from Chat sub-views | HIGH | LOW | P1 |
| Remove host confirmation sheet | MEDIUM | LOW | P1 |
| Home layout audit and fix | MEDIUM | LOW | P1 |
| Consistent inline navigation titles | MEDIUM | LOW | P1 |
| Quick-switch host from sidebar | MEDIUM | MEDIUM | P2 |
| NavigationPath chat navigation | HIGH | HIGH | P2 |
| System prompt inline edit | MEDIUM | MEDIUM | P2 |
| Per-host config preview before switch | MEDIUM | MEDIUM | P2 |
| Project-scope config section | MEDIUM | MEDIUM | P2 |
| Uninstall from Browse context menu | LOW | LOW | P2 |
| Trending skills default query | LOW | MEDIUM | P3 |
| README preview before skill install | MEDIUM | HIGH | P3 |
| Scope waterfall visualiser | LOW | HIGH | P3 |
| Install progress SSE streaming | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for v3.1 launch — correctness, completeness, or blocking UX issues
- P2: Should have — add in follow-up phases within v3.1 if P1 leaves capacity
- P3: Nice to have — defer to v3.2+

---

## Complexity Notes per Feature Area

| Feature Area | Baseline Complexity | Risky Sub-feature | Risk Reason |
|---|---|---|---|
| Config sync | LOW–MEDIUM | App-wide reload on host switch | Touches AppState + all ViewModels; cross-cutting concern with no existing propagation path |
| GitHub browse/install | LOW–MEDIUM | Per-item install state | Simple pattern port from `PluginsViewModel`; risk is low if done precisely |
| Host Profiles redesign | MEDIUM | Context reload propagation | `activate()` currently isolated to `HostProfilesViewModel`; wiring to `AppState` is new architecture |
| Navigation overhaul | LOW–MEDIUM | NavigationPath chat navigation | Structural change to the root navigation model; conflicts with `@SceneStorage` chat restoration |

---

## Dependencies on Existing Screens and Components

| New Feature | Existing Screen / Component | Dependency Type |
|---|---|---|
| Config sync badges on all fields | `SettingsConfigSection` + `InheritanceBadge` | Extend — badge exists, needs broader application to all fields |
| System prompt display | `SettingsConfigSection.generalSettingsSection` | Add field — no UI exists today |
| GitHub skills install per-item state | `BrowserView.githubBrowseSection` + `SkillsViewModel` | Extend — add `installingSkills: Set<String>`, mirror `PluginsViewModel` pattern |
| GitHub plugins browse UI | `BrowserView.pluginsContent` | Add section — mirror existing `githubBrowseSection` in Skills tab |
| Host switch context reload | `HostProfilesViewModel.activate()` + `AppState` | New link — `activate()` must notify `AppState` to update `serverURL` and trigger reconnect |
| Sidebar quick-switch | `SidebarView` header | Add `Menu` — host list from `HostProfilesViewModel` or `AppState` |
| Chat hamburger visibility | `SidebarRootView.mainContent(showHamburger:)` + `ChatView` sub-views | Verify + fix — toolbar hamburger may be obscured by NavigationStack back button at depth |
| Inline navigation titles | All nine `ActiveScreen` destination views | Audit — apply `.inlineNavigationBarTitle()` where missing |
| Remove host confirmation | `HostProfilesView.hostProfileRow()` context menu | Add `.confirmationDialog` before calling `viewModel.remove(id)` |

---

## iOS HIG Grounding

**Side menu pattern (MEDIUM confidence — HIG + existing implementation):**
Apple HIG does not prescribe a side menu for iPhone. The preferred patterns are tab bar (up to 5 destinations) or `NavigationSplitView` (iPad). The existing ZStack overlay sidebar is a well-established community pattern for apps with more than 5 top-level destinations. The existing implementation is architecturally correct. The remaining risk is gesture conflict: the 30pt edge zone for swipe-open must be verified against SwiftUI scroll gesture recognisers inside `ChatView`.

**Back button pattern (HIGH confidence — Apple WWDC22 + NavigationStack docs):**
The SwiftUI-idiomatic back button comes from `NavigationStack` + `NavigationPath`. The current implementation swaps `activeScreen` at the root level, giving no navigation history and therefore no back button. The correct fix is to push `ChatView` onto the `NavigationStack` path rather than swapping the root screen. This is documented in Apple's WWDC22 session "SwiftUI cookbook for navigation."

**Profile switching pattern (MEDIUM confidence — WhatsApp, Slack, GitHub mobile):**
The platform norm for multi-account switching is: active profile indicated by a checkmark or accent badge in a list; switching is a single tap with a brief loading indicator; the entire app reloads its data to reflect the new context. The existing "Active" capsule in `HostProfilesView` follows this pattern. The missing piece is the data reload propagation.

**Config inheritance UI (HIGH confidence — codebase analysis):**
`InheritanceBadge` + `SettingsInfoButton` are already designed correctly. The pattern is: nil value = inherited (Host Default badge with link icon), explicit value = custom (Custom badge with pencil icon). This is the same mental model as Xcode's build settings "Inherited from target" vs overridden values. The gap is coverage — only 2–3 fields use it today; the remaining settings fields are undecorated.

---

## Sources

- Codebase: `ILSApp/ILSApp/Views/Browser/BrowserView.swift` — GitHub browse section, plugins content, skills content, install flow
- Codebase: `ILSApp/ILSApp/Views/Settings/SettingsConfigSection.swift` — InheritanceBadge, SettingsInfoButton, config field coverage
- Codebase: `ILSApp/ILSApp/Views/Fleet/HostProfilesView.swift` — active badge, health polling, activate/remove
- Codebase: `ILSApp/ILSApp/Views/Fleet/HostProfileDetailView.swift` — lifecycle controls, logs, health display
- Codebase: `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` — ActiveScreen enum, hamburger, edge swipe, NavigationStack root architecture
- Codebase: `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` — GitHub search/install implementation, global isLoading limitation
- Codebase: `ILSApp/ILSApp/ViewModels/PluginsViewModel.swift` — `installingPlugins: Set<String>` pattern to replicate, marketplace search
- Codebase: `ILSApp/ILSApp/ViewModels/HostProfilesViewModel.swift` — `activate()`, health polling, AppState propagation gap
- Codebase: `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift` — `loadConfig(scope:)`, `saveConfig()`, scope handling
- [Claude Code settings docs](https://code.claude.com/docs/en/settings) — 6-level config precedence chain (Enterprise > CLI > Local Project > Shared Project > User > Defaults)
- [Claude Code settings reference](https://claudefa.st/blog/guide/settings-reference) — scope system, file locations, merging rules
- [Apple WWDC22 — SwiftUI cookbook for navigation](https://developer.apple.com/videos/play/wwdc2022/10054/) — NavigationStack + NavigationPath back button pattern
- [Mastering Navigation in SwiftUI 2025](https://medium.com/@dinaga119/mastering-navigation-in-swiftui-the-2025-guide-to-clean-scalable-routing-bbcb6dbce929) — NavigationStack best practices, coordinator pattern
- [Account switcher UX patterns](https://medium.com/ux-power-tools/ways-to-design-account-switchers-app-switchers-743e05372ede) — active indicator, context reload, single-tap switch norms

---

*Feature research for: ILS iOS/macOS v3.1 — Config sync, GitHub browse/install, Host Profiles redesign, Navigation overhaul*
*Researched: 2026-02-24*
