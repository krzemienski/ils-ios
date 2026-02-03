# ILS Backend API Reference

**Version:** 1.0
**Base URL:** `http://localhost:8080`
**Last Updated:** 2026-02-03

## Table of Contents

- [Overview](#overview)
- [Response Format](#response-format)
- [Authentication](#authentication)
- [Health Check](#health-check)
- [Projects](#projects)
- [Sessions](#sessions)
- [Chat & Streaming](#chat--streaming)
- [Skills](#skills)
- [Plugins](#plugins)
- [MCP Servers](#mcp-servers)
- [Configuration](#configuration)
- [Statistics](#statistics)
- [WebSocket Protocol](#websocket-protocol)
- [Error Handling](#error-handling)

---

## Overview

The ILS (Intelligent Learning System) Backend provides a RESTful API for managing Claude Code projects, sessions, skills, plugins, and MCP servers. It supports real-time chat streaming via Server-Sent Events (SSE) and WebSocket connections.

**Key Features:**
- Project and session management
- Real-time chat with Claude Code CLI
- Skill discovery and management
- Plugin installation and configuration
- MCP server integration
- Configuration management across scopes (user, project, local)

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

## Authentication

Currently, the API does not require authentication. This is suitable for local development and single-user deployments. Future versions may add API key or OAuth support for multi-user scenarios.

---

## Health Check

### Check API Health

**Endpoint:** `GET /health`
**Description:** Simple health check to verify the API is running.

**Response:** Plain text `"OK"`

**Example:**

```bash
curl http://localhost:8080/health
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
**Description:** List all projects discovered from `~/.claude/projects/`.

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
        "description": "string?",
        "createdAt": "2026-02-03T00:00:00Z",
        "lastAccessedAt": "2026-02-03T00:00:00Z",
        "sessionCount": 5
      }
    ],
    "total": 1
  }
}
```

**Example:**

```bash
curl http://localhost:8080/api/v1/projects
```

---

### Create Project

**Endpoint:** `POST /api/v1/projects`
**Description:** Create a new project.

**Request Body:**
```json
{
  "name": "My Project",
  "path": "/path/to/project",
  "defaultModel": "sonnet",
  "description": "Optional description"
}
```

**Response:** Returns the created project object.

**Example:**

```bash
curl -X POST http://localhost:8080/api/v1/projects \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Project",
    "path": "/tmp/my-project",
    "defaultModel": "sonnet"
  }'
```

---

### Get Project

**Endpoint:** `GET /api/v1/projects/:id`
**Description:** Get a single project by ID.

**Parameters:**
- `id` (path, UUID) - Project ID

**Response:** Returns a single project object.

**Example:**

```bash
curl http://localhost:8080/api/v1/projects/EC342AC4-974A-4846-B4E0-114DE149F4EC
```

---

### Update Project

**Endpoint:** `PUT /api/v1/projects/:id`
**Description:** Update an existing project. All fields are optional.

**Parameters:**
- `id` (path, UUID) - Project ID

**Request Body:**
```json
{
  "name": "Updated Name",
  "defaultModel": "opus",
  "description": "Updated description"
}
```

**Response:** Returns the updated project object.

**Example:**

```bash
curl -X PUT http://localhost:8080/api/v1/projects/EC342AC4-974A-4846-B4E0-114DE149F4EC \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Project Name"
  }'
```

---

### Delete Project

**Endpoint:** `DELETE /api/v1/projects/:id`
**Description:** Delete a project and all associated sessions.

**Parameters:**
- `id` (path, UUID) - Project ID

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
curl -X DELETE http://localhost:8080/api/v1/projects/EC342AC4-974A-4846-B4E0-114DE149F4EC
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
curl http://localhost:8080/api/v1/projects/EC342AC4-974A-4846-B4E0-114DE149F4EC/sessions
```

---

## Sessions

Sessions represent individual chat conversations with Claude Code.

### List Sessions

**Endpoint:** `GET /api/v1/sessions`
**Description:** List all sessions, optionally filtered by project.

**Query Parameters:**
- `projectId` (optional, UUID) - Filter sessions by project

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "claudeSessionId": "string?",
        "name": "string?",
        "projectId": "uuid?",
        "projectName": "string?",
        "model": "sonnet",
        "permissionMode": "default",
        "status": "active",
        "messageCount": 10,
        "totalCostUSD": 0.05,
        "source": "ils",
        "forkedFrom": "uuid?",
        "createdAt": "2026-02-03T00:00:00Z",
        "lastActiveAt": "2026-02-03T00:00:00Z"
      }
    ],
    "total": 1
  }
}
```

**Example:**

```bash
# List all sessions
curl http://localhost:8080/api/v1/sessions

# Filter by project
curl "http://localhost:8080/api/v1/sessions?projectId=EC342AC4-974A-4846-B4E0-114DE149F4EC"
```

---

### Create Session

**Endpoint:** `POST /api/v1/sessions`
**Description:** Create a new chat session.

**Request Body:**
```json
{
  "projectId": "uuid (optional)",
  "name": "Session name (optional)",
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
curl -X POST http://localhost:8080/api/v1/sessions \
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
        "name": "string?",
        "projectPath": "string?",
        "source": "external",
        "lastActiveAt": "2026-02-03T00:00:00Z"
      }
    ],
    "scannedPaths": ["~/.claude/projects/"],
    "total": 5
  }
}
```

**Example:**

```bash
curl http://localhost:8080/api/v1/sessions/scan
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
curl http://localhost:8080/api/v1/sessions/12345678-1234-1234-1234-123456789abc
```

---

### Delete Session

**Endpoint:** `DELETE /api/v1/sessions/:id`
**Description:** Delete a session.

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
curl -X DELETE http://localhost:8080/api/v1/sessions/12345678-1234-1234-1234-123456789abc
```

---

### Fork Session

**Endpoint:** `POST /api/v1/sessions/:id/fork`
**Description:** Create a fork (copy) of an existing session.

**Parameters:**
- `id` (path, UUID) - Session ID to fork

**Response:** Returns the new forked session object with `forkedFrom` field set.

**Example:**

```bash
curl -X POST http://localhost:8080/api/v1/sessions/12345678-1234-1234-1234-123456789abc/fork
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
        "createdAt": "2026-02-03T00:00:00Z"
      }
    ],
    "total": 20
  }
}
```

**Example:**

```bash
# Get first 100 messages
curl http://localhost:8080/api/v1/sessions/12345678-1234-1234-1234-123456789abc/messages

# Pagination
curl "http://localhost:8080/api/v1/sessions/12345678-1234-1234-1234-123456789abc/messages?limit=50&offset=50"
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
  "sessionId": "uuid (optional)",
  "projectId": "uuid (optional)",
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
curl -X POST http://localhost:8080/api/v1/chat/stream \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "List files in current directory",
    "options": {
      "model": "sonnet"
    }
  }'
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
echo '{"type":"message","prompt":"Hello!"}' | websocat ws://localhost:8080/api/v1/chat/ws/12345678-1234-1234-1234-123456789abc
```

---

### Submit Permission Decision

**Endpoint:** `POST /api/v1/chat/permission/:requestId`
**Description:** Submit a permission decision for a pending request (used with SSE streaming).

**Parameters:**
- `requestId` (path, string) - Permission request ID

**Request Body:**
```json
{
  "decision": "allow",
  "reason": "User approved this action"
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
curl -X POST http://localhost:8080/api/v1/chat/permission/req-123 \
  -H "Content-Type: application/json" \
  -d '{
    "decision": "allow"
  }'
```

---

### Cancel Chat

**Endpoint:** `POST /api/v1/chat/cancel/:sessionId`
**Description:** Cancel an active chat session.

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
curl -X POST http://localhost:8080/api/v1/chat/cancel/abc123
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
        "content": "---\nname: research\n..."
      }
    ],
    "total": 12
  }
}
```

**Example:**

```bash
# List all skills
curl http://localhost:8080/api/v1/skills

# Refresh cache
curl "http://localhost:8080/api/v1/skills?refresh=true"

# Search
curl "http://localhost:8080/api/v1/skills?search=research"
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
curl -X POST http://localhost:8080/api/v1/skills \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-skill",
    "description": "A custom skill",
    "content": "---\nname: my-skill\n---\n\n# Do something cool"
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
curl http://localhost:8080/api/v1/skills/research
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
curl -X PUT http://localhost:8080/api/v1/skills/research \
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
curl -X DELETE http://localhost:8080/api/v1/skills/my-skill
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
curl http://localhost:8080/api/v1/plugins
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
curl http://localhost:8080/api/v1/plugins/marketplace
```

---

### Install Plugin

**Endpoint:** `POST /api/v1/plugins/install`
**Description:** Install a plugin from a marketplace.

**Request Body:**
```json
{
  "pluginName": "github",
  "marketplace": "claude-plugins-official"
}
```

**Response:** Returns the installed plugin object.

**Example:**

```bash
curl -X POST http://localhost:8080/api/v1/plugins/install \
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
curl -X POST http://localhost:8080/api/v1/plugins/cache@official/enable
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
curl -X POST http://localhost:8080/api/v1/plugins/cache@official/disable
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
curl -X DELETE http://localhost:8080/api/v1/plugins/cache@official
```

---

## MCP Servers

MCP (Model Context Protocol) servers provide external tools and context to Claude Code.

### List MCP Servers

**Endpoint:** `GET /api/v1/mcp`
**Description:** List all configured MCP servers.

**Query Parameters:**
- `scope` (optional, string) - Filter by scope: `user`, `project`, or `managed`
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
curl http://localhost:8080/api/v1/mcp

# Filter by scope
curl "http://localhost:8080/api/v1/mcp?scope=user"

# Refresh cache
curl "http://localhost:8080/api/v1/mcp?refresh=true"
```

---

### Get MCP Server

**Endpoint:** `GET /api/v1/mcp/:name`
**Description:** Get a single MCP server by name.

**Parameters:**
- `name` (path, string) - MCP server name

**Query Parameters:**
- `scope` (optional, string) - Scope to search: `user`, `project`, or `managed`

**Response:** Returns a single MCP server object.

**Example:**

```bash
curl http://localhost:8080/api/v1/mcp/firecrawl
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
curl -X POST http://localhost:8080/api/v1/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-mcp",
    "command": "npx",
    "args": ["-y", "my-mcp-package"],
    "scope": "user"
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
curl -X DELETE http://localhost:8080/api/v1/mcp/my-mcp

# Delete from project scope
curl -X DELETE "http://localhost:8080/api/v1/mcp/my-mcp?scope=project"
```

---

## Configuration

Configuration management for Claude Code settings across different scopes.

### Get Configuration

**Endpoint:** `GET /api/v1/config`
**Description:** Get configuration for a specific scope.

**Query Parameters:**
- `scope` (optional, string, default: `user`) - Configuration scope: `user`, `project`, `local`, or `managed`

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
curl http://localhost:8080/api/v1/config

# Get project configuration
curl "http://localhost:8080/api/v1/config?scope=project"
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
curl -X PUT http://localhost:8080/api/v1/config \
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
curl -X POST http://localhost:8080/api/v1/config/validate \
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
curl http://localhost:8080/api/v1/stats
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
curl http://localhost:8080/api/v1/settings
```

---

## WebSocket Protocol

The WebSocket protocol provides bidirectional real-time communication for chat sessions.

### Connection

**Endpoint:** `ws://localhost:8080/api/v1/chat/ws/:sessionId`

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

- `sonnet` - Claude 3.5 Sonnet (default)
- `opus` - Claude 3 Opus
- `haiku` - Claude 3.5 Haiku
- `claude-sonnet-4-5` - Claude Sonnet 4.5
- `claude-opus-4-5` - Claude Opus 4.5
- `claude-3-5-sonnet` - Claude 3.5 Sonnet (full name)
- `claude-3-5-haiku` - Claude 3.5 Haiku (full name)

---

## Rate Limiting

Currently, the API does not implement rate limiting. This may be added in future versions for production deployments.

---

## CORS

The API does not currently implement CORS headers. For web clients, you may need to run the API behind a proxy that adds appropriate CORS headers.

---

## Changelog

**v1.0.0 (2026-02-03)**
- Initial API release
- Projects, sessions, skills, plugins, MCP servers management
- Real-time chat via SSE and WebSocket
- Configuration management
- Statistics and health endpoints

---

## Support

For issues, feature requests, or questions, please refer to the project repository or documentation.
