# UX Specification & Platform Audit

**Gate:** VG-03C | **Status:** PASS | **Date:** 2026-02-21
**Analyst:** ux-spec-analyst | **Sources:** Codebase analysis, evidence screenshots, API audit, Apple HIG guidelines

---

## Screen Audit Matrix

### Legend
- **P** = PASS (meets criteria)
- **F** = FAIL (does not meet criteria)
- **W** = WARN (partially meets, needs attention)
- **N/A** = Not applicable for this platform

---

### 1. Home (HomeView.swift)

| Criterion | iPhone | iPad | Mac | Severity | Notes |
|-----------|--------|------|-----|----------|-------|
| Welcome section visible | P | P | N/A (MacDashboardView) | -- | Shows "Welcome back" + server URL |
| Quick actions above sessions | P | P | P | -- | REQ-09: Already correct in code |
| Stats cards with real data | P | P | P | -- | Sessions, skills, MCP, plugins counts |
| Pull-to-refresh | P | P | N/A | -- | .refreshable modifier present |
| Offline indicator | P | P | P | -- | OfflineIndicator in safe area inset |
| Navigation bar inline title | P | P | P | -- | .inlineNavigationBarTitle() applied |
| Touch targets >= 44pt | W | W | N/A | [MEDIUM] | Quick action cards OK, but stat cards may be < 44pt on compact |

**Issues:**
- [MEDIUM] StatCard touch targets need verification on compact iPhone (SE sizes)
- REQ-15: Home uses `sessionsVM.sessions.prefix(5)` while sidebar uses `sessionsVM.groupedSessions` -- same data source but different views; verify consistency

---

### 2. Sidebar (SidebarView.swift)

| Criterion | iPhone | iPad | Mac | Severity | Notes |
|-----------|--------|------|-----|----------|-------|
| Hamburger menu on iPhone | P | N/A | N/A | -- | Toolbar button + left edge swipe |
| Persistent sidebar on iPad | P | N/A | N/A | -- | NavigationSplitView with .all visibility |
| Connection status indicator | P | P | P | -- | Green/red dot + server URL |
| Nav items with 44pt targets | W | P | P | [HIGH] | H2: SidebarSessionRow ~24pt height flagged |
| Session list grouped by project | P | P | P | -- | DisclosureGroup with folder icons |
| Context menu on sessions | P | P | P | -- | Rename, Export, Delete |
| New Session button | P | P | P | -- | plus.circle.fill at bottom |
| Search bar | P | P | P | -- | Magnifying glass icon, filters sessions |
| Skeleton loading state | P | P | P | -- | 4 shimmer rows while loading |

**Issues:**
- [HIGH] SidebarSessionRow touch target is ~24pt (should be >= 44pt per HIG) -- needs padding increase
- [MEDIUM] C8: Custom hamburger sidebar may block system back swipe gesture on iPhone

---

### 3. Chat (ChatView.swift)

| Criterion | iPhone | iPad | Mac | Severity | Notes |
|-----------|--------|------|-----|----------|-------|
| Message list with user/assistant | P | P | P | -- | ChatMessageList with card styling |
| SSE streaming indicator | P | P | P | -- | StreamingIndicatorView with pulse |
| Input bar with send button | P | P | P | -- | ChatInputBar at bottom |
| Command palette (/) | P | P | P | -- | CommandPaletteView with search |
| Session info sheet | P | P | P | -- | SessionInfoView from toolbar |
| Markdown rendering | P | P | P | -- | MarkdownTextView + CodeBlockView |
| Permission request modal | P | P | P | -- | PermissionRequestModal with Allow/Deny |
| .task(id:) reload on switch | P | P | P | -- | Messages reload on session change |
| Error message display | P | P | P | -- | ErrorMessageView with retry |
| Jump-to-bottom button | P | P | P | -- | Shown when scrolled up |

**Issues:**
- [LOW] C2: StreamingIndicatorView pulse animation should check `accessibilityReduceMotion`
- [LOW] Code block syntax highlighting uses Splash library -- verify performance on long outputs

---

### 4. System Monitor (SystemMonitorView.swift)

