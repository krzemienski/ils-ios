---
spec: ils-complete-rebuild
phase: tasks
total_tasks: 42
created: 2026-02-06T00:00:00Z
---

# Tasks: ILS Complete Rebuild

## Execution Context

| Setting | Value |
|---------|-------|
| Testing depth | Comprehensive -- functional validation plus E2E automation with simulator screenshots for every feature |
| Deployment approach | App Store ready -- full submission prep: Privacy Manifest, screenshots, App Store metadata |
| Execution priority | Balanced -- reasonable quality with speed, follow existing patterns but don't over-engineer |
| Simulator UDID | `50523130-57AA-48B0-ABD0-4D59CE455F14` (iPhone 16 Pro Max, iOS 18.6) |
| Backend port | 9090 |
| Build iOS | `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build` |
| Build backend | `swift build --target ILSBackend` |
| Run backend | `PORT=9090 swift run ILSBackend` |

---

## Phase 1: Make It Work (POC)

Focus: Get all new features compiling and responding to API calls. Accept hardcoded values, skip edge cases, validate E2E.

### 1.1 Add Citadel dependency and shared models [x]

- **Do**:
  1. Add `Citadel` package dependency to `Package.swift`: `.package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.7.0")`
  2. Add Citadel to both `ILSBackend` and create a conditional import for iOS target
  3. Add `Yams` to `ILSShared` target dependencies
  4. Create `Sources/ILSShared/Models/ServerConnection.swift` with `ServerConnection` struct and `AuthMethod` enum per design
  5. Create `Sources/ILSShared/DTOs/ConnectionResponse.swift` with `ConnectionResponse`, `ServerInfo`, `ClaudeConfigPaths`, `ServerStatus`, `ConnectRequest` structs per design
  6. Create `Sources/ILSShared/DTOs/SearchResult.swift` with `GitHubCodeSearchResponse`, `GitHubCodeItem`, `GitHubRepository`, `GitHubSearchResult`, `SkillInstallRequest`, `PluginSearchResult`, `AddMarketplaceRequest`, `Marketplace` structs per design
- **Files**:
  - Modify: `Package.swift`
  - Create: `Sources/ILSShared/Models/ServerConnection.swift`
  - Create: `Sources/ILSShared/DTOs/ConnectionResponse.swift`
  - Create: `Sources/ILSShared/DTOs/SearchResult.swift`
- **Done when**: `swift build --target ILSShared` compiles with zero errors
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSShared 2>&1 | tail -5`
- **Commit**: `feat(shared): add ServerConnection, SearchResult, ConnectionResponse models and Citadel/Yams deps`
- _Requirements: FR-26, FR-27, FR-31_
- _Design: New Shared Models_

### 1.2 Enhance existing shared models (Skill, Plugin)

- **Do**:
  1. Update `Sources/ILSShared/Models/Skill.swift`:
     - Add `github` case to `SkillSource` enum
     - Add fields: `rawContent: String?`, `stars: Int?`, `author: String?`, `lastUpdated: String?`
     - Keep `content` for backward compat, add `rawContent` as alias
     - Add `Hashable` conformance
  2. Update `Sources/ILSShared/Models/Plugin.swift`:
     - Add `stars: Int?`, `source: PluginSource?`, `category: String?` to `Plugin`
     - Add `PluginSource` enum (official, community)
     - Keep existing `PluginMarketplace` and `PluginInfo`
  3. Update `Sources/ILSShared/DTOs/Requests.swift`:
     - Add `SkillInstallRequest` if not in SearchResult.swift
     - Verify `InstallPluginRequest` has `scope` field
- **Files**:
  - Modify: `Sources/ILSShared/Models/Skill.swift`
  - Modify: `Sources/ILSShared/Models/Plugin.swift`
  - Modify: `Sources/ILSShared/DTOs/Requests.swift`
- **Done when**: `swift build --target ILSShared` compiles; `swift build --target ILSBackend` compiles
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -5`
- **Commit**: `feat(shared): enhance Skill and Plugin models with GitHub fields and PluginSource`
- _Requirements: FR-28, FR-29, FR-30_
- _Design: Modified Shared Models_

### 1.3 [VERIFY] Quality checkpoint: backend compiles

- **Do**: Build both ILSShared and ILSBackend targets to ensure model changes don't break existing code
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -10`
- **Done when**: Zero compile errors on backend
- **Commit**: `chore(backend): fix compilation after model updates` (only if fixes needed)

### 1.4 Create backend SSHService [x]

- **Do**:
  1. Create `Sources/ILSBackend/Services/SSHService.swift` as an actor
  2. Import Citadel; share `app.eventLoopGroup` (do NOT create separate EventLoopGroup)
  3. Implement `connect(host:port:username:authMethod:)` using `SSHClient.connect`
  4. Implement `disconnect()`, `executeCommand(_:)`, `isConnected()`, `getServerStatus()`
  5. `executeCommand` runs remote command via Citadel's `executeCommandStream` and returns stdout/stderr
  6. `getServerStatus` runs `claude --version` remotely, returns `ServerStatus`
  7. Store `SSHClient?` as private var; handle connection lifecycle
- **Files**:
  - Create: `Sources/ILSBackend/Services/SSHService.swift`
- **Done when**: `swift build --target ILSBackend` compiles
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -5`
- **Commit**: `feat(backend): add SSHService with Citadel for remote server connections`
- _Requirements: FR-13, FR-1_
- _Design: SSHService (P0)_

### 1.5 Create AuthController and wire server/status

- **Do**:
  1. Create `Sources/ILSBackend/Controllers/AuthController.swift` implementing `RouteCollection`
  2. Route `POST /auth/connect`: decode `ConnectRequest`, call `SSHService.connect`, return `ConnectionResponse`
  3. Route `POST /auth/disconnect`: call `SSHService.disconnect`, return `AcknowledgedResponse`
  4. Store SSHService instance as a shared singleton (via `app.storage`)
  5. Add `GET /server/status` route to `StatsController` that calls `SSHService.getServerStatus()`
  6. Register `AuthController` in `routes.swift`
  7. For POC: if SSHService connect fails, return `ConnectionResponse(success: false, error: message)` -- don't crash
