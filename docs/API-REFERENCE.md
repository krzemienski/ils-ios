# API Reference

Base URL: `http://localhost:9090/api/v1`

All endpoints return responses in the format:
```json
{
  "success": true,
  "data": { ... },
  "error": "..." // optional
}
```

## Health

### GET /health
Get server health status.

**Response:** `HealthInfo`
```json
{
  "status": "ok",
  "version": "1.0.0",
  "claudeAvailable": true,
  "claudeVersion": "claude-cli 1.2.3",
  "port": 9090
}
```

**Example:**
```bash
curl http://localhost:9090/health
```

---

## Projects

### GET /api/v1/projects
List all projects discovered from `~/.claude/projects/`.

**Response:** `ListResponse<Project>`

**Example:**
```bash
curl http://localhost:9090/api/v1/projects
```

### POST /api/v1/projects
Create a new project (or return existing if path matches).

**Request:** `CreateProjectRequest`
```json
{
  "name": "My Project",
  "path": "/path/to/project",
  "defaultModel": "sonnet",
  "description": "Project description"
}
```

**Response:** `Project`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/projects \
  -H "Content-Type: application/json" \
  -d '{"name":"My Project","path":"/path/to/project"}'
```

### GET /api/v1/projects/:id
Get a specific project by ID.

**Response:** `Project`

**Example:**
```bash
curl http://localhost:9090/api/v1/projects/{uuid}
```

### PUT /api/v1/projects/:id
Update a project's metadata.

**Request:** `UpdateProjectRequest`
```json
{
  "name": "Updated Name",
  "defaultModel": "opus",
  "description": "Updated description"
}
```

**Response:** `Project`

**Example:**
```bash
curl -X PUT http://localhost:9090/api/v1/projects/{uuid} \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Name"}'
```

### DELETE /api/v1/projects/:id
Delete a project and all its associated sessions.

**Response:** `DeletedResponse`

**Example:**
```bash
curl -X DELETE http://localhost:9090/api/v1/projects/{uuid}
```

### GET /api/v1/projects/:id/sessions
Get all sessions for a specific project.

**Response:** `ListResponse<ChatSession>`

**Example:**
```bash
curl http://localhost:9090/api/v1/projects/{uuid}/sessions
```

---

## Sessions

### GET /api/v1/sessions
List all sessions with optional project filter.

**Query Parameters:**
- `projectId` (optional): Filter by project UUID

**Response:** `ListResponse<ChatSession>`

**Example:**
```bash
curl http://localhost:9090/api/v1/sessions
curl http://localhost:9090/api/v1/sessions?projectId={uuid}
```

### POST /api/v1/sessions
Create a new session.

**Request:** `CreateSessionRequest`
```json
{
  "name": "My Session",
  "projectId": "uuid",
  "model": "sonnet",
  "permissionMode": "default"
}
```

**Response:** `ChatSession`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"name":"My Session","model":"sonnet"}'
```

### GET /api/v1/sessions/scan
Scan for external Claude Code sessions from `~/.claude/projects/`.

**Response:** `SessionScanResponse`

**Example:**
```bash
curl http://localhost:9090/api/v1/sessions/scan
```

### GET /api/v1/sessions/:id
Get a specific session by ID.

**Response:** `ChatSession`

**Example:**
```bash
curl http://localhost:9090/api/v1/sessions/{uuid}
```

### DELETE /api/v1/sessions/:id
Delete a session and its messages.

**Response:** `DeletedResponse`

**Example:**
```bash
curl -X DELETE http://localhost:9090/api/v1/sessions/{uuid}
```

### POST /api/v1/sessions/:id/fork
Fork a session, creating a new session with the same settings.

**Response:** `ChatSession`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/sessions/{uuid}/fork
```

### GET /api/v1/sessions/:id/messages
Get messages for a session with pagination.

**Query Parameters:**
- `limit` (optional, default: 100): Number of messages to return
- `offset` (optional, default: 0): Offset for pagination

**Response:** `ListResponse<Message>`

**Example:**
```bash
curl http://localhost:9090/api/v1/sessions/{uuid}/messages?limit=50&offset=0
```

### GET /api/v1/sessions/transcript/:encodedProjectPath/:sessionId
Read messages from an external session's JSONL transcript file.

**Query Parameters:**
- `limit` (optional, default: 200): Number of messages to return
- `offset` (optional, default: 0): Offset for pagination

**Response:** `ListResponse<Message>`

**Example:**
```bash
curl http://localhost:9090/api/v1/sessions/transcript/{encodedPath}/{sessionId}
```

---

## Chat

### POST /api/v1/chat/stream
Stream Claude CLI responses via Server-Sent Events.

**Request:** `ChatStreamRequest`
```json
{
  "prompt": "What is 2+2?",
  "sessionId": "uuid",
  "projectId": "uuid",
  "options": {
    "model": "sonnet",
    "permissionMode": "default"
  }
}
```

**Response:** SSE stream with events:
- `text`: Text chunks from Claude
- `done`: Completion marker
- `error`: Error messages

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/chat/stream \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Hello","sessionId":"uuid"}' \
  --no-buffer
```

