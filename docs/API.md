# ILS Backend API Reference

**Version:** 1.0
**Base URL:** `http://localhost:9999`
**Last Updated:** 2026-02-13

## Table of Contents

- [Overview](#overview)
- [Response Format](#response-format)
- [Health Check](#health-check)
- [Projects](#projects)
- [Sessions](#sessions)
- [Chat & Streaming](#chat--streaming)
- [Skills](#skills)
- [Plugins](#plugins)
- [MCP Servers](#mcp-servers)
- [Configuration](#configuration)
- [Statistics](#statistics)
- [System](#system)
- [Themes](#themes)
- [WebSocket Protocol](#websocket-protocol)
- [Error Handling](#error-handling)

---

## Overview

The ILS (Intelligent Learning System) Backend provides a RESTful API for managing Claude Code projects, sessions, skills, plugins, and MCP servers. It supports real-time chat streaming via Server-Sent Events (SSE) and WebSocket connections.

**Key Features:**
- Project and session management
- Real-time chat with Claude Code CLI
- Skill discovery and installation from GitHub
- Plugin installation and configuration
- MCP server integration
- Configuration management across scopes (user, project, local)
- System monitoring (CPU, memory, disk, network)
- Theme customization

---

## Response Format

All API responses (except health check and streaming endpoints) follow this standard wrapper format:

```json
{
  "success": true,
  "data": { ... },
  "error": null
}
```

**Success Response:**
```json
{
  "success": true,
  "data": {
    "items": [...],
    "total": 10
  },
  "error": null
}
```

**Error Response:**
```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "NOT_FOUND",
    "message": "Resource not found"
  }
}
```

---

## Health Check

### Check API Health

**Endpoint:** `GET /health`
**Description:** Simple health check to verify the API is running.

**Response:** Plain text `"OK"`

**Example:**

```bash
curl http://localhost:9999/health
```

**Response:**
```
OK
```

---

## Projects

Projects represent codebases or directories managed by ILS. The API reads from `~/.claude/projects/` to discover existing Claude Code projects.

### List Projects

**Endpoint:** `GET /api/v1/projects`
**Description:** List all projects discovered from `~/.claude/projects/` sessions-index files.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "name": "string",
        "path": "string",
        "defaultModel": "sonnet",
        "description": "string",
        "createdAt": "2026-02-13T00:00:00Z",
        "lastAccessedAt": "2026-02-13T00:00:00Z",
        "sessionCount": 5,
        "encodedPath": "string"
      }
    ],
    "total": 1
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/projects
```

**Note:** Project IDs are deterministic UUIDs generated from the project path using SHA256.

---

### Get Project

**Endpoint:** `GET /api/v1/projects/:id`
**Description:** Get a single project by deterministic ID.

**Parameters:**
- `id` (path, UUID) - Deterministic project ID

**Response:** Returns a single project object.

**Example:**

```bash
curl http://localhost:9999/api/v1/projects/EC342AC4-974A-4846-B4E0-114DE149F4EC
```

---

### Get Project Sessions

**Endpoint:** `GET /api/v1/projects/:id/sessions`
**Description:** Get all sessions for a specific project.

**Parameters:**
- `id` (path, UUID) - Project ID

**Response:** Returns a list of sessions for the project.

**Example:**

```bash
curl http://localhost:9999/api/v1/projects/EC342AC4-974A-4846-B4E0-114DE149F4EC/sessions
```

---

## Sessions

Sessions represent individual chat conversations with Claude Code.

### List Sessions

**Endpoint:** `GET /api/v1/sessions`
**Description:** List all sessions (DB + external) with unified pagination, deduplication, search, and sorting.

**Query Parameters:**
- `projectId` (optional, UUID) - Filter sessions by project
- `page` (optional, int, default: 1) - Page number (1-based)
- `limit` (optional, int, default: 50, max: 100) - Items per page
- `search` (optional, string) - Case-insensitive search across name, projectName, firstPrompt
- `refresh` (optional, string) - If "true", bypasses external sessions cache

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "claudeSessionId": "string",
        "name": "string",
        "projectId": "uuid",
        "projectName": "string",
        "model": "sonnet",
        "permissionMode": "default",
        "status": "active",
        "messageCount": 10,
        "totalCostUSD": 0.05,
        "source": "ils",
        "forkedFrom": "uuid",
        "firstPrompt": "string",
        "createdAt": "2026-02-13T00:00:00Z",
        "lastActiveAt": "2026-02-13T00:00:00Z"
      }
    ],
    "total": 100,
    "hasMore": true
  }
}
```

**Example:**

```bash
# List all sessions
curl http://localhost:9999/api/v1/sessions

# Filter by project
curl "http://localhost:9999/api/v1/sessions?projectId=EC342AC4-974A-4846-B4E0-114DE149F4EC"

# Search sessions
curl "http://localhost:9999/api/v1/sessions?search=authentication"

# Paginate
curl "http://localhost:9999/api/v1/sessions?page=2&limit=25"
```

---

### Create Session

**Endpoint:** `POST /api/v1/sessions`
**Description:** Create a new chat session.

**Request Body:**
```json
{
  "projectId": "uuid",
  "name": "Session name",
  "model": "sonnet",
  "permissionMode": "default"
}
```

**Permission Modes:**
- `default` - Ask for permission on sensitive operations
- `acceptEdits` - Auto-accept file edits
- `plan` - Plan mode (no execution)
- `bypassPermissions` - Skip all permission prompts

**Response:** Returns the created session object.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Session",
    "model": "sonnet",
    "permissionMode": "default"
  }'
```

---

### Scan External Sessions

**Endpoint:** `GET /api/v1/sessions/scan`
**Description:** Scan `~/.claude/projects/` for external Claude Code sessions not yet tracked by ILS.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "claudeSessionId": "string",
        "name": "string",
        "projectPath": "string",
        "source": "external",
        "lastActiveAt": "2026-02-13T00:00:00Z"
      }
    ],
    "scannedPaths": ["~/.claude/projects/"],
    "total": 5
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/sessions/scan
```

---

### Get Session

**Endpoint:** `GET /api/v1/sessions/:id`
**Description:** Get a single session by ID.

**Parameters:**
- `id` (path, UUID) - Session ID

**Response:** Returns a single session object.

**Example:**

```bash
curl http://localhost:9999/api/v1/sessions/12345678-1234-1234-1234-123456789abc
```

---

### Rename Session

**Endpoint:** `PUT /api/v1/sessions/:id`
**Description:** Rename a session.

**Parameters:**
- `id` (path, UUID) - Session ID

**Request Body:**
```json
{
  "name": "New Session Name"
}
```

**Response:** Returns the updated session object.

**Example:**

```bash
curl -X PUT http://localhost:9999/api/v1/sessions/12345678-1234-1234-1234-123456789abc \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Session Name"}'
```

---

### Delete Session

**Endpoint:** `DELETE /api/v1/sessions/:id`
**Description:** Delete a session and its messages.

**Parameters:**
- `id` (path, UUID) - Session ID

**Response:**
```json
{
  "success": true,
  "data": {
    "deleted": true
  }
}
```

**Example:**

```bash
curl -X DELETE http://localhost:9999/api/v1/sessions/12345678-1234-1234-1234-123456789abc
```

---

### Fork Session

**Endpoint:** `POST /api/v1/sessions/:id/fork`
**Description:** Create a fork (copy) of an existing session with the same settings.

**Parameters:**
- `id` (path, UUID) - Session ID to fork

**Response:** Returns the new forked session object with `forkedFrom` field set.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/sessions/12345678-1234-1234-1234-123456789abc/fork
```

---

### Get Session Messages

**Endpoint:** `GET /api/v1/sessions/:id/messages`
**Description:** Get all messages for a session with pagination.

**Parameters:**
- `id` (path, UUID) - Session ID

**Query Parameters:**
- `limit` (optional, int, default: 100) - Max number of messages to return
- `offset` (optional, int, default: 0) - Number of messages to skip

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "sessionId": "uuid",
        "role": "user",
        "content": "string",
        "createdAt": "2026-02-13T00:00:00Z"
      }
    ],
    "total": 20
  }
}
```

**Example:**

```bash
# Get first 100 messages
curl http://localhost:9999/api/v1/sessions/12345678-1234-1234-1234-123456789abc/messages

# Pagination
curl "http://localhost:9999/api/v1/sessions/12345678-1234-1234-1234-123456789abc/messages?limit=50&offset=50"
```

---

### Get Session Transcript

**Endpoint:** `GET /api/v1/sessions/transcript/:encodedProjectPath/:sessionId`
**Description:** Read messages from an external session's JSONL transcript file.

**Parameters:**
- `encodedProjectPath` (path, string) - Base64-encoded project path
- `sessionId` (path, string) - Claude session ID

**Query Parameters:**
- `limit` (optional, int, default: 200) - Number of messages to return
- `offset` (optional, int, default: 0) - Offset for pagination

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "sessionId": "string",
        "role": "user",
        "content": "string",
        "createdAt": "2026-02-13T00:00:00Z"
      }
    ]
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/sessions/transcript/{encodedPath}/{sessionId}
```

---

## Chat & Streaming

### Stream Chat (SSE)

**Endpoint:** `POST /api/v1/chat/stream`
**Description:** Send a message to Claude Code and stream the response via Server-Sent Events (SSE).

**Request Body:**
```json
{
  "prompt": "Hello, Claude!",
  "sessionId": "uuid",
  "projectId": "uuid",
  "options": {
    "model": "sonnet",
    "permissionMode": "default",
    "maxTurns": 10,
    "maxBudgetUSD": 1.0,
    "allowedTools": ["Read", "Edit"],
    "disallowedTools": ["Bash"],
    "resume": "session-id",
    "forkSession": false
  }
}
```

**Response:** Server-Sent Events stream with `event:` and `data:` fields.

**SSE Event Types:**
- `system` - System initialization message with session ID
- `assistant` - Assistant message chunks (text, tool use, thinking)
- `result` - Final result with usage statistics
- `permission` - Permission request from Claude
- `error` - Error message

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/chat/stream \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "List files in current directory",
    "sessionId": "uuid",
    "options": {
      "model": "sonnet"
    }
  }' \
  --no-buffer
```

**SSE Response Example:**
```
event: system
data: {"type":"system","subtype":"init","data":{"sessionId":"abc123"}}

event: assistant
data: {"type":"assistant","content":[{"type":"text","text":"I'll list the files"}]}

event: result
data: {"type":"result","subtype":"success","sessionId":"abc123","numTurns":1,"totalCostUSD":0.01}
```

**Note:** If a sessionId is provided but doesn't exist in the database, it will be auto-created. This enables client-generated UUIDs for "New Session" flows.

---

### WebSocket Chat

**Endpoint:** `WS /api/v1/chat/ws/:sessionId`
**Description:** Bidirectional WebSocket connection for real-time chat.

**Parameters:**
- `sessionId` (path, UUID) - Session ID

**Client Messages:**
```json
// Send a message
{
  "type": "message",
  "prompt": "Hello!"
}

// Respond to permission request
{
  "type": "permission",
  "requestId": "req-123",
  "decision": "allow",
  "reason": "User approved"
}

// Cancel the current operation
{
  "type": "cancel"
}
```

**Server Messages:**
```json
// Stream message
{
  "type": "stream",
  "message": { /* StreamMessage */ }
}

// Permission request
{
  "type": "permission",
  "request": {
    "requestId": "req-123",
    "toolName": "Bash",
    "toolInput": { "command": "rm -rf /" }
  }
}

// Error
{
  "type": "error",
  "error": {
    "code": "EXECUTION_ERROR",
    "message": "Claude CLI failed"
  }
}

// Complete
{
  "type": "complete",
  "result": {
    "sessionId": "abc123",
    "numTurns": 5,
    "totalCostUSD": 0.05
  }
}
```

**Example (using websocat):**

```bash
# Install websocat: brew install websocat
echo '{"type":"message","prompt":"Hello!"}' | websocat ws://localhost:9999/api/v1/chat/ws/12345678-1234-1234-1234-123456789abc
```

---

### Submit Permission Decision

**Endpoint:** `POST /api/v1/chat/permission/:sessionId/:requestId`
**Description:** Submit a permission decision for a pending request (used with SSE streaming).

**Parameters:**
- `sessionId` (path, string) - Session ID
- `requestId` (path, string) - Permission request ID

**Request Body:**
```json
{
  "decision": "allow"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "acknowledged": true
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/chat/permission/session-123/req-456 \
  -H "Content-Type: application/json" \
  -d '{
    "decision": "allow"
  }'
```

---

### Cancel Chat

**Endpoint:** `POST /api/v1/chat/cancel/:sessionId`
**Description:** Cancel an active chat session's Claude CLI process.

**Parameters:**
- `sessionId` (path, string) - Session ID

**Response:**
```json
{
  "success": true,
  "data": {
    "cancelled": true
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/chat/cancel/abc123
```

---

## Skills

Skills are reusable Claude Code instructions stored in `~/.claude/skills/`.

### List Skills

**Endpoint:** `GET /api/v1/skills`
**Description:** List all available skills.

**Query Parameters:**
- `refresh` (optional, bool) - Bypass cache and re-scan filesystem
- `search` (optional, string) - Filter by name, description, or tags

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "name": "research",
        "description": "Orchestrate parallel scientist agents",
        "version": "1.0.0",
        "tags": ["research", "agents"],
        "isActive": true,
        "path": "/Users/user/.claude/skills/research",
        "source": "local",
        "content": "---\nname: research\n...",
        "stars": 42,
        "author": "username"
      }
    ],
    "total": 12
  }
}
```

**Example:**

```bash
# List all skills
curl http://localhost:9999/api/v1/skills

# Refresh cache
curl "http://localhost:9999/api/v1/skills?refresh=true"

# Search
curl "http://localhost:9999/api/v1/skills?search=research"
```

---

### Create Skill

**Endpoint:** `POST /api/v1/skills`
**Description:** Create a new skill.

**Request Body:**
```json
{
  "name": "my-skill",
  "description": "Brief description",
  "content": "---\nname: my-skill\ndescription: Brief description\n---\n\n# Instructions\n..."
}
```

**Response:** Returns the created skill object.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/skills \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-skill",
    "description": "A custom skill",
    "content": "---\nname: my-skill\n---\n\n# Do something cool"
  }'
```

---

### Search Skills on GitHub

**Endpoint:** `GET /api/v1/skills/search`
**Description:** Search GitHub for skills.

**Query Parameters:**
- `q` (required, string) - Search query
- `page` (optional, int, default: 1) - Page number
- `per_page` (optional, int, default: 20) - Results per page

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "repository": "owner/repo",
        "description": "Skill description",
        "stars": 42,
        "skillPath": "SKILL.md"
      }
    ]
  }
}
```

**Example:**

```bash
curl "http://localhost:9999/api/v1/skills/search?q=claude+skill"
```

---

### Install Skill from GitHub

**Endpoint:** `POST /api/v1/skills/install`
**Description:** Install a skill from GitHub.

**Request Body:**
```json
{
  "repository": "owner/repo",
  "skillPath": "SKILL.md"
}
```

**Response:** Returns the installed skill object.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/skills/install \
  -H "Content-Type: application/json" \
  -d '{
    "repository": "owner/repo",
    "skillPath": "SKILL.md"
  }'
```

---

### Get Skill

**Endpoint:** `GET /api/v1/skills/:name`
**Description:** Get a single skill by name.

**Parameters:**
- `name` (path, string) - Skill name

**Response:** Returns a single skill object with full content.

**Example:**

```bash
curl http://localhost:9999/api/v1/skills/research
```

---

### Update Skill

**Endpoint:** `PUT /api/v1/skills/:name`
**Description:** Update an existing skill's content.

**Parameters:**
- `name` (path, string) - Skill name

**Request Body:**
```json
{
  "content": "---\nname: research\ndescription: Updated\n---\n\n# New instructions"
}
```

**Response:** Returns the updated skill object.

**Example:**

```bash
curl -X PUT http://localhost:9999/api/v1/skills/research \
  -H "Content-Type: application/json" \
  -d '{
    "content": "---\nname: research\n---\n\n# Updated content"
  }'
```

---

### Delete Skill

**Endpoint:** `DELETE /api/v1/skills/:name`
**Description:** Delete a skill.

**Parameters:**
- `name` (path, string) - Skill name

**Response:**
```json
{
  "success": true,
  "data": {
    "deleted": true
  }
}
```

**Example:**

```bash
curl -X DELETE http://localhost:9999/api/v1/skills/my-skill
```

---

## Plugins

Plugins extend Claude Code functionality. Installed plugins are tracked in `~/.claude/plugins/installed_plugins.json`.

### List Plugins

**Endpoint:** `GET /api/v1/plugins`
**Description:** List all installed plugins.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "name": "cache",
        "description": "Plugin description",
        "marketplace": "official",
        "isInstalled": true,
        "isEnabled": true,
        "version": "1.0.0",
        "commands": ["/cache:clear"],
        "agents": ["cache-agent"],
        "path": "/Users/user/.claude/plugins/cache"
      }
    ],
    "total": 3
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/plugins
```

---

### Search Plugins

**Endpoint:** `GET /api/v1/plugins/search`
**Description:** Search installed plugins by name/description.

**Query Parameters:**
- `q` (required, string) - Search query

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "name": "github",
        "description": "GitHub integration"
      }
    ]
  }
}
```

