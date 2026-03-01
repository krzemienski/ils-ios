# Feature Landscape

**Domain:** Native iOS/macOS client for Claude Code (v5.0 new features)
**Researched:** 2026-02-27
**Overall confidence:** HIGH

## Scope

This document covers the five v5.0 feature domains:

1. Config inheritance (CLI -> backend -> mobile settings cascade)
2. GitHub browse/install (skill/plugin marketplace)
3. Hooks management (CRUD operations for Claude Code hooks)
4. macOS parity (platform-specific features)
5. Profile switching (host profile cascade through settings)

Features are assessed against what already exists in ILS (substantial app with 10+ screens, 19 view models, 16 backend controllers, 13 themes, premium gating, and basic versions of hooks display, fleet/host profiles, and config editing).

---

## Table Stakes

Features users expect from a Claude Code management client at this maturity level. Missing any of these makes the app feel incomplete relative to what the CLI already provides.

### 1. Config Inheritance Visualization

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Multi-scope config loading (user/project/local) | Claude Code CLI has 4+ scopes; mobile must show all | Medium | Existing `ConfigController`, `ConfigScope` enum |
| "Inherited" vs "Overridden" badges per setting | Users need to see where a value comes from and what it overrides | Medium | Existing `ConfigOverride` DTO (already has `winningScope`, `userValue`, `projectValue`, `localValue`) |
| Scope picker in config editor | User must choose which scope to edit (user vs project vs local) | Low | Existing `ConfigEditorView` with `scope` parameter |
| Merged/effective config view | Show the final computed config after all scopes merge | Medium | New backend endpoint to return merged config |
| Read-only display for managed scope | Managed settings cannot be overridden; show them locked | Low | New `managed` case in `ConfigScope` enum |

**Why table stakes:** The CLI's `/status` command already shows settings and their source scopes. The mobile client currently only fetches one scope at a time (`/config?scope=user`). Users who manage settings across multiple projects will be confused if the mobile app doesn't show where values actually come from.

### 2. Hooks Read/Display with Full Event Type Coverage

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Display all 16 hook event types | Claude Code now has 16 event types; ILS only shows 5 | Low | Existing `HooksConfig` model needs new fields |
| Hook type badges (command/prompt/agent/http) | Four hook types exist; users need to see which is configured | Low | Existing `HookDefinition` model (add `type` variants) |
| Matcher pattern display with regex highlighting | Matchers are regexes that control when hooks fire; crucial context | Low | Already displayed but could use syntax highlighting |
| Hook source/scope indicator | Show whether hook came from user, project, local, or plugin | Medium | Need scope info from backend per hook group |
| Expandable hook detail with full JSON preview | Power users want to see the raw hook config for debugging | Low | Existing `GlassCard` pattern + JSON formatter |

