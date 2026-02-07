# Requirements: ILS iOS App — Functional Polish & UX Audit

## Goal

Fix every broken end-to-end flow in the ILS iOS app so that a user can launch the app, connect to a backend, create sessions, chat with Claude, manage MCP servers/skills/plugins, and browse external sessions — all validated with screenshot evidence across 13 real user scenarios.

## Architectural Decisions (Locked)

| # | Decision | Rationale |
|---|----------|-----------|
| AD-1 | **Projects: filesystem-only** | `~/.claude/projects/` is canonical. Remove DB-based project creation. Sessions link by directory path, not DB ID. |
| AD-2 | **SSH: remove entirely** | Zero user value. Remove views, Settings links, SSHConnectionManager. Re-add in future spec if needed. |
| AD-3 | **External sessions: merge into sessions list** | One unified list. External sessions marked with icon + "read-only" badge. Call `GET /sessions/scan` alongside `GET /sessions`. |
| AD-4 | **Plugin install: real git clone** | Backend SkillsController already has this pattern. Implement actual `git clone --depth 1` in PluginsController. |
| AD-5 | **Always-connected** | No offline/local mode. Graceful error states when disconnected. First-run onboarding prompts for server URL. |

---

## User Stories

### US-1: First Launch & Server Connection

**As a** new user
**I want to** be guided to enter my backend server URL on first launch
**So that** I can connect without hunting through Settings

**Acceptance Criteria:**
- [ ] AC-1.1: On first launch (no saved URL or connection fails), a modal sheet appears with URL input field, "Connect" button, and brief explanation
- [ ] AC-1.2: Entering a valid URL and tapping "Connect" calls `/health`, shows green success indicator, dismisses sheet
- [ ] AC-1.3: Invalid URL or unreachable server shows inline error message without dismissing sheet
- [ ] AC-1.4: After successful connection, Dashboard loads real stats from `GET /stats`
- [ ] AC-1.5: User can still change URL later in Settings > Backend Connection
- [ ] AC-1.6: "Test Connection" in Settings calls `/health` and shows connected/disconnected status

### US-2: Browse External Claude Code Sessions

**As a** user who uses Claude Code from terminal
**I want to** see my terminal sessions in the iOS app
**So that** I can review past conversations on mobile

**Acceptance Criteria:**
- [ ] AC-2.1: Sessions list calls both `GET /sessions` and `GET /sessions/scan`, merges results sorted by date
- [ ] AC-2.2: External sessions show a distinct icon/badge (e.g., terminal icon) in the list row
- [ ] AC-2.3: Tapping external session shows read-only transcript via `GET /sessions/transcript/:path/:id`
- [ ] AC-2.4: Read-only banner visible at bottom of chat view for external sessions
- [ ] AC-2.5: Input bar hidden or disabled for external sessions (no false affordance to type)
- [ ] AC-2.6: Pull-to-refresh re-scans external sessions

### US-3: Create Session & Chat End-to-End

**As a** user
**I want to** create a new session, send a message, and get a streamed response
**So that** I can chat with Claude from the iOS app

**Acceptance Criteria:**
- [ ] AC-3.1: Tapping "+" opens NewSessionView with name, model picker, and optional project picker
- [ ] AC-3.2: Project picker shows filesystem projects from `GET /projects` (not DB projects)
- [ ] AC-3.3: `POST /sessions` creates session; app auto-navigates to ChatView immediately
- [ ] AC-3.4: Typing message and tapping send calls `POST /chat/stream` with SSE
- [ ] AC-3.5: Streaming response renders incrementally with typing indicator
- [ ] AC-3.6: All form fields (systemPrompt, maxBudget, maxTurns, model, fallbackModel) sent to backend or stored for first message options
- [ ] AC-3.7: Empty message cannot be sent (send button disabled)

### US-4: Resume Existing Session

**As a** user
**I want to** continue a previous conversation
**So that** Claude has context from our earlier exchange

**Acceptance Criteria:**
- [ ] AC-4.1: Sessions list shows all ILS sessions with name, model, date, message count
- [ ] AC-4.2: Tapping session loads message history via `GET /sessions/:id/messages`
- [ ] AC-4.3: Sending new message uses `resume: true` with `claudeSessionId`
- [ ] AC-4.4: Claude responds with awareness of previous conversation context

### US-5: Cancel Active Stream

**As a** user
**I want to** stop a Claude response mid-stream
**So that** I can correct my prompt or abort a runaway response

**Acceptance Criteria:**
- [ ] AC-5.1: Stop button visible during active streaming
- [ ] AC-5.2: Tapping stop calls `POST /chat/cancel/:sessionId` on backend BEFORE cancelling local SSE connection
- [ ] AC-5.3: Backend terminates Claude CLI process
- [ ] AC-5.4: Partial response preserved in chat view
- [ ] AC-5.5: Input bar re-enabled after cancellation; user can send new message

### US-6: Fork Session

**As a** user
**I want to** fork a session to explore an alternative approach
**So that** I keep the original conversation intact

**Acceptance Criteria:**
- [ ] AC-6.1: Menu > Fork Session calls `POST /sessions/:id/fork`
- [ ] AC-6.2: Confirmation alert shows fork name
- [ ] AC-6.3: After fork, app auto-navigates to the new forked session
- [ ] AC-6.4: Forked session contains original message history
- [ ] AC-6.5: Original session remains unchanged

### US-7: MCP Server Management

**As a** user
**I want to** add, edit, and remove MCP servers from the iOS app
**So that** I can configure Claude's tool access without editing JSON files

**Acceptance Criteria:**
- [ ] AC-7.1: MCP Servers tab shows list from `GET /mcp`
- [ ] AC-7.2: "+" button opens form: name, command, args (array), env vars (key-value pairs)
- [ ] AC-7.3: `POST /mcp` creates server; list refreshes
- [ ] AC-7.4: Tapping existing server opens edit form; `PUT /mcp/:name` saves changes
- [ ] AC-7.5: Swipe-to-delete calls `DELETE /mcp/:name` with confirmation
- [ ] AC-7.6: Pull-to-refresh reloads list

### US-8: Plugin Management & Real Install

**As a** user
**I want to** install plugins from marketplace sources
**So that** I can extend Claude's capabilities

**Acceptance Criteria:**
- [ ] AC-8.1: Installed plugins list from `GET /plugins` with enable/disable toggles
- [ ] AC-8.2: Toggle calls `POST /plugins/:name/enable` or `/disable`
- [ ] AC-8.3: Marketplace view shows available plugins from registered sources
- [ ] AC-8.4: "Install" button calls `POST /plugins/install` which performs real `git clone --depth 1`
- [ ] AC-8.5: Newly installed plugin appears in installed list after refresh
- [ ] AC-8.6: Swipe-to-delete calls `DELETE /plugins/:name` with confirmation
- [ ] AC-8.7: Marketplace search searches marketplace sources, not installed plugins
- [ ] AC-8.8: "Add Source" registers a new marketplace URL via `POST /plugins/marketplaces`

### US-9: Skill Discovery & Management

**As a** user
**I want to** browse, search, install, and view skills
**So that** I can add specialized capabilities to Claude

**Acceptance Criteria:**
- [ ] AC-9.1: Skills list shows installed skills from `GET /skills`
- [ ] AC-9.2: Tapping skill opens detail view showing name, description, content preview via `GET /skills/:name`
- [ ] AC-9.3: Search bar triggers `GET /skills/search?q=` for GitHub skill search
- [ ] AC-9.4: Search results show installable skills with "Install" button
- [ ] AC-9.5: Install calls `POST /skills/install` (GitHub clone)
- [ ] AC-9.6: Swipe-to-delete calls `DELETE /skills/:name` with confirmation
- [ ] AC-9.7: Pull-to-refresh reloads skills list

### US-10: Projects & Project Sessions

**As a** user
**I want to** see my Claude Code projects and their associated sessions
**So that** I can organize work by project

**Acceptance Criteria:**
- [ ] AC-10.1: Projects list shows filesystem projects from `GET /projects` (directory-based)
- [ ] AC-10.2: No "Create Project" button (projects created via filesystem, not app)
- [ ] AC-10.3: Tapping project shows detail: path, description, session count
- [ ] AC-10.4: Project detail shows sessions filtered to that project via `GET /projects/:id/sessions`
- [ ] AC-10.5: "New Session in Project" pre-selects that project in NewSessionView
- [ ] AC-10.6: Project IDs are stable across requests (deterministic from path, not random UUID)

### US-11: Dashboard with Recent Activity

**As a** user
**I want to** see a dashboard with stats and recent sessions
**So that** I get an overview of my Claude Code usage

**Acceptance Criteria:**
- [ ] AC-11.1: Dashboard shows counts from `GET /stats` (projects, sessions, skills, plugins, MCP servers)
- [ ] AC-11.2: Recent sessions section populated from `GET /stats/recent`
- [ ] AC-11.3: Tapping a recent session navigates to ChatView
- [ ] AC-11.4: Dashboard refreshes on appear and pull-to-refresh

### US-12: Settings Cleanup

**As a** user
**I want to** see a clean, non-redundant Settings page
**So that** I can configure the app without confusion

**Acceptance Criteria:**
- [ ] AC-12.1: SSH Connections section removed entirely
- [ ] AC-12.2: Fleet Management section removed entirely
- [ ] AC-12.3: "Quick Settings" and "General" merged into single section (no duplicate model picker)
- [ ] AC-12.4: ConfigProfiles/Overrides/History views removed (showed mock data)
- [ ] AC-12.5: Config Management section removed or replaced with raw JSON editor only
- [ ] AC-12.6: Model picker saves via `PUT /config`
- [ ] AC-12.7: Server URL change shows confirmation dialog before applying

### US-13: Consistent Error & Empty States

**As a** user
**I want to** see clear, consistent messaging when things are empty or broken
**So that** I know what to do next

**Acceptance Criteria:**
- [ ] AC-13.1: All list views use consistent empty state component (same style, icon, message)
- [ ] AC-13.2: Disconnected state shows actionable message: "Not connected. Go to Settings to configure server URL."
- [ ] AC-13.3: Network errors show user-friendly message, not raw error strings
- [ ] AC-13.4: Loading states show spinner/skeleton consistently across all views

---

## Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-1 | First-run onboarding shows server URL modal | P0 | AC-1.1 through AC-1.3 |
| FR-2 | Sessions list merges DB + external sessions | P0 | AC-2.1, AC-2.2 |
| FR-3 | Session creation auto-navigates to ChatView | P0 | AC-3.3 |
| FR-4 | NewSessionView sends all form fields to backend | P0 | AC-3.6 |
| FR-5 | Chat cancel calls `POST /chat/cancel/:sessionId` | P0 | AC-5.2, AC-5.3 |
| FR-6 | Plugin install performs real git clone | P0 | AC-8.4, AC-8.5 |
| FR-7 | Projects use filesystem only; remove DB create | P0 | AC-10.1, AC-10.2, AC-10.6 |
| FR-8 | External sessions render as read-only transcript | P1 | AC-2.3 through AC-2.5 |
| FR-9 | MCP server add/edit/delete UI | P1 | AC-7.2 through AC-7.5 |
| FR-10 | Skill detail view | P1 | AC-9.2 |
| FR-11 | Skill search + install from GitHub | P1 | AC-9.3 through AC-9.5 |
| FR-12 | Dashboard recent sessions | P1 | AC-11.2, AC-11.3 |
| FR-13 | Fork auto-navigates to new session | P1 | AC-6.3 |
| FR-14 | Remove SSH views + Settings sections | P1 | AC-12.1, AC-12.2 |
| FR-15 | Remove mock/stub views (ConfigProfiles, Overrides, History, Fleet) | P1 | AC-12.4, AC-12.5 |
| FR-16 | Merge Quick Settings into General section | P2 | AC-12.3 |
| FR-17 | Marketplace search hits correct endpoint | P2 | AC-8.7 |
| FR-18 | Consistent empty states across all views | P2 | AC-13.1 through AC-13.4 |
| FR-19 | Server URL change confirmation dialog | P2 | AC-12.7 |
| FR-20 | Project detail shows filtered sessions | P2 | AC-10.4, AC-10.5 |

## Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-1 | App launch to connected dashboard | Time | < 3 seconds on local network |
| NFR-2 | Session list load (DB + scan merge) | Time | < 2 seconds for 100 sessions |
| NFR-3 | Chat streaming first token | Time | < 5 seconds after send (network dependent) |
| NFR-4 | Pull-to-refresh on all list views | Consistency | 100% of list views support it |
| NFR-5 | Error messages are user-friendly | Quality | No raw HTTP codes, no stack traces, no "Error: ..." prefixes |
| NFR-6 | No dead-end navigation | UX | Every tappable element leads to real content or shows clear empty state |
| NFR-7 | Backend endpoint coverage | Utilization | 38+ of 48 endpoints called by iOS (up from 22) |

---

## 13 User Scenarios as Acceptance Tests

Each scenario is a complete E2E flow validated by screenshot evidence on the dedicated simulator (iPhone 16 Pro Max, UDID: `50523130-57AA-48B0-ABD0-4D59CE455F14`).

### S-01: First Launch & Server Setup
**Endpoints**: `/health`, `GET /stats`, `GET /config?scope=user`

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | Fresh install, open app | Onboarding modal appears with URL field | s01-onboarding.png |
| 2 | Enter `http://localhost:9090`, tap Connect | Green "Connected" indicator, modal dismisses | s01-connected.png |
| 3 | View Dashboard | Real stats (project count, session count, etc.) | s01-dashboard.png |

### S-02: Browse External Claude Code Sessions
**Endpoints**: `GET /sessions`, `GET /sessions/scan`, `GET /sessions/transcript/:path/:id`

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | Open Sessions tab | Merged list: ILS + external sessions | s02-sessions-list.png |
| 2 | Identify external session | Terminal icon + "read-only" badge visible | s02-external-badge.png |
| 3 | Tap external session | Read-only transcript loads, banner at bottom | s02-readonly-transcript.png |
| 4 | Verify input bar | Input bar hidden or disabled | s02-no-input.png |

### S-03: Create New Session & Chat
**Endpoints**: `POST /sessions`, `POST /chat/stream`, `GET /sessions/:id/messages`

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | Tap "+" | NewSessionView opens | s03-new-session.png |
| 2 | Set name, pick model, select project | Form populated with filesystem projects | s03-form-filled.png |
| 3 | Tap Create | ChatView opens automatically | s03-chat-view.png |
| 4 | Type "Hello, what can you do?" | Message appears in chat | s03-message-sent.png |
| 5 | Wait for response | Streaming response renders incrementally | s03-streaming.png |
| 6 | Response complete | Full response visible, input re-enabled | s03-response-complete.png |

### S-04: Chat in Multiple Projects
**Endpoints**: `GET /projects`, `POST /sessions` (x2), `POST /chat/stream` (x2)

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | Create session in Project A | Session created, chat opens | s04-project-a-chat.png |
| 2 | Send message in Project A | Response received | s04-project-a-response.png |
| 3 | Go back, create session in Project B | Second session created | s04-project-b-chat.png |
| 4 | Send message in Project B | Independent response (no cross-contamination) | s04-project-b-response.png |

