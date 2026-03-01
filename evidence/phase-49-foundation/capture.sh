#!/bin/bash
# Phase 49 Foundation — Evidence Capture Script
# Captures numbered screenshot artifacts proving Fleet→HostProfile rename is complete.
# Run from repository root: bash evidence/phase-49-foundation/capture.sh

set -e

SIMULATOR_UDID="50523130-57AA-48B0-ABD0-4D59CE455F14"
OUT_DIR="evidence/phase-49-foundation"
APP_BUNDLE="com.ils.app"

mkdir -p "$OUT_DIR"

echo "==> Booting simulator..."
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
sleep 2

echo "==> Finding latest ILSApp.app build..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ILSApp.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
  echo "ERROR: ILSApp.app not found in DerivedData. Run a build first."
  exit 1
fi

echo "==> Installing app from: $APP_PATH"
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE"
sleep 3

echo "==> Capturing 01 — app home screen..."
xcrun simctl io "$SIMULATOR_UDID" screenshot "$OUT_DIR/01-app-home.png"

echo "==> Navigating to Host Profiles via deep link (new: ils://host-profiles)..."
xcrun simctl openurl "$SIMULATOR_UDID" "ils://host-profiles"
sleep 1
xcrun simctl io "$SIMULATOR_UDID" screenshot "$OUT_DIR/02-host-profiles-via-new-deeplink.png"

echo "==> Navigating via legacy deep link (backward compat: ils://fleet)..."
xcrun simctl openurl "$SIMULATOR_UDID" "ils://fleet"
sleep 1
xcrun simctl io "$SIMULATOR_UDID" screenshot "$OUT_DIR/03-host-profiles-via-fleet-deeplink.png"

echo ""
echo "Evidence captured to $OUT_DIR/:"
ls -1 "$OUT_DIR/"*.png 2>/dev/null || echo "(no .png files yet)"
echo ""
echo "NEXT: Run backend and capture API evidence with:"
echo "  curl -s http://localhost:9999/api/v1/host-profiles | python3 -m json.tool > $OUT_DIR/04-api-host-profiles-response.json"
echo "  curl -s http://localhost:9999/api/v1/fleet | python3 -m json.tool > $OUT_DIR/05-api-fleet-alias-response.json"
