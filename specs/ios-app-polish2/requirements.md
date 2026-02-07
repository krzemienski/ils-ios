# Requirements: ILS iOS App — Complete Polish, Remote Access & System Monitoring

## Goal

Transform the ILS iOS app from a functional prototype into a polished, feature-complete Claude Code management tool with remote access via Cloudflare tunnels, host system monitoring, proper navigation, and a redesigned UI — validated end-to-end with real builds and screenshot evidence.

---

## Architectural Decisions (Locked)

| # | Decision | Rationale |
|---|----------|-----------|
| AD-1 | **Tab bar navigation** replaces sidebar-as-sheet | Sidebar sheet is the #1 UX friction. Tab bar is standard iOS. Sidebar kept as supplementary (swipe gesture or toolbar). |
| AD-2 | **Cloudflare quick tunnel first** | Zero config, no account needed. Named tunnels as optional "bring your own Cloudflare" upgrade. |
| AD-3 | **SSH provisioning deferred** | High risk, low immediate value. Citadel + SSHService stay in codebase for future use. Focus on Cloudflare for remote access. |
| AD-4 | **System monitoring as new tab** | Distinct feature set (CPU/memory/disk/network/processes) deserves dedicated navigation entry, not embedded in Dashboard. |
| AD-5 | **WebSocket for live metrics** | Already have WebSocketService. 2-second intervals for real-time charts. SSE for chat, WS for metrics. |
| AD-6 | **Feature parity fixes before redesign** | Fix broken features first (12 known issues). Then redesign. Redesign must not mask bugs. |
| AD-7 | **Color-coded entities** | Sessions=blue, Projects=green, Skills=purple, MCP=orange, Plugins=yellow, System=teal. Breaks the "everything is orange" monotony. |
| AD-8 | **Dark mode only** | Consistent with v1 decision. Fix the broken theme toggle to respect user choice between system/light/dark. |

---

## User Stories

### US-1: Cloudflare Quick Tunnel for Remote Access

**As a** user running ILS backend on my home machine
**I want to** start a Cloudflare tunnel with one tap and get a public URL
**So that** I can access my backend from anywhere without port forwarding

**Acceptance Criteria:**
- [ ] AC-1.1: Settings > Remote Access section shows "Start Tunnel" toggle
- [ ] AC-1.2: Toggling on calls `POST /api/v1/tunnel/start`; backend spawns `cloudflared tunnel --url http://localhost:9090`
- [ ] AC-1.3: Backend parses `trycloudflare.com` URL from cloudflared stdout within 15 seconds
- [ ] AC-1.4: Tunnel URL displayed with "Copy" button and QR code (CoreImage CIQRCodeGenerator)
- [ ] AC-1.5: `GET /api/v1/tunnel/status` returns `{running: bool, url: string?, uptime: int?}`
- [ ] AC-1.6: Toggling off calls `POST /api/v1/tunnel/stop`; backend kills cloudflared process
- [ ] AC-1.7: If `cloudflared` binary not found, show inline message with install instructions link
- [ ] AC-1.8: Tunnel URL auto-populates in ServerSetupSheet when connecting from another device

### US-2: Named Cloudflare Tunnel (Optional)

**As a** user with a Cloudflare account
**I want to** configure a named tunnel with my own domain
**So that** I get a stable, branded URL that persists across restarts

**Acceptance Criteria:**
- [ ] AC-2.1: Settings > Remote Access > "Use Custom Domain" section (collapsed by default)
- [ ] AC-2.2: Fields for Cloudflare API token and tunnel name
- [ ] AC-2.3: Token stored securely (backend env var or Keychain)
- [ ] AC-2.4: `POST /api/v1/tunnel/start` accepts optional `{token, tunnelName, domain}` for named tunnel
- [ ] AC-2.5: Named tunnel survives backend restart (persisted config)

### US-3: Enhanced First-Run Onboarding

**As a** new user opening the app for the first time
**I want to** be guided through connecting to a backend with clear options
**So that** I can get started without confusion

