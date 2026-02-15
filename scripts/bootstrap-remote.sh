#!/bin/bash
# =============================================================================
# ILS Backend — Remote Bootstrap Script
# =============================================================================
#
# Downloads a pre-built ILS Backend binary and starts it on a remote server.
# Designed for non-interactive execution with machine-parseable output.
#
# Usage (from iOS app via SSH):
#   curl -sSL https://raw.githubusercontent.com/krzemienski/ils-ios/master/scripts/bootstrap-remote.sh | bash -s -- [OPTIONS]
#
# Options:
#   --port PORT         Backend port (default: 9999)
#   --no-tunnel         Skip Cloudflare tunnel setup
#   --repo URL          GitHub repository for releases (default: krzemienski/ils-ios)
#   --version TAG       Specific version tag (default: latest)
#   --install-dir DIR   Installation directory (default: ~/ils-backend)
#   --from-source       Build from source instead of downloading binary (fallback)
#   --branch BRANCH     Git branch for --from-source mode (default: master)
#
# Output markers (parsed by iOS app):
#   ILS_STEP:name:status:message     Step progress
#   ILS_TUNNEL_URL:https://...        Tunnel URL (final output)
#   ILS_BACKEND_URL:http://...        Direct backend URL
#   ILS_ERROR:message                 Fatal error
#   ILS_COMPLETE                      Setup finished successfully
# =============================================================================

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
BACKEND_PORT="${PORT:-9999}"
SETUP_TUNNEL=true
GITHUB_REPO="krzemienski/ils-ios"
VERSION_TAG="latest"
INSTALL_DIR="$HOME/ils-backend"
FROM_SOURCE=false
BRANCH="master"

# ── Parse Arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)        BACKEND_PORT="$2"; shift 2 ;;
        --no-tunnel)   SETUP_TUNNEL=false; shift ;;
        --repo)
            # Accept full URL or owner/repo format
            REPO_ARG="$2"
            if [[ "$REPO_ARG" == https://* ]]; then
                # Extract owner/repo from URL
                GITHUB_REPO=$(echo "$REPO_ARG" | sed -E 's|https://github.com/||; s|\.git$||')
            else
                GITHUB_REPO="$REPO_ARG"
            fi
            shift 2
            ;;
        --version)     VERSION_TAG="$2"; shift 2 ;;
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        --from-source) FROM_SOURCE=true; shift ;;
        --branch)      BRANCH="$2"; shift 2 ;;
        *)             shift ;;
    esac
done

# ── Output Helpers ───────────────────────────────────────────────────────────
# These markers are parsed by the iOS app via streaming SSH output.
step() {
    # Usage: step <name> <status> <message>
    # status: pending | in_progress | success | failure | skipped
    echo "ILS_STEP:$1:$2:$3"
}

emit_url() {
    echo "ILS_TUNNEL_URL:$1"
}

emit_backend_url() {
    echo "ILS_BACKEND_URL:$1"
}

emit_error() {
    echo "ILS_ERROR:$1"
}

emit_complete() {
    echo "ILS_COMPLETE"
}

# Also print human-readable output for debugging
log() {
    echo "[ILS] $1"
}

# ── Step 1: Detect Platform ──────────────────────────────────────────────────
step "detect_platform" "in_progress" "Detecting platform..."

PLATFORM="$(uname -s)"
ARCH="$(uname -m)"

# Normalize architecture names to match binary naming convention
case "$ARCH" in
    x86_64|amd64)   NORM_ARCH="amd64" ;;
    aarch64|arm64)   NORM_ARCH="arm64" ;;
    *)               NORM_ARCH="$ARCH" ;;
esac

case "$PLATFORM" in
    Linux)
        BINARY_SUFFIX="linux-${NORM_ARCH}"
        log "Platform: Linux ($ARCH → $BINARY_SUFFIX)"
        step "detect_platform" "success" "Linux ($ARCH)"
        ;;
    Darwin)
        BINARY_SUFFIX="darwin-${NORM_ARCH}"
        log "Platform: macOS ($ARCH → $BINARY_SUFFIX)"
        step "detect_platform" "success" "macOS ($ARCH)"
        ;;
    *)
        step "detect_platform" "failure" "Unsupported platform: $PLATFORM"
        emit_error "Unsupported platform: $PLATFORM. Only Linux and macOS are supported."
        exit 1
        ;;
