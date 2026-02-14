#!/bin/bash
# =============================================================================
# ILS Backend — Remote Bootstrap Script
# =============================================================================
#
# Downloads from raw GitHub and executes on a remote server via SSH.
# Designed for non-interactive execution with machine-parseable output.
#
# Usage (from iOS app via SSH):
#   curl -sSL https://raw.githubusercontent.com/krzemienski/ils-ios/master/scripts/bootstrap-remote.sh | bash -s -- [OPTIONS]
#
# Options:
#   --port PORT         Backend port (default: 9999)
#   --docker            Force Docker mode (default: auto-detect)
#   --native            Force native Swift mode (default: auto-detect)
#   --no-tunnel         Skip Cloudflare tunnel setup
#   --repo URL          Custom repository URL
#   --branch BRANCH     Git branch to use (default: master)
#   --install-dir DIR   Installation directory (default: ~/ils-ios)
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
BUILD_MODE="auto"  # auto, docker, native
SETUP_TUNNEL=true
REPO_URL="https://github.com/krzemienski/ils-ios.git"
BRANCH="master"
INSTALL_DIR="$HOME/ils-ios"

# ── Parse Arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)       BACKEND_PORT="$2"; shift 2 ;;
        --docker)     BUILD_MODE="docker"; shift ;;
        --native)     BUILD_MODE="native"; shift ;;
        --no-tunnel)  SETUP_TUNNEL=false; shift ;;
        --repo)       REPO_URL="$2"; shift 2 ;;
        --branch)     BRANCH="$2"; shift 2 ;;
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        *)            shift ;;
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

case "$PLATFORM" in
    Linux)
        log "Platform: Linux ($ARCH)"
        step "detect_platform" "success" "Linux ($ARCH)"
        ;;
    Darwin)
        log "Platform: macOS ($ARCH)"
        step "detect_platform" "success" "macOS ($ARCH)"
        ;;
    *)
        step "detect_platform" "failure" "Unsupported platform: $PLATFORM"
        emit_error "Unsupported platform: $PLATFORM. Only Linux and macOS are supported."
        exit 1
        ;;
esac

# ── Step 2: Check Dependencies & Decide Build Mode ──────────────────────────
step "install_dependencies" "in_progress" "Checking dependencies..."

HAS_SWIFT=false
HAS_DOCKER=false
HAS_GIT=false
HAS_CURL=false
HAS_CLOUDFLARED=false

command -v git    &>/dev/null && HAS_GIT=true
command -v curl   &>/dev/null && HAS_CURL=true
command -v swift  &>/dev/null && HAS_SWIFT=true
command -v docker &>/dev/null && HAS_DOCKER=true
command -v cloudflared &>/dev/null && HAS_CLOUDFLARED=true

if ! $HAS_GIT; then
    step "install_dependencies" "failure" "git is not installed"
    emit_error "git is required but not installed. Install with: apt install git (Linux) or xcode-select --install (macOS)"
    exit 1
fi

if ! $HAS_CURL; then
    step "install_dependencies" "failure" "curl is not installed"
    emit_error "curl is required but not installed. Install with: apt install curl"
    exit 1
fi

# Auto-detect build mode
if [ "$BUILD_MODE" = "auto" ]; then
    if $HAS_SWIFT; then
        BUILD_MODE="native"
        log "Auto-detected: native Swift build"
    elif $HAS_DOCKER; then
        BUILD_MODE="docker"
        log "Auto-detected: Docker build (Swift not found)"
    else
        step "install_dependencies" "failure" "Neither Swift nor Docker found"
        emit_error "Neither Swift nor Docker is installed. Install Swift (https://swift.org/install) or Docker (https://docs.docker.com/engine/install/)."
        exit 1
    fi
fi

# Validate chosen mode
if [ "$BUILD_MODE" = "native" ] && ! $HAS_SWIFT; then
    step "install_dependencies" "failure" "Swift not installed (required for native mode)"
    emit_error "Swift is not installed. Install from https://swift.org/install or use --docker flag."
    exit 1
fi

if [ "$BUILD_MODE" = "docker" ] && ! $HAS_DOCKER; then
    step "install_dependencies" "failure" "Docker not installed (required for docker mode)"
    emit_error "Docker is not installed. Install from https://docs.docker.com/engine/install/ or use --native flag."
    exit 1
fi

DEPS_MSG="git:ok"
$HAS_SWIFT && DEPS_MSG="$DEPS_MSG swift:ok"
$HAS_DOCKER && DEPS_MSG="$DEPS_MSG docker:ok"
$HAS_CLOUDFLARED && DEPS_MSG="$DEPS_MSG cloudflared:ok"
step "install_dependencies" "success" "Dependencies OK ($DEPS_MSG) — mode: $BUILD_MODE"