### S-05: Resume Existing Session
**Endpoints**: `GET /sessions`, `GET /sessions/:id/messages`, `POST /chat/stream` (resume)

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | Open Sessions, tap existing session | Message history loaded | s05-history.png |
| 2 | Send follow-up message | Claude responds with context of prior conversation | s05-resumed.png |

### S-06: Fork & Experiment
**Endpoints**: `POST /sessions/:id/fork`, `POST /chat/stream`

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | In active session, tap menu > Fork | Confirmation alert with fork name | s06-fork-alert.png |
| 2 | Confirm fork | Auto-navigates to forked session with history | s06-forked-session.png |
| 3 | Send different message | Response in forked context | s06-forked-chat.png |

### S-07: MCP Server Management
**Endpoints**: `GET /mcp`, `POST /mcp`, `PUT /mcp/:name`, `DELETE /mcp/:name`

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | Open MCP Servers tab | List of configured servers | s07-mcp-list.png |
| 2 | Tap "+" | Add form: name, command, args, env | s07-mcp-add-form.png |
| 3 | Fill form, tap Save | Server appears in list | s07-mcp-added.png |
| 4 | Tap existing server | Edit form with current values | s07-mcp-edit.png |
| 5 | Swipe to delete | Confirmation, server removed | s07-mcp-deleted.png |

### S-08: Settings Configuration
**Endpoints**: `GET /config?scope=user`, `PUT /config`, `GET /stats`, `GET /health`

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | Open Settings | Clean layout, no SSH/Fleet/mock sections | s08-settings.png |
| 2 | Change default model | Model picker updates | s08-model-change.png |
| 3 | Save | `PUT /config` succeeds | s08-saved.png |
| 4 | Scroll to About | Claude version from `/health` | s08-about.png |

### S-09: Plugin Management
**Endpoints**: `GET /plugins`, `POST /plugins/:name/enable`, `POST /plugins/:name/disable`, `DELETE /plugins/:name`, `GET /plugins/marketplace`, `POST /plugins/install`

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | Open Plugins tab | Installed plugins list | s09-plugins-list.png |
| 2 | Toggle a plugin off | Disable call succeeds, visual update | s09-plugin-disabled.png |
| 3 | Open Marketplace | Available plugins shown | s09-marketplace.png |
| 4 | Tap Install on a plugin | Real install (git clone), plugin appears in list | s09-installed.png |
| 5 | Swipe to delete plugin | Confirmation, plugin removed | s09-deleted.png |

### S-10: Skill Discovery & Install
**Endpoints**: `GET /skills`, `GET /skills/search?q=`, `POST /skills/install`, `GET /skills/:name`, `DELETE /skills/:name`

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | Open Skills tab | Installed skills list | s10-skills-list.png |
| 2 | Tap a skill | Detail view with name, description, content | s10-skill-detail.png |
| 3 | Search for skill | GitHub search results | s10-search-results.png |
| 4 | Install a skill | Clone completes, skill in list | s10-installed.png |
| 5 | Delete a skill | Swipe, confirm, removed | s10-deleted.png |

### S-11: Projects & Project Sessions
**Endpoints**: `GET /projects`, `GET /projects/:id`, `GET /projects/:id/sessions`

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | Open Projects tab | Filesystem projects listed (stable IDs) | s11-projects-list.png |
| 2 | Tap a project | Detail: path, description, session count | s11-project-detail.png |
| 3 | View project sessions | Sessions filtered to this project | s11-project-sessions.png |
| 4 | Tap "New Session" in project | NewSessionView with project pre-selected | s11-new-session-in-project.png |

### S-12: Config Management
**Endpoints**: `GET /config?scope=user`, `GET /config?scope=project`, `PUT /config`

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | Open Settings > Configuration | Raw JSON editor for user config | s12-config-editor.png |
| 2 | Edit a value | Change persists via `PUT /config` | s12-config-saved.png |
| 3 | Switch to project scope | Project config loads | s12-project-config.png |

