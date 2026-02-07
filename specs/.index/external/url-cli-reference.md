---
type: external-spec
source-type: url
source-id: https://docs.anthropic.com/en/docs/claude-code/cli-reference
fetched: 2026-02-05T21:45:00Z
---

# Claude Code CLI Reference

## Summary
Complete reference for Claude Code command-line interface, covering all commands, flags, configuration options, and usage patterns for both interactive REPL and SDK-based automation.

## Key Sections

### CLI Commands
- `claude` - Start interactive REPL
- `claude "query"` - Start with initial prompt
- `claude -p "query"` - Query via SDK and exit
- `cat file | claude -p "query"` - Process piped content
- `claude -c` - Continue most recent conversation
- `claude -c -p "query"` - Continue via SDK
- `claude -r "<session>"` - Resume session by ID or name
- `claude update` - Update to latest version
- `claude mcp` - Configure MCP servers

### Session Management
- `--continue`, `-c` - Load most recent conversation
- `--resume`, `-r` - Resume specific session
- `--session-id` - Use specific UUID
- `--fork-session` - Create new session from resumed one
- `--from-pr` - Resume sessions linked to GitHub PR
- `--no-session-persistence` - Disable session saving (print mode)

### Model Selection
- `--model` - Set model (alias or full name)
- `--fallback-model` - Auto-fallback when overloaded (print mode)

### System Prompts
- `--system-prompt` - Replace entire default prompt
- `--system-prompt-file` - Replace with file contents (print mode)
- `--append-system-prompt` - Append to default prompt
- `--append-system-prompt-file` - Append file contents (print mode)

### Tool Control
- `--tools` - Restrict available built-in tools
- `--allowedTools` - Tools that execute without permission prompt
- `--disallowedTools` - Tools to deny/remove

### Permission Management
- `--permission-mode` - Begin in specific permission mode
- `--dangerously-skip-permissions` - Skip all prompts
- `--allow-dangerously-skip-permissions` - Enable bypass option

### Agent Configuration
- `--agent` - Specify agent for session
- `--agents` - Define custom subagents via JSON
- `--teammate-mode` - Set team display mode (auto/in-process/tmux)

### MCP Configuration
- `--mcp-config` - Load MCP servers from JSON files/strings
- `--strict-mcp-config` - Only use specified MCP servers

### Output Formatting
- `--output-format` - Set format (text/json/stream-json)
- `--input-format` - Specify input format (text/stream-json)
- `--include-partial-messages` - Include streaming events
- `--json-schema` - Get validated JSON matching schema (print mode)

### Directory & Context
- `--add-dir` - Add additional working directories

### Integration Features
- `--chrome` - Enable Chrome browser integration
- `--no-chrome` - Disable Chrome integration
- `--ide` - Auto-connect to IDE if available
- `--remote` - Create web session on claude.ai
- `--teleport` - Resume web session in terminal

### Initialization & Hooks
- `--init` - Run initialization hooks and start
- `--init-only` - Run initialization hooks and exit
- `--maintenance` - Run maintenance hooks and exit

### Budget & Limits
- `--max-budget-usd` - Maximum spend limit (print mode)
- `--max-turns` - Limit agentic turns (print mode)

### Settings & Configuration
- `--settings` - Load settings from JSON file/string
- `--setting-sources` - Specify sources (user/project/local)
- `--plugin-dir` - Load plugins from directories

### Debugging & Development
- `--debug` - Enable debug mode with category filtering
- `--verbose` - Enable verbose logging
- `--disable-slash-commands` - Disable all skills
- `--version`, `-v` - Show version number

### Beta Features
- `--betas` - Beta headers for API requests (API key users)

### Agents Flag Format
JSON object defining custom subagents with fields:
- `description` (required) - When to invoke
- `prompt` (required) - System prompt
- `tools` (optional) - Specific tools array
- `model` (optional) - Model alias (sonnet/opus/haiku/inherit)

### System Prompt Flags Comparison
- `--system-prompt` - Replaces entire prompt (both modes)
- `--system-prompt-file` - Replaces with file (print only)
- `--append-system-prompt` - Appends to default (both modes)
- `--append-system-prompt-file` - Appends file (print only)

## Keywords
cli command-line interface flags options configuration session-management permissions mcp agents automation sdk print-mode interactive-mode

## Related Components
- service-claudeexecutorservice.md
- model-session.md
- controller-sessionscontroller.md

## Usage Patterns

### Interactive Mode
```bash
claude
claude "explain this project"
claude --model opus
claude --chrome
```

### Print/SDK Mode
```bash
claude -p "query"
claude -p --output-format json "query"
claude -p --max-turns 3 "query"
cat logs.txt | claude -p "explain"
```

### Session Resumption
```bash
claude -c
claude -r "auth-refactor"
claude --from-pr 123
```

### Permission Control
```bash
claude --permission-mode plan
claude --allowedTools "Bash(git *)" "Read"
claude --dangerously-skip-permissions
```

## See Also
- Chrome extension - Browser automation
- Interactive mode - Shortcuts and features
- Common workflows - Advanced patterns
- Settings - Configuration options
- Agent SDK - Programmatic usage
