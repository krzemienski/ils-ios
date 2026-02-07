# Design: ILS Complete Rebuild

## Overview

Incremental enhancement of the existing ILS iOS monorepo (ILSApp + ILSBackend + ILSShared) to close all spec gaps while preserving the 12 validated beyond-spec screens. Adds SSH/Citadel connectivity, GitHub skill/plugin discovery, enhanced CRUD views (MCP scope tabs, plugin marketplace, settings JSON editor, skill detail), and aligns the design system to spec tokens. No architectural rewrites -- extends existing MVVM + Vapor patterns.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     iOS App (ILSApp)                        │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │   Views/VMs  │  │  APIClient   │  │   SSHService     │  │
│  │  (SwiftUI)   │──│  (REST/SSE)  │  │  (Citadel)       │  │
│  └──────────────┘  └──────┬───────┘  └────────┬─────────┘  │
│                           │                    │            │
│  ┌──────────────┐  ┌──────┴───────┐  ┌────────┴─────────┐  │
│  │  SSEClient   │  │  ConfigMgr   │  │  KeychainService │  │
│  │ (streaming)  │  │  (settings)  │  │  (secrets)       │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└──────────────────────────┬──────────────────┬───────────────┘
                           │ REST/SSE         │ SSH (Citadel)
                           │ :9090            │ :22
┌──────────────────────────┴──────────────────┴───────────────┐
│                   Vapor Backend (ILSBackend)                 │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    Controllers                         │ │
│  │  Auth │ Stats │ Skills │ MCP │ Plugins │ Config │ ...  │ │
│  └───────────────────────┬────────────────────────────────┘ │
│                          │                                  │
│  ┌───────────┐ ┌─────────┴──────┐ ┌──────────┐ ┌────────┐ │
│  │FileSystem │ │  GitHubService │ │SSHService│ │Indexing│ │
│  │ Service   │ │  (GitHub API)  │ │(Citadel) │ │Service │ │
│  └─────┬─────┘ └───────┬────────┘ └────┬─────┘ └───┬────┘ │
│        │               │               │           │      │
│  ┌─────┴─────┐  ┌──────┴───────┐  ┌────┴────┐ ┌───┴────┐ │
│  │~/.claude/ │  │ GitHub REST  │  │ Remote  │ │SQLite  │ │
│  │ (local)   │  │ API          │  │ Server  │ │(cache) │ │
│  └───────────┘  └──────────────┘  └─────────┘ └────────┘ │
│                                                             │
│  Preserved: ClaudeExecutor │ StreamingService │ WebSocket   │
└─────────────────────────────────────────────────────────────┘
```

**Data source routing**: FileSystemService for local ops (default). SSHService for remote ops when a ServerConnection is active. GitHubService for discovery. All coexist -- no replacement.

## Components

### New Backend Services

#### SSHService (P0)

**Purpose**: Citadel-based SSH client for remote server operations
**Location**: `Sources/ILSBackend/Services/SSHService.swift`

```swift
import Citadel
import NIO

actor SSHService {
    private var client: SSHClient?
    private var connectionInfo: ServerConnection?

    func connect(host: String, port: Int, username: String,
                 authMethod: SSHAuthMethod) async throws -> ConnectionResponse

    func disconnect() async

    func executeCommand(_ command: String) async throws -> CommandResult

    func readFile(path: String) async throws -> String

    func writeFile(path: String, content: String) async throws

    func isConnected() -> Bool

    func getServerStatus() async throws -> ServerStatus
}

enum SSHAuthMethod {
    case password(String)
    case publicKey(privateKey: String, passphrase: String?)
}

struct CommandResult: Codable, Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int
}

struct ServerStatus: Codable, Sendable {
    let connected: Bool
    let claudeVersion: String?
    let uptime: TimeInterval?
    let configPaths: ClaudeConfigPaths?
}
```

**NIO conflict mitigation**: Citadel already builds on SwiftNIO SSH which Vapor also uses. Share the same EventLoopGroup from `app.eventLoopGroup` -- do NOT create a separate one. This avoids the conflict that broke ClaudeCodeSDK.

#### GitHubService (P1)

**Purpose**: Search GitHub Code API for SKILL.md files and plugin marketplaces
**Location**: `Sources/ILSBackend/Services/GitHubService.swift`

```swift
import Vapor

struct GitHubService {
    let client: Vapor.Client
    let token: String?  // From Environment.get("GITHUB_TOKEN")

    func searchSkills(query: String, page: Int, perPage: Int)
        async throws -> GitHubCodeSearchResponse

    func fetchRawContent(owner: String, repo: String, path: String)
        async throws -> String

    func getRepository(owner: String, repo: String)
        async throws -> GitHubRepository

    func searchPluginMarketplaces(query: String)
        async throws -> [GitHubSearchResult]
}
```

**Rate limiting**: Check `X-RateLimit-Remaining` header. When < 5, return cached results + `rateLimited: true` flag. With token: 30 req/min for code search. Without: 10 req/min.

#### IndexingService (P2)

**Purpose**: SQLite-backed cache for discovered skills/plugins with TTL
**Location**: `Sources/ILSBackend/Services/IndexingService.swift`

```swift
actor IndexingService {
    func cacheSearchResults(query: String, results: [GitHubSearchResult]) async
    func getCachedResults(query: String, maxAge: TimeInterval) async -> [GitHubSearchResult]?
    func cacheSkillContent(repository: String, content: String) async
    func getCachedSkillContent(repository: String) async -> String?
    func pruneExpired() async
}
```

Uses Fluent with a new `CachedSearchResult` migration. TTL: 1 hour for search results, 24 hours for raw content.

### New Backend Controller

#### AuthController (P0)

**Location**: `Sources/ILSBackend/Controllers/AuthController.swift`

```swift
import Vapor

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("connect", use: connect)       // POST /auth/connect
        auth.post("disconnect", use: disconnect)  // POST /auth/disconnect
    }

    // POST /auth/connect
    // Body: { host, port, username, authMethod, credential }
    // Returns: { success, sessionId, serverInfo }
    func connect(req: Request) async throws -> ConnectionResponse

    // POST /auth/disconnect
    func disconnect(req: Request) async throws -> AcknowledgedResponse
}
```

### Modified Backend Controllers

#### SkillsController -- add search + install (P1)

New routes:
- `GET /skills/search?q={query}` -- proxies to GitHubService
- `POST /skills/install` -- clones repo, extracts SKILL.md
- `GET /skills/:name` -- returns single skill with full content (already exists, verify rawContent)
- `PUT /skills/:name` -- update skill content (already exists)

#### MCPController -- add update (P1)

New route:
- `PUT /mcp/:name` -- update existing MCP server configuration

#### PluginsController -- add search + marketplace (P1)

New routes:
- `GET /plugins/search?q={query}` -- search across registered marketplaces
- `POST /marketplaces` -- register custom marketplace from GitHub repo

#### StatsController -- add server status (P0)

New route:
- `GET /server/status` -- returns SSH connection health, Claude version, uptime

### New Shared Models (ILSShared)

#### ServerConnection.swift (P0)

```swift
public struct ServerConnection: Codable, Identifiable, Sendable {
    public let id: UUID
    public var host: String
    public var port: Int
    public var username: String
    public var authMethod: AuthMethod
    public var label: String?
    public var lastConnected: Date?

