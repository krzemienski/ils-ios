---
type: external-spec
source-type: url
source-id: https://docs.anthropic.com/en/docs/claude-code/sub-agents
fetched: 2026-02-05T21:45:00Z
---

# Claude Code Subagents

## Summary
Specialized AI assistants that run in independent contexts with custom system prompts, specific tool access, and separate permissions. Subagents handle task-specific workflows while preserving main conversation context.

## Key Sections

### Built-in Subagents
- **Explore**: Fast, read-only agent for searching and analyzing codebases (Haiku model)
- **Plan**: Research agent for gathering context during plan mode (inherits model, read-only)
- **General-purpose**: Complex multi-step tasks with exploration and modification (inherits model, all tools)
- **Bash**: Terminal command execution in separate context
- **statusline-setup**: Status line configuration (Sonnet)
- **Claude Code Guide**: Feature questions (Haiku)

### Configuration Methods
1. Markdown files with YAML frontmatter
2. CLI `--agents` JSON flag
3. Interactive `/agents` command
4. Plugin distribution

### Scopes & Locations
- `--agents` CLI flag - Current session only (priority 1)
- `.claude/agents/` - Project-level (priority 2)
- `~/.claude/agents/` - User-level all projects (priority 3)
- Plugin `agents/` directory - Where plugin enabled (priority 4)

### Frontmatter Fields
- `name` (required) - Unique identifier (lowercase-hyphenated)
- `description` (required) - When Claude should delegate
- `tools` (optional) - Allowlist of available tools
- `disallowedTools` (optional) - Denylist to remove tools
- `model` (optional) - sonnet/opus/haiku/inherit (default: inherit)
- `permissionMode` (optional) - default/acceptEdits/dontAsk/bypassPermissions/plan
- `skills` (optional) - Skills to preload into context
- `hooks` (optional) - Lifecycle hooks scoped to subagent
- `memory` (optional) - Persistent memory scope (user/project/local)

### Tool Control
Available tools include all Claude Code internal tools:
- Read, Write, Edit - File operations
- Grep, Glob - Search operations
- Bash - Command execution
- Task - Agent delegation
- MCP tools - External integrations

Tool restriction patterns:
- `tools` field - Allowlist (inherit all if omitted)
- `disallowedTools` field - Denylist
- Conditional validation via `PreToolUse` hooks

### Permission Modes
- `default` - Standard permission checking
- `acceptEdits` - Auto-accept file edits
- `dontAsk` - Auto-deny prompts (allowed tools still work)
- `bypassPermissions` - Skip all checks (use with caution)
- `plan` - Plan mode (read-only exploration)

### Skills Integration
- Preload skill content into subagent context at startup
- Full content injection (not just availability)
- Subagents don't inherit parent skills
- Inverse of running skills in subagents

### Persistent Memory
Three scopes for cross-session learning:
- `user`: `~/.claude/agent-memory/<name>/` - All projects
- `project`: `.claude/agent-memory/<name>/` - Project-specific, shareable
- `local`: `.claude/agent-memory-local/<name>/` - Project-specific, not version-controlled

Memory features:
- Auto-includes first 200 lines of MEMORY.md in prompt
- Auto-enables Read/Write/Edit tools
- Builds institutional knowledge over time

### Hooks Configuration

#### In Frontmatter
Events run only while subagent active:
- `PreToolUse` - Before tool execution (matcher: tool name)
- `PostToolUse` - After tool execution (matcher: tool name)
- `Stop` - When subagent finishes (auto-converted to SubagentStop)

#### In settings.json
Events in main session:
- `SubagentStart` - When subagent begins (matcher: agent type name)
- `SubagentStop` - When any subagent completes (no matcher)

### Execution Modes
- **Foreground**: Blocks main conversation, passes permission prompts
- **Background**: Concurrent execution, pre-approval required, no MCP tools, auto-denies unapproved permissions

Background behavior:
- Claude Code prompts upfront for needed permissions
- Subagent inherits approved permissions
- AskUserQuestion tool calls fail
- Can resume in foreground if permissions fail

### Context Management
- Fresh context per invocation by default
- Resume capability preserves full conversation history
- Transcripts stored in `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`
- Independent of main conversation compaction
- Auto-compaction at ~95% capacity (configurable via CLAUDE_AUTOCOMPACT_PCT_OVERRIDE)
- Cleanup based on cleanupPeriodDays setting (default: 30 days)

### Common Patterns

#### Isolate High-Volume Operations
- Test suite execution
- Documentation fetching
- Log file processing
- Keeps verbose output in subagent context

#### Parallel Research
- Spawn multiple subagents for independent investigations
- Each explores separately, Claude synthesizes findings
- Warning: Multiple detailed results can consume context

#### Chain Subagents
- Sequential workflows with result passing
- Example: code-reviewer → optimizer
- Each completes before next begins

### Design Patterns
- **Focused subagents**: Excel at one specific task
- **Detailed descriptions**: Guide automatic delegation
- **Limited tool access**: Security and focus
- **Version control**: Share project subagents with team
- **Proactive delegation**: Include "use proactively" in description

### Limitations
- Subagents cannot spawn other subagents
- For nested delegation, use Skills or chain from main conversation
- Background subagents lack MCP tool access
- Background subagents cannot ask clarifying questions

### /agents Command Features
- View all available subagents (built-in, user, project, plugin)
- Create new with guided setup or Claude generation
- Edit existing configuration and tool access
- Delete custom subagents
- See active subagent when duplicates exist

### Disabling Subagents
Add to settings.json `deny` array:
```json
{
  "permissions": {
    "deny": ["Task(Explore)", "Task(my-custom-agent)"]
  }
}
```

Or use CLI flag:
```bash
claude --disallowedTools "Task(Explore)"
```

## Keywords
subagents agents delegation task-specific isolated-context tool-restrictions permissions background-tasks foreground-tasks persistent-memory hooks skills automation parallel-execution context-management

## Related Components
- controller-sessionscontroller.md
- service-claudeexecutorservice.md
- model-session.md

## Example Use Cases

### Code Reviewer (Read-only)
```yaml
name: code-reviewer
description: Expert code review. Use after writing code.
tools: Read, Grep, Glob, Bash
model: inherit
```

### Debugger (Read/Write)
```yaml
name: debugger
description: Debug errors and test failures
tools: Read, Edit, Bash, Grep, Glob
```

### Data Scientist
```yaml
name: data-scientist
description: SQL queries and BigQuery operations
tools: Bash, Read, Write
model: sonnet
```

### Database Query Validator
```yaml
name: db-reader
description: Execute read-only database queries
tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly-query.sh"
```

## See Also
- Agent teams - Multiple agents coordinating across sessions
- Skills - Reusable prompts in main conversation
- Plugins - Distribution mechanism for subagents
- Hooks - Lifecycle event handling
- MCP servers - External tool integration