**Example:**

```bash
curl "http://localhost:9999/api/v1/plugins/search?q=github"
```

---

### List Plugin Marketplaces

**Endpoint:** `GET /api/v1/plugins/marketplace`
**Description:** List available plugin marketplaces.

**Response Schema:**
```json
{
  "success": true,
  "data": [
    {
      "name": "claude-plugins-official",
      "source": "anthropics/claude-code",
      "plugins": [
        {
          "name": "github",
          "description": "GitHub integration"
        }
      ]
    }
  ]
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/plugins/marketplace
```

---

### Register Marketplace

**Endpoint:** `POST /api/v1/plugins/marketplaces`
**Description:** Register a new plugin marketplace.

**Request Body:**
```json
{
  "repo": "owner/repo",
  "source": "github"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "name": "repo",
    "source": "github",
    "repo": "owner/repo"
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/plugins/marketplaces \
  -H "Content-Type: application/json" \
  -d '{
    "repo": "owner/repo",
    "source": "github"
  }'
```

---

### Install Plugin

**Endpoint:** `POST /api/v1/plugins/install`
**Description:** Install a plugin via git clone from a marketplace.

**Request Body:**
```json
{
  "pluginName": "github",
  "marketplace": "official"
}
```

**Response:** Returns the installed plugin object.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/plugins/install \
  -H "Content-Type: application/json" \
  -d '{
    "pluginName": "github",
    "marketplace": "claude-plugins-official"
  }'