**Acceptance Criteria:**
- [ ] AC-3.1: ServerSetupSheet shows three tab modes: "Local" (prefilled `http://localhost:9090`), "Remote" (IP/hostname input), "Tunnel" (paste Cloudflare URL)
- [ ] AC-3.2: Connection progress shows 3 steps: DNS resolve, TCP connect, health check — with checkmarks
- [ ] AC-3.3: Successful connection shows backend info: Claude CLI version, project count, skill count
- [ ] AC-3.4: Connection history stored in UserDefaults array (last 5 URLs)
- [ ] AC-3.5: Recent connections shown as tappable list below input
- [ ] AC-3.6: "Configure" button in disconnected banner opens ServerSetupSheet (existing behavior preserved)

### US-4: Tab Bar Navigation

**As a** user
**I want to** switch between app sections via a bottom tab bar
**So that** I always know where I am and can navigate with one tap

**Acceptance Criteria:**
- [ ] AC-4.1: Bottom tab bar with 5 tabs: Dashboard, Sessions, Projects, System, Settings
- [ ] AC-4.2: Each tab uses distinct SF Symbol icon + entity color tint on active state
- [ ] AC-4.3: Skills, MCP Servers, Plugins accessible from Dashboard quick actions or Settings sub-sections
- [ ] AC-4.4: Sidebar sheet removed as primary navigation; replaced by tab bar
- [ ] AC-4.5: Tab bar uses `.ultraThinMaterial` background for frosted glass effect
- [ ] AC-4.6: Badge counts on tabs (e.g., active sessions count on Sessions tab)

### US-5: System Metrics Dashboard

**As a** user running Claude Code sessions on a host machine
**I want to** see real-time CPU, memory, disk, and network metrics
**So that** I can monitor system health and debug performance issues

**Acceptance Criteria:**
- [ ] AC-5.1: "System" tab shows 4 metric cards: CPU %, Memory used/total, Disk used/total, Network I/O
- [ ] AC-5.2: Each card has a sparkline chart (Swift Charts, last 60 data points = 2 minutes)
- [ ] AC-5.3: Live data via WebSocket `WS /api/v1/system/metrics/live` at 2-second intervals
- [ ] AC-5.4: Fallback to `GET /api/v1/system/metrics` polling at 5-second intervals if WS fails
- [ ] AC-5.5: Load average shown as supplementary metric below CPU
- [ ] AC-5.6: Cards use gradient backgrounds matching entity color scheme (teal for system)

### US-6: Process List

**As a** user monitoring system resources
**I want to** see running processes sorted by CPU/memory usage
**So that** I can identify resource-heavy Claude sessions

**Acceptance Criteria:**
- [ ] AC-6.1: "Processes" section below metrics cards (or separate sub-tab)
- [ ] AC-6.2: List shows process name, PID, CPU %, memory MB — from `GET /api/v1/system/processes`
- [ ] AC-6.3: Search bar filters processes by name
- [ ] AC-6.4: Sort toggle: by CPU (default) or by memory
- [ ] AC-6.5: Pull-to-refresh reloads process list
- [ ] AC-6.6: Read-only — no kill/signal functionality (safety)

### US-7: File Browser

**As a** user managing Claude Code on a remote host
**I want to** browse the filesystem from the app
**So that** I can inspect project files and configs without SSH

**Acceptance Criteria:**
- [ ] AC-7.1: "Files" sub-section in System tab
- [ ] AC-7.2: Tree view starting at `~/` with breadcrumb navigation
- [ ] AC-7.3: `GET /api/v1/system/files?path=/path` returns directory listing (name, type, size, modified)
- [ ] AC-7.4: Tapping a file shows read-only preview (text files only, first 500 lines)
- [ ] AC-7.5: Tapping a directory navigates into it
- [ ] AC-7.6: Read-only — no create/edit/delete (safety)
- [ ] AC-7.7: Backend restricts paths to user home directory (no `/etc`, `/var`)

### US-8: Fix Advanced Session Options

**As a** user creating a new session with specific settings
**I want to** my systemPrompt, maxBudget, maxTurns, and fallbackModel to actually be sent to the backend
**So that** my sessions use the configuration I specified

**Acceptance Criteria:**
- [ ] AC-8.1: `CreateSessionRequest` includes systemPrompt, maxBudget, maxTurns, fallbackModel, permissions fields
- [ ] AC-8.2: `buildChatOptions()` called and options passed in first `POST /chat/stream` request
- [ ] AC-8.3: Session created with advanced options behaves differently than default (verifiable via response)

### US-9: Fix Health Check Path Mismatch

