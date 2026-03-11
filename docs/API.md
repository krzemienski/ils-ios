# ILS Backend API Reference

**Version:** 1.4
**Base URL:** `http://localhost:9999`
**Last Updated:** 2026-03-10

## Table of Contents

- [Overview](#overview)
- [Response Format](#response-format)
- [Health Check](#health-check)
- [Projects](#projects)
- [Sessions](#sessions)
- [Chat & Streaming](#chat--streaming)
- [Checkpoints](#checkpoints)
- [Skills](#skills)
- [Plugins](#plugins)
- [MCP Servers](#mcp-servers)
- [Configuration](#configuration)
- [Statistics](#statistics)
- [System](#system)
- [Themes](#themes)
- [Teams](#teams)
- [Tunnel](#tunnel)
- [Host Profiles](#host-profiles)
- [Data Erasure](#data-erasure)
- [Activity Feed](#activity-feed)
- [Permissions](#permissions)
- [Pairing](#pairing)
- [Analytics](#analytics)
- [Usage](#usage)
- [Audit Trail](#audit-trail)
- [Workflows](#workflows)
- [Agent Queue](#agent-queue)
- [Session Templates](#session-templates)
- [Session Health](#session-health)
- [Automation Rules](#automation-rules)
- [Suggestions](#suggestions)
- [Terminal](#terminal)
- [SSH](#ssh)
- [Recordings](#recordings)
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
- Agent teams coordination
- Cloudflare tunnel management
- Host profile management
- GDPR data erasure

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

### Check API Health (Simple)

**Endpoint:** `GET /health`
**Description:** Simple health check. Returns plain text `"OK"`.

**Example:**
```bash
curl http://localhost:9999/health
```

---

### Detailed Health Check

**Endpoint:** `GET /api/v1/health`
**Description:** Detailed health check with component status.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "version": "1.4.0",
    "claudeAvailable": true,
    "databaseConnected": true,
    "uptime": 3600
  }
}
```

---

### Readiness Check

**Endpoint:** `GET /api/v1/health/ready`
**Description:** Kubernetes-style readiness probe. Returns 200 when ready to serve traffic.

---

### Liveness Check

**Endpoint:** `GET /api/v1/health/live`
**Description:** Kubernetes-style liveness probe. Returns 200 when process is alive.

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

### Create Project

**Endpoint:** `POST /api/v1/projects`
**Description:** Create a new project record in the database.

**Request Body:**
```json
{
  "name": "my-project",
  "path": "/Users/nick/code/my-project",
  "defaultModel": "sonnet",
  "description": "Optional description"
}
```

**Response:** Returns the created project object.

---

### Update Project

**Endpoint:** `PUT /api/v1/projects/:id`
**Description:** Update project metadata (name, description, defaultModel).

**Parameters:**
- `id` (path, UUID) - Project ID

**Request Body:**
```json
{
  "name": "updated-name",
  "description": "Updated description",
  "defaultModel": "opus"
}
```

**Response:** Returns the updated project object.

---

### Delete Project

**Endpoint:** `DELETE /api/v1/projects/:id`
**Description:** Delete a project record from the database.

**Parameters:**
- `id` (path, UUID) - Project ID

**Response:**
```json
{ "success": true, "data": { "deleted": true } }
```

---

### Bulk Delete Projects

**Endpoint:** `POST /api/v1/projects/bulk-delete`
**Description:** Bulk-delete projects by ID array (max 100).

**Request Body:**
```json
{ "ids": ["uuid1", "uuid2"] }
```

**Response:**
```json
{ "success": true, "data": { "deleted": true } }
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
- `projectName` (optional, string) - Filter sessions by project name (use "Ungrouped" for sessions without projects)
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

# Filter by project name
curl "http://localhost:9999/api/v1/sessions?projectName=my-project"

# Search sessions
curl "http://localhost:9999/api/v1/sessions?search=authentication"

# Paginate
curl "http://localhost:9999/api/v1/sessions?page=2&limit=25"
```

---

### Get Project Groups

**Endpoint:** `GET /api/v1/sessions/projects`
**Description:** Get all projects with their session counts, sorted by most recently active. Optimized for sidebar display without loading all individual sessions.

**Query Parameters:**
- `refresh` (optional, string) - If "true", bypasses external sessions cache

**Response Schema:**
```json
{
  "success": true,
  "data": [
    {
      "name": "project-name",
      "sessionCount": 15,
      "latestDate": "2026-02-13T00:00:00Z"
    },
    {
      "name": "Ungrouped",
      "sessionCount": 5,
      "latestDate": "2026-02-12T00:00:00Z"
    }
  ]
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/sessions/projects
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

### Get Transcript Files

**Endpoint:** `GET /api/v1/sessions/transcript/:encodedProjectPath/:sessionId/files`
**Description:** List files modified during an external session (from JSONL transcript).

**Parameters:**
- `encodedProjectPath` (path, string) - Base64-encoded project path
- `sessionId` (path, string) - Claude session ID

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "files": ["path/to/file1.swift", "path/to/file2.swift"],
    "changes": [
      {
        "path": "path/to/file.swift",
        "operation": "write",
        "timestamp": "2026-02-13T00:00:00Z"
      }
    ]
  }
}
```

---

### Search All Sessions (FTS)

**Endpoint:** `GET /api/v1/sessions/search`
**Description:** Full-text search across all session messages using FTS5.

**Query Parameters:**
- `q` (required, string) - Search query
- `limit` (optional, int, default: 20) - Max results
- `offset` (optional, int, default: 0) - Pagination offset

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "sessionId": "uuid",
        "sessionName": "string",
        "messageId": "uuid",
        "snippet": "...matching text...",
        "createdAt": "2026-02-13T00:00:00Z"
      }
    ],
    "total": 5
  }
}
```

---

### Get Search History

**Endpoint:** `GET /api/v1/sessions/search/history`
**Description:** Get recent search queries (last 20 unique queries).

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "queries": ["authentication", "refactor", "fix bug"]
  }
}
```

---

### Clear Search History

**Endpoint:** `DELETE /api/v1/sessions/search/history`
**Description:** Clear all stored search history.

**Response:**
```json
{ "success": true, "data": { "deleted": true } }
```

---

### Get Model Stats

**Endpoint:** `GET /api/v1/sessions/model-stats`
**Description:** Aggregate model usage statistics across all sessions.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "models": [
      {
        "model": "sonnet",
        "sessionCount": 100,
        "messageCount": 500,
        "totalCostUSD": 1.23
      }
    ],
    "totalSessions": 150
  }
}
```

---

### Suggest Model

**Endpoint:** `POST /api/v1/sessions/suggest-model`
**Description:** Get a smart model routing suggestion based on the task description.

**Request Body:**
```json
{
  "prompt": "Refactor the entire authentication module",
  "projectId": "uuid"
}
```

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "suggestedModel": "opus",
    "reasoning": "Complex refactoring task benefits from Opus's deeper reasoning"
  }
}
```

---

### Compare Sessions

**Endpoint:** `GET /api/v1/sessions/compare`
**Description:** Compare two sessions side-by-side.

**Query Parameters:**
- `a` (required, UUID) - First session ID
- `b` (required, UUID) - Second session ID

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "sessionA": { /* session object */ },
    "sessionB": { /* session object */ },
    "diff": {
      "messageCountDiff": 5,
      "costDiff": 0.02
    }
  }
}
```

---

### Integrity Check

**Endpoint:** `GET /api/v1/sessions/integrity-check`
**Description:** Verify session messageCount integrity. Pass `?fix=true` to auto-correct counts.

**Query Parameters:**
- `fix` (optional, bool) - If true, fix mismatched counts

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "checked": 150,
    "mismatches": 3,
    "fixed": 3
  }
}
```

---

### Update Session Model

**Endpoint:** `PATCH /api/v1/sessions/:id/model`
**Description:** Update the Claude model for an existing session.

**Parameters:**
- `id` (path, UUID) - Session ID

**Request Body:**
```json
{ "model": "opus" }
```

**Response:** Returns the updated session object.

---

### Bulk Delete Sessions

**Endpoint:** `POST /api/v1/sessions/bulk-delete`
**Description:** Delete multiple sessions by ID array (max 100).

**Request Body:**
```json
{ "ids": ["uuid1", "uuid2"] }
```

**Response:**
```json
{ "success": true, "data": { "deleted": true } }
```

---

### Bulk Export Sessions

**Endpoint:** `POST /api/v1/sessions/bulk-export`
**Description:** Export multiple sessions as a JSON archive.

**Request Body:**
```json
{ "ids": ["uuid1", "uuid2"] }
```

**Response:** Returns a JSON array of session export objects (messages included).

---

### Import Session

**Endpoint:** `POST /api/v1/sessions/import`
**Description:** Import a previously exported session (restores session + messages).

**Request Body:** Session export JSON object (as produced by bulk-export).

**Response:** Returns the imported session object.

---

### Get Fork Tree

**Endpoint:** `GET /api/v1/sessions/:id/fork-tree`
**Description:** Get the complete fork lineage for a session family (parent + all forks).

**Parameters:**
- `id` (path, UUID) - Any session ID in the family

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "root": { /* session object */ },
    "forks": [{ /* session object */ }]
  }
}
```

---

### Search Session Messages

**Endpoint:** `GET /api/v1/sessions/:id/messages/search`
**Description:** Search within a specific session's messages.

**Parameters:**
- `id` (path, UUID) - Session ID

**Query Parameters:**
- `q` (required, string) - Search query

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "role": "assistant",
        "content": "...matching content...",
        "createdAt": "2026-02-13T00:00:00Z"
      }
    ]
  }
}
```

---

### Export Session

**Endpoint:** `GET /api/v1/sessions/:id/export`
**Description:** Export a single session as JSON (session metadata + all messages).

**Parameters:**
- `id` (path, UUID) - Session ID

**Response:** JSON export object (Content-Type: application/json).

---

### Register Live Activity Token

**Endpoint:** `POST /api/v1/sessions/:id/live-activity-token`
**Description:** Register an iOS Live Activity push token for a session (used to push content-state updates when app is backgrounded).

**Parameters:**
- `id` (path, UUID) - Session ID

**Request Body:**
```json
{ "token": "apns-push-token-string" }
```

**Response:**
```json
{ "success": true, "data": { "acknowledged": true } }
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

### Preview Skill from GitHub

**Endpoint:** `GET /api/v1/skills/preview`
**Description:** Preview a skill from a GitHub repository before installing.

**Query Parameters:**
- `repository` (required, string) - GitHub repo in `owner/repo` format
- `skillPath` (optional, string, default: `SKILL.md`) - Path to skill file within repo

**Response:** Returns a skill object with full content preview.

---

### Enable Skill

**Endpoint:** `POST /api/v1/skills/:name/enable`
**Description:** Enable a skill (sets `isActive: true`).

**Parameters:**
- `name` (path, string) - Skill name

**Response:**
```json
{ "success": true, "data": { "enabled": true } }
```

---

### Disable Skill

**Endpoint:** `POST /api/v1/skills/:name/disable`
**Description:** Disable a skill (sets `isActive: false`).

**Parameters:**
- `name` (path, string) - Skill name

**Response:**
```json
{ "success": true, "data": { "enabled": false } }
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

### Search Plugins on GitHub

**Endpoint:** `GET /api/v1/plugins/github-search`
**Description:** Search GitHub for plugins by keyword.

**Query Parameters:**
- `q` (required, string) - Search query

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "repository": "owner/repo",
        "description": "Plugin description",
        "stars": 42
      }
    ]
  }
}
```

---

### Preview Plugin from GitHub

**Endpoint:** `GET /api/v1/plugins/preview`
**Description:** Preview a plugin from a GitHub repository before installing.

**Query Parameters:**
- `repository` (required, string) - GitHub repo in `owner/repo` format

**Response:** Returns a plugin object with content preview.

---

### Check Plugin Update

**Endpoint:** `GET /api/v1/plugins/:name/check-update`
**Description:** Check if an installed plugin has an available update.

**Parameters:**
- `name` (path, string) - Plugin name

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "hasUpdate": true,
    "currentVersion": "1.0.0",
    "latestVersion": "1.1.0"
  }
}
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

### Search MCP Servers

**Endpoint:** `GET /api/v1/mcp/search`
**Description:** Search available MCP servers in the marketplace.

**Query Parameters:**
- `q` (optional, string) - Search query

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "name": "firecrawl",
        "description": "Web scraping MCP server",
        "command": "npx",
        "args": ["-y", "firecrawl-mcp"]
      }
    ]
  }
}
```

---

### Get MCP Marketplace

**Endpoint:** `GET /api/v1/mcp/marketplace`
**Description:** List available MCP servers from the official marketplace.

**Response:** Returns an array of available MCP server configurations.

---

### Get MCP Presets

**Endpoint:** `GET /api/v1/mcp/presets`
**Description:** Get pre-configured MCP server presets for quick setup.

**Response:** Returns an array of preset MCP server configurations with name, command, args, and env template.

---

### Validate MCP Config

**Endpoint:** `POST /api/v1/mcp/validate`
**Description:** Validate an MCP server configuration without saving it.

**Request Body:**
```json
{
  "name": "my-mcp",
  "command": "npx",
  "args": ["-y", "my-mcp-package"]
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

---

### Get MCP Server Health

**Endpoint:** `GET /api/v1/mcp/:name/health`
**Description:** Check health of a specific MCP server.

**Parameters:**
- `name` (path, string) - MCP server name

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "name": "firecrawl",
    "status": "healthy",
    "latencyMs": 42
  }
}
```

---

### Get MCP Server Logs

**Endpoint:** `GET /api/v1/mcp/:name/logs`
**Description:** Get recent logs for an MCP server.

**Parameters:**
- `name` (path, string) - MCP server name

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "logs": ["line1", "line2"],
    "name": "firecrawl"
  }
}
```

---

### Enable MCP Server

**Endpoint:** `POST /api/v1/mcp/:name/enable`
**Description:** Enable a configured MCP server.

**Parameters:**
- `name` (path, string) - MCP server name

**Response:**
```json
{ "success": true, "data": { "enabled": true } }
```

---

### Disable MCP Server

**Endpoint:** `POST /api/v1/mcp/:name/disable`
**Description:** Disable an MCP server without removing its configuration.

**Parameters:**
- `name` (path, string) - MCP server name

**Response:**
```json
{ "success": true, "data": { "enabled": false } }
```

---

### Restart MCP Server

**Endpoint:** `POST /api/v1/mcp/:name/restart`
**Description:** Restart a running MCP server.

**Parameters:**
- `name` (path, string) - MCP server name

**Response:**
```json
{ "success": true, "data": { "restarted": true } }
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

### Get Effective Configuration

**Endpoint:** `GET /api/v1/config/effective`
**Description:** Get the merged/effective configuration (all scopes combined with precedence).

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "scope": "effective",
    "content": {
      "model": "sonnet",
      "permissions": { "allow": ["Read", "Edit"] }
    }
  }
}
```

---

### Export Configuration

**Endpoint:** `GET /api/v1/config/export`
**Description:** Export all configuration scopes as a single JSON document for backup/transfer.

**Response:** JSON export of all scopes (user, project, local).

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

### Validate API Key

**Endpoint:** `POST /api/v1/config/validate-api-key`
**Description:** Validate an Anthropic API key by making a test call.

**Request Body:**
```json
{ "apiKey": "sk-ant-..." }
```

**Response:**
```json
{
  "success": true,
  "data": {
    "isValid": true,
    "error": null
  }
}
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
**Description:** Get recent sessions for dashboard timeline (DB + external merged, top 10).

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
    ],
    "total": 100
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

### Get Server Status

**Endpoint:** `GET /api/v1/server/status`
**Description:** Get local server connection status.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "connected": true
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/server/status
```

---

## System

System monitoring endpoints for CPU, memory, disk, network, and processes.

### Get System Metrics

**Endpoint:** `GET /api/v1/system/metrics`
**Description:** Get current system metrics (CPU, memory, disk, network).

**Response Schema:**
```json
{
  "cpu": 45.2,
  "memory": {
    "used": 8589934592,
    "total": 17179869184,
    "percentage": 50.0
  },
  "disk": {
    "used": 107374182400,
    "total": 214748364800,
    "percentage": 50.0
  },
  "network": {
    "bytesIn": 1234567890,
    "bytesOut": 987654321
  },
  "loadAverage": [2.5, 2.3, 2.1]
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/system/metrics
```

---

### Get System Processes

**Endpoint:** `GET /api/v1/system/processes`
**Description:** List running processes with CPU and memory usage.

**Query Parameters:**
- `sort` (optional, string, default: "cpu") - Sort by "cpu" or "memory"

**Response Schema:**
```json
[
  {
    "name": "process-name",
    "pid": 1234,
    "cpuPercent": 12.5,
    "memoryMB": 100.0
  }
]
```

**Example:**

```bash
# Sort by CPU (default)
curl http://localhost:9999/api/v1/system/processes

# Sort by memory
curl "http://localhost:9999/api/v1/system/processes?sort=memory"
```

---

### Browse Files

**Endpoint:** `GET /api/v1/system/files`
**Description:** Browse filesystem with path parameter (restricted to home directory).

**Query Parameters:**
- `path` (required, string) - Directory path to browse

**Response Schema:**
```json
[
  {
    "name": "file.txt",
    "isDirectory": false,
    "size": 1024,
    "modifiedDate": "2026-02-13T00:00:00Z"
  }
]
```

**Example:**

```bash
curl "http://localhost:9999/api/v1/system/files?path=/Users/user/Documents"
```

---

### Get Metrics Source

**Endpoint:** `GET /api/v1/system/metrics/source`
**Description:** Get the source of system metrics (local or remote).

**Response Schema:**
```json
{
  "source": "local",
  "hostName": null
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/system/metrics/source
```

---

### Get Claude Processes

**Endpoint:** `GET /api/v1/system/processes/claude`
**Description:** List only Claude CLI processes currently running.

**Response Schema:**
```json
[
  {
    "name": "claude",
    "pid": 1234,
    "cpuPercent": 5.2,
    "memoryMB": 200.0,
    "sessionId": "uuid"
  }
]
```

---

### Get Process History

**Endpoint:** `GET /api/v1/system/processes/history`
**Description:** Get historical process resource usage snapshots.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "snapshots": [
      {
        "timestamp": "2026-03-10T12:00:00Z",
        "cpu": 45.2,
        "memoryMB": 8192
      }
    ]
  }
}
```

---

### Kill Process

**Endpoint:** `POST /api/v1/system/processes/:pid/kill`
**Description:** Send SIGTERM to a running process by PID.

**Parameters:**
- `pid` (path, int) - Process ID

**Response:**
```json
{ "success": true, "data": { "killed": true } }
```

---

### Get Process Alerts

**Endpoint:** `GET /api/v1/system/processes/alerts`
**Description:** Get alerts for processes exceeding CPU or memory thresholds.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "alerts": [
      {
        "pid": 1234,
        "name": "node",
        "type": "high_cpu",
        "value": 98.5,
        "threshold": 80.0
      }
    ]
  }
}
```

---

### Get Current Version

**Endpoint:** `GET /api/v1/system/version/current`
**Description:** Get the current ILS backend version.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "version": "1.4.0",
    "buildDate": "2026-03-10",
    "claudeCliVersion": "1.0.15"
  }
}
```

---

### Get Version History

**Endpoint:** `GET /api/v1/system/version/history`
**Description:** Get the version history / changelog entries.

**Response:** Array of version objects with version string and release notes.

---

### Check for Updates

**Endpoint:** `GET /api/v1/system/version/check-updates`
**Description:** Check if a newer version of ILS is available.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "hasUpdate": false,
    "latestVersion": "1.4.0",
    "currentVersion": "1.4.0"
  }
}
```

---

### Check Compatibility

**Endpoint:** `GET /api/v1/system/version/compatibility`
**Description:** Check compatibility between the iOS client and backend versions.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "compatible": true,
    "minClientVersion": "1.0.0",
    "minBackendVersion": "1.3.0"
  }
}
```

---

### Get System Limits

**Endpoint:** `GET /api/v1/system/limits`
**Description:** Get current session resource limits (max turns, budget caps).

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "defaultMaxTurns": 10,
    "defaultMaxBudgetUSD": 5.0,
    "sessionLimits": {}
  }
}
```

---

### Update Session Limits

**Endpoint:** `PUT /api/v1/system/limits/:sessionId`
**Description:** Update resource limits for a specific session.

**Parameters:**
- `sessionId` (path, string) - Session ID

**Request Body:**
```json
{
  "maxTurns": 20,
  "maxBudgetUSD": 10.0
}
```

**Response:** Returns the updated limits for the session.

---

### Live Metrics Stream (WebSocket)

**Endpoint:** `WS /api/v1/system/metrics/live`
**Description:** Stream system metrics via WebSocket every 2 seconds.

**Server Messages:**
```json
{
  "cpu": 45.2,
  "memory": {
    "used": 8589934592,
    "total": 17179869184,
    "percentage": 50.0
  },
  "disk": {
    "used": 107374182400,
    "total": 214748364800,
    "percentage": 50.0
  },
  "network": {
    "bytesIn": 1234567890,
    "bytesOut": 987654321
  },
  "loadAverage": [2.5, 2.3, 2.1]
}
```

**Example (using websocat):**

```bash
websocat ws://localhost:9999/api/v1/system/metrics/live
```

---

## Themes

Custom theme management for the iOS app. Note: Themes controller manages **custom themes only** (stored in database). Built-in themes are handled client-side.

### List Custom Themes

**Endpoint:** `GET /api/v1/themes`
**Description:** List all custom themes.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "name": "My Custom Theme",
        "description": "A custom theme",
        "author": "username",
        "version": "1.0.0",
        "colors": {
          "background": "#000000",
          "text": "#FFFFFF"
        },
        "typography": {},
        "spacing": {},
        "cornerRadius": {},
        "shadows": {}
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

### Create Custom Theme

**Endpoint:** `POST /api/v1/themes`
**Description:** Create a new custom theme.

**Request Body:**
```json
{
  "name": "My Theme",
  "description": "A custom theme",
  "author": "username",
  "version": "1.0.0",
  "colors": {
    "background": "#000000",
    "text": "#FFFFFF"
  },
  "typography": {},
  "spacing": {},
  "cornerRadius": {},
  "shadows": {}
}
```

**Response:** Returns the created theme object.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/themes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Dark Blue",
    "colors": {"background": "#001122"}
  }'
```

---

### Get Custom Theme

**Endpoint:** `GET /api/v1/themes/:id`
**Description:** Get a single custom theme by ID.

**Parameters:**
- `id` (path, UUID) - Theme ID

**Response:** Returns a single theme object.

**Example:**

```bash
curl http://localhost:9999/api/v1/themes/12345678-1234-1234-1234-123456789abc
```

---

### Update Custom Theme

**Endpoint:** `PUT /api/v1/themes/:id`
**Description:** Update an existing custom theme.

**Parameters:**
- `id` (path, UUID) - Theme ID

**Request Body:**
```json
{
  "name": "Updated Theme",
  "colors": {
    "background": "#111111"
  }
}
```

**Response:** Returns the updated theme object.

**Example:**

```bash
curl -X PUT http://localhost:9999/api/v1/themes/12345678-1234-1234-1234-123456789abc \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Theme"}'
```

---

### Delete Custom Theme

**Endpoint:** `DELETE /api/v1/themes/:id`
**Description:** Delete a custom theme.

**Parameters:**
- `id` (path, UUID) - Theme ID

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
curl -X DELETE http://localhost:9999/api/v1/themes/12345678-1234-1234-1234-123456789abc
```

---

## Teams

Agent teams coordination for multi-agent workflows.

### List Teams

**Endpoint:** `GET /api/v1/teams`
**Description:** List all agent teams.

**Response Schema:**
```json
{
  "success": true,
  "data": [
    {
      "name": "team-alpha",
      "description": "Analysis team",
      "members": [
        {
          "name": "agent-1",
          "agentType": "analyst",
          "model": "sonnet",
          "status": "idle"
        }
      ],
      "createdAt": "2026-02-13T00:00:00Z"
    }
  ]
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/teams
```

---

### Create Team

**Endpoint:** `POST /api/v1/teams`
**Description:** Create a new agent team.

**Request Body:**
```json
{
  "name": "team-alpha",
  "description": "Analysis team"
}
```

**Response:** Returns the created team object.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/teams \
  -H "Content-Type: application/json" \
  -d '{
    "name": "team-alpha",
    "description": "Analysis team"
  }'
```

---

### Get Team Details

**Endpoint:** `GET /api/v1/teams/:name`
**Description:** Get details for a specific team (includes live member status).

**Parameters:**
- `name` (path, string) - Team name

**Response:** Returns a single team object with updated member statuses.

**Example:**

```bash
curl http://localhost:9999/api/v1/teams/team-alpha
```

---

### Delete Team

**Endpoint:** `DELETE /api/v1/teams/:name`
**Description:** Delete a team (shuts down all teammates first).

**Parameters:**
- `name` (path, string) - Team name

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
curl -X DELETE http://localhost:9999/api/v1/teams/team-alpha
```

---

### Spawn Teammate

**Endpoint:** `POST /api/v1/teams/:name/spawn`
**Description:** Spawn a new teammate in the team.

**Parameters:**
- `name` (path, string) - Team name

**Request Body:**
```json
{
  "name": "agent-1",
  "agentType": "analyst",
  "model": "sonnet",
  "prompt": "Analyze the codebase"
}
```

**Response:** Returns the created teammate object.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/teams/team-alpha/spawn \
  -H "Content-Type: application/json" \
  -d '{
    "name": "agent-1",
    "agentType": "analyst",
    "model": "sonnet",
    "prompt": "Analyze the codebase"
  }'
```

---

### Shutdown Teammates

**Endpoint:** `POST /api/v1/teams/:name/shutdown`
**Description:** Shutdown one or all teammates.

**Parameters:**
- `name` (path, string) - Team name

**Request Body (optional):**
```json
{
  "memberName": "agent-1"
}
```

**Note:** If no body or no `memberName` provided, shuts down all teammates.

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
# Shutdown specific member
curl -X POST http://localhost:9999/api/v1/teams/team-alpha/shutdown \
  -H "Content-Type: application/json" \
  -d '{"memberName":"agent-1"}'

# Shutdown all members
curl -X POST http://localhost:9999/api/v1/teams/team-alpha/shutdown
```

---

### Remove Team Member

**Endpoint:** `DELETE /api/v1/teams/:name/members/:memberName`
**Description:** Remove a specific team member.

**Parameters:**
- `name` (path, string) - Team name
- `memberName` (path, string) - Member name

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
curl -X DELETE http://localhost:9999/api/v1/teams/team-alpha/members/agent-1
```

---

### List Team Tasks

**Endpoint:** `GET /api/v1/teams/:name/tasks`
**Description:** List all tasks for a team.

**Parameters:**
- `name` (path, string) - Team name

**Response Schema:**
```json
{
  "success": true,
  "data": [
    {
      "id": "task-id",
      "subject": "Analyze module X",
      "description": "Detailed task description",
      "status": "pending",
      "owner": null,
      "createdAt": "2026-02-13T00:00:00Z"
    }
  ]
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/teams/team-alpha/tasks
```

---

### Create Team Task

**Endpoint:** `POST /api/v1/teams/:name/tasks`
**Description:** Create a new task for the team.

**Parameters:**
- `name` (path, string) - Team name

**Request Body:**
```json
{
  "subject": "Analyze module X",
  "description": "Detailed task description"
}
```

**Response:** Returns the created task object.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/teams/team-alpha/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "subject": "Analyze module X",
    "description": "Check for bugs"
  }'
```

---

### Update Team Task

**Endpoint:** `PUT /api/v1/teams/:name/tasks/:taskId`
**Description:** Update a task's status or owner.

**Parameters:**
- `name` (path, string) - Team name
- `taskId` (path, string) - Task ID

**Request Body:**
```json
{
  "status": "in_progress",
  "owner": "agent-1"
}
```

**Response:** Returns the updated task object.

**Example:**

```bash
curl -X PUT http://localhost:9999/api/v1/teams/team-alpha/tasks/task-123 \
  -H "Content-Type: application/json" \
  -d '{
    "status": "completed",
    "owner": "agent-1"
  }'
```

---

### List Team Messages

**Endpoint:** `GET /api/v1/teams/:name/messages`
**Description:** List all messages in the team.

**Parameters:**
- `name` (path, string) - Team name

**Response Schema:**
```json
{
  "success": true,
  "data": [
    {
      "from": "agent-1",
      "to": "agent-2",
      "content": "Message content",
      "timestamp": "2026-02-13T00:00:00Z"
    }
  ]
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/teams/team-alpha/messages
```

---

### Send Team Message

**Endpoint:** `POST /api/v1/teams/:name/messages`
**Description:** Send a message within the team.

**Parameters:**
- `name` (path, string) - Team name

**Request Body:**
```json
{
  "from": "agent-1",
  "to": "agent-2",
  "content": "Message content"
}
```

**Response:** Returns the created message object.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/teams/team-alpha/messages \
  -H "Content-Type: application/json" \
  -d '{
    "from": "agent-1",
    "to": "agent-2",
    "content": "Analysis complete"
  }'
```

---

## Tunnel

Cloudflare tunnel management for remote access.

### Start Tunnel

**Endpoint:** `POST /api/v1/tunnel/start`
**Description:** Start a Cloudflare tunnel (quick or named).

**Request Body (optional):**
```json
{
  "token": "tunnel-token",
  "tunnelName": "my-tunnel",
  "domain": "my-app.example.com"
}
```

**Note:** If token, tunnelName, and domain are all provided, starts a named tunnel. Otherwise starts a quick tunnel with a random trycloudflare.com URL.

**Response:**
```json
{
  "url": "https://random-name.trycloudflare.com"
}
```

**Error Response (cloudflared not installed):**
```json
{
  "error": "cloudflared not installed",
  "installUrl": "https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
}
```

**Example:**

```bash
# Start quick tunnel
curl -X POST http://localhost:9999/api/v1/tunnel/start

# Start named tunnel
curl -X POST http://localhost:9999/api/v1/tunnel/start \
  -H "Content-Type: application/json" \
  -d '{
    "token": "my-token",
    "tunnelName": "my-tunnel",
    "domain": "my-app.example.com"
  }'
```

---

### Stop Tunnel

**Endpoint:** `POST /api/v1/tunnel/stop`
**Description:** Stop the running tunnel.

**Response:**
```json
{
  "stopped": true
}
```

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/tunnel/stop
```

---

### Get Tunnel Status

**Endpoint:** `GET /api/v1/tunnel/status`
**Description:** Get current tunnel status.

**Response Schema:**
```json
{
  "running": true,
  "url": "https://random-name.trycloudflare.com",
  "uptime": 3600,
  "mode": "quick"
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/tunnel/status
```

---

### Get Tunnel Health

**Endpoint:** `GET /api/v1/tunnel/health`
**Description:** Check if the tunnel is healthy and reachable.

**Response Schema:**
```json
{
  "healthy": true,
  "url": "https://random-name.trycloudflare.com",
  "latencyMs": 45
}
```

---

### Get Tunnel Logs

**Endpoint:** `GET /api/v1/tunnel/logs`
**Description:** Get recent cloudflared process logs.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "logs": ["2026-03-10T12:00:00Z INF Tunnel connected", "..."],
    "lineCount": 50
  }
}
```

---

## Host Profiles

Host profiles represent remote machines in the ILS fleet for distributed Claude Code execution. The active host profile determines which machine ILS connects to. The underlying database table is `fleet_hosts` to preserve existing data.

**Backward-Compatible Aliases:** All `/api/v1/host-profiles/*` routes are also accessible via `/api/v1/fleet/*` (e.g., `GET /api/v1/fleet`, `POST /api/v1/fleet/register`). The `/fleet` prefix is maintained for backward compatibility and routes to the same handlers.

> **Authentication**: When `ILS_ADMIN_KEY` is configured in the server environment, all Host Profiles endpoints require the `X-Admin-Token` header matching that key. Example: `-H "X-Admin-Token: $ILS_ADMIN_KEY"`. In development (no `ILS_ADMIN_KEY` set), requests are allowed without authentication.

### List Host Profiles

**Endpoint:** `GET /api/v1/host-profiles`
**Description:** List all registered host profiles, sorted by active status then name. Returns the active host ID separately for quick lookup.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "hosts": [
      {
        "id": "uuid",
        "name": "My Mac Mini",
        "host": "192.168.1.100",
        "port": 22,
        "backendPort": 9999,
        "username": "nick",
        "authMethod": "key",
        "isActive": true,
        "healthStatus": "healthy",
        "lastHealthCheck": "2026-02-28T12:00:00Z",
        "platform": "macOS"
      }
    ],
    "activeHostId": "uuid"
  }
}
```

**Fields:**
- `hosts` - Array of all registered host profiles
- `activeHostId` - UUID of the currently active host, or `null` if none is active
- `healthStatus` - One of `"healthy"`, `"degraded"`, `"unreachable"`, `"unknown"`

**Example:**

```bash
curl http://localhost:9999/api/v1/host-profiles \
  -H "X-Admin-Token: $ILS_ADMIN_KEY"
```

---

### Register Host Profile

**Endpoint:** `POST /api/v1/host-profiles/register`
**Description:** Register a new remote host profile. The new host is created with `isActive: false` and `healthStatus: "unknown"`.

**Request Body:**
```json
{
  "name": "My Mac Mini",
  "host": "192.168.1.100",
  "port": 22,
  "backendPort": 9999,
  "username": "nick",
  "authMethod": "key",
  "credential": "/path/to/private/key"
}
```

**Required Fields:**
- `name` (string, max 255 chars) - Human-readable display name
- `host` (string, max 255 chars) - Hostname or IP address
- `port` (integer, default: `22`) - SSH port on the remote machine
- `backendPort` (integer, default: `9999`) - Port the ILS backend listens on remotely

**Optional Fields:**
- `username` (string) - SSH username for authentication
- `authMethod` (string) - Authentication method, e.g. `"password"` or `"key"`
- `credential` (string) - Credential value (password or private key path)

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "My Mac Mini",
    "host": "192.168.1.100",
    "port": 22,
    "backendPort": 9999,
    "username": "nick",
    "authMethod": "key",
    "isActive": false,
    "healthStatus": "unknown",
    "lastHealthCheck": null,
    "platform": null
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/host-profiles/register \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: $ILS_ADMIN_KEY" \
  -d '{
    "name": "My Mac Mini",
    "host": "192.168.1.100",
    "port": 22,
    "backendPort": 9999,
    "username": "nick",
    "authMethod": "key"
  }'
```

---

### Activate Host Profile

**Endpoint:** `POST /api/v1/host-profiles/:id/activate`
**Description:** Set a host profile as the active host. All other profiles are atomically deactivated in the same database transaction to ensure only one host is active at a time.

**Parameters:**
- `id` (path, UUID) - Host profile ID

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "My Mac Mini",
    "host": "192.168.1.100",
    "port": 22,
    "backendPort": 9999,
    "username": "nick",
    "authMethod": "key",
    "isActive": true,
    "healthStatus": "unknown",
    "lastHealthCheck": null,
    "platform": null
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/host-profiles/550e8400-e29b-41d4-a716-446655440000/activate \
  -H "X-Admin-Token: $ILS_ADMIN_KEY"
```

---

### Delete Host Profile

**Endpoint:** `DELETE /api/v1/host-profiles/:id`
**Description:** Permanently delete a host profile by ID.

**Parameters:**
- `id` (path, UUID) - Host profile ID

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
curl -X DELETE http://localhost:9999/api/v1/host-profiles/550e8400-e29b-41d4-a716-446655440000 \
  -H "X-Admin-Token: $ILS_ADMIN_KEY"
```

---

### Get Host Profile Health

**Endpoint:** `GET /api/v1/host-profiles/:id/health`
**Description:** Check the health of a specific host profile by performing a live HTTP GET to `http(s)://{host}:{backendPort}/health`. Times out after 5 seconds. The health status and timestamp are persisted to the database after each check.

**Parameters:**
- `id` (path, UUID) - Host profile ID

**Health Status Values:**
| Status | Description |
|--------|-------------|
| `healthy` | Remote backend responded with HTTP 2xx |
| `degraded` | Remote backend responded with a non-2xx status |
| `unreachable` | Connection refused, timed out, or DNS failure |
| `unknown` | Health has not been checked yet |

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "hostId": "uuid",
    "status": "healthy",
    "backendVersion": "1.1.0",
    "claudeAvailable": true,
    "lastChecked": "2026-02-28T12:00:00Z"
  }
}
```

**Fields:**
- `hostId` - UUID of the host profile that was checked
- `status` - Current health status (`healthy`, `degraded`, `unreachable`, `unknown`)
- `backendVersion` - Version string returned by the remote `/health` endpoint, or `"unknown"`
- `claudeAvailable` - `true` if the remote backend responded with HTTP 2xx
- `lastChecked` - ISO 8601 timestamp of when this check was performed

**Example:**

```bash
curl http://localhost:9999/api/v1/host-profiles/550e8400-e29b-41d4-a716-446655440000/health \
  -H "X-Admin-Token: $ILS_ADMIN_KEY"
```

---

## Data Erasure

The Data Erasure API provides GDPR-compliant deletion of all user data stored by ILS, including sessions, messages, and associated metadata.

> **Authentication**: When `ILS_ADMIN_KEY` is configured in the server environment, all Data Erasure endpoints require the `X-Admin-Token` header matching that key. Example: `-H "X-Admin-Token: $ILS_ADMIN_KEY"`. In development (no `ILS_ADMIN_KEY` set), requests are allowed without authentication.

### Delete All Data

**Endpoint:** `DELETE /api/v1/data/all`
**Description:** Permanently deletes all sessions, messages, and user data stored by ILS. This operation is irreversible and is intended for GDPR compliance (right to erasure).

**Request Body:** None required.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "sessionsDeleted": 42,
    "messagesDeleted": 1337,
    "projectsDeleted": 5,
    "themesDeleted": 2,
    "fleetHostsDeleted": 3,
    "cacheEntriesDeleted": 18
  }
}
```

**Fields:**
- `sessionsDeleted` - Number of sessions that were deleted
- `messagesDeleted` - Number of messages that were deleted
- `projectsDeleted` - Number of projects that were deleted
- `themesDeleted` - Number of themes that were deleted
- `fleetHostsDeleted` - Number of fleet/host profile entries that were deleted
- `cacheEntriesDeleted` - Number of cache entries that were deleted

**Example:**

```bash
curl -X DELETE http://localhost:9999/api/v1/data/all \
  -H "X-Admin-Token: $ILS_ADMIN_KEY"
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "sessionsDeleted": 42,
    "messagesDeleted": 1337,
    "projectsDeleted": 5,
    "themesDeleted": 2,
    "fleetHostsDeleted": 3,
    "cacheEntriesDeleted": 18
  }
}
```

**⚠️ Warning:** This operation is **permanent and irreversible**. All sessions and messages stored in the ILS database will be deleted. External Claude Code session files in `~/.claude/projects/` are not affected.

---

## Activity Feed

### List Activity Events

**Endpoint:** `GET /api/v1/activity/events`
**Description:** Retrieve recent activity events derived from sessions and messages.

**Query Parameters:**
- `limit` (optional, int, default: 50, max: 200) - Maximum events to return
- `since` (optional, ISO 8601 date) - Only return events after this timestamp
- `eventType` (optional, comma-separated string) - Filter by event types (e.g., `session_created,message_sent`)
- `sessionId` (optional, UUID) - Restrict to a single session
- `projectName` (optional, string) - Restrict to sessions in a project
- `severity` (optional, string) - Filter by severity: `info`, `warning`, or `error`

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "events": [
      {
        "id": "uuid",
        "timestamp": "2026-02-28T12:00:00Z",
        "eventType": "session_created",
        "severity": "info",
        "sessionId": "uuid",
        "projectName": "my-project",
        "title": "Session created",
        "details": "string"
      }
    ],
    "totalCount": 5,
    "unreadCount": 2,
    "hasMore": false
  }
}
```

**Example:**

```bash
# Get recent events
curl http://localhost:9999/api/v1/activity/events

# Get events since a specific time
curl "http://localhost:9999/api/v1/activity/events?since=2026-02-28T00:00:00Z"

# Filter by type and severity
curl "http://localhost:9999/api/v1/activity/events?eventType=session_created,message_sent&severity=error"
```

---

### Stream Activity Events

**Endpoint:** `GET /api/v1/activity/events/stream`
**Description:** Server-Sent Events stream providing real-time activity updates.

**Behavior:**
- Polls database every 5 seconds for new activity
- Sends heartbeat comment every 15 seconds to keep connection alive
- Supports same query parameters as `/activity/events` for filtering

**Example:**

```bash
curl http://localhost:9999/api/v1/activity/events/stream
```

---

## Checkpoints

Checkpoints allow saving and restoring the state of a session's messages at a specific point in time.

### List Checkpoints

**Endpoint:** `GET /api/v1/sessions/:id/checkpoints`
**Description:** List all checkpoints for a session, ordered newest first.

**Parameters:**
- `id` (path, UUID) - Session ID

**Response Schema:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "sessionId": "uuid",
      "label": "Checkpoint name",
      "messageCount": 42,
      "isAuto": false,
      "createdAt": "2026-02-28T12:00:00Z"
    }
  ]
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/sessions/12345678-1234-1234-1234-123456789abc/checkpoints
```

---

### Create Checkpoint

**Endpoint:** `POST /api/v1/sessions/:id/checkpoints`
**Description:** Create a new checkpoint, snapshots current message IDs.

**Parameters:**
- `id` (path, UUID) - Session ID

**Request Body:**
```json
{
  "label": "Checkpoint name",
  "isAuto": false,
  "maxRetained": 20
}
```

**Response:** Returns the newly created checkpoint object.

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/sessions/12345678-1234-1234-1234-123456789abc/checkpoints \
  -H "Content-Type: application/json" \
  -d '{"label":"Before refactoring","isAuto":false}'
```

---

### Delete Checkpoint

**Endpoint:** `DELETE /api/v1/sessions/:id/checkpoints/:checkpointId`
**Description:** Delete a specific checkpoint.

**Parameters:**
- `id` (path, UUID) - Session ID
- `checkpointId` (path, UUID) - Checkpoint ID

**Response:**
```json
{
  "success": true,
  "data": { "deleted": true }
}
```

**Example:**

```bash
curl -X DELETE http://localhost:9999/api/v1/sessions/12345678-1234-1234-1234-123456789abc/checkpoints/abcdef01-2345-6789-abcd-ef0123456789
```

---

### Restore Checkpoint

**Endpoint:** `POST /api/v1/sessions/:id/checkpoints/:checkpointId/restore`
**Description:** Restore session to the message state captured in a checkpoint.

**Parameters:**
- `id` (path, UUID) - Session ID
- `checkpointId` (path, UUID) - Checkpoint ID

**Response:**
```json
{
  "success": true,
  "data": {
    "sessionId": "uuid",
    "messagesRestored": 42
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/sessions/12345678-1234-1234-1234-123456789abc/checkpoints/abcdef01-2345-6789-abcd-ef0123456789/restore
```

---

## Permissions

Manage Claude Code tool-use permission requests and history.

### List Pending Permissions

**Endpoint:** `GET /api/v1/permissions/pending`
**Description:** List all pending permission requests.

**Query Parameters:**
- `sessionId` (optional, UUID) - Filter to a specific session

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "requestId": "string",
        "sessionId": "uuid",
        "toolName": "read_file",
        "toolInput": { "path": "/path/to/file" },
        "timestamp": "2026-02-28T12:00:00Z"
      }
    ],
    "total": 3,
    "pendingCount": 3
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/permissions/pending
```

---

### List Permission History

**Endpoint:** `GET /api/v1/permissions/history`
**Description:** List resolved permission records (allow/deny decisions).

**Query Parameters:**
- `limit` (optional, int, default: 50, max: 500) - Maximum records to return
- `sessionId` (optional, UUID) - Filter to a specific session

**Response:** Similar structure to pending permissions, with decisions included.

**Example:**

```bash
curl http://localhost:9999/api/v1/permissions/history?limit=100
```

---

### Submit Permission Decision

**Endpoint:** `POST /api/v1/permissions/:requestId/decide`
**Description:** Submit an allow or deny decision for a pending permission request.

**Parameters:**
- `requestId` (path, string) - Permission request ID

**Request Body:**
```json
{
  "decision": "allow"
}
```

**Decision Values:** `allow` or `deny`

**Response:**
```json
{
  "success": true,
  "data": {}
}
```

**Example:**

```bash
curl -X POST http://localhost:9999/api/v1/permissions/req-123/decide \
  -H "Content-Type: application/json" \
  -d '{"decision":"allow"}'
```

---

### Clear Pending Permissions

**Endpoint:** `DELETE /api/v1/permissions/pending`
**Description:** Clear all pending permission requests.

**Query Parameters:**
- `sessionId` (optional, UUID) - Clear only pending requests for a specific session

**Response:**
```json
{
  "success": true,
  "data": { "cleared": true }
}
```

**Example:**

```bash
curl -X DELETE http://localhost:9999/api/v1/permissions/pending
```

---

## Pairing

QR code-based pairing for device registration and authentication.

### Generate Pairing QR Code

**Endpoint:** `GET /api/v1/pairing/qr`
**Description:** Generate a new QR code pairing token.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "token": "uuid",
    "qrData": "{\"backendUrl\":\"http://...\",\"version\":\"1.0.0\"}",
    "expiresAt": "2026-02-28T13:00:00Z"
  }
}
```

**Example:**

```bash
curl http://localhost:9999/api/v1/pairing/qr
```

---

### Invalidate Pairing Token

**Endpoint:** `DELETE /api/v1/pairing/qr/:token`
**Description:** Invalidate a pairing token. Safe to call even if token already expired.

**Parameters:**
- `token` (path, UUID) - Pairing token to invalidate

**Response:**
```json
{
  "success": true,
  "data": { "invalidated": true }
}
```

**Example:**

```bash
curl -X DELETE http://localhost:9999/api/v1/pairing/qr/12345678-1234-1234-1234-123456789abc
```

---

## Analytics

Analytics endpoints compute data from existing sessions and filesystem sources.

### Get Activity Timeline

**Endpoint:** `GET /api/v1/analytics/activity`
**Description:** Daily activity timeline of session and message counts.

**Query Parameters:**
- `period` (optional, string, default: `week`) - `week` (7 days) or `month` (30 days)

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "projectName": "All Projects",
    "dataPoints": [
      {
        "date": "2026-03-04",
        "sessionCount": 5,
        "messageCount": 42,
        "tokensUsed": 0
      }
    ],
    "startDate": "2026-03-04",
    "endDate": "2026-03-10",
    "granularity": "day"
  }
}
```

---

### Get Session Metrics

**Endpoint:** `GET /api/v1/analytics/sessions`
**Description:** Aggregated session effectiveness metrics including model breakdown and completion rates.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "projectName": "All Projects",
    "totalSessions": 150,
    "avgMessagesPerSession": 8.5,
    "avgSessionDurationSeconds": 0,
    "completedSessions": 140,
    "abandonedSessions": 10,
    "completionRate": 93.3,
    "avgIterationsPerSession": 8.5,
    "modelUsage": [
      {
        "model": "sonnet",
        "sessionCount": 100,
        "messageCount": 800,
        "tokensUsed": 0,
        "usagePercentage": 66.7
      }
    ]
  }
}
```

---

### Get Skill Analytics

**Endpoint:** `GET /api/v1/analytics/skills`
**Description:** Skill usage analytics listing all configured skills with active/inactive status.

**Query Parameters:**
- `period` (optional, string, default: `week`) - `week` or `month`

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "projectName": "All Projects",
    "totalSessions": 150,
    "skillStats": [
      {
        "skillName": "research",
        "invocationCount": 1,
        "sessionCount": 0,
        "usagePercentage": 0.0,
        "avgEffectivenessRating": null
      }
    ],
    "startDate": "2026-03-04",
    "endDate": "2026-03-10"
  }
}
```

---

### Get Analytics Summary

**Endpoint:** `GET /api/v1/analytics/summary`
**Description:** High-level summary of activity for the given period.

**Query Parameters:**
- `period` (optional, string, default: `week`) - `week` or `month`

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "projectName": "All Projects",
    "periodLabel": "Last 7 days",
    "startDate": "2026-03-04",
    "endDate": "2026-03-10",
    "totalSessions": 25,
    "totalMessages": 200,
    "totalTokensUsed": 0,
    "completionRate": 92.0,
    "topModel": "sonnet",
    "topSkill": "research"
  }
}
```

---

### Export Analytics

**Endpoint:** `GET /api/v1/analytics/export`
**Description:** Full analytics export combining activity, session metrics, skill analytics, and summary.

**Query Parameters:**
- `period` (optional, string, default: `week`) - `week` or `month`

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "projectName": "All Projects",
    "exportedAt": "2026-03-10T12:00:00Z",
    "summary": { /* AnalyticsSummary */ },
    "activityTimeline": [ /* ActivityDataPoint[] */ ],
    "sessionMetrics": { /* SessionMetricsResponse */ },
    "skillAnalytics": { /* SkillAnalyticsResponse */ }
  }
}
```

---

## Usage

Usage metrics and rate limit tracking.

### Get Usage Metrics

**Endpoint:** `GET /api/v1/usage`
**Description:** Aggregate usage metrics with daily breakdown and rate limit status.

**Query Parameters:**
- `period` (optional, string, default: `monthly`) - `daily`, `weekly`, or `monthly`

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "period": "monthly",
    "periodStart": "2026-02-09",
    "periodEnd": "2026-03-10",
    "totalMessages": 1200,
    "totalSessions": 150,
    "averageMessagesPerSession": 8.0,
    "totalDurationSeconds": 0,
    "dailyBreakdown": [
      {
        "date": "2026-03-10",
        "messageCount": 42,
        "sessionCount": 5,
        "totalDurationSeconds": 0
      }
    ],
    "projectBreakdown": [
      {
        "projectName": "ils-ios",
        "messageCount": 800,
        "sessionCount": 100,
        "totalDurationSeconds": 0,
        "percentageOfTotal": 66.7
      }
    ],
    "rateLimitStatus": {
      "messagesUsed": 12,
      "messagesLimit": 45,
      "windowResetsAt": "2026-03-10T17:00:00Z",
      "windowDurationSeconds": 18000
    }
  }
}
```

