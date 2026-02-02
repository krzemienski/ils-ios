#!/bin/bash
set -e

# ILS iOS App UI Test Runner
# Runs E2E tests using the configured Xcode Test Plan

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="ILSApp"
TEST_PLAN="ILSApp.xctestplan"
RESULTS_DIR="${PROJECT_DIR}/test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Default values
CONFIGURATION="Default Configuration"
DEVICE="iPhone 15 Pro"
OS_VERSION="latest"
PARALLEL=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run ILS iOS App UI Tests

OPTIONS:
    -c, --config NAME       Test configuration to run (default: "Default Configuration")
                           Options: "Default Configuration", "Quick Smoke Tests",
                                   "Full Regression", "Localization Testing - German",
                                   "Localization Testing - Japanese",
                                   "Localization Testing - Arabic (RTL)"
    -q, --quick            Run quick smoke tests (5 essential tests)
    -f, --full             Run full regression suite with retries
    -d, --device DEVICE    Device to test on (default: "iPhone 15 Pro")
    -o, --output DIR       Custom output directory (default: test-results)
    -p, --parallel         Enable parallel test execution
    -v, --verbose          Verbose output
    -h, --help             Show this help message

EXAMPLES:
    # Run quick smoke tests
    $0 --quick

    # Run full regression suite
    $0 --full

    # Run on specific device
    $0 --device "iPad Pro (12.9-inch) (6th generation)"

    # Run with parallel execution
    $0 --parallel --full

    # Run localization tests
    $0 --config "Localization Testing - German"

EOF
    exit 1
}

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIGURATION="$2"
            shift 2
            ;;
        -q|--quick)
            CONFIGURATION="Quick Smoke Tests"
            shift
            ;;
        -f|--full)
            CONFIGURATION="Full Regression"
            shift
            ;;
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -o|--output)
            RESULTS_DIR="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_msg "$RED" "Unknown option: $1"
            usage
            ;;
    esac
done

# Create results directory
mkdir -p "$RESULTS_DIR"
RESULT_BUNDLE="${RESULTS_DIR}/TestResults_${TIMESTAMP}.xcresult"

# Print configuration
print_msg "$BLUE" "========================================"
print_msg "$BLUE" "ILS iOS App UI Test Runner"
print_msg "$BLUE" "========================================"
echo "Configuration: $CONFIGURATION"
echo "Device: $DEVICE"
echo "Results: $RESULT_BUNDLE"
echo "Parallel: $PARALLEL"
echo ""

# Build xcodebuild command
XCODEBUILD_CMD="xcodebuild test"
XCODEBUILD_CMD="$XCODEBUILD_CMD -project \"${PROJECT_DIR}/ILSApp.xcodeproj\""
XCODEBUILD_CMD="$XCODEBUILD_CMD -scheme \"$SCHEME\""
XCODEBUILD_CMD="$XCODEBUILD_CMD -testPlan \"$TEST_PLAN\""
XCODEBUILD_CMD="$XCODEBUILD_CMD -destination \"platform=iOS Simulator,name=$DEVICE\""
XCODEBUILD_CMD="$XCODEBUILD_CMD -resultBundlePath \"$RESULT_BUNDLE\""
XCODEBUILD_CMD="$XCODEBUILD_CMD -only-testing-configuration \"$CONFIGURATION\""

# Add parallel execution if requested
if [ "$PARALLEL" = true ]; then
    XCODEBUILD_CMD="$XCODEBUILD_CMD -parallel-testing-enabled YES"
    XCODEBUILD_CMD="$XCODEBUILD_CMD -maximum-parallel-testing-workers auto"
fi

# Add quiet flag if not verbose
if [ "$VERBOSE" = false ]; then
    XCODEBUILD_CMD="$XCODEBUILD_CMD -quiet"
fi

# Print command if verbose
if [ "$VERBOSE" = true ]; then
    print_msg "$YELLOW" "Running command:"
    echo "$XCODEBUILD_CMD"
    echo ""
fi

# Run tests
print_msg "$BLUE" "Starting tests..."
echo ""

# Execute the command
if eval $XCODEBUILD_CMD; then
    print_msg "$GREEN" "✓ All tests passed!"
    EXIT_CODE=0
else
    print_msg "$RED" "✗ Some tests failed"
    EXIT_CODE=1
fi

echo ""
print_msg "$BLUE" "========================================"
print_msg "$BLUE" "Test Results Summary"
print_msg "$BLUE" "========================================"

# Extract test summary using xcresulttool
if command -v xcrun &> /dev/null; then
    echo "Extracting test results..."
    xcrun xcresulttool get --format json --path "$RESULT_BUNDLE" > "${RESULTS_DIR}/summary_${TIMESTAMP}.json" 2>/dev/null || true

    # Try to extract human-readable summary
    if [ -f "${RESULTS_DIR}/summary_${TIMESTAMP}.json" ]; then
        print_msg "$BLUE" "Detailed results saved to: ${RESULTS_DIR}/summary_${TIMESTAMP}.json"
    fi
fi

# Print result bundle location
echo ""
print_msg "$BLUE" "Result Bundle: $RESULT_BUNDLE"
print_msg "$BLUE" "Open with: open \"$RESULT_BUNDLE\""
echo ""

# Export screenshots if available
SCREENSHOTS_DIR="${RESULTS_DIR}/screenshots_${TIMESTAMP}"
if [ -d "$RESULT_BUNDLE" ]; then
    print_msg "$BLUE" "Exporting screenshots..."
    mkdir -p "$SCREENSHOTS_DIR"

    # Extract screenshots using xcresulttool
    xcrun xcresulttool export --type directory --path "$RESULT_BUNDLE" --output-path "$SCREENSHOTS_DIR" 2>/dev/null || true

    if [ "$(ls -A "$SCREENSHOTS_DIR" 2>/dev/null)" ]; then
        print_msg "$GREEN" "Screenshots exported to: $SCREENSHOTS_DIR"
    else
        rmdir "$SCREENSHOTS_DIR" 2>/dev/null || true
    fi
fi

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    print_msg "$GREEN" "✓ Test run completed successfully"
else
    print_msg "$RED" "✗ Test run completed with failures"
fi
echo ""

exit $EXIT_CODE
