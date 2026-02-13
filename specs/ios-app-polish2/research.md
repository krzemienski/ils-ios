---
spec: ios-app-polish2
phase: research
created: 2026-02-06T23:00:00-05:00
---

# Research: ios-app-polish2

## Executive Summary

The ILS iOS app has a working foundation (MVVM + Vapor backend, SSE streaming, 22 screens) but needs significant work across 8 areas: Cloudflare tunnel integration for remote access, first-run host configuration, SSH-based remote provisioning, host system monitoring/metrics, full feature parity audit, codebase/UX improvements, ralph orchestrator sync, and UI/UX redesign. The previous `ios-app-polish` spec validated 13 scenarios with 42 screenshots but the user is frustrated that full functional validation was never properly achieved end-to-end. This spec must be comprehensive and get EVERYTHING working.

## 1. Cloudflare Tunnel Integration

### External Research

**Quick Tunnels (free, no account needed):**
- Command: `cloudflared tunnel --url http://localhost:9090`
- Outputs a random `*.trycloudflare.com` subdomain to stdout
- No config file, no account, no DNS setup required
- Tunnel destroyed when process stops; new random URL on restart
- Source: [Cloudflare Quick Tunnels docs](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/)

**Named Tunnels (account required, stable URL):**
- Requires Cloudflare account + `cloudflared tunnel login`
- Create via API: `POST https://api.cloudflare.com/client/v4/accounts/{account_id}/tunnels`
- Supports custom domains via DNS CNAME records
- Source: [Cloudflare Tunnel API docs](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel-api/)

**Key stdout parsing pattern:**
When running `cloudflared tunnel --url http://localhost:9090`, stdout contains:
```
INF Requesting new quick Tunnel on trycloudflare.com...
INF +--------------------------------------------------------------------------------------------+
INF |  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |
INF |  https://threaded-fathers-explore-supplier.trycloudflare.com                               |
INF +--------------------------------------------------------------------------------------------+
```
The URL can be parsed from the line containing `trycloudflare.com`.

### Implementation Plan

**Backend API endpoints needed:**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/tunnel/start` | POST | Start cloudflared process, parse URL from stdout |
| `/api/v1/tunnel/stop` | POST | Kill cloudflared process |
| `/api/v1/tunnel/status` | GET | Return current tunnel URL + running state |

**Backend service (`TunnelService.swift`):**
- Actor wrapping a `Process` for `cloudflared`
- Parse stdout for `trycloudflare.com` URL using regex
- Store active process reference for stop/cancel
- Health check: verify tunnel URL resolves

**iOS changes:**
- Settings section "Remote Access" with Start/Stop tunnel toggle
- Display current tunnel URL with "Copy" button
- Option to supply own Cloudflare credentials for named tunnel
- QR code generation of tunnel URL for easy sharing

### Feasibility

| Aspect | Assessment | Notes |
|--------|------------|-------|
| Quick tunnel | High | Just spawn `cloudflared` process, parse stdout |
| Named tunnel | Medium | Needs Cloudflare account/token management |
| `cloudflared` availability | Medium | Must be installed on backend host; could auto-install |

### Recommendation

Start with quick tunnels (zero config). Add named tunnel support as optional "bring your own Cloudflare" feature. Backend should check if `cloudflared` binary exists and offer install instructions if missing.

---

## 2. First-Run Backend Host Configuration

### Current State

- `ServerSetupSheet` exists in `ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift`
- Shows on first launch when connection fails (triggered by `showOnboardingIfNeeded()`)
- Has URL text field (defaults to `http://localhost:9090`), Connect button, success/failure indicator
- `AppState` persists `serverURL` to `UserDefaults`
- Settings also has a "Backend Connection" section with URL field + Test Connection

### What's Missing

1. **No IP address entry helper** -- Users must type full URL including `http://` prefix
2. **No network scanning** -- Could auto-discover backend on local network via Bonjour/mDNS
3. **No connection history** -- Can't switch between multiple backends
4. **No clear guidance** -- "Enter the URL of your ILS backend server" is vague
5. **No SSH provisioning flow** -- No way to set up backend from the app