---

### Export Usage as CSV

**Endpoint:** `GET /api/v1/usage/export`
**Description:** Export usage data as a CSV file (date, messages, cost).

**Query Parameters:**
- `period` (optional, string, default: `monthly`) - `daily`, `weekly`, or `monthly`

**Response:** CSV file download (`Content-Type: text/csv`).

```
date,messages,cost
2026-03-10,42,0.00
2026-03-09,38,0.00
```

---

## Audit Trail

The AI action audit trail records every file operation, command execution, and tool use performed by Claude. Entries are immutable (append-only). File operations can be rolled back.

### List Audit Actions

**Endpoint:** `GET /api/v1/audit-actions`
**Description:** List audit actions with optional filtering.

**Query Parameters:**
- `sessionId` (optional, string) - Filter to a specific session
- `actionType` (optional, string) - Filter by action type (e.g. `file_write`, `file_create`, `file_delete`, `command`, `tool_use`, `rollback`)
- `filePath` (optional, string) - Filter by file path (prefix match)
- `since` (optional, ISO 8601) - Only actions at or after this time
- `until` (optional, ISO 8601) - Only actions at or before this time
- `limit` (optional, int, default: 50, max: 500)
- `offset` (optional, int, default: 0)

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "actions": [
      {
        "id": "uuid",
        "sessionId": "string",
        "sessionName": "string",
        "actionType": "file_write",
        "description": "Wrote 42 lines to main.swift",
        "filePath": "/Users/nick/Desktop/ils-ios/Sources/main.swift",
        "command": null,
        "toolName": "Edit",
        "beforeContent": "old content",
        "afterContent": "new content",
        "metadata": {},
        "isRollbackable": true,
        "rollbackStatus": "not_rolled_back",
        "rolledBackAt": null,
        "rollbackAuditId": null,
        "createdAt": "2026-03-10T12:00:00Z"
      }
    ],
    "totalCount": 150,
    "hasMore": true
  }
}
```

**Action Types:**
- `file_write` - File content modified
- `file_create` - New file created
- `file_delete` - File deleted
- `command` - Shell command executed
- `tool_use` - Claude tool invoked (non-file)
- `rollback` - Rollback action recorded

---

### Create Audit Action

**Endpoint:** `POST /api/v1/audit-actions`
**Description:** Record a new audit action entry. The trail is append-only.

**Request Body:**
```json
{
  "sessionId": "string",
  "sessionName": "My Session",
  "actionType": "file_write",
  "description": "Updated authentication logic",
  "filePath": "/path/to/file.swift",
  "command": null,
  "toolName": "Edit",
  "beforeContent": "old content",
  "afterContent": "new content",
  "metadata": {},
  "isRollbackable": true
}
```

**Response:** Returns the created audit action object.

---

### Rollback Audit Action

**Endpoint:** `POST /api/v1/audit-actions/:id/rollback`
**Description:** Roll back a specific audit action. For file operations (`file_write`, `file_create`, `file_delete`), restores the file to its pre-action state. The rollback itself is recorded as a new immutable audit entry.

**Parameters:**
- `id` (path, UUID) - Audit action ID

**Request Body (optional):**
```json
{ "reason": "Accidentally deleted wrong file" }
```

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "results": [
      {
        "actionId": "uuid",
        "succeeded": true,
        "errorMessage": null,
        "rollbackAuditAction": { /* AuditAction */ }
      }
    ]
  }
}
```