esac

# ── Step 2: Check Dependencies ───────────────────────────────────────────────
step "install_dependencies" "in_progress" "Checking dependencies..."

HAS_CURL=false
HAS_CLOUDFLARED=false

command -v curl   &>/dev/null && HAS_CURL=true
command -v cloudflared &>/dev/null && HAS_CLOUDFLARED=true

if ! $HAS_CURL; then
    step "install_dependencies" "failure" "curl is not installed"
    emit_error "curl is required but not installed. Install with: apt install curl (Linux) or it should be pre-installed (macOS)"
    exit 1
fi

if $FROM_SOURCE; then
    # Source mode needs git and swift
    HAS_GIT=false
    HAS_SWIFT=false
    command -v git   &>/dev/null && HAS_GIT=true
    command -v swift &>/dev/null && HAS_SWIFT=true

    if ! $HAS_GIT; then
        step "install_dependencies" "failure" "git is not installed (required for --from-source)"
        emit_error "git is required for source builds. Install with: apt install git"
        exit 1
    fi
    if ! $HAS_SWIFT; then
        step "install_dependencies" "failure" "Swift is not installed (required for --from-source)"
        emit_error "Swift is required for source builds. Install from https://swift.org/install"
        exit 1
    fi

    DEPS_MSG="curl:ok git:ok swift:ok"
else
    DEPS_MSG="curl:ok"
fi

$HAS_CLOUDFLARED && DEPS_MSG="$DEPS_MSG cloudflared:ok"
step "install_dependencies" "success" "Dependencies OK ($DEPS_MSG)"

# ── Step 3: Download or Build Backend ─────────────────────────────────────────

if $FROM_SOURCE; then
    # ── Source Build Path ────────────────────────────────────────────────────
    SOURCE_DIR="$HOME/ils-ios"
    step "clone_repository" "in_progress" "Setting up repository..."

    REPO_URL="https://github.com/${GITHUB_REPO}.git"

    if [ -d "$SOURCE_DIR/.git" ]; then
        log "Repository exists at $SOURCE_DIR, updating..."
        cd "$SOURCE_DIR"
        git fetch origin "$BRANCH" 2>&1 || true
        git checkout "$BRANCH" 2>&1 || true
        git pull origin "$BRANCH" 2>&1 || true
        step "clone_repository" "success" "Repository updated ($BRANCH)"
    else
        log "Cloning repository to $SOURCE_DIR..."
        git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$SOURCE_DIR" 2>&1
        cd "$SOURCE_DIR"
        step "clone_repository" "success" "Repository cloned ($BRANCH)"
    fi

    step "build_backend" "in_progress" "Building backend from source..."
    log "Running: swift build -c release --product ILSBackend"
    if swift build -c release --product ILSBackend 2>&1; then
        BINARY_PATH="$(swift build -c release --show-bin-path)/ILSBackend"
        if [ -f "$BINARY_PATH" ]; then
            # Copy binary to install dir
            mkdir -p "$INSTALL_DIR"
            cp "$BINARY_PATH" "$INSTALL_DIR/ILSBackend"
            chmod +x "$INSTALL_DIR/ILSBackend"
            step "build_backend" "success" "Backend built from source"
        else
            step "build_backend" "failure" "Binary not found after build"
            emit_error "Swift build succeeded but binary not found at expected path"
            exit 1
        fi
    else
        step "build_backend" "failure" "Swift build failed"
        emit_error "swift build failed. Check Swift version compatibility."
        exit 1
    fi