- **Files**:
  - Create: `Sources/ILSBackend/Controllers/AuthController.swift`
  - Modify: `Sources/ILSBackend/Controllers/StatsController.swift`
  - Modify: `Sources/ILSBackend/App/routes.swift`
- **Done when**: `swift build --target ILSBackend` compiles; `curl -X POST localhost:9090/api/v1/auth/connect -H 'Content-Type: application/json' -d '{"host":"localhost","port":22,"username":"test","authMethod":"password","credential":"test"}' | jq .` returns JSON (success or error)
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -5`
- **Commit**: `feat(backend): add AuthController with SSH connect/disconnect and server/status endpoint`
- _Requirements: FR-1, FR-2_
- _Design: AuthController, StatsController server status_

### 1.6 Create GitHubService and skill search/install endpoints

- **Do**:
  1. Create `Sources/ILSBackend/Services/GitHubService.swift` as a struct
  2. Read `GITHUB_TOKEN` from `Environment.get("GITHUB_TOKEN")`
  3. Implement `searchSkills(query:page:perPage:)` using Vapor's `Client` to call `https://api.github.com/search/code?q={query}+filename:SKILL.md`
  4. Set `Authorization: Bearer {token}` header if token available
  5. Parse response into `GitHubCodeSearchResponse`, transform to `[GitHubSearchResult]`
  6. Implement `fetchRawContent(owner:repo:path:)` to get raw file from `https://raw.githubusercontent.com/{owner}/{repo}/main/{path}`
  7. Add `GET /skills/search?q={query}` route to `SkillsController` that calls GitHubService
  8. Add `POST /skills/install` route to `SkillsController` that:
     - Receives `SkillInstallRequest` with `repository` and optional `skillPath`
     - Fetches raw SKILL.md content via GitHubService
     - Writes to `~/.claude/skills/{name}/SKILL.md`
     - Returns installed `Skill` object
  9. POC shortcut: use raw content fetch instead of git clone for speed
- **Files**:
  - Create: `Sources/ILSBackend/Services/GitHubService.swift`
  - Modify: `Sources/ILSBackend/Controllers/SkillsController.swift`
- **Done when**: Backend compiles; `curl 'localhost:9090/api/v1/skills/search?q=code-review' | jq .` returns results (with GITHUB_TOKEN set)
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -5`
- **Commit**: `feat(backend): add GitHubService and skill search/install endpoints`
- _Requirements: FR-3, FR-4, FR-11, FR-40, FR-41_
- _Design: GitHubService, SkillsController search+install_

### 1.7 Add MCP update endpoint and plugin search/marketplace endpoints

- **Do**:
  1. Add `PUT /mcp/:name` route to `MCPController`:
     - Decode `CreateMCPRequest`, find existing server by name, update fields
     - Call `FileSystemService.updateMCPServer` (add if missing) to write config
  2. Add `GET /plugins/search?q={query}` route to `PluginsController`:
     - POC: filter installed plugins by name/description matching query
     - Future: search across registered marketplaces
  3. Add `POST /marketplaces` route to `PluginsController`:
     - Decode `AddMarketplaceRequest`, validate `owner/repo` format
     - Add to config's `extraKnownMarketplaces` via FileSystemService
     - Return new `Marketplace` object
- **Files**:
  - Modify: `Sources/ILSBackend/Controllers/MCPController.swift`
  - Modify: `Sources/ILSBackend/Controllers/PluginsController.swift`
- **Done when**: Backend compiles; `curl -X PUT localhost:9090/api/v1/mcp/test-server -H 'Content-Type: application/json' -d '{"name":"test-server","command":"npx","args":["-y","test"]}' | jq .success` returns true
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -5`
- **Commit**: `feat(backend): add MCP update, plugin search, and marketplace registration endpoints`
- _Requirements: FR-5, FR-6, FR-7_
- _Design: MCPController update, PluginsController search+marketplace_

### 1.8 [VERIFY] Backend full build + endpoint smoke test

