#!/bin/bash
# Headless Build Validation — Non-interactive build check for iOS, macOS, and backend
# Usage: bash scripts/headless-build.sh [ios|macos|backend|all]
set -euo pipefail

PROJECT_DIR="/Users/nick/Desktop/ils-ios"
TARGET="${1:-all}"
FAILURES=0

build_ios() {
    echo "=== iOS Build ==="
    if xcodebuild -project "$PROJECT_DIR/ILSApp/ILSApp.xcodeproj" \
        -scheme ILSApp \
        -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' \
        -quiet 2>&1 | tail -5; then
        echo "iOS: PASS"
    else
        echo "iOS: FAIL"
        FAILURES=$((FAILURES + 1))
    fi
}

build_macos() {
    echo "=== macOS Build ==="
    if xcodebuild -project "$PROJECT_DIR/ILSApp/ILSApp.xcodeproj" \
        -scheme ILSMacApp \
        -destination 'platform=macOS' \
        -quiet 2>&1 | tail -5; then
        echo "macOS: PASS"
    else
        echo "macOS: FAIL"
        FAILURES=$((FAILURES + 1))
    fi
}

build_backend() {
    echo "=== Backend Build ==="
    cd "$PROJECT_DIR"
    if swift build 2>&1 | tail -5; then
        echo "Backend: PASS"
    else
        echo "Backend: FAIL"
        FAILURES=$((FAILURES + 1))
    fi
}

case "$TARGET" in
    ios)     build_ios ;;
    macos)   build_macos ;;
    backend) build_backend ;;
    all)
        build_ios
        echo ""
        build_macos
        echo ""
        build_backend
        ;;
    *)
        echo "Usage: $0 [ios|macos|backend|all]"
        exit 1
        ;;
esac

echo ""
if [ $FAILURES -eq 0 ]; then
    echo "All builds PASSED"
    exit 0
else
    echo "$FAILURES build(s) FAILED"
    exit 1
fi
