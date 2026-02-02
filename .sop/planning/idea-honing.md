# ILS Application - Requirements Clarification

This document captures the Q&A process for refining the ILS application requirements to achieve Claude Code feature parity.

---

## Q1: Architecture Approach - Local vs Remote Execution

**Question:** The current ILS spec uses SSH to connect to a remote server where Claude Code is installed. For the expanded functionality (chat sessions, real-time streaming), which architecture should we use?

**Answer:** The architecture is already defined in the spec:
- **Vapor API backend** runs on the **host machine** (same machine where Claude Code is installed)
- **iOS app** connects to the Vapor backend via HTTP/REST + SSE/WebSocket
- Backend executes Claude Code CLI commands directly (not via SSH)
- Streaming uses **SSE or WebSocket** routes for real-time chat
- Shared models package between iOS app and Vapor backend

This is a client-server architecture where:
- Backend = Vapor server on host machine with direct Claude Code access
- Frontend = iOS app that connects remotely to the backend

---

## Q2: Real-Time Streaming Protocol

**Question:** For streaming chat responses from Claude Code to the iOS app, which protocol should we use?

**Answer:** Both SSE and WebSocket:
- **SSE** for simple streaming responses (one-way server-to-client)
- **WebSocket** for interactive sessions requiring bidirectional communication (interrupts, permission prompts, follow-up messages without new connections)

---

## Q3: Session Detection and Management

**Question:** How should the app detect and display previous Claude Code sessions from the host machine?

**Answer:** Hybrid approach:
- **ILS database** tracks sessions created through ILS (with metadata like name, project, creation date)
- **Scan Claude Code storage** to discover ALL sessions (including those created outside ILS)
- Display both with clear distinction (ILS-managed vs external)
- Allow resuming any discovered session

---

## Q4: Project Context

**Question:** How should ILS handle "projects" - should it be aware of different codebases/directories the user works on?

**Answer:** Full project management:
- ILS maintains a list of projects (directory paths on host machine)
- User can add/remove/select projects
- Sessions are scoped to projects
- Project-specific settings, plugins, MCP servers displayed per-project
- Backend tracks project paths and passes to Claude Code as working directory

---

## Q5: CLI Execution Method

**Question:** How should the Vapor backend execute Claude Code CLI commands?

**Answer:** Support BOTH execution methods:

1. **Swift Process + Pipes** (Primary)
   - Use Foundation's Process class to spawn `claude` CLI
   - Capture stdout/stderr via pipes
   - Parse stream-json output line by line
   - Native Swift, no external dependencies
   - Reference: https://github.com/jamesrochabrun/ClaudeCodeSDK as starting point

2. **Python Agent SDK Sidecar** (Optional/Advanced)
   - Run Python service using `claude-agent-sdk`
   - Vapor communicates with Python service via HTTP/IPC
   - Provides additional SDK features (hooks, custom tools, etc.)
   - User can choose which backend to use

**Need to research**: What additional capabilities does Agent SDK provide over CLI headless mode?

---

## Q6: Permission Handling

**Question:** How should ILS handle permission prompts from Claude Code (when Claude wants to execute tools)?

**Answer:** Configurable per-session:
- User selects permission mode when starting a session
- **Bypass mode**: `--dangerously-skip-permissions` for full automation
- **Plan mode**: `--permission-mode plan` for planning without execution
- **Interactive mode**: Forward permission requests to iOS app via WebSocket, user approves/denies in real-time
- **Accept edits**: `--permission-mode acceptEdits` auto-approves file changes

---

## Q7: Chat UI Message Types

**Question:** What types of content should the chat interface display?

**Answer:** Full transparency with collapsible sections:
- **Text responses** - Always visible, primary content
- **Tool calls** - Show tool name and inputs (collapsible for long inputs)
- **Tool results** - Show outputs (collapsible for verbose content)
- **Thinking blocks** - Display when extended thinking enabled (collapsible)
- **Cost/usage stats** - Show at end of response (tokens, cost, duration)
- **Permission requests** - Prominent display when interactive mode
- **Errors** - Highlighted error messages

