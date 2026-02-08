# Tools, Skills, MCPs & SDKs Inventory

> Generated: 2026-02-07 | Project: ILS iOS (`/Users/nick/Desktop/ils-ios`)

---

## 1. MCP Servers & Tools

### 1.1 XClaude Plugin (`mcp__plugin_xclaude-plugin_xc-all`)

Xcode and iOS Simulator automation MCP. **Critical for iOS development.**

#### Xcode Build Tools
| Tool | Description |
|------|-------------|
| `xcode_build` | Build Xcode project (scheme, configuration, destination) |
| `xcode_clean` | Clean build artifacts |
| `xcode_test` | Run test suite (scheme, destination, test plan, only_testing) |
| `xcode_list` | List schemes and targets |
| `xcode_version` | Get Xcode version info |

#### Simulator Management
| Tool | Description |
|------|-------------|
| `simulator_list` | List simulators (filter by type, runtime, availability) |
| `simulator_boot` | Boot a simulator device |
| `simulator_shutdown` | Shutdown a simulator |
| `simulator_create` | Create new simulator |
| `simulator_delete` | Delete a simulator |
| `simulator_install_app` | Install .app bundle |
| `simulator_launch_app` | Launch app by bundle ID |
| `simulator_terminate_app` | Terminate running app |
| `simulator_screenshot` | Capture screenshot |
| `simulator_openurl` | Open URL/deep link |
| `simulator_get_app_container` | Get app container path (data/bundle/group) |
| `simulator_health_check` | Validate iOS dev environment |

#### IDB (iOS Development Bridge) UI Automation
| Tool | Description |
|------|-------------|
| `idb_describe` | Query UI accessibility tree (all elements or point) |
| `idb_tap` | Tap at coordinates |
| `idb_input` | Type text or press keys |
| `idb_gesture` | Swipe gestures or hardware button presses |
| `idb_find_element` | Search UI elements by label/identifier |
| `idb_check_quality` | Check UI quality |

---

### 1.2 Oh-My-ClaudeCode Tools (`mcp__plugin_oh-my-claudecode_t`)

#### LSP (Language Server Protocol)
| Tool | Description |
|------|-------------|
| `lsp_hover` | Type info and docs at position |
| `lsp_goto_definition` | Jump to symbol definition |
| `lsp_find_references` | Find all references to a symbol |
| `lsp_document_symbols` | File symbol outline |
| `lsp_workspace_symbols` | Search symbols by name across workspace |
| `lsp_diagnostics` | File errors/warnings/hints |
| `lsp_diagnostics_directory` | Project-wide diagnostics (tsc --noEmit) |
| `lsp_prepare_rename` | Check rename feasibility |
| `lsp_rename` | Rename symbol across project |
| `lsp_code_actions` | Available refactorings/quick fixes |
| `lsp_code_action_resolve` | Full edit details for a code action |
| `lsp_servers` | List available language servers |

#### AST (Abstract Syntax Tree)
| Tool | Description |
|------|-------------|
| `ast_grep_search` | Structural code pattern search (supports Swift) |
| `ast_grep_replace` | Structural code transformation |

#### Python REPL
| Tool | Description |
|------|-------------|
| `python_repl` | Persistent Python REPL (pandas, numpy, matplotlib) |

#### State Management
| Tool | Description |
|------|-------------|
| `state_read` | Read mode state (autopilot, ralph, ultrawork, etc.) |
| `state_write` | Write/update mode state |
| `state_clear` | Clear mode state |
| `state_list_active` | List active modes |
| `state_get_status` | Detailed mode status |

#### Notepad (Session Memory)
| Tool | Description |
|------|-------------|
| `notepad_read` | Read notepad (all/priority/working/manual) |
| `notepad_write_priority` | Set priority context (max 500 chars) |
| `notepad_write_working` | Add timestamped working memory entry |
| `notepad_write_manual` | Add permanent manual entry |
| `notepad_prune` | Remove old entries (default: 7 days) |
| `notepad_stats` | Get notepad statistics |

#### Project Memory
| Tool | Description |
|------|-------------|
| `project_memory_read` | Read project memory (techStack, build, etc.) |
| `project_memory_write` | Write/update project memory |
| `project_memory_add_note` | Add categorized note |
| `project_memory_add_directive` | Add persistent directive |

---

### 1.3 Codex MCP (`mcp__plugin_oh-my-claudecode_x`)

OpenAI Codex CLI integration for analytical/planning tasks.

