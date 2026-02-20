#!/bin/bash
# Agent Preflight Check — Run before spawning observer/memory agent sessions
# Verifies authentication, connectivity, and environment readiness
# Usage: source scripts/agent-preflight.sh || exit 1
set -euo pipefail

MAX_RETRIES=3
RETRY_DELAY=10
LOG_FILE="${HOME}/.claude/agent-errors.log"
PROJECT_DIR="/Users/nick/Desktop/ils-ios"

log_error() {
    local msg="$1"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] PREFLIGHT FAIL: $msg" >> "$LOG_FILE"
    echo "PREFLIGHT FAIL: $msg" >&2
}

log_ok() {
    echo "PREFLIGHT OK: $1"
}

# 1. Check Claude CLI is available
if ! command -v claude &>/dev/null; then
    log_error "Claude CLI not found in PATH"
    exit 1
fi
log_ok "Claude CLI found"

# 2. Verify authentication with a lightweight call
AUTH_OK=false
for i in $(seq 1 $MAX_RETRIES); do
    if claude -p "echo ok" --allowedTools "" --max-turns 1 2>/dev/null | grep -q "ok"; then
        AUTH_OK=true
        break
    fi
    if [ $i -lt $MAX_RETRIES ]; then
        echo "Auth check failed (attempt $i/$MAX_RETRIES), retrying in ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
    fi
done

if [ "$AUTH_OK" != "true" ]; then
    log_error "Authentication failed after $MAX_RETRIES attempts — session $(date +%s)"
    echo ""
    echo "Observer/memory agent session BLOCKED."
    echo "Run '/login' manually or check API key configuration."
    echo "Error logged to: $LOG_FILE"
    exit 1
fi
log_ok "Authentication verified"

# 3. Check project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    log_error "Project directory not found: $PROJECT_DIR"
    exit 1
fi
log_ok "Project directory exists"

# 4. Check backend connectivity (optional — warn but don't block)
if curl -sf http://localhost:9999/health >/dev/null 2>&1; then
    log_ok "Backend healthy on port 9999"
else
    echo "WARNING: Backend not running on port 9999 (non-blocking)"
fi

# 5. Check simulator availability (optional — warn but don't block)
SIMULATOR_UDID="50523130-57AA-48B0-ABD0-4D59CE455F14"
if xcrun simctl list devices | grep -q "$SIMULATOR_UDID.*Booted"; then
    log_ok "Dedicated simulator booted"
else
    echo "WARNING: Dedicated simulator not booted (non-blocking)"
fi

echo ""
echo "All preflight checks passed. Agent session can proceed."
exit 0