**Errors:**
- `422` - Action is not rollbackable (`isRollbackable: false`)
- `409` - Action has already been rolled back

---

## Workflows

Workflow automation management. Workflows are stored as JSON files on the filesystem.

### List Workflows

**Endpoint:** `GET /api/v1/workflows`
**Description:** List all workflows, sorted by most recently updated.

**Response Schema:**
```json
{
  "success": true,
  "data": [
    {
      "id": "string",
      "name": "My Workflow",
      "description": "string",
      "status": "idle",
      "nodes": [],
      "connections": [],
      "createdAt": "2026-03-10T12:00:00Z",
      "updatedAt": "2026-03-10T12:00:00Z"
    }
  ]
}
```

---

### Create Workflow

**Endpoint:** `POST /api/v1/workflows`
**Description:** Create a new workflow.

**Request Body:**
```json
{
  "name": "My Workflow",
  "description": "Optional description",
  "nodes": [],
  "connections": []
}
```

**Response:** Returns the created workflow object.

---

### Get Workflow

**Endpoint:** `GET /api/v1/workflows/:id`
**Description:** Get a specific workflow by ID.

**Parameters:**
- `id` (path, string) - Workflow ID

**Response:** Returns the workflow object.

---

### Update Workflow

**Endpoint:** `PUT /api/v1/workflows/:id`
**Description:** Update an existing workflow.