| Tool | Description |
|------|-------------|
| `ask_codex` | Send prompt to Codex (roles: architect, planner, critic, analyst, code-reviewer, security-reviewer, tdd-guide) |
| `check_job_status` | Non-blocking status check |
| `wait_for_job` | Blocking wait (up to 1 hour) |
| `kill_job` | Kill running job (SIGTERM/SIGINT) |
| `list_jobs` | List background jobs |

---

### 1.4 Gemini MCP (`mcp__plugin_oh-my-claudecode_g`)

Google Gemini CLI integration for design/implementation tasks (1M token context).

| Tool | Description |
|------|-------------|
| `ask_gemini` | Send prompt to Gemini (roles: designer, writer, vision) |
| `check_job_status` | Non-blocking status check |
| `wait_for_job` | Blocking wait (up to 1 hour) |
| `kill_job` | Kill running job |
| `list_jobs` | List background jobs |

---

### 1.5 Claude Memory (`mcp__plugin_claude-mem_mcp-search`)

3-layer memory search workflow.

| Tool | Description |
|------|-------------|
| `____IMPORTANT` | Usage instructions for 3-layer workflow |
| `search` | Step 1: Search memory, returns index with IDs |
| `timeline` | Step 2: Get context around results |
| `get_observations` | Step 3: Fetch full details for filtered IDs |

---

### 1.6 Context7 (Dual: `mcp__Context7` + `mcp__claude_ai_context7`)

Up-to-date documentation for any library/framework.

| Tool | Description |
|------|-------------|
| `resolve-library-id` | Resolve package name to Context7 library ID |
| `query-docs` | Query documentation with library ID |

---

### 1.7 DeepWiki (`mcp__claude_ai_deepwiki`)

AI-powered GitHub repository documentation.

| Tool | Description |
|------|-------------|
| `read_wiki_structure` | Get documentation topics for a repo |
| `read_wiki_contents` | View full documentation |
| `ask_question` | Ask questions about a repo (up to 10 repos) |

---

### 1.8 Firecrawl (Triple: `mcp__firecrawl` + `mcp__claude_ai_firecrawl` + `mcp__firecrawl-mcp`)

Web scraping, crawling, and data extraction.

| Tool | Description |
|------|-------------|
| `firecrawl_scrape` | Scrape single URL (markdown, JSON, screenshot, branding) |
| `firecrawl_map` | Map website structure, discover URLs |
| `firecrawl_search` | Search web with optional scraping |
| `firecrawl_crawl` | Crawl website with configurable depth |
| `firecrawl_check_crawl_status` | Check crawl job status |
| `firecrawl_extract` | Extract structured data from URLs |
| `firecrawl_agent` | Autonomous web research agent |
| `firecrawl_agent_status` | Check agent job status |

---

### 1.9 Tavily (`mcp__tavily`)

Web search and research tools.

| Tool | Description |
|------|-------------|
| `tavily_search` | Search web (basic/advanced/fast/ultra-fast) |
| `tavily_extract` | Extract content from URLs |
| `tavily_crawl` | Crawl website |
| `tavily_map` | Map website structure |
| `tavily_research` | Comprehensive research (mini/pro/auto) |

---

### 1.10 Repomix (`mcp__repomix`)

AI-optimized codebase analysis and packaging.

| Tool | Description |
|------|-------------|
| `pack_codebase` | Package local directory for AI analysis |
| `pack_remote_repository` | Package GitHub repo for AI analysis |
| `generate_skill` | Create Claude Agent Skill from codebase |
| `attach_packed_output` | Attach existing packed file |
| `read_repomix_output` | Read packed output (with line ranges) |
| `grep_repomix_output` | Search patterns in packed output |
| `file_system_read_file` | Read file via Repomix |
| `file_system_read_directory` | Read directory via Repomix |

---

### 1.11 Sequential Thinking (`mcp__sequential-thinking`)

| Tool | Description |
|------|-------------|
| `sequentialthinking` | Dynamic reflective problem-solving with branching, revision, and hypothesis verification |

---

### 1.12 Stitch (`mcp__stitch`)

UI design and code generation.

| Tool | Description |
|------|-------------|
| `create_project` | Create new Stitch project |
| `get_project` | Get project details |
| `list_projects` | List projects (owned/shared) |
| `list_screens` | List screens in project |
| `get_screen` | Get screen details |
| `generate_screen_from_text` | Generate screen from text prompt (MOBILE/DESKTOP) |

---

### 1.13 Vercel (`mcp__claude_ai_Vercel`)

| Tool | Description |
|------|-------------|
| `deploy_to_vercel` | Deploy current project |
| `list_projects` | List projects |
| `get_project` | Get project details |
| `list_deployments` | List deployments |
| `get_deployment` | Get deployment details |
| `get_deployment_build_logs` | Get build logs |
| `get_runtime_logs` | Get runtime logs |
| `search_vercel_documentation` | Search Vercel docs |
| `list_teams` | List user teams |
| `check_domain_availability_and_price` | Check domain availability |
| `get_access_to_vercel_url` | Generate shareable link for protected deployments |
| `web_fetch_vercel_url` | Fetch protected Vercel URL |

---

### 1.14 Cloudflare (`mcp__claude_ai_Cloudflare_Developer_Platform`)

| Tool | Description |
|------|-------------|
| `accounts_list` | List accounts |
| `set_active_account` | Set active account |
| `kv_namespaces_list/create/delete/get/update` | KV namespace management |
| `workers_list/get_worker/get_worker_code` | Workers management |
| `r2_buckets_list/create/get/delete` | R2 storage management |
| `d1_databases_list/create/delete/get/query` | D1 database management |
| `hyperdrive_configs_list/delete/get/edit` | Hyperdrive config |
| `search_cloudflare_documentation` | Search CF docs |
| `migrate_pages_to_workers_guide` | Migration guide |

---

### 1.15 Mermaid Chart (`mcp__claude_ai_Mermaid_Chart`)

| Tool | Description |
|------|-------------|
| `validate_and_render_mermaid_diagram` | Render diagram to image |
| `get_diagram_title` | Generate title from content |
| `get_diagram_summary` | Generate summary |
| `list_tools` | List available MCP tools |

---

### 1.16 GoDaddy (`mcp__claude_ai_GoDaddy`)

| Tool | Description |
|------|-------------|
| `domains_suggest` | Generate domain name suggestions |
| `domains_check_availability` | Check domain availability |

---

## 2. Claude Code Skills (oh-my-claudecode)

### 2.1 Execution Modes
| Skill | Trigger | Description |
|-------|---------|-------------|
| `autopilot` | "build me", "I want a" | Full autonomous execution |
| `ralph` | "ralph", "don't stop" | Self-referential loop until completion |
| `ultrawork` | "ulw", "ultrawork" | Maximum parallelism |
| `ultrapilot` | "ultrapilot" | Parallel autopilot with file ownership |
| `ecomode` | "eco", "ecomode" | Token-efficient with Haiku/Sonnet |
| `swarm` | "swarm" | N coordinated agents with SQLite claiming |
| `pipeline` | "pipeline" | Sequential agent chaining |
| `ultraqa` | (by autopilot) | QA cycling workflow |

### 2.2 Planning
| Skill | Trigger | Description |
|-------|---------|-------------|
| `plan` | "plan this" | Strategic planning |
| `ralplan` | "ralplan" | Iterative planning (Planner+Architect+Critic) |
| `review` | "review plan" | Review with Critic |
| `analyze` | "analyze", "debug" | Deep analysis |

### 2.3 Search & Research
| Skill | Trigger | Description |
|-------|---------|-------------|
| `deepsearch` | "search", "find" | Thorough codebase search |
| `deepinit` | "deepinit" | Deep codebase init with AGENTS.md |
| `research` | "research" | Parallel scientist agents |

### 2.4 Quality & Review
| Skill | Trigger | Description |
|-------|---------|-------------|
| `tdd` | "tdd", "test first" | Test-Driven Development |
| `build-fix` | "fix build" | Fix build/type errors |
| `code-review` | "review code" | Code quality review |
| `security-review` | "security review" | OWASP Top 10 detection |

### 2.5 Silent/Auto-Detected
| Skill | Trigger | Description |
|-------|---------|-------------|
| `frontend-ui-ux` | UI/component work | Designer-developer |
| `git-master` | Git/commit work | Git expert |

### 2.6 Utilities
| Skill | Description |
|-------|-------------|
| `cancel` | Cancel active OMC mode |
| `note` | Save notes to notepad |
| `learner` | Extract skill from conversation |

### 2.7 Custom Slash Commands
| Command | File | Description |
|---------|------|-------------|
| `/validate` | `~/.claude/commands/validate.md` | Functional validation through real user testing (no mocks) |

---

## 3. Agent Definitions (oh-my-claudecode)

33 agents available across tiers:

