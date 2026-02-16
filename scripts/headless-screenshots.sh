#!/bin/bash
# Headless Screenshot Capture — Non-interactive multi-screen capture
# Usage: bash scripts/headless-screenshots.sh [output_dir]
set -euo pipefail

SIMULATOR="50523130-57AA-48B0-ABD0-4D59CE455F14"
OUTPUT_DIR="${1:-/tmp/screenshots-$(date +%Y%m%d-%H%M%S)}"
PROJECT_DIR="/Users/nick/Desktop/ils-ios"

mkdir -p "$OUTPUT_DIR"
echo "Saving screenshots to: $OUTPUT_DIR"

# Ensure simulator is booted
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
sleep 2

# Build and install latest
echo "Building iOS app..."
xcodebuild -project "$PROJECT_DIR/ILSApp/ILSApp.xcodeproj" \
    -scheme ILSApp \
    -destination "id=$SIMULATOR" \
    -quiet 2>&1 | tail -3

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app -maxdepth 0 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
    echo "ERROR: Could not find built app"
    exit 1
fi

echo "Installing app..."
xcrun simctl install "$SIMULATOR" "$APP_PATH"

# Launch app
xcrun simctl launch "$SIMULATOR" com.ils.app
sleep 3

capture() {
    local name="$1"
    local deep_link="${2:-}"

    if [ -n "$deep_link" ]; then
        xcrun simctl openurl "$SIMULATOR" "$deep_link"
        sleep 2
    fi

    xcrun simctl io "$SIMULATOR" screenshot "$OUTPUT_DIR/$name.png"
    echo "Captured: $name.png"
}

# Capture key screens via deep links
capture "01-home" "ils://home"
capture "02-sessions" "ils://sessions"
capture "03-settings" "ils://settings"
capture "04-system" "ils://system"
capture "05-browser" "ils://browser"

echo ""
echo "Done! $( ls "$OUTPUT_DIR"/*.png 2>/dev/null | wc -l ) screenshots captured."
echo "Output: $OUTPUT_DIR"