- **Do**:
  1. Build backend: `swift build --target ILSBackend`
  2. Start backend briefly and test all new endpoints respond (even if with error)
  3. Verify existing endpoints still work: `curl localhost:9090/health | jq .status`
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -3`
- **Done when**: Backend compiles cleanly; all existing endpoints unchanged
- **Commit**: `chore(backend): pass quality checkpoint after new endpoints` (only if fixes needed)

### 1.9 Update ILSTheme.swift design tokens

- **Do**:
  1. Update `ILSApp/ILSApp/Theme/ILSTheme.swift`:
     - `accent`: change to `Color(red: 1.0, green: 107.0/255.0, blue: 53.0/255.0)` (#FF6B35)
     - `secondaryBackground`: change to `Color(red: 13.0/255.0, green: 13.0/255.0, blue: 13.0/255.0)` (#0D0D0D)
     - `tertiaryBackground`: change to `Color(red: 26.0/255.0, green: 26.0/255.0, blue: 26.0/255.0)` (#1A1A1A)
     - `secondaryText`: change to `Color(red: 160.0/255.0, green: 160.0/255.0, blue: 160.0/255.0)` (#A0A0A0)
     - `tertiaryText`: change to `Color(red: 102.0/255.0, green: 102.0/255.0, blue: 102.0/255.0)` (#666666)
     - `success`: change to `Color(red: 76.0/255.0, green: 175.0/255.0, blue: 80.0/255.0)` (#4CAF50)
     - `warning`: change to `Color(red: 1.0, green: 167.0/255.0, blue: 38.0/255.0)` (#FFA726)
     - `error`: change to `Color(red: 239.0/255.0, green: 83.0/255.0, blue: 80.0/255.0)` (#EF5350)
     - `separator` (borderDefault): change to `Color(red: 42.0/255.0, green: 42.0/255.0, blue: 42.0/255.0)` (#2A2A2A)
  2. Add new tokens:
     - `accentSecondary`: `Color(red: 1.0, green: 140.0/255.0, blue: 90.0/255.0)` (#FF8C5A)
     - `accentTertiary`: `Color(red: 1.0, green: 69.0/255.0, blue: 0.0)` (#FF4500)
     - `borderDefault`: same as separator (#2A2A2A)
     - `borderActive`: same as accent (#FF6B35)
  3. Rename corner radius:
     - `cornerRadiusS` (4) -> keep as `cornerRadiusXS`
     - `cornerRadiusM` (8) -> `cornerRadiusSmall`
     - `cornerRadiusL` (12) -> `cornerRadiusMedium`
     - `cornerRadiusXL` (16) -> `cornerRadiusLarge`
  4. Update all references to renamed corner radius properties across views
- **Files**:
  - Modify: `ILSApp/ILSApp/Theme/ILSTheme.swift`
  - Modify: All views referencing `cornerRadiusM`, `cornerRadiusL`, `cornerRadiusXL`
- **Done when**: iOS app compiles with updated theme
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Commit**: `feat(theme): align all color tokens and corner radii to spec values`
- _Requirements: FR-34, FR-35, FR-36, FR-37, AC-18.1 through AC-18.5_
- _Design: Color Tokens, Corner Radius Alignment_

### 1.10 Create iOS KeychainService

- **Do**:
  1. Create `ILSApp/ILSApp/Services/KeychainService.swift`
  2. Implement using `Security.framework` directly (no third-party wrappers)
  3. Methods: `save(key:data:)`, `load(key:)`, `delete(key:)`
  4. Convenience: `savePassword(_:for:)`, `loadPassword(for:)`, `saveSSHKey(_:label:)`, `loadSSHKey(label:)`, `saveToken(_:key:)`, `loadToken(key:)`
  5. Use `kSecClassGenericPassword` for passwords/tokens, `kSecClassKey` for SSH keys
  6. Handle errors: `errSecDuplicateItem` (update instead), `errSecItemNotFound` (return nil)
- **Files**:
  - Create: `ILSApp/ILSApp/Services/KeychainService.swift`
- **Done when**: iOS app compiles
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Commit**: `feat(ios): add KeychainService for secure credential storage`
- _Requirements: FR-23, NFR-5, NFR-6_
- _Design: KeychainService_

### 1.11 Create ServerConnectionView and ViewModel

- **Do**:
  1. Create `ILSApp/ILSApp/ViewModels/ServerConnectionViewModel.swift`:
     - `@Published` properties: host, port (default "22"), username, authMethod (password/key), credential, isConnecting, error, recentConnections
     - `connect()` method: POST to `/auth/connect` via APIClient, store token in Keychain, save to recent connections (UserDefaults, max 10)
     - `loadRecentConnections()` from UserDefaults
     - `selectRecentConnection(_:)` to pre-fill form
     - Follow existing pattern: `@MainActor class ... : ObservableObject` with `configure(client:)`
  2. Create directory `ILSApp/ILSApp/Views/ServerConnection/`
  3. Create `ILSApp/ILSApp/Views/ServerConnection/ServerConnectionView.swift`:
     - Form with: host TextField, port TextField, username TextField
     - Auth method picker (Password / SSH Key) as segmented control
     - Password: SecureField; SSH Key: file picker button
     - Connect button with loading state (PrimaryButtonStyle)
     - Recent Connections list below with green/gray dot indicators
     - Error alert on failure
     - Dark theme: `.scrollContentBackground(.hidden).background(ILSTheme.background)`
  4. Update `ILSApp/ILSApp/ILSAppApp.swift` AppState:
     - Add `@Published var isServerConnected: Bool = false`
     - Add `@Published var serverConnectionInfo: ConnectionResponse?`
  5. Update `ILSApp/ILSApp/ContentView.swift`:
     - Add optional display of ServerConnectionView (accessible from Settings, not a mandatory gate)
- **Files**:
  - Create: `ILSApp/ILSApp/ViewModels/ServerConnectionViewModel.swift`
  - Create: `ILSApp/ILSApp/Views/ServerConnection/ServerConnectionView.swift`
  - Modify: `ILSApp/ILSApp/ILSAppApp.swift`
  - Modify: `ILSApp/ILSApp/ContentView.swift`
- **Done when**: iOS app compiles; ServerConnectionView is navigable from Settings
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Commit**: `feat(ios): add ServerConnectionView with SSH form and recent connections`
- _Requirements: FR-15, US-1, AC-1.1 through AC-1.7_
- _Design: ServerConnectionView, ServerConnectionViewModel_

### 1.12 [VERIFY] iOS app builds after SSH foundation

- **Do**: Full iOS build to catch any compilation issues from theme + new files
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Done when**: `BUILD SUCCEEDED`
- **Commit**: `chore(ios): fix compilation issues` (only if fixes needed)

### 1.13 Create SkillDetailView and ViewModel

- **Do**:
  1. Create `ILSApp/ILSApp/ViewModels/SkillDetailViewModel.swift`:
     - Takes a `Skill` (or skill name) as init param
     - `@Published` properties: skill, rawContent, isLoading, isEditing, editedContent, error
     - `loadDetail()`: GET `/skills/{name}` to fetch full content
     - `deleteSkill()`: DELETE `/skills/{name}` with confirmation
     - `saveEdits()`: PUT `/skills/{name}` with updated content
  2. Create `ILSApp/ILSApp/Views/Skills/SkillDetailView.swift`:
     - Header: icon, name, version, author, star count, last updated
     - Description section
     - SKILL.md Preview section in monospace font ScrollView
     - "Uninstall" button (red destructive) with confirmation alert
     - "Edit SKILL.md" button (secondary style) toggles inline TextEditor
     - Save button appears when editing
     - Navigation title = skill name
- **Files**:
  - Create: `ILSApp/ILSApp/ViewModels/SkillDetailViewModel.swift`
  - Create: `ILSApp/ILSApp/Views/Skills/SkillDetailView.swift`
- **Done when**: iOS app compiles; SkillDetailView exists
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Commit**: `feat(ios): add SkillDetailView with SKILL.md preview, edit, and uninstall`
- _Requirements: FR-17, US-8, AC-8.1 through AC-8.7_
- _Design: SkillDetailView_

### 1.14 Enhance SkillsListView with GitHub search and navigation to detail

- **Do**:
  1. Update `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift`:
     - Add `@Published var gitHubResults: [GitHubSearchResult] = []`
     - Add `@Published var isSearching = false`
     - Add `@Published var gitHubSearchText = ""`
     - Add `searchGitHub(query:)`: GET `/skills/search?q={query}`, debounced 300ms
     - Add `installSkill(result:)`: POST `/skills/install` with SkillInstallRequest, on success add to skills list
     - Change `[SkillItem]` to `[Skill]` throughout (use ILSShared's Skill, not the local SkillItem)
  2. Update `ILSApp/ILSApp/Views/Skills/SkillsListView.swift`:
     - Add search bar at bottom of installed list with accent border on focus
     - Add "Discovered from GitHub" section showing `gitHubResults`
     - Each GitHub result: repo name, description, star count, orange "Install" button
     - Install button shows spinner during install, transitions to "Installed" on success
     - Tap installed skill -> NavigationLink to SkillDetailView
     - Update all `SkillItem` references to `Skill`
- **Files**:
  - Modify: `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift`
  - Modify: `ILSApp/ILSApp/Views/Skills/SkillsListView.swift`
- **Done when**: iOS compiles; SkillsListView has GitHub search section and navigates to SkillDetailView
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Commit**: `feat(ios): add GitHub skill search and SkillDetailView navigation to SkillsListView`
- _Requirements: FR-18, US-5, US-6, US-7, AC-5.1 through AC-7.5_
- _Design: SkillsListView GitHub search, SkillDetailView navigation_

### 1.15 Enhance MCPServerListView with scope tabs and CRUD

- **Do**:
  1. Update `ILSApp/ILSApp/ViewModels/MCPViewModel.swift`:
     - Add `@Published var selectedScope: MCPScope = .user`
     - Add `loadServers(scope:)` calling GET `/mcp?scope={scope}`
     - Add `updateServer(name:request:)` calling PUT `/mcp/{name}`
     - Add `deleteServer(name:scope:)` calling DELETE `/mcp/{name}?scope={scope}`
  2. Create `ILSApp/ILSApp/Views/MCP/AddMCPServerView.swift`:
     - Sheet form: name, command, args (comma-separated), env key-value pairs, scope picker
     - Radio toggle: "Custom Command" (only option for POC)
     - Form validation: name and command required
     - Submit calls POST `/mcp`
  3. Create `ILSApp/ILSApp/Views/MCP/EditMCPServerView.swift`:
     - Pre-filled form with existing server data
     - Save calls PUT `/mcp/{name}`
  4. Update `ILSApp/ILSApp/Views/MCP/MCPServerListView.swift`:
     - Add scope tabs (Picker with segmented style): User / Project / Local
     - Orange accent underline on active tab
     - Per-server action buttons: Edit (sheet), Delete (confirmation)
     - "Add Server" button in toolbar opening AddMCPServerView sheet
     - Env vars displayed masked (show *** for values)
- **Files**:
  - Modify: `ILSApp/ILSApp/ViewModels/MCPViewModel.swift`
  - Create: `ILSApp/ILSApp/Views/MCP/AddMCPServerView.swift`
  - Create: `ILSApp/ILSApp/Views/MCP/EditMCPServerView.swift`
  - Modify: `ILSApp/ILSApp/Views/MCP/MCPServerListView.swift`
- **Done when**: iOS compiles; MCP list shows scope tabs with Add/Edit/Delete actions
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Commit**: `feat(ios): add MCP scope tabs, Add/Edit server forms, and CRUD actions`
- _Requirements: FR-19, US-9, US-10, US-11, AC-9.1 through AC-11.5_
- _Design: MCPServerListView scope tabs, AddMCPServerView, EditMCPServerView_

### 1.16 [VERIFY] iOS mid-build quality checkpoint

- **Do**: Full iOS build after MCP + Skills changes
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Done when**: `BUILD SUCCEEDED`
- **Commit**: `chore(ios): fix mid-build compilation issues` (only if fixes needed)

### 1.17 Create PluginMarketplaceView and enhance PluginsListView

- **Do**:
  1. Update `ILSApp/ILSApp/ViewModels/PluginsViewModel.swift`:
     - Add `@Published var marketplacePlugins: [PluginSearchResult] = []`
     - Add `@Published var marketplaceSearchText = ""`
     - Add `@Published var selectedCategory: String = "All"`
     - Add `searchPlugins(query:)`: GET `/plugins/search?q={query}`
     - Add `installPlugin(result:)`: POST `/plugins/install`
     - Add `addMarketplace(repo:)`: POST `/marketplaces`
  2. Create `ILSApp/ILSApp/Views/Plugins/PluginMarketplaceView.swift`:
     - Sheet modal view
     - Search bar at top with placeholder "Search plugins..."
     - Category filter chips (horizontal ScrollView): All, Productivity, DevOps, Testing, Documentation
     - Official Marketplace section from GET `/plugins/marketplace`
     - Plugin cards: name, description, star count, source badge (Official/Community)
     - Install button (accent orange) / "Installed" badge (muted)
     - "Add from GitHub repo" button at bottom with input field for `owner/repo`
  3. Update `ILSApp/ILSApp/Views/Plugins/PluginsListView.swift`:
     - Add toolbar button "Marketplace" opening PluginMarketplaceView as sheet
     - Existing installed plugins list remains
- **Files**:
  - Modify: `ILSApp/ILSApp/ViewModels/PluginsViewModel.swift`
  - Create: `ILSApp/ILSApp/Views/Plugins/PluginMarketplaceView.swift`
  - Modify: `ILSApp/ILSApp/Views/Plugins/PluginsListView.swift`
- **Done when**: iOS compiles; PluginMarketplaceView opens from PluginsListView
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Commit**: `feat(ios): add PluginMarketplaceView with search, categories, and install`
- _Requirements: FR-20, US-12, US-13, US-14, AC-12.1 through AC-14.5_
- _Design: PluginMarketplaceView, PluginsListView marketplace button_

### 1.18 Enhance SettingsView with JSON editor and Quick Settings

- **Do**:
  1. Update `ILSApp/ILSApp/Views/Settings/SettingsView.swift`:
     - Add scope Picker at top: User / Project / Local
     - Add TextEditor with monospace font showing raw JSON from GET `/config?scope={scope}`
     - Add real-time JSON validation indicator: green checkmark "Valid JSON" or red X with error
     - Add "Save Changes" button (accent orange) calling PUT `/config` with scope and content
     - Add validation on change via local JSON parsing (no need for server round-trip in POC)
     - Add Quick Settings section below:
       - Model picker (claude-sonnet-4, claude-opus-4)
       - Extended Thinking toggle
       - Co-authored-by toggle
     - Quick Setting changes update the rawJSON in-place
     - Add "Server Connection" NavigationLink to ServerConnectionView
  2. POC shortcut: JSON validation done client-side via `JSONSerialization.isValidJSONObject`; skip server-side `/config/validate` call
- **Files**:
  - Modify: `ILSApp/ILSApp/Views/Settings/SettingsView.swift`
- **Done when**: iOS compiles; SettingsView shows JSON editor with scope picker
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Commit**: `feat(ios): add JSON config editor, scope selector, and Quick Settings to SettingsView`
- _Requirements: FR-21, US-15, US-16, AC-15.1 through AC-16.6_
- _Design: SettingsView JSON editor + Quick Settings_

### 1.19 Enhance DashboardView with Quick Actions and Activity feed

- **Do**:
  1. Update `ILSApp/ILSApp/ViewModels/DashboardViewModel.swift`:
     - Add `quickActions` computed property returning 4 items: (title, icon, tab) tuples
     - Recent activity already loads from `GET /stats/recent` -- format as activity feed
  2. Update `ILSApp/ILSApp/Views/Dashboard/DashboardView.swift`:
     - Below stat cards, add "Quick Actions" section header
     - 4 rows: "Discover Skills" (star icon), "Browse Plugins" (puzzlepiece), "Configure MCP" (server.rack), "Edit Settings" (gear)
     - Each row taps to set `appState.selectedTab`
     - Add "Recent Activity" section below Quick Actions showing recentSessions as timeline
     - Each activity item: session name, timestamp, status icon
     - Stat card counts use accent orange color for the number
- **Files**:
  - Modify: `ILSApp/ILSApp/ViewModels/DashboardViewModel.swift`
  - Modify: `ILSApp/ILSApp/Views/Dashboard/DashboardView.swift`
- **Done when**: iOS compiles; Dashboard shows Quick Actions and activity feed
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Commit**: `feat(ios): add Quick Actions and Recent Activity feed to DashboardView`
- _Requirements: FR-16, US-3, AC-3.1 through AC-3.5_
- _Design: DashboardView Quick Actions + Activity_

### 1.20 Unify SkillItem -> Skill across iOS app

- **Do**:
  1. Delete the `SkillItem` struct from `ILSApp/ILSApp/Views/Chat/CommandPaletteView.swift` (lines 128-155)
  2. Add `import ILSShared` where needed
  3. Add `Hashable` conformance to `Skill` in ILSShared if not already done in 1.2
  4. Replace all `SkillItem` references with `Skill` across:
     - `CommandPaletteView.swift`
     - `SkillsViewModel.swift` (already done in 1.14)
     - `SkillsListView.swift` (already done in 1.14)
  5. Handle any property differences (`source` was `String?` in SkillItem, is `SkillSource` in Skill) -- adjust decoding
- **Files**:
  - Modify: `ILSApp/ILSApp/Views/Chat/CommandPaletteView.swift`
  - Possibly modify: `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift`
- **Done when**: No `SkillItem` references remain; app compiles
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep -c 'SkillItem' && echo "Should be 0"`
- **Commit**: `refactor(ios): unify SkillItem to Skill from ILSShared`
- _Requirements: FR-33_
- _Design: Technical Decisions - SkillItem unification_