### WS /api/v1/chat/ws/:sessionId
WebSocket connection for bidirectional chat.

**Example:**
```bash
# Use a WebSocket client to connect
wscat -c ws://localhost:9090/api/v1/chat/ws/{uuid}
```

### POST /api/v1/chat/permission/:requestId
Submit permission decision for a pending request.

**Request:** `PermissionDecision`
```json
{
  "decision": "allow"
}
```

**Response:** `AcknowledgedResponse`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/chat/permission/{requestId} \
  -H "Content-Type: application/json" \
  -d '{"decision":"allow"}'
```

### POST /api/v1/chat/cancel/:sessionId
Cancel an active chat session's Claude CLI process.

**Response:** `CancelledResponse`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/chat/cancel/{sessionId}
```

---

## Skills

### GET /api/v1/skills
List all skills.

**Query Parameters:**
- `refresh` (optional): Bypass cache
- `search` (optional): Filter by name/description/tags

**Response:** `ListResponse<Skill>`

**Example:**
```bash
curl http://localhost:9090/api/v1/skills
curl http://localhost:9090/api/v1/skills?search=git
curl http://localhost:9090/api/v1/skills?refresh=true
```

### POST /api/v1/skills
Create a new skill.

**Request:** `CreateSkillRequest`
```json
{
  "name": "my-skill",
  "content": "Skill content here",
  "description": "Optional description"
}
```

**Response:** `Skill`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/skills \
  -H "Content-Type: application/json" \
  -d '{"name":"my-skill","content":"# My Skill\n..."}'
```

### GET /api/v1/skills/search
Search GitHub for skills.

**Query Parameters:**
- `q` (required): Search query
- `page` (optional, default: 1): Page number
- `per_page` (optional, default: 20): Results per page

**Response:** `ListResponse<GitHubSearchResult>`

**Example:**
```bash
curl "http://localhost:9090/api/v1/skills/search?q=claude+skill"
```

### POST /api/v1/skills/install
Install a skill from GitHub.

**Request:** `SkillInstallRequest`
```json
{
  "repository": "owner/repo",
  "skillPath": "SKILL.md"
}
```

**Response:** `Skill`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/skills/install \
  -H "Content-Type: application/json" \
  -d '{"repository":"owner/repo","skillPath":"SKILL.md"}'
```

### GET /api/v1/skills/:name
Get a single skill by name.

**Response:** `Skill`

**Example:**
```bash
curl http://localhost:9090/api/v1/skills/my-skill
```

### PUT /api/v1/skills/:name
Update a skill.

**Request:** `UpdateSkillRequest`
```json
{
  "content": "Updated skill content"
}
```

**Response:** `Skill`

**Example:**
```bash
curl -X PUT http://localhost:9090/api/v1/skills/my-skill \
  -H "Content-Type: application/json" \
  -d '{"content":"# Updated\n..."}'
```

### DELETE /api/v1/skills/:name
Delete a skill.

**Response:** `DeletedResponse`

**Example:**
```bash
curl -X DELETE http://localhost:9090/api/v1/skills/my-skill
```

---

## MCP Servers

### GET /api/v1/mcp
List all MCP servers.

**Query Parameters:**
- `scope` (optional): Filter by scope (`user` or `project`)
- `refresh` (optional): Bypass cache

**Response:** `ListResponse<MCPServer>`

**Example:**
```bash
curl http://localhost:9090/api/v1/mcp
curl http://localhost:9090/api/v1/mcp?scope=user
curl http://localhost:9090/api/v1/mcp?refresh=true
```

### GET /api/v1/mcp/:name
Get a single MCP server by name.

**Query Parameters:**
- `scope` (optional): Filter by scope

**Response:** `MCPServer`

**Example:**
```bash
curl http://localhost:9090/api/v1/mcp/my-server
curl http://localhost:9090/api/v1/mcp/my-server?scope=user
```

### POST /api/v1/mcp
Add a new MCP server.

**Request:** `CreateMCPRequest`
```json
{
  "name": "my-server",
  "command": "node",
  "args": ["server.js"],
  "env": {"KEY": "value"},
  "scope": "user"
}
```

**Response:** `MCPServer`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/mcp \
  -H "Content-Type: application/json" \
  -d '{"name":"my-server","command":"node","args":["server.js"]}'
```

### PUT /api/v1/mcp/:name
Update an existing MCP server.

**Request:** `CreateMCPRequest`
```json
{
  "name": "my-server",
  "command": "node",
  "args": ["updated-server.js"],
  "scope": "user"
}
```

**Response:** `MCPServer`

**Example:**
```bash
curl -X PUT http://localhost:9090/api/v1/mcp/my-server \
  -H "Content-Type: application/json" \
  -d '{"name":"my-server","command":"node","args":["updated.js"]}'
