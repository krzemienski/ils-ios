# Claude Code Complete Feature Research

**Date**: 2026-02-01
**Sources**: Official documentation from code.claude.com, platform.claude.com, Context7 API docs

---

## Executive Summary

Claude Code is an agentic coding tool with two primary interfaces:
1. **CLI** - Interactive terminal application and headless/non-interactive mode
2. **Agent SDK** - Python/TypeScript APIs for programmatic integration

To achieve feature parity, ILS must support both interfaces and their full capabilities.

---

## 1. CLI Commands & Modes

### Core Commands

| Command | Description | Example |
|---------|-------------|---------|
| `claude` | Start interactive REPL | `claude` |
| `claude "query"` | Start REPL with initial prompt | `claude "explain this project"` |
| `claude -p "query"` | Non-interactive/headless mode | `claude -p "explain this function"` |
| `cat file \| claude -p` | Process piped content | `cat logs.txt \| claude -p "explain"` |
| `claude -c` | Continue most recent conversation | `claude -c` |
| `claude -r "<session>"` | Resume session by ID or name | `claude -r "auth-refactor" "query"` |
| `claude update` | Update to latest version | `claude update` |
| `claude mcp` | Configure MCP servers | `claude mcp add ...` |

### Output Formats (Critical for ILS)

| Format | Flag | Use Case |
|--------|------|----------|
| Text | `--output-format text` | Human-readable output |
| JSON | `--output-format json` | Structured data for parsing |
| Streaming JSON | `--output-format stream-json` | Real-time streaming for UIs |

**Stream JSON is essential for ILS chat interface** - provides real-time token streaming.

### Key Flags for ILS

| Flag | Purpose |
|------|---------|
| `--model` | Select model (sonnet, opus, or full name) |
| `--resume` / `-r` | Resume session by ID or name |
| `--continue` / `-c` | Continue most recent conversation |
| `--session-id` | Use specific session UUID |
| `--fork-session` | Create new session when resuming |
| `--mcp-config` | Load MCP servers from JSON |
| `--plugin-dir` | Load plugins from directory |
| `--setting-sources` | Which settings to load (user, project, local) |
| `--allowedTools` | Tools that don't need permission |
| `--disallowedTools` | Tools to disable |
| `--max-turns` | Limit agentic turns |
| `--max-budget-usd` | Spending limit |
| `--include-partial-messages` | Include partial streaming events |
| `--no-session-persistence` | Don't save sessions |

---

## 2. Session Management

### Session Lifecycle

1. **Create**: New session starts with any query
2. **Get ID**: Session ID in `init` system message
3. **Resume**: Use `--resume <session-id>` or `-c` for most recent
4. **Fork**: Use `--fork-session` to branch without modifying original
5. **Continue**: Use `-c` or `-c -p` to continue in print mode

### Session Storage