    public enum AuthMethod: String, Codable, Sendable {
        case password
        case sshKey
    }
}
```

#### SearchResult.swift (P1)

```swift
public struct GitHubCodeSearchResponse: Codable, Sendable {
    public let totalCount: Int
    public let incompleteResults: Bool
    public let items: [GitHubCodeItem]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

public struct GitHubCodeItem: Codable, Sendable {
    public let name: String
    public let path: String
    public let htmlUrl: String
    public let repository: GitHubRepository

    enum CodingKeys: String, CodingKey {
        case name, path
        case htmlUrl = "html_url"
        case repository
    }
}

public struct GitHubRepository: Codable, Identifiable, Sendable {
    public let id: Int
    public let fullName: String
    public let description: String?
    public let stargazersCount: Int
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case description
        case stargazersCount = "stargazers_count"
        case updatedAt = "updated_at"
    }
}

public struct GitHubSearchResult: Codable, Identifiable, Sendable {
    public let id: UUID
    public let repository: String
    public let name: String
    public let description: String?
    public let stars: Int
    public let lastUpdated: String?
    public let skillPath: String?
}

public struct SkillInstallRequest: Codable, Sendable {
    public let repository: String
    public let skillPath: String?
}

public struct PluginSearchResult: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let stars: Int?
    public let source: String  // "official" or "community"
    public let marketplace: String
    public let isInstalled: Bool
}
```

#### ConnectionResponse.swift (P0)

```swift
public struct ConnectionResponse: Codable, Sendable {
    public let success: Bool
    public let sessionId: String?
    public let serverInfo: ServerInfo?
    public let error: String?
}

public struct ServerInfo: Codable, Sendable {
    public let claudeInstalled: Bool
    public let claudeVersion: String?
    public let configPaths: ClaudeConfigPaths?
}

public struct ClaudeConfigPaths: Codable, Sendable {
    public let userSettings: String?     // ~/.claude/settings.json
    public let projectSettings: String?  // .claude/settings.json
    public let localSettings: String?    // .claude/settings.local.json
    public let userMCP: String?          // ~/.mcp.json
    public let skills: String?           // ~/.claude/skills/
}
```

### Modified Shared Models

#### Skill.swift -- add rawContent, enhance source (P1)

```swift
// Add to existing SkillSource enum:
case github  // New case for GitHub-discovered skills

// Add to Skill struct:
public var rawContent: String?  // Full SKILL.md text (rename from content)
public var stars: Int?           // GitHub star count (for discovered skills)
public var author: String?       // Skill author
public var lastUpdated: String?  // ISO8601 date
```

**Migration strategy**: Rename `content` to `rawContent` in Skill struct. The `content` field is already optional and used identically -- just a rename for spec alignment. Update `FileSystemService.parseSkillFile` and `SkillsViewModel` references.

#### Plugin.swift -- add stars, enhance marketplace (P1)

```swift
// Add to Plugin struct:
public var stars: Int?
public var source: PluginSource?
public var category: String?  // "productivity", "devops", "testing", "documentation"

public enum PluginSource: String, Codable, Sendable {
    case official
    case community
}

// Add new Marketplace type (alongside PluginMarketplace):
public struct Marketplace: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let source: String       // "github"
    public let repo: String         // "owner/repo"
    public var plugins: [PluginInfo]
}
```

#### MCPServer.swift -- add managed scope (P2)

```swift
// MCPScope already has user/project/local -- no changes needed for v1
// Managed scope deferred per requirements
```

### New iOS Services

#### SSHService (iOS) (P0)

**Location**: `ILSApp/ILSApp/Services/SSHService.swift`

```swift
import Citadel

actor SSHClientService {
    private var client: SSHClient?

    func connect(host: String, port: Int, username: String,
                 password: String) async throws

    func connect(host: String, port: Int, username: String,
                 privateKey: Data) async throws

    func executeCommand(_ command: String) async throws -> String

    func readFile(path: String) async throws -> String

    func writeFile(path: String, content: String) async throws

    func disconnect() async
}
```

**Note**: iOS SSH is used ALONGSIDE REST, not as replacement. REST for CRUD operations (skills, MCP, plugins, config). SSH for file editing, diffs, stats, direct access.

#### KeychainService (P0)

**Location**: `ILSApp/ILSApp/Services/KeychainService.swift`

```swift
struct KeychainService {
    static func save(key: String, data: Data) throws
    static func load(key: String) throws -> Data?
    static func delete(key: String) throws

    // Convenience methods
    static func savePassword(_ password: String, for server: String) throws
    static func loadPassword(for server: String) throws -> String?
    static func saveSSHKey(_ key: Data, label: String) throws
    static func loadSSHKey(label: String) throws -> Data?
    static func saveToken(_ token: String, key: String) throws
    static func loadToken(key: String) throws -> String?
}
```

Uses `Security.framework` directly. No third-party keychain wrapper needed.

#### ConfigurationManager (P2)

**Location**: `ILSApp/ILSApp/Services/ConfigurationManager.swift`

```swift
@MainActor
class ConfigurationManager: ObservableObject {
    @Published var currentScope: String = "user"
    @Published var configInfo: ConfigInfo?
    @Published var rawJSON: String = ""
    @Published var validationStatus: ValidationStatus = .unknown
    @Published var hasUnsavedChanges: Bool = false

