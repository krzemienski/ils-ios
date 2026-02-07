#!/bin/bash

# ILS Remote Access - Cloudflare Tunnel Setup
# This script:
# 1. Builds and starts the ILS backend
# 2. Sets up Cloudflare Tunnel
# 3. Manages both processes together

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_PORT=9090
PID_DIR="${PROJECT_DIR}/.remote-access"
BACKEND_PID_FILE="${PID_DIR}/backend.pid"
TUNNEL_PID_FILE="${PID_DIR}/cloudflare-tunnel.pid"
TUNNEL_CONFIG_FILE="${PID_DIR}/cloudflare-config.yml"
TUNNEL_URL_FILE="${PID_DIR}/tunnel-url.txt"

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up processes..."

    # Stop tunnel
    if [ -f "$TUNNEL_PID_FILE" ]; then
        TUNNEL_PID=$(cat "$TUNNEL_PID_FILE")
        if ps -p "$TUNNEL_PID" > /dev/null 2>&1; then
            log_info "Stopping Cloudflare tunnel (PID: $TUNNEL_PID)"
            kill "$TUNNEL_PID" 2>/dev/null || true
            sleep 2
            kill -9 "$TUNNEL_PID" 2>/dev/null || true
        fi
        rm -f "$TUNNEL_PID_FILE"
    fi

    # Stop backend
    if [ -f "$BACKEND_PID_FILE" ]; then
        BACKEND_PID=$(cat "$BACKEND_PID_FILE")
        if ps -p "$BACKEND_PID" > /dev/null 2>&1; then
            log_info "Stopping ILS backend (PID: $BACKEND_PID)"
            kill "$BACKEND_PID" 2>/dev/null || true
            sleep 2
            kill -9 "$BACKEND_PID" 2>/dev/null || true
        fi
        rm -f "$BACKEND_PID_FILE"
    fi
}

trap cleanup EXIT INT TERM

# Check if cloudflared is installed
check_cloudflared() {
    if ! command -v cloudflared &> /dev/null; then
        log_error "cloudflared is not installed"
        log_info "Install it with: brew install cloudflared"
        log_info "Or download from: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
        exit 1
    fi
    log_success "cloudflared is installed"
}

# Build backend
build_backend() {
    log_info "Building ILS backend..."
    cd "$PROJECT_DIR"

    if swift build --product ILSBackend; then
        log_success "Backend built successfully"
    else
        log_error "Backend build failed"
        exit 1
    fi
}

# Start backend
start_backend() {
    log_info "Starting ILS backend on port $BACKEND_PORT..."

    # Check if port is already in use
    if lsof -i :$BACKEND_PORT > /dev/null 2>&1; then
        log_warning "Port $BACKEND_PORT is already in use"
        log_info "Attempting to kill existing process..."
        lsof -ti :$BACKEND_PORT | xargs kill -9 2>/dev/null || true
        sleep 2
    fi

    # Start backend in background
    cd "$PROJECT_DIR"
    swift run ILSBackend > "${PID_DIR}/backend.log" 2>&1 &
    BACKEND_PID=$!
    echo "$BACKEND_PID" > "$BACKEND_PID_FILE"

    log_info "Backend started (PID: $BACKEND_PID)"
    log_info "Backend logs: ${PID_DIR}/backend.log"

    # Wait for backend to be ready
    log_info "Waiting for backend to be ready..."
    MAX_WAIT=30
    WAITED=0

    while [ $WAITED -lt $MAX_WAIT ]; do
        if curl -s -f http://localhost:$BACKEND_PORT/health > /dev/null 2>&1; then
            log_success "Backend is ready!"
            return 0
        fi
        sleep 1
        WAITED=$((WAITED + 1))
        echo -n "."
    done

    echo ""
    log_error "Backend failed to start within ${MAX_WAIT} seconds"
    log_info "Check logs: tail -f ${PID_DIR}/backend.log"
    exit 1
}

