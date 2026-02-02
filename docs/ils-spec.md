Task: ILS Application - Claude Code Configuration Manager with Agentic Development Toolkit

## Skill Inventory and Activation

&lt;skill_assessment&gt;
- [ ] Inventory all available MCP servers and tools
- [ ] Activate SwiftUI iOS/macOS development skills
- [ ] Activate Vapor backend development skills
- [ ] Activate SSH networking and security skills
- [ ] Activate GitHub API integration skills
- [ ] Activate design system and theming skills
- [ ] Document skill selection rationale: Full-stack Swift monorepo with shared models between iOS app and Vapor backend
      &lt;/skill_assessment&gt;

## Pre-Task Research and Setup

&lt;research_phase&gt;
- [ ] Enable sequential thinking for systematic task breakdown (500+ steps)
- [ ] Search for existing solutions using web search tools:
- [ ] Query for Claude Code configuration management libraries
- [ ] Query for MCP server discovery and management patterns
- [ ] Query for SwiftUI SSH client implementations
- [ ] Evaluate top solutions for fitness:
- [ ] **SSH**: Citadel (orlandos-nl/Citadel) - High-level Swift SSH framework built on SwiftNIO SSH [Source](https://github.com/orlandos-nl/Citadel)
- [ ] **Backend**: Vapor 4.x - Mature Swift web framework [Source](https://vapor.codes)
- [ ] **GitHub API**: serhii-londar/GithubAPI or direct REST implementation [Source](https://github.com/serhii-londar/GithubAPI)
- [ ] Check last commit dates (prefer repositories active within 6 months)
- [ ] Document findings in project documentation
- [ ] Pull documentation for Citadel, Vapor, SwiftUI from official sources
      &lt;/research_phase&gt;

## Technical Research Findings

### Claude Code Configuration Architecture

&lt;claude_code_research&gt;
**Configuration File Locations:** [Source](https://code.claude.com/docs/en/settings)

ScopeLocationPurposeUser Settings`~/.claude/settings.json`Personal global settingsProject Settings`.claude/settings.json`Team-shared project settingsLocal Settings`.claude/settings.local.json`Per-machine overridesMCP Servers (User)`~/.claude.json`User-scoped MCP configurationsMCP Servers (Project)`.mcp.json`Project-scoped MCP serversManaged Settings`/Library/Application Support/ClaudeCode/managed-settings.json` (macOS)Enterprise deploymentManaged MCP`/Library/Application Support/ClaudeCode/managed-mcp.json` (macOS)Enterprise MCP servers

**Skills Directory Structure:** [Source](https://code.claude.com/docs/en/slash-commands)

```
~/.claude/skills/
├── skill-name/
│   └── SKILL.md           # YAML frontmatter + markdown instructions
```

[**SKILL.md**](http://SKILL.md)** Format (YAML Frontmatter):** [Source](https://github.com/alirezarezvani/claude-code-skill-factory)

```yaml
---
name: skill-name-in-kebab-case
description: Brief one-line description
---
# Instructions markdown content
```

**Plugin System:** [Source](https://code.claude.com/docs/en/discover-plugins)
- Plugin marketplace: `/plugin marketplace add owner/repo`
- Plugin installation: `/plugin install plugin-name@marketplace-name`
- Plugin cache: `~/.claude/plugins/cache`
- Plugin manifest: `.claude-plugin/plugin.json`
- Marketplace file: `.claude-plugin/marketplace.json`

**MCP Server Configuration Format:** [Source](https://code.claude.com/docs/en/mcp)

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@package/server"],
      "env": { "API_KEY": "${API_KEY}" }
    }
  }
}
```

**settings.json Key Fields:** [Source](https://code.claude.com/docs/en/settings)
- `permissions`: { allow: [], deny: [] }
- `env`: Environment variables
- `model`: Override default model
- `hooks`: PreToolUse/PostToolUse commands
- `enabledPlugins`: { "plugin@marketplace": true }
- `extraKnownMarketplaces`: Marketplace configurations
  &lt;/claude_code_research&gt;

## Sub-Agent Allocation

 - [ ] Spawn 15+ sub-agents based on Critical complexity - [ ] Assign execution strategy: Multi-phase orchestrated

**Parallel Workstreams:**
- [ ] Workstream A: Shared Models Package development
- [ ] Workstream B: Vapor Backend API development
- [ ] Workstream C: SwiftUI iOS App development
- [ ] Workstream D: Design System & Theme implementation
- [ ] Workstream E: GitHub API integration service

**Sequential Phases:**
1. Phase 1: Shared Models Package (foundation)
2. Phase 2: Backend API (provides responses to frontend)
3. Phase 3: iOS App UI implementation
4. Phase 4: Integration testing via Simulator + cURL

## Project Architecture

 ``` ILSApp/ # Monorepo root ├── Package.swift # Workspace manifest ├── Sources/ │ ├── ILSShared/ # Shared models package │ │ ├── Models/ │ │ │ ├── ClaudeConfig.swift │ │ │ ├── MCPServer.swift │ │ │ ├── Skill.swift │ │ │ ├── Plugin.swift │ │ │ ├── Marketplace.swift │ │ │ └── ServerConnection.swift │ │ └── DTOs/ │ │ ├── APIResponse.swift │ │ └── SearchResult.swift │ │ │ ├── ILSBackend/ # Vapor backend │ │ ├── App/ │ │ │ ├── configure.swift │ │ │ ├── routes.swift │ │ │ └── entrypoint.swift │ │ ├── Controllers/ │ │ │ ├── SkillsController.swift │ │ │ ├── PluginsController.swift │ │ │ ├── MCPController.swift │ │ │ └── SearchController.swift │ │ ├── Services/ │ │ │ ├── GitHubService.swift │ │ │ └── IndexingService.swift │ │ └── Migrations/ │ │ │ └── ILSApp/ # iOS/macOS SwiftUI App │ ├── ILSApp.swift │ ├── Theme/ │ │ ├── ILSTheme.swift │ │ └── Colors.swift │ ├── Views/ │ │ ├── Dashboard/ │ │ ├── Skills/ │ │ ├── Plugins/ │ │ ├── MCP/ │ │ ├── Settings/ │ │ └── ServerConnection/ │ ├── ViewModels/ │ ├── Services/ │ │ ├── SSHService.swift │ │ ├── APIClient.swift │ │ └── ConfigurationManager.swift │ └── Resources/ │ └── Assets.xcassets │ ├── Tests/ └── README.md ```

## Design System Specification

&lt;design_system&gt;
**Theme: Dark Mode Only with Hot Orange Accent**

TokenValueUsage`background.primary#000000`Main app background`background.secondary#0D0D0D`Card backgrounds`background.tertiary#1A1A1A`Input fields, elevated surfaces`accent.primary#FF6B35`Hot Orange - primary actions, highlights`accent.secondary#FF8C5A`Lighter orange - hover states`accent.tertiary#FF4500`Deeper orange - pressed states`text.primary#FFFFFF`Primary text`text.secondary#A0A0A0`Secondary/muted text`text.tertiary#666666`Disabled text`border.default#2A2A2A`Card borders`border.active#FF6B35`Active/focused borders`success#4CAF50`Success states`warning#FFA726`Warning states`error#EF5350`Error states

**Typography:**
- Headings: SF Pro Display, Bold
- Body: SF Pro Text, Regular
- Code: SF Mono, Regular

**Corner Radius:**
- Small: 8pt (buttons, inputs)
- Medium: 12pt (cards)
- Large: 16pt (modals)

**Spacing Scale:**
- xs: 4pt
- sm: 8pt
- md: 16pt
- lg: 24pt
- xl: 32pt
  &lt;/design_system&gt;

## Wireframes Specification

### Screen 1: Server Connection (Entry Point)

```
┌─────────────────────────────────────┐
│ ████████ ILS ████████████████████░░ │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │    🖥️ Connect to Server     │   │
│  └─────────────────────────────┘   │
│                                     │
│  Host: ┌───────────────────────┐   │
│        │ 192.168.1.100         │   │
│        └───────────────────────┘   │
│                                     │
│  Port: ┌───────────────────────┐   │
│        │ 22                    │   │
│        └───────────────────────┘   │
│                                     │
│  User: ┌───────────────────────┐   │
│        │ admin                 │   │
│        └───────────────────────┘   │
│                                     │
│  Auth: ○ Password  ● SSH Key       │
│                                     │
│  Key:  ┌───────────────────────┐   │
│        │ Select Key File...    │   │
│        └───────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │    [████ CONNECT ████]      │   │ <- Accent Orange Button
│  └─────────────────────────────┘   │
│                                     │
│  Recent Connections:               │
│  ┌─────────────────────────────┐   │
│  │ 🟢 home-server (192.168..)  │   │
│  │ ⚪ dev-box (10.0.0.5)       │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**API Calls:** None (local state management)

### Screen 2: Dashboard (Post-Connection)

```
┌─────────────────────────────────────┐
│ ◀ │ Dashboard │ home-server 🟢 │ ⚙️ │
├─────────────────────────────────────┤
│                                     │
│  ┌───────┐ ┌───────┐ ┌───────┐    │
│  │ 12    │ │ 8     │ │ 3     │    │
│  │Skills │ │MCPs   │ │Plugins│    │
│  └───────┘ └───────┘ └───────┘    │
│                                     │
│  Quick Actions ─────────────────   │
│  ┌─────────────────────────────┐   │
│  │ 🔍 Discover New Skills      │→  │
│  ├─────────────────────────────┤   │
│  │ 📦 Browse Plugin Market     │→  │
│  ├─────────────────────────────┤   │
│  │ 🔧 Configure MCP Servers    │→  │
│  ├─────────────────────────────┤   │
│  │ ⚙️  Edit Claude Settings    │→  │
│  └─────────────────────────────┘   │
│                                     │
│  Recent Activity ───────────────   │
│  ┌─────────────────────────────┐   │
│  │ ✅ Installed code-review    │   │
│  │    2 hours ago              │   │
│  ├─────────────────────────────┤   │
│  │ 🔄 Updated github MCP       │   │
│  │    Yesterday                │   │
│  └─────────────────────────────┘   │
│                                     │
├─────────────────────────────────────┤
│ [Home] [Skills] [MCPs] [Discover]  │
└─────────────────────────────────────┘
```

**API Calls:**
- `GET /api/v1/server/status` - Connection health
- `GET /api/v1/stats` - Dashboard stats

### Screen 3: Skills Explorer

```
┌─────────────────────────────────────┐
│ ◀ │ Skills │ ⊕ Add │ 🔍 Filter    │
├─────────────────────────────────────┤
│                                     │
│  Installed Skills ──────────────   │
│  ┌─────────────────────────────┐   │
│  │ 📝 code-review             │   │
│  │ Automated PR code review   │   │
│  │ v1.2.0 │ ✅ Active │ ⋮     │   │
│  ├─────────────────────────────┤   │
│  │ 🧪 test-generator          │   │
│  │ Generate unit tests        │   │
│  │ v2.0.1 │ ✅ Active │ ⋮     │   │
│  ├─────────────────────────────┤   │
│  │ 📊 analytics               │   │
│  │ Code analytics & metrics   │   │
│  │ v1.0.0 │ ⚪ Disabled│ ⋮    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🔍 Search Skill Repos...   │   │ <- Accent border on focus
│  └─────────────────────────────┘   │
│                                     │
│  Discovered from GitHub ────────   │
│  ┌─────────────────────────────┐   │
│  │ ⭐ 234 │ refactor-pro       │   │
│  │ Advanced refactoring skill │   │
│  │ [Install]                  │   │ <- Orange button
│  └─────────────────────────────┘   │
│                                     │
├─────────────────────────────────────┤
│ [Home] [Skills] [MCPs] [Discover]  │
└─────────────────────────────────────┘
```

**API Calls:**
- `GET /api/v1/skills` - List installed skills
- `GET /api/v1/skills/search?q={query}` - Search GitHub
- `POST /api/v1/skills/install` - Install skill
- `DELETE /api/v1/skills/{id}` - Uninstall skill

### Screen 4: Skill Detail View

```
┌─────────────────────────────────────┐
│ ◀ │ code-review │ ⋮               │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │         📝                  │   │
│  │    code-review              │   │
│  │    v1.2.0 by anthropic      │   │
│  │    ⭐ 1.2k │ Updated 3d ago │   │
│  └─────────────────────────────┘   │
│                                     │
│  Description ───────────────────   │
│  Automated code review skill      │
│  that analyzes PRs for issues,    │
│  security vulnerabilities, and    │
│  suggests improvements.           │
│                                     │
│  SKILL.md Preview ──────────────   │
│  ┌─────────────────────────────┐   │
│  │ ---                         │   │
│  │ name: code-review           │   │
│  │ description: Reviews code   │   │
│  │ ---                         │   │
│  │ ## Instructions             │   │
│  │ When reviewing code...      │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ [████ UNINSTALL ████]       │   │ <- Red destructive
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ [   Edit SKILL.md   ]       │   │ <- Secondary
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**API Calls:**
- `GET /api/v1/skills/{id}` - Skill details
- `PUT /api/v1/skills/{id}` - Update skill
- `DELETE /api/v1/skills/{id}` - Uninstall

### Screen 5: MCP Server Management

```
┌─────────────────────────────────────┐
│ ◀ │ MCP Servers │ ⊕ Add          │
├─────────────────────────────────────┤
│                                     │
│  Scope: [User] [Project] [Local]   │
│         ~~~~~~                     │ <- Orange underline active
│                                     │
│  Active Servers ────────────────   │
│  ┌─────────────────────────────┐   │
│  │ 🟢 github                   │   │
│  │ npx @mcp/server-github     │   │
│  │ [Disable] [Edit] [Delete]  │   │
│  ├─────────────────────────────┤   │
│  │ 🟢 filesystem              │   │
│  │ npx @mcp/server-filesystem │   │
│  │ Paths: ~/projects          │   │
│  │ [Disable] [Edit] [Delete]  │   │
│  ├─────────────────────────────┤   │
│  │ 🔴 postgres (error)        │   │
│  │ Connection refused         │   │
│  │ [Retry] [Edit] [Delete]    │   │
│  └─────────────────────────────┘   │
│                                     │
│  Add New Server ────────────────   │
│  ┌─────────────────────────────┐   │
│  │ ○ From Registry            │   │
│  │ ● Custom Command           │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**API Calls:**
- `GET /api/v1/mcp?scope={scope}` - List MCP servers
- `POST /api/v1/mcp` - Add server
- `PUT /api/v1/mcp/{id}` - Update server
- `DELETE /api/v1/mcp/{id}` - Remove server

### Screen 6: Plugin Marketplace

```
┌─────────────────────────────────────┐
│ ◀ │ Plugin Marketplace            │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🔍 Search plugins...        │   │
│  └─────────────────────────────┘   │
│                                     │
│  Categories ────────────────────   │
│  [All] [Productivity] [DevOps]    │
│  [Testing] [Documentation]        │
│                                     │
│  Official Marketplace ──────────   │
│  ┌─────────────────────────────┐   │
│  │ 📦 github                   │   │
│  │ GitHub integration plugin  │   │
│  │ ⭐ 2.1k │ Official          │   │
│  │ [████ INSTALL ████]        │   │
│  ├─────────────────────────────┤   │
│  │ 📦 linear                   │   │
│  │ Linear project management  │   │
│  │ ⭐ 856 │ Official           │   │
│  │ [████ INSTALL ████]        │   │
│  ├─────────────────────────────┤   │
│  │ 📦 sentry                   │   │
│  │ Error tracking integration │   │
│  │ ⭐ 432 │ Official           │   │
│  │ [✓ Installed]              │   │ <- Muted/disabled
│  └─────────────────────────────┘   │
│                                     │
│  Add Custom Marketplace ────────   │
│  ┌─────────────────────────────┐   │
│  │ + Add from GitHub repo     │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**API Calls:**
- `GET /api/v1/plugins/marketplace` - List marketplaces
- `GET /api/v1/plugins/search?q={query}` - Search plugins
- `POST /api/v1/plugins/install` - Install plugin
- `POST /api/v1/marketplaces` - Add marketplace

### Screen 7: Settings/Configuration Editor

```
┌─────────────────────────────────────┐
│ ◀ │ Claude Settings               │
├─────────────────────────────────────┤
│                                     │
│  Config File: [User▾]              │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ {                           │   │
│  │   "model": "claude-sonnet", │   │
│  │   "permissions": {          │   │
│  │     "allow": [              │   │
│  │       "Bash(npm run *)"     │   │
│  │     ],                      │   │
│  │     "deny": [               │   │
│  │       "Read(.env)"          │   │
│  │     ]                       │   │
│  │   },                        │   │
│  │   "env": {                  │   │
│  │     "DEBUG": "true"         │   │
│  │   }                         │   │
│  │ }                           │   │
│  └─────────────────────────────┘   │
│  Syntax: ✅ Valid JSON             │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ [████ SAVE CHANGES ████]   │   │
│  └─────────────────────────────┘   │
│                                     │
│  Quick Settings ────────────────   │
│  Model: [claude-sonnet-4▾]        │
│  Extended Thinking: [●] ON        │
│  Co-authored-by: [○] OFF          │
│                                     │
└─────────────────────────────────────┘
```

**API Calls:**
- `GET /api/v1/config?scope={scope}` - Get config
- `PUT /api/v1/config` - Update config
- `POST /api/v1/config/validate` - Validate JSON

## API Contract Specification

&lt;api_contract&gt;

### Base URL

`http://localhost:8080/api/v1`

### Authentication

Bearer token via header: `Authorization: Bearer {ssh_session_token}`

### Endpoints

Server Connection

```
POST /auth/connect
Request:
{
  "host": "192.168.1.100",
  "port": 22,
  "username": "admin",
  "authMethod": "key" | "password",
  "credential": "..." // password or key path
}
Response:
{
  "success": true,
  "sessionId": "uuid",
  "serverInfo": {
    "claudeInstalled": true,
    "claudeVersion": "1.0.113",
    "configPaths": { ... }
  }
}
```

Dashboard Stats

```
GET /stats
Response:
{
  "skills": { "total": 12, "active": 10 },
  "mcpServers": { "total": 8, "healthy": 6 },
  "plugins": { "total": 3, "enabled": 3 }
}
```

Skills

```
GET /skills
Response:
{
  "items": [
    {
      "id": "uuid",
      "name": "code-review",
      "description": "...",
      "version": "1.2.0",
      "isActive": true,
      "path": "~/.claude/skills/code-review",
      "skillMd": "---\nname: code-review\n..."
    }
  ]
}

GET /skills/search?q={query}
Response:
{
  "items": [
    {
      "repository": "owner/repo",
      "name": "skill-name",
      "stars": 234,
      "description": "...",
      "lastUpdated": "2025-01-15T..."
    }
  ]
}

POST /skills/install
Request:
{
  "repository": "owner/repo",
  "skillPath": "skills/code-review"
}
Response:
{
  "success": true,
  "skill": { ... }
}

DELETE /skills/{id}
Response:
{ "success": true }
```

MCP Servers

```
GET /mcp?scope=user|project|local
Response:
{
  "items": [
    {
      "name": "github",
      "command": "npx",
      "args": ["-y", "@mcp/server-github"],
      "env": { "GITHUB_TOKEN": "***" },
      "status": "healthy" | "error",
      "scope": "user"
    }
  ]
}

POST /mcp
Request:
{
  "name": "postgres",
  "command": "npx",
  "args": [...],
  "env": {...},
  "scope": "project"
}

PUT /mcp/{name}
DELETE /mcp/{name}
```

Plugins

```
GET /plugins/marketplace
Response:
{
  "marketplaces": [
    {
      "name": "claude-plugins-official",
      "source": "anthropics/claude-code",
      "plugins": [...]
    }
  ]
}

POST /plugins/install
Request:
{
  "pluginName": "github",
  "marketplace": "claude-plugins-official",
  "scope": "user"
}

POST /marketplaces
Request:
{
  "source": "github",
  "repo": "acme-corp/claude-plugins"
}
```

Configuration

```
GET /config?scope=user|project|local
Response:
{
  "scope": "user",
  "path": "~/.claude/settings.json",
  "content": { ... },
  "isValid": true
}

PUT /config
Request:
{
  "scope": "user",
  "content": { ... }
}

POST /config/validate
Request:
{ "content": { ... } }
Response:
{ "isValid": true, "errors": [] }
```

&lt;/api_contract&gt;

## Primary Implementation

### Phase 1: Shared Models Package

- [ ] Think sequentially through data model design with 100+ steps
- [ ] Create `Package.swift` for monorepo workspace
- [ ] Implement shared Codable models:
- [ ] `ClaudeConfig.swift` - settings.json structure
- [ ] `MCPServer.swift` - MCP server configuration
- [ ] `Skill.swift` - [SKILL.md](http://SKILL.md) representation with YAML parsing
- [ ] `Plugin.swift` - Plugin manifest structure
- [ ] `Marketplace.swift` - marketplace.json structure
- [ ] `ServerConnection.swift` - SSH connection details
- [ ] Implement shared DTOs:
- [ ] `APIResponse<T>` - Generic response wrapper
- [ ] `SearchResult.swift` - GitHub search results
- [ ] Validate compilation: `swift build --target ILSShared`

### Phase 2: Vapor Backend Implementation

- [ ] Think sequentially through API architecture with 200+ steps
- [ ] Set up Vapor project structure
- [ ] Implement services:
- [ ] `GitHubService.swift` - GitHub API integration for searching [SKILL.md](http://SKILL.md) files
      - [ ] `GET https://api.github.com/search/code?q=SKILL.md+filename:SKILL.md`
      - [ ] Parse repository results
      - [ ] Fetch raw [SKILL.md](http://SKILL.md) content
- [ ] `IndexingService.swift` - Cache and index discovered skills/plugins
- [ ] Implement controllers:
- [ ] `AuthController.swift` - SSH connection management via Citadel
- [ ] `SkillsController.swift` - CRUD for skills
- [ ] `MCPController.swift` - MCP server management
- [ ] `PluginsController.swift` - Plugin marketplace integration
- [ ] `ConfigController.swift` - Claude settings management
- [ ] Configure routes per API contract
- [ ] Validate via cURL:

```bash
curl http://localhost:8080/api/v1/skills
curl -X POST http://localhost:8080/api/v1/auth/connect -d '...'
```

### Phase 3: SwiftUI iOS Application

- [ ] Think sequentially through UI implementation with 300+ steps
- [ ] Implement design system:
- [ ] `ILSTheme.swift` - Color tokens, typography, spacing
- [ ] `Colors.xcassets` - Dark mode only colors
- [ ] Set AccentColor to Hot Orange `#FF6B35`
- [ ] Implement SSH service using Citadel:

```swift
let client = try await SSHClient.connect(
  host: host,
  authenticationMethod: .passwordBased(username: user, password: pass),
  hostKeyValidator: .acceptAnything()
)
let stdout = try await client.executeCommand("claude --version")
```

- [ ] Implement views (each must compile before next):
- [ ] `ServerConnectionView.swift` - Entry point SSH form
- [ ] `DashboardView.swift` - Main hub post-connection
- [ ] `SkillsListView.swift` - Skills explorer
- [ ] `SkillDetailView.swift` - Single skill view
- [ ] `MCPServerListView.swift` - MCP management
- [ ] `PluginMarketplaceView.swift` - Plugin discovery
- [ ] `SettingsEditorView.swift` - JSON config editor
- [ ] Implement ViewModels with `@Observable`:
- [ ] `ServerConnectionViewModel`
- [ ] `DashboardViewModel`
- [ ] `SkillsViewModel`
- [ ] `MCPViewModel`
- [ ] `PluginsViewModel`
- [ ] Implement `APIClient.swift` - URLSession-based networking
- [ ] Test each view in iOS Simulator

### Phase 4: GitHub Repository Indexing

- [ ] Implement backend indexing service:
- [ ] Search GitHub for repositories containing `SKILL.md` files
- [ ] Filter by valid YAML frontmatter format
- [ ] Store results in local SQLite/PostgreSQL
- [ ] Schedule periodic re-indexing
- [ ] Search query patterns:

```
SKILL.md filename:SKILL.md
name: description: path:SKILL.md
.claude-plugin/marketplace.json
```

## Validation and Testing

 - [ ] Test SSH connection with real server in iOS Simulator - [ ] Test all API endpoints via cURL against running Vapor backend - [ ] Verify each SwiftUI view compiles and renders correctly - [ ] Test dark theme appearance across all screens - [ ] Validate JSON parsing of Claude Code config files - [ ] Test SKILL.md YAML frontmatter parsing - [ ] Verify MCP server configuration round-trip - [ ] Test plugin marketplace integration - [ ] Confirm no light mode appearance (enforce dark only)

## Post-Task Documentation

 - [ ] Document complete architecture decisions - [ ] Record all shared model definitions - [ ] Store API contract specification - [ ] Document design token system - [ ] Archive wireframe specifications - [ ] Record SwiftUI component library - [ ] Document SSH connection flow - [ ] Store GitHub API integration patterns - [ ] Document Claude Code file paths and formats

---

## Technical Dependencies

PackageVersionPurposeVapor4.xBackend web frameworkCitadelLatestSwift SSH clientSwiftNIO SSHLatestLow-level SSH (Citadel dependency)Fluent4.xDatabase ORM for VaporSwiftUIiOS 17+Native UI framework

## File Format References

[**SKILL.md**](http://SKILL.md)** Format:** [Source](https://github.com/alirezarezvani/claude-code-skill-factory)

```yaml
---
name: skill-name-in-kebab-case
description: Brief one-line description
---
# Skill Instructions
Markdown content with instructions...
```

**marketplace.json Format:** [Source](https://code.claude.com/docs/en/plugin-marketplaces)

```json
{
  "name": "marketplace-name",
  "owner": { "name": "...", "url": "..." },
  "plugins": [
    {
      "name": "plugin-name",
      "source": { "type": "local", "path": "./plugins/..." }
    }
  ]
}
```

**MCP Configuration Format:** [Source](https://code.claude.com/docs/en/mcp)

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@package/server"],
      "env": { "KEY": "${ENV_VAR}" }
    }
  }
}
```