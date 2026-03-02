import Foundation

// MARK: - Documentation Models

/// Semantic category grouping for in-app Claude Code documentation articles.
///
/// Cases mirror the six top-level sections of the Claude Code reference:
/// slash commands, configuration, MCP server setup, hooks, permissions,
/// and general best practices.
enum DocCategory: String, CaseIterable, Identifiable {
    case slashCommands   = "Slash Commands"
    case configuration   = "Configuration"
    case mcpServers      = "MCP Servers"
    case hooks           = "Hooks"
    case permissions     = "Permissions"
    case bestPractices   = "Best Practices"

    var id: String { rawValue }

    /// SF Symbol name used as the category icon in list headers and badges.
    var icon: String {
        switch self {
        case .slashCommands:  return "terminal"
        case .configuration:  return "gear"
        case .mcpServers:     return "server.rack"
        case .hooks:          return "bolt"
        case .permissions:    return "lock.shield"
        case .bestPractices:  return "star.circle"
        }
    }
}

/// A single in-app documentation article covering one Claude Code concept or command.
///
/// Articles are value types. All content is compiled-in as Swift string literals —
/// there is no network fetch and no JSON parsing. `id` is a stable slug suitable for
/// UserDefaults bookmark persistence.
struct DocArticle: Identifiable, Equatable {
    /// Stable URL-slug–style identifier, e.g. `"slash-compact"` or `"mcp-overview"`.
    let id: String
    /// Short display title shown in list rows and article headers.
    let title: String
    /// One-sentence description shown in list rows below the title.
    let summary: String
    /// Full Markdown-style body text rendered in the detail view.
    let body: String
    /// Top-level section this article belongs to.
    let category: DocCategory
    /// Searchable tags for full-text search and context-sensitive matching.
    let tags: [String]
    /// Optional runnable/copyable code snippet displayed in a monospaced card.
    let codeExample: String?

    static func == (lhs: DocArticle, rhs: DocArticle) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Static Content

extension DocArticle {
    /// Complete compiled-in article library (~30 articles).
    ///
    /// Covers all six ``DocCategory`` sections. Slash command articles mirror
    /// `CommandPaletteView.allBuiltInCommands` with expanded body content.
    static let allArticles: [DocArticle] = slashCommandArticles
        + configurationArticles
        + mcpArticles
        + hooksArticles
        + permissionsArticles
        + bestPracticesArticles
}

// MARK: Slash Commands

private extension DocArticle {
    static let slashCommandArticles: [DocArticle] = [
        DocArticle(
            id: "slash-compact",
            title: "/compact",
            summary: "Compact conversation history to reduce context usage.",
            body: """
            Use `/compact` when your conversation history is growing large and consuming token budget. \
            Claude Code summarises the full history into a condensed form, preserving the most important \
            context while dramatically reducing token count.

            **When to use**
            - Before switching to a new task in the same session
            - When hitting context-limit warnings
            - After long debugging sessions to "reset" the narrative

            **Behaviour**
            The command sends the full history to Claude with a compaction prompt. The result replaces \
            the conversation buffer. You can follow `/compact` with `/cost` to verify the reduction.
            """,
            category: .slashCommands,
            tags: ["compact", "context", "tokens", "history", "memory"],
            codeExample: "/compact"
        ),
        DocArticle(
            id: "slash-clear",
            title: "/clear",
            summary: "Clear conversation history and start fresh.",
            body: """
            `/clear` wipes the entire in-memory conversation buffer, giving you a blank slate without \
            closing the session or reconnecting. Unlike `/compact`, no summary is kept — the history \
            is simply discarded.

            **When to use**
            - Starting a completely unrelated task
            - After accidental sensitive data entry
            - When you want zero prior context influencing responses

            **Note:** Session metadata (project path, working directory, model) is preserved. \
            Only the message history is cleared.
            """,
            category: .slashCommands,
            tags: ["clear", "reset", "history", "fresh start"],
            codeExample: "/clear"
        ),
        DocArticle(
            id: "slash-config",
            title: "/config",
            summary: "View or modify Claude Code configuration.",
            body: """
            `/config` opens an interactive configuration editor inside the terminal. You can inspect \
            all current settings and toggle options without editing JSON files manually.

            **Common settings**
            - `theme` — terminal colour scheme
            - `autoUpdates` — enable/disable automatic updates
            - `preferredNotifChannel` — notification delivery

            Run `/config` with no arguments for the interactive menu, or append `key value` to set \
            a value directly:

            `/config theme dark`
            """,
            category: .slashCommands,
            tags: ["config", "settings", "configuration", "preferences"],
            codeExample: "/config"
        ),
        DocArticle(
            id: "slash-cost",
            title: "/cost",
            summary: "Show token usage and cost for this session.",
            body: """
            `/cost` prints a summary of tokens consumed and the estimated USD cost for the current \
            session. Useful for budget tracking during long development sessions.

            **Output includes**
            - Input tokens used
            - Output tokens generated
            - Cache read / write tokens
            - Estimated total cost

            Prices reflect the model currently in use. Switch models with `/model` to see how \
            choices affect cost.
            """,
            category: .slashCommands,
            tags: ["cost", "tokens", "budget", "usage", "billing"],
            codeExample: "/cost"
        ),
        DocArticle(
            id: "slash-doctor",
            title: "/doctor",
            summary: "Run diagnostics to check for common issues.",
            body: """
            `/doctor` performs a series of environment checks and reports any problems it finds, \
            including missing CLI tools, outdated versions, misconfigured API keys, and network \
            connectivity issues.

            **Checks performed**
            - Claude Code version vs latest release
            - `ANTHROPIC_API_KEY` presence and validity
            - Node.js and npm versions
            - Git availability
            - MCP server connectivity (if configured)

            Run `/doctor` first when troubleshooting unexpected behaviour.
            """,
            category: .slashCommands,
            tags: ["doctor", "diagnostics", "troubleshoot", "health", "debug"],
            codeExample: "/doctor"
        ),
        DocArticle(
            id: "slash-help",
            title: "/help",
            summary: "Show available commands and usage information.",
            body: """
            `/help` prints a formatted list of all available slash commands with short descriptions. \
            Pass a command name as an argument to get detailed help for that specific command:

            `/help compact`

            The help output is context-sensitive — it reflects commands available in the current \
            environment, including any custom skills you have installed.
            """,
            category: .slashCommands,
            tags: ["help", "commands", "reference", "usage"],
            codeExample: "/help"
        ),
        DocArticle(
            id: "slash-init",
            title: "/init",
            summary: "Initialize a new CLAUDE.md project memory file.",
            body: """
            `/init` creates a `CLAUDE.md` file in the current working directory. Claude Code reads \
            this file automatically at session start and uses it as persistent project context.

            **What to put in CLAUDE.md**
            - Project description and goals
            - Tech stack and conventions
            - Common commands (`build`, `test`, `deploy`)
            - Gotchas and pitfalls to avoid
            - Links to important documentation

            The file is plain Markdown. Claude will follow instructions written there for every \
            session in that directory.
            """,
            category: .slashCommands,
            tags: ["init", "CLAUDE.md", "memory", "project", "context"],
            codeExample: "/init"
        ),
        DocArticle(
            id: "slash-login",
            title: "/login",
            summary: "Log in to your Anthropic account.",
            body: """
            `/login` opens the Anthropic authentication flow. By default, Claude Code uses your \
            `ANTHROPIC_API_KEY` environment variable, but `/login` lets you authenticate via the \
            Anthropic Console for plan-based billing.

            After login, your credentials are stored in the system keychain. Run `/logout` to \
            remove stored credentials.
            """,
            category: .slashCommands,
            tags: ["login", "authentication", "account", "credentials", "anthropic"],
            codeExample: "/login"
        ),
        DocArticle(
            id: "slash-logout",
            title: "/logout",
            summary: "Log out of your Anthropic account.",
            body: """
            `/logout` removes stored Anthropic credentials from the system keychain. After running \
            this command, Claude Code will fall back to the `ANTHROPIC_API_KEY` environment variable \
            for authentication.

            Use this command when switching between accounts or when rotating API keys.
            """,
            category: .slashCommands,
            tags: ["logout", "authentication", "account", "credentials"],
            codeExample: "/logout"
        ),
        DocArticle(
            id: "slash-mcp",
            title: "/mcp",
            summary: "View and manage MCP server connections.",
            body: """
            `/mcp` lists all configured Model Context Protocol servers and their current connection \
            status. You can use sub-commands to add, remove, or restart servers.

            **Sub-commands**
            - `/mcp list` — show all configured servers
            - `/mcp add <name> <command>` — add a new server
            - `/mcp remove <name>` — remove a server
            - `/mcp restart <name>` — restart a specific server

            MCP servers extend Claude Code with custom tools. See the MCP Servers section \
            for setup guides.
            """,
            category: .slashCommands,
            tags: ["mcp", "servers", "tools", "integrations"],
            codeExample: "/mcp list"
        ),
        DocArticle(
            id: "slash-memory",
            title: "/memory",
            summary: "Edit CLAUDE.md project memory file.",
            body: """
            `/memory` opens the current project's `CLAUDE.md` file in your configured editor. \
            If no `CLAUDE.md` exists, it offers to create one (equivalent to `/init`).

            Changes saved to the file take effect in the next session. To apply changes immediately, \
            use `/clear` after saving to reload the context.

            **Tip:** Keep CLAUDE.md concise. Overly long files consume tokens and dilute the \
            most important instructions.
            """,
            category: .slashCommands,
            tags: ["memory", "CLAUDE.md", "project", "context", "edit"],
            codeExample: "/memory"
        ),
        DocArticle(
            id: "slash-model",
            title: "/model",
            summary: "Switch the active Claude model.",
            body: """
            `/model` changes the Claude model used for the rest of the session. Pass the model \
            name as an argument:

            `/model claude-sonnet-4-5`

            **Available models**
            - `claude-opus-4-5` — most capable, highest cost
            - `claude-sonnet-4-5` — balanced performance and cost (default)
            - `claude-haiku-4-5` — fastest, lowest cost

            Use `/cost` after switching to understand the pricing impact of each model.
            """,
            category: .slashCommands,
            tags: ["model", "claude", "opus", "sonnet", "haiku", "switch"],
            codeExample: "/model claude-sonnet-4-5"
        ),
        DocArticle(
            id: "slash-permissions",
            title: "/permissions",
            summary: "View and manage tool permissions.",
            body: """
            `/permissions` shows which tools and operations Claude Code is allowed to perform in \
            the current project. You can grant or revoke permissions interactively.

            **Permission categories**
            - File read / write
            - Shell command execution
            - Network access
            - Browser automation

            Permissions are stored per-project in `~/.claude/projects/<hash>/settings.json` and \
            can also be set globally in `~/.claude/settings.json`.
            """,
            category: .slashCommands,
            tags: ["permissions", "security", "tools", "allow", "deny"],
            codeExample: "/permissions"
        ),
        DocArticle(
            id: "slash-review",
            title: "/review",
            summary: "Request a code review of recent changes.",
            body: """
            `/review` asks Claude to review the most recent changes in your working directory \
            (based on `git diff`). Claude provides feedback on correctness, style, potential \
            bugs, and improvement opportunities.

            **Tips**
            - Run `/review` before committing
            - Add specific concerns as a follow-up: "focus on security"
            - Use `--staged` to review only staged changes

            `/review --staged`
            """,
            category: .slashCommands,
            tags: ["review", "code review", "git", "diff", "feedback"],
            codeExample: "/review"
        ),
        DocArticle(
            id: "slash-status",
            title: "/status",
            summary: "Show current session status and connection info.",
            body: """
            `/status` displays a status dashboard for the current Claude Code session, including:

            - Active model and version
            - Working directory and project
            - Token usage summary
            - MCP server status
            - Authentication state

            Useful for a quick health check at the start of a session or after configuration changes.
            """,
            category: .slashCommands,
            tags: ["status", "session", "info", "connection", "health"],
            codeExample: "/status"
        ),
        DocArticle(
            id: "slash-terminal-setup",
            title: "/terminal-setup",
            summary: "Install shell integration for enhanced terminal support.",
            body: """
            `/terminal-setup` installs shell hooks into your `.bashrc`, `.zshrc`, or `.fish` config \
            that enable enhanced terminal integration, including:

            - Directory change tracking
            - Command history sharing with Claude
            - Automatic project detection
            - Richer error context

            Run once per machine. Re-run after upgrading your shell.
            """,
            category: .slashCommands,
            tags: ["terminal", "shell", "setup", "integration", "zsh", "bash"],
            codeExample: "/terminal-setup"
        ),
    ]
}

// MARK: Configuration

private extension DocArticle {
    static let configurationArticles: [DocArticle] = [
        DocArticle(
            id: "config-overview",
            title: "Configuration Overview",
            summary: "Understand the layered configuration system in Claude Code.",
            body: """
            Claude Code uses a layered configuration system. Settings are resolved in this order \
            (later values override earlier ones):

            1. **Built-in defaults** — shipped with Claude Code
            2. **Global settings** — `~/.claude/settings.json`
            3. **Project settings** — `.claude/settings.json` in the project root
            4. **Local overrides** — `.claude/settings.local.json` (gitignored)
            5. **Environment variables** — prefixed with `CLAUDE_`

            Use `/config` to edit settings interactively, or edit the JSON files directly.
            """,
            category: .configuration,
            tags: ["configuration", "settings", "json", "override", "environment"],
            codeExample: nil
        ),
        DocArticle(
            id: "config-claude-md",
            title: "CLAUDE.md Project Memory",
            summary: "Use CLAUDE.md to give Claude persistent project context.",
            body: """
            `CLAUDE.md` is a plain Markdown file placed in your project root. Claude Code reads it \
            automatically at the start of every session and uses its contents as persistent context.

            **Best practices**
            - Keep it under 500 lines to avoid diluting instructions
            - Use clear headings: `## Build Commands`, `## Architecture`, `## Conventions`
            - Include common gotchas your team has encountered
            - Update it as the project evolves

            Claude treats `CLAUDE.md` as authoritative instructions. Be specific and direct.
            """,
            category: .configuration,
            tags: ["CLAUDE.md", "memory", "project", "context", "instructions"],
            codeExample: """
            # My Project

            ## Build
            npm run build

            ## Test
            npm test -- --watchAll=false

            ## Conventions
            - Use TypeScript strict mode
            - All async functions must handle errors
            """
        ),
        DocArticle(
            id: "config-api-key",
            title: "API Key Configuration",
            summary: "Set up your Anthropic API key for Claude Code.",
            body: """
            Claude Code requires an Anthropic API key. Set it using one of these methods:

            **Environment variable (recommended)**
            ```
            export ANTHROPIC_API_KEY=sk-ant-...
            ```

            **`.env` file** (project-level, gitignored)
            ```
            ANTHROPIC_API_KEY=sk-ant-...
            ```

            **System keychain** — use `/login` to store credentials securely.

            The environment variable takes precedence over keychain credentials. \
            Never commit API keys to version control.
            """,
            category: .configuration,
            tags: ["api key", "authentication", "ANTHROPIC_API_KEY", "environment variable"],
            codeExample: "export ANTHROPIC_API_KEY=sk-ant-..."
        ),
        DocArticle(
            id: "config-model",
            title: "Default Model Selection",
            summary: "Configure which Claude model Claude Code uses by default.",
            body: """
            Set the default model in your global or project settings:

            ```json
            {
              "defaultModel": "claude-sonnet-4-5"
            }
            ```

            Or use the `CLAUDE_MODEL` environment variable:

            ```
            export CLAUDE_MODEL=claude-opus-4-5
            ```

            Override per-session with `/model <name>`. Model availability depends on \
            your API plan.
            """,
            category: .configuration,
            tags: ["model", "default", "settings", "claude", "opus", "sonnet", "haiku"],
            codeExample: """
            {
              "defaultModel": "claude-sonnet-4-5"
            }
            """
        ),
    ]
}

// MARK: MCP Servers

private extension DocArticle {
    static let mcpArticles: [DocArticle] = [
        DocArticle(
            id: "mcp-overview",
            title: "MCP Server Overview",
            summary: "Understand how Model Context Protocol servers extend Claude Code.",
            body: """
            Model Context Protocol (MCP) is an open standard that allows external servers to \
            provide Claude with additional tools and data sources. Claude Code acts as an MCP \
            client, connecting to one or more servers at startup.

            **What MCP servers can provide**
            - Custom tools (functions Claude can call)
            - Resource access (files, databases, APIs)
            - Prompts (reusable instruction templates)

            Servers run as local processes or remote services and communicate via JSON-RPC \
            over stdio or HTTP/SSE.
            """,
            category: .mcpServers,
            tags: ["mcp", "model context protocol", "tools", "servers", "extensions"],
            codeExample: nil
        ),
        DocArticle(
            id: "mcp-setup",
            title: "Adding an MCP Server",
            summary: "Configure a new MCP server in Claude Code settings.",
            body: """
            Add MCP servers to `~/.claude/settings.json` under the `mcpServers` key:

            ```json
            {
              "mcpServers": {
                "filesystem": {
                  "command": "npx",
                  "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/dir"]
                }
              }
            }
            ```

            Or use the `/mcp add` command:

            `/mcp add filesystem npx -y @modelcontextprotocol/server-filesystem ~/projects`

            Restart Claude Code after adding servers to load the new tools.
            """,
            category: .mcpServers,
            tags: ["mcp", "setup", "add", "configuration", "settings.json"],
            codeExample: """
            {
              "mcpServers": {
                "my-server": {
                  "command": "node",
                  "args": ["./mcp-server.js"]
                }
              }
            }
            """
        ),
        DocArticle(
            id: "mcp-troubleshoot",
            title: "MCP Server Troubleshooting",
            summary: "Diagnose and fix common MCP server connection issues.",
            body: """
            **Server not connecting**
            1. Check the server process is running: `/mcp list`
            2. Verify the command and args in settings.json
            3. Run `/doctor` to check for environment issues
            4. Look for error output in Claude Code logs

            **Tools not appearing**
            - Ensure the server implements the tools list endpoint
            - Check for version mismatches between client and server
            - Try `/mcp restart <name>` to force reconnection

            **Permission denied**
            - MCP servers inherit Claude Code's permissions
            - Grant additional permissions with `/permissions`
            """,
            category: .mcpServers,
            tags: ["mcp", "troubleshoot", "debug", "connection", "error"],
            codeExample: "/mcp list"
        ),
        DocArticle(
            id: "mcp-popular-servers",
            title: "Popular MCP Servers",
            summary: "A curated list of commonly used MCP servers.",
            body: """
            **Official Anthropic Servers**
            - `@modelcontextprotocol/server-filesystem` — Read/write local files
            - `@modelcontextprotocol/server-github` — GitHub API access
            - `@modelcontextprotocol/server-postgres` — PostgreSQL queries
            - `@modelcontextprotocol/server-brave-search` — Web search

            **Community Servers**
            - `@modelcontextprotocol/server-sqlite` — SQLite database tools
            - `@modelcontextprotocol/server-slack` — Slack messaging
            - `@modelcontextprotocol/server-puppeteer` — Browser automation

            Install via npm: `npm install -g @modelcontextprotocol/server-filesystem`
            """,
            category: .mcpServers,
            tags: ["mcp", "servers", "filesystem", "github", "postgres", "popular"],
            codeExample: "npm install -g @modelcontextprotocol/server-filesystem"
        ),
    ]
}

// MARK: Hooks

private extension DocArticle {
    static let hooksArticles: [DocArticle] = [
        DocArticle(
            id: "hooks-overview",
            title: "Hooks Overview",
            summary: "Automate actions at key points in Claude Code's workflow.",
            body: """
            Hooks are shell commands that Claude Code executes automatically at defined lifecycle \
            points. They enable automation without requiring changes to your CLAUDE.md or repeated \
            instructions.

            **Lifecycle points**
            - `PreToolUse` — before any tool is called
            - `PostToolUse` — after a tool call completes
            - `Notification` — when Claude sends a notification event
            - `Stop` — when Claude finishes responding

            Hooks are defined in `settings.json` and run as child processes with full access \
            to tool call metadata via environment variables.
            """,
            category: .hooks,
            tags: ["hooks", "automation", "lifecycle", "PreToolUse", "PostToolUse"],
            codeExample: nil
        ),
        DocArticle(
            id: "hooks-setup",
            title: "Configuring Hooks",
            summary: "Set up hooks in your Claude Code settings.json.",
            body: """
            Define hooks in `~/.claude/settings.json` or `.claude/settings.json`:

            ```json
            {
              "hooks": {
                "PostToolUse": [
                  {
                    "matcher": "Write",
                    "hooks": [
                      {
                        "type": "command",
                        "command": "prettier --write $CLAUDE_FILE_PATH"
                      }
                    ]
                  }
                ]
              }
            }
            ```

            The `matcher` field filters which tool calls trigger the hook. \
            Use `"*"` to match all tools.
            """,
            category: .hooks,
            tags: ["hooks", "setup", "configuration", "PostToolUse", "command"],
            codeExample: """
            {
              "hooks": {
                "PostToolUse": [
                  {
                    "matcher": "Write",
                    "hooks": [{ "type": "command", "command": "prettier --write $CLAUDE_FILE_PATH" }]
                  }
                ]
              }
            }
            """
        ),
        DocArticle(
            id: "hooks-env-vars",
            title: "Hook Environment Variables",
            summary: "Environment variables available inside hook scripts.",
            body: """
            Claude Code injects context into hook processes via environment variables:

            | Variable | Description |
            |---|---|
            | `CLAUDE_TOOL_NAME` | Name of the tool being called |
            | `CLAUDE_TOOL_INPUT` | JSON-encoded tool input |
            | `CLAUDE_TOOL_RESULT` | JSON-encoded tool result (PostToolUse only) |
            | `CLAUDE_FILE_PATH` | File path (for file-related tools) |
            | `CLAUDE_SESSION_ID` | Current session identifier |

            Use these to make hooks context-aware — e.g. run linting only on `.ts` files.
            """,
            category: .hooks,
            tags: ["hooks", "environment variables", "CLAUDE_TOOL_NAME", "CLAUDE_FILE_PATH"],
            codeExample: """
            #!/bin/bash
            # Only format TypeScript files
            if [[ "$CLAUDE_FILE_PATH" == *.ts ]]; then
              prettier --write "$CLAUDE_FILE_PATH"
            fi
            """
        ),
    ]
}

// MARK: Permissions

private extension DocArticle {
    static let permissionsArticles: [DocArticle] = [
        DocArticle(
            id: "permissions-overview",
            title: "Permissions Overview",
            summary: "Understand how Claude Code manages tool and file permissions.",
            body: """
            Claude Code enforces a permission system to ensure you always remain in control. \
            Before executing potentially dangerous operations, Claude asks for explicit approval.

            **Permission levels**
            - **Auto-approved** — Safe read operations run without prompting
            - **Ask once** — You approve the first use; subsequent uses are automatic
            - **Always ask** — Every use requires explicit approval
            - **Denied** — Operation is blocked entirely

            Permissions are stored per-project. Global defaults live in \
            `~/.claude/settings.json`.
            """,
            category: .permissions,
            tags: ["permissions", "security", "approval", "tools", "safety"],
            codeExample: nil
        ),
        DocArticle(
            id: "permissions-allow-list",
            title: "Allow and Deny Lists",
            summary: "Pre-approve or block specific tools using allowedTools and blockedTools.",
            body: """
            Avoid repeated permission prompts by configuring allow/deny lists in settings.json:

            ```json
            {
              "allowedTools": [
                "Read",
                "Write",
                "Bash(git *)"
              ],
              "blockedTools": [
                "Bash(rm -rf *)"
              ]
            }
            ```

            `allowedTools` entries support glob-style matching on tool name and arguments. \
            This is the recommended approach for trusted project environments.
            """,
            category: .permissions,
            tags: ["permissions", "allowedTools", "blockedTools", "settings", "allow list"],
            codeExample: """
            {
              "allowedTools": ["Read", "Write", "Bash(git *)"],
              "blockedTools": ["Bash(rm -rf *)"]
            }
            """
        ),
        DocArticle(
            id: "permissions-network",
            title: "Network Access Permissions",
            summary: "Control which network requests Claude Code is allowed to make.",
            body: """
            By default, Claude Code can only reach the Anthropic API. MCP servers and \
            browser tools may require additional network permissions.

            **Configuring network access**
            ```json
            {
              "networkAccess": {
                "allowedHosts": ["api.github.com", "*.mycompany.com"]
              }
            }
            ```

            Network permissions apply to all tools that make HTTP requests, including \
            MCP server tools and the built-in browser automation tool.
            """,
            category: .permissions,
            tags: ["permissions", "network", "hosts", "allowedHosts", "HTTP"],
            codeExample: """
            {
              "networkAccess": {
                "allowedHosts": ["api.github.com"]
              }
            }
            """
        ),
    ]
}

// MARK: Best Practices

private extension DocArticle {
    static let bestPracticesArticles: [DocArticle] = [
        DocArticle(
            id: "bp-effective-prompting",
            title: "Effective Prompting",
            summary: "Write clearer prompts to get better results from Claude.",
            body: """
            **Be specific about the task**
            State what you want, the constraints, and the expected output format. \
            Vague prompts produce vague results.

            **Provide context up front**
            Don't assume Claude remembers previous sessions. State the relevant \
            background in each new session, or rely on `CLAUDE.md` for persistent context.

            **Break large tasks into steps**
            Ask Claude to outline a plan before implementing. Review the plan, \
            then approve execution. This reduces wasted effort on wrong approaches.

            **Use examples**
            Show Claude an example of what you want. "Make it look like X" with \
            an actual X is far more effective than a long description.
            """,
            category: .bestPractices,
            tags: ["prompting", "tips", "effective", "context", "instructions"],
            codeExample: nil
        ),
        DocArticle(
            id: "bp-git-workflow",
            title: "Git Workflow with Claude Code",
            summary: "Best practices for using Claude Code with version control.",
            body: """
            **Commit frequently**
            Ask Claude to commit after each logical change. Small commits are easier \
            to review and revert.

            **Review before committing**
            Use `/review --staged` to have Claude review staged changes before you \
            finalise a commit. Catch issues early.

            **Use branches**
            Work on a feature branch. If Claude makes a mistake, `git reset --hard` \
            brings you back to a clean state quickly.

            **Include git context**
            When reporting a bug, share the relevant `git log` or `git diff` output \
            so Claude has full context.
            """,
            category: .bestPractices,
            tags: ["git", "workflow", "commits", "branches", "version control"],
            codeExample: "git checkout -b feature/my-feature"
        ),
        DocArticle(
            id: "bp-cost-management",
            title: "Managing API Costs",
            summary: "Strategies to control token usage and keep costs predictable.",
            body: """
            **Use `/compact` proactively**
            Compact the conversation before token usage gets too high. A compact \
            session is cheaper than one that hits the context limit mid-task.

            **Choose the right model**
            Use `haiku` for simple tasks (refactoring, reformatting), `sonnet` for \
            general development, and `opus` only for complex architectural work.

            **Set a spending limit**
            Configure `spendingLimitUSD` in settings.json to prevent unexpected charges:

            ```json
            { "spendingLimitUSD": 10 }
            ```

            **Monitor with `/cost`**
            Check `/cost` at natural break points to track usage per task.
            """,
            category: .bestPractices,
            tags: ["cost", "tokens", "budget", "spending limit", "haiku", "compact"],
            codeExample: """
            {
              "spendingLimitUSD": 10
            }
            """
        ),
        DocArticle(
            id: "bp-security",
            title: "Security Best Practices",
            summary: "Keep your projects and credentials safe when using Claude Code.",
            body: """
            **Never share API keys in conversation**
            Claude Code has access to your working directory. Avoid pasting API keys, \
            passwords, or secrets directly in chat — use environment variables or a \
            secrets manager instead.

            **Review shell commands before approving**
            Read every `Bash` tool call Claude proposes. Malicious or incorrect commands \
            can cause irreversible damage. If unsure, ask Claude to explain the command first.

            **Use project-scoped permissions**
            Grant only the permissions each project needs. Don't give a documentation \
            project shell execution rights.

            **Audit hooks**
            Hooks run automatically. Review your `settings.json` hooks section regularly, \
            especially after cloning a new project.
            """,
            category: .bestPractices,
            tags: ["security", "api key", "credentials", "permissions", "hooks", "safety"],
            codeExample: nil
        ),
        DocArticle(
            id: "bp-project-structure",
            title: "Organising Projects for Claude Code",
            summary: "Structure your project so Claude Code works most effectively.",
            body: """
            **Maintain a good CLAUDE.md**
            A well-written `CLAUDE.md` is the single best investment for Claude Code \
            productivity. Include build commands, test commands, architecture overview, \
            and common gotchas.

            **Keep a clean working directory**
            Claude reads directory listings and file trees. A cluttered workspace \
            (stale build artifacts, too many files) increases noise and token usage.

            **Use `.claudeignore`**
            Create a `.claudeignore` file (same syntax as `.gitignore`) to exclude \
            files Claude should not read — build output, node_modules, large assets.

            **Consistent naming**
            Consistent file and variable naming helps Claude make correct assumptions \
            about project conventions without being told explicitly.
            """,
            category: .bestPractices,
            tags: ["project", "structure", "CLAUDE.md", "claudeignore", "organisation"],
            codeExample: """
            # .claudeignore
            node_modules/
            dist/
            *.log
            .env*
            """
        ),
    ]
}