```

---

### Enable Plugin

**Endpoint:** `POST /api/v1/plugins/:name/enable`
**Description:** Enable a plugin.

**Parameters:**
- `name` (path, string) - Plugin name (format: `plugin-name@marketplace`)

**Response:**
```json
{
  "success": true,
  "data": {
    "enabled": true
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/plugins/cache@official/enable
```

---

### Disable Plugin

**Endpoint:** `POST /api/v1/plugins/:name/disable`
**Description:** Disable a plugin.

**Parameters:**
- `name` (path, string) - Plugin name

**Response:**
```json
{
  "success": true,
  "data": {
    "enabled": false
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/plugins/cache@official/disable
```

---

### Uninstall Plugin

**Endpoint:** `DELETE /api/v1/plugins/:name`
**Description:** Uninstall a plugin.

**Parameters:**
- `name` (path, string) - Plugin name

**Response:**
```json
{
  "success": true,
  "data": {
    "deleted": true
  }
}
```

**Example:**

```bash
curl -X DELETE http://localhost:9999/api/v1/plugins/cache@official
```

---

## MCP Servers

MCP (Model Context Protocol) servers provide external tools and context to Claude Code.

### List MCP Servers

**Endpoint:** `GET /api/v1/mcp`
**Description:** List all configured MCP servers.

**Query Parameters:**
- `scope` (optional, string) - Filter by scope: `user` or `project`
- `refresh` (optional, bool) - Bypass cache and re-read configuration files

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "name": "firecrawl",
        "command": "npx",
        "args": ["-y", "firecrawl-mcp"],
        "env": {
          "FIRECRAWL_API_KEY": "***"
        },
        "scope": "user",
        "status": "unknown",
        "configPath": "/Users/user/.claude.json"
      }
    ],
    "total": 1
  }
}
```

**MCP Status Values:**
- `healthy` - Server is running and responsive
- `unhealthy` - Server is configured but not responding
- `unknown` - Status not yet checked

**Example:**

```bash
# List all MCP servers
curl http://localhost:9999/api/v1/mcp

# Filter by scope
curl "http://localhost:9999/api/v1/mcp?scope=user"

# Refresh cache
curl "http://localhost:9999/api/v1/mcp?refresh=true"
```

---

### Get MCP Server

**Endpoint:** `GET /api/v1/mcp/:name`
**Description:** Get a single MCP server by name.

**Parameters:**
- `name` (path, string) - MCP server name

**Query Parameters:**
- `scope` (optional, string) - Scope to search: `user` or `project`

**Response:** Returns a single MCP server object.

**Example:**

```bash
curl http://localhost:9999/api/v1/mcp/firecrawl
curl "http://localhost:9999/api/v1/mcp/firecrawl?scope=user"
```

---

### Create MCP Server

**Endpoint:** `POST /api/v1/mcp`
**Description:** Add a new MCP server configuration.

**Request Body:**
```json
{
  "name": "my-mcp",
  "command": "npx",
  "args": ["-y", "my-mcp-package"],
  "env": {
    "API_KEY": "secret-key"
  },
  "scope": "user"
}
```

**Response:** Returns the created MCP server object.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-mcp",
    "command": "npx",
    "args": ["-y", "my-mcp-package"],
    "scope": "user"
  }'
```

---

### Update MCP Server

**Endpoint:** `PUT /api/v1/mcp/:name`
**Description:** Update an existing MCP server.

**Parameters:**
- `name` (path, string) - MCP server name

**Request Body:**
```json
{
  "name": "my-mcp",
  "command": "node",
  "args": ["updated-server.js"],
  "scope": "user"
}
```

**Response:** Returns the updated MCP server object.

**Example:**

```bash
curl -X PUT http://localhost:9999/api/v1/mcp/my-server \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-server",
    "command": "node",
    "args": ["updated.js"]
  }'
```

---

### Delete MCP Server

**Endpoint:** `DELETE /api/v1/mcp/:name`
**Description:** Remove an MCP server configuration.

**Parameters:**
- `name` (path, string) - MCP server name

**Query Parameters:**
- `scope` (optional, string, default: `user`) - Scope to delete from

**Response:**
```json
{
  "success": true,
  "data": {
    "deleted": true
  }
}
```

**Example:**

```bash
# Delete from user scope (default)
curl -X DELETE http://localhost:9999/api/v1/mcp/my-mcp

# Delete from project scope
curl -X DELETE "http://localhost:9999/api/v1/mcp/my-mcp?scope=project"
```

---

## Configuration

Configuration management for Claude Code settings across different scopes.

### Get Configuration

**Endpoint:** `GET /api/v1/config`
**Description:** Get configuration for a specific scope.

**Query Parameters:**
- `scope` (optional, string, default: `user`) - Configuration scope: `user`, `project`, or `local`

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "scope": "user",
    "path": "/Users/user/.claude/settings.json",
    "content": {
      "model": "sonnet",
      "permissions": {
        "allow": ["Read", "Edit"],
        "deny": ["Bash"]
      },
      "env": {
        "API_KEY": "value"
      },
      "hooks": {
        "preToolUse": "echo 'Before tool'",
        "postToolUse": "echo 'After tool'"
      },
      "enabledPlugins": {
        "cache@official": true
      },
      "extraKnownMarketplaces": {
        "custom": "owner/repo"
      }
    }
  }
}
```

**Example:**

```bash
# Get user configuration
curl http://localhost:9999/api/v1/config

# Get project configuration
curl "http://localhost:9999/api/v1/config?scope=project"
```

---

### Update Configuration

**Endpoint:** `PUT /api/v1/config`
**Description:** Update configuration for a specific scope.

**Request Body:**
```json
{
  "scope": "user",
  "content": {
    "model": "opus",
    "permissions": {
      "allow": ["Read", "Edit", "Bash"]
    }
  }
}
```

**Response:** Returns the updated configuration.

**Example:**

```bash
curl -X PUT http://localhost:9999/api/v1/config \
  -H "Content-Type: application/json" \
  -d '{
    "scope": "user",
    "content": {
      "model": "opus"
    }
  }'
```

---

### Validate Configuration

**Endpoint:** `POST /api/v1/config/validate`
**Description:** Validate a configuration object without saving it.

**Request Body:**
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

**Response:**
```json
{
  "success": true,
  "data": {
    "isValid": true,
    "errors": []
  }
}
```

**Invalid Example Response:**
```json
{
  "success": true,
  "data": {
    "isValid": false,
    "errors": [
      "Invalid model name: invalid-model",
      "permissions.allow contains empty string"
    ]
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/config/validate \
  -H "Content-Type: application/json" \
  -d '{
    "content": {
      "model": "sonnet"
    }
  }'
```

---

## Statistics

### Get Statistics

**Endpoint:** `GET /api/v1/stats`
**Description:** Get overall statistics about projects, sessions, skills, MCP servers, and plugins.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "projects": {
      "total": 2,
      "active": null
    },
    "sessions": {
      "total": 5,
      "active": 0
    },
    "skills": {
      "total": 12,
      "active": 10
    },
    "mcpServers": {
      "total": 3,
      "healthy": 2
    },
    "plugins": {
      "total": 4,
      "enabled": 3
    }
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/stats
```

---

### Get Recent Sessions

**Endpoint:** `GET /api/v1/stats/recent`
**Description:** Get recent sessions for dashboard timeline.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "name": "Session name",
        "lastActiveAt": "2026-02-13T00:00:00Z"
      }
    ]
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/stats/recent
```

---

### Get Settings

**Endpoint:** `GET /api/v1/settings`
**Description:** Get raw user settings from `~/.claude/settings.json`.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "model": "sonnet",
    "permissions": {
      "allow": ["Read", "Edit"],
      "deny": []
    },
    "env": {},
    "hooks": null,
    "enabledPlugins": {
      "cache@official": true
    },
    "extraKnownMarketplaces": null
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/settings
```

---

## System

System monitoring endpoints for CPU, memory, disk, network, and processes.

### Get System Status

**Endpoint:** `GET /api/v1/system/status`
**Description:** Get current system metrics (CPU, memory, disk, network).

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "cpu": {
      "usage": 45.2,
      "cores": 8
    },
    "memory": {
      "used": 8589934592,
      "total": 17179869184,
      "usagePercent": 50.0
    },
    "disk": {
      "used": 107374182400,
      "total": 214748364800,
      "usagePercent": 50.0
    },
    "network": {
      "bytesIn": 1234567890,
      "bytesOut": 987654321
    }
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/system/status
```

---

### Get System Processes

**Endpoint:** `GET /api/v1/system/processes`
**Description:** List running processes with CPU and memory usage.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "pid": 1234,
        "name": "process-name",
        "cpu": 12.5,
        "memory": 104857600
      }
    ]
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/system/processes
```

---

### Browse Files

**Endpoint:** `GET /api/v1/system/files`
**Description:** Browse filesystem with path parameter.

**Query Parameters:**
- `path` (optional, string, default: "~") - Directory path to browse

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "name": "file.txt",
        "path": "/Users/user/file.txt",
        "isDirectory": false,
        "size": 1024,
        "modifiedAt": "2026-02-13T00:00:00Z"
      }
    ]
  }
}
```