**Parameters:**
- `id` (path, string) - Workflow ID

**Request Body:**
```json
{
  "name": "Updated Name",
  "description": "Updated description",
  "status": "idle",
  "nodes": [],
  "connections": []
}
```

**Response:** Returns the updated workflow object.

---

### Delete Workflow

**Endpoint:** `DELETE /api/v1/workflows/:id`
**Description:** Delete a workflow by ID.

**Parameters:**
- `id` (path, string) - Workflow ID

**Response:**
```json
{ "success": true, "data": { "deleted": true } }
```

---

### Execute Workflow

**Endpoint:** `POST /api/v1/workflows/:id/execute`
**Description:** Start executing a workflow.

**Parameters:**
- `id` (path, string) - Workflow ID

**Request Body (optional):**
```json
{ "parameters": { "key": "value" } }
```

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "id": "execution-uuid",
    "workflowId": "string",
    "status": "running",
    "progress": 0.0,
    "currentNodeId": null,
    "startedAt": "2026-03-10T12:00:00Z",
    "completedAt": null,
    "error": null
  }
}
```

---

### Pause Workflow

**Endpoint:** `POST /api/v1/workflows/:id/pause`
**Description:** Pause a running workflow execution.

**Parameters:**
- `id` (path, string) - Workflow ID

**Response:** Returns the updated execution object with `status: "paused"`.

---

### Cancel Workflow

**Endpoint:** `POST /api/v1/workflows/:id/cancel`
**Description:** Cancel an active workflow execution.

**Parameters:**
- `id` (path, string) - Workflow ID

**Response:** Returns the updated execution object with `status: "cancelled"`.

---

### Stream Latest Execution (SSE)

**Endpoint:** `GET /api/v1/workflows/:id/executions/latest`
**Description:** Stream execution progress for the latest execution via Server-Sent Events. Polls every 500ms until terminal state reached.

**Parameters:**
- `id` (path, string) - Workflow ID

**SSE Events:** Each event contains the full `WorkflowExecution` JSON. Stream ends when status is `completed`, `failed`, or `cancelled`.

---

### Create Workflow Schedule

**Endpoint:** `POST /api/v1/workflows/:id/schedules`
**Description:** Create a cron schedule for a workflow.

**Parameters:**
- `id` (path, string) - Workflow ID

**Request Body:**
```json
{
  "cron": "0 9 * * 1-5",
  "enabled": true,
  "timezone": "America/New_York"
}
```

**Response:** Returns the created `WorkflowSchedule` object (HTTP 201).

---

### List Workflow Schedules

**Endpoint:** `GET /api/v1/workflows/:id/schedules`
**Description:** List all schedules for a workflow.

**Response:** Returns an array of `WorkflowSchedule` objects.

---

### Get Workflow Schedule

**Endpoint:** `GET /api/v1/workflows/:id/schedules/:scheduleId`
**Description:** Get a specific schedule.

---

### Update Workflow Schedule

**Endpoint:** `PUT /api/v1/workflows/:id/schedules/:scheduleId`
**Description:** Update a schedule's cron expression, enabled state, or timezone.

**Request Body:**
```json
{
  "cron": "0 10 * * 1-5",
  "enabled": false,
  "timezone": "UTC"
}
```

---

### Delete Workflow Schedule

**Endpoint:** `DELETE /api/v1/workflows/:id/schedules/:scheduleId`
**Description:** Delete a workflow schedule.

**Response:**
```json
{ "success": true, "data": { "deleted": true } }
```

---

## Agent Queue

Task queue for running Claude agents sequentially or in parallel.

### List Queue

**Endpoint:** `GET /api/v1/queue`
**Description:** List all queue items with counts.

**Query Parameters:**
- `status` (optional, string) - Filter by status: `queued`, `running`, `paused`, `completed`, `failed`, `cancelled`
- `projectId` (optional, UUID) - Filter by project

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "title": "Run code review",
        "description": "Review all uncommitted changes",
        "status": "queued",
        "priority": 0,
        "position": 0,
        "executionMode": "sequential",
        "projectId": null,
        "dependsOn": [],
        "createdAt": "2026-03-10T12:00:00Z",
        "startedAt": null,
        "completedAt": null
      }
    ],
    "executionMode": "sequential",
    "isPaused": false,
    "totalCount": 3,
    "runningCount": 1,
    "pendingCount": 2
  }
}
```