---

## Q8: Plugin & MCP Management Scope

**Question:** Should ILS allow full CRUD operations on plugins and MCP servers, or read-only viewing?

**Answer:** Full CRUD operations:
- **Plugins**: Install from marketplaces, uninstall, enable/disable, browse marketplace, add custom marketplaces
- **MCP Servers**: Add, remove, edit configurations for all scopes (user, project, local)
- **Skills**: View, create, edit, delete skills
- **Settings**: Full editing of all settings.json files

---

## Q9: Authentication & Security

**Question:** How should the iOS app authenticate with the Vapor backend?

**Answer:** No authentication (local network):
- Backend assumed to be on local network or accessed via VPN
- No API keys or user accounts needed for MVP
- Simple setup for personal use
- Can add authentication later if needed for remote access

---

## Q10: Initial MVP Scope

**Question:** What's the priority order for implementing features?

**Answer:** Full parallel development with rigorous validation:

**Development Approach:**
- Backend and iOS frontend developed in parallel
- Backend must be validated FIRST before iOS integration
- All features developed simultaneously

**Validation Strategy (3D Shift Validation):**
- **NO unit tests, mock tests, pytest, or functional tests**
- **Backend**: Real curl commands against actual running backend with real Claude Code
- **Daemon/Services**: Compile, build, execute, verify via actual process execution
- **iOS App**: Build in Simulator, capture screenshots, visually verify
- **Integration**: Correlate iOS screenshots with backend logs as evidence

**Evidence Requirements:**
- Backend: Terminal output showing successful curl responses with expected JSON
- iOS: Screenshots from Simulator showing expected UI state
- Integration: Both screenshot AND correlated backend logs showing data flow

---

## Requirements Summary

### Core Architecture
- **Backend**: Vapor server running on host machine with Claude Code
- **Frontend**: iOS SwiftUI app connecting to backend
- **Shared Models**: Swift package shared between backend and frontend
- **Streaming**: SSE for simple responses, WebSocket for interactive sessions
- **Execution**: Swift Process (CLI) + optional Python Agent SDK sidecar

### Features (All in Parallel)
1. **Chat Interface** - Real-time streaming, full message type transparency
2. **Session Management** - Hybrid (ILS DB + Claude Code storage scan)
3. **Project Management** - Full project CRUD, session scoping
4. **Plugin System** - Full CRUD, marketplace browsing, install/uninstall
5. **MCP Servers** - Full CRUD for all scopes
6. **Skills & Commands** - View, create, edit, invoke
7. **Settings** - Full editing of all config scopes
8. **Permission Handling** - Configurable per-session (bypass/plan/interactive)

### Non-Requirements (MVP)
- Authentication (local network assumed)
- Multi-user support
- Remote access security

---

## Q11: 3D Shift Validation Methodology (CRITICAL)

**Question:** How exactly should validation work during development?

**Answer:** 3D Shift Validation is MANDATORY for all development:

### Backend Validation (Vapor API)
```
For EVERY endpoint:
1. Build and compile the actual production Vapor binary
2. Run the actual server
3. Execute real curl commands against actual running server
4. Verify responses contain expected real data from Claude Code
5. Capture terminal output as evidence
```

**Example Evidence:**
```bash
# Start server
$ swift run ILSBackend &

# Test endpoint with REAL data
$ curl http://localhost:8080/api/v1/skills
{
  "success": true,
  "data": {
    "items": [
      {"name": "code-review", "path": "~/.claude/skills/code-review", ...}
    ]
  }
}

# Evidence: PASS - returns actual skills from host machine
```

### iOS Validation (SwiftUI App)
```
For EVERY screen/feature:
1. Build and compile actual iOS app
2. Run in iOS Simulator
3. Perform actual user interactions
4. Capture screenshot of expected state
5. Correlate screenshot with backend logs
```