### 1.21 [VERIFY] Full build checkpoint (backend + iOS)

- **Do**: Build both targets to verify everything compiles
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -3`
- **Done when**: Both targets compile successfully
- **Commit**: `chore: fix full build issues` (only if fixes needed)

### 1.22 POC Checkpoint: E2E validation with real data

- **Do**:
  1. Start backend: `PORT=9090 swift run ILSBackend &`
  2. Build and install iOS app on simulator
  3. Verify via automated commands:
     - `curl localhost:9090/health | jq .status` -- "ok"
     - `curl localhost:9090/api/v1/stats | jq .success` -- true
     - `curl localhost:9090/api/v1/skills | jq '.data.total'` -- non-zero
     - `curl localhost:9090/api/v1/mcp | jq '.data.total'` -- non-zero
     - `curl 'localhost:9090/api/v1/server/status' | jq .` -- returns JSON
     - `curl -X POST localhost:9090/api/v1/auth/connect -H 'Content-Type: application/json' -d '{"host":"localhost","port":22,"username":"test","authMethod":"password","credential":"test"}' | jq .` -- returns JSON response
  4. Launch app on simulator, take screenshot of Dashboard
  5. Navigate to Skills, take screenshot showing list
  6. Navigate to MCP Servers, take screenshot showing scope tabs
  7. Navigate to Settings, take screenshot showing JSON editor
  8. Verify all 12 existing screens still render (no regression)
- **Done when**: Backend serves all endpoints; iOS app launches and displays all views with real data
- **Verify**: `curl localhost:9090/health | jq .status`
- **Commit**: `feat(ils): complete POC -- all features compiling with real backend data`
- _Requirements: All P0 + P1 FRs_
- _Design: All Phases 1-4_

---

## Phase 2: Refactoring

After POC validated, clean up code structure and error handling.

### 2.1 Extract and modularize backend services

- **Do**:
  1. Extract SSHService storage into Vapor's `Application.Storage` pattern for proper lifecycle
  2. Add GitHubService as proper dependency in controllers (not re-instantiated per request)
  3. Add rate limit header checking in GitHubService (`X-RateLimit-Remaining`)
  4. Add proper error types for SSH connection failures
  5. Ensure all new controllers use `@Sendable` on route handlers
- **Files**:
  - Modify: `Sources/ILSBackend/Services/SSHService.swift`
  - Modify: `Sources/ILSBackend/Services/GitHubService.swift`
  - Modify: `Sources/ILSBackend/Controllers/AuthController.swift`
  - Modify: `Sources/ILSBackend/Controllers/SkillsController.swift`
- **Done when**: Backend compiles; services properly lifecycle-managed
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -5`
- **Commit**: `refactor(backend): extract service singletons and add rate limit handling`
- _Design: SSHService NIO conflict mitigation, GitHubService rate limiting_

