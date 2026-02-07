---
spec: ils-complete-rebuild
phase: research
created: 2026-02-05T22:50:00Z
---

# Research: ILS Complete Rebuild - Gap Analysis

## Executive Summary

The ILS iOS app has **significantly diverged from both spec documents** (`ils-spec.md` and `ils.md`). The current implementation evolved beyond the original vision into a **Claude Code session management client** with real-time chat, SSE streaming, and project/session CRUD -- none of which appear in the original specs. Meanwhile, several core spec features remain completely unimplemented: **SSH/Citadel connectivity, ServerConnection entry screen, GitHub skill/plugin search, IndexingService, and the spec's exact design tokens**. The app currently reads from the local filesystem (`~/.claude/`) directly rather than through SSH as the spec envisioned.

The current app is a **functional, validated product** (12 screens, SSE streaming, real Claude CLI integration) that should be treated as the foundation. The rebuild should close spec gaps while preserving the substantial beyond-spec work already done.

## Gap Analysis Matrix

### Models (Sources/ILSShared/Models/)

| Spec Requirement | Spec File | Current Status | Gap | Priority |
|-----------------|-----------|----------------|-----|----------|
| `ServerConnection.swift` | ils.md Task 1.1 | **MISSING** - Not in codebase | Missing | P1 |
| `MCPServer.swift` | ils.md Task 1.2 | **DIVERGED** - Different structure. Spec has nested `ConfigScope` enum + `MCPConfiguration`/`MCPServerDefinition` types. Current has separate `MCPScope`/`MCPStatus` enums, UUID-based `id`, no `MCPConfiguration` wrapper | Partial | P2 |
| `Skill.swift` | ils.md Task 1.3 | **DIVERGED** - Spec has `rawContent: String`, `source: SkillSource` as enum with associated values (`github(repository:stars:)`), YAML parser via `Yams`. Current has `content: String?`, `source: SkillSource` as plain enum (`.local/.plugin/.builtin`), `tags: [String]`, no `Yams` dependency in ILSShared | Partial | P2 |
| `Plugin.swift` | ils.md Task 1.4 | **DIVERGED** - Spec has `stars: Int?`, `source: PluginSource` enum with associated value `.community(repository:)`, plus `Marketplace`, `MarketplaceOwner`, `MarketplacePlugin`, `PluginSourceDefinition` types. Current has simpler `Plugin` + separate `PluginMarketplace`/`PluginInfo` types, no star count, no PluginSource enum | Partial | P2 |
| `ClaudeConfig.swift` | ils.md Task 1.5 | **ENHANCED** - Current has MORE fields than spec (statusLine, theme, apiKeyStatus, alwaysThinkingEnabled, autoUpdatesChannel). Spec's `HooksConfig` was simpler (array of `HookCommand`); current has nested `HookGroup` with `HookDefinition`. Missing spec's `ClaudeConfigPaths` struct | Enhanced | P3 |
| `Marketplace.swift` (standalone) | ils.md Task 1.4 | **MERGED** - Marketplace types exist inside `Plugin.swift` as `PluginMarketplace` | Partial | P3 |
| `APIResponse.swift` (DTO) | ils.md Task 1.6 | **DIVERGED** - Spec had `timestamp`, `APIError` with `details`, `DashboardStats`, `ResourceStats`, `ConnectionResponse`, `ServerInfo`, `ConfigPathsInfo`. Current DTOs in `Requests.swift` are simpler; `StatsResponse` structure different (5 categories vs spec's 3); no `ConnectionResponse`/`ServerInfo` | Partial | P2 |
| `SearchResult.swift` (DTO) | ils.md Task 1.7 | **MISSING** - No `GitHubSearchResult`, `GitHubCodeSearchResponse`, `GitHubCodeItem`, `GitHubRepository`, `SkillInstallRequest` (from GitHub) types | Missing | P1 |
| `Session.swift` | N/A (beyond spec) | **BONUS** - Not in original spec. Full `ChatSession`, `ExternalSession`, `SessionStatus`, `SessionSource`, `PermissionMode` | Preserve | -- |
| `Project.swift` | N/A (beyond spec) | **BONUS** - Not in original spec | Preserve | -- |
| `Message.swift` | N/A (beyond spec) | **BONUS** - Not in original spec | Preserve | -- |
| `StreamMessage.swift` | N/A (beyond spec) | **BONUS** - Full Claude streaming protocol types | Preserve | -- |

### Backend Controllers (Sources/ILSBackend/Controllers/)

| Spec Requirement | Spec Endpoint | Current Status | Gap | Priority |
|-----------------|---------------|----------------|-----|----------|
| `AuthController` | `POST /auth/connect` | **MISSING** - No SSH auth, no connection management | Missing | P0 |
| `StatsController` | `GET /stats` | **ENHANCED** - Returns 5 categories (projects, sessions, skills, mcp, plugins) vs spec's 3. Also has `GET /stats/recent`, `GET /settings` | Enhanced | P3 |
| `SkillsController` | `GET/POST/DELETE /skills`, `GET /skills/search` | **PARTIAL** - CRUD works via FileSystem. **Missing: `GET /skills/search?q=` (GitHub search)**. Uses `:name` param not `:id`. No `POST /skills/install` from GitHub | Partial | P1 |
| `MCPController` | `GET/POST/PUT/DELETE /mcp` | **PARTIAL** - CRUD works. Missing: `PUT /mcp/:name` (update). Has `GET /mcp/:name` (show) which spec didn't specify but is useful | Partial | P2 |
| `PluginsController` | Marketplace + install | **PARTIAL** - Has `GET /plugins`, `GET /plugins/marketplace`, `POST /plugins/install`. **Missing: `GET /plugins/search?q=`**. Extra: enable/disable/uninstall endpoints (beyond spec) | Partial | P2 |
| `ConfigController` | `GET/PUT /config`, `POST /config/validate` | **COMPLETE** - All 3 spec endpoints implemented | Complete | -- |
| `SearchController` | N/A in spec routes but implied | **MISSING** - No dedicated search controller | Missing | P1 |
| `SessionsController` | N/A (beyond spec) | **BONUS** - Full CRUD + fork + scan + transcript reading | Preserve | -- |
| `ChatController` | N/A (beyond spec) | **BONUS** - SSE streaming, WebSocket, permission handling, cancel | Preserve | -- |
| `ProjectsController` | N/A (beyond spec) | **BONUS** - Full CRUD + session listing per project | Preserve | -- |

### Backend Services (Sources/ILSBackend/Services/)

| Spec Requirement | Current Status | Gap | Priority |
|-----------------|----------------|-----|----------|
| `GitHubService.swift` - Search GitHub for SKILL.md files | **MISSING** - Not implemented at all | Missing | P1 |
| `IndexingService.swift` - Cache/index discovered skills/plugins | **MISSING** - Not implemented | Missing | P2 |
| `SSHService` (implied by auth flow) | **MISSING** - No SSH integration. Backend reads LOCAL filesystem | Missing | P0 |
| `FileSystemService.swift` | **EXISTS (beyond spec)** - Reads local `~/.claude/` directory for skills, MCP, config, sessions | Preserve | -- |
| `ClaudeExecutorService.swift` | **EXISTS (beyond spec)** - Executes Claude CLI as subprocess | Preserve | -- |
| `StreamingService.swift` | **EXISTS (beyond spec)** - SSE response builder with message persistence | Preserve | -- |
| `WebSocketService.swift` | **EXISTS (beyond spec)** - WebSocket chat handler | Preserve | -- |

### iOS App Views (ILSApp/ILSApp/Views/)

| Spec Wireframe | Current View | Status | Gap | Priority |
|---------------|-------------|--------|-----|----------|
| Screen 1: ServerConnectionView | **MISSING** | No SSH connection screen exists | Missing | P0 |
| Screen 2: DashboardView | `Dashboard/DashboardView.swift` | **PARTIAL** - Has stat cards and recent sessions. Missing: Quick Actions list (Discover Skills, Browse Plugins, Configure MCP, Edit Settings), Recent Activity feed | Partial | P1 |
| Screen 3: Skills Explorer | `Skills/SkillsListView.swift` | **PARTIAL** - Lists installed skills. **Missing: search bar for GitHub discovery, "Discovered from GitHub" section, Install button from search results** | Partial | P1 |
| Screen 4: Skill Detail | No `SkillDetailView.swift` | **MISSING** - No detail view for individual skills (SKILL.md preview, version, uninstall, edit) | Missing | P1 |
| Screen 5: MCP Server Management | `MCP/MCPServerListView.swift` | **PARTIAL** - Lists servers. Missing: scope tabs (User/Project/Local), Add New Server form (Registry vs Custom), Disable/Edit/Delete per-server actions, status indicators | Partial | P1 |
| Screen 6: Plugin Marketplace | `Plugins/PluginsListView.swift` | **PARTIAL** - Lists installed plugins. **Missing: marketplace browsing, search, categories, Install buttons, "Add Custom Marketplace" option** | Partial | P1 |
| Screen 7: Settings/Config Editor | `Settings/SettingsView.swift` | **PARTIAL** - Shows settings. Missing: raw JSON editor with syntax validation, scope selector (User/Project/Local), Quick Settings toggles (Model, Extended Thinking, Co-authored-by) | Partial | P1 |
| N/A | `Chat/ChatView.swift` | **BONUS** - Full chat UI with SSE streaming | Preserve | -- |
| N/A | `Chat/CommandPaletteView.swift` | **BONUS** - Command palette overlay | Preserve | -- |
| N/A | `Chat/MessageView.swift` | **BONUS** - Rich message rendering | Preserve | -- |
| N/A | `Sessions/SessionsListView.swift` | **BONUS** - Session management | Preserve | -- |
| N/A | `Sessions/NewSessionView.swift` | **BONUS** - Session creation | Preserve | -- |
| N/A | `Sessions/SessionInfoView.swift` | **BONUS** - Session details/info | Preserve | -- |
| N/A | `Projects/ProjectsListView.swift` | **BONUS** - Project browser | Preserve | -- |
| N/A | `Projects/ProjectDetailView.swift` | **BONUS** - Project details | Preserve | -- |
| N/A | `Projects/NewProjectView.swift` | **BONUS** - Project creation | Preserve | -- |
| N/A | `Sidebar/SidebarView.swift` | **BONUS** - Navigation sidebar | Preserve | -- |

### iOS App Services (ILSApp/ILSApp/Services/)

| Spec Requirement | Current Status | Gap | Priority |
|-----------------|----------------|-----|----------|
| `SSHService.swift` (Citadel-based) | **MISSING** - No SSH service in iOS app | Missing | P0 |
| `APIClient.swift` | **EXISTS** - Actor-based URLSession client with generic CRUD | Complete | -- |
| `ConfigurationManager.swift` | **MISSING** - Spec wanted a config manager for Claude settings lifecycle | Missing | P2 |
| `SSEClient.swift` | **EXISTS (beyond spec)** - SSE streaming client | Preserve | -- |

### iOS App ViewModels (ILSApp/ILSApp/ViewModels/)

| Spec Requirement | Current Status | Gap | Priority |
|-----------------|----------------|-----|----------|
| `ServerConnectionViewModel` | **MISSING** | Missing | P0 |
| `DashboardViewModel` | **EXISTS** | Partial (needs Quick Actions) | P2 |
| `SkillsViewModel` | **EXISTS** | Partial (needs GitHub search) | P1 |
| `MCPViewModel` | **EXISTS** | Partial (needs scope filtering) | P2 |
| `PluginsViewModel` | **EXISTS** | Partial (needs marketplace) | P1 |
| `SessionsViewModel` | **EXISTS (beyond spec)** | Preserve | -- |
| `ChatViewModel` | **EXISTS (beyond spec)** | Preserve | -- |
| `ProjectsViewModel` | **EXISTS (beyond spec)** | Preserve | -- |

## 1. Feature Gaps (Detailed)

### 1.1 Missing Features (Not Implemented At All)

**F-MISS-1: SSH/Server Connection (P0)**
- Spec envisions connecting to a REMOTE server via SSH to manage Claude Code
- Current app operates LOCALLY only (reads `~/.claude/` on the machine running the backend)
- No `ServerConnection` model, no `ServerConnectionView`, no SSH service
- Citadel dependency listed in spec `Package.swift` but NOT in current `Package.swift`
- **Impact**: The entire spec premise of "remote management" is absent

**F-MISS-2: GitHub Skill Discovery & Install (P1)**
- Spec: `GET /skills/search?q=` searches GitHub Code API for SKILL.md files
- Spec: `POST /skills/install` clones from GitHub repo
- Current: Only lists LOCAL skills from `~/.claude/skills/`
- No `GitHubService.swift` exists
- No `SearchResult.swift` DTO exists

**F-MISS-3: GitHub Plugin Discovery (P1)**
- Spec: Browse plugin marketplaces from GitHub repos
- Current: Marketplace endpoint returns hardcoded official list
- No real GitHub integration for plugin discovery

**F-MISS-4: Skill Detail View (P1)**
- Spec wireframe 4 shows: SKILL.md preview, version, author, stars, Uninstall, Edit buttons
- No `SkillDetailView.swift` exists in the codebase

**F-MISS-5: IndexingService (P2)**
- Spec: Background service to cache/index discovered skills and plugins
- Current: No indexing, only direct filesystem reads with 30s TTL cache

### 1.2 Partially Implemented Features

**F-PART-1: Dashboard (P1)**
- Has: Stat cards (projects, sessions, skills, MCP, plugins), recent sessions
- Missing: Quick Actions list (4 navigation shortcuts), Recent Activity feed (install/update history)

**F-PART-2: Skills Explorer (P1)**
- Has: List installed skills with name, description, path, source
- Missing: GitHub search bar, "Discovered from GitHub" section, Install button, Active/Disabled toggle per skill

**F-PART-3: MCP Server Management (P1)**
- Has: List all servers, show command/args/env
- Missing: Scope tabs (User/Project/Local), Add New Server form, Edit/Delete/Disable per server, "From Registry" vs "Custom Command" radio, error retry

**F-PART-4: Plugin Marketplace (P1)**
- Has: List installed plugins, marketplace endpoint
- Missing: Search, category filters, Install buttons, "Add Custom Marketplace", browse remote plugins

**F-PART-5: Settings Editor (P1)**
- Has: Settings display
- Missing: Raw JSON editor with syntax highlighting, JSON validation feedback, scope selector dropdown, Quick Settings toggles (Model, Extended Thinking, Co-authored-by)

### 1.3 Complete Features (Matching Spec)

**F-COMP-1: Config CRUD** - `GET /config`, `PUT /config`, `POST /config/validate` all implemented correctly

**F-COMP-2: Stats Endpoint** - Returns counts for all resource types (exceeds spec by including projects + sessions)

**F-COMP-3: Health Endpoint** - Returns structured health info including Claude version detection

## 2. Design System Gaps

### 2.1 Color Token Mismatches

| Token | Spec Value | Current Value | File | Match? |
|-------|-----------|---------------|------|--------|
| accent.primary | `#FF6B35` | `#FF6600` (rgb 1.0, 102/255, 0) | ILSTheme.swift:8 | **MISMATCH** |
| accent.secondary | `#FF8C5A` | Not defined | -- | **MISSING** |
| accent.tertiary | `#FF4500` | Not defined | -- | **MISSING** |
| background.primary | `#000000` | `#000000` (0,0,0) | ILSTheme.swift:11 | MATCH |
| background.secondary | `#0D0D0D` | `#1C1C1E` (28,28,30) | ILSTheme.swift:12 | **MISMATCH** (Apple system dark) |
| background.tertiary | `#1A1A1A` | `#2C2C2E` (44,44,46) | ILSTheme.swift:13 | **MISMATCH** (Apple system dark) |
| text.primary | `#FFFFFF` | `Color.white` | ILSTheme.swift:16 | MATCH |
| text.secondary | `#A0A0A0` | `#8E8E93` (142,142,147) | ILSTheme.swift:17 | **MISMATCH** (Apple system gray) |
| text.tertiary | `#666666` | `#48484A` (72,72,74) | ILSTheme.swift:18 | **MISMATCH** |
| border.default | `#2A2A2A` | `#262628` (separator) | ILSTheme.swift:31 | **CLOSE** (slightly off) |
| border.active | `#FF6B35` | Not defined separately | -- | **MISSING** |
| success | `#4CAF50` | `#34C759` (52,199,89) | ILSTheme.swift:21 | **MISMATCH** (Apple green) |
| warning | `#FFA726` | `#FF9500` (255,149,0) | ILSTheme.swift:22 | **MISMATCH** (Apple orange) |
| error | `#EF5350` | `#FF3B30` (255,59,48) | ILSTheme.swift:23 | **MISMATCH** (Apple red) |

**Summary**: Current theme uses **Apple system colors** (SF-style). Spec defines **custom dark theme colors**. 9 of 15 tokens mismatch. The current approach is arguably better for iOS ecosystem consistency, but does not match the spec.

### 2.2 Typography Gaps

| Spec | Current | Match? |
|------|---------|--------|
| SF Pro Display, Bold (headings) | `Font.system(.title, weight: .bold)` | **PARTIAL** - Uses system dynamic type, not explicit SF Pro Display |
| SF Pro Text, Regular (body) | `Font.system(.body)` | MATCH (system default IS SF Pro Text) |
| SF Mono, Regular (code) | `Font.system(.body, design: .monospaced)` | MATCH |

The spec in `ils.md` Task 2B.2 defines explicit point sizes (34, 28, 22, etc.) in a `Typography` enum. Current theme uses SwiftUI dynamic type scales instead. **Not a strict mismatch** -- current approach is better for accessibility.

### 2.3 Corner Radius Gaps

| Spec | Current | Match? |
|------|---------|--------|
| Small: 8pt | `cornerRadiusS: 4`, `cornerRadiusM: 8` | **MISMATCH** - Spec small=8, current small=4 |
| Medium: 12pt | `cornerRadiusL: 12` | MATCH (but labeled "L" not "M") |
| Large: 16pt | `cornerRadiusXL: 16` | MATCH (but labeled "XL" not "L") |

Naming convention differs. Values partially match but naming is shifted by one tier.

### 2.4 Spacing Scale

| Spec | Current | Match? |
|------|---------|--------|
| xs: 4pt | `spacingXS: 4` | MATCH |
| sm: 8pt | `spacingS: 8` | MATCH |
| md: 16pt | `spacingM: 16` | MATCH |
| lg: 24pt | `spacingL: 24` | MATCH |
| xl: 32pt | `spacingXL: 32` | MATCH |

Spacing scale is correct.

### 2.5 Spec Theme Structure (ils.md Task 2B.2)

The `ils.md` spec defines a more structured theme with nested enums (`Colors`, `Typography`, `Spacing`, `CornerRadius`, `Shadows`), card styles with border overlays, and specific button/text field styles. Current `ILSTheme.swift` uses flat properties instead. The spec's design is more comprehensive but the current code is functional.

### 2.6 Color Asset Catalogs

Spec Task 2B.1 defines `Colors/` in `Assets.xcassets` with specific color sets (BackgroundPrimary, BackgroundSecondary, etc.). Current implementation uses **hardcoded Color() values** rather than asset catalog references. This means no easy designer override and no accessibility support through asset catalogs.

## 3. API Contract Gaps

### 3.1 Missing Endpoints

| Spec Endpoint | Purpose | Status |
|--------------|---------|--------|
| `POST /auth/connect` | SSH connection with host/port/user/auth | **MISSING** |
| `GET /server/status` | Connection health check | **MISSING** |
| `GET /skills/search?q=` | GitHub skill search | **MISSING** |
| `POST /skills/install` | Install skill from GitHub | **MISSING** |
| `PUT /mcp/:name` | Update MCP server config | **MISSING** |
| `GET /plugins/search?q=` | Search plugins across marketplaces | **MISSING** |
| `POST /marketplaces` | Add custom marketplace | **MISSING** |

### 3.2 Schema Mismatches

| Endpoint | Spec Schema | Current Schema | Difference |
|----------|------------|----------------|------------|
| `GET /stats` | `{skills:{total,active}, mcpServers:{total,healthy}, plugins:{total,enabled}}` | `{projects:{total,active?}, sessions:{total,active}, skills:{total,active?}, mcpServers:{total,healthy}, plugins:{total,enabled}}` | Current has 5 categories vs spec's 3 |
| `GET /skills` | Items have `id: UUID`, `skillMd: String` | Items have `id: UUID`, `content: String?`, `tags: [String]` | Field name/optional differences |
| `GET /mcp` | Items use `name` as `id`, have `status: "healthy"|"error"` | Items have UUID `id`, `status: MCPStatus` enum | ID type differs |
| `GET /plugins/marketplace` | Returns `{marketplaces: [{name, source, plugins}]}` | Returns `APIResponse<[PluginMarketplace]>` | Wrapper structure differs |
| `GET /config` | Returns `{scope, path, content, isValid}` | Returns `APIResponse<ConfigInfo>` with same fields | Wrapped in APIResponse (minor) |

### 3.3 Response Format

Spec defines raw JSON responses. Current wraps everything in `APIResponse<T>` with `{success, data, error}`. This is actually **better** than the spec (consistent error handling), but deviates from the spec contract.

### 3.4 Base URL

Spec: `http://localhost:8080/api/v1`
Current: `http://localhost:9090/api/v1` (changed to avoid ralph-mobile conflict)

## 4. Backend Architecture Gaps

### 4.1 Database

- **Spec**: SQLite in-memory (`.memory`) -- for development only
- **Current**: SQLite file (`ils.sqlite`) -- persistent storage
- **Current additions**: `CreateProjects`, `CreateSessions`, `CreateMessages` migrations with Fluent ORM models (`ProjectModel`, `SessionModel`, `MessageModel`)
- **Assessment**: Current is superior -- persistent storage with proper migrations

### 4.2 Dependencies

| Spec Dependency | Current Status |
|----------------|----------------|
| Vapor 4.89+ | Present (same) |
| Fluent 4.9+ | Present (same) |
| FluentSQLiteDriver 4.6+ | Present (same) |
| Citadel 0.7+ (SSH) | **MISSING** from Package.swift |
| Yams 5.0+ | Present (same) but NOT in ILSShared target (only ILSBackend) |
| ClaudeCodeSDK | **ADDED** (beyond spec) - forked SDK for CLI integration |

### 4.3 Data Source Architecture

**Spec vision**: iOS app -> Vapor backend -> SSH tunnel -> remote machine's `~/.claude/`
**Current reality**: iOS app -> Vapor backend -> local filesystem `~/.claude/`

The `FileSystemService` reads the LOCAL machine's Claude configuration. This works for single-machine use but doesn't match the spec's remote-management vision.

## 5. Current Strengths (Preserve These)

### 5.1 Beyond-Spec Features (HIGH VALUE)

| Feature | Implementation | Evidence |
|---------|---------------|----------|
| **Chat/Sessions System** | Full CRUD for sessions with SQLite persistence, message history, fork capability | SessionsController, ChatController, ChatView |
| **SSE Streaming** | Real-time Claude CLI output via Server-Sent Events with timeout handling | ClaudeExecutorService, StreamingService, SSEClient |
| **WebSocket Support** | Alternative real-time communication channel | WebSocketService |
| **Claude CLI Integration** | Direct subprocess execution of `claude` CLI with two-tier timeouts | ClaudeExecutorService.swift |
| **Stream Message Protocol** | Full typed protocol for system, assistant, result, permission, error messages | StreamMessage.swift |
| **Project Management** | Scans `~/.claude/projects/` for real project data, CRUD operations | ProjectsController, ProjectsListView |
| **External Session Discovery** | Reads `sessions-index.json` and JSONL transcripts from Claude Code storage | FileSystemService.scanExternalSessions() |
| **Command Palette** | Slash-command style overlay for quick actions | CommandPaletteView.swift |
| **Session Forking** | Fork existing sessions to continue from a point | SessionsController.fork() |
| **Rich Message Rendering** | Content blocks: text, tool_use, tool_result, thinking | MessageView.swift |
| **Permission Handling** | Tool permission requests/decisions during chat | ChatController.permission() |
| **Claude Version Detection** | Health endpoint detects Claude CLI version | routes.swift detectClaudeVersion() |

### 5.2 Architecture Strengths

- **Actor-based APIClient** with proper concurrency safety
- **MVVM pattern** consistently applied across all views
- **Reusable theme components** (CardStyle, PrimaryButtonStyle, LoadingOverlay, ErrorStateView, EmptyStateView)
- **Caching layer** in FileSystemService with TTL-based invalidation
- **Proper CORS** and error middleware
- **Generic API response wrapper** for consistent error handling

### 5.3 Validated Screens (12 working screens per project memory)

Dashboard, Sessions, Projects, Skills, MCP Servers, Plugins, Settings, Sidebar, New Session, Chat View, Command Palette, Session Info

## 6. Recommendations

### 6.1 Rebuild vs Incremental

**Recommendation: INCREMENTAL ENHANCEMENT, not rebuild.**

Rationale:
- 12 screens working and validated
- SSE streaming (hardest feature) already works
- Session/chat system is substantial beyond-spec value
- Most spec gaps are ADDITIVE (new screens, new endpoints) not REPLACEMENT
- Only the SSH/remote paradigm is fundamentally different -- and local-first may actually be the better UX

### 6.2 Priority Order

**P0 - Architectural Decision Required**
1. **SSH vs Local-First**: Decide whether to implement SSH/Citadel remote management (spec vision) or embrace local-first (current reality). If local-first, several spec features become irrelevant (ServerConnection, auth, SSHService). Recommend: **Local-first with optional SSH later**.

**P1 - Core Feature Gaps (add to current app)**
2. **SkillDetailView** - Add navigation from skill list to detail view with SKILL.md preview, edit, delete
3. **GitHub Skill Search** - Add `GitHubService`, `GET /skills/search?q=`, search UI in SkillsListView
4. **Enhanced Dashboard** - Add Quick Actions list, Recent Activity feed
5. **MCP Management** - Add scope tabs, Add/Edit/Delete forms, status indicators
6. **Plugin Marketplace** - Add marketplace browsing, search, category filters, install flow
7. **Settings Editor** - Add raw JSON editor, validation feedback, Quick Settings toggles

**P2 - Model Alignment**
8. Align model schemas to match spec more closely (add missing fields, fix enums)
9. Add `SearchResult.swift` DTOs for GitHub integration
10. Add `ConfigurationManager.swift` for settings lifecycle

**P3 - Design Polish**
11. Resolve color token mismatches (spec custom vs Apple system -- make a deliberate choice)
12. Align corner radius naming convention
13. Consider asset catalog colors for designer workflow

### 6.3 Estimated Scope

| Work Item | Effort | Dependencies |
|-----------|--------|-------------|
| SSH/Citadel integration | XL (2-3 weeks) | Architectural decision |
| SkillDetailView | S (1-2 days) | None |
| GitHubService + search | M (3-5 days) | GitHub API token |
| Dashboard Quick Actions + Activity | S (1-2 days) | None |
| MCP scope tabs + forms | M (3-5 days) | None |
| Plugin marketplace UI | M (3-5 days) | GitHubService |
| Settings JSON editor | M (3-5 days) | None |
| Model schema alignment | S (1-2 days) | None |
| Design token alignment | S (1 day) | Design decision |
| **Total (without SSH)** | **L (3-4 weeks)** | |
| **Total (with SSH)** | **XL (6-7 weeks)** | |

## 7. Stitch MCP Design Integration Notes

Stitch MCP can be leveraged for:
- **Generating consistent screen designs** for the 4 missing/partial views (SkillDetail, enhanced MCP, Plugin Marketplace, Settings Editor)
- **Design token system** -- Generate a Stitch project with the spec's color tokens and export as SwiftUI assets
- **Wireframe-to-implementation** -- Feed spec wireframes into Stitch to generate pixel-accurate SwiftUI views
- **Dark theme consistency** -- Use Stitch to ensure all new screens match the validated V2 design
- **Component library** -- Generate reusable card, button, and form components from the design system spec

**Recommendation**: Create a Stitch project with the ILS design system (either spec tokens or Apple system tokens -- decide first), then generate each missing view from the wireframes.

## 8. Quality Commands

| Type | Command | Source |
|------|---------|--------|
| Build (backend) | `swift build --target ILSBackend` | Package.swift |
| Build (shared) | `swift build --target ILSShared` | Package.swift |
| Build (iOS) | `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build` | Xcode project |
| Run backend | `PORT=9090 swift run ILSBackend` | configure.swift |
| Test (shared) | `swift test --filter ILSSharedTests` | Package.swift |
| Test (backend) | `swift test --filter ILSBackendTests` | Package.swift |
| Lint | Not found | -- |
| TypeCheck | N/A (Swift compiler handles this) | -- |

**Local CI**: `swift build && swift test`

## Open Questions

1. **SSH or Local-First?** - Should the rebuild implement SSH/Citadel remote management, or embrace the current local-first architecture? This is the single biggest architectural decision.
2. **Color tokens: Spec custom vs Apple system?** - The spec defines custom hex colors (#FF6B35, #0D0D0D, etc.). The current app uses Apple system colors (#1C1C1E, #34C759, etc.). Which is the intended direction?
3. **GitHub API Authentication** - The GitHubService needs a token for code search. How should this be configured? Environment variable? User-provided in Settings?
4. **Tab bar or sidebar navigation?** - Spec wireframe 2 shows a bottom tab bar `[Home] [Skills] [MCPs] [Discover]`. Current app uses a sidebar sheet + tab structure. Which navigation paradigm?
5. **ServerConnection as gate?** - Spec puts ServerConnection as the entry point (must connect before seeing dashboard). Current app launches directly to sessions. If local-first, is a connection screen still needed?

## Related Specs

| Spec | Relationship | mayNeedUpdate |
|------|-------------|---------------|
| `specs/app-improvements` | Medium - likely covers incremental UI improvements that overlap with this gap analysis | true |

## Sources

- `/Users/nick/Desktop/ils-ios/docs/ils-spec.md` - Original feature specification
- `/Users/nick/Desktop/ils-ios/docs/ils.md` - Master build orchestration specification
- `/Users/nick/Desktop/ils-ios/Package.swift` - Current dependency manifest
- `/Users/nick/Desktop/ils-ios/Sources/ILSShared/Models/*.swift` - All shared model files
- `/Users/nick/Desktop/ils-ios/Sources/ILSShared/DTOs/Requests.swift` - All DTOs and request types
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/*.swift` - All 8 controllers
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Services/*.swift` - All 4 services
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/App/routes.swift` - Route registration
- `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/App/configure.swift` - App configuration
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Theme/ILSTheme.swift` - Current theme
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Services/APIClient.swift` - iOS HTTP client
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/**/*.swift` - All 16 view files
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/ViewModels/*.swift` - All 8 view models