**Why table stakes:** The current `HooksManagementView` is read-only and shows only 5 of the 16 event types (`SessionStart`, `SubagentStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`). Missing: `PermissionRequest`, `PostToolUseFailure`, `Notification`, `SubagentStop`, `Stop`, `TeammateIdle`, `TaskCompleted`, `ConfigChange`, `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `SessionEnd`. Users configure hooks in their settings files and need to verify they're correct. Without seeing all event types, hook debugging requires switching back to the CLI.

### 3. Plugin/Skill Browser with Enhanced Metadata

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Browse installed plugins with version, author, description | Users need to see what plugins are active and their metadata | Low | Existing `PluginsViewModel`, `PluginConfigView` (partially built in Phase 47 ECO-01) |
| Browse installed skills with frontmatter info | Skills are the primary extensibility mechanism; need visibility into `disable-model-invocation`, `allowed-tools`, `context` | Medium | Existing skill detail view needs frontmatter parsing |
| Search across skills by name/description/keyword | 1000+ skills exist; search is mandatory | Low | Already implemented in `BrowserView` |
| Plugin update available indicator | Users need to know when newer versions exist | Low | Existing plugin versioning (ECO-01 from v4.0) has update check endpoint |
| Skill detail view showing invocation type | Show whether skill is user-invocable, model-invocable, or both | Medium | Parse frontmatter from SKILL.md content |

**Why table stakes:** The browser already shows skills, plugins, and MCP servers. But the Claude Code ecosystem has matured significantly with the marketplace system, plugin manifests (`plugin.json`), and skill frontmatter. The mobile app needs to surface this richer metadata to match what CLI users see via `/plugin list` and `/skills`.

### 4. macOS Keyboard Shortcuts

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Cmd+N for new session | Standard macOS shortcut | Low | Existing `NotificationCenter` publisher `.ilsCreateNewSession` |
| Cmd+F for search/filter | Standard find shortcut; should focus search field | Low | Existing `isSearchFocused` state + `/` key handler in `MacContentView` |
| Cmd+, for Settings | Universal macOS Settings shortcut | Low | Existing `MacSettingsView` |
| Cmd+1/2/3... for sidebar sections | Standard sidebar navigation | Low | Existing `SidebarSection` enum with 8 cases |
| Cmd+W to close session/window | Standard close shortcut | Low | Existing `WindowManager` |
| Cmd+Shift+N for new window | Standard new-window shortcut | Low | Existing `openSessionWindow()` |

**Why table stakes:** macOS users muscle-memory these shortcuts. The app already handles `/` for search focus and has `NotificationCenter` publishers for menu commands, but keyboard shortcuts are not wired to SwiftUI `.keyboardShortcut()` modifiers on `Commands` menu items. This is the bare minimum for feeling like a real Mac app.

### 5. macOS Menu Bar Integration

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| File menu with New Session, Close Window | Standard macOS File menu | Low | Standard SwiftUI `Commands` |
| Edit menu with standard Cut/Copy/Paste/Select All | SwiftUI provides defaults but needs verification | Low | Standard SwiftUI |
| View menu with sidebar toggle | Standard macOS View menu pattern | Low | Existing `columnVisibility` state |
| Session menu with Rename/Fork/Export/Delete | Already wired via NotificationCenter publishers | Low | Existing `.ilsRenameSession`, `.ilsForkSession`, etc. |
| Window menu with standard management | Multiple windows via `WindowManager.shared` | Low | Existing `SessionWindowView` |

**Why table stakes:** The macOS app already posts notifications for session operations and handles them in `MacContentView.onReceive()`. But these are programmatic triggers, not proper `Commands` menu items with keyboard shortcuts visible in the menu bar. Users expect to see and discover these through the menu.

### 6. Host Profile Activation Cascades Settings

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Switching host reloads config from new backend | When active host changes, all settings should refresh | Medium | Existing `HostProfilesViewModel.activate()` calls `appState.updateServerURL()` |
| Config scope shows host-specific context | After switching hosts, config viewer should reflect that host's settings | Low | Existing `ConfigController` reads from filesystem on backend side |
| Active host indicator in Settings | Settings should show which host's config is being displayed/edited | Low | Existing `appState.activeHostName` |
| Hooks reload on host switch | Different hosts may have different hooks configured | Low | Existing `onChange(of: appState.serverURL)` in `HooksManagementView` |

**Why table stakes:** The existing `HostProfilesViewModel.activate()` already updates the server URL and triggers reloads via `appState.updateServerURL()`. Most views have `onChange(of: appState.serverURL)` handlers that refresh data. But the Settings and Config views don't visually acknowledge that their content is now from a different host. Users will be confused editing settings without knowing which backend they apply to.

---

## Differentiators

Features that set the app apart from using the CLI directly. Not expected, but create real value.

### 1. Config Diff View

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Side-by-side scope comparison | Visually compare user vs project vs local config | High | New UI component, three concurrent API calls |
| Highlight conflicts/overrides | Color-code settings overridden at a more specific scope | Medium | Existing `ConfigOverride` DTO provides all data needed |
| "What would change?" preview | Before saving, show which effective settings would change | High | Config merge logic on backend or client |

**Value:** No CLI equivalent exists. The CLI's `/status` shows current effective values but not a visual comparison across scopes. This is a unique mobile/desktop advantage over terminal UX.

### 2. Hooks CRUD (Create/Update/Delete)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Create new hook via form UI | Add hooks without hand-editing JSON -- select event type, set matcher, define command | High | New `HookEditorView`, backend `PUT /config` with hook mutations |
| Edit existing hook inline | Modify command, matcher, or type without opening a text editor | Medium | Parse and re-serialize hooks within `ClaudeConfig` |
| Delete hook with confirmation | Remove hooks safely | Medium | Config write with hooks removed |
| Toggle hook enabled/disabled | Temporarily disable a hook without deleting it | Medium | No native Claude Code concept; would need app-level convention |
| Hook execution log/history | See when hooks fired, exit codes, duration | High | Requires new backend endpoint or log file parsing |

**Value:** Editing hooks currently requires manually editing JSON files. A visual editor for hooks would be a significant DX improvement, especially for the newer `prompt` and `agent` hook types which have complex configuration (LLM evaluation criteria, agent tool access, etc.).

### 3. Marketplace Discovery and Install

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Browse marketplace catalogs | Show available plugins from registered marketplaces with categories and tags | High | New backend endpoint to fetch/cache marketplace.json from registered sources |
| One-tap plugin install | Install a plugin directly from the browse UI | High | Backend needs to invoke `claude plugin install` or equivalent git clone |
| Marketplace registration UI | Add new marketplace sources (GitHub repo, URL) from the app | Medium | Backend endpoint for marketplace management |
| Plugin update notifications | Badge/indicator when installed plugins have newer versions | Medium | Existing plugin versioning (ECO-01 from v4.0) |
| Skill preview before install | Show SKILL.md content and frontmatter before committing | Medium | Fetch and render markdown from marketplace source |

**Value:** The CLI experience for marketplace browsing (`/plugin marketplace add`, `/plugin install`) is sequential and text-based. A visual catalog with categories, search, and one-tap install would be a "mobile App Store" experience for Claude Code extensions. Marketplace schema supports `category`, `tags`, `keywords`, `description`, `author`, `version`, and `homepage` -- all ideal for visual browsing.

### 4. macOS Handoff / Continuity

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Continue session viewing between iPhone and Mac | Start browsing a session on iPhone, pick up on Mac | Medium | `NSUserActivity` with SwiftUI `userActivity()` and `onContinueUserActivity()` modifiers |
| Universal clipboard for session content | Copy session text on Mac, paste on iPhone | Low | Automatic if same iCloud account (standard Continuity) |
| Drag-and-drop sessions between macOS windows | Drag session from list to new window | Medium | `Transferable` protocol, `draggable()`/`dropDestination()` modifiers |

**Value:** Unique cross-platform experience that no web-based Claude Code client can match. Moving between devices seamlessly leverages the native advantage of having both iOS and macOS apps from the same codebase.

### 5. macOS Multi-Window Panels

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Open config editor in separate window | Edit config while viewing sessions in main window | Medium | New `WindowGroup` scene |
| System monitor as detachable panel | Always-visible system metrics while working | Medium | New `WindowGroup` scene |
| Stage Manager awareness | Proper window sizing and grouping | Low | `defaultSize()` and `windowResizability()` modifiers |

**Value:** The macOS app already supports opening sessions in new windows via `WindowManager.shared.openSessionWindow()`. Extending this to config, system monitor, and hooks creates a true multi-pane desktop experience impossible on mobile.

### 6. Config History / Rollback

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Config change history with rollback | See what changed and revert to previous config | High | Claude Code auto-backs up 5 most recent configs; backend could expose these |
| Before/after diff on config saves | Show exactly what changed before committing | Medium | Diff existing config vs proposed changes |

**Value:** Claude Code auto-backs up the 5 most recent config files. Exposing this through the mobile app as a visual history with rollback would be a unique safety net that even the CLI doesn't offer as a polished feature.

---

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Raw JSON text editor for hooks** | Error-prone; users create invalid JSON, break matchers, misconfigure hook types. The existing `ConfigEditorView` does raw editing already -- hooks specifically need structured forms. | Build structured hook editor with form fields, dropdowns for event types, and validation before serializing to JSON |
| **Auto-sync config changes to CLI in real-time** | Config files are on the host filesystem; mobile talks to a backend. Real-time sync requires file watchers, WebSocket push, and conflict resolution. Disproportionate complexity. | Manual refresh with pull-to-refresh; show "last loaded" timestamp with cache freshness indicators (already built in v4.0 DATA-03) |
| **Plugin marketplace with user reviews/ratings** | Building a review system is a product in itself. Claude Code's marketplace is a JSON catalog, not a social platform. Reviews belong upstream. | Show GitHub stars if available from marketplace metadata; link to source repo for community feedback |
| **Hook execution from mobile** | Hooks are shell commands, HTTP endpoints, or LLM prompts that run on the host. Remote execution has severe security implications. | Display hook config for debugging; provide "Edit Config" to modify; show execution logs if backend captures them |
| **Full config editor for managed scope** | Managed settings are enterprise-deployed and cannot be overridden by design. An editor creates false expectations. | Show managed settings as read-only with a "Managed by organization" badge and lock icon |
| **macOS menu bar extra (background agent)** | A persistent menu bar utility requires a separate process, LaunchAgent, and fundamental architecture changes. The app is a session viewer, not a daemon. | Focus on main window experience; add a Dock menu with quick actions instead |
| **macOS Touch Bar support** | Apple discontinued Touch Bar on all current Mac models. `ILSMacApp/TouchBar/` directory exists but investment here is wasted. | Remove or ignore Touch Bar code; invest in keyboard shortcuts and menu bar |
| **Inline hook testing/dry-run** | Running hooks with test inputs from mobile requires remote execution. Complex, security-sensitive, out of scope. | Show the JSON input schema per event type so users understand what their hooks receive |
| **Plugin auto-update from mobile** | Auto-updating plugins requires git operations on the host filesystem. The backend would need to shell out to git, npm, or pip. | Show update-available badges; link to CLI command for updating; defer actual updates to CLI |

---

## Feature Dependencies

```
ConfigScope Enum Update (add "managed" case)
  |-> Config Inheritance Visualization (table stakes)
  |     |-> Config Diff View (differentiator)
  |     |-> Config History (differentiator)
  |
  |-> Settings Host-Awareness (table stakes)
        |-> Profile Switching Cascade (table stakes)