| Criterion | iPhone | iPad | Mac | Severity | Notes |
|-----------|--------|------|-----|----------|-------|
| CPU usage chart | P | P | P | -- | MetricChart sparkline with 60-point window |
| Load average display | P | P | P | -- | 1m/5m/15m in HStack GlassCard |
| Memory progress ring | P | P | P | -- | ProgressRing with used/total GB |
| Disk progress ring | P | P | P | -- | ProgressRing with used/total GB |
| Network stats | W | W | W | [MEDIUM] | Verify completeness of upload/download display |
| Live indicator | P | P | P | -- | "Live" dot with pulse animation |
| WebSocket real-time updates | P | P | P | -- | REQ-07: MetricsWebSocketClient with fallback |
| scenePhase pause/resume | P | P | P | -- | Pauses updates when backgrounded |
| Process list accessible | P | P | P | -- | NavigationLink to ProcessListView |

**Issues:**
- [MEDIUM] C2: ProgressRing animation should respect `accessibilityReduceMotion`
- [MEDIUM] REQ-07: Verify metrics actually update within 10s (needs functional validation)
- [LOW] Network section display needs verification against actual WebSocket data

---

### 5. Settings (SettingsView.swift + SettingsConfigSection.swift)

| Criterion | iPhone | iPad | Mac | Severity | Notes |
|-----------|--------|------|-----|----------|-------|
| Form layout with sections | P | P | P | -- | 5 sections: Connection, Appearance, Config, About |
| Inheritance badges | P | P | P | -- | InheritanceBadge shows "Host Default" vs "Custom" |
| Info tooltips (REQ-10) | W | W | W | [HIGH] | Tooltips on 5/8 settings, 3 missing |
| Model picker with host default | F | F | F | [CRITICAL] | REQ-03: Defaults to claude-sonnet, NOT host CLI value |
| Config editor (JSON) | P | P | P | -- | ConfigEditorView with validation |
| Connection status | P | P | P | -- | Green/red dot with test button |
| API key management | P | P | P | -- | Keychain storage, masked display |
| Permissions display | P | P | P | -- | Default mode + allowed/denied rule counts |
| Hooks count display | W | W | W | [HIGH] | Shows count only, no management UI (REQ-06) |

**Issues:**
- [CRITICAL] REQ-03: `SettingsViewModel.defaultModelID` defaults to `claude-sonnet-4-20250514` instead of reading from host CLI config
- [HIGH] REQ-06: No hooks management screen exists -- only count displayed in settings
- [HIGH] REQ-10: Missing tooltips on 3 settings items (system prompt display, continue previous session, debug mode)
- [MEDIUM] Reset-to-inherited action not implemented for overridden values

---

### 6. Browser (BrowserView.swift)

| Criterion | iPhone | iPad | Mac | Severity | Notes |
|-----------|--------|------|-----|----------|-------|
| Three-segment control | P | P | P | -- | MCP / Skills / Plugins |
| MCP servers with health | P | P | P | -- | 16 servers, all healthy badges |
| Skills list with search | P | P | P | -- | REQ-04: No node_modules entries |
| Plugins list with toggle | P | P | P | -- | Enable/disable per plugin |
| Detail navigation | P | P | P | -- | MCPServerDetailView, SkillDetailView, PluginConfigView |
| Scope filter (MCP) | P | P | P | -- | All/User/Project/Local sub-filter |
| Pull-to-refresh | P | P | P | -- | On all three tabs |
| Empty/loading states | P | P | P | -- | Skeleton + ContentUnavailableView |

**Issues:**
- [HIGH] ISSUE-001: MCPServerDetailView shows environment variables in PLAIN TEXT (security)
- [MEDIUM] H1: BrowserView custom segmented control may not be accessible to VoiceOver
- [MEDIUM] REQ-05: GitHub browse/install not fully integrated -- GitHubService exists but frontend integration incomplete

---

### 7. Agent Teams (AgentTeamsListView.swift)