Sessions are stored locally and can be:
- Resumed by ID (UUID)
- Resumed by name
- Listed (need to research if there's a list command)
- Linked to PRs (`--from-pr`)

### SDK Session Management

```python
# Get session ID from init message
async for message in query(prompt="...", options=options):
    if hasattr(message, 'subtype') and message.subtype == 'init':
        session_id = message.data.get('session_id')

# Resume session
options = ClaudeAgentOptions(resume="session-xyz")

# Fork session (create branch)
options = ClaudeAgentOptions(resume=session_id, fork_session=True)
```

---

## 3. Real-Time Streaming

### CLI Streaming

```bash
claude -p "query" --output-format stream-json --include-partial-messages
```

### SDK Streaming

The SDK returns an async iterator that yields messages:

```python
async for message in query(prompt="...", options=options):
    if isinstance(message, AssistantMessage):
        for block in message.content:
            if isinstance(block, TextBlock):
                # Stream text to UI
                yield block.text
```

### Message Types for Streaming

| Type | Purpose |
|------|---------|
| `SystemMessage (init)` | Session started, contains session_id, plugins, commands |
| `AssistantMessage` | Claude's response with content blocks |
| `TextBlock` | Text content to display |
| `ToolUseBlock` | Tool being called |
| `ToolResultBlock` | Tool execution result |
| `ThinkingBlock` | Extended thinking content |
| `ResultMessage` | Final message with cost, duration, usage |

---

## 4. Plugins

### Plugin Structure

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest
├── commands/             # Slash commands
├── agents/               # Subagents
├── skills/               # Skills
└── hooks/                # Event handlers
```

### Plugin Management CLI

```bash
# Add marketplace
claude plugin marketplace add owner/repo

# Install from marketplace
claude plugin install plugin-name@marketplace-name

# Disable/Enable
/plugin disable plugin-name@marketplace
/plugin enable plugin-name@marketplace

# Uninstall
/plugin uninstall plugin-name@marketplace
```

### Plugin Loading via SDK

```python
options = ClaudeAgentOptions(
    plugins=[
        {"type": "local", "path": "./my-plugin"},
    ],
    setting_sources=["user", "project"]  # REQUIRED!
)
```

**Critical**: `setting_sources` is required for plugins to load.

---

## 5. MCP Servers

### Configuration Locations

| Scope | File | Purpose |
|-------|------|---------|
| User | `~/.claude.json` | Global MCP servers |
| Project | `.mcp.json` | Project-specific servers |

### MCP Server Definition

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

### CLI MCP Commands

```bash
claude mcp add --transport http github https://api.githubcopilot.com/mcp/
```

### SDK MCP Integration

```python
options = ClaudeAgentOptions(
    mcp_servers={"weather": server_config},
    allowed_tools=["mcp__weather__get_weather"]
)
```

---

## 6. Skills & Slash Commands

### Skill Structure

```
~/.claude/skills/
└── skill-name/
    └── SKILL.md
```

**SKILL.md Format:**
```yaml
---
name: skill-name
description: Brief description
---
# Instructions
Markdown content...
```

### Command Namespacing

Plugin commands are namespaced: `/plugin-name:command-name`

### Invoking Skills

```python
# Via SDK
prompt = "/skill-name arguments"

# Or via Skill tool
# Claude uses: Skill(skill="skill-name", args="...")
```

---

## 7. Subagents

### Definition Methods

1. **Programmatic** (via SDK/CLI):
```python
options = ClaudeAgentOptions(
    agents={
        'code-reviewer': {
            'description': 'Expert code review specialist',
            'prompt': 'You are a code reviewer...',
            'tools': ['Read', 'Grep', 'Glob'],
            'model': 'sonnet'
        }
    }
)
```

2. **CLI Flag**:
```bash
claude --agents '{"reviewer":{"description":"...","prompt":"..."}}'
```

3. **Filesystem**: `.claude/agents/agent-name.md`

### Agent Definition Fields

| Field | Required | Description |
|-------|----------|-------------|
| `description` | Yes | When to use this agent |
| `prompt` | Yes | System prompt |
| `tools` | No | Allowed tools |
| `model` | No | sonnet/opus/haiku/inherit |

---

## 8. Settings & Configuration

### Configuration File Hierarchy

| Scope | Location | Purpose |
|-------|----------|---------|
| User | `~/.claude/settings.json` | Personal global settings |
| Project | `.claude/settings.json` | Team-shared settings |
| Local | `.claude/settings.local.json` | Per-machine overrides |
| Managed | `/Library/Application Support/ClaudeCode/managed-settings.json` | Enterprise |

### Settings Fields

```json
{
  "permissions": { "allow": [], "deny": [] },
  "env": {},
  "model": "claude-sonnet-4-5",
  "hooks": { "PreToolUse": [], "PostToolUse": [] },
  "enabledPlugins": { "plugin@marketplace": true },
  "extraKnownMarketplaces": {}
}
```

---

## 9. Hooks

### Hook Types

| Event | When |
|-------|------|
| `PreToolUse` | Before tool execution |
| `PostToolUse` | After tool execution |

### Hook SDK Integration

```python
async def validate_bash(input_data, tool_use_id, context):
    if input_data['tool_name'] == 'Bash':
        command = input_data['tool_input'].get('command', '')
        if 'rm -rf /' in command:
            return {
                'hookSpecificOutput': {
                    'hookEventName': 'PreToolUse',
                    'permissionDecision': 'deny',
                    'permissionDecisionReason': 'Blocked'
                }
            }
    return {}

options = ClaudeAgentOptions(
    hooks={
        'PreToolUse': [HookMatcher(matcher='Bash', hooks=[validate_bash])]
    }
)
```

---

## 10. Tools Available

### Built-in Tools

| Tool | Purpose |
|------|---------|
| Read | Read files |
| Write | Write files |
| Edit | Edit files |
| Bash | Execute shell commands |
| Glob | File pattern matching |
| Grep | Content search |
| Task | Spawn subagents |
| Skill | Invoke skills |
| TodoWrite | Manage todos |
| WebFetch | Fetch URLs |
| WebSearch | Search web |

### MCP Tool Naming

Format: `mcp__{server}__{tool}`
Example: `mcp__github__create_issue`

---

## 11. Permission Modes

| Mode | Description |
|------|-------------|
| `default` | Standard permission behavior |
| `acceptEdits` | Auto-accept file edits |
| `plan` | Planning mode - no execution |
| `bypassPermissions` | Skip all permission checks |

---

## 12. Cost & Usage Tracking

From `ResultMessage`:
- `total_cost_usd` - API cost
- `duration_ms` - Execution time
- `duration_api_ms` - API time
- `num_turns` - Agentic turns
- `usage` - Token usage dict

---

## ILS Feature Requirements Summary

### Must Have (Core Parity)

1. **Chat Interface**
   - Real-time streaming via stream-json
   - Message type handling (text, tool use, results)
   - Session management (create, resume, fork, list)

2. **Session Management**
   - Detect previous sessions
   - Resume by ID or name
   - Fork sessions
   - Session persistence

3. **Plugin System**
   - List installed plugins
   - Install/uninstall plugins
   - Enable/disable plugins
   - Browse marketplaces

4. **MCP Servers**
   - CRUD operations on MCP configs
   - Support all scopes (user, project, local)

5. **Skills & Commands**
   - List available skills
   - Invoke skills
   - Create custom commands

6. **Settings**
   - Edit all settings scopes
   - Permissions management
   - Environment variables
   - Model selection

### Should Have

7. **Subagents**
   - Define custom agents
   - Track agent execution

8. **Cost Tracking**
   - Display cost per session
   - Budget limits

9. **Model Selection**
   - Choose model per session
   - Support all model variants

### Nice to Have

10. **Hooks**
    - Configure pre/post tool hooks
    - Custom validation

11. **Project Detection**
    - Detect Claude Code projects
    - Load project-specific settings

---

## Sources

- [CLI Reference](https://code.claude.com/docs/en/cli-reference)
- [Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Session Management](https://platform.claude.com/docs/en/agent-sdk/sessions)
- [Streaming Input](https://platform.claude.com/docs/en/agent-sdk/streaming-vs-single-mode)
- [Plugins](https://code.claude.com/docs/en/plugins)
- [MCP](https://code.claude.com/docs/en/mcp)