HooksConfig Model Update (add 11 missing event types + hook type variants)
  |-> Hooks Full Display (table stakes)
  |     |-> Hooks CRUD Editor (differentiator)

Existing BrowserView + PluginsViewModel
  |-> Plugin Metadata Enhancement (table stakes)
  |     |-> Marketplace Discovery (differentiator)
  |           |-> One-Tap Install (differentiator)

Existing MacContentView + NotificationCenter Publishers
  |-> Keyboard Shortcuts via Commands {} (table stakes)
  |-> Menu Bar Integration (table stakes)
  |     |-> Multi-Window Panels (differentiator)
  |
  Existing NSUserActivity support in SwiftUI
  |-> Handoff / Continuity (differentiator)

Existing HostProfilesViewModel.activate()
  |-> Profile Activation Cascade (table stakes)
  |     |-> Settings Host-Awareness (table stakes)
```

### Critical Path

1. **ILSShared model changes** -- `ConfigScope` (add `managed`), `HooksConfig` (add 11 event type fields), `HookDefinition` (add prompt/agent/http type support). These unblock both config inheritance and hooks features across iOS and macOS.
2. **Backend endpoints** -- Merged/effective config endpoint, config overrides endpoint, marketplace catalog endpoint.
3. **UI features** -- Build on updated models and endpoints. Config inheritance view, expanded hooks display, enhanced plugin/skill browser.
4. **macOS features** -- Keyboard shortcuts and menu bar are largely independent of the model/backend work and can proceed in parallel.
5. **Profile switching** -- Verify and fix gaps in the existing `onChange(of: appState.serverURL)` cascade across all views.

---

## MVP Recommendation

### Must Have (ship v5.0 without these = incomplete)

1. **Config inheritance visualization** with scope badges (user/project/local/managed) and "Inherited"/"Overridden" indicators. The `ConfigOverride` DTO already provides `winningScope`, `userValue`, `projectValue`, `localValue` -- the backend and UI need to use them. Add a scope picker to `ConfigEditorView` and a merged/effective config summary view.

2. **Hooks display for all 16 event types** with hook type badges (command/prompt/agent/http). The current `HooksConfig` model only covers 5 events. Add: `PermissionRequest`, `PostToolUseFailure`, `Notification`, `SubagentStop`, `Stop`, `TeammateIdle`, `TaskCompleted`, `ConfigChange`, `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `SessionEnd`.