**Example:**

```bash
curl "http://localhost:9999/api/v1/system/files?path=/Users/user/Documents"
```

---

## Themes

Custom theme management for the iOS app.

### List Themes

**Endpoint:** `GET /api/v1/themes`
**Description:** List all available themes (built-in + custom).

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "midnight",
        "name": "Midnight",
        "isBuiltIn": true,
        "isDark": true,
        "colors": {
          "background": "#000000",
          "text": "#FFFFFF"
        }
      }
    ]
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/themes
```

---

### Get Current Theme

**Endpoint:** `GET /api/v1/themes/current`
**Description:** Get the currently active theme from settings.

**Response:** Returns a single theme object.

**Example:**

```bash
curl http://localhost:9999/api/v1/themes/current
```

---

### Set Current Theme

**Endpoint:** `POST /api/v1/themes/current`
**Description:** Set the active theme.

**Request Body:**
```json
{
  "themeId": "midnight"
}
```

**Response:** Returns the updated theme object.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/themes/current \
  -H "Content-Type: application/json" \
  -d '{"themeId":"midnight"}'
```

---

## WebSocket Protocol

The WebSocket protocol provides bidirectional real-time communication for chat sessions.

### Connection

**Endpoint:** `ws://localhost:9999/api/v1/chat/ws/:sessionId`