### 2.2 Add comprehensive error handling to iOS ViewModels

- **Do**:
  1. Add retry with exponential backoff (3 attempts) to all new ViewModel network calls
  2. Add proper loading/error states to ServerConnectionViewModel, SkillDetailViewModel
  3. Add debounced search (300ms) to SkillsViewModel.searchGitHub using Combine/Task delay
  4. Add unsaved changes warning to SettingsView JSON editor (alert on navigate away)
  5. Ensure all ViewModels follow pattern: `isLoading = true; error = nil; do { ... } catch { self.error = error }; isLoading = false`
- **Files**:
  - Modify: `ILSApp/ILSApp/ViewModels/ServerConnectionViewModel.swift`
  - Modify: `ILSApp/ILSApp/ViewModels/SkillDetailViewModel.swift`
  - Modify: `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift`
  - Modify: `ILSApp/ILSApp/Views/Settings/SettingsView.swift`
- **Done when**: All ViewModels have consistent error handling; debounce works on search
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Commit**: `refactor(ios): add comprehensive error handling and debounced search`
- _Design: Error Handling patterns_

### 2.3 Create ConfigurationManager service

- **Do**:
  1. Create `ILSApp/ILSApp/Services/ConfigurationManager.swift`:
     - `@MainActor class ConfigurationManager: ObservableObject`
     - `@Published var currentScope`, `rawJSON`, `validationStatus`, `hasUnsavedChanges`
     - `loadConfig(scope:)`: GET `/config?scope={scope}`
     - `validateJSON(_:)`: POST `/config/validate`
     - `saveChanges()`: PUT `/config` with scope and content
     - `updateQuickSetting(key:value:)`: updates rawJSON string in-place
  2. Integrate into SettingsView to replace inline logic