3. **macOS keyboard shortcuts** (Cmd+N, Cmd+F, Cmd+,, Cmd+1/2/3) and proper menu bar items via SwiftUI `Commands` in the `App` declaration. The `NotificationCenter` publishers already exist; wiring them to `Commands` with `.keyboardShortcut()` is straightforward.

4. **Profile switching cascades** through settings. When `HostProfilesViewModel.activate()` fires, config editor and hooks views must reload from the new backend. The existing `onChange(of: appState.serverURL)` handlers in most views handle this -- verify and fix gaps. Add visual indicator of which host's settings are being shown.

5. **Plugin/skill browser enhancements** with version info, update indicators, and skill frontmatter display. Most of this was partially built in Phase 47 (ECO-01, ECO-02); needs completion and metadata expansion.

### Should Have (target for v5.0 but deferrable)

6. **Hooks CRUD editor** -- structured form for creating/editing hooks. High value but high complexity. Acceptable to ship with read-only hooks + "Edit Config" button to the raw JSON editor.

7. **Marketplace browsing** -- visual catalog of available plugins from registered marketplaces. Requires significant new backend work (fetching remote marketplace.json, caching, presenting catalog). Can ship with local-only plugin management initially.

8. **macOS menu bar with full Commands** -- proper File, Edit, View, Session, and Window menus with all keyboard shortcuts. Medium effort, high polish.