**Example Evidence:**
```
EVIDENCE_3.1_SkillsListView:
- Type: Screenshot + Backend Log
- Screenshot: Shows SkillsListView with 3 skills loaded
- Backend Log: GET /api/v1/skills returned 200 with 3 items
- Correlation: UI shows same skills as API response
- Status: PASS
```

### What is PROHIBITED
- NO unit tests
- NO mock data
- NO pytest/XCTest automated tests
- NO functional test suites
- NO stubbed responses
- NO fake/simulated Claude Code

### What is REQUIRED
- Real compiled binaries
- Real running servers
- Real curl commands
- Real Claude Code on host machine
- Real iOS Simulator
- Real screenshots
- Real backend logs
- Evidence artifacts for EVERY task

---

## Q12: UI/UX Screen Flow Details

**Question:** What are the specific screens and navigation patterns needed?

**Answer:** Session-centric chat app navigation:

### Primary Navigation
- **Sessions List** (like Messages app) - Main screen showing all sessions
- Tap session → **Chat View** for that session
- **Projects/Plugins/Settings** in sidebar menu or secondary navigation

### Screen Hierarchy
```
├── Sessions List (main)
│   ├── New Session (with project/model selection)
│   └── Session Chat View
│       ├── Message stream (text, tools, results)
│       ├── Input bar + command palette
│       └── Session info (model, project, cost)
├── Sidebar Menu
│   ├── Projects
│   │   ├── Project List
│   │   ├── Project Detail (sessions, settings)
│   │   └── Add/Edit Project
│   ├── Plugins
│   │   ├── Installed Plugins
│   │   ├── Marketplace Browser
│   │   └── Plugin Detail
│   ├── MCP Servers
│   │   ├── Server List
│   │   └── Add/Edit Server
│   ├── Skills
│   │   ├── Skills List
│   │   └── Skill Detail/Editor
│   └── Settings
│       ├── App Settings
│       └── Claude Code Config Editor
```

### Chat Input
- Text input field
- **Full command palette** (keyboard shortcut style UI)
  - Quick access to skills, tools, settings
  - Slash command autocomplete
  - Model/project switching
  - Permission mode selection

---

## Q13: Model Selection UI

**Question:** How should users select which Claude model to use?

**Answer:** Project default + per-session override:
- Each project has a default model setting
- New sessions inherit project's default model
- Users can override model when creating session or via command palette
- Available models: sonnet, opus, haiku (aliases) + full model names

---

## Final Requirements Checklist

### Architecture ✓
- [x] Vapor backend on host machine with Claude Code
- [x] iOS SwiftUI frontend connecting to backend
- [x] Shared Swift models package
- [x] SSE + WebSocket for streaming
- [x] Swift Process CLI + optional Python SDK sidecar

### Features ✓
- [x] Chat with real-time streaming
- [x] Full message transparency (text, tools, results, thinking, cost)
- [x] Session management (create, resume, fork, list, hybrid storage)
- [x] Project management (CRUD, session scoping, model defaults)
- [x] Plugins (full CRUD, marketplace, install/uninstall)
- [x] MCP servers (full CRUD, all scopes)
- [x] Skills (view, create, edit, invoke)
- [x] Settings (full config editing)
- [x] Configurable permissions (bypass/plan/interactive)
- [x] Command palette for quick access

### UI/UX ✓
- [x] Session-centric navigation (like Messages app)
- [x] Sidebar menu for Projects/Plugins/MCP/Skills/Settings
- [x] Full command palette in chat
- [x] Dark mode with hot orange accent (from original spec)

### Validation ✓
- [x] 3D Shift Validation methodology
- [x] Real curl tests for backend
- [x] Real Simulator screenshots for iOS
- [x] Evidence artifacts required for every task
- [x] NO unit tests, mocks, or automated test suites