**Connection Flow:**
1. Client opens WebSocket connection
2. Server validates session ID
3. Connection established - ready to exchange messages

---

### Client Messages

**Send a Message:**
```json
{
  "type": "message",
  "prompt": "Hello, Claude!"
}
```

**Respond to Permission Request:**
```json
{
  "type": "permission",
  "requestId": "req-abc123",
  "decision": "allow",
  "reason": "User approved"
}
```

**Cancel Operation:**
```json
{
  "type": "cancel"
}
```

---

### Server Messages

**Stream Message (Assistant Response):**
```json
{
  "type": "stream",
  "message": {
    "type": "assistant",
    "content": [
      {
        "type": "text",
        "text": "Here's the answer..."
      },
      {
        "type": "toolUse",
        "id": "tool-123",
        "name": "Read",
        "input": {
          "file_path": "/path/to/file"
        }
      }
    ]
  }
}
```

**Permission Request:**
```json
{
  "type": "permission",
  "request": {
    "type": "permission",
    "requestId": "req-abc123",
    "toolName": "Bash",
    "toolInput": {
      "command": "rm file.txt"
    }
  }
}
```

**Error:**
```json
{
  "type": "error",
  "error": {
    "type": "error",
    "code": "EXECUTION_ERROR",
    "message": "Claude CLI failed to execute"
  }
}
```