### Defer (v6.0+)

9. Config diff view (side-by-side scope comparison)
10. Handoff / Continuity (cross-device session viewing)
11. Config history with rollback (leveraging Claude Code's auto-backup files)
12. Marketplace install from mobile (backend CLI invocation)
13. Multi-window panels for config/system monitor/hooks (macOS)
14. Hook execution logs/history

---

## Complexity Budget

| Feature Area | Table Stakes Effort | Differentiator Effort | Total |
|-------------|--------------------|-----------------------|-------|
| Config Inheritance | 3-4 days | +2-3 days (diff view) | 5-7 days |
| Hooks Management | 2-3 days (display) | +4-5 days (CRUD editor) | 6-8 days |
| Plugin/Skill Browser | 1-2 days (metadata) | +5-6 days (marketplace) | 6-8 days |
| macOS Parity | 2-3 days (shortcuts+menus) | +2-3 days (Handoff, multi-window) | 4-6 days |
| Profile Switching | 1-2 days | N/A | 1-2 days |
| **Total** | **9-14 days** | **+13-17 days** | **22-31 days** |

Table stakes alone: approximately 2 weeks of focused execution.
With key differentiators (hooks CRUD + marketplace browse): approximately 4 weeks.

---

## Sources

### Official Documentation (HIGH confidence)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) -- 16 event types, matcher patterns, hook handler types (command/prompt/agent/http), JSON schemas
- [Claude Code Settings Reference](https://code.claude.com/docs/en/settings) -- Full settings keys, scope precedence (managed > local > project > user), merge behavior, permission rules
- [Claude Code Plugin Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) -- Marketplace schema, plugin sources (GitHub/npm/pip/git URL), distribution model
- [Claude Code Skills](https://code.claude.com/docs/en/skills) -- Skill file format, frontmatter reference, invocation control, supporting files

### Community / Guides (MEDIUM confidence)
- [Claude Code Hooks Power User Guide](https://claude.com/blog/how-to-configure-hooks)
- [Building macOS Apps with SwiftUI (2026)](https://oneuptime.com/blog/post/2026-02-02-swiftui-macos-applications/view)
- [macOS Menu Bar App Best Practices](https://medium.com/@p_anhphong/what-i-learned-building-a-native-macos-menu-bar-app-eacbc16c2e14)
- [SwiftUI Handoff with NSUserActivity](https://www.hackingwithswift.com/quick-start/swiftui/how-to-continue-an-nsuseractivity-in-swiftui)
- [Customizing macOS Menu Bar in SwiftUI](https://danielsaidi.com/blog/2023/11/22/customizing-the-macos-menu-bar-in-swiftui)

### Codebase Analysis (HIGH confidence)
- `ILSShared/Models/ClaudeConfig.swift` -- `HooksConfig` covers 5 of 16 event types; `HookDefinition` has `type` and `command` only
- `ILSShared/DTOs/ResponseDTOs.swift` -- `ConfigOverride` DTO already models scope cascade with `winningScope`, `userValue`, `projectValue`, `localValue`
- `ILSShared/Models/MCPServer.swift` -- `ConfigScope` enum has user/project/local (missing managed)
- `HooksManagementView.swift` -- Read-only display, 5 event types, no CRUD capability
- `HostProfilesViewModel.swift` -- Activation cascades server URL via `appState.updateServerURL()` but settings views don't show which host is active
- `MacContentView.swift` -- NotificationCenter publishers exist for session operations; keyboard shortcut `/` wired; `SidebarSection` enum has 8 cases
- `MacSettingsView.swift` -- Tabbed settings view with 5 tabs, no connection to hooks or config inheritance visualization
- `ConfigController.swift` -- Supports GET/PUT/validate for single scope; no merged/effective config endpoint
- `PluginConfigView` + `PluginsViewModel` -- Plugin version display partially built in Phase 47 ECO-01