### Best Practices (iOS onboarding)

- Step-by-step wizard pattern (1. Enter host, 2. Test connection, 3. See dashboard)
- Visual feedback at each step (checkmarks, progress indicators)
- Sensible defaults (localhost for development, explain remote for production)
- Remember recent connections for easy switching
- Show backend version/status after successful connection

### Recommendation

Enhance `ServerSetupSheet` to:
1. Have tabs/modes: "Local" (auto-fill localhost), "Remote" (IP/hostname entry), "Cloudflare" (paste tunnel URL)
2. Show connection progress with detailed status (DNS resolve, TCP connect, health check)
3. Store connection history in UserDefaults array
4. After connection, show backend info (version, Claude CLI status, project count)

---

## 3. SSH-Based Remote Provisioning

### Current State

- Backend has `SSHService.swift` using Citadel library
- Supports password and RSA key auth
- Can execute remote commands and get stdout/stderr
- `AuthController.swift` exists but is registered in routes (likely has connect/status endpoints)
- iOS had SSH views but they were deleted in previous polish spec (14 dead files removed)
- Package.swift includes Citadel dependency

### What a Provisioning Flow Would Look Like

**Backend install script (conceptual):**
```bash
#!/bin/bash
# Install Swift (via swiftly or apt)
curl -sL https://swiftly.dev/install.sh | bash
# Clone ILS repo
git clone https://github.com/<user>/ils-ios.git ~/ils
cd ~/ils
# Build backend
swift build -c release
# Start backend
PORT=9090 .build/release/ILSBackend &
```

**API endpoints needed:**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/provision/connect` | POST | SSH into remote machine |
| `/api/v1/provision/install` | POST | Run install script on remote |
| `/api/v1/provision/status` | GET | Check install progress |

**iOS UI:**
- "Set Up New Server" flow in ServerSetupSheet
- Collect: hostname, port, username, auth method (password/key)
- Show real-time install progress (streaming log output)
- After install completes, auto-switch to the new backend URL

### Security Considerations

- SSH credentials should NOT be stored long-term (use Keychain if storing)
- Private keys should never leave the device
- The provisioning flow is a one-time operation
- Consider: backend-to-backend SSH (the iOS app asks its current backend to provision a NEW backend on a remote machine)

### Feasibility

| Aspect | Assessment | Notes |
|--------|------------|-------|
| SSH connectivity | High | Citadel already integrated and working |
| Script execution | High | `executeCommand()` already works |
| Real-time progress | Medium | Need streaming output, not just final result |
| Security | Medium | Credential handling needs careful design |
| Cross-platform | Low | Install script is Linux-specific; macOS has different paths |

### Recommendation

Implement as a "wizard" flow within ServerSetupSheet. Keep it simple: collect SSH creds, run a well-tested install script, show output log, then switch to the new backend. Store credentials in iOS Keychain only if user explicitly opts in. This is the backend SSHService acting as a jump box -- the iOS app talks to its current backend, which SSHes into the target machine.

---

## 4. Host System Monitoring & Metrics

### External Research

**Swift system metrics on macOS:**
- `sysctl` API provides CPU, memory, disk info on macOS ([source](https://sanzaru84.medium.com/how-to-fetch-system-information-with-sysctl-in-swift-on-macos-8ffcdc9b5b99))
- `apple/swift-system-metrics` reports process-level metrics to Swift Metrics ([GitHub](https://github.com/apple/swift-system-metrics))
- `host_processor_info()` / `host_statistics()` for per-CPU usage
- `proc_pidinfo` for per-process CPU/memory
- NOTE: `sysctl` only works on macOS, not iOS -- but our backend runs on macOS/Linux

**For Linux hosts:**
- `/proc/stat`, `/proc/meminfo`, `/proc/loadavg` for system metrics
- `/proc/<pid>/stat` for per-process metrics
- `df` for disk usage
- `ifstat` or `/proc/net/dev` for network I/O

**Swift Charts (iOS 16+):**
- Native framework, no third-party dependency needed
- Supports real-time updating line charts
- Performance concern: limit to ~100 data points visible, use sliding window
- Source: [Apple Swift Charts docs](https://developer.apple.com/documentation/Charts)

**Data transport: WebSocket vs SSE:**
- WebSocket: bidirectional, lower latency, better for 1-second update intervals
- SSE: simpler, one-directional, good for 5-10 second intervals
- Recommendation: WebSocket for live metrics (already have WebSocketService in backend)

### Backend Implementation

**New `SystemMetricsService.swift`:**

| Metric | macOS Source | Linux Source |
|--------|-------------|--------------|
| CPU % | `host_processor_info()` | `/proc/stat` |
| Memory used/total | `host_statistics64()` | `/proc/meminfo` |
| Disk used/total | `FileManager.attributesOfFileSystem` | `statvfs()` |
| Network I/O | `netstat` or `nettop` | `/proc/net/dev` |
| Load average | `sysctl(CTL_VM, VM_LOADAVG)` | `/proc/loadavg` |
| Process list | `NSRunningApplication` + `proc_pidinfo` | `/proc/<pid>/stat` |

**API endpoints:**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/system/metrics` | GET | Snapshot of CPU, memory, disk, network |
| `/api/v1/system/processes` | GET | List running processes with CPU/memory |
| `/api/v1/system/files` | GET | Browse filesystem (with path query param) |
| `WS /api/v1/system/metrics/live` | WS | Stream metrics every 2 seconds |