**Complete (Session Finished):**
```json
{
  "type": "complete",
  "result": {
    "type": "result",
    "subtype": "success",
    "sessionId": "abc123",
    "durationMs": 5000,
    "durationApiMs": 3000,
    "isError": false,
    "numTurns": 3,
    "totalCostUSD": 0.05,
    "usage": {
      "inputTokens": 1000,
      "outputTokens": 500,
      "cacheReadInputTokens": 200,
      "cacheCreationInputTokens": 50
    }
  }
}
```

---

### Content Block Types

**Text Block:**
```json
{
  "type": "text",
  "text": "Human-readable text content"
}
```

**Tool Use Block:**
```json
{
  "type": "toolUse",
  "id": "tool-use-id",
  "name": "Read",
  "input": {
    "file_path": "/path/to/file"
  }
}
```

**Tool Result Block:**
```json
{
  "type": "toolResult",
  "toolUseId": "tool-use-id",
  "content": "File contents...",
  "isError": false
}
```

**Thinking Block:**
```json
{
  "type": "thinking",
  "thinking": "Internal reasoning process..."
}
```

---

## Error Handling

### HTTP Status Codes

- `200 OK` - Request succeeded
- `400 Bad Request` - Invalid request parameters
- `404 Not Found` - Resource not found
- `422 Unprocessable Entity` - Validation failed (e.g., empty prompt)
- `500 Internal Server Error` - Server error
- `503 Service Unavailable` - Claude CLI not available

