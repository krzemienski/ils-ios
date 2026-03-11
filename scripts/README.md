# ILS Scripts

Automation scripts for building, deploying, and testing the ILS backend.

---

## Overview

| Script | Purpose | When to Use |
|--------|---------|-------------|
| [`setup.sh`](#setupsh) | Verify prerequisites, build backend, run migrations | First-time setup on a new machine |
| [`install-backend-service.sh`](#install-backend-servicesh) | Install backend as a launchd/systemd service | When you want the backend to auto-start on login |
| [`bootstrap-remote.sh`](#bootstrap-remotesh) | Download and start backend on a remote server | Deploying to a remote Linux/macOS host via SSH |
| [`run_regression_tests.sh`](#run_regression_testssh) | Run the full iOS regression test suite | Before merging PRs or after major changes |
| [`reinstall-plugins.sh`](#reinstall-pluginssh) | Reinstall Claude Code plugins to local scope | When plugins appear disabled after updates |
| [`api-audit.sh`](#api-auditsh) | Test all API endpoints against the live backend | Verifying a backend deployment is healthy |
| [`extract-performance-metrics.sh`](#performance-scripts) | Extract performance metrics from xcresult bundles | After running regression tests |
| [`generate-performance-report.py`](#performance-scripts) | Generate HTML performance regression report | Comparing performance across builds |
| [`update-performance-baseline.sh`](#performance-scripts) | Update performance baseline from latest results | After confirming performance is acceptable |
| [`check-performance-regression.py`](#performance-scripts) | Check for performance regressions vs baseline | In CI before merging |
| [`sdk-wrapper.py`](#sdk-wrapperpy) | Python wrapper for Claude Agent SDK | Used by backend chat execution |

> **Note:** Run all scripts from the **repository root**, not from within `scripts/`.

---

## `setup.sh`

Performs a complete first-time environment check: validates Swift, Xcode, Node.js, and Claude CLI installations; builds the backend; and runs database migrations.

### Prerequisites

- macOS with Xcode installed (or Linux with Swift toolchain)
- Swift 6.0+

### Usage

```bash
./scripts/setup.sh
```

No arguments or options.

### Expected Output

```
ILS - Setup Script
===================

[OK] Swift found: swift-driver version: ...
[OK] Xcode found: Xcode 16.x.x
[WARN] Node.js not found. Optional — needed for Claude Agent SDK.
[WARN] Claude CLI not found. Optional — needed for full chat functionality.

Building backend...
[OK] Backend built successfully

Running database migrations...
  Waiting for backend to start... (1/30)
[OK] Backend started, migrations complete
[OK] Database created: ils.sqlite

=========================================
Setup complete!

Next steps:
  1. Start backend:  PORT=9999 swift run ILSBackend
  2. Open Xcode:     open ILSApp/ILSApp.xcodeproj
  3. Run iOS app:    Select 'ILSApp' scheme, Cmd+R
  4. Run macOS app:  Select 'ILSMacApp' scheme, Cmd+R
=========================================
```

### Notes

- `[WARN]` messages for Node.js and Claude CLI are non-fatal; those tools are optional.
- `[FAIL]` messages cause the script to exit with a non-zero code.
- The script temporarily starts the backend to run migrations, then shuts it down.

---

## `install-backend-service.sh`

Builds a release binary and registers it as a persistent background service. On macOS it creates a **launchd** LaunchAgent (`~/Library/LaunchAgents/com.ils.backend.plist`); on Linux it creates a **systemd** user unit (`~/.config/systemd/user/com.ils.backend.service`).

### Prerequisites

- Swift 6.0+ in PATH
- macOS or Linux (other platforms are unsupported)
- `sudo` is **not** required — the service is installed at user scope

### Usage

```bash
./scripts/install-backend-service.sh
```

No arguments or options.

### Expected Output

```
ILS Backend - Service Installer
================================

Building release binary...
[OK] Release binary built: .build/release/ILSBackend

# macOS output:
[OK] Installed launchd service: com.ils.backend

Manage with:
  Start:   launchctl load ~/Library/LaunchAgents/com.ils.backend.plist
  Stop:    launchctl unload ~/Library/LaunchAgents/com.ils.backend.plist
  Logs:    tail -f /tmp/ils-backend.log
  Remove:  launchctl unload ~/Library/LaunchAgents/com.ils.backend.plist && rm ~/Library/LaunchAgents/com.ils.backend.plist

Verifying service...
[OK] Backend is running on http://localhost:9999
```

### Managing the Service

**macOS (launchd):**
```bash
# Stop
launchctl unload ~/Library/LaunchAgents/com.ils.backend.plist

# Start
launchctl load ~/Library/LaunchAgents/com.ils.backend.plist

# View logs
tail -f /tmp/ils-backend.log
tail -f /tmp/ils-backend.error.log

# Remove permanently
launchctl unload ~/Library/LaunchAgents/com.ils.backend.plist
rm ~/Library/LaunchAgents/com.ils.backend.plist
```

**Linux (systemd):**
```bash
# Status
systemctl --user status com.ils.backend

# Stop
systemctl --user stop com.ils.backend

# View logs
journalctl --user -u com.ils.backend -f

# Remove permanently
systemctl --user disable com.ils.backend
rm ~/.config/systemd/user/com.ils.backend.service
```

### System Changes

> **Warning:** This script modifies your system's service manager.
>
> - **macOS:** Writes `~/Library/LaunchAgents/com.ils.backend.plist` and loads it immediately via `launchctl`. The service will auto-start at every login (`RunAtLoad: true`, `KeepAlive: true`).
> - **Linux:** Writes `~/.config/systemd/user/com.ils.backend.service`, runs `systemctl --user daemon-reload`, and enables + starts the unit. The service auto-restarts on failure.
> - Logs are written to `/tmp/ils-backend.log` and `/tmp/ils-backend.error.log` on macOS.
> - The service runs on **port 9999**. Ensure nothing else occupies this port.

---

## `bootstrap-remote.sh`

Downloads a pre-built ILS Backend binary (or builds from source) on a remote server and starts it, optionally setting up a Cloudflare tunnel for external access. Designed to be piped directly from `curl` for non-interactive execution.

### Prerequisites

- `curl` (required on the remote host)
- For `--from-source`: `git` and `swift` on the remote host
- For tunnel: `cloudflared` on the remote host, or a Cloudflare tunnel token

### Usage

```bash
# Run directly via curl (typical use from iOS app SSH deployment)
curl -sSL https://raw.githubusercontent.com/krzemienski/ils-ios/master/scripts/bootstrap-remote.sh \
  | bash -s -- [OPTIONS]

# Run locally
./scripts/bootstrap-remote.sh [OPTIONS]
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--port PORT` | `9999` | Backend listening port |
| `--no-tunnel` | *(tunnel enabled)* | Skip Cloudflare tunnel setup |
| `--repo URL` | `krzemienski/ils-ios` | GitHub repo (owner/repo or full URL) |
| `--version TAG` | `latest` | GitHub release tag to download |
| `--install-dir DIR` | `~/ils-backend` | Where to install the binary |
| `--from-source` | *(binary download)* | Build from source instead of downloading |
| `--branch BRANCH` | `master` | Git branch (used with `--from-source`) |
| `--cf-token TOKEN` | — | Cloudflare named tunnel token |
| `--tunnel-name NAME` | — | Informational tunnel name |
| `--domain DOMAIN` | — | Custom domain for named tunnel |

### Example Invocations

```bash
# Download latest binary, start on port 9999, set up quick tunnel
curl -sSL .../bootstrap-remote.sh | bash

# Build from source on the master branch, no tunnel
curl -sSL .../bootstrap-remote.sh | bash -s -- --from-source --no-tunnel

# Use a specific release and custom port
curl -sSL .../bootstrap-remote.sh | bash -s -- --version v1.2.0 --port 8888

# Named Cloudflare tunnel
curl -sSL .../bootstrap-remote.sh | bash -s -- \
  --cf-token eyJh... \
  --domain ils.example.com
```

### Output Markers

The script emits structured markers parsed by the iOS app:

| Marker | Meaning |
|--------|---------|
| `ILS_STEP:name:status:message` | Step progress (pending/in_progress/success/failure/skipped) |
| `ILS_TUNNEL_URL:https://...` | Public tunnel URL |
| `ILS_BACKEND_URL:http://...` | Direct backend URL |
| `ILS_ERROR:message` | Fatal error |
| `ILS_COMPLETE` | Setup finished successfully |

### Notes

- If a binary for the detected platform is not available on GitHub Releases, the script automatically falls back to `--from-source`.
- Supported platforms: Linux (amd64, arm64) and macOS (amd64, arm64).
- An existing installation is updated in-place without wiping data.

---

## `run_regression_tests.sh`

Starts the ILS backend (if not already running), then runs the full iOS UI regression test suite (`ILSAppUITests/RegressionTests`) via `xcodebuild` against a specific iPhone 16 Pro Max simulator. Generates an `.xcresult` bundle and a summary report.

### Prerequisites

- Xcode 16.0+ with iOS 18 SDK
- Simulator UDID `50523130-57AA-48B0-ABD0-4D59CE455F14` (iPhone 16 Pro Max, iOS 18.6) booted
- `xcpretty` installed (`gem install xcpretty`)
- `ILSFullStack.xcworkspace` present in the repository root
- Swift in PATH (to build/start the backend)

### Usage

```bash
./scripts/run_regression_tests.sh [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help message and exit |
| `-s N`, `--scenario N` | Run only scenario N (1–10) *(not yet implemented — runs all)* |
| `-k`, `--keep-backend` | Skip auto-starting the backend; fail if it is not already running |
| `-d NAME`, `--device NAME` | Use a different simulator by name (e.g. `"iPhone 14 Pro"`) |
| `-v`, `--verbose` | Enable verbose output |

### Example Invocations

```bash
# Run all regression tests (starts backend automatically)
./scripts/run_regression_tests.sh

# Use an already-running backend
./scripts/run_regression_tests.sh --keep-backend

# Run against a different simulator
./scripts/run_regression_tests.sh --device "iPhone 15 Pro"

# Run with verbose output
./scripts/run_regression_tests.sh -v
```

### Expected Output

```
[INFO] ═══════════════════════════════════
[INFO]   ILS iOS Regression Test Runner
[INFO] ═══════════════════════════════════

[INFO] Checking if backend is running...
[INFO] Starting ILS backend server...
[INFO] Building backend...
[INFO] Waiting for backend to be ready...
[SUCCESS] Backend is ready!

[INFO] Running regression tests...
...xcpretty output...

[SUCCESS] All tests passed! ✅

[INFO] ═══════════════════════════════════
[INFO]         TEST SUMMARY
[INFO] ═══════════════════════════════════
[SUCCESS] Passed: 42
[SUCCESS] Failed: 0
[INFO] ═══════════════════════════════════

[INFO] Test run complete!
[INFO] View results: open 'TestResults_20260228_120000.xcresult'
```

### Notes

- The `.xcresult` bundle is saved to the repository root with a timestamp suffix.
- A JSON summary is generated alongside the bundle if `xcresulttool` is available.
- The backend process started by this script is automatically stopped when the script exits (via `trap`).
- If the backend fails to start within 30 seconds, the script exits with code 1.

---

## `reinstall-plugins.sh`

Reinstalls Claude Code plugins from user scope to local project scope. Use this when plugins appear disabled in the ILS project despite being installed globally.

### Prerequisites

- `jq` (`brew install jq` on macOS)
- `claude` CLI in PATH
- `~/.claude/plugins/installed_plugins.json` exists (created by Claude Code)

### Usage

```bash
./scripts/reinstall-plugins.sh [MODE] [--dry-run]
```

### Modes

| Mode | Description |
|------|-------------|
| *(no args)* | Install all user-scope plugins to local project scope |
| `--list` | List all installed plugins with scope and version |
| `--enable-all` | Add `enabledPlugins` entries to `~/.claude/settings.json` |
| `--generate` | Print `claude plugin install` commands for manual use |
| `--priority` | Install only the 15 priority/essential plugins |
| `--dry-run` | Show what would be done without executing any changes |

### Example Invocations

```bash
# See what would be installed (safe, no changes)
./scripts/reinstall-plugins.sh --dry-run

# List all plugins and their scopes
./scripts/reinstall-plugins.sh --list

# Reinstall all plugins to local scope
./scripts/reinstall-plugins.sh

# Quick fix: just enable plugins in settings without reinstalling
./scripts/reinstall-plugins.sh --enable-all

# Install only the core priority plugins
./scripts/reinstall-plugins.sh --priority

# Generate commands for manual inspection
./scripts/reinstall-plugins.sh --generate
```

### Expected Output

```
========================================
  Claude Code Plugin Reinstallation
========================================

[INFO] Installing plugins to local scope for project: /path/to/ils-ios
[INFO] Found 23 user-scope plugins to install

[1/23] Installing oh-my-claudecode@omc... OK
[2/23] Installing superpowers@claude-plugins-official... OK
...
[OK] Installation complete: 22 succeeded, 1 failed
[WARN] Restart Claude Code for changes to take effect
```

### System Changes

> **Warning:** This script modifies Claude Code settings.
>
> - **`--enable-all`** overwrites `~/.claude/settings.json` with an updated `enabledPlugins` map. A timestamped backup is created automatically (e.g. `settings.json.backup.20260228_120000`).
> - **Default install mode** runs `claude plugin install ... --scope local` for each plugin, which writes to `.claude/settings.local.json` in the project directory.
> - **No network calls** are made by `--list`, `--generate`, or `--dry-run`.
> - A small 200ms delay is inserted between installs to avoid rate-limiting.

---

## `api-audit.sh`

Smoke-tests all API endpoints against a live backend at `http://localhost:9999`. Tests approximately 88 routes across Sessions, Projects, Chat, Skills, MCP, Plugins, Config, Stats, Themes, System, Tunnel, Teams, and Fleet, plus pagination and error-case verification.

### Prerequisites

- `curl` in PATH
- `python3` in PATH
- ILS backend running on port 9999 (`PORT=9999 swift run ILSBackend`)

### Usage

```bash
./scripts/api-audit.sh
```

No arguments or options. The script exits with code 0 if all tested endpoints pass, or code 1 if any fail.

### Example Invocations

```bash
# Start the backend, then run the audit
PORT=9999 swift run ILSBackend &
sleep 5
./scripts/api-audit.sh

# Run audit and save output to a file
./scripts/api-audit.sh | tee audit-results.txt

# Run audit and show only failures
./scripts/api-audit.sh | grep "✗"
```

### Expected Output

```
══════════════════════════════════════════
  HEALTH (no /api/v1 prefix)
══════════════════════════════════════════
  ✓ GET /health (HTTP 200, has 'status')
  ✓ GET /health/ready (HTTP 200, has 'status')
  ✓ GET /health/live (HTTP 200, has 'status')

══════════════════════════════════════════
  SESSIONS (/api/v1/sessions) — 14 routes
══════════════════════════════════════════
  ✓ GET /sessions (list) (HTTP 200, APIResponse wrapper OK)
  ...
  ⊘ GET /sessions/:id (no sessions in DB)

══════════════════════════════════════════
  AUDIT RESULTS SUMMARY
══════════════════════════════════════════
  Total endpoints tested: 72
  PASS: 65
  FAIL: 0
  SKIP: 7

✓ All tested endpoints PASSED. No 500 errors on valid requests.
```

### Output Symbols

| Symbol | Meaning |
|--------|---------|
| `✓` (green) | Endpoint responded with expected status code and structure |
| `✗` (red) | Endpoint failed or returned unexpected response |
| `⊘` (yellow) | Skipped — requires prerequisite data or would cause side effects |

### Notes

- **Read-only by default:** Destructive operations (plugin install/delete, tunnel start/stop, `PUT /config`) are skipped.
- **Creates and cleans up test data:** Sessions, projects, skills, MCP servers, themes, teams, and fleet hosts are created and immediately deleted as part of the audit.
- The script fails fast if the backend is not reachable before tests begin.
- WebSocket endpoints (`/chat/ws/:sessionId`, `/system/metrics/live`) are skipped and require a dedicated WebSocket client to test.

---

## Performance Scripts

Four scripts for tracking performance regressions across builds. Run after `run_regression_tests.sh`.

| Script | Purpose |
|--------|---------|
| `extract-performance-metrics.sh` | Extracts timing metrics from `.xcresult` bundles |
| `generate-performance-report.py` | Generates HTML report comparing current vs baseline |
| `update-performance-baseline.sh` | Saves current results as the new baseline |
| `check-performance-regression.py` | Exits non-zero if any metric regresses beyond threshold |

### Prerequisites

- `xcresulttool` (bundled with Xcode)
- `python3` in PATH
- A `.xcresult` bundle from `run_regression_tests.sh`

### Typical Workflow

```bash
# 1. Run regression tests (produces TestResults_*.xcresult)
./scripts/run_regression_tests.sh

# 2. Extract metrics
./scripts/extract-performance-metrics.sh TestResults_*.xcresult

# 3. Check for regressions vs baseline
python3 scripts/check-performance-regression.py

# 4. If acceptable, update the baseline
./scripts/update-performance-baseline.sh

# 5. Generate HTML report for review
python3 scripts/generate-performance-report.py
```

---

## `sdk-wrapper.py`

Python wrapper that invokes the Claude Agent SDK (`claude-agent-sdk`) for chat execution. Called by `ClaudeExecutorService` in the backend when processing chat requests.

### Prerequisites

- `claude-agent-sdk` pip package installed
- `claude` CLI configured with valid credentials

### Usage

Not intended for direct invocation. Called by the backend:

```bash
python3 scripts/sdk-wrapper.py --session-id <UUID> --prompt "<text>" [--project-id <UUID>]
```

### Output

Emits NDJSON to stdout, one event per line, parsed by `ClaudeExecutorService`:

```json
{"type": "assistant", "content": [...]}
{"type": "result", "usage": {...}, "cost": 0.0419}
```

### Notes

- Uses `include_partial_messages=True` for streaming
- Inherits Claude CLI OAuth auth — no `ANTHROPIC_API_KEY` required
- The backend strips `CLAUDECODE=1` and `CLAUDE_CODE_*` env vars before invocation to prevent nesting detection from blocking execution