**iOS Views:**
- New "System" tab in sidebar (or section in Dashboard)
- Live CPU/Memory/Disk/Network charts using Swift Charts
- Process list with search and sort (by CPU%, memory)
- File browser (tree view with breadcrumb navigation)
- Overview cards showing current values + sparkline trends

### Feasibility

| Aspect | Assessment | Notes |
|--------|------------|-------|
| macOS metrics | High | Well-documented APIs |
| Linux metrics | High | `/proc` filesystem is standard |
| Swift Charts | High | Native iOS 16+, app targets iOS 17 |
| WebSocket streaming | High | WebSocketService already exists |
| File browser | Medium | Security: must limit to allowed paths |
| Process management | Low | Kill/signal processes is risky |

### Recommendation

Start with read-only metrics dashboard (CPU, memory, disk, network) + process list. Use WebSocket for live streaming at 2-second intervals. File browser as a separate view with read-only access. Skip process kill/signal initially. Swift Charts provides native, performant charting.

---

## 5. Full Feature Parity Audit

### Feature Inventory

| Feature | View | Status | Issues |
|---------|------|--------|--------|
| **Dashboard** | DashboardView | WORKING | Stats load, recent sessions tappable, quick actions navigate |
| **Sessions List** | SessionsListView | WORKING | ILS + external sessions merged, search, delete, FAB button |
| **Create Session** | NewSessionView | PARTIAL | Creates session + auto-navigates, BUT advanced options (systemPrompt, maxBudget, maxTurns, fallbackModel) collected in form but NOT sent in `CreateSessionRequest` |
| **Chat** | ChatView | WORKING | SSE streaming, typing indicator, status banner, message history, fork, cancel |
| **Chat Cancel** | ChatViewModel | WORKING | Calls `POST /chat/cancel/:sessionId` + local SSE cancel |
| **Chat Fork** | ChatView | WORKING | Fork + alert + auto-navigate to forked session |
| **Session Info** | SessionInfoView | WORKING | Shows name, model, status, timestamps, cost |
| **Command Palette** | CommandPaletteView | PARTIAL | Opens sheet, inserts text into input, but commands are hardcoded strings not dynamic |
| **Message Rendering** | MessageView | PARTIAL | Text renders, tool calls show name only (no input/output preview), thinking blocks show but not collapsible, markdown rendering via MarkdownTextView |
| **Projects List** | ProjectsListView | WORKING | Filesystem projects with search, detail view |
| **Project Detail** | ProjectDetailView | WORKING | Shows info + sessions list + path |
| **Project Sessions** | ProjectSessionsListView | WORKING | Lists sessions for a project |
| **Skills List** | SkillsListView | WORKING | Installed skills + GitHub search + install |
| **Skill Detail** | SkillDetailView | WORKING | Full content, edit, delete, copy |
| **Skill Create** | SkillEditorView | WORKING | Create/edit via API |
| **MCP Servers** | MCPServerListView | WORKING | CRUD, scope picker, health status, import/export |
| **MCP Detail** | MCPServerDetailView | WORKING | Command, args, env, config path |
| **MCP Add/Edit** | NewMCPServerView + EditMCPServerView | WORKING | Full form, scope picker |
| **Plugins List** | PluginsListView | WORKING | Toggle enable/disable, uninstall, search |
| **Marketplace** | MarketplaceView | PARTIAL | Category filter works, install calls API, but install is git clone (which works) -- marketplace content depends on what repos are configured |
| **Settings** | SettingsView | WORKING | Connection, model, permissions, API key, hooks, stats, cache, about |
| **Config Editor** | ConfigEditorView | WORKING | Raw JSON editor with validation |
| **Sidebar** | SidebarView | WORKING | All tabs, connection status, active project |
| **Onboarding** | ServerSetupSheet | WORKING | URL entry, health check, auto-dismiss |
| **Log Viewer** | LogViewerView | EXISTS | Not verified if functional |
| **Notifications** | NotificationPreferencesView | EXISTS | Not verified if functional |
| **Session Templates** | SessionTemplatesView | EXISTS | Template presets for quick session creation |