---

### Error Response Format

All errors follow the standard API response format:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  }
}
```

---

### Common Error Codes

| Code | Description |
|------|-------------|
| `INVALID_REQUEST` | Request body or parameters are invalid |
| `NOT_FOUND` | Requested resource does not exist |
| `ALREADY_EXISTS` | Resource already exists (e.g., duplicate project) |
| `CLAUDE_UNAVAILABLE` | Claude CLI is not installed or not in PATH |
| `EXECUTION_ERROR` | Error executing Claude CLI command |
| `PERMISSION_DENIED` | Permission denied for file/directory access |
| `VALIDATION_ERROR` | Configuration validation failed |
| `INTERNAL_ERROR` | Unexpected server error |

---

### Vapor Error Responses

When using Vapor's `Abort` errors, the response format is:

```json
{
  "error": true,
  "reason": "Resource not found"
}
```

---

## Model Names

Valid model names for Claude Code:

- `sonnet` - Claude Sonnet 4 (default)
- `opus` - Claude Opus 4
- `haiku` - Claude Haiku 4
- `claude-sonnet-4` - Claude Sonnet 4 (full name)
- `claude-opus-4` - Claude Opus 4 (full name)
- `claude-haiku-4` - Claude Haiku 4 (full name)
- `claude-sonnet-4-5` - Claude Sonnet 4.5
- `claude-opus-4-5` - Claude Opus 4.5

---

## Rate Limiting

Currently, the API does not implement rate limiting. This may be added in future versions for production deployments.

---

## CORS

The API does not currently implement CORS headers. For web clients, you may need to run the API behind a proxy that adds appropriate CORS headers.

---

## Changelog

**v1.0.0 (2026-02-13)**
- Consolidated API documentation
- Corrected port to 9999
- Removed Auth, SSH, Fleet, and Setup endpoints
- Added System monitoring endpoints
- Added Themes endpoints
- Updated model names to Claude 4 series
- Enhanced session listing with pagination, search, and deduplication
- Added session rename endpoint
- Added skill search and install from GitHub
- Added plugin search and marketplace management
- Auto-create sessions on first message for client-generated UUIDs

---

## Support

For issues, feature requests, or questions, please refer to the project repository or documentation.