### By Domain
| Domain | Haiku (Low) | Sonnet (Medium) | Opus (High) |
|--------|-------------|-----------------|-------------|
| Analysis | `architect-low` | `architect-medium` | `architect` |
| Execution | `executor-low` | `executor` | `executor-high` |
| Deep Work | - | - | `deep-executor` |
| Search | `explore` | `explore-medium` | `explore-high` |
| Research | `researcher-low` | `researcher` | - |
| Frontend | `designer-low` | `designer` | `designer-high` |
| Docs | `writer` | - | - |
| Visual | - | `vision` | - |
| Planning | - | - | `planner` |
| Critique | - | - | `critic` |
| Pre-Planning | - | - | `analyst` |
| Testing | - | `qa-tester` | `qa-tester-high` |
| Security | `security-reviewer-low` | - | `security-reviewer` |
| Build | `build-fixer-low` | `build-fixer` | - |
| TDD | `tdd-guide-low` | `tdd-guide` | - |
| Code Review | `code-reviewer-low` | - | `code-reviewer` |
| Data Science | `scientist-low` | `scientist` | `scientist-high` |
| Git | - | `git-master` | - |

---

## 4. Installed CLI Tools

### 4.1 Apple/Xcode Toolchain
| Tool | Path | Version |
|------|------|---------|
| `swift` | `/usr/bin/swift` | Swift 6.2.4 |
| `xcodebuild` | `/usr/bin/xcodebuild` | Xcode 26.3 (17C519) |
| `xcrun` | `/usr/bin/xcrun` | v72 |
| `xcodegen` | `/opt/homebrew/bin/xcodegen` | installed |
| `tuist` | `/opt/homebrew/bin/tuist` | installed (tuist@4.21.1) |
| `swiftformat` | `/opt/homebrew/bin/swiftformat` | installed |
| `swiftlint` | `/opt/homebrew/bin/swiftlint` | installed |
| `periphery` | `/opt/homebrew/bin/periphery` | installed (dead code detection) |
| `xcbeautify` | `/opt/homebrew/bin/xcbeautify` | installed |
| `xcpretty` | `~/.gem/bin/xcpretty` | installed |
| `carthage` | `/opt/homebrew/bin/carthage` | installed |
| `fastlane` | `/opt/homebrew/bin/fastlane` | installed |
| `idb` | `~/Library/Python/3.12/bin/idb` | fb-idb 1.1.7 |
| `idb-companion` | brew | installed |

### 4.2 NOT Installed
| Tool | Status |
|------|--------|
| `mint` | not found |
| `sourcery` | not found |
| `cocoapods` (CLI) | not found (brew has it but CLI missing) |

### 4.3 General Development
| Tool | Path | Version |
|------|------|---------|
| `gh` | `/opt/homebrew/bin/gh` | 2.86.0 |
| `jq` | `/opt/homebrew/bin/jq` | installed |
| `python3` | `/opt/homebrew/bin/python3.12` | 3.12.12 |
| `node` | `/opt/homebrew/bin/node` | v25.5.0 |
| `npm` | `/usr/local/bin/npm` | 8.5.1 |
| `git` | brew | installed |
| `tmux` | brew | installed |
| `ripgrep` | brew | installed |

---

## 5. Relevant Homebrew Packages

### iOS/Swift Development
`carthage`, `cocoapods`, `fastlane`, `idb-companion`, `swiftformat`, `swiftgen`, `swiftlint`, `tuist@4.21.1`, `xcbeautify`, `xclogparser`, `xcode-build-server`, `xcodegen`, `xctesthtmlreport`

### Backend/Server
`cloudflared`, `redis`, `postgresql@15`, `postgresql@16`, `supabase`, `vapor` (via swift deps)

### AI/ML
`aichat`, `airis-code`, `codex`, `gemini-cli`, `ralph-orchestrator`, `openai-whisper`

### Build & Automation
`cmake`, `gradle`, `docker`, `docker-compose`, `docker-machine`

### Languages & Runtimes
`go`, `rust`, `rustup`, `ruby`, `python@3.10/3.11/3.12/3.13/3.14`, `node`, `node@22`, `deno`, `bun`

### Package Managers
`pnpm`, `yarn`, `nvm`, `uv`, `pipx`, `poetry`, `mise`

### Networking & Security
`cloudflared`, `tailscale`, `mosh`, `sshpass`, `trufflehog`

### Media
`ffmpeg`, `imagemagick`, `tesseract`

### Other Notable
`repomix`, `claude-squad`, `cliclick`, `htop`, `glances`, `obsidian-cli`, `pandoc`, `rclone`

---

## 6. Python Packages (iOS-relevant)