**As a** user checking backend connection in Settings
**I want to** "Test Connection" to actually work
**So that** I get accurate connection status

**Acceptance Criteria:**
- [ ] AC-9.1: `SettingsViewModel.loadHealth()` calls `/health` (root), not `/api/v1/health`
- [ ] AC-9.2: "Test Connection" in Settings shows green check on success, red X with error on failure
- [ ] AC-9.3: Health check result includes Claude CLI version and backend uptime

### US-10: Fix Dark Mode Toggle

**As a** user who prefers light mode or system-follows
**I want to** the color scheme picker in Settings to actually change the app theme
**So that** my preference is respected

**Acceptance Criteria:**
- [ ] AC-10.1: Remove hardcoded `.preferredColorScheme(.dark)` from `ILSAppApp.swift`
- [ ] AC-10.2: Color scheme read from `AppState` (backed by UserDefaults)
- [ ] AC-10.3: Changing picker in Settings immediately updates app appearance
- [ ] AC-10.4: Preference persists across app launches

### US-11: Session Rename & Export

**As a** user with many sessions
**I want to** rename sessions and export chat history
**So that** I can organize conversations and share them

**Acceptance Criteria:**
- [ ] AC-11.1: Long-press or swipe on session row reveals "Rename" action
- [ ] AC-11.2: Rename updates session name via `PUT /api/v1/sessions/:id` (new endpoint)
- [ ] AC-11.3: Session info view has "Export" button
- [ ] AC-11.4: Export generates markdown file of conversation and presents iOS share sheet
- [ ] AC-11.5: Export includes session name, model, timestamps, all messages

### US-12: Chat Message Rendering Upgrade

**As a** user chatting with Claude
**I want to** see properly rendered markdown, code blocks, and collapsible sections
**So that** Claude's responses are readable and useful

**Acceptance Criteria:**
- [ ] AC-12.1: Markdown renders: bold, italic, lists, headings, links, inline code
- [ ] AC-12.2: Code blocks render with syntax highlighting and language label
- [ ] AC-12.3: Tool calls render as expandable accordions showing tool name + input preview
- [ ] AC-12.4: Tool results render with collapsible output
- [ ] AC-12.5: Thinking blocks render as collapsible "Thinking..." sections
- [ ] AC-12.6: Chat bubbles use gradient styling: user messages right-aligned (blue gradient), assistant left-aligned (dark gray)

### US-13: Command Palette with Dynamic Commands

**As a** user in a chat session
**I want to** access real Claude CLI commands from the command palette
**So that** I can use advanced features without typing

**Acceptance Criteria:**
- [ ] AC-13.1: Command palette populated from backend or from known Claude CLI command list
- [ ] AC-13.2: Commands include: /compact, /clear, /config, /cost, /doctor, /help, /init, /login, /logout, /mcp, /memory, /model, /permissions, /review, /status, /terminal-setup
- [ ] AC-13.3: Selecting a command inserts it as a message (existing behavior)
- [ ] AC-13.4: Search/filter within command palette

### US-14: Aggregate Cost Tracking

**As a** user managing multiple Claude sessions
**I want to** see total spend across all sessions
**So that** I can monitor my API costs

**Acceptance Criteria:**
- [ ] AC-14.1: Dashboard shows total cost card (sum of all session costs)
- [ ] AC-14.2: Cost breakdown by model available in Settings > Usage
- [ ] AC-14.3: Data sourced from `GET /api/v1/stats` (aggregate) + per-session cost from session info
- [ ] AC-14.4: Cost displayed as USD with 2 decimal places

### US-15: Fix Skill Install Optimistic State

**As a** user installing a skill from GitHub
**I want to** see real install status, not a fake "Installed" after 2 seconds
**So that** I know if the install actually succeeded

**Acceptance Criteria:**
- [ ] AC-15.1: Install button shows spinner during `POST /skills/install` request
- [ ] AC-15.2: On success (HTTP 200), button changes to "Installed" with checkmark
- [ ] AC-15.3: On failure, button reverts to "Install" and shows inline error toast
- [ ] AC-15.4: Remove the hardcoded 2-second delay

### US-16: Dynamic Marketplace Categories

**As a** user browsing the plugin marketplace
**I want to** see categories sourced from actual data, not hardcoded strings
**So that** categories reflect what's actually available