---

### Enqueue Task

**Endpoint:** `POST /api/v1/queue`
**Description:** Add a new task to the queue.

**Request Body:**
```json
{
  "title": "Run code review",
  "description": "Review all uncommitted changes for bugs",
  "priority": 0,
  "executionMode": "sequential",
  "projectId": "uuid",
  "dependsOn": []
}
```

**Response:** Returns the created `AgentQueueItem`.

---

### Get Queue Templates

**Endpoint:** `GET /api/v1/queue/templates`
**Description:** List built-in task templates for common batch operations.

**Built-in Templates:** `run-all-tests`, `code-review`, `fix-lint`, `update-dependencies`, `generate-docs`, `security-audit`

**Response Schema:**
```json
{
  "success": true,
  "data": [
    {
      "id": "code-review",
      "title": "Code Review",
      "description": "Review all uncommitted changes for quality and correctness",
      "prompt": "Review all uncommitted changes...",
      "tags": ["review", "quality"]
    }
  ]
}
```

---

### Get Queue Item

**Endpoint:** `GET /api/v1/queue/:id`
**Description:** Get a specific queue item by ID.

---

### Update Queue Item

**Endpoint:** `PUT /api/v1/queue/:id`
**Description:** Update mutable fields of a queue item (title, description, priority, dependsOn). Running items cannot have priority or dependencies changed.

