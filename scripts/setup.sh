#!/bin/bash
set -e

echo "ILS - Setup Script"
echo "==================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# Check Swift
if command -v swift &> /dev/null; then
    SWIFT_VERSION=$(swift --version 2>&1 | head -1)
    ok "Swift found: $SWIFT_VERSION"
else
    fail "Swift not found. Install Xcode or Swift toolchain from https://swift.org"
fi

# Check Xcode (macOS only)
if [[ "$(uname)" == "Darwin" ]]; then
    if command -v xcodebuild &> /dev/null; then
        XCODE_VERSION=$(xcodebuild -version 2>&1 | head -1)
        ok "Xcode found: $XCODE_VERSION"
    else
        warn "Xcode not found. Required for iOS/macOS app builds."
        echo "  Install from: https://developer.apple.com/xcode/"
    fi
fi

# Check Node.js (optional, for Agent SDK)
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    ok "Node.js found: $NODE_VERSION (enables Agent SDK integration)"
else
    warn "Node.js not found. Optional — needed for Claude Agent SDK."
    echo "  Install from: https://nodejs.org"
fi

# Check Claude CLI (optional)
if command -v claude &> /dev/null; then
    ok "Claude CLI found"
else
    warn "Claude CLI not found. Optional — needed for full chat functionality."
    echo "  Install from: https://docs.anthropic.com/en/docs/claude-code"
fi

echo ""
echo "Building backend..."
cd "$(dirname "$0")/.."
swift build 2>&1 | tail -5

if [ $? -eq 0 ]; then
    ok "Backend built successfully"
else
    fail "Backend build failed. Check errors above."
fi

echo ""
echo "Running database migrations..."
PORT=9999 swift run ILSBackend &
BACKEND_PID=$!
sleep 8
kill $BACKEND_PID 2>/dev/null || true
wait $BACKEND_PID 2>/dev/null || true

if [ -f "ils.sqlite" ]; then
    ok "Database created: ils.sqlite"
else
    warn "Database file not found — it will be created on first run"
fi

echo ""
echo "========================================="
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Start backend:  PORT=9999 swift run ILSBackend"
echo "  2. Open Xcode:     open ILSApp/ILSApp.xcodeproj"
echo "  3. Run iOS app:    Select 'ILSApp' scheme, Cmd+R"
echo "  4. Run macOS app:  Select 'ILSMacApp' scheme, Cmd+R"
echo "========================================="
