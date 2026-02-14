#!/bin/bash

# ILS Remote Access - Tailscale Setup
# This script:
# 1. Builds and starts the ILS backend
# 2. Ensures Tailscale is running
# 3. Provides Tailscale IP for remote access

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_PORT="${PORT:-9999}"
PID_DIR="${PROJECT_DIR}/.remote-access"
BACKEND_PID_FILE="${PID_DIR}/backend.pid"
TAILSCALE_IP_FILE="${PID_DIR}/tailscale-ip.txt"

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
    log_info "Cleaning up..."

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

# Check if Tailscale is installed
check_tailscale() {
    if ! command -v tailscale &> /dev/null; then
        log_error "Tailscale is not installed"
        log_info "Install it with: brew install --cask tailscale"
        log_info "Or download from: https://tailscale.com/download"
        exit 1
    fi
    log_success "Tailscale is installed"
}

# Check Tailscale status
check_tailscale_status() {
    log_info "Checking Tailscale status..."

    if ! tailscale status > /dev/null 2>&1; then
        log_error "Tailscale is not running or not authenticated"
        log_info "Starting Tailscale..."

        # Try to start Tailscale (macOS)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open -a Tailscale
            log_info "Tailscale app opened. Please authenticate if needed."
            sleep 5
        fi

        # Check again
        if ! tailscale status > /dev/null 2>&1; then
            log_error "Tailscale is still not running"
            log_info "Please start Tailscale and authenticate, then run this script again"
            exit 1
        fi
    fi

    log_success "Tailscale is running"
}

# Get Tailscale IP
get_tailscale_ip() {
    log_info "Getting Tailscale IP address..."

    TAILSCALE_IP=$(tailscale ip -4)

    if [ -z "$TAILSCALE_IP" ]; then
        log_error "Could not get Tailscale IP"
        exit 1
    fi

    echo "$TAILSCALE_IP" > "$TAILSCALE_IP_FILE"
    log_success "Tailscale IP: $TAILSCALE_IP"
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

# Display connection info
display_info() {
    TAILSCALE_IP=$(cat "$TAILSCALE_IP_FILE")
    TAILSCALE_URL="http://${TAILSCALE_IP}:${BACKEND_PORT}"

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ILS Backend Remote Access Active (Tailscale)${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BLUE}Local URL:${NC}       http://localhost:$BACKEND_PORT"
    echo -e "  ${BLUE}Tailscale URL:${NC}   $TAILSCALE_URL"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Configure your iOS app with:${NC}"
    echo -e "  ${TAILSCALE_URL}"
    echo ""
    echo -e "${BLUE}Note:${NC} This URL works on any device connected to your Tailscale network"
    echo ""
    echo -e "${BLUE}Tailscale Network Status:${NC}"
    tailscale status | head -5
    echo ""
}

# Monitor processes
monitor() {
    log_info "Monitoring backend..."
    log_info "Press Ctrl+C to stop"
    echo ""

    display_info

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

        # Health check
        if ! curl -s -f http://localhost:$BACKEND_PORT/health > /dev/null 2>&1; then
            log_warning "Backend health check failed"
        fi

        # Check Tailscale
        if ! tailscale status > /dev/null 2>&1; then
            log_warning "Tailscale connection lost"
        fi
    done
}

# Main execution
main() {
    log_info "═══════════════════════════════════════════════════"
    log_info "  ILS Remote Access - Tailscale Setup              "
    log_info "═══════════════════════════════════════════════════"
    echo ""

    # Create PID directory
    mkdir -p "$PID_DIR"

    # Check prerequisites
    check_tailscale
    check_tailscale_status

    # Get Tailscale IP
    get_tailscale_ip

    # Build backend
    build_backend

    # Start backend
    start_backend

    # Monitor
    monitor
}

# Run main
main