**Acceptance Criteria:**
- [ ] AC-16.1: Categories derived from `GET /plugins/marketplace` response data (unique category values)
- [ ] AC-16.2: "All" category always present as first option
- [ ] AC-16.3: Client-side filtering by category (existing behavior, but with dynamic data)

### US-17: Standardized Error Handling

**As a** user performing any action
**I want to** see clear, consistent feedback when something fails
**So that** I know what went wrong and what to do

**Acceptance Criteria:**
- [ ] AC-17.1: All user-initiated actions show toast on failure (not silent `print()`)
- [ ] AC-17.2: Error messages are user-friendly (no raw HTTP codes, no stack traces)
- [ ] AC-17.3: Transient network errors auto-retry (3 attempts, exponential backoff)
- [ ] AC-17.4: All background operations log to `AppLogger`
- [ ] AC-17.5: Consistent `ErrorStateView` used across all views

### US-18: Standardized Loading States

**As a** user waiting for data to load
**I want to** see consistent skeleton/shimmer loading patterns
**So that** the app feels polished and responsive

**Acceptance Criteria:**
- [ ] AC-18.1: All list views use skeleton loading pattern (not mixed spinner/skeleton)
- [ ] AC-18.2: Shimmer animation on skeleton placeholders
- [ ] AC-18.3: Loading state disappears once data arrives (no flash of empty state)

### US-19: UI/UX Redesign

**As a** user
**I want to** see a visually distinctive, polished app with clear visual hierarchy
**So that** the app feels professional and is enjoyable to use

**Acceptance Criteria:**
- [ ] AC-19.1: Color-coded entities: Sessions=#007AFF (blue), Projects=#34C759 (green), Skills=#AF52DE (purple), MCP=#FF6B35 (orange), Plugins=#FFD60A (yellow), System=#30B0C7 (teal)
- [ ] AC-19.2: Dashboard stat cards use circular progress rings or gradient backgrounds per entity color
- [ ] AC-19.3: Section headers with larger font weight and more whitespace
- [ ] AC-19.4: Custom empty states with SF Symbol illustrations + descriptive text (not generic `ContentUnavailableView`)
- [ ] AC-19.5: Forms use grouped inset style with rounded sections
- [ ] AC-19.6: Frosted glass (`.ultraThinMaterial`) on sheets, overlays, tab bar
- [ ] AC-19.7: Subtle gradient accents on card borders/headers
- [ ] AC-19.8: Pull-to-refresh adds haptic feedback + "Updated just now" timestamp

### US-20: Dead Code & Dependency Cleanup

**As a** developer
**I want to** remove unused code and dependencies
**So that** the codebase is clean and builds are fast

**Acceptance Criteria:**
- [ ] AC-20.1: `ClaudeCodeSDK` removed from Package.swift (bypassed, never imported)
- [ ] AC-20.2: All unused services audited: `CacheManager`, `ConfigurationManager`, `KeychainService` — remove or implement properly
- [ ] AC-20.3: No dead imports or unreachable code paths
- [ ] AC-20.4: Build time unchanged or improved after cleanup

---

## Functional Requirements

### FR-1: Cloudflare Tunnel (Backend)

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-1.1 | `POST /api/v1/tunnel/start` — Spawn `cloudflared` process, parse URL | Must | cURL returns `{url: "https://xxx.trycloudflare.com"}` |
| FR-1.2 | `POST /api/v1/tunnel/stop` — Kill cloudflared process | Must | cURL returns `{stopped: true}` |
| FR-1.3 | `GET /api/v1/tunnel/status` — Return tunnel state + URL | Must | cURL returns `{running: true/false, url: ...}` |
| FR-1.4 | `TunnelService.swift` actor — Process lifecycle, stdout parsing, health check | Must | Backend compiles, tunnel starts/stops cleanly |
| FR-1.5 | Named tunnel support with Cloudflare API token | Should | cURL with token creates persistent tunnel |

### FR-2: First-Run Onboarding (iOS)

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-2.1 | ServerSetupSheet Local/Remote/Tunnel tabs | Must | Screenshot shows 3 tab modes |
| FR-2.2 | Multi-step connection progress indicator | Must | Screenshot shows DNS/TCP/health steps |
| FR-2.3 | Connection history (last 5 URLs) | Should | Reconnect to previously used URL |
| FR-2.4 | Backend info display after connection | Should | Shows Claude version + counts |