**Request Body:**
```json
{
  "title": "Updated title",
  "priority": 1,
  "dependsOn": ["uuid1"]
}
```

---

### Delete Queue Item

**Endpoint:** `DELETE /api/v1/queue/:id`
**Description:** Delete a queue item. Running items are cancelled before deletion.

**Response:**
```json
{ "success": true, "data": { "deleted": true } }
```

---

### Pause Queue Item

**Endpoint:** `POST /api/v1/queue/:id/pause`
**Description:** Pause a currently running queue item.

**Response:** Returns the updated `AgentQueueItem` with `status: "paused"`.

---

### Resume Queue Item

**Endpoint:** `POST /api/v1/queue/:id/resume`
**Description:** Resume a paused queue item.

**Response:** Returns the updated `AgentQueueItem` with `status: "queued"`.

---

### Cancel Queue Item

**Endpoint:** `POST /api/v1/queue/:id/cancel`
**Description:** Cancel a queue item, stopping execution if running.

**Response:** Returns the updated `AgentQueueItem` with `status: "cancelled"`.

---

### Bulk Delete Queue Items

**Endpoint:** `POST /api/v1/queue/bulk-delete`
**Description:** Delete multiple queue items by UUID array. Running items are cancelled first.

**Request Body:**
```json
{ "ids": ["uuid1", "uuid2"] }
```