### Key Issues Found

1. **`CreateSessionRequest` drops advanced options** -- Form collects systemPrompt, maxBudget, maxTurns, fallbackModel, includePartialMessages, continueConversation but `CreateSessionRequest` only sends `name`, `projectId`, `model`. The `buildChatOptions()` method exists but is never called.

2. **Permission decision is a stub** -- `ChatController.permission()` logs the decision but does nothing. The Claude CLI process has already moved on. Real permission handling would require interactive stdin.

3. **WebSocket chat handler exists but iOS never uses it** -- `ChatController.handleWebSocket()` is fully implemented but SSEClient only uses HTTP POST `/chat/stream`.

4. **Message rendering is basic** -- Tool calls show name only (no input preview, no collapsible output). Tool results show text only. Thinking blocks are inline text, not collapsible sections. No syntax highlighting for code blocks.

5. **No session rename** -- Sessions can be created with a name but there's no way to rename them later.

6. **No session export** -- Can't export chat history as text/markdown/JSON.

7. **No token/cost tracking dashboard** -- Individual sessions show cost, but no aggregate view of total spend.

8. **`healthCheck()` path mismatch** -- `getHealth()` calls `/health` directly but `loadHealth()` in SettingsViewModel calls `/api/v1/health` which doesn't exist (health endpoint is at root `/health`). This silently fails.

9. **Command palette is hardcoded** -- Commands like "Continue", "Stop", "Think harder" are static strings, not actual CLI commands.

10. **No dark/light theme toggle actually works** -- Settings shows color scheme picker (System/Light/Dark) that saves to backend config, but `ILSAppApp.swift` hardcodes `.preferredColorScheme(.dark)`. The setting has no effect.

11. **Marketplace categories are hardcoded** -- `["All", "Productivity", "DevOps", "Testing", "Documentation"]` are static strings, not from backend.

12. **GitHub search in Skills uses optimistic "Installed" state** -- After tapping Install, it shows "Installed" after a 2-second delay regardless of actual success/failure.

### Backend Endpoint Coverage