### S-13: Cancel Active Stream
**Endpoints**: `POST /chat/stream`, `POST /chat/cancel/:sessionId`

| Step | Action | Expected | Screenshot |
|------|--------|----------|------------|
| 1 | Send message, streaming starts | Typing indicator + stop button visible | s13-streaming.png |
| 2 | Tap stop button | Cancel endpoint called, stream stops | s13-cancelled.png |
| 3 | Verify recovery | Partial response preserved, input re-enabled | s13-recovered.png |

---

## Endpoint Coverage Matrix

After implementation, the following endpoints must be called by iOS:

| # | Endpoint | Called Today? | Required by Scenario |
|---|----------|---------------|---------------------|
| 1 | `GET /health` | YES | S-01 |
| 2 | `GET /sessions` | YES | S-02, S-05 |
| 3 | `POST /sessions` | YES | S-03, S-04 |
| 4 | `GET /sessions/scan` | **NO -> YES** | S-02 |
| 5 | `GET /sessions/:id` | **NO -> YES** | S-05 |
| 6 | `DELETE /sessions/:id` | YES | — |
| 7 | `POST /sessions/:id/fork` | YES | S-06 |
| 8 | `GET /sessions/:id/messages` | YES | S-03, S-05 |
| 9 | `GET /sessions/transcript/:path/:id` | YES | S-02 |
| 10 | `POST /chat/stream` | YES | S-03, S-04, S-05, S-13 |
| 11 | `POST /chat/cancel/:sessionId` | **NO -> YES** | S-13 |
| 12 | `GET /projects` | YES | S-03, S-11 |
| 13 | `GET /projects/:id` | **NO -> YES** | S-11 |
| 14 | `GET /projects/:id/sessions` | **NO -> YES** | S-11 |
| 15 | `GET /skills` | YES | S-10 |
| 16 | `GET /skills/:name` | **NO -> YES** | S-10 |
| 17 | `GET /skills/search?q=` | **NO -> YES** | S-10 |
| 18 | `POST /skills/install` | **NO -> YES** | S-10 |
| 19 | `DELETE /skills/:name` | **NO -> YES** | S-10 |
| 20 | `GET /mcp` | YES | S-07 |
| 21 | `GET /mcp/:name` | **NO -> YES** | S-07 |
| 22 | `POST /mcp` | **NO -> YES** | S-07 |
| 23 | `PUT /mcp/:name` | **NO -> YES** | S-07 |
| 24 | `DELETE /mcp/:name` | **NO -> YES** | S-07 |
| 25 | `GET /plugins` | YES | S-09 |
| 26 | `GET /plugins/marketplace` | YES | S-09 |
| 27 | `POST /plugins/install` | YES (stub) -> **REAL** | S-09 |
| 28 | `POST /plugins/:name/enable` | YES | S-09 |
| 29 | `POST /plugins/:name/disable` | YES | S-09 |
| 30 | `DELETE /plugins/:name` | YES | S-09 |
| 31 | `POST /plugins/marketplaces` | YES | S-09 |
| 32 | `GET /stats` | YES | S-01, S-08 |
| 33 | `GET /stats/recent` | **NO -> YES** | S-01 |
| 34 | `GET /config?scope=user` | YES | S-08, S-12 |
| 35 | `GET /config?scope=project` | **NO -> YES** | S-12 |
| 36 | `PUT /config` | YES | S-08, S-12 |

**Result: 36 of 48 endpoints exercised (75%, up from 46%)**