### FR-3: System Monitoring (Backend)

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-3.1 | `GET /api/v1/system/metrics` — CPU, memory, disk, network snapshot | Must | cURL returns metrics JSON |
| FR-3.2 | `WS /api/v1/system/metrics/live` — Stream metrics every 2 seconds | Must | WebSocket client receives periodic updates |
| FR-3.3 | `GET /api/v1/system/processes` — Process list with CPU/memory per process | Must | cURL returns process array |
| FR-3.4 | `GET /api/v1/system/files?path=` — Directory listing (read-only) | Should | cURL returns file/directory entries |
| FR-3.5 | `SystemMetricsService.swift` — macOS (`host_processor_info`, `host_statistics64`) + Linux (`/proc/*`) | Must | Metrics accurate on build host |
| FR-3.6 | Path restriction to user home directory | Must | cURL with `/etc/shadow` returns 403 |

### FR-4: System Monitoring (iOS)

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-4.1 | System tab with 4 metric cards + sparkline charts (Swift Charts) | Must | Screenshot shows live charts |
| FR-4.2 | Process list with search and sort | Must | Screenshot shows filtered processes |
| FR-4.3 | File browser with breadcrumb navigation | Should | Screenshot shows directory tree |
| FR-4.4 | WebSocket connection for live metrics | Must | Charts update in real-time |

### FR-5: Feature Parity Fixes

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-5.1 | `CreateSessionRequest` sends all advanced options | Must | Session created with systemPrompt behaves accordingly |
| FR-5.2 | Health check path fixed (`/health` not `/api/v1/health`) | Must | "Test Connection" in Settings works |
| FR-5.3 | Dark mode toggle wired to `preferredColorScheme` | Must | Changing setting changes app theme |
| FR-5.4 | Skill install shows real status (no fake 2s delay) | Must | Failed install shows error, not "Installed" |
| FR-5.5 | Command palette uses real Claude CLI commands | Should | Commands list matches Claude CLI `/help` |
| FR-5.6 | Session rename via `PUT /sessions/:id` | Should | Renamed session persists |
| FR-5.7 | Session export as markdown via share sheet | Should | Shared markdown contains full conversation |
| FR-5.8 | Marketplace categories from data, not hardcoded | Should | Categories match marketplace content |
| FR-5.9 | Aggregate cost tracking on Dashboard | Should | Total cost shown across sessions |
| FR-5.10 | Permission endpoint is stub — document as known limitation | Won't (v1) | Documented in app "About" or README |
| FR-5.11 | WebSocket chat unused — document as future enhancement | Won't (v1) | Documented |

### FR-6: Navigation & UX

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-6.1 | Replace sidebar sheet with 5-tab TabView | Must | Screenshot shows bottom tab bar |
| FR-6.2 | Connection banner as slim, non-intrusive bar | Must | Screenshot shows Slack-style reconnecting banner |
| FR-6.3 | Pull-to-refresh with haptic + "Updated" timestamp | Should | Haptic fires on refresh complete |
| FR-6.4 | Consistent skeleton loading across all list views | Should | All lists use same skeleton pattern |

### FR-7: Chat Rendering

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-7.1 | Markdown rendering (bold, italic, lists, headings, links, code) | Must | Screenshot shows formatted response |
| FR-7.2 | Code blocks with syntax highlighting + language label | Must | Screenshot shows highlighted code |
| FR-7.3 | Tool call expandable accordions | Should | Screenshot shows collapsed/expanded tool call |
| FR-7.4 | Thinking blocks as collapsible sections | Should | Screenshot shows "Thinking..." toggle |
| FR-7.5 | Chat bubbles with gradient styling | Should | Screenshot shows styled bubbles |

### FR-8: UI/UX Redesign

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-8.1 | Entity color scheme applied across all views | Must | Each entity type has distinct color |
| FR-8.2 | Dashboard stat cards with gradients/rings | Must | Screenshot shows redesigned cards |
| FR-8.3 | Custom empty states with personality | Should | Screenshot shows custom empty views |
| FR-8.4 | Frosted glass materials on overlays | Should | Sheets/tab bar show blur effect |
| FR-8.5 | ClaudeCodeSDK removed from Package.swift | Must | `swift build` succeeds without it |
| FR-8.6 | Unused services removed or implemented | Should | No dead code in Services/ |