    private var client: APIClient?

    enum ValidationStatus {
        case unknown, valid, invalid(errors: [String])
    }

    func loadConfig(scope: String) async
    func validateJSON(_ json: String) async
    func saveChanges() async throws
    func updateQuickSetting(key: String, value: Any) // Updates rawJSON in-place
}
```

### New iOS Views

#### ServerConnectionView (P0)

**Location**: `ILSApp/ILSApp/Views/ServerConnection/ServerConnectionView.swift`

```
┌─────────────────────────────────┐
│         Connect to Server       │
│                                 │
│  Host: [________________]       │
│  Port: [22_______________]      │
│  User: [________________]       │
│                                 │
│  Auth: (o) Password  ( ) Key    │
│  [________________]             │
│                                 │
│  [████ CONNECT ████]            │
│                                 │
│  Recent Connections:            │
│  🟢 home-server (192.168..)    │
│  ⚪ dev-box (10.0.0.5)         │
└─────────────────────────────────┘
```

**ViewModel**: `ServerConnectionViewModel` -- manages form state, recent connections (UserDefaults for list, Keychain for credentials), connection status.

**Navigation**: Shows as initial screen when no active connection. After connect, navigates to Dashboard. Also accessible from Settings.

#### SkillDetailView (P1)

**Location**: `ILSApp/ILSApp/Views/Skills/SkillDetailView.swift`

```
┌─────────────────────────────────┐
│ < Skills    code-review         │
│                                 │
│  ┌─ Header ────────────────┐    │
│  │  📝 code-review         │    │
│  │  v1.2.0 by anthropic    │    │
│  │  ⭐ 1.2k │ Updated 3d   │    │
│  └─────────────────────────┘    │
│                                 │
│  Description                    │
│  Automated code review...       │
│                                 │
│  SKILL.md Preview               │
│  ┌─────────────────────────┐    │
│  │ ---                     │    │
│  │ name: code-review       │    │
│  │ ---                     │    │
│  │ ## Instructions         │    │
│  └─────────────────────────┘    │
│                                 │
│  [████ UNINSTALL ████]  (red)   │
│  [   Edit SKILL.md   ]  (sec)  │
└─────────────────────────────────┘
```

Uses existing `Skill` model. Edit opens inline `TextEditor` with monospace font. Uninstall shows confirmation alert then calls `DELETE /skills/:name`.

### Modified iOS Views

#### DashboardView -- add Quick Actions + Activity (P1)

Add below existing stat cards:
1. **Quick Actions** section: 4 rows (Discover Skills, Browse Plugins, Configure MCP, Edit Settings) -- each sets `appState.selectedTab`
2. **Recent Activity** feed: `GET /stats/recent` returns last 10 events

#### SkillsListView -- add GitHub search (P1)

Add below installed skills list:
1. Search bar with accent border on focus
2. Debounced search (300ms) calls `GET /skills/search?q=`
3. "Discovered from GitHub" section with `GitHubSearchResult` cards
4. Orange "Install" button per result calling `POST /skills/install`
5. Navigation to `SkillDetailView` on tap

#### MCPServerListView -- add scope tabs + CRUD (P1)

Add:
1. Scope picker (segmented control): User / Project / Local with accent underline
2. Per-server action buttons: Disable, Edit, Delete
3. "Add Server" sheet with radio toggle (Registry / Custom Command)
4. Edit sheet (pre-filled form)
5. `PUT /mcp/:name` for updates

#### PluginsListView -- enhance to marketplace (P1)

Add:
1. Search bar at top
2. Category filter chips (horizontal scroll): All, Productivity, DevOps, Testing, Documentation
3. "Official Marketplace" section from `GET /plugins/marketplace`
4. Install/Installed state per plugin
5. "Add Custom Marketplace" button opening sheet for GitHub repo input

#### SettingsView -- add JSON editor + Quick Settings (P1)

Add:
1. Scope dropdown (User / Project / Local)
2. `TextEditor` with monospace font showing raw JSON
3. Validation indicator: green checkmark or red X with error
4. "Save Changes" button (accent orange)
5. Quick Settings section: Model picker, Extended Thinking toggle, Co-authored-by toggle

### New iOS ViewModels

| ViewModel | Location | Responsibilities |
|-----------|----------|-----------------|
| `ServerConnectionViewModel` | `ViewModels/ServerConnectionViewModel.swift` | Form validation, SSH connect via APIClient, recent connections, connection state |
| `SkillDetailViewModel` | `ViewModels/SkillDetailViewModel.swift` | Load single skill, edit content, delete, SKILL.md preview |

### Modified iOS ViewModels

| ViewModel | Changes |
|-----------|---------|
| `SkillsViewModel` | Add `searchGitHub(query:)`, `installSkill(result:)`, `gitHubResults: [GitHubSearchResult]` |
| `MCPViewModel` | Add `selectedScope`, `addServer()`, `updateServer()`, `deleteServer()` |
| `PluginsViewModel` | Add `searchPlugins(query:)`, `marketplacePlugins`, `installPlugin()`, `addMarketplace()` |
| `DashboardViewModel` | Add `quickActions`, `recentActivity: [ActivityEvent]` |

## Data Flow

### SSH Connection Flow

```
User                iOS App              Backend            Remote Server
 │                    │                    │                    │
 │  Enter creds       │                    │                    │
 │───────────────────>│                    │                    │
 │                    │ POST /auth/connect │                    │
 │                    │───────────────────>│                    │
 │                    │                    │  SSHClient.connect │
 │                    │                    │───────────────────>│
 │                    │                    │  claude --version  │
 │                    │                    │───────────────────>│
 │                    │                    │<───────────────────│
 │                    │  ConnectionResponse│                    │
 │                    │<───────────────────│                    │
 │  Dashboard         │                    │                    │
 │<───────────────────│                    │                    │
 │                    │                    │                    │
 │  (ongoing)         │ GET /server/status │                    │
 │                    │───────────────────>│  ping              │
 │                    │                    │───────────────────>│