# ── Step 3: Clone or Update Repository ───────────────────────────────────────
step "clone_repository" "in_progress" "Setting up repository..."

if [ -d "$INSTALL_DIR/.git" ]; then
    log "Repository exists at $INSTALL_DIR, updating..."
    cd "$INSTALL_DIR"
    git fetch origin "$BRANCH" 2>&1 || true
    git checkout "$BRANCH" 2>&1 || true
    git pull origin "$BRANCH" 2>&1 || true
    step "clone_repository" "success" "Repository updated ($BRANCH)"
else
    log "Cloning repository to $INSTALL_DIR..."
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>&1
    cd "$INSTALL_DIR"
    step "clone_repository" "success" "Repository cloned ($BRANCH)"
fi

# ── Step 4: Build Backend ────────────────────────────────────────────────────
step "build_backend" "in_progress" "Building backend ($BUILD_MODE mode)..."

if [ "$BUILD_MODE" = "native" ]; then
    # Native Swift build
    log "Running: swift build -c release --product ILSBackend"
    if swift build -c release --product ILSBackend 2>&1; then
        BINARY_PATH="$(swift build -c release --show-bin-path)/ILSBackend"
        if [ -f "$BINARY_PATH" ]; then
            step "build_backend" "success" "Backend built successfully (native)"
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

elif [ "$BUILD_MODE" = "docker" ]; then
    # Docker build
    log "Building Docker image..."

    # Create a Dockerfile if one doesn't exist
    if [ ! -f "$INSTALL_DIR/Dockerfile.backend" ]; then
        cat > "$INSTALL_DIR/Dockerfile.backend" << 'DOCKERFILE'
FROM swift:6.0 AS builder
WORKDIR /app
COPY Package.swift Package.resolved ./
COPY Sources/ Sources/
RUN swift build -c release --product ILSBackend

FROM swift:6.0-slim
WORKDIR /app
COPY --from=builder /app/.build/release/ILSBackend /app/ILSBackend
COPY --from=builder /app/.build/release/ /app/.build/release/
EXPOSE 9999
ENV PORT=9999
CMD ["/app/ILSBackend"]
DOCKERFILE
    fi

    if docker build -f "$INSTALL_DIR/Dockerfile.backend" -t ils-backend:latest "$INSTALL_DIR" 2>&1; then
        step "build_backend" "success" "Docker image built successfully"
    else
        step "build_backend" "failure" "Docker build failed"
        emit_error "Docker build failed. Check Dockerfile and Swift version."
        exit 1
    fi
fi

# ── Step 5: Start Backend ────────────────────────────────────────────────────
step "start_backend" "in_progress" "Starting backend on port $BACKEND_PORT..."

# Kill any existing backend on that port
if command -v lsof &>/dev/null; then
    lsof -ti:"$BACKEND_PORT" 2>/dev/null | xargs kill -9 2>/dev/null || true
elif command -v fuser &>/dev/null; then
    fuser -k "$BACKEND_PORT/tcp" 2>/dev/null || true
fi
sleep 1

# Create log/pid directory
STATE_DIR="$INSTALL_DIR/.remote-access"
mkdir -p "$STATE_DIR"

if [ "$BUILD_MODE" = "native" ]; then
    cd "$INSTALL_DIR"
    PORT="$BACKEND_PORT" nohup "$BINARY_PATH" > "$STATE_DIR/backend.log" 2>&1 &
    BACKEND_PID=$!
    echo "$BACKEND_PID" > "$STATE_DIR/backend.pid"
    log "Backend started (PID: $BACKEND_PID)"

elif [ "$BUILD_MODE" = "docker" ]; then
    # Stop existing container if running
    docker stop ils-backend 2>/dev/null || true
    docker rm ils-backend 2>/dev/null || true

    docker run -d \
        --name ils-backend \
        -p "$BACKEND_PORT:$BACKEND_PORT" \
        -v "$INSTALL_DIR/ils.sqlite:/app/ils.sqlite" \
        -e "PORT=$BACKEND_PORT" \
        ils-backend:latest > "$STATE_DIR/docker-container-id.txt" 2>&1
    log "Docker container started"
fi

# ── Step 6: Health Check ─────────────────────────────────────────────────────
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

# ── Step 7: Setup Tunnel ─────────────────────────────────────────────────────
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
log "  Mode:   $BUILD_MODE"
log "  Logs:   $STATE_DIR/"
log "============================================"
log ""
log "To stop: kill \$(cat $STATE_DIR/backend.pid) && kill \$(cat $STATE_DIR/cloudflare-tunnel.pid 2>/dev/null) 2>/dev/null"