**Used by iOS (24 endpoints):**
- `GET /health`
- `GET /api/v1/stats`
- `GET /api/v1/stats/recent`
- `GET /api/v1/sessions`, `POST /sessions`, `DELETE /sessions/:id`
- `GET /sessions/scan`, `GET /sessions/:id/messages`
- `GET /sessions/transcript/:path/:sessionId`
- `POST /sessions/:id/fork`
- `POST /chat/stream`, `POST /chat/cancel/:id`
- `GET /projects`, `GET /projects/:id`
- `GET /projects/:id/sessions`
- `GET /skills`, `GET /skills/:name`, `POST /skills`, `PUT /skills/:name`, `DELETE /skills/:name`
- `GET /skills/github/search`, `POST /skills/github/install`
- `GET /mcp`, `POST /mcp`, `PUT /mcp/:name`, `DELETE /mcp/:name`
- `GET /plugins`, `POST /plugins/toggle`, `POST /plugins/install`, `DELETE /plugins/:name`
- `GET /plugins/marketplace`, `POST /plugins/marketplace`
- `GET /config`, `PUT /config`

**Unused by iOS:**
- `WS /chat/ws/:sessionId` -- WebSocket chat
- `POST /chat/permission/:requestId` -- Permission decisions
- `POST /auth/connect`, `GET /auth/server/status` -- SSH auth
- Various SSH-related endpoints

---

## 6. Codebase & UX Improvements (8 identified)

### Improvement 1: Navigation Architecture Overhaul
**Current:** Sidebar is a `.sheet` that dismisses on item selection. No tab bar.
**Problem:** Users must open sidebar sheet for every navigation. No persistent navigation indication.
**Fix:** Replace sidebar sheet with either (a) proper `TabView` with 4-5 primary tabs + "More" menu, or (b) iPad-style `NavigationSplitView` on larger iPhones. This is the single biggest UX friction.