---

## Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-1 | App launch to connected dashboard | Time | < 3 seconds on local network |
| NFR-2 | System metrics WebSocket latency | Latency | < 100ms per update on LAN |
| NFR-3 | Swift Charts rendering (60 data points) | Frame rate | 60fps, no jank |
| NFR-4 | Tunnel URL availability after start | Time | < 15 seconds |
| NFR-5 | File browser directory listing | Time | < 1 second for directories with < 1000 entries |
| NFR-6 | Error messages | Quality | No raw HTTP codes, no stack traces, no "Error:" prefixes |
| NFR-7 | Pull-to-refresh on all list views | Consistency | 100% of list views support it |
| NFR-8 | Memory usage with live metrics | Peak | < 250MB with charts active |
| NFR-9 | Accessibility | VoiceOver | All interactive elements labeled; Dynamic Type M-XXXL tested |
| NFR-10 | Dark mode | Single theme | No light-mode color leaks (unless user selects light) |
| NFR-11 | Backend process cleanup | Reliability | `cloudflared` process killed on backend shutdown (SIGTERM handler) |
| NFR-12 | iOS version | Platform | iOS 17.0+ |

---

## MoSCoW Priority Matrix

### Must Have (P0)
- Tab bar navigation (FR-6.1)
- System metrics backend + iOS (FR-3.1-3.3, FR-4.1-4.2, FR-4.4)
- Cloudflare quick tunnel (FR-1.1-1.4)
- Health check fix (FR-5.2)
- Dark mode toggle fix (FR-5.3)
- Advanced session options fix (FR-5.1)
- Skill install real status (FR-5.4)
- Markdown chat rendering (FR-7.1-7.2)
- Entity color scheme (FR-8.1-8.2)
- ClaudeCodeSDK removal (FR-8.5)
- Enhanced onboarding tabs (FR-2.1-2.2)

### Should Have (P1)
- Process list with search/sort (FR-4.2)
- File browser (FR-4.3, FR-3.4)
- Connection history (FR-2.3-2.4)
- Named tunnel (FR-1.5)
- Session rename + export (FR-5.6-5.7)
- Command palette dynamic commands (FR-5.5)
- Marketplace dynamic categories (FR-5.8)
- Aggregate cost tracking (FR-5.9)
- Tool call accordions + thinking blocks (FR-7.3-7.4)
- Chat bubble styling (FR-7.5)
- Connection banner redesign (FR-6.2)
- Pull-to-refresh feedback (FR-6.3)
- Skeleton loading standardization (FR-6.4)
- Custom empty states (FR-8.3)
- Frosted glass materials (FR-8.4)
- Dead code cleanup (FR-8.6)

### Could Have (P2)
- Accessibility audit (Dynamic Type, VoiceOver order)
- File content preview in file browser
- QR code for tunnel URL

### Won't Have (v1)
- SSH provisioning wizard (AD-3, deferred)
- Permission handling for Claude tool use (FR-5.10, stub remains)
- WebSocket chat (FR-5.11, SSE remains primary)
- Process kill/signal (safety concern)
- Light mode theme design (fix toggle, but no custom light palette)
- Multi-backend simultaneous connections
- Ralph orchestrator sync (user must clarify repo)

---

## Validation Scenarios (Functional, No Mocks)

Each scenario validated on dedicated simulator (iPhone 16 Pro Max, UDID: `50523130-57AA-48B0-ABD0-4D59CE455F14`).

### VS-1: Cloudflare Tunnel Lifecycle
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | Open Settings > Remote Access | Tunnel section visible | Screenshot |
| 2 | Tap "Start Tunnel" | Spinner, then URL appears | Screenshot |
| 3 | Copy URL, open in browser | Backend health endpoint responds | Browser screenshot |
| 4 | Tap "Stop Tunnel" | URL clears, toggle off | Screenshot |

### VS-2: First-Run Onboarding Flow
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | Fresh install, launch | ServerSetupSheet with 3 tabs | Screenshot |
| 2 | Select "Local", tap Connect | Progress steps: DNS, TCP, health | Screenshot |
| 3 | Connection succeeds | Backend info shown, sheet dismisses | Screenshot |
| 4 | Dashboard loads | Real stats visible | Screenshot |