else
    # ── Pre-built Binary Path (default) ──────────────────────────────────────
    step "clone_repository" "skipped" "Using pre-built binary (no clone needed)"

    step "build_backend" "in_progress" "Downloading pre-built backend binary..."

    mkdir -p "$INSTALL_DIR"
    BINARY_NAME="ILSBackend-${BINARY_SUFFIX}"

    if [ "$VERSION_TAG" = "latest" ]; then
        DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${BINARY_NAME}"
    else
        DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${VERSION_TAG}/${BINARY_NAME}"
    fi

    log "Downloading: $DOWNLOAD_URL"

    # Download binary using stdout redirect instead of curl's -o flag.
    # curl -o uses an internal write callback that fails with "client returned
    # ERROR on write" in certain SSH exec contexts (Citadel). Redirecting stdout
    # to a file uses bash's file descriptor handling which works reliably.
    CURL_ERR="$INSTALL_DIR/.curl-error"
    set +e
    curl -fsSL "$DOWNLOAD_URL" > "$INSTALL_DIR/ILSBackend" 2>"$CURL_ERR"
    CURL_EXIT=$?
    set -e

    if [ "$CURL_EXIT" -ne 0 ]; then
        step "build_backend" "failure" "Download failed (curl exit $CURL_EXIT)"
        log "URL: $DOWNLOAD_URL"
        [ -f "$CURL_ERR" ] && log "curl error: $(cat "$CURL_ERR")"
        log "Disk space: $(df -h "$INSTALL_DIR" 2>/dev/null | tail -1 || echo 'unknown')"
        rm -f "$CURL_ERR"
        if [ "$CURL_EXIT" -eq 22 ]; then
            emit_error "Binary not found (HTTP 404). Release may not exist for this platform ($BINARY_SUFFIX). Check https://github.com/${GITHUB_REPO}/releases"
        else
            emit_error "Failed to download binary (curl exit $CURL_EXIT). URL: $DOWNLOAD_URL"
        fi
        exit 1
    fi
    rm -f "$CURL_ERR"

    if [ -f "$INSTALL_DIR/ILSBackend" ] && [ -s "$INSTALL_DIR/ILSBackend" ]; then
        chmod +x "$INSTALL_DIR/ILSBackend"
        FILE_SIZE=$(stat -c%s "$INSTALL_DIR/ILSBackend" 2>/dev/null || stat -f%z "$INSTALL_DIR/ILSBackend" 2>/dev/null || echo "unknown")
        log "Binary downloaded: $FILE_SIZE bytes"
        step "build_backend" "success" "Binary downloaded ($FILE_SIZE bytes)"
    else
        step "build_backend" "failure" "Downloaded file is empty"
        log "URL: $DOWNLOAD_URL"
        emit_error "Downloaded binary is empty. Release may not exist for this platform. Try --from-source flag or check https://github.com/${GITHUB_REPO}/releases"
        exit 1
    fi
fi

# ── Step 4: Start Backend ────────────────────────────────────────────────────
step "start_backend" "in_progress" "Starting backend on port $BACKEND_PORT..."

# Kill any existing backend on that port
if command -v lsof &>/dev/null; then
    lsof -ti:"$BACKEND_PORT" 2>/dev/null | xargs kill -9 2>/dev/null || true
elif command -v fuser &>/dev/null; then
    fuser -k "$BACKEND_PORT/tcp" 2>/dev/null || true
fi
sleep 1

# Create state directory
STATE_DIR="$INSTALL_DIR/.state"
mkdir -p "$STATE_DIR"

cd "$INSTALL_DIR"
PORT="$BACKEND_PORT" nohup "$INSTALL_DIR/ILSBackend" > "$STATE_DIR/backend.log" 2>&1 &
BACKEND_PID=$!
echo "$BACKEND_PID" > "$STATE_DIR/backend.pid"
log "Backend started (PID: $BACKEND_PID)"

step "start_backend" "success" "Backend started (PID: $BACKEND_PID)"

# ── Step 5: Health Check ─────────────────────────────────────────────────────
step "health_check" "in_progress" "Waiting for backend to be ready..."

HEALTHY=false
for i in $(seq 1 30); do
    if curl -sf "http://localhost:$BACKEND_PORT/health" > /dev/null 2>&1; then
        HEALTHY=true
        break
    fi
    sleep 2
    log "Waiting for backend... ($i/30)"
done

if $HEALTHY; then
    step "health_check" "success" "Backend is healthy on port $BACKEND_PORT"
    emit_backend_url "http://localhost:$BACKEND_PORT"
else
    step "health_check" "failure" "Backend not responding after 60s"
    if [ -f "$STATE_DIR/backend.log" ]; then
        log "Last 10 lines of backend log:"
        tail -10 "$STATE_DIR/backend.log" 2>/dev/null || true
    fi
    emit_error "Backend failed to start. Check logs at $STATE_DIR/backend.log"
    exit 1