```

### GitHub Skill Discovery Flow

```
User                iOS App              Backend            GitHub API
 │                    │                    │                    │
 │  Search "review"   │                    │                    │
 │───────────────────>│                    │                    │
 │                    │ GET /skills/search │                    │
 │                    │  ?q=review         │                    │
 │                    │───────────────────>│                    │
 │                    │                    │ Check IndexCache   │
 │                    │                    │ (miss)             │
 │                    │                    │ GET /search/code   │
 │                    │                    │───────────────────>│
 │                    │                    │<───────────────────│
 │                    │                    │ Cache results      │
 │                    │  [SearchResults]   │                    │
 │                    │<───────────────────│                    │
 │  Show results      │                    │                    │
 │<───────────────────│                    │                    │
 │                    │                    │                    │
 │  Tap "Install"     │                    │                    │
 │───────────────────>│                    │                    │
 │                    │ POST /skills/install                    │
 │                    │───────────────────>│                    │
 │                    │                    │ git clone --depth 1│
 │                    │                    │ Copy SKILL.md      │
 │                    │                    │ Parse + validate   │
 │                    │  Skill object      │                    │
 │                    │<───────────────────│                    │
 │  "Installed" badge │                    │                    │
 │<───────────────────│                    │                    │
```

### MCP CRUD Flow

```
User                iOS App              Backend            Filesystem
 │                    │                    │                    │
 │  Select scope=user │                    │                    │
 │───────────────────>│                    │                    │
 │                    │ GET /mcp?scope=user│                    │
 │                    │───────────────────>│                    │
 │                    │                    │ Read ~/.mcp.json   │
 │                    │                    │───────────────────>│
 │                    │  [MCPServer]       │                    │
 │                    │<───────────────────│                    │
 │                    │                    │                    │
 │  Edit server       │                    │                    │
 │───────────────────>│                    │                    │
 │                    │ PUT /mcp/:name     │                    │
 │                    │───────────────────>│                    │
 │                    │                    │ Update ~/.mcp.json │
 │                    │                    │───────────────────>│
 │                    │  Updated MCPServer │                    │
 │                    │<───────────────────│                    │
```

## API Contract

### Complete Endpoint List

#### Existing (Preserve)

| Method | Path | Controller | Response |
|--------|------|-----------|----------|
| GET | `/health` | routes.swift | `HealthInfo` |
| GET | `/api/v1/stats` | StatsController | `APIResponse<StatsResponse>` |
| GET | `/api/v1/stats/recent` | StatsController | `APIResponse<RecentSessionsResponse>` |
| GET | `/api/v1/skills` | SkillsController | `APIResponse<ListResponse<Skill>>` |
| POST | `/api/v1/skills` | SkillsController | `APIResponse<Skill>` |
| GET | `/api/v1/skills/:name` | SkillsController | `APIResponse<Skill>` |
| PUT | `/api/v1/skills/:name` | SkillsController | `APIResponse<Skill>` |
| DELETE | `/api/v1/skills/:name` | SkillsController | `APIResponse<DeletedResponse>` |
| GET | `/api/v1/mcp` | MCPController | `APIResponse<ListResponse<MCPServer>>` |
| POST | `/api/v1/mcp` | MCPController | `APIResponse<MCPServer>` |
| GET | `/api/v1/mcp/:name` | MCPController | `APIResponse<MCPServer>` |
| DELETE | `/api/v1/mcp/:name` | MCPController | `APIResponse<DeletedResponse>` |
| GET | `/api/v1/plugins` | PluginsController | `APIResponse<ListResponse<Plugin>>` |
| GET | `/api/v1/plugins/marketplace` | PluginsController | `APIResponse<[PluginMarketplace]>` |
| POST | `/api/v1/plugins/install` | PluginsController | `APIResponse<Plugin>` |
| POST | `/api/v1/plugins/enable/:name` | PluginsController | `APIResponse<EnabledResponse>` |
| POST | `/api/v1/plugins/disable/:name` | PluginsController | `APIResponse<EnabledResponse>` |
| DELETE | `/api/v1/plugins/:name` | PluginsController | `APIResponse<DeletedResponse>` |
| GET | `/api/v1/config` | ConfigController | `APIResponse<ConfigInfo>` |
| PUT | `/api/v1/config` | ConfigController | `APIResponse<ConfigInfo>` |
| POST | `/api/v1/config/validate` | ConfigController | `APIResponse<ConfigValidationResult>` |
| GET | `/api/v1/sessions` | SessionsController | `APIResponse<ListResponse<ChatSession>>` |
| POST | `/api/v1/sessions` | SessionsController | `APIResponse<ChatSession>` |
| GET | `/api/v1/sessions/:id` | SessionsController | `APIResponse<ChatSession>` |
| DELETE | `/api/v1/sessions/:id` | SessionsController | `APIResponse<DeletedResponse>` |
| POST | `/api/v1/sessions/:id/fork` | SessionsController | `APIResponse<ChatSession>` |
| GET | `/api/v1/sessions/scan` | SessionsController | `APIResponse<SessionScanResponse>` |
| POST | `/api/v1/chat/stream` | ChatController | SSE stream |
| POST | `/api/v1/chat/ws` | ChatController | WebSocket |
| POST | `/api/v1/chat/:sessionId/cancel` | ChatController | `APIResponse<CancelledResponse>` |
| POST | `/api/v1/chat/:sessionId/permission` | ChatController | `APIResponse<AcknowledgedResponse>` |
| GET | `/api/v1/projects` | ProjectsController | `APIResponse<ListResponse<Project>>` |
| POST | `/api/v1/projects` | ProjectsController | `APIResponse<Project>` |
| GET | `/api/v1/projects/:id` | ProjectsController | `APIResponse<Project>` |
| PUT | `/api/v1/projects/:id` | ProjectsController | `APIResponse<Project>` |
| DELETE | `/api/v1/projects/:id` | ProjectsController | `APIResponse<DeletedResponse>` |
| GET | `/api/v1/projects/:id/sessions` | ProjectsController | `APIResponse<ListResponse<ChatSession>>` |

#### New Endpoints

| Method | Path | Controller | Request Body | Response | Priority |
|--------|------|-----------|-------------|----------|----------|
| POST | `/api/v1/auth/connect` | AuthController | `ConnectRequest` | `ConnectionResponse` | P0 |
| POST | `/api/v1/auth/disconnect` | AuthController | -- | `AcknowledgedResponse` | P0 |
| GET | `/api/v1/server/status` | StatsController | -- | `ServerStatus` | P0 |
| GET | `/api/v1/skills/search` | SkillsController | `?q={query}` | `APIResponse<ListResponse<GitHubSearchResult>>` | P1 |
| POST | `/api/v1/skills/install` | SkillsController | `SkillInstallRequest` | `APIResponse<Skill>` | P1 |
| PUT | `/api/v1/mcp/:name` | MCPController | `CreateMCPRequest` | `APIResponse<MCPServer>` | P1 |
| GET | `/api/v1/plugins/search` | PluginsController | `?q={query}` | `APIResponse<ListResponse<PluginSearchResult>>` | P1 |
| POST | `/api/v1/marketplaces` | PluginsController | `AddMarketplaceRequest` | `APIResponse<Marketplace>` | P1 |

### Request/Response Schemas (New)

```swift
// POST /auth/connect
struct ConnectRequest: Content {
    let host: String
    let port: Int           // default 22
    let username: String
    let authMethod: String  // "password" or "key"
    let credential: String  // password text or base64-encoded key
}