### VS-3: Tab Bar Navigation
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | App launched, connected | Bottom tab bar with 5 tabs | Screenshot |
| 2 | Tap each tab | Correct view loads per tab | 5 screenshots |
| 3 | Skills/MCP/Plugins | Accessible from Dashboard or Settings | Screenshot |

### VS-4: System Metrics Live
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | Open System tab | 4 metric cards with charts | Screenshot |
| 2 | Wait 10 seconds | Charts update with new data points | Screenshot |
| 3 | Scroll to processes | Process list with CPU/memory columns | Screenshot |
| 4 | Search "claude" | Filtered to Claude-related processes | Screenshot |

### VS-5: File Browser
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | System tab > Files | Home directory listing | Screenshot |
| 2 | Navigate into `.claude/` | Skills, projects visible | Screenshot |
| 3 | Tap a text file | Read-only content preview | Screenshot |

### VS-6: Advanced Session Creation
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | Create session with systemPrompt "You are a pirate" | Session created | Screenshot |
| 2 | Send "Hello" | Response in pirate voice | Screenshot |

### VS-7: Dark/Light Mode Toggle
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | Settings > Appearance > Light | App switches to light mode | Screenshot |
| 2 | Settings > Appearance > Dark | App switches to dark mode | Screenshot |
| 3 | Relaunch app | Persisted preference applied | Screenshot |

### VS-8: Chat Markdown Rendering
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | Send "Write hello world in Python with explanation" | Response with code block | Screenshot |
| 2 | Verify code block | Syntax highlighted, language label | Screenshot |
| 3 | Verify markdown | Bold, lists, headings rendered | Screenshot |

### VS-9: Session Rename & Export
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | Long-press session > Rename | Rename dialog appears | Screenshot |
| 2 | Enter new name, confirm | List shows updated name | Screenshot |
| 3 | Session info > Export | Share sheet with markdown | Screenshot |

### VS-10: Skill Install Real Status
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | Search GitHub for a skill | Results with Install buttons | Screenshot |
| 2 | Tap Install | Spinner shown during install | Screenshot |
| 3 | Install succeeds | "Installed" with checkmark (real, not timed) | Screenshot |

### VS-11: System Monitoring Backend cURL
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | `curl /api/v1/system/metrics` | CPU/memory/disk/network JSON | Terminal output |
| 2 | `curl /api/v1/system/processes` | Process array with PID/CPU/mem | Terminal output |
| 3 | `curl /api/v1/system/files?path=~` | Directory listing JSON | Terminal output |

### VS-12: Cost Tracking
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | Dashboard | Total cost card visible | Screenshot |
| 2 | Multiple sessions with costs | Aggregate matches sum | Screenshot |

### VS-13: Error Handling Consistency
| Step | Action | Expected | Evidence |
|------|--------|----------|----------|
| 1 | Disconnect backend, try action | Toast error shown (not silent) | Screenshot |
| 2 | Reconnect | Banner clears, data loads | Screenshot |

---

## New Backend Endpoints Required

| # | Endpoint | Method | Purpose |
|---|----------|--------|---------|
| 1 | `/api/v1/tunnel/start` | POST | Start cloudflared tunnel |
| 2 | `/api/v1/tunnel/stop` | POST | Stop cloudflared tunnel |
| 3 | `/api/v1/tunnel/status` | GET | Tunnel state + URL |
| 4 | `/api/v1/system/metrics` | GET | CPU/memory/disk/network snapshot |
| 5 | `/api/v1/system/metrics/live` | WS | Stream metrics (2s interval) |
| 6 | `/api/v1/system/processes` | GET | Process list |
| 7 | `/api/v1/system/files` | GET | Directory listing |
| 8 | `/api/v1/sessions/:id` | PUT | Rename session |

---

## Glossary