- **Files**:
  - Create: `ILSApp/ILSApp/Services/ConfigurationManager.swift`
  - Modify: `ILSApp/ILSApp/Views/Settings/SettingsView.swift`
- **Done when**: SettingsView uses ConfigurationManager; server-side validation works
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Commit**: `refactor(ios): extract ConfigurationManager for settings lifecycle`
- _Requirements: FR-24_
- _Design: ConfigurationManager_

### 2.4 [VERIFY] Quality checkpoint after refactoring

- **Do**: Build both backend and iOS
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -3`
- **Done when**: Both targets compile with zero errors
- **Commit**: `chore: pass refactoring quality checkpoint` (only if fixes needed)

---

## Phase 3: Functional Validation

Real UI validation with simulator screenshots. No mocks, no stubs, no unit tests.

### 3.1 Validate backend endpoints with cURL

- **Do**:
  1. Start backend: `PORT=9090 swift run ILSBackend`
  2. Test all existing endpoints:
     - `curl localhost:9090/health | jq .`
     - `curl localhost:9090/api/v1/stats | jq .success`
     - `curl localhost:9090/api/v1/skills | jq '.data.total'`
     - `curl localhost:9090/api/v1/mcp | jq '.data.total'`
     - `curl localhost:9090/api/v1/plugins | jq '.data.total'`
     - `curl localhost:9090/api/v1/config | jq .success`
     - `curl localhost:9090/api/v1/sessions | jq .success`
     - `curl localhost:9090/api/v1/projects | jq .success`
  3. Test all new endpoints:
     - `curl localhost:9090/api/v1/server/status | jq .`
     - `curl -X POST localhost:9090/api/v1/auth/connect -H 'Content-Type: application/json' -d '{"host":"localhost","port":22,"username":"test","authMethod":"password","credential":"test"}' | jq .`
     - `curl 'localhost:9090/api/v1/skills/search?q=code-review' | jq .` (requires GITHUB_TOKEN)
     - `curl -X POST localhost:9090/api/v1/skills/install -H 'Content-Type: application/json' -d '{"repository":"anthropics/claude-code-skills"}' | jq .`
     - `curl -X PUT localhost:9090/api/v1/mcp/test -H 'Content-Type: application/json' -d '{"name":"test","command":"echo"}' | jq .`
     - `curl 'localhost:9090/api/v1/plugins/search?q=github' | jq .`
     - `curl -X POST localhost:9090/api/v1/marketplaces -H 'Content-Type: application/json' -d '{"source":"github","repo":"test/test"}' | jq .`
  4. Record pass/fail for each endpoint
- **Done when**: All existing endpoints return success; all new endpoints return valid JSON (success or meaningful error)
- **Verify**: `curl localhost:9090/health | jq .status`
- **Commit**: `chore(backend): verify all API endpoints respond correctly`
- _Requirements: FR-1 through FR-10_

### 3.2 Validate iOS screens with simulator screenshots

- **Do**:
  1. Build and install iOS app on simulator UDID `50523130-57AA-48B0-ABD0-4D59CE455F14`
  2. Boot simulator if needed: `xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14`
  3. Launch app: `xcrun simctl launch 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app`
  4. Take screenshots of all screens via `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot`:
     - Dashboard (with Quick Actions + Activity)
     - Sessions List
     - Skills List (with search bar area)
     - MCP Servers (with scope tabs)
     - Plugins List
     - Settings (with JSON editor)
     - Sidebar
     - Chat View
  5. Verify color tokens visually: accent should be #FF6B35 orange, backgrounds should be pure black (#000000)
  6. Compare against previous 12 validated screens to check for regression
- **Done when**: All screens render correctly; no visual regressions
- **Verify**: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /tmp/ils-dashboard.png && ls -la /tmp/ils-dashboard.png`
- **Commit**: `chore(ios): capture validation screenshots for all screens`
- _Requirements: FR-15 through FR-22, US-18_