**Response:**
```json
{ "success": true, "data": { "deleted": true } }
```

---

### Reorder Queue

**Endpoint:** `POST /api/v1/queue/reorder`
**Description:** Reorder queued items by specifying the desired ID sequence. Items not in the list are appended at the end preserving relative order.

**Request Body:**
```json
{ "orderedIds": ["uuid2", "uuid1", "uuid3"] }
```

**Response:** Returns the full updated `AgentQueue` snapshot.

---

## Session Templates

Session templates provide reusable configurations (model, permission mode, system prompt) for quick session creation.

### List Templates

**Endpoint:** `GET /api/v1/templates`
**Description:** List all templates: built-in defaults merged with user-created DB templates.

**Query Parameters:**
- `search` (optional, string) - Case-insensitive filter on name and description

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "name": "Default",
        "description": "Standard session with default settings",
        "model": "sonnet",
        "permissionMode": "default",
        "systemPrompt": "",
        "maxBudgetUSD": null,
        "maxTurns": null,
        "isFavorite": false,
        "isBuiltIn": true
      }
    ]
  }
}
```

---

### Create Template

**Endpoint:** `POST /api/v1/templates`
**Description:** Create a new user-defined template.

**Request Body:**
```json
{
  "name": "My Template",
  "description": "For TypeScript projects",
  "model": "sonnet",
  "permissionMode": "acceptEdits",
  "systemPrompt": "You are working on a TypeScript project...",
  "maxBudgetUSD": 2.0,
  "maxTurns": 20,
  "isFavorite": false
}
```

**Response:** Returns the created template object.

---

### Get Template

**Endpoint:** `GET /api/v1/templates/:id`
**Description:** Get a specific template by ID. Checks built-in templates first, then DB.

---

### Update Template

**Endpoint:** `PUT /api/v1/templates/:id`
**Description:** Update a user-defined template. Returns 403 if the template is built-in.

---

### Delete Template

**Endpoint:** `DELETE /api/v1/templates/:id`
**Description:** Delete a user-defined template. Returns 403 if built-in.

---

### Bulk Delete Templates

**Endpoint:** `POST /api/v1/templates/bulk-delete`
**Description:** Bulk-delete user-defined templates (max 100). Returns 403 if any ID is a built-in template.

**Request Body:**
```json
{ "ids": ["uuid1", "uuid2"] }
```

---

## Session Health

Health analysis for sessions and projects.

### Get Health Summary

**Endpoint:** `GET /api/v1/sessions/health/summary`
**Description:** Overall health summary across all sessions.

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "totalSessions": 150,
    "healthySessions": 140,
    "warningSessions": 8,
    "criticalSessions": 2,
    "overallScore": 94.5
  }
}
```

---

### Export Health Report

**Endpoint:** `GET /api/v1/sessions/health/export`
**Description:** Export health report as JSON for all sessions.

**Response:** Health report JSON (Content-Type: application/json).

---

### Get Session Health

**Endpoint:** `GET /api/v1/sessions/:id/health`
**Description:** Get health metrics for a specific session.

**Parameters:**
- `id` (path, UUID) - Session ID

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "sessionId": "uuid",
    "score": 85.0,
    "status": "warning",
    "issues": [
      {
        "type": "high_cost",
        "severity": "warning",
        "message": "Session cost exceeds $2"
      }
    ]
  }
}
```

---

### Get Projects Health

**Endpoint:** `GET /api/v1/projects/health`
**Description:** Get aggregated health metrics per project.

**Response Schema:**
```json
{
  "success": true,
  "data": [
    {
      "projectName": "ils-ios",
      "sessionCount": 50,
      "avgScore": 90.0,
      "status": "healthy"
    }
  ]
}
```

---

## Automation Rules

Event-driven automation rules that trigger actions when session conditions are met.

### List Automation Rules

**Endpoint:** `GET /api/v1/automation-rules`
**Description:** List all automation rules with optional filters.

**Query Parameters:**
- `sessionId` (optional, UUID) - Filter by session
- `projectName` (optional, string) - Filter by project
- `isEnabled` (optional, bool) - Filter by enabled state

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "rules": [
      {
        "id": "uuid",
        "name": "High Cost Alert",
        "description": "Notify when cost exceeds $5",
        "triggerType": "cost_threshold",
        "conditions": [
          { "field": "cost_usd", "operator": "greater_than", "value": "5.0" }
        ],
        "actionType": "notify",
        "actionConfig": { "notificationMessage": "Cost exceeded $5" },
        "isEnabled": true,
        "sessionId": null,
        "projectName": null,
        "createdAt": "2026-03-10T12:00:00Z"
      }
    ],
    "totalCount": 3
  }
}
```

**Trigger Types:** `cost_threshold`, `session_complete`, `error_occurred`, `idle_timeout`, `context_near_limit`

**Action Types:** `notify`, `export`, `fork`

---

### Create Automation Rule

**Endpoint:** `POST /api/v1/automation-rules`
**Description:** Create a new automation rule.

**Request Body:**
```json
{
  "name": "High Cost Alert",
  "description": "Notify when session cost exceeds $5",
  "triggerType": "cost_threshold",
  "conditions": [
    { "field": "cost_usd", "operator": "greater_than", "value": "5.0" }
  ],
  "actionType": "notify",
  "actionConfig": { "notificationMessage": "Session cost exceeded $5" },
  "isEnabled": true,
  "sessionId": null,
  "projectName": null
}
```

**Response:** Returns the created rule object.

---

### Get Automation Rule

**Endpoint:** `GET /api/v1/automation-rules/:id`
**Description:** Get a specific automation rule by ID.

---

### Update Automation Rule

**Endpoint:** `PUT /api/v1/automation-rules/:id`
**Description:** Update an existing automation rule (partial update — only provided fields changed).

---

### Delete Automation Rule

**Endpoint:** `DELETE /api/v1/automation-rules/:id`
**Description:** Delete an automation rule.

**Response:**
```json
{ "success": true, "data": { "deleted": true } }
```

---

### Get Rule Execution History

**Endpoint:** `GET /api/v1/automation-rules/executions`
**Description:** Get rule execution history with optional filters.

**Query Parameters:**
- `ruleId` (optional, UUID) - Filter by rule
- `sessionId` (optional, UUID) - Filter by session
- `status` (optional, string) - Filter by status: `success`, `failed`, `skipped`

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "executions": [
      {
        "id": "uuid",
        "ruleId": "uuid",
        "sessionId": "uuid",
        "status": "success",
        "executedAt": "2026-03-10T12:00:00Z",
        "error": null
      }
    ],
    "totalCount": 15
  }
}
```

---

### Get Rule Templates

**Endpoint:** `GET /api/v1/automation-rules/templates`
**Description:** Get pre-built rule templates for common automation scenarios.

**Built-in Templates:** `high-cost-alert`, `auto-export-on-complete`, `fork-on-error`, `idle-timeout-notify`, `context-limit-warning`

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "templates": [
      {
        "id": "high-cost-alert",
        "name": "High Cost Alert",
        "description": "Notify when session cost exceeds $5",
        "triggerType": "cost_threshold",
        "conditions": [{ "field": "cost_usd", "operator": "greater_than", "value": "5.0" }],
        "actionType": "notify",
        "actionConfig": { "notificationMessage": "Session cost exceeded $5" }
      }
    ]
  }
}
```

---

## Suggestions

Smart suggestion engine for sessions, skills, and prompt inputs.

### Get Session Suggestions

**Endpoint:** `GET /api/v1/suggestions/sessions`
**Description:** Get ranked session suggestions based on context, recency, and interaction history.

**Query Parameters:**
- `context` (optional, string) - Free-text context for keyword scoring
- `projectName` (optional, string) - Boost sessions from same project
- `gitBranch` (optional, string) - Boost sessions matching branch name
- `limit` (optional, int, default: 5, max: 50)

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "sessionId": "uuid",
        "sessionName": "Auth refactor",
        "projectName": "ils-ios",
        "score": 0.85,
        "reason": "Recent activity in same project"
      }
    ]
  }
}
```

---

### Get Skill Suggestions

**Endpoint:** `GET /api/v1/suggestions/skills`
**Description:** Get ranked skill suggestions based on project and context.

**Query Parameters:**
- `projectName` (optional, string) - Project name for tag-based matching
- `context` (optional, string) - Free-text context
- `limit` (optional, int, default: 5, max: 50)

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "skillName": "research",
        "description": "Orchestrate parallel scientist agents",
        "score": 0.72,
        "tags": ["research", "agents"]
      }
    ]
  }
}
```

---

### Get Abandoned Sessions

**Endpoint:** `GET /api/v1/suggestions/abandoned`
**Description:** Get sessions inactive for 24+ hours that are worth resuming.

