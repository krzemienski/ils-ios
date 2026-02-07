---
spec: ils-complete-rebuild
phase: requirements
created: 2026-02-05T23:05:00-05:00
---

# Requirements: ILS Complete Rebuild

## Goal

Bring the ILS iOS app to full compliance with both spec documents (ils-spec.md, ils.md) by closing all feature gaps, aligning the design system, and implementing missing API endpoints — while preserving the high-value beyond-spec features (chat/SSE streaming, sessions, projects) already validated and working.

## User Decisions

| Question | Decision |
|----------|----------|
| Primary users | End users via App Store — needs polish, onboarding, App Store compliance |
| Priority tradeoffs | Feature completeness — all spec features working |
| Success criteria | Full spec compliance — every feature, endpoint, screen from both spec docs implemented and working |
| Architecture | **Hybrid REST+SSH** — User installs Vapor backend on their server. iOS app connects via REST for most operations. SSH used alongside REST for file editing, diffs, stats, and direct server access. SSH setup also enables the backend server connection. Future: dynamic Cloudflare URLs for remote access |
| Color tokens | **Spec custom** (#FF6B35, #0D0D0D, etc.) — NOT Apple system colors |
| GitHub API token | **Yes, server-side** — Backend env var (`GITHUB_TOKEN`). Indexes GitHub for skills/plugins. Users discover + install from app. No per-user token needed |
| Navigation | **Sidebar** as primary navigation (NOT tab bar). See Stitch designs as source of truth |
| Chat/Sessions placement | Accessible via **sidebar** and from within views (e.g., project detail → session). NOT a dedicated tab |
| Enterprise/managed scope | **No** — not for v1, deferred |
| Design source of truth | **Stitch MCP project "ILS Dashboard"** (ID: 6714718863820708466) — 15 screens |

### Stitch MCP Design Reference (15 Screens)

| # | Screen ID | Title |
|---|-----------|-------|
| 1 | `25aed8120fe4488d9ad5ac8433ac4b42` | ILS Dashboard |
| 2 | `d184411ba94f43c69b90f2747ab47ac7` | ILS Chat Sessions List |
| 3 | `e50b50c05cc045069ab1e0c202dc89fb` | ILS AI Chat Interface |
| 4 | `847d8c88eb9046ad8de99b9bce64bbaa` | Projects List |
| 5 | `27a3b7233cfa4b0692f0c07d6d370f5c` | ILS AI Skills Library |
| 6 | `a9acdbf1bcb647ea9bf5e3b6339ee4e4` | MCP Servers List |
| 7 | `aa5f210b40f04369a602fd33ba6b29a4` | ILS Plugin Manager |
| 8 | `16ee91c1c662404baf56bb5d710aba14` | ILS App Settings |
| 9 | `32e13751fdfb4c898f48c9be5a5f1aff` | New Session Modal |
| 10 | `9c83a0bf962140f48ce11e6f52ccd7b0` | Session Information Details |
| 11 | `5556ce4f5c5e48cda95cf285c97f5b4b` | Command Palette Modal |
| 12 | `7e7bbafdd39e4fe6a152e2e3e4454fe9` | ILS Sidebar Navigation |
| 13 | `896d9c0cf3c3458fa51365a932912a45` | Project Details and Edit |
| 14 | `46398039370944a488f6d15bb810478f` | Plugin Marketplace Modal |
| 15 | `cda568a2f4a347e786a1be977683323e` | Skill Detail View |

**Design theme**: Dark mode, #FF6600 accent, Inter font, round-12 corners, saturation 3

---

## User Stories

### Server Connection & Authentication

#### US-1: Connect to Remote Server via SSH
**As a** user managing Claude Code on a remote server
**I want to** enter SSH credentials (host, port, username, auth method) and connect
**So that** I can manage Claude Code installations on remote machines

**Acceptance Criteria:**
- [ ] AC-1.1: ServerConnectionView displays form with host, port (default 22), username, auth method toggle (password/SSH key)
- [ ] AC-1.2: Password auth sends credentials via `POST /auth/connect` and receives session token
- [ ] AC-1.3: SSH key auth allows selecting a key file from device storage
- [ ] AC-1.4: Connect button shows loading state, disables during connection attempt
- [ ] AC-1.5: Successful connection navigates to Dashboard with green connection indicator
- [ ] AC-1.6: Failed connection shows error message with retry option
- [ ] AC-1.7: Recent Connections list persists across app launches (max 10, sorted by lastConnected)

#### US-2: View Connection Status
**As a** connected user
**I want to** see server health status in the navigation bar
**So that** I know if my connection is active

**Acceptance Criteria:**
- [ ] AC-2.1: Green dot indicator when connected and healthy
- [ ] AC-2.2: Red dot when connection lost or server error
- [ ] AC-2.3: `GET /server/status` polled every 30 seconds
- [ ] AC-2.4: Automatic reconnection attempt on connection loss (3 retries, exponential backoff)

### Dashboard & Navigation

#### US-3: View Dashboard with Stats and Quick Actions
**As a** user on the Dashboard
**I want to** see resource counts, quick action shortcuts, and recent activity
**So that** I can quickly navigate to common tasks and monitor my setup

**Acceptance Criteria:**
- [ ] AC-3.1: Three stat cards showing Skills (total/active), MCP Servers (total/healthy), Plugins (total/enabled)
- [ ] AC-3.2: Quick Actions list with 4 items: Discover Skills, Browse Plugins, Configure MCP, Edit Settings — each navigates to respective screen
- [ ] AC-3.3: Recent Activity feed showing last 10 install/update/delete events with timestamp
- [ ] AC-3.4: Stats load from `GET /stats` on appear and pull-to-refresh
- [ ] AC-3.5: Stat cards show accent orange highlight on count values

#### US-4: Navigate via Tab Bar
**As a** user
**I want to** switch between main sections via bottom tab bar
**So that** I can quickly access Home, Skills, MCPs, and Discover sections

**Acceptance Criteria:**
- [ ] AC-4.1: Bottom tab bar with 4 tabs: Home, Skills, MCPs, Discover (per spec wireframe 2)
- [ ] AC-4.2: Tab icons use SF Symbols consistent with feature purpose
- [ ] AC-4.3: Active tab uses accent.primary color, inactive uses text.tertiary
- [ ] AC-4.4: Existing sidebar navigation preserved as supplementary navigation (accessible via toolbar button)

### Skills Management

#### US-5: Browse Installed Skills
**As a** user
**I want to** see all locally installed Claude Code skills with status indicators
**So that** I can manage my skill library

**Acceptance Criteria:**
- [ ] AC-5.1: List shows each skill with name, description, version, Active/Disabled badge
- [ ] AC-5.2: Skills load from `GET /skills`
- [ ] AC-5.3: Pull-to-refresh reloads the list
- [ ] AC-5.4: Tapping a skill navigates to SkillDetailView
- [ ] AC-5.5: Overflow menu (three-dot) per skill for quick actions (disable, delete)

#### US-6: Search GitHub for Skills
**As a** user
**I want to** search GitHub for SKILL.md files and discover new skills
**So that** I can expand my Claude Code capabilities

**Acceptance Criteria:**
- [ ] AC-6.1: Search bar at bottom of skills list with accent border on focus
- [ ] AC-6.2: Typing triggers debounced search (300ms) via `GET /skills/search?q={query}`
- [ ] AC-6.3: Results show in "Discovered from GitHub" section with repo name, description, star count
- [ ] AC-6.4: Each result has an orange "Install" button
- [ ] AC-6.5: Empty state when no results found

#### US-7: Install Skill from GitHub
**As a** user viewing a GitHub skill search result
**I want to** install it with one tap
**So that** the skill becomes available in my Claude Code setup

**Acceptance Criteria:**
- [ ] AC-7.1: Tapping Install sends `POST /skills/install` with repository and skillPath
- [ ] AC-7.2: Button shows loading spinner during install
- [ ] AC-7.3: Success transitions button to "Installed" (muted/disabled style)
- [ ] AC-7.4: Skill appears in Installed Skills section after install
- [ ] AC-7.5: Error displays inline alert with message

#### US-8: View Skill Details
**As a** user
**I want to** see full skill information including SKILL.md preview
**So that** I can understand what the skill does and manage it

**Acceptance Criteria:**
- [ ] AC-8.1: SkillDetailView shows: icon, name, version, author, star count, last updated
- [ ] AC-8.2: Description section with full text
- [ ] AC-8.3: SKILL.md Preview section with syntax-highlighted YAML frontmatter + markdown content
- [ ] AC-8.4: "Uninstall" button (red destructive style) calls `DELETE /skills/{id}`
- [ ] AC-8.5: "Edit SKILL.md" button (secondary style) opens editable text view
- [ ] AC-8.6: Save edits via `PUT /skills/{id}`
- [ ] AC-8.7: Confirmation dialog before uninstall

### MCP Server Management

#### US-9: Browse MCP Servers by Scope
**As a** user
**I want to** see MCP servers filtered by scope (User/Project/Local)
**So that** I can manage configurations at the right level

**Acceptance Criteria:**
- [ ] AC-9.1: Scope tabs at top: User, Project, Local — with accent orange underline on active tab
- [ ] AC-9.2: Tab selection filters via `GET /mcp?scope={scope}`
- [ ] AC-9.3: Each server card shows: status dot (green=healthy, red=error), name, command with args, action buttons
- [ ] AC-9.4: Error servers show error message and "Retry" button
- [ ] AC-9.5: Env vars displayed with values masked (show *** for sensitive values)

#### US-10: Add New MCP Server
**As a** user
**I want to** add a new MCP server via form (From Registry or Custom Command)
**So that** I can extend Claude Code's capabilities

**Acceptance Criteria:**
- [ ] AC-10.1: "Add" button in navigation bar opens Add Server form
- [ ] AC-10.2: Radio toggle: "From Registry" vs "Custom Command"
- [ ] AC-10.3: Custom Command form: name, command, args (comma-separated), env key-value pairs, scope picker
- [ ] AC-10.4: Submit sends `POST /mcp` with scope
- [ ] AC-10.5: New server appears in list after creation
- [ ] AC-10.6: Form validation: name and command required

#### US-11: Edit and Delete MCP Servers
**As a** user
**I want to** modify or remove existing MCP server configurations
**So that** I can keep my setup current

**Acceptance Criteria:**
- [ ] AC-11.1: "Edit" button per server opens pre-filled form
- [ ] AC-11.2: Save sends `PUT /mcp/{name}`
- [ ] AC-11.3: "Delete" button shows confirmation, then sends `DELETE /mcp/{name}`
- [ ] AC-11.4: "Disable" toggles server without deleting (removes from active config)
- [ ] AC-11.5: Optimistic UI update with rollback on error

### Plugin Marketplace

#### US-12: Browse Plugin Marketplace
**As a** user
**I want to** browse available plugins across marketplaces with categories
**So that** I can discover and install useful plugins

**Acceptance Criteria:**
- [ ] AC-12.1: Search bar at top with placeholder "Search plugins..."
- [ ] AC-12.2: Category filter chips: All, Productivity, DevOps, Testing, Documentation
- [ ] AC-12.3: Official Marketplace section lists plugins from `GET /plugins/marketplace`
- [ ] AC-12.4: Each plugin card shows: name, description, star count, source badge (Official/Community)
- [ ] AC-12.5: Install button (accent orange) for uninstalled plugins
- [ ] AC-12.6: "Installed" badge (muted) for already-installed plugins
- [ ] AC-12.7: Search filters via `GET /plugins/search?q={query}`

#### US-13: Install Plugin from Marketplace
**As a** user
**I want to** install a plugin with one tap
**So that** it becomes active in my Claude Code setup

**Acceptance Criteria:**
- [ ] AC-13.1: Tapping Install sends `POST /plugins/install` with pluginName, marketplace, scope
- [ ] AC-13.2: Loading state on button during install
- [ ] AC-13.3: Success transitions to "Installed" badge
- [ ] AC-13.4: Plugin appears in installed list on Plugins tab

#### US-14: Add Custom Marketplace
**As a** user
**I want to** add a custom plugin marketplace from a GitHub repo
**So that** I can access community plugin collections

**Acceptance Criteria:**
- [ ] AC-14.1: "Add from GitHub repo" button at bottom of marketplace view
- [ ] AC-14.2: Input field for GitHub repo path (owner/repo format)
- [ ] AC-14.3: Submit sends `POST /marketplaces` with source and repo
- [ ] AC-14.4: New marketplace section appears with its plugins listed
- [ ] AC-14.5: Validation: repo must match `owner/repo` pattern

### Settings & Configuration

#### US-15: Edit Claude Config with JSON Editor
**As a** user
**I want to** directly edit Claude Code configuration JSON with validation
**So that** I can fine-tune settings not exposed as toggles

**Acceptance Criteria:**
- [ ] AC-15.1: Scope dropdown at top: User, Project, Local — loads from `GET /config?scope={scope}`
- [ ] AC-15.2: JSON text editor with monospace font displaying current config content
- [ ] AC-15.3: Real-time syntax validation indicator: green checkmark "Valid JSON" or red X with error description
- [ ] AC-15.4: "Save Changes" button (accent orange) sends `PUT /config` with scope and content
- [ ] AC-15.5: Validation calls `POST /config/validate` before save
- [ ] AC-15.6: Unsaved changes warning on navigate away

#### US-16: Use Quick Settings Toggles
**As a** user
**I want to** toggle common settings without editing raw JSON
**So that** I can quickly adjust model, thinking mode, and attribution

**Acceptance Criteria:**
- [ ] AC-16.1: Quick Settings section below JSON editor
- [ ] AC-16.2: Model picker dropdown (claude-sonnet-4, claude-opus-4, etc.)
- [ ] AC-16.3: Extended Thinking toggle (on/off)
- [ ] AC-16.4: Co-authored-by toggle (on/off)
- [ ] AC-16.5: Changes via Quick Settings update the JSON editor content in real-time
- [ ] AC-16.6: Changes persist only when "Save Changes" is tapped

### Chat & Sessions (Preserve Existing)

#### US-17: Preserve Chat Session System
**As a** user
**I want to** continue using the existing chat, session, and project features
**So that** the high-value beyond-spec functionality remains available

**Acceptance Criteria:**
- [ ] AC-17.1: SessionsListView, ChatView, CommandPaletteView, MessageView unchanged
- [ ] AC-17.2: SSE streaming with Claude CLI subprocess continues working
- [ ] AC-17.3: Session CRUD (create, list, fork, delete) unchanged
- [ ] AC-17.4: Project management (CRUD, session listing per project) unchanged
- [ ] AC-17.5: External session discovery from sessions-index.json unchanged
- [ ] AC-17.6: Permission handling during chat unchanged
- [ ] AC-17.7: WebSocket support unchanged

### Design System Compliance

#### US-18: Align Design Tokens to Spec
**As a** user
**I want to** see a polished, consistent dark theme matching the spec's design system
**So that** the app feels professional and cohesive

**Acceptance Criteria:**
- [ ] AC-18.1: All 15 color tokens match spec values (or deliberate Apple system color decision documented)
- [ ] AC-18.2: accent.primary = `#FF6B35`, accent.secondary = `#FF8C5A`, accent.tertiary = `#FF4500`
- [ ] AC-18.3: Corner radius naming aligned: small=8pt, medium=12pt, large=16pt
- [ ] AC-18.4: Typography uses SF Pro Display Bold for headings, SF Pro Text Regular for body, SF Mono for code
- [ ] AC-18.5: All new screens match Stitch-generated designs

---

## Functional Requirements

### Backend API Endpoints

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-1 | `POST /auth/connect` — Accept SSH credentials, establish connection via Citadel, return session token + server info | P0 | cURL returns `{success: true, sessionId, serverInfo: {claudeInstalled, claudeVersion, configPaths}}` |
| FR-2 | `GET /server/status` — Return connection health, Claude version, uptime | P0 | cURL returns `{connected: true, claudeVersion: "x.y.z"}` when connected |
| FR-3 | `GET /skills/search?q={query}` — Search GitHub Code API for SKILL.md files | P1 | cURL with `?q=code-review` returns array of `GitHubSearchResult` with repository, stars, description |
| FR-4 | `POST /skills/install` — Clone skill from GitHub repo into `~/.claude/skills/` | P1 | cURL with `{repository, skillPath}` returns installed Skill object; file exists on disk |
| FR-5 | `PUT /mcp/{name}` — Update existing MCP server configuration | P1 | cURL with updated config returns modified server; config file updated on disk |
| FR-6 | `GET /plugins/search?q={query}` — Search across all registered marketplaces | P1 | cURL returns filtered plugin list matching query |
| FR-7 | `POST /marketplaces` — Register a custom marketplace from GitHub repo | P1 | cURL with `{source, repo}` returns new Marketplace object; persisted for future queries |
| FR-8 | `GET /skills/{id}` — Return single skill with full SKILL.md content | P1 | cURL returns complete Skill with rawContent populated |
| FR-9 | `PUT /skills/{id}` — Update skill content (edit SKILL.md) | P2 | cURL with updated content persists to disk |
| FR-10 | Preserve all existing endpoints: `/sessions/*`, `/chat/*`, `/projects/*`, `/stats/*`, `/config/*`, `/health` | P0 | All existing cURL tests continue passing |

### Backend Services

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-11 | `GitHubService.swift` — Search GitHub Code API (`GET https://api.github.com/search/code?q=SKILL.md+filename:SKILL.md`), parse results, fetch raw SKILL.md content | P1 | Service returns `[GitHubSearchResult]` from live GitHub API |
| FR-12 | `IndexingService.swift` — Cache discovered skills/plugins in SQLite with TTL; background refresh | P2 | Cached results returned within 50ms; stale cache refreshed automatically |
| FR-13 | SSH connectivity via Citadel — Execute remote commands, read/write remote files | P0 | Backend can run `claude --version` on remote host and return output |
| FR-14 | Preserve `FileSystemService`, `ClaudeExecutorService`, `StreamingService`, `WebSocketService` | P0 | All existing services continue functioning |

### iOS Views

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-15 | `ServerConnectionView` — SSH form matching spec wireframe 1 | P0 | Screenshot matches wireframe: host, port, user, auth toggle, key selector, Connect button, recent connections |
| FR-16 | `DashboardView` enhanced — Add Quick Actions list + Recent Activity feed per spec wireframe 2 | P1 | Screenshot shows stat cards + 4 quick action rows + activity feed |
| FR-17 | `SkillDetailView` — New view matching spec wireframe 4 | P1 | Screenshot shows skill header, description, SKILL.md preview, Uninstall + Edit buttons |
| FR-18 | `SkillsListView` enhanced — Add GitHub search bar + "Discovered from GitHub" section per wireframe 3 | P1 | Screenshot shows installed skills + search bar + GitHub results with Install buttons |
| FR-19 | `MCPServerListView` enhanced — Add scope tabs + Add/Edit/Delete forms per wireframe 5 | P1 | Screenshot shows scope tabs with orange active underline + server cards with action buttons |
| FR-20 | `PluginMarketplaceView` — Enhanced marketplace with search, categories, Install per wireframe 6 | P1 | Screenshot shows search, category chips, plugin cards with Install/Installed states |
| FR-21 | `SettingsView` enhanced — Raw JSON editor + Quick Settings per wireframe 7 | P1 | Screenshot shows scope picker, JSON editor, validation indicator, Quick Settings toggles |
| FR-22 | Preserve all existing views: Chat, Sessions, Projects, Sidebar, CommandPalette, MessageView | P0 | All 12 validated screens unchanged |

### iOS Services

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-23 | `SSHService.swift` — Citadel-based SSH client for iOS; connect, execute, SFTP read/write | P0 | Service connects to test host, executes command, returns stdout |
| FR-24 | `ConfigurationManager.swift` — Manage config lifecycle: load, validate, save, scope switching | P2 | Manager loads config for each scope; validates JSON; saves with rollback on error |
| FR-25 | Preserve `APIClient.swift` and `SSEClient.swift` | P0 | Existing networking unchanged |

### Data Models

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-26 | Add `ServerConnection.swift` to ILSShared — id, host, port, username, authMethod, label, lastConnected | P0 | Model compiles; Codable round-trip works |
| FR-27 | Add `SearchResult.swift` to ILSShared — `GitHubSearchResult`, `GitHubCodeSearchResponse`, `GitHubCodeItem`, `GitHubRepository`, `SkillInstallRequest`, `PluginInstallRequest`, `MCPServerCreateRequest` | P1 | All DTOs compile; JSON decode from GitHub API responses works |
| FR-28 | Align `MCPServer.swift` — Add `ConfigScope` enum (user/project/local/managed), `MCPConfiguration` wrapper, `MCPServerDefinition` | P1 | Model matches spec; existing list/create still works |
| FR-29 | Align `Skill.swift` — Add `rawContent: String`, update `SkillSource` to enum with associated values (`.github(repository:stars:)`), add `SkillParser` with Yams | P1 | SKILL.md YAML frontmatter parses correctly |
| FR-30 | Align `Plugin.swift` — Add `stars: Int?`, `PluginSource` enum with `.community(repository:)`, add `Marketplace`, `MarketplaceOwner`, `MarketplacePlugin`, `PluginSourceDefinition` | P1 | Plugin model matches spec; marketplace JSON decodes |
| FR-31 | Add `ClaudeConfigPaths` struct, `ConnectionResponse`, `ServerInfo`, `ConfigPathsInfo` DTOs | P1 | All compile and are usable by controllers |
| FR-32 | Add `DashboardStats` / `ResourceStats` DTOs matching spec schema (3 categories: skills, mcpServers, plugins) | P2 | DTO encodes to spec-defined JSON shape |
| FR-33 | Preserve all beyond-spec models: `ChatSession`, `ExternalSession`, `Project`, `Message`, `StreamMessage`, `SessionStatus`, `PermissionMode` | P0 | No regressions |

### Design System

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-34 | Update `ILSTheme.swift` color tokens to match spec or document Apple-system-color decision | P2 | All 15 tokens defined; either match spec hex or have documented rationale |
| FR-35 | Add `accent.secondary` (#FF8C5A) and `accent.tertiary` (#FF4500) to theme | P2 | Colors accessible via `ILSTheme.accentSecondary` / `ILSTheme.accentTertiary` |
| FR-36 | Align corner radius: small=8pt, medium=12pt, large=16pt | P3 | Theme properties renamed and values match |
| FR-37 | Add `border.active` color token (accent.primary) | P3 | Token used for focused input fields |
| FR-38 | Consider asset catalog colors (`Assets.xcassets`) for designer workflow | P3 | Colors defined in xcassets OR documented decision to keep hardcoded |

### GitHub API Integration

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-39 | GitHub API token configuration — env var `GITHUB_TOKEN` on backend, configurable in Settings | P1 | Backend reads token from environment; Settings shows config option |
| FR-40 | GitHub Code Search — query `SKILL.md+filename:SKILL.md` with pagination | P1 | Returns results matching query with star counts and last-updated dates |
| FR-41 | GitHub raw content fetch — download SKILL.md from discovered repos | P1 | Raw markdown content retrieved and parseable |
| FR-42 | Rate limiting awareness — handle GitHub 403 rate limit responses gracefully | P2 | App shows "Rate limited — try again in X seconds" message |

---

## Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-1 | App Store compliance | Apple Review Guidelines | Pass review: no private API usage, proper permissions, privacy manifest |
| NFR-2 | Launch performance | Time to Dashboard | < 2 seconds cold start |
| NFR-3 | API response time | Backend response | < 500ms for local endpoints; < 3s for GitHub search |
| NFR-4 | Offline behavior | Graceful degradation | Cached data displayed; clear offline indicator; no crashes |
| NFR-5 | SSH security | Key storage | SSH keys stored in iOS Keychain; never in UserDefaults or plaintext |
| NFR-6 | API token security | Token storage | GitHub token and session tokens stored in Keychain |
| NFR-7 | Accessibility | VoiceOver | All interactive elements labeled; Dynamic Type supported |
| NFR-8 | Dark mode | Single theme | Dark mode only; no light mode appearance leaks |
| NFR-9 | Minimum iOS version | Platform | iOS 17.0+ |
| NFR-10 | Memory usage | Peak memory | < 200MB under normal usage |
| NFR-11 | Network resilience | Retry logic | Automatic retry with exponential backoff (3 attempts) on transient failures |
| NFR-12 | Data persistence | Local storage | Recent connections, cached skills/plugins survive app termination |
| NFR-13 | Bundle ID | Identity | `com.ils.app` (already set) |
| NFR-14 | URL scheme | Deep linking | `ils://` scheme preserved for navigation |
| NFR-15 | Onboarding | First launch | First-launch flow guides user to connect to server or configure local mode |

---

## Out of Scope

- Light mode theme (dark only per spec)
- iPad-specific layouts (iPhone-first; iPad gets default scaling)
- watchOS or macOS Catalyst builds
- Plugin authoring/creation within the app
- SKILL.md authoring from scratch (only edit existing)
- Custom MCP server registry hosting
- Multi-server simultaneous connections (one active connection at a time)
- End-to-end encryption for SSH traffic (Citadel handles SSH encryption natively)
- Localization / i18n (English only for v1)
- Push notifications
- Analytics / telemetry
- Automated testing framework (validation via real UI per project rules)
- Enterprise/managed scope configuration
- Tab bar navigation (sidebar is primary per Stitch designs)

---

## Glossary

| Term | Definition |
|------|-----------|
| **Skill** | A SKILL.md file in `~/.claude/skills/` containing YAML frontmatter (name, description) + markdown instructions that extend Claude Code's capabilities |
| **MCP Server** | Model Context Protocol server — an external process Claude Code communicates with for tool access (filesystem, GitHub, database, etc.) |
| **Plugin** | A Claude Code extension installed from a marketplace, providing additional commands and integrations |
| **Marketplace** | A GitHub repository containing a `marketplace.json` that lists available plugins |
| **Scope** | Configuration level: User (`~/.claude/`), Project (`.claude/`), Local (`.claude/settings.local.json`), or Managed (enterprise) |
| **Citadel** | Swift SSH library built on SwiftNIO SSH, used for remote server connections |
| **SSE** | Server-Sent Events — one-way streaming protocol used for real-time Claude CLI output |
| **Config Paths** | Standard locations for Claude Code configuration files (see `ClaudeConfigPaths` in spec) |
| **YAML Frontmatter** | Metadata block at top of SKILL.md delimited by `---`, parsed by Yams library |
| **FileSystemService** | Existing backend service that reads local `~/.claude/` directory — preserved alongside SSH for local-first usage |

---

## Dependencies

| Dependency | Type | Purpose | Status |
|------------|------|---------|--------|
| Citadel (orlandos-nl/Citadel) | Swift Package | SSH connectivity from both backend and iOS app | Must add to Package.swift |
| Yams (jpsim/Yams) | Swift Package | YAML parsing for SKILL.md frontmatter | Present in backend; must add to ILSShared target |
| GitHub REST API | External API | Code search for skill/plugin discovery | Requires API token |
| Stitch MCP | Design Tool | Generate pixel-accurate screen designs from spec wireframes | Available via MCP |
| Vapor 4.89+ | Swift Package | Backend web framework | Already integrated |
| Fluent + SQLiteDriver | Swift Package | ORM and database | Already integrated |
| ClaudeCodeSDK (forked) | Swift Package | Claude CLI subprocess management | Already integrated |
| iOS Keychain | System Framework | Secure storage for SSH keys and API tokens | Available on iOS 17+ |
| SF Symbols | System Resource | Icons for navigation, status indicators | Available on iOS 17+ |

---

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Citadel SSH library incompatible with iOS sandbox | Blocks all SSH features (P0) | Medium | Test early; fallback to REST-only mode with backend SSH proxy |
| GitHub API rate limiting (60 req/hr unauthenticated) | Skill/plugin search degraded | High | Require token; implement IndexingService cache; show rate limit UI |
| App Store rejection for SSH functionality | Blocks distribution | Low | SSH is permitted; ensure proper entitlements and privacy descriptions |
| SKILL.md format variations in wild | Parse failures on install | Medium | Robust parser with fallback to raw content display |
| Citadel + SwiftNIO conflicts with Vapor's NIO | Build or runtime crashes | Medium | Known issue with ClaudeCodeSDK + NIO; test integration early |
| Design token decision (spec vs Apple) delays design phase | Blocks UI work | Low | Make decision at design phase start; either choice is viable |
| Large skill repositories slow to clone | Install timeout | Medium | Shallow clone (`--depth 1`); progress indicator; timeout at 60s |
| Multiple spec documents with contradictions | Ambiguous requirements | Low | `ils.md` is authoritative for exact code; `ils-spec.md` for design/wireframes |

---

## Resolved Questions

All previously unresolved questions have been answered:

1. **Color tokens** → Spec custom (#FF6B35, #0D0D0D, etc.)
2. **GitHub API token** → Yes, server-side env var on Vapor backend. Indexes GitHub for skill/plugin discovery
3. **Architecture** → Hybrid REST+SSH; user installs Vapor backend, iOS connects via REST, SSH for file ops
4. **Navigation** → Sidebar (per Stitch designs), NOT tab bar
5. **Chat/Sessions** → Accessible via sidebar and from within views
6. **Managed scope** → Deferred to v2

---

## Success Criteria

| Criteria | Measurement |
|----------|------------|
| All 7 spec screens implemented | Screenshot evidence of each matching wireframe layout |
| All spec API endpoints responding | cURL test for each of the 7 missing + 10 existing endpoints returning correct JSON |
| SSH connection works E2E | Connect to remote host, run `claude --version`, display result in app |
| GitHub skill search works | Search query returns real GitHub results with Install capability |
| Design tokens aligned | Side-by-side comparison of app screenshots vs spec color values |
| Beyond-spec features preserved | All 12 previously validated screens still pass visual inspection |
| App Store build succeeds | Archive build with no errors; passes Xcode validation |
| No mocks or stubs | Every feature validated with real data through actual UI |

## Next Steps

1. Approve requirements (user review)
2. Design phase: Use Stitch MCP to generate screen designs from spec wireframes
3. Architecture phase: Define implementation plan with phased delivery
4. Implementation: Incremental — close gaps without breaking existing features
