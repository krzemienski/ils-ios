# External Integrations

**Analysis Date:** 2026-02-19

## APIs & External Services

**Claude AI (via Claude CLI):**
- Service: Anthropic Claude API (accessed through Claude CLI)
- What it's used for: Chat responses, code execution, skill generation
- SDK/Client: Claude CLI (binary `claude` in PATH) via Python `claude-agent-sdk` wrapper
- Auth: OAuth token stored by Claude CLI (environment-inherited, no ANTHROPIC_API_KEY needed)
- Backend integration: `ClaudeExecutorService.swift` spawns `python3 scripts/sdk-wrapper.py` subprocess which calls Claude CLI, outputs NDJSON stream
- Fallback: Direct Claude CLI invocation via `claude -p` flag when SDK unavailable (outside Claude Code sessions)

**GitHub API:**
- Service: GitHub REST API for marketplace search and skill content fetching
- What it's used for: Searching for SKILL.md files, fetching skill marketplace, cloning plugins
- Endpoint: `https://api.github.com/search/code`
- Auth: `GITHUB_TOKEN` environment variable (optional, rate-limited without it)
- Backend integration: `GitHubService.swift` queries GitHub Code search API
- Caching: Search results cached in SQLite via `IndexingService` to reduce API calls
- Files: `Sources/ILSBackend/Services/GitHubService.swift`

**Cloudflare Tunnel:**
- Service: Cloudflare tunnel for exposing local backend to internet
- What it's used for: Remote access to ILS backend via tunnel URL
- Modes: Quick tunnel (random URL) or named tunnel (custom domain with token)
- CLI tool: `cloudflared` binary (optional dependency, checked at startup)
- Backend integration: `TunnelService.swift` manages cloudflared subprocess
- Files: `Sources/ILSBackend/Services/TunnelService.swift`

## Data Storage

**Databases:**
- Backend (Vapor):
  - Type: SQLite
  - Location: `ils.sqlite` (working directory of backend process)
  - Client: Fluent ORM with FluentSQLiteDriver
  - Connection: File-based, auto-created at startup
  - Tables: Projects, Sessions, Messages, Themes, CachedResults, FleetHosts
  - Migrations: Auto-run on startup via `app.autoMigrate()`

- Client (iOS/macOS):
  - Type: SQLite
  - Framework: GRDB (database toolkit)
  - Purpose: Local caching of sessions, projects, skills for offline resilience
  - Location: App's Documents directory
  - Tables: cached_sessions (one-way cache from backend)
  - Files: `ILSApp/ILSApp/Services/LocalDatabase.swift`

**File Storage:**
- Local filesystem only (no cloud storage)
- Backend stores:
  - Skill YAML files (in ~/.claude-code/skills/ or similar)
  - Plugin repositories (cloned via git into ~/.plugins/ or similar)
  - Configuration files (from ~/.claude-code/)
  - Session transcripts (read from ~/.claude-code/sessions/)

- iOS/macOS stores:
  - Logs: `~/Library/Caches/com.ils.app/logs/` (AppLogger.swift)
  - Credentials: iOS Keychain only (not filesystem)
  - App state: UserDefaults for app preferences

**Caching:**
- Backend: In-memory cache in APIClient actor (30-second TTL for GET requests)
- Backend: SQLite cache for GitHub search results (IndexingService)
- Client: GRDB local database for sessions/projects (offline fallback)
- WebSocket metrics: Sliding window of 60 data points per metric in MetricsWebSocketClient

## Authentication & Identity

**Auth Provider:**
- Custom: Backend optional API key validation via `ILS_API_KEY` environment variable
- Implementation: `APIKeyMiddleware.swift` checks Authorization header (Bearer token)
- iOS/macOS implementation: APIClient actor manages API key in Keychain
- Biometric protection: Optional Face ID/Touch ID for Keychain access

**OAuth (Claude CLI):**
- Auth method: OAuth flow managed by Claude CLI
- Scope: Read/write access to Claude Code sessions
- Token storage: Managed by Claude CLI (typically ~/.config/claude/auth.json)
- App responsibility: Inherit auth from host environment (CLAUDECODE session or local Claude CLI auth)

**SSH Authentication (Citadel):**
- Methods: Password-based or SSH key (RSA/ECDSA/ED25519)
- Key storage: File path or raw key content
- Implementation: `CitadelSSHService.swift` parses and uses keys via Citadel library
- Purpose: Remote command execution on fleet hosts

## Monitoring & Observability

**Error Tracking:**
- None detected. Errors logged locally via AppLogger.swift

**Logs:**
- Local file logging only
- Framework: Standard OS log integration (not Sentry/Crash reporting)
- Location: iOS - `~/Library/Caches/com.ils.app/logs/`
- Rotation: Automatic when log file exceeds size limit
- Categories: Used for filtering (e.g., "sse", "keychain", "api", "chat")
- Files: `ILSApp/ILSApp/Services/AppLogger.swift`

**Metrics:**
- System metrics collected via backend SystemMetricsService
- Streamed to iOS/macOS via WebSocket at `/api/v1/metrics/stream`
- Metrics: CPU %, Memory %, Disk %, Network In/Out Mbps, process list
- Historical data: Last 60 data points kept in-memory for charting

## CI/CD & Deployment

**Hosting:**
- Backend: Runs as Swift executable on developer's machine (port 9999)
- Tunnel: Optional Cloudflare tunnel for remote access
- iOS: Apple App Store (code signing required)
- macOS: Apple App Store (hardened runtime, code signing required)

**CI Pipeline:**
- None detected in active use
- Fastlane directory present (`fastlane/`) but not configured
- Xcode Cloud possible but not active

**Build System:**
- Xcode 16.0 with XcodeGen (project.yml → .xcodeproj)
- Swift Package Manager for dependency resolution
- Schemes with pre/post-build actions for backend lifecycle management

## Environment Configuration

**Required env vars:**
- `PORT` - Backend port (default: 9999)
- `GITHUB_TOKEN` - GitHub API authentication (optional, needed for marketplace search)

**Optional env vars:**
- `ILS_CORS_ORIGINS` - CORS allowed origins (default: localhost:3000,8080,9999)
- `ILS_API_KEY` - Backend API key requirement (opt-in)
- `CLAUDECODE` - Set by Claude Code when running inside CC session (stripped by ClaudeExecutorService before subprocess spawn)

**Secrets location:**
- iOS/macOS: Keychain (`kSecClassGenericPassword`, service name: "com.ils.app")
- Backend: Environment variables only (no .env file support detected)
- Git: Credentials via git-credential-osxkeychain or SSH key auth

## Webhooks & Callbacks

**Incoming:**
- Not detected. No webhook endpoints observed.

**Outgoing:**
- Git clone operations: When installing plugins from marketplace
  - Endpoint: `https://github.com/<owner>/<repo>.git`
  - Method: `git clone` via FileSystemService
  - Purpose: Download plugin source code

**Server-Sent Events (SSE):**
- Endpoint: `POST /api/v1/chat/stream`
- Client: `SSEClient.swift` (streaming chat responses from Claude)
- Format: NDJSON (newline-delimited JSON)
- Timeout: 5 minutes initial, 10 minutes total

**WebSocket:**
- Endpoint: `wss://<host>:<port>/api/v1/metrics/stream` (converted from HTTPS)
- Client: `MetricsWebSocketClient.swift` (streaming system metrics)
- Fallback: REST polling if WebSocket fails 3+ times
- Purpose: Real-time CPU/memory/disk/network monitoring

---

*Integration audit: 2026-02-19*