**Query Parameters:**
- `limit` (optional, int, default: 5, max: 20)

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "sessionId": "uuid",
        "sessionName": "Refactor auth module",
        "projectName": "ils-ios",
        "lastActiveAt": "2026-03-08T10:00:00Z",
        "hoursSinceActive": 50,
        "messageCount": 12
      }
    ]
  }
}
```

---

### Get Continuation Summary

**Endpoint:** `GET /api/v1/suggestions/continuation/:sessionId`
**Description:** Get a smart continuation summary for a specific session (last messages, open tasks, suggested next steps).

**Parameters:**
- `sessionId` (path, UUID) - Session ID

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "sessionId": "uuid",
    "sessionName": "Auth refactor",
    "lastMessageAt": "2026-03-08T10:00:00Z",
    "summary": "Working on authentication module refactoring. Last action: rewrote login flow.",
    "suggestedContinuation": "Continue with the token refresh implementation",
    "openTasks": ["Implement token refresh", "Add error handling"]
  }
}
```

---

### Get Prompt Suggestions

**Endpoint:** `GET /api/v1/suggestions/prompts`
**Description:** Get context-aware prompt suggestions for chat input.

**Query Parameters:**
- `sessionId` (optional, UUID) - Session context
- `context` (optional, string) - Current conversation context
- `projectContext` (optional, string) - Project-specific context (language/framework)
- `limit` (optional, int, default: 4, max: 10)

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid",
        "text": "Explain what this code does",
        "category": "analysis",
        "score": 0.9
      }
    ]
  }
}
```

---

### Submit Suggestion Feedback

**Endpoint:** `POST /api/v1/suggestions/feedback`
**Description:** Record user interaction with a suggestion (boosts relevance or dismisses).

**Request Body:**
```json
{
  "targetId": "uuid-or-prompt-text",
  "suggestionType": "session",
  "action": "click"
}
```

**Supported actions:** `click` (boosts score), `dismiss` (hides from abandoned results)

**Response:**
```json
{ "success": true, "data": { "acknowledged": true } }
```

---

## Terminal

Embedded terminal for executing shell commands on the backend host.

### Execute Command

**Endpoint:** `POST /api/v1/terminal/execute`
**Description:** Execute a shell command and return full output (blocking).

**Request Body:**
```json
{
  "command": "ls -la",
  "workingDirectory": "/Users/nick/Desktop/ils-ios",
  "environment": { "NODE_ENV": "development" },
  "timeout": 30
}
```

**Response Schema:**
```json
{
  "stdout": "total 48\ndrwxr-xr-x ...",
  "stderr": "",
  "exitCode": 0,
  "duration": 0.05,
  "workingDirectory": "/Users/nick/Desktop/ils-ios"
}
```

---

### Get Terminal Config

**Endpoint:** `GET /api/v1/terminal/config`
**Description:** Get current terminal configuration (working directory, shell).

**Response Schema:**
```json
{
  "shell": "/bin/zsh",
  "workingDirectory": "/Users/nick",
  "environment": {}
}
```

---

### Reset Terminal

**Endpoint:** `POST /api/v1/terminal/reset`
**Description:** Reset working directory to the user's home directory.

**Response:** Returns updated terminal config.

---

### Stream Terminal (WebSocket)

**Endpoint:** `WS /api/v1/terminal/stream`
**Description:** Stream command output in real time over WebSocket.

**Protocol:**
1. Client sends JSON: `{ "command": "npm test", "workingDirectory": "/path", "timeout": 60 }`
2. Server streams frames:
   - `{ "type": "stdout", "data": "chunk of output" }`
   - `{ "type": "stderr", "data": "error output" }`
   - `{ "type": "exit", "data": "", "exitCode": 0 }`
3. Multiple commands can be sent sequentially over the same connection.

**Example:**
```bash
websocat ws://localhost:9999/api/v1/terminal/stream
# Then send: {"command":"ls","workingDirectory":"/tmp"}
```

---

## SSH

SSH connection management for remote host execution. **Note:** SSH execution is not yet implemented — endpoints return `501 Not Implemented`.

### Connect

**Endpoint:** `POST /api/v1/ssh/connect`
**Description:** Establish SSH connection to a remote host.

**Request Body:**
```json
{
  "host": "192.168.1.100",
  "port": 22,
  "username": "nick",
  "authMethod": "key",
  "credential": "/path/to/key"
}
```

**Response:** `SSHStatusResponse` (currently returns 501).

---

### Disconnect

**Endpoint:** `POST /api/v1/ssh/disconnect`
**Description:** Disconnect from the current SSH session.

---

### Get SSH Status

**Endpoint:** `GET /api/v1/ssh/status`
**Description:** Get current SSH connection status.

**Response Schema:**
```json
{
  "connected": false,
  "host": null,
  "username": null,
  "platform": null,
  "connectedAt": null,
  "uptime": null
}
```

---

### Execute Remote Command

**Endpoint:** `POST /api/v1/ssh/execute`
**Description:** Execute a command on the remote host via SSH.

**Request Body:**
```json
{
  "command": "ls -la",
  "workingDirectory": "/home/nick"
}
```

**Response:** `SSHExecuteResponse` (currently returns 501).

---

## Recordings

Session recording and playback for capturing and replaying Claude interactions.

### Start Recording

**Endpoint:** `POST /api/v1/sessions/:id/recordings`
**Description:** Start a new recording for a session.

**Parameters:**
- `id` (path, UUID) - Session ID

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "sessionId": "uuid",
    "status": "recording",
    "startedAt": "2026-03-10T12:00:00Z"
  }
}
```

---

### List Session Recordings

**Endpoint:** `GET /api/v1/sessions/:id/recordings`
**Description:** List all recordings for a session.

**Parameters:**
- `id` (path, UUID) - Session ID

**Response:** Array of recording objects.

---

### Get Recording

**Endpoint:** `GET /api/v1/recordings/:recordingId`
**Description:** Get a specific recording by ID.

**Parameters:**
- `recordingId` (path, UUID) - Recording ID

---

### Stop Recording

**Endpoint:** `POST /api/v1/recordings/:recordingId/stop`
**Description:** Stop an active recording.

**Parameters:**
- `recordingId` (path, UUID) - Recording ID

**Response:** Returns the updated recording object with `status: "completed"`.

---

### Delete Recording

**Endpoint:** `DELETE /api/v1/recordings/:recordingId`
**Description:** Delete a recording.

**Parameters:**
- `recordingId` (path, UUID) - Recording ID

**Response:**
```json
{ "success": true, "data": { "deleted": true } }
```

---

### Get Playback Events

**Endpoint:** `GET /api/v1/recordings/:recordingId/events`
**Description:** Get all recorded events for playback.

**Parameters:**
- `recordingId` (path, UUID) - Recording ID

**Response Schema:**
```json
{
  "success": true,
  "data": {
    "events": [
      {
        "timestamp": "2026-03-10T12:00:00Z",
        "type": "message",
        "data": {}
      }
    ]
  }
}
```

---

### Export Recording

**Endpoint:** `GET /api/v1/recordings/:recordingId/export`
**Description:** Export a recording as a JSON archive.

**Parameters:**
- `recordingId` (path, UUID) - Recording ID

**Response:** JSON export (Content-Type: application/json).

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
- `claude-3-5-sonnet` - Claude 3.5 Sonnet
- `claude-3-5-haiku` - Claude 3.5 Haiku

---

## Rate Limiting

Currently, the API does not implement rate limiting. This may be added in future versions for production deployments.

---

## CORS

The API does not currently implement CORS headers. For web clients, you may need to run the API behind a proxy that adds appropriate CORS headers.

---

## Changelog

**v1.4.0 (2026-03-10)**
- Added Health Check detail endpoints (`GET /health/ready`, `GET /health/live`, `GET /api/v1/health`)
- Added Sessions: search (FTS5), search history, model-stats, suggest-model, compare, integrity-check, PATCH model, bulk-delete, bulk-export, import, fork-tree, messages/search, export, live-activity-token, transcript/files
- Added Projects: create (POST), update (PUT), delete (DELETE), bulk-delete
- Added Skills: preview, enable, disable
- Added Plugins: github-search, preview, check-update
- Added MCP: search, marketplace, presets, validate, per-server health/logs/enable/disable/restart
- Added Config: effective, export, validate-api-key
- Added System: claude processes, process history, kill process, process alerts, version endpoints, limits CRUD
- Added Tunnel: health, logs
- Added Analytics section (activity, sessions, skills, summary, export)
- Added Usage section (metrics, CSV export, rate limit status)
- Added Audit Trail section (list, create, rollback with file restoration)
- Added Workflows section (CRUD, execute, pause, cancel, SSE stream, schedules CRUD)
- Added Agent Queue section (list, enqueue, templates, CRUD, pause/resume/cancel, bulk-delete, reorder)
- Added Session Templates section (list, CRUD, bulk-delete, built-in protection)
- Added Session Health section (summary, export, per-session health, projects health)
- Added Automation Rules section (list, CRUD, execution history, templates)
- Added Suggestions section (sessions, skills, abandoned, continuation, prompts, feedback)
- Added Terminal section (execute, config, reset, WebSocket stream)
- Added SSH section (connect, disconnect, status, execute — currently 501 Not Implemented)
- Added Recordings section (start, list, get, stop, delete, playback events, export)

**v1.3.0 (2026-03-09)**
- Added Activity Feed section (GET /activity/events, GET /activity/events/stream with SSE)
- Added Checkpoints section (create, list, delete, restore session state)
- Added Permissions section (list pending/history, submit decisions, clear pending)
- Added Pairing section (QR code generation and token management)
- Updated documentation with comprehensive request/response examples
- All new endpoints tested and verified against actual backend controllers

**v1.2.0 (2026-02-28)**
- Added Host Profiles section (list, register, activate, delete, health-check endpoints)
- Added Data Erasure section (`DELETE /api/v1/data/all` for GDPR right-to-erasure compliance)

**v1.1.0 (2026-02-15)**
- Added Teams endpoints (list, create, delete, spawn, shutdown, tasks, messages)
- Added Tunnel endpoints (start, stop, status)
- Updated System endpoints (metrics instead of status, added metrics/source and metrics/live WebSocket)
- Added sessions/projects endpoint for optimized project groups
- Updated Themes to custom themes only (database-backed)
- Removed non-existent themes/current endpoints
- Added server/status endpoint
- Clarified projectName filter for sessions (supports "Ungrouped")
- Fixed all route paths to match actual implementation

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