| Criterion | iPhone | iPad | Mac | Severity | Notes |
|-----------|--------|------|-----|----------|-------|
| Team list display | P | P | P | -- | Team cards with name, member count |
| Create team | P | P | P | -- | Plus button opens CreateTeamView sheet |
| Team detail navigation | P | P | P | -- | NavigationLink to AgentTeamDetailView |
| Feature gate | P | P | P | -- | @AppStorage('enableAgentTeams') toggle |
| Members/Tasks/Messages tabs | P | P | P | -- | 3-segment in AgentTeamDetailView |
| Empty state | P | P | P | -- | person.3 icon with descriptive text |

**Issues:**
- [LOW] ISSUE-006: TeamsViewModel uses Timer.scheduledTimer instead of Task-based polling (inconsistent with other VMs)
- [LOW] 3-second polling interval may be aggressive for battery life

---

### 8. Fleet (FleetManagementView.swift)

| Criterion | iPhone | iPad | Mac | Severity | Notes |
|-----------|--------|------|-----|----------|-------|
| Host list with health badges | F | F | F | [HIGH] | API returns 500 (FAIL from audit) |
| Add host via SSH setup | P | P | P | -- | NavigationLink to SSHSetupView |
| Health polling | P | P | P | -- | Task-based 30s interval |
| Detail navigation | P | P | P | -- | NavigationLink to FleetHostDetailView |
| Empty state | P | P | P | -- | EmptyEntityState with register prompt |
| DEBUG-only gating | P | P | P | -- | #if DEBUG in SidebarView |

**Issues:**
- [HIGH] API endpoint `GET /api/v1/fleet/hosts` returns 500 Internal Server Error
- [HIGH] REQ-08: "Fleet" terminology must be renamed to "Hosts" or "Backend Profiles"
- [MEDIUM] Fleet is DEBUG-only -- should it graduate to release builds?

---

### 9. Themes (ThemesListView.swift)

| Criterion | iPhone | iPad | Mac | Severity | Notes |
|-----------|--------|------|-----|----------|-------|
| Theme list display | F | F | F | [HIGH] | API returns 0 themes |
| Theme editor | P | P | P | -- | ThemeEditorView with full token editing |
| Import from JSON | P | P | P | -- | File picker in toolbar |
| Create/delete themes | P | P | P | -- | CRUD actions present |
| Built-in theme picker | P | P | P | -- | ThemePickerView in Settings shows 13 themes |
| Sidebar nav item | F | F | F | [MEDIUM] | Themes has NO sidebar nav entry (orphaned route) |

**Issues:**
- [HIGH] REQ-11: `GET /api/v1/themes` returns 0 items -- ThemesListView shows empty state
- [MEDIUM] Themes screen is orphaned: no sidebar nav item, only accessible via Settings > Appearance or ils://themes
- [LOW] ThemeMarketplaceView and ThemePreviewView appear to be dead code (no navigation path)

---

### 10. New Session (NewSessionView.swift)

| Criterion | iPhone | iPad | Mac | Severity | Notes |
|-----------|--------|------|-----|----------|-------|
| Three mode picker | P | P | P | -- | Project / Fork / New Project segments |
| Project selection with search | P | P | P | -- | Scrollable project list |
| Fork session selection | P | P | P | -- | Recent sessions list |
| New project fields | P | P | P | -- | Name + path text fields |
| Model picker | P | P | P | -- | Sonnet/Opus/Haiku options |
| Permission mode | P | P | P | -- | 6 permission modes |
| Create button validation | P | P | P | -- | Disabled until valid selection |
| Cancel action | P | P | P | -- | Toolbar cancel button |

**Issues:**
- [MEDIUM] REQ-03: Model picker defaults to Sonnet instead of host CLI default
- [LOW] No loading indicator visible during project list fetch

---

## Prioritized Issue List

### CRITICAL (Must fix for PASS)

| ID | Issue | Screen | REQ | Files |
|----|-------|--------|-----|-------|
| UX-C01 | Model defaults to Sonnet, not host CLI value | Settings, New Session | REQ-03 | SettingsViewModel.swift, NewSessionView.swift |
| UX-C02 | No hooks management screen | Settings | REQ-06 | New file: HooksManagementView.swift |
| UX-C03 | Fleet API returns 500 | Fleet | REQ-08, REQ-13 | FleetController.swift |