### 3.3 Validate new view navigation flows

- **Do**:
  1. Verify Dashboard Quick Actions navigate to correct tabs
  2. Verify Skills -> tap skill -> SkillDetailView renders
  3. Verify MCP -> scope tab switching loads different server lists
  4. Verify MCP -> Add Server sheet opens and closes
  5. Verify Plugins -> Marketplace button opens PluginMarketplaceView sheet
  6. Verify Settings -> scope picker changes JSON content
  7. Verify Settings -> Server Connection link navigates to ServerConnectionView
  8. Take screenshot evidence for each navigation flow
- **Done when**: All navigation paths work; evidence captured
- **Verify**: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /tmp/ils-nav-test.png && ls -la /tmp/ils-nav-test.png`
- **Commit**: `chore(ios): validate all navigation flows with screenshot evidence`
- _Requirements: AC-3.2, AC-5.4, AC-9.1, AC-10.1, AC-12.1, AC-15.1_

### 3.4 [VERIFY] Quality checkpoint after validation

- **Do**: Confirm both targets build and all screenshots captured
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -3`
- **Done when**: Both build; validation evidence exists
- **Commit**: `chore: pass validation quality checkpoint` (only if fixes needed)

---

## Phase 4: Quality Gates + App Store Prep

### 4.1 Create IndexingService and cache migration

- **Do**:
  1. Create `Sources/ILSBackend/Migrations/CreateCachedResults.swift`:
     - Table: `cached_results` with columns: id, query, result_json, created_at, expires_at
  2. Create `Sources/ILSBackend/Services/IndexingService.swift` as actor:
     - `cacheSearchResults(query:results:)` -- store with 1hr TTL
     - `getCachedResults(query:maxAge:)` -- return if not expired
     - `pruneExpired()` -- delete expired rows
  3. Register migration in `configure.swift`
  4. Integrate into GitHubService: check cache before API call
- **Files**:
  - Create: `Sources/ILSBackend/Migrations/CreateCachedResults.swift`
  - Create: `Sources/ILSBackend/Services/IndexingService.swift`
  - Modify: `Sources/ILSBackend/App/configure.swift`
  - Modify: `Sources/ILSBackend/Services/GitHubService.swift`
- **Done when**: Backend compiles; cached results table created on startup
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -5`
- **Commit**: `feat(backend): add IndexingService with SQLite cache and CreateCachedResults migration`
- _Requirements: FR-12_
- _Design: IndexingService_

### 4.2 Add Privacy Manifest and App Store metadata

- **Do**:
  1. Create or update `ILSApp/ILSApp/PrivacyInfo.xcprivacy`:
     - NSPrivacyAccessedAPITypes: file timestamp API (for session dates), user defaults API
     - NSPrivacyTracking: false
     - NSPrivacyTrackingDomains: empty
  2. Verify `Info.plist` has:
     - NSLocalNetworkUsageDescription (for backend connection)
     - URL scheme `ils://` registered
  3. Verify bundle ID is `com.ils.app`
  4. Add accessibility labels to all new interactive elements:
     - ServerConnectionView form fields
     - SkillDetailView buttons
     - MCP Add/Edit forms
     - Plugin Marketplace install buttons
     - Settings JSON editor
  5. Ensure all images have accessibility descriptions
- **Files**:
  - Create/Modify: `ILSApp/ILSApp/PrivacyInfo.xcprivacy`
  - Modify: New views (add `.accessibilityLabel()` to buttons/fields)
- **Done when**: Privacy manifest exists; all new interactive elements have accessibility labels
- **Verify**: `ls /Users/nick/Desktop/ils-ios/ILSApp/ILSApp/PrivacyInfo.xcprivacy && echo "exists"`
- **Commit**: `feat(ios): add Privacy Manifest and accessibility labels for App Store compliance`
- _Requirements: NFR-1, NFR-7_

### 4.3 Connection status polling and reconnection

- **Do**:
  1. Add server status polling to AppState:
     - When `isServerConnected`, poll `GET /server/status` every 30 seconds
     - Green dot when healthy, red dot when connection lost
     - On connection loss: attempt reconnect 3 times with exponential backoff
  2. Show connection indicator in sidebar/toolbar
  3. Handle app backgrounding: stop polling, reconnect on foreground via `scenePhase`