// POST /marketplaces
struct AddMarketplaceRequest: Content {
    let source: String  // "github"
    let repo: String    // "owner/repo"
}

// PUT /mcp/:name -- reuses existing CreateMCPRequest
```

## Navigation Architecture

### Sidebar-First Navigation

```
┌─────────────────────────────┐
│ NavigationStack              │
│                              │
│  ┌───── ContentView ──────┐ │
│  │                         │ │
│  │  [Sidebar Button]       │ │
│  │                         │ │
│  │  ┌─ detailView ──────┐ │ │
│  │  │                    │ │ │
│  │  │ Dashboard          │ │ │
│  │  │ SessionsList       │ │ │
│  │  │ ProjectsList       │ │ │
│  │  │ SkillsList ────────┼─┼─┼── push → SkillDetailView
│  │  │ MCPServerList      │ │ │
│  │  │ PluginsList ───────┼─┼─┼── sheet → PluginMarketplace
│  │  │ Settings           │ │ │
│  │  └────────────────────┘ │ │
│  │                         │ │
│  │  .sheet(SidebarView)    │ │
│  └─────────────────────────┘ │
│                              │
│  Pre-connection:             │
│  ServerConnectionView        │
│  (shown when !isConnected    │
│   && no savedConnections)    │
└─────────────────────────────┘
```

**Key decisions**:
- Sidebar stays as `.sheet` -- proven pattern, works well on iPhone
- `SidebarItem` enum extended to include new sections if needed
- No tab bar (per user decision -- sidebar is primary)
- ServerConnectionView shown conditionally based on connection state
- `appState.selectedTab` drives which view is displayed
- Deep links (`ils://`) already work via `handleURL` -- extend with `ils://connect`

### New Navigation Paths

| From | To | Mechanism |
|------|-----|-----------|
| Dashboard Quick Action | Skills/MCP/Plugins/Settings | `appState.selectedTab = "skills"` |
| SkillsListView | SkillDetailView | `NavigationLink` push |
| SkillsListView search result | SkillDetailView | `NavigationLink` push |
| PluginsListView | PluginMarketplaceView | `.sheet` modal |
| MCPServerListView | AddMCPServerView | `.sheet` modal |
| MCPServerListView | EditMCPServerView | `.sheet` modal |
| Settings | ServerConnectionView | `NavigationLink` push |
| App launch (no connection) | ServerConnectionView | Conditional in ContentView |

## Design System

### Color Tokens -- Spec Custom Values

| Token | Spec Value | Current Value | Action |
|-------|-----------|---------------|--------|
| `accent` (primary) | `#FF6B35` | `#FF6600` | **Change** to `Color(red: 1.0, green: 107/255, blue: 53/255)` |
| `accentSecondary` | `#FF8C5A` | Missing | **Add** `Color(red: 1.0, green: 140/255, blue: 90/255)` |
| `accentTertiary` | `#FF4500` | Missing | **Add** `Color(red: 1.0, green: 69/255, blue: 0)` |
| `background` | `#000000` | `#000000` | Keep |
| `secondaryBackground` | `#0D0D0D` | `#1C1C1E` | **Change** to `Color(red: 13/255, green: 13/255, blue: 13/255)` |
| `tertiaryBackground` | `#1A1A1A` | `#2C2C2E` | **Change** to `Color(red: 26/255, green: 26/255, blue: 26/255)` |
| `primaryText` | `#FFFFFF` | `Color.white` | Keep |
| `secondaryText` | `#A0A0A0` | `#8E8E93` | **Change** to `Color(red: 160/255, green: 160/255, blue: 160/255)` |
| `tertiaryText` | `#666666` | `#48484A` | **Change** to `Color(red: 102/255, green: 102/255, blue: 102/255)` |
| `borderDefault` | `#2A2A2A` | `#262628` | **Change** to `Color(red: 42/255, green: 42/255, blue: 42/255)` |
| `borderActive` | `#FF6B35` | Missing | **Add** (same as accent) |
| `success` | `#4CAF50` | `#34C759` | **Change** to `Color(red: 76/255, green: 175/255, blue: 80/255)` |
| `warning` | `#FFA726` | `#FF9500` | **Change** to `Color(red: 1.0, green: 167/255, blue: 38/255)` |
| `error` | `#EF5350` | `#FF3B30` | **Change** to `Color(red: 239/255, green: 83/255, blue: 80/255)` |

### Corner Radius Alignment

