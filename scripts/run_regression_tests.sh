#!/bin/bash

# ILS iOS App - Regression Test Runner
# Automatically starts backend, runs all regression tests, and generates reports

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${PROJECT_DIR}/ILSFullStack.xcworkspace"
SCHEME="ILSApp"
DESTINATION="platform=iOS Simulator,name=iPhone 15 Pro"
RESULT_BUNDLE="${PROJECT_DIR}/TestResults_$(date +%Y%m%d_%H%M%S).xcresult"
BACKEND_PID_FILE="${PROJECT_DIR}/.backend_test.pid"

# Functions
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

cleanup() {
    log_info "Cleaning up..."

    # Kill backend if it was started by this script
    if [ -f "$BACKEND_PID_FILE" ]; then
        BACKEND_PID=$(cat "$BACKEND_PID_FILE")
        if ps -p "$BACKEND_PID" > /dev/null 2>&1; then
            log_info "Stopping backend (PID: $BACKEND_PID)"
            kill "$BACKEND_PID" 2>/dev/null || true
            sleep 2
            # Force kill if still running
            if ps -p "$BACKEND_PID" > /dev/null 2>&1; then
                kill -9 "$BACKEND_PID" 2>/dev/null || true
            fi
        fi
        rm -f "$BACKEND_PID_FILE"
    fi
}

# Trap to ensure cleanup on exit
trap cleanup EXIT INT TERM

check_backend() {
    log_info "Checking if backend is running..."
    if curl -s -f http://localhost:9999/health > /dev/null 2>&1; then
        log_success "Backend is already running"
        return 0
    else
        return 1
    fi
}

start_backend() {
    log_info "Starting ILS backend server..."

    cd "$PROJECT_DIR"

    # Build backend first
    log_info "Building backend..."
    swift build --product ILSBackend

    # Start backend in background
    PORT=9999 swift run ILSBackend > "${PROJECT_DIR}/backend_test.log" 2>&1 &
    BACKEND_PID=$!
    echo "$BACKEND_PID" > "$BACKEND_PID_FILE"

    log_info "Backend started (PID: $BACKEND_PID)"

    # Wait for backend to be ready
    log_info "Waiting for backend to be ready..."
    MAX_WAIT=30
    WAITED=0

    while [ $WAITED -lt $MAX_WAIT ]; do
        if curl -s -f http://localhost:9999/health > /dev/null 2>&1; then
            log_success "Backend is ready!"
            return 0
        fi
        sleep 1
        WAITED=$((WAITED + 1))
        echo -n "."
    done

    echo ""
    log_error "Backend failed to start within ${MAX_WAIT} seconds"
    log_info "Check backend_test.log for details"
    exit 1
}

run_tests() {
    log_info "Running regression tests..."
    log_info "Workspace: $WORKSPACE"
    log_info "Scheme: $SCHEME"
    log_info "Destination: $DESTINATION"

    # Check if workspace exists
    if [ ! -d "$WORKSPACE" ]; then
        log_error "Workspace not found: $WORKSPACE"
        exit 1
    fi

    # Run tests
    set +e  # Don't exit on test failures
    xcodebuild test \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:ILSAppUITests/RegressionTests \
        -resultBundlePath "$RESULT_BUNDLE" \
        | tee test_output.log \
        | xcpretty --color --simple

    TEST_EXIT_CODE=$?
    set -e

    return $TEST_EXIT_CODE
}

generate_report() {
    log_info "Generating test report..."

    if [ -d "$RESULT_BUNDLE" ]; then
        log_success "Test results saved to: $RESULT_BUNDLE"

        # Extract summary
        if command -v xcresulttool > /dev/null 2>&1; then
            log_info "Extracting test summary..."
            xcresulttool get --path "$RESULT_BUNDLE" --format json > "${RESULT_BUNDLE}.json"
            log_success "JSON report: ${RESULT_BUNDLE}.json"
        fi

        # Count tests
        if [ -f "test_output.log" ]; then
            PASSED=$(grep -c "Test Case.*passed" test_output.log 2>/dev/null || echo "0")
            FAILED=$(grep -c "Test Case.*failed" test_output.log 2>/dev/null || echo "0")
            # Remove any whitespace/newlines
            PASSED=$(echo "$PASSED" | tr -d '[:space:]')
            FAILED=$(echo "$FAILED" | tr -d '[:space:]')

            echo ""
            log_info "═══════════════════════════════════"
            log_info "         TEST SUMMARY              "
            log_info "═══════════════════════════════════"
            log_success "Passed: $PASSED"
            if [ "$FAILED" -gt 0 ]; then
                log_error "Failed: $FAILED"
            else
                log_success "Failed: $FAILED"
            fi
            log_info "═══════════════════════════════════"
        fi
    else
        log_warning "No test results bundle found"
    fi
}

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help              Show this help message
    -s, --scenario N        Run only scenario N (1-10)
    -k, --keep-backend      Don't start/stop backend (use existing)
    -d, --device NAME       Use specific device (default: iPhone 15 Pro)
    -v, --verbose           Show verbose output

Examples:
    $(basename "$0")                    # Run all scenarios
    $(basename "$0") -s 1               # Run only Scenario 1
    $(basename "$0") -k                 # Use existing backend
    $(basename "$0") -d "iPhone 14 Pro" # Use iPhone 14 Pro simulator

EOF
}

# Parse arguments
SCENARIO=""
KEEP_BACKEND=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -s|--scenario)
            SCENARIO="$2"
            shift 2
            ;;
        -k|--keep-backend)
            KEEP_BACKEND=true
            shift
            ;;
        -d|--device)
            DESTINATION="platform=iOS Simulator,name=$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Main execution
log_info "═══════════════════════════════════"
log_info "  ILS iOS Regression Test Runner   "
log_info "═══════════════════════════════════"
echo ""

# Check if backend should be managed
if [ "$KEEP_BACKEND" = false ]; then
    if ! check_backend; then
        start_backend
    fi
else
    if ! check_backend; then
        log_error "Backend is not running and --keep-backend was specified"
        exit 1
    fi
fi

# Modify test target if specific scenario requested
if [ -n "$SCENARIO" ]; then
    log_info "Running only Scenario $SCENARIO"
    SCENARIO_NUM=$(printf "%02d" "$SCENARIO")
    # This would need to be adjusted based on your test naming
    log_warning "Single scenario execution not yet implemented - running all scenarios"
fi

# Run tests
if run_tests; then
    log_success "All tests passed! ✅"
    EXIT_CODE=0
else
    log_error "Some tests failed ❌"
    EXIT_CODE=1
fi

# Generate report
generate_report

# Cleanup log
rm -f test_output.log

echo ""
log_info "Test run complete!"
log_info "View results: open '$RESULT_BUNDLE'"

exit $EXIT_CODE