- **Files**:
  - Modify: `ILSApp/ILSApp/ILSAppApp.swift`
  - Modify: `ILSApp/ILSApp/Views/Sidebar/SidebarView.swift`
- **Done when**: Connection status shows in sidebar; auto-reconnect works
- **Verify**: `cd /Users/nick/Desktop/ils-ios && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
- **Commit**: `feat(ios): add server connection status polling and auto-reconnect`
- _Requirements: US-2, AC-2.1 through AC-2.4_

### 4.4 [VERIFY] Full local CI

- **Do**: Run complete build verification
- **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build --target ILSBackend 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -3`
- **Done when**: Both targets build successfully with zero errors and zero warnings on new code
- **Commit**: `chore: pass local CI` (only if fixes needed)

### 4.5 Create PR and verify CI

- **Do**:
  1. Verify current branch is feature branch: `git branch --show-current`
  2. If on default branch, STOP and alert user
  3. Stage all changes: `git add` specific files (not -A)
  4. Push branch: `git push -u origin $(git branch --show-current)`
  5. Create PR: `gh pr create --title "feat: ILS complete rebuild - SSH, GitHub integration, enhanced views" --body "..."`
  6. Wait for CI: `gh pr checks --watch`
- **Verify**: `gh pr checks` shows all green
- **Done when**: PR created; CI passes
- **If CI fails**: Read failures with `gh pr checks`, fix locally, push, re-verify

### 4.6 [VERIFY] AC checklist

- **Do**: Programmatically verify each acceptance criteria by checking code/tests/behavior:
  1. AC-1.x: ServerConnectionView exists with form fields
  2. AC-2.x: Connection status polling in AppState
  3. AC-3.x: Dashboard has Quick Actions + Activity
  4. AC-5.x through AC-8.x: Skills search, install, detail view
  5. AC-9.x through AC-11.x: MCP scope tabs, CRUD
  6. AC-12.x through AC-14.x: Plugin marketplace
  7. AC-15.x through AC-16.x: Settings JSON editor + Quick Settings
  8. AC-17.x: Existing features preserved (check files unchanged)
  9. AC-18.x: Theme tokens match spec values
- **Verify**: Grep codebase for key implementations; verify file existence
- **Done when**: All acceptance criteria confirmed met
- **Commit**: None

---

## Phase 5: PR Lifecycle

### 5.1 Monitor CI pipeline

- **Do**:
  1. Check PR status: `gh pr checks`
  2. If any check fails, read error details
  3. Fix issues locally, commit, push
  4. Re-check: `gh pr checks --watch`
- **Done when**: All CI checks green
- **Verify**: `gh pr checks`
- **Commit**: `fix: address CI failures` (if needed)

### 5.2 Address code review feedback

- **Do**:
  1. Check for review comments: `gh pr view --comments`
  2. Address each comment with code changes
  3. Push fixes
  4. Re-verify CI passes
- **Done when**: All review comments addressed; CI green
- **Verify**: `gh pr checks`
- **Commit**: `fix: address review feedback` (per round)

### 5.3 Final E2E validation

- **Do**:
  1. Pull latest from PR branch
  2. Build and run backend + iOS app
  3. Validate all new features work with real data:
     - Dashboard: Quick Actions navigate correctly
     - Skills: search bar, GitHub results (if GITHUB_TOKEN available), detail view
     - MCP: scope tabs switch, Add/Edit/Delete work
     - Plugins: marketplace opens, search works
     - Settings: JSON editor loads, validates, saves
     - Server Connection: form renders, submission works
  4. Verify all 12 existing screens still work (no regression)
  5. Capture final screenshot evidence
- **Done when**: All features verified with real data; no regressions
- **Verify**: `curl localhost:9090/health | jq .status`
- **Commit**: `chore: final E2E validation passed`

### 5.4 [VERIFY] Final acceptance

- **Do**:
  1. Verify zero test regressions (no existing tests should break)
  2. Verify code is modular and follows existing patterns
  3. Verify CI checks green
  4. Verify all acceptance criteria met
  5. Verify Privacy Manifest exists
  6. Verify accessibility labels on new views
- **Verify**: `gh pr checks && echo "All green"`
- **Done when**: PR ready to merge; all completion criteria met
- **Commit**: None

---

## Notes

### POC shortcuts taken (Phase 1)
- GitHub skill install uses raw content fetch instead of `git clone --depth 1`
- JSON config validation done client-side only (no server-side `/config/validate` call)
- Plugin search filters installed plugins only (no cross-marketplace search)
- SSHService connection may not work without a real SSH target -- returns error gracefully
- IndexingService deferred to Phase 4.1
- No server-side debounce on search endpoints

### Production TODOs (Phase 2+)
- Implement git clone for skill install (supports sibling files)
- Add server-side config validation
- Cross-marketplace plugin search
- Rate limit handling with UI feedback
- Connection status polling with exponential backoff
- Proper iOS SSH client (Citadel on iOS -- sandbox testing needed)
- App Store archive build validation

### File count summary
- **New files**: 18 (8 backend, 7 iOS views/VMs, 3 shared models)
- **Modified files**: 22+ (controllers, models, views, ViewModels, theme, routes, configure)
- **New API endpoints**: 8
- **Total tasks**: 42

### Unresolved Questions
- **Citadel on iOS sandbox**: Does Citadel SSH work within iOS app sandbox? If not, SSH must be backend-proxy only. Test during Phase 1.4.
- **GITHUB_TOKEN availability**: Search endpoint requires token for reasonable rate limits. Without it, only 10 req/min. Graceful degradation needed.
- **Git availability on backend host**: `POST /skills/install` via git clone needs `git` binary. POC uses raw content fetch as fallback.