```

### DELETE /api/v1/mcp/:name
Remove an MCP server.

**Query Parameters:**
- `scope` (optional, default: `user`): Scope to delete from

**Response:** `DeletedResponse`

**Example:**
```bash
curl -X DELETE http://localhost:9090/api/v1/mcp/my-server
curl -X DELETE "http://localhost:9090/api/v1/mcp/my-server?scope=user"
```

---

## Plugins

### GET /api/v1/plugins
List installed plugins.

**Response:** `ListResponse<Plugin>`

**Example:**
```bash
curl http://localhost:9090/api/v1/plugins
```

### GET /api/v1/plugins/search
Search installed plugins by name/description.

**Query Parameters:**
- `q` (required): Search query

**Response:** `ListResponse<Plugin>`

**Example:**
```bash
curl "http://localhost:9090/api/v1/plugins/search?q=github"
```

### GET /api/v1/plugins/marketplace
List available plugins from marketplaces.

**Response:** `[PluginMarketplace]`

**Example:**
```bash
curl http://localhost:9090/api/v1/plugins/marketplace
```

### POST /api/v1/plugins/marketplaces
Register a new marketplace.

**Request:** `AddMarketplaceRequest`
```json
{
  "repo": "owner/repo",
  "source": "github"
}
```

**Response:** `Marketplace`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/plugins/marketplaces \
  -H "Content-Type: application/json" \
  -d '{"repo":"owner/repo","source":"github"}'
```

### POST /api/v1/plugins/install
Install a plugin.

**Request:** `InstallPluginRequest`
```json
{
  "pluginName": "my-plugin",
  "marketplace": "official"
}
```

**Response:** `Plugin`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/plugins/install \
  -H "Content-Type: application/json" \
  -d '{"pluginName":"github","marketplace":"official"}'
```

### POST /api/v1/plugins/:name/enable
Enable a plugin.

**Response:** `EnabledResponse`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/plugins/my-plugin/enable
```

### POST /api/v1/plugins/:name/disable
Disable a plugin.

**Response:** `EnabledResponse`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/plugins/my-plugin/disable
```

### DELETE /api/v1/plugins/:name
Uninstall a plugin.

**Response:** `DeletedResponse`

**Example:**
```bash
curl -X DELETE http://localhost:9090/api/v1/plugins/my-plugin
```

---

## Config

### GET /api/v1/config
Get configuration for a scope.

**Query Parameters:**
- `scope` (optional, default: `user`): Configuration scope

**Response:** `ConfigInfo`

**Example:**
```bash
curl http://localhost:9090/api/v1/config
curl http://localhost:9090/api/v1/config?scope=user
```

### PUT /api/v1/config
Update configuration.

**Request:** `UpdateConfigRequest`
```json
{
  "scope": "user",
  "content": {
    "model": "sonnet",
    "permissions": {
      "allow": ["Read", "Write"]
    }
  }
}
```

**Response:** `ConfigInfo`

**Example:**
```bash
curl -X PUT http://localhost:9090/api/v1/config \
  -H "Content-Type: application/json" \
  -d '{"scope":"user","content":{"model":"sonnet"}}'
```

### POST /api/v1/config/validate
Validate configuration.

**Request:** `ValidateConfigRequest`
```json
{
  "content": {
    "model": "sonnet",
    "permissions": {
      "allow": ["Read"]
    }
  }
}
```

**Response:** `ConfigValidationResult`
```json
{
  "isValid": true,
  "errors": []
}
```

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/config/validate \
  -H "Content-Type: application/json" \
  -d '{"content":{"model":"sonnet"}}'
```

---

## Stats

### GET /api/v1/stats
Get overall statistics.

**Response:** `StatsResponse`
```json
{
  "projects": {"total": 10},
  "sessions": {"total": 25, "active": 2},
  "skills": {"total": 50, "active": 30},
  "mcpServers": {"total": 5, "healthy": 4},
  "plugins": {"total": 8, "enabled": 6}
}
```

**Example:**
```bash
curl http://localhost:9090/api/v1/stats
```

### GET /api/v1/stats/recent
Get recent sessions for dashboard timeline.

**Response:** `RecentSessionsResponse`

**Example:**
```bash
curl http://localhost:9090/api/v1/stats/recent
```

### GET /api/v1/settings
Get raw settings from `~/.claude/settings.json`.

**Response:** `ClaudeConfig`

**Example:**
```bash
curl http://localhost:9090/api/v1/settings
```

### GET /api/v1/server/status
Get remote server connection status.

**Response:** `ServerStatus`

**Example:**
```bash
curl http://localhost:9090/api/v1/server/status
```

---

## Auth

### POST /api/v1/auth/connect
Connect to remote server via SSH.

**Request:** `ConnectRequest`
```json
{
  "host": "example.com",
  "port": 22,
  "username": "user",
  "authMethod": "password",
  "credential": "password123"
}
```

**Response:** `ConnectionResponse`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/auth/connect \
  -H "Content-Type: application/json" \
  -d '{"host":"example.com","port":22,"username":"user","authMethod":"password","credential":"pass"}'
```

### POST /api/v1/auth/disconnect
Disconnect from current server.

**Response:** `AcknowledgedResponse`

**Example:**
```bash
curl -X POST http://localhost:9090/api/v1/auth/disconnect
```