| Spec Name | Spec Value | Current Name | Current Value | Action |
|-----------|-----------|-------------|---------------|--------|
| small | 8pt | `cornerRadiusM` | 8pt | Rename to `cornerRadiusSmall` |
| medium | 12pt | `cornerRadiusL` | 12pt | Rename to `cornerRadiusMedium` |
| large | 16pt | `cornerRadiusXL` | 16pt | Rename to `cornerRadiusLarge` |
| -- | -- | `cornerRadiusS` (4pt) | 4pt | Keep as `cornerRadiusXS` (useful for pills) |

### Typography (No Changes)

Current approach uses SwiftUI dynamic type which is better for accessibility. SF Pro Display Bold for headings via `.system(.title, weight: .bold)` already matches spec intent. Keep as-is.

### New Theme Additions

```swift
// Add to ILSTheme:
static let accentSecondary = Color(red: 1.0, green: 140.0/255.0, blue: 90.0/255.0)
static let accentTertiary = Color(red: 1.0, green: 69.0/255.0, blue: 0.0)
static let borderDefault = Color(red: 42.0/255.0, green: 42.0/255.0, blue: 42.0/255.0)
static let borderActive = accent  // Same as accent.primary
```

### Asset Catalog Decision

**Decision: Keep hardcoded colors in ILSTheme.swift, skip xcassets.**

Rationale:
- Single source of truth in code
- No designer handoff workflow exists
- Theme is dark-only (no light/dark variants)
- Asset catalog adds file management overhead with no benefit
- Current pattern works and is validated

## Technical Decisions

| Decision | Options Considered | Choice | Rationale |
|----------|-------------------|--------|-----------|
| SSH library | Citadel, NMSSH, libssh2 | **Citadel** | Pure Swift, built on SwiftNIO SSH (same NIO Vapor uses), maintained |
| NIO conflict | Separate EventLoopGroup, Share Vapor's | **Share Vapor's** | Avoids the exact issue that broke ClaudeCodeSDK (RunLoop vs NIO) |
| GitHub API auth | Per-user token, Server-side env var | **Server-side env var** | Simpler, no per-user GitHub login needed |
| Skill install | Git clone, Download ZIP, Fetch raw | **Git clone --depth 1** | Gets full SKILL.md + any referenced files, shallow = fast |
| JSON editor | WebView + CodeMirror, Native TextEditor | **Native TextEditor** | No WebView dependency, simpler, good enough for config |
| Marketplace persistence | SQLite, File-based | **SQLite** (Fluent) | Already using Fluent; cache table is natural extension |
| Color tokens | Apple system, Spec custom | **Spec custom** | User explicitly chose spec colors over Apple system |
| Navigation | Tab bar, Sidebar | **Sidebar** | User decision; matches Stitch designs |
| ServerConnection gate | Required before dashboard, Optional | **Optional** | Support local-first mode; connection screen in Settings too |
| SkillItem type | Unify with Skill, Keep separate | **Unify** | SkillItem in CommandPaletteView is redundant; use Skill from ILSShared |
| Config editor scope write | All scopes, User only | **All scopes** | Extend FileSystemService.writeConfig for project/local |

## File Structure

### New Files

| File | Target | Action | Purpose |
|------|--------|--------|---------|
| `Sources/ILSShared/Models/ServerConnection.swift` | ILSShared | Create | SSH connection model |
| `Sources/ILSShared/DTOs/SearchResult.swift` | ILSShared | Create | GitHub search DTOs |
| `Sources/ILSShared/DTOs/ConnectionResponse.swift` | ILSShared | Create | Auth response DTOs |
| `Sources/ILSBackend/Controllers/AuthController.swift` | ILSBackend | Create | SSH auth endpoints |
| `Sources/ILSBackend/Services/SSHService.swift` | ILSBackend | Create | Backend Citadel SSH |
| `Sources/ILSBackend/Services/GitHubService.swift` | ILSBackend | Create | GitHub API client |
| `Sources/ILSBackend/Services/IndexingService.swift` | ILSBackend | Create | Search cache |
| `Sources/ILSBackend/Migrations/CreateCachedResults.swift` | ILSBackend | Create | Cache table migration |
| `ILSApp/ILSApp/Views/ServerConnection/ServerConnectionView.swift` | ILSApp | Create | SSH form UI |
| `ILSApp/ILSApp/Views/Skills/SkillDetailView.swift` | ILSApp | Create | Skill detail screen |
| `ILSApp/ILSApp/Views/MCP/AddMCPServerView.swift` | ILSApp | Create | Add server form |
| `ILSApp/ILSApp/Views/MCP/EditMCPServerView.swift` | ILSApp | Create | Edit server form |
| `ILSApp/ILSApp/Views/Plugins/PluginMarketplaceView.swift` | ILSApp | Create | Marketplace modal |
| `ILSApp/ILSApp/ViewModels/ServerConnectionViewModel.swift` | ILSApp | Create | Connection VM |
| `ILSApp/ILSApp/ViewModels/SkillDetailViewModel.swift` | ILSApp | Create | Skill detail VM |
| `ILSApp/ILSApp/Services/SSHService.swift` | ILSApp | Create | iOS Citadel client |
| `ILSApp/ILSApp/Services/KeychainService.swift` | ILSApp | Create | Keychain wrapper |
| `ILSApp/ILSApp/Services/ConfigurationManager.swift` | ILSApp | Create | Config lifecycle |

### Modified Files

| File | Target | Changes |
|------|--------|---------|
| `Package.swift` | Root | Add Citadel dependency, add Yams to ILSShared |
| `Sources/ILSBackend/App/routes.swift` | ILSBackend | Register AuthController, add `/server/status` route |
| `Sources/ILSBackend/App/configure.swift` | ILSBackend | Register `CreateCachedResults` migration |
| `Sources/ILSBackend/Controllers/SkillsController.swift` | ILSBackend | Add `search`, `install` routes |
| `Sources/ILSBackend/Controllers/MCPController.swift` | ILSBackend | Add `update` route |
| `Sources/ILSBackend/Controllers/PluginsController.swift` | ILSBackend | Add `search`, `addMarketplace` routes |
| `Sources/ILSBackend/Controllers/StatsController.swift` | ILSBackend | Add `serverStatus` route |
| `Sources/ILSShared/Models/Skill.swift` | ILSShared | Add `rawContent`, `stars`, `author`, `github` source case |
| `Sources/ILSShared/Models/Plugin.swift` | ILSShared | Add `stars`, `PluginSource`, `category`, `Marketplace` struct |
| `Sources/ILSShared/DTOs/Requests.swift` | ILSShared | Add `SkillInstallRequest`, `AddMarketplaceRequest`, `ConnectRequest` |
| `ILSApp/ILSApp/Theme/ILSTheme.swift` | ILSApp | Update all color tokens to spec values |
| `ILSApp/ILSApp/ILSAppApp.swift` | ILSApp | Add ServerConnection state to AppState |
| `ILSApp/ILSApp/ContentView.swift` | ILSApp | Conditional ServerConnectionView when no connection |
| `ILSApp/ILSApp/Views/Dashboard/DashboardView.swift` | ILSApp | Add Quick Actions + Recent Activity |
| `ILSApp/ILSApp/Views/Skills/SkillsListView.swift` | ILSApp | Add GitHub search section |
| `ILSApp/ILSApp/Views/MCP/MCPServerListView.swift` | ILSApp | Add scope tabs, CRUD actions |
| `ILSApp/ILSApp/Views/Plugins/PluginsListView.swift` | ILSApp | Add marketplace browsing |
| `ILSApp/ILSApp/Views/Settings/SettingsView.swift` | ILSApp | Add JSON editor + Quick Settings |
| `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` | ILSApp | Add GitHub search + install |
| `ILSApp/ILSApp/ViewModels/MCPViewModel.swift` | ILSApp | Add scope, update, delete |
| `ILSApp/ILSApp/ViewModels/PluginsViewModel.swift` | ILSApp | Add marketplace search |
| `ILSApp/ILSApp/ViewModels/DashboardViewModel.swift` | ILSApp | Add quick actions + activity |
| `ILSApp/ILSApp/Views/Chat/CommandPaletteView.swift` | ILSApp | Remove `SkillItem` (use `Skill` from ILSShared) |

## Error Handling

| Error Scenario | Handling Strategy | User Impact |
|----------------|-------------------|-------------|
| SSH connection timeout | 10s timeout, catch `NIOConnectionError`, show alert | "Could not connect to server. Check host and port." |
| SSH auth failure | Catch Citadel auth error, surface specific reason | "Authentication failed. Check username and password." |
| SSH connection lost mid-session | `SSHService.isConnected()` poll every 30s, auto-reconnect 3x | Red dot in sidebar, "Reconnecting..." toast, then "Connection lost" |
| GitHub API rate limit | Check `X-RateLimit-Remaining`, return cached + flag | "Rate limited -- try again in X seconds" banner |
| GitHub search no results | Return empty array | "No skills found on GitHub" empty state |
| GitHub API unreachable | Catch URLError, return cached results if available | "GitHub unavailable -- showing cached results" |
| Skill install: clone fails | Catch Process error, clean up partial clone | "Failed to install: could not clone repository" |
| Skill install: no SKILL.md | Check file exists after clone, clean up | "Repository does not contain a valid SKILL.md" |
| MCP config write fails | Catch file permission error | "Could not write MCP configuration" with path shown |
| JSON validation failure | `POST /config/validate` returns `{isValid: false, errors}` | Red X with specific error: "Expected '}' at line 5" |
| Keychain access denied | Catch `errSecAuthFailed` | "Please allow ILS to access the keychain" |
| Network offline | APIClient `isRetriable` check, exponential backoff 3x | "No connection -- retrying..." with spinner |

### Error Pattern (consistent across all new code)

```swift
// ViewModel pattern:
func someAction() async {
    isLoading = true
    error = nil
    do {
        let result = try await client.post("/endpoint", body: request)
        // Update state immutably
        self.data = result.data
    } catch {
        self.error = error
    }
    isLoading = false
}

// View pattern:
if let error = viewModel.error {
    ErrorStateView(error: error) { await viewModel.retry() }
} else if viewModel.isLoading {
    ProgressView()
} else {
    // Content
}
```

## Edge Cases