Intentionally excluded (12):
- `WS /chat/ws/:sessionId` — WebSocket unused by design (SSE chosen)
- `POST /chat/permission/:requestId` — Permission system deferred
- `POST /projects` — Removed per AD-1 (filesystem-only)
- `PUT /projects/:id` — Filesystem projects not editable from app
- `DELETE /projects/:id` — Filesystem projects not deletable from app
- `POST /skills` — Create via install, not manual creation
- `PUT /skills/:name` — Edit not in scope
- `GET /plugins/search` — Replaced by marketplace search
- `GET /settings` — Raw settings.json not exposed to user
- `GET /server/status` — SSH removed per AD-2
- `POST /auth/connect` — SSH removed per AD-2
- `POST /auth/disconnect` — SSH removed per AD-2

---

## Glossary

- **External session**: A Claude Code session created in terminal (not via ILS app). Stored as JSONL transcript in `~/.claude/projects/`. Read-only in ILS.
- **ILS session**: A session created via the ILS app. Stored in SQLite DB. Supports active chat.
- **Filesystem project**: A directory under `~/.claude/projects/` representing a Claude Code project. The canonical source of truth for projects.
- **MCP server**: A Model Context Protocol server providing tools to Claude (e.g., filesystem, database, web search).
- **Marketplace source**: A GitHub URL or registry that lists available plugins for installation.
- **SSE**: Server-Sent Events. The streaming protocol used for real-time chat responses.

## Out of Scope

- SSH connections and remote server management (removed per AD-2)
- Offline/local-only mode (always-connected per AD-5)
- WebSocket chat (SSE is the chosen protocol)
- Message deletion within sessions
- Config validation endpoint (`POST /config/validate`)
- Permission handling for Claude tool use
- Plugin categorization/tagging system
- Project creation from iOS (filesystem-only per AD-1)
- Project editing/deletion from iOS
- Skill creation/editing from iOS (only install/delete)
- Config profiles, overrides, history views (removed — showed mock data)
- Fleet management view (removed — showed mock data)

## Dependencies

- Backend running on port 9090 with `PORT=9090 swift run ILSBackend`
- Claude CLI installed on backend host (required for `POST /chat/stream`)
- `~/.claude/projects/` directory exists with at least one project (for external session scenarios)
- Dedicated simulator: iPhone 16 Pro Max, UDID `50523130-57AA-48B0-ABD0-4D59CE455F14`
- Xcode build succeeds for both backend (`swift build`) and iOS app (`xcodebuild`)

## Success Criteria

All 13 scenarios (S-01 through S-13) must:
1. Complete without errors or crashes
2. Exercise the documented endpoints (verified via backend logs or network inspection)
3. Produce screenshot evidence at each step
4. Screenshots reviewed and confirmed to show expected behavior

Quantitative targets:
- **13/13 scenarios pass** with screenshot evidence
- **36+ of 48 backend endpoints** called by iOS client
- **Zero dead-end navigations** — every tappable element leads to real content
- **Zero mock/stub data** displayed anywhere in the app
- **Consistent empty states** across all list views

---

## Unresolved Questions

1. **Project ID stability** — Research says filesystem projects get random UUIDs per request. Backend needs to generate deterministic IDs (e.g., hash of path) for session-project linking to work. Needs backend change.
2. **Plugin install error handling** — What happens if git clone fails mid-install? Should show error inline? Retry button?
3. **Marketplace data source** — Current marketplace list is hardcoded in backend. Where do real marketplace entries come from? For now, "Add Source" (GitHub URL) may be sufficient.
4. **Session-project linking for filesystem projects** — If projects use deterministic IDs from path, how are existing DB sessions linked? May need migration or just accept orphaned sessions.
5. **External session date sorting** — `GET /sessions/scan` returns sessions with filesystem timestamps. Are these reliably sortable alongside DB session `createdAt` dates?

## Next Steps

1. Approve or amend these requirements
2. Create design.md with UI wireframes for new views (onboarding, MCP CRUD, skill detail, skill search)
3. Create implementation plan phased by priority (P0 first, then P1, then P2)
4. Implement and validate scenario-by-scenario with screenshot evidence