### Improvement 2: Connection Status as Persistent Banner (not blocking)
**Current:** Red "No connection" banner at top blocks content area. Retry/Configure buttons compete for attention.
**Problem:** When disconnected, the error banner pushes content down and dominates the view.
**Fix:** Slim, non-intrusive status bar (like Slack's reconnecting banner) that slides down, auto-retries, and slides away on reconnect. Move detailed connection config to Settings only.

### Improvement 3: Pull-to-Refresh is Silent
**Current:** `.refreshable` exists on most lists but gives no completion feedback.
**Problem:** User pulls to refresh, spinner shows, data updates silently. No indication it succeeded.
**Fix:** Add haptic feedback on refresh completion + brief toast "Updated" or timestamp "Last updated: just now" at bottom of lists.

### Improvement 4: Chat Message Rendering Quality
**Current:** Plain text with basic tool call names. No markdown rendering. Thinking is inline.
**Problem:** Claude's responses often contain code blocks, lists, bold text. These render as plain text.
**Fix:** Proper markdown rendering (code syntax highlighting, collapsible thinking blocks, tool call accordions with input/output preview). Consider using `swift-markdown-ui` or similar.

### Improvement 5: Dead Code and Unused Dependencies
**Current:** `ClaudeCodeSDK` in Package.swift but never imported (bypassed due to RunLoop issue). `CacheManager` with no real caching. `ConfigurationManager` and `KeychainService` files exist but functionality is minimal.
**Problem:** Bloats build time and confuses contributors.
**Fix:** Remove `ClaudeCodeSDK` dependency. Audit all services for actual usage. Remove or implement properly.

### Improvement 6: Error Handling Inconsistency
**Current:** Some views show `ErrorStateView`, some print to console, some silently fail. `APIClient` has error types but many catch blocks just `print()`.
**Problem:** Users get no feedback when operations fail (e.g., skill install, plugin toggle).
**Fix:** Standardize error handling: all user-initiated actions show toast/alert on failure. All background operations log to `AppLogger`. Add retry logic for transient failures.

### Improvement 7: Missing Loading States
**Current:** Skills and Plugins show `ProgressView("Loading...")` centered. Sessions/Projects show skeleton views. Dashboard has skeleton. Inconsistent.
**Problem:** Some views feel broken during loading, others look polished.
**Fix:** Standardize on skeleton loading pattern across all list views. Add shimmer animation.

### Improvement 8: Accessibility Gaps
**Current:** Most views have `accessibilityIdentifier` and basic labels. Good foundation.
**Problem:** Dynamic type not tested, VoiceOver navigation order may be off, some interactive elements missing hints.
**Fix:** Test with Dynamic Type (all sizes). Ensure VoiceOver reads sensible order. Add accessibility traits to all interactive elements.

---

## 7. Ralph Orchestrator Latest Code

### Research Findings

- **No "ralph" code exists anywhere in the ILS codebase** -- Searched all source files, no matches except the word "orchestrat" in one docs file
- **No separate ralph-orchestrator repo found** -- No GitHub references, no package dependencies
- **The user's reference to "ralph orchestrator"** likely refers to the broader ILS concept -- the backend that orchestrates Claude Code sessions. The name "ralph" may be a project codename
- **`ralph-mobile` is referenced in MEMORY.md** as a separate app on port 8080 that conflicts with ILS on port 9090
- **The ILS backend IS the orchestrator** -- it wraps Claude CLI, manages sessions, handles streaming

### Recommendation

Clarify with user what "ralph orchestrator" repo/code they want pulled. The ILS backend (`Sources/ILSBackend/`) is the orchestrator. If there's a separate repo (e.g., `nickpettican/ralph` or similar), the user needs to provide the URL. The backend is already functional as a Claude Code orchestration layer.

---

## 8. Current UI/UX State Assessment

### Current Design System

**Colors:**
- Accent: #FF6B35 (hot orange)
- Background: Pure black (#000000)
- Secondary bg: #0D0D0D (near-black)
- Tertiary bg: #1A1A1A
- Text: White / #A0A0A0 / #666666
- Status: Green #4CAF50, Orange #FFA726, Red #EF5350, Blue #007AFF

**Typography:** System fonts with standard sizes (title/headline/body/caption/monospaced)

**Spacing:** 4/8/16/24/32 scale

**Components:** CardStyle, DarkListStyle, PrimaryButtonStyle, SecondaryButtonStyle, ErrorStateView, EmptyStateView, StatusBadge, ToastModifier, LoadingOverlay, HapticManager

### Design Problems Identified

1. **Monotonous dark gray on black** -- Every screen looks the same. No visual hierarchy between sections. Cards (#0D0D0D) barely distinguish from background (#000000).

2. **Orange accent is overused** -- Every interactive element, every icon, every link is the same #FF6B35. No color variation for different entity types (sessions vs projects vs skills).

3. **No visual identity** -- No app icon shown in-app, no branding, no distinctive visual element. Could be any app.

4. **List-heavy design** -- Almost every screen is a plain `List {}`. No visual variety (cards, grids, hero sections).

5. **Navigation is confusing** -- Sidebar as sheet is non-standard iOS. No tab bar. Users can't see where they are without opening sidebar.

6. **Forms are generic** -- NewSessionView, NewMCPServerView use default Form style. No custom styling, no visual grouping.

7. **No empty state personality** -- Empty states use system `ContentUnavailableView` with generic icons. No custom illustrations or personality.

8. **Stat cards are functional but boring** -- Dashboard stat cards are plain rectangles with numbers. No gradients, no progress rings, no visual interest.

### Redesign Recommendations

For the UI/UX redesign, consider:
- **Color-coded entities**: Blue for sessions, green for projects, purple for skills, orange for MCP, yellow for plugins
- **Gradient accents**: Subtle gradient headers or card borders instead of flat colors
- **Tab bar navigation**: Bottom tab bar with 4-5 primary destinations (Dashboard, Sessions, Projects, Settings) + "More" for Skills/MCP/Plugins
- **Rich stat cards**: Circular progress rings, sparkline mini-charts, subtle background gradients
- **Visual hierarchy**: Larger section headers, divider lines between groups, more whitespace
- **Frosted glass effects**: Use `.ultraThinMaterial` for overlays and sheets (iOS native)
- **Custom empty states**: Illustrated empty states with personality
- **Chat redesign**: Bubble styles with gradients, avatar placeholders, code block syntax highlighting

---

## Related Specs

| Spec | Relevance | Relationship | mayNeedUpdate |
|------|-----------|-------------|---------------|
| `ios-app-polish` | High | Direct predecessor. Validated 13 scenarios, implemented ServerSetupSheet, deterministic IDs, dead code cleanup. This spec builds on top. | No (superseded) |
| `ils-complete-rebuild` | High | Identified 42 gaps. Only 3 tasks completed (Citadel + SSHService + AuthController). SSH architecture decisions relevant. | Yes (Cloudflare tunnel changes SSH approach) |
| `agent-teams` | Medium | Audited 14 issues in the app. Overlap with feature parity audit. | No |
| `app-improvements` | Low | Empty spec, just CLAUDE.md. | No |

---

## Quality Commands

| Type | Command | Source |
|------|---------|--------|
| Backend Build | `swift build` | Package.swift |
| iOS Build | `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build` | Xcode project |
| Lint | Not found | No linter configured |
| TypeCheck | Not found | Swift compiler is the type checker |
| Unit Test | `swift test` | Package.swift testTargets |
| Integration Test | Not found | No integration tests |
| E2E Test | Not found | No automated E2E tests |
| Build (all) | `swift build && xcodebuild ...` | Combined |

**Local CI**: `swift build && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build`

---

## Feasibility Assessment

| Area | Viability | Effort | Risk | Notes |
|------|-----------|--------|------|-------|
| Cloudflare Tunnel | High | M | Low | Process spawn + stdout parse. Quick tunnel is trivial. |
| First-Run Config | High | S | Low | Enhance existing ServerSetupSheet |
| SSH Provisioning | Medium | L | Medium | Citadel works but install scripts need testing per platform |
| System Monitoring | High | L | Low | Well-documented APIs, Swift Charts native |
| Feature Parity | High | M | Low | Most features work; fix 12 specific issues found |
| UX Improvements | High | M | Low | Mostly UI changes, no backend work |
| Ralph Orchestrator | Unknown | ? | High | Need user to clarify what repo/code |
| UI/UX Redesign | High | XL | Medium | Touches every view; risk of regression |

**Overall Effort: XL** (4-6 weeks of focused work)

---

## Recommendations for Requirements

1. **Prioritize feature parity fixes over new features** -- The 12 issues found (advanced options not sent, health check path mismatch, dark mode toggle broken, etc.) should be fixed FIRST before adding Cloudflare/monitoring.

2. **Implement Cloudflare quick tunnel first** -- It's the simplest remote access solution. Named tunnels can come later.

3. **System monitoring should be a new tab, not embedded in Dashboard** -- It's a distinct feature set that deserves its own navigation entry.

4. **UI/UX redesign should happen AFTER functional completeness** -- Fix broken features first, redesign second. Otherwise redesign masks bugs.

5. **Navigation overhaul is the single highest-impact UX change** -- Replace sidebar sheet with tab bar. This affects every user interaction.

6. **Drop or defer SSH provisioning to phase 2** -- It's the riskiest and least commonly needed feature. Focus on Cloudflare + monitoring first.

7. **Ralph orchestrator needs user clarification** -- Can't implement without knowing what code to pull.

8. **Add aggregate cost tracking** -- Users managing multiple Claude sessions need to see total spend across all sessions.

9. **Standardize error handling and loading states** -- Apply consistent patterns across all views before redesign.

10. **Chat message rendering upgrade is high-impact** -- Proper markdown, code highlighting, and collapsible sections dramatically improve the primary use case.

---

## Open Questions for User

1. **Ralph orchestrator**: What repo/URL should be pulled? Is this the ILS backend itself, or a separate codebase?

2. **Cloudflare account**: Should the app assume `cloudflared` is pre-installed on the backend host, or should it handle installation? Should named tunnel support require users to enter their Cloudflare API token?

3. **System monitoring scope**: Should file browsing be included (security risk), or only read-only metrics (CPU/memory/disk/network)?

4. **SSH provisioning target OS**: Is this only for macOS hosts, or also Linux (Ubuntu/Debian)? The install scripts differ significantly.

5. **Redesign scope**: Full redesign of all 22+ screens, or focused redesign of key flows (onboarding, chat, dashboard)?

6. **Backend deployment**: Is the backend expected to run as a persistent service (launchd/systemd), or manually started? This affects tunnel and monitoring lifecycles.

7. **Multi-backend support**: Should the app support connecting to multiple backends simultaneously (e.g., local + remote), or single connection only?

---

## Sources

### External
- [Cloudflare Quick Tunnels docs](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/)
- [Cloudflare Tunnel API docs](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel-api/)
- [cloudflare/cloudflared GitHub](https://github.com/cloudflare/cloudflared)
- [apple/swift-system-metrics](https://github.com/apple/swift-system-metrics)
- [sysctl in Swift](https://sanzaru84.medium.com/how-to-fetch-system-information-with-sysctl-in-swift-on-macos-8ffcdc9b5b99)
- [Apple Swift Charts](https://developer.apple.com/documentation/Charts)
- [Real-time Charts in SwiftUI](https://medium.com/@wesleymatlock/real-time-graphs-charts-in-swiftui-master-of-data-visualization-460cd03610a3)
- [Apple Developer Forums - CPU usage](https://developer.apple.com/forums/thread/655349)

### Internal (key files read)
- `<project-root>/ILSApp/ILSApp/ILSAppApp.swift` -- App entry point + AppState
- `<project-root>/ILSApp/ILSApp/ContentView.swift` -- Navigation container
- `<project-root>/ILSApp/ILSApp/Views/Chat/ChatView.swift` -- Chat UI
- `<project-root>/ILSApp/ILSApp/ViewModels/ChatViewModel.swift` -- Chat logic
- `<project-root>/ILSApp/ILSApp/Services/APIClient.swift` -- HTTP client
- `<project-root>/ILSApp/ILSApp/Services/SSEClient.swift` -- SSE streaming
- `<project-root>/ILSApp/ILSApp/Theme/ILSTheme.swift` -- Design system
- `<project-root>/ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift` -- Onboarding
- `<project-root>/ILSApp/ILSApp/Views/Settings/SettingsView.swift` -- Settings
- `<project-root>/ILSApp/ILSApp/Views/Dashboard/DashboardView.swift` -- Dashboard
- `<project-root>/ILSApp/ILSApp/Views/Sessions/SessionsListView.swift` -- Sessions list
- `<project-root>/ILSApp/ILSApp/Views/Sessions/NewSessionView.swift` -- Session creation
- `<project-root>/ILSApp/ILSApp/Views/Projects/ProjectsListView.swift` -- Projects
- `<project-root>/ILSApp/ILSApp/Views/Skills/SkillsListView.swift` -- Skills
- `<project-root>/ILSApp/ILSApp/Views/MCP/MCPServerListView.swift` -- MCP servers
- `<project-root>/ILSApp/ILSApp/Views/Plugins/PluginsListView.swift` -- Plugins
- `<project-root>/ILSApp/ILSApp/Views/Sidebar/SidebarView.swift` -- Sidebar nav
- `<project-root>/Sources/ILSBackend/Controllers/ChatController.swift` -- Chat API
- `<project-root>/Sources/ILSBackend/Services/ClaudeExecutorService.swift` -- Claude CLI wrapper
- `<project-root>/Sources/ILSBackend/Services/SSHService.swift` -- SSH client
- `<project-root>/Sources/ILSBackend/App/routes.swift` -- Route registration
- `<project-root>/Sources/ILSShared/Models/Session.swift` -- Session model
- `<project-root>/Package.swift` -- Dependencies
- `<project-root>/specs/ios-app-polish/.progress.md` -- Previous spec progress
- `<project-root>/specs/ils-complete-rebuild/.progress.md` -- Rebuild spec progress