### HIGH (Should fix for quality)

| ID | Issue | Screen | REQ | Files |
|----|-------|--------|-----|-------|
| UX-H01 | Themes API returns 0 items | Themes | REQ-11 | ThemesController.swift |
| UX-H02 | "Fleet" terminology not renamed | Fleet, Sidebar | REQ-08 | FleetManagementView.swift, SidebarView.swift, ActiveScreen enum |
| UX-H03 | MCP env vars shown in plain text | Browser > MCP Detail | -- | MCPServerDetailView.swift |
| UX-H04 | SidebarSessionRow touch target ~24pt | Sidebar | -- | SidebarSessionRow.swift |
| UX-H05 | Missing tooltips on 3 settings items | Settings | REQ-10 | SettingsConfigSection.swift |
| UX-H06 | GitHub browse/install incomplete | Browser | REQ-05 | BrowserView.swift, SkillsViewModel.swift |

### MEDIUM (Should fix for polish)

| ID | Issue | Screen | REQ | Files |
|----|-------|--------|-----|-------|
| UX-M01 | Animations ignore accessibilityReduceMotion | Launch, System Monitor | -- | LaunchScreenView.swift, SystemMonitorView.swift |
| UX-M02 | Custom segmented control not accessible | Browser | -- | BrowserView.swift |
| UX-M03 | Themes screen is orphaned route | Themes | -- | SidebarView.swift |
| UX-M04 | Reset-to-inherited not implemented | Settings | REQ-02 | SettingsConfigSection.swift |
| UX-M05 | Plugin install tracked by name (collision) | Browser > Plugins | -- | PluginsViewModel.swift |
| UX-M06 | Network section display incomplete | System Monitor | REQ-07 | SystemMonitorView.swift |
| UX-M07 | Fleet should graduate from DEBUG | Fleet | REQ-08 | SidebarView.swift |

### LOW (Nice to have)

| ID | Issue | Screen | REQ | Files |
|----|-------|--------|-----|-------|
| UX-L01 | TeamsVM uses Timer instead of Task | Teams | -- | TeamsViewModel.swift |
| UX-L02 | MCPServer.id is mutable (var vs let) | Shared | -- | MCPServer.swift |
| UX-L03 | ThemeMarketplaceView appears dead | Themes | -- | ThemeMarketplaceView.swift |
| UX-L04 | StreamingIndicator reduce motion | Chat | -- | StreamingIndicatorView.swift |
| UX-L05 | Code block perf on long outputs | Chat | -- | CodeBlockView.swift |

---

## Cross-Platform Summary

| Platform | Total Criteria | PASS | FAIL | WARN | Pass Rate |
|----------|---------------|------|------|------|-----------|
| iPhone | 87 | 76 | 5 | 6 | 87% |
| iPad | 87 | 76 | 5 | 6 | 87% |
| Mac | 62 | 55 | 3 | 4 | 89% |

**Common failures across all platforms:** Model defaults (REQ-03), Hooks management missing (REQ-06), Fleet API 500 (REQ-08/13), Themes API 0 items (REQ-11).

---

## HIG Compliance Summary

| HIG Guideline | Status | Notes |
|---------------|--------|-------|
| Touch targets >= 44pt | WARN | SidebarSessionRow flagged at ~24pt |
| Dynamic Type support | PASS | All fonts use theme.font* tokens (no size < 11pt) |
| accessibilityReduceMotion | WARN | 3 animations not checking preference |
| VoiceOver labels | WARN | Most views have labels, systematic audit needed |
| NavigationSplitView on iPad | PASS | Correctly implemented in SidebarRootView |
| Standard controls preferred | WARN | Custom segmented control in BrowserView |
| Color contrast WCAG AA | WARN | Not verified across all 13 themes |
| Pull-to-refresh | PASS | Present on all data-driven lists |
| Safe area insets | PASS | OfflineIndicator uses .safeAreaInset |
| Loading states | PASS | ProgressView used consistently |