| Term | Definition |
|------|-----------|
| **Quick tunnel** | Free Cloudflare tunnel (`cloudflared tunnel --url`) with random `*.trycloudflare.com` subdomain. No account needed. Destroyed when process stops. |
| **Named tunnel** | Persistent Cloudflare tunnel with custom domain. Requires Cloudflare account + API token. |
| **System metrics** | CPU usage %, memory used/total, disk used/total, network bytes in/out — collected from OS APIs. |
| **Sparkline** | Miniature line chart showing recent trend (last 60 data points). Built with Swift Charts. |
| **Entity color** | Distinct color assigned to each data type (sessions=blue, projects=green, etc.) for visual differentiation. |
| **Skeleton loading** | Placeholder UI showing the shape of expected content with shimmer animation while data loads. |
| **SSE** | Server-Sent Events. One-way streaming for chat responses. |
| **WebSocket** | Bidirectional streaming for live system metrics. |
| **Tab bar** | Standard iOS bottom navigation with 5 persistent tabs. Replaces sidebar-as-sheet. |

---

## Out of Scope

- SSH provisioning wizard (deferred to future spec; Citadel stays in codebase)
- Process kill/signal from iOS (safety risk)
- File create/edit/delete from file browser (read-only)
- Light mode custom design (toggle works, but no custom light palette)
- Multi-backend simultaneous connections (single active connection)
- WebSocket chat (SSE is primary; WS handler stays for future)
- Permission handling (stub remains; real implementation needs interactive stdin)
- Ralph orchestrator sync (user must clarify repo URL)
- iPad-specific layouts (iPhone-first)
- Push notifications
- Localization / i18n
- App Store submission (separate effort)

---

## Dependencies

| Dependency | Type | Status | Notes |
|------------|------|--------|-------|
| `cloudflared` binary on backend host | External | User-installed | Backend checks for binary, shows install link if missing |
| Swift Charts (iOS 16+) | System Framework | Available | Native, no third-party needed |
| WebSocketService in backend | Internal | Exists | Extend for system metrics |
| CoreImage (CIQRCodeGenerator) | System Framework | Available | QR code for tunnel URL |
| Backend port 9090 | Config | Set | `PORT=9090 swift run ILSBackend` |
| Claude CLI on backend host | External | Required | For chat streaming |
| Dedicated simulator | Hardware | Available | iPhone 16 Pro Max, UDID `50523130-57AA-48B0-ABD0-4D59CE455F14` |
| Xcode 16+ | Tool | Required | Swift Charts, iOS 17 |

---

## Success Criteria

| Criteria | Measurement |
|----------|-------------|
| 13 validation scenarios pass | Screenshot evidence for each VS-1 through VS-13 |
| 8 new backend endpoints responding | cURL test for each returns correct JSON |
| Tab bar replaces sidebar sheet | All navigation via bottom tabs |
| Live system metrics streaming | Charts update visually every 2 seconds |
| Cloudflare tunnel starts and produces URL | URL accessible from external device |
| Zero silent failures | All errors show user-facing feedback |
| Zero hardcoded/fake data | No optimistic delays, no hardcoded categories |
| Entity colors applied | Each entity type visually distinct |
| Markdown renders in chat | Code blocks highlighted, lists formatted |
| Build succeeds without ClaudeCodeSDK | `swift build` clean after removal |

---

## Unresolved Questions

1. **Ralph orchestrator repo** — User referenced "pull down latest ralph orchestrator code." No such repo found in codebase or GitHub. Need URL or clarification.
2. **Cloudflare binary install** — Should backend auto-install `cloudflared` via `brew install cloudflared`, or just show instructions? Auto-install is invasive.
3. **File browser security boundary** — Restrict to `~/` or allow configurable root paths? `~/` is safest default.
4. **System metrics on Linux** — Backend uses macOS APIs (`host_processor_info`). If deployed on Linux, needs `/proc/*` fallback. Both or macOS-only for v1?
5. **Markdown rendering library** — Use `swift-markdown-ui` (third-party) or build custom AttributedString renderer? Third-party is faster but adds a dependency.
6. **Cost data accuracy** — Per-session cost comes from Claude CLI output. Is this reliably available for all sessions, or only completed ones?
7. **Tab bar item count** — 5 tabs (Dashboard, Sessions, Projects, System, Settings) is at the iOS limit. Should Skills/MCP/Plugins get their own tabs, or stay nested?

---

## Next Steps

1. Approve or amend these requirements
2. Create design.md with screen mockups for new views (System tab, redesigned Dashboard, tab bar layout, tunnel UI)
3. Create phased implementation plan (P0 first: tab bar + metrics + tunnel + fixes, then P1: polish + rendering)
4. Implement and validate scenario-by-scenario with screenshot evidence