fi

# ── Step 6: Setup Tunnel ─────────────────────────────────────────────────────
if $SETUP_TUNNEL; then
    step "setup_tunnel" "in_progress" "Setting up Cloudflare tunnel..."

    if ! $HAS_CLOUDFLARED; then
        # Try to install cloudflared
        step "setup_tunnel" "in_progress" "Installing cloudflared..."
        INSTALLED_CF=false

        if [ "$PLATFORM" = "Linux" ]; then
            case "$ARCH" in
                x86_64|amd64)
                    CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
                    ;;
                aarch64|arm64)
                    CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
                    ;;
                armv7l|armhf)
                    CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm"
                    ;;
                *)
                    CF_URL=""
                    ;;
            esac

            if [ -n "${CF_URL:-}" ]; then
                CF_BIN="$HOME/.local/bin/cloudflared"
                mkdir -p "$HOME/.local/bin"
                if curl -sSL "$CF_URL" -o "$CF_BIN" && chmod +x "$CF_BIN"; then
                    export PATH="$HOME/.local/bin:$PATH"
                    INSTALLED_CF=true
                    log "cloudflared installed to $CF_BIN"
                fi
            fi
        elif [ "$PLATFORM" = "Darwin" ]; then
            if command -v brew &>/dev/null; then
                if brew install cloudflared 2>&1; then
                    INSTALLED_CF=true
                    log "cloudflared installed via Homebrew"
                fi
            fi
        fi

        if ! $INSTALLED_CF; then
            step "setup_tunnel" "skipped" "cloudflared not available and auto-install failed"
            log "Tunnel skipped. Backend accessible at http://localhost:$BACKEND_PORT"
            log "Install cloudflared manually: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
            # Still complete successfully — direct connection via SSH port forwarding is the fallback
            emit_complete
            exit 0
        fi
    fi

    # Start cloudflared tunnel
    TUNNEL_LOG="$STATE_DIR/cloudflare-tunnel.log"
    cloudflared tunnel --url "http://localhost:$BACKEND_PORT" --no-autoupdate > "$TUNNEL_LOG" 2>&1 &
    TUNNEL_PID=$!
    echo "$TUNNEL_PID" > "$STATE_DIR/cloudflare-tunnel.pid"
    log "cloudflared started (PID: $TUNNEL_PID)"

    # Wait for tunnel URL (up to 30 seconds)
    TUNNEL_URL=""
    for i in $(seq 1 30); do
        if [ -f "$TUNNEL_LOG" ]; then
            TUNNEL_URL=$(grep -oE "https://[a-zA-Z0-9-]+\.trycloudflare\.com" "$TUNNEL_LOG" 2>/dev/null | head -1)
            if [ -n "$TUNNEL_URL" ]; then
                break
            fi
        fi
        sleep 1
        log "Waiting for tunnel URL... ($i/30)"
    done

    if [ -n "$TUNNEL_URL" ]; then
        echo "$TUNNEL_URL" > "$STATE_DIR/tunnel-url.txt"
        step "setup_tunnel" "success" "Tunnel active: $TUNNEL_URL"
        emit_url "$TUNNEL_URL"
    else
        step "setup_tunnel" "failure" "Timed out waiting for tunnel URL"
        log "cloudflared may still be starting. Check logs: $TUNNEL_LOG"
        # Don't exit with error — backend is running, just tunnel failed
        emit_backend_url "http://localhost:$BACKEND_PORT"
    fi
else
    step "setup_tunnel" "skipped" "Tunnel not requested"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
emit_complete

log ""
log "============================================"
log "  ILS Backend is running!"
log "  Local:  http://localhost:$BACKEND_PORT"
if [ -n "${TUNNEL_URL:-}" ]; then
    log "  Tunnel: $TUNNEL_URL"
fi
log "  Binary: $INSTALL_DIR/ILSBackend"
log "  Logs:   $STATE_DIR/"
log "============================================"
log ""
log "To stop: kill \$(cat $STATE_DIR/backend.pid) && kill \$(cat $STATE_DIR/cloudflare-tunnel.pid 2>/dev/null) 2>/dev/null"
