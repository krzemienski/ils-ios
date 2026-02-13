#!/bin/bash
set -e

echo "ILS Backend - Service Installer"
echo "================================"
echo ""

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_NAME="com.ils.backend"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# Build release binary
echo "Building release binary..."
cd "$PROJECT_DIR"
swift build -c release 2>&1 | tail -3

# Detect actual binary path (handles arm64-apple-macosx on Apple Silicon)
BINARY_PATH=$(swift build -c release --show-bin-path)/ILSBackend
if [ ! -f "$BINARY_PATH" ]; then
    fail "Release binary not found at $BINARY_PATH"
fi
ok "Release binary built: $BINARY_PATH"

if [[ "$(uname)" == "Darwin" ]]; then
    # macOS: launchd
    PLIST_PATH="$HOME/Library/LaunchAgents/${SERVICE_NAME}.plist"

    # Unload existing if present
    launchctl unload "$PLIST_PATH" 2>/dev/null || true

    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${SERVICE_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BINARY_PATH}</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${PROJECT_DIR}</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PORT</key>
        <string>9999</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/ils-backend.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ils-backend.error.log</string>
</dict>
</plist>
EOF

    launchctl load "$PLIST_PATH"
    ok "Installed launchd service: $SERVICE_NAME"
    echo ""
    echo "Manage with:"
    echo "  Start:   launchctl load $PLIST_PATH"
    echo "  Stop:    launchctl unload $PLIST_PATH"
    echo "  Logs:    tail -f /tmp/ils-backend.log"
    echo "  Remove:  launchctl unload $PLIST_PATH && rm $PLIST_PATH"

elif [[ "$(uname)" == "Linux" ]]; then
    # Linux: systemd
    UNIT_PATH="$HOME/.config/systemd/user/${SERVICE_NAME}.service"
    mkdir -p "$(dirname "$UNIT_PATH")"

    cat > "$UNIT_PATH" << EOF
[Unit]
Description=ILS Backend Server
After=network.target

[Service]
Type=simple
WorkingDirectory=${PROJECT_DIR}
ExecStart=${BINARY_PATH}
Environment=PORT=9999
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME"
    systemctl --user start "$SERVICE_NAME"
    ok "Installed systemd user service: $SERVICE_NAME"
    echo ""
    echo "Manage with:"
    echo "  Status:  systemctl --user status $SERVICE_NAME"
    echo "  Stop:    systemctl --user stop $SERVICE_NAME"
    echo "  Logs:    journalctl --user -u $SERVICE_NAME -f"
    echo "  Remove:  systemctl --user disable $SERVICE_NAME && rm $UNIT_PATH"

else
    fail "Unsupported platform: $(uname)"
fi

# Verify
echo ""
echo "Verifying service..."
SERVICE_OK=false
for i in $(seq 1 15); do
    if curl -sf http://localhost:9999/health > /dev/null 2>&1; then
        ok "Backend is running on http://localhost:9999"
        SERVICE_OK=true
        break
    fi
    echo "  Waiting for backend... ($i/15)"
    sleep 2
done

if [ "$SERVICE_OK" = false ]; then
    warn "Backend not responding after 30s. Check logs: tail -f /tmp/ils-backend.log"
fi