| Package | Version | Description |
|---------|---------|-------------|
| `fb-idb` | 1.1.7 | Facebook iOS Development Bridge |
| `pymobiledevice3` | 2.30.0 | iOS device automation |
| `swiftlens` | 0.2.14 | Swift code analysis (local dev) |
| `claude_code_api` | 0.1.0 | Claude Code API (local dev) |

---

## 7. Swift Package Dependencies (SPM via Xcode)

### Direct Dependencies (Project)
| Package | Source | Purpose |
|---------|--------|---------|
| SwiftAnthropic | github.com/...SwiftAnthropic | Anthropic API client |
| ClaudeCodeSDK | github.com/...ClaudeCodeSDK | Claude Code SDK (forked) |
| HighlightSwift | github.com/appstefan/HighlightSwift | Syntax highlighting |
| swift-markdown-ui | github.com/gonzalezreal/swift-markdown-ui | Markdown rendering |
| NetworkImage | github.com/gonzalezreal/NetworkImage | Async image loading |
| Yams | github.com/jpsim/Yams | YAML parsing |

### Backend (Vapor Stack)
| Package | Purpose |
|---------|---------|
| vapor | Web framework |
| fluent | ORM |
| fluent-sqlite-driver | SQLite database driver |
| fluent-kit | Fluent core |
| sqlite-kit / sqlite-nio | SQLite bindings |
| async-http-client | HTTP client |
| websocket-kit | WebSocket support |
| console-kit | CLI utilities |
| routing-kit | URL routing |
| multipart-kit | Multipart form data |
| sql-kit | SQL query building |

### Networking (Apple/Server)
| Package | Purpose |
|---------|---------|
| swift-nio | Event-driven networking |
| swift-nio-ssl | TLS/SSL |
| swift-nio-http2 | HTTP/2 |
| swift-nio-extras | Extra channel handlers |
| swift-nio-transport-services | Network.framework integration |
| swift-nio-ssh | SSH protocol |
| Citadel | SSH client (via swift-nio-ssh) |
| BigInt | Large integer support |

### Apple Ecosystem
| Package | Purpose |
|---------|---------|
| swift-algorithms | Sequence/collection algorithms |
| swift-async-algorithms | Async sequence algorithms |
| swift-collections | Data structures |
| swift-crypto | Cryptography |
| swift-certificates | X.509 certificates |
| swift-atomics | Atomic operations |
| swift-numerics | Numeric protocols |
| swift-system | System calls |
| swift-log | Logging |
| swift-metrics | Metrics |
| swift-distributed-tracing | Distributed tracing |
| swift-service-context | Service context |
| swift-service-lifecycle | Service lifecycle |
| swift-http-types | HTTP type definitions |
| swift-http-structured-headers | HTTP structured headers |
| swift-asn1 | ASN.1 encoding |

---

## 8. Project Structure

| Component | Path | Type |
|-----------|------|------|
| Xcode Project | `ILSApp/ILSApp.xcodeproj` | `.xcodeproj` |
| Xcode Workspace | `ILSApp.xcworkspace` (root) | `.xcworkspace` |
| Bundle ID | `com.ils.app` | - |
| Dedicated Simulator | `50523130-57AA-48B0-ABD0-4D59CE455F14` | iPhone 16 Pro Max, iOS 18.6 |
| Backend | Vapor (Swift), port 9090 | SPM |
| URL Scheme | `ils://` | Registered in Info.plist |

---

## 9. Built-in Claude Code Tools

| Tool | Description |
|------|-------------|
| `Read` | Read files |
| `Write` | Write/create files |
| `Edit` | Edit files (string replacement) |
| `Glob` | File pattern matching |
| `Grep` | Content search (ripgrep) |
| `Bash` | Shell command execution |
| `WebFetch` | Fetch and analyze web content |
| `WebSearch` | Web search |
| `NotebookEdit` | Edit Jupyter notebooks |
| `Task` | Delegate to sub-agents |
| `TaskCreate/Update/Get/List` | Task management |
| `SendMessage` | Team communication |
| `ToolSearch` | Search/load deferred tools |
| `Skill` | Invoke skills |

---

## 10. Summary Statistics

| Category | Count |
|----------|-------|
| MCP Servers | 16 (some duplicated across providers) |
| Total MCP Tools | ~160+ unique tools |
| OMC Skills | 25+ |
| OMC Agents | 33 |
| CLI Tools (iOS) | 14 installed, 3 missing |
| Brew Packages | 300+ (40+ relevant) |
| Swift Packages | 42 (direct + transitive) |
| Python iOS Tools | 4 |
| Custom Commands | 1 (`/validate`) |