- **Concurrent SSH + REST**: Both can be active simultaneously. REST for CRUD, SSH for file ops. No conflict -- different transport.
- **SKILL.md without YAML frontmatter**: Parser falls back to raw content display. Name derived from filename.
- **SKILL.md with invalid YAML**: Display raw text, mark as "unparseable" in UI. Don't block install.
- **Empty ~/.claude/skills/**: Show empty state with "Discover Skills" CTA.
- **MCP server with HTTP type**: Already handled in FileSystemService. Preserve `type: "http"` with `url` field.
- **Env vars with `${VAR}` templates**: Mask in display. Don't resolve -- they're runtime placeholders.
- **Multiple marketplaces with same plugin**: Show source badge (Official vs Community). Install from user's chosen marketplace.
- **Config file doesn't exist yet**: Create with empty `{}` on first save. `readConfig` already handles missing file.
- **SSH key file formats**: Support OpenSSH and PEM. Citadel handles both natively.
- **Large SKILL.md files**: TextEditor handles up to ~1MB fine. Truncate preview at 10KB in list view.
- **Concurrent skill installs**: Queue with DispatchSemaphore(value: 1). Show "Install in progress" for second attempt.
- **App backgrounded during SSH**: Citadel connection may drop. Re-establish on foreground via `scenePhase` observer.

## Security Considerations

| Concern | Approach |
|---------|----------|
| SSH passwords | Stored in iOS Keychain, never UserDefaults or plaintext |
| SSH private keys | Stored in Keychain as `kSecClassKey`, protected by Secure Enclave where available |
| GitHub API token | Server-side env var only (`GITHUB_TOKEN`). Never sent to iOS. Never in config files. |
| SSH host key validation | First-connect: TOFU (Trust On First Use) with prompt. Subsequent: validate against stored fingerprint |
| MCP env vars in API responses | Already masked in FileSystemService (first 4 + last 4 chars). Preserve this. |
| Bearer tokens | Session tokens for auth stored in Keychain. Transmitted over HTTPS in production. |
| Config file permissions | Backend writes with 0600 permissions (owner read/write only) |
| App Store compliance | SSH is permitted. Add Privacy Manifest entries for network access. No private APIs used. |

## Performance Considerations

| Area | Approach | Target |
|------|----------|--------|
| GitHub search debounce | 300ms on iOS, server-side cache | < 3s perceived |
| Skill list load | 30s TTL cache in FileSystemService (existing) | < 200ms cached |
| MCP list load | 30s TTL cache (existing) | < 200ms cached |
| IndexingService | SQLite cache, 1hr TTL for search, 24hr for content | < 50ms cache hit |
| SSH connection | Connection pooling (keep alive), 10s timeout | < 5s first connect |
| Skill install (git clone) | `--depth 1`, 60s timeout, progress indicator | < 30s typical |
| App launch | No blocking network calls in `AppState.init` | < 2s to Dashboard |
| JSON editor | Native TextEditor (no WebView overhead) | Instant typing |
| Config validation | Debounced (500ms) server-side validation | < 200ms response |

## Phased Delivery

### Phase 1: Foundation (P0) -- SSH + Connection

**Dependencies**: None (foundational)
**Files**: 8 new, 3 modified
**Effort**: M (3-5 days)

1. Add Citadel to `Package.swift`
2. Create `ServerConnection.swift` model
3. Create `ConnectionResponse.swift` DTOs
4. Create backend `SSHService.swift`
5. Create `AuthController.swift` with `/auth/connect`, `/auth/disconnect`
6. Add `GET /server/status` to StatsController
7. Create `KeychainService.swift` on iOS
8. Create `ServerConnectionView.swift` + `ServerConnectionViewModel.swift`
9. Integrate connection state into `AppState`
10. Update `ContentView` for conditional server connection screen

**Validation**: Connect to real SSH server, see green dot in sidebar.

### Phase 2: Design System Alignment (P2/P3) -- Theme

**Dependencies**: None (parallel with Phase 1)
**Files**: 1 modified (ILSTheme.swift)
**Effort**: S (1 day)

1. Update all color tokens in ILSTheme.swift to spec values
2. Add `accentSecondary`, `accentTertiary`, `borderDefault`, `borderActive`
3. Rename corner radius properties
4. Verify all 12 existing screens still look correct

**Validation**: Screenshot comparison of all screens against Stitch designs.

### Phase 3: GitHub Integration (P1) -- Search + Install

**Dependencies**: Phase 1 (for SSH-based install on remote; REST install works without)
**Files**: 5 new, 4 modified
**Effort**: M (3-5 days)

1. Create `GitHubService.swift` on backend
2. Create `SearchResult.swift` DTOs in ILSShared
3. Add `GET /skills/search` and `POST /skills/install` to SkillsController
4. Create `IndexingService.swift` + migration
5. Update `SkillsViewModel` with GitHub search + install
6. Update `SkillsListView` with search bar + results section
7. Create `SkillDetailView.swift` + `SkillDetailViewModel.swift`
8. Enhance `Skill.swift` model (rawContent, stars, author)

**Validation**: Search "code-review", see GitHub results, install one, see in installed list.

### Phase 4: Enhanced Views (P1) -- MCP, Plugins, Settings, Dashboard

**Dependencies**: Phase 3 (for shared patterns)
**Files**: 5 new, 8 modified
**Effort**: L (5-7 days)

1. **MCP Management**:
   - Add scope tabs to MCPServerListView
   - Create `AddMCPServerView.swift`, `EditMCPServerView.swift`
   - Add `PUT /mcp/:name` endpoint
   - Update MCPViewModel

2. **Plugin Marketplace**:
   - Create `PluginMarketplaceView.swift`
   - Add `GET /plugins/search`, `POST /marketplaces` endpoints
   - Update PluginsViewModel + PluginsListView
   - Add Plugin model enhancements

3. **Settings Editor**:
   - Add JSON TextEditor to SettingsView
   - Add scope selector + Quick Settings toggles
   - Create `ConfigurationManager.swift`

4. **Dashboard Enhancement**:
   - Add Quick Actions section
   - Add Recent Activity feed
   - Update DashboardViewModel

**Validation**: Each sub-feature validated independently with real data.

### Phase 5: Model Alignment + Polish (P2/P3)

**Dependencies**: Phases 1-4
**Files**: 3 modified
**Effort**: S (2-3 days)

1. Unify `SkillItem` → `Skill` in CommandPaletteView
2. Align Plugin model fields
3. Add Yams to ILSShared target for client-side SKILL.md parsing
4. Add `ConfigurationManager` integration
5. App Store compliance checks (Privacy Manifest, entitlements)
6. Accessibility pass (VoiceOver labels on new views)

**Validation**: Full app walkthrough, all screens, all features.

## Validation Plan

- [ ] Build and run backend: `PORT=9090 swift run ILSBackend`
- [ ] Build and run iOS app on Simulator (50523130-57AA-48B0-ABD0-4D59CE455F14)
- [ ] Test SSH connection to real server via UI
- [ ] Test GitHub skill search and install via UI
- [ ] Test MCP scope tabs and CRUD via UI
- [ ] Test plugin marketplace search and install via UI
- [ ] Test settings JSON editor save/load via UI
- [ ] Capture screenshots of all 15+ screens
- [ ] Verify all 12 existing screens unchanged
- [ ] Verify color tokens match spec hex values

## Unresolved Questions

1. **Citadel iOS sandbox**: Does Citadel's SwiftNIO SSH work within iOS app sandbox? If not, SSH functionality must be backend-only (iOS sends REST to backend, backend SSHs to remote). **Mitigation**: Test early in Phase 1; fallback is backend-proxy pattern.

2. **Git clone on backend**: The `POST /skills/install` needs `git` available on the backend host. This is true for macOS dev machines but may not be for production. **Mitigation**: Fall back to GitHub API raw content fetch if git unavailable.

3. **Connection persistence**: Should SSH connections survive app backgrounding? iOS aggressively kills background network. **Recommendation**: Treat as ephemeral -- reconnect on foreground, store credentials in Keychain for seamless re-auth.

4. **Plugin marketplace.json format**: The spec references `.claude-plugin/marketplace.json` but real-world format may vary. Need to validate against actual Claude Code plugin repos. **Mitigation**: Flexible parser with fallback to listing files.