# Start Cloudflare tunnel
start_tunnel() {
    log_info "Starting Cloudflare tunnel..."

    # Create tunnel config
    cat > "$TUNNEL_CONFIG_FILE" << EOF
url: http://localhost:$BACKEND_PORT
metrics: localhost:2000
EOF

    # Start tunnel
    cloudflared tunnel --config "$TUNNEL_CONFIG_FILE" --url http://localhost:$BACKEND_PORT \
        > "${PID_DIR}/cloudflare-tunnel.log" 2>&1 &
    TUNNEL_PID=$!
    echo "$TUNNEL_PID" > "$TUNNEL_PID_FILE"

    log_info "Cloudflare tunnel started (PID: $TUNNEL_PID)"
    log_info "Tunnel logs: ${PID_DIR}/cloudflare-tunnel.log"

    # Wait for tunnel URL
    log_info "Waiting for tunnel URL..."
    sleep 5

    # Extract URL from logs
    if grep -q "https://" "${PID_DIR}/cloudflare-tunnel.log"; then
        TUNNEL_URL=$(grep "https://" "${PID_DIR}/cloudflare-tunnel.log" | grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" | head -1)

        if [ -n "$TUNNEL_URL" ]; then
            echo "$TUNNEL_URL" > "$TUNNEL_URL_FILE"
            log_success "Tunnel URL: $TUNNEL_URL"
            log_success "Your ILS backend is now accessible at: $TUNNEL_URL"
        else
            log_warning "Could not extract tunnel URL from logs"
            log_info "Check logs: tail -f ${PID_DIR}/cloudflare-tunnel.log"
        fi
    else
        log_warning "Tunnel URL not yet available"
        log_info "Check logs: tail -f ${PID_DIR}/cloudflare-tunnel.log"
    fi
}

# Monitor processes
monitor() {
    log_info "Monitoring backend and tunnel..."
    log_info "Press Ctrl+C to stop"
    echo ""

    # Display connection info
    if [ -f "$TUNNEL_URL_FILE" ]; then
        TUNNEL_URL=$(cat "$TUNNEL_URL_FILE")
        echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  ILS Backend Remote Access Active${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BLUE}Local URL:${NC}  http://localhost:$BACKEND_PORT"
        echo -e "  ${BLUE}Remote URL:${NC} $TUNNEL_URL"
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}Configure your iOS app with:${NC}"
        echo -e "  ${TUNNEL_URL}"
        echo ""
    fi

    # Monitor loop
    while true; do
        sleep 10

        # Check backend
        if [ -f "$BACKEND_PID_FILE" ]; then
            BACKEND_PID=$(cat "$BACKEND_PID_FILE")
            if ! ps -p "$BACKEND_PID" > /dev/null 2>&1; then
                log_error "Backend process died! Restarting..."
                start_backend
            fi
        fi

        # Check tunnel
        if [ -f "$TUNNEL_PID_FILE" ]; then
            TUNNEL_PID=$(cat "$TUNNEL_PID_FILE")
            if ! ps -p "$TUNNEL_PID" > /dev/null 2>&1; then
                log_error "Tunnel process died! Restarting..."
                start_tunnel
            fi
        fi

        # Health check
        if ! curl -s -f http://localhost:$BACKEND_PORT/health > /dev/null 2>&1; then
            log_warning "Backend health check failed"
        fi
    done
}

# Main execution
main() {
    log_info "═══════════════════════════════════════════════════"
    log_info "  ILS Remote Access - Cloudflare Tunnel Setup     "
    log_info "═══════════════════════════════════════════════════"
    echo ""

    # Create PID directory
    mkdir -p "$PID_DIR"

    # Check prerequisites
    check_cloudflared

    # Build backend
    build_backend

    # Start backend
    start_backend

    # Start tunnel
    start_tunnel

    # Monitor
    monitor
}

# Run main
main
