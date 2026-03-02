#!/bin/bash
set -e

# ILS iOS App Snapshot Test Manager
# Manages snapshot recording, diffing, and acceptance workflows

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="ILSApp"
SIMULATOR_UDID="50523130-57AA-48B0-ABD0-4D59CE455F14"
RESULTS_DIR="${PROJECT_DIR}/test-results"
REFERENCE_DIR="${PROJECT_DIR}/ILSAppUITests/SnapshotTests/ReferenceImages"
SNAPSHOT_TEST_CLASS="ScreenSnapshotTests"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Default mode
MODE=""
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
Usage: $0 [MODE] [OPTIONS]

Manage ILS iOS App UI Snapshot Tests

MODES:
    --record        Record new reference snapshots
                    Runs ScreenSnapshotTests with RECORD_SNAPSHOTS=1 env var.
                    New reference images are saved directly to:
                      ILSAppUITests/SnapshotTests/ReferenceImages/

    --diff          Show diff images from the last test run
                    Exports Actual/Reference attachments from the latest
                    xcresult bundle and opens them in Preview for comparison.

    --accept-all    Accept all snapshot diffs from the last test run
                    Copies new (Actual) screenshots to ReferenceImages as the
                    new baseline. Commit the updated references afterwards.

OPTIONS:
    -v, --verbose   Verbose xcodebuild output
    -h, --help      Show this help message

WORKFLOW:
    1. Record initial baseline: $0 --record
    2. Run tests normally to detect regressions (see run-ui-tests.sh)
    3. Review failures visually: $0 --diff
    4. Accept intended visual changes: $0 --accept-all
    5. Commit updated reference images to version control

EXAMPLES:
    $0 --record
    $0 --diff
    $0 --accept-all
    $0 --record --verbose

EOF
    exit 1
}

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Find the most recent xcresult bundle in RESULTS_DIR
find_latest_xcresult() {
    ls -td "${RESULTS_DIR}"/*.xcresult 2>/dev/null | head -1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --record)
            MODE="record"
            shift
            ;;
        --diff)
            MODE="diff"
            shift
            ;;
        --accept-all)
            MODE="accept-all"
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

# Require a mode
if [ -z "$MODE" ]; then
    print_msg "$RED" "Error: No mode specified"
    echo ""
    usage
fi

# Header
print_msg "$BLUE" "========================================"
print_msg "$BLUE" "ILS iOS App Snapshot Manager"
print_msg "$BLUE" "Mode: --$MODE"
print_msg "$BLUE" "========================================"
echo ""

# ─── RECORD MODE ──────────────────────────────────────────────────────────────
if [ "$MODE" = "record" ]; then
    print_msg "$YELLOW" "Recording new reference snapshots..."
    echo "Simulator: $SIMULATOR_UDID"
    echo "Reference Dir: $REFERENCE_DIR"
    echo ""

    mkdir -p "$RESULTS_DIR"
    RESULT_BUNDLE="${RESULTS_DIR}/SnapshotRecord_${TIMESTAMP}.xcresult"

    # Build xcodebuild command targeting only ScreenSnapshotTests
    XCODEBUILD_CMD="xcodebuild test"
    XCODEBUILD_CMD="$XCODEBUILD_CMD -project \"${PROJECT_DIR}/ILSApp.xcodeproj\""
    XCODEBUILD_CMD="$XCODEBUILD_CMD -scheme \"$SCHEME\""
    XCODEBUILD_CMD="$XCODEBUILD_CMD -destination \"id=$SIMULATOR_UDID\""
    XCODEBUILD_CMD="$XCODEBUILD_CMD -only-testing:\"ILSAppUITests/$SNAPSHOT_TEST_CLASS\""
    XCODEBUILD_CMD="$XCODEBUILD_CMD -resultBundlePath \"$RESULT_BUNDLE\""
    XCODEBUILD_CMD="$XCODEBUILD_CMD -testenv RECORD_SNAPSHOTS=1"

    if [ "$VERBOSE" = false ]; then
        XCODEBUILD_CMD="$XCODEBUILD_CMD -quiet"
    fi

    if [ "$VERBOSE" = true ]; then
        print_msg "$YELLOW" "Running command:"
        echo "$XCODEBUILD_CMD"
        echo ""
    fi

    print_msg "$BLUE" "Starting snapshot recording run..."
    echo ""

    if eval $XCODEBUILD_CMD; then
        print_msg "$GREEN" "✓ Snapshots recorded successfully"
        echo ""
        print_msg "$BLUE" "Reference images saved to:"
        print_msg "$BLUE" "  $REFERENCE_DIR"
        echo ""
        print_msg "$YELLOW" "Commit the new references with:"
        print_msg "$YELLOW" "  git add ILSApp/ILSAppUITests/SnapshotTests/ReferenceImages/"
        print_msg "$YELLOW" "  git commit -m 'Record snapshot baselines'"
    else
        print_msg "$RED" "✗ Snapshot recording failed — check test output above"
        echo ""
        print_msg "$YELLOW" "Hint: Ensure the simulator ($SIMULATOR_UDID) is available and the app builds."
        exit 1
    fi

# ─── DIFF MODE ────────────────────────────────────────────────────────────────
elif [ "$MODE" = "diff" ]; then
    print_msg "$BLUE" "Locating latest test results..."

    LATEST_XCRESULT=$(find_latest_xcresult)

    if [ -z "$LATEST_XCRESULT" ]; then
        print_msg "$RED" "✗ No xcresult bundles found in: $RESULTS_DIR"
        echo ""
        print_msg "$YELLOW" "Run tests first using:"
        print_msg "$YELLOW" "  ./scripts/run-ui-tests.sh --quick"
        exit 1
    fi

    print_msg "$BLUE" "Using: $(basename "$LATEST_XCRESULT")"
    echo ""

    # Export all attachments to a temp directory
    EXPORT_DIR="${RESULTS_DIR}/snapshot-diff-${TIMESTAMP}"
    mkdir -p "$EXPORT_DIR"

    print_msg "$BLUE" "Exporting snapshot attachments from xcresult..."
    xcrun xcresulttool export \
        --type directory \
        --path "$LATEST_XCRESULT" \
        --output-path "$EXPORT_DIR" 2>/dev/null || true

    # Collect Actual_*.png and Reference_*.png files
    DIFF_IMAGES=()
    while IFS= read -r -d '' img; do
        DIFF_IMAGES+=("$img")
    done < <(find "$EXPORT_DIR" \( -name "Actual_*.png" -o -name "Reference_*.png" \) -print0 2>/dev/null)

    if [ ${#DIFF_IMAGES[@]} -eq 0 ]; then
        print_msg "$GREEN" "✓ No snapshot diffs found — all snapshot tests passed!"
        rm -rf "$EXPORT_DIR"
        exit 0
    fi

    print_msg "$YELLOW" "Found ${#DIFF_IMAGES[@]} diff image(s):"
    for img in "${DIFF_IMAGES[@]}"; do
        echo "  $(basename "$img")"
    done
    echo ""

    print_msg "$BLUE" "Opening diff images in Preview..."
    open -a Preview "${DIFF_IMAGES[@]}"

    echo ""
    print_msg "$GREEN" "✓ Opened ${#DIFF_IMAGES[@]} image(s) in Preview"
    echo ""
    print_msg "$YELLOW" "To accept all diffs as the new baseline, run:"
    print_msg "$YELLOW" "  $0 --accept-all"

# ─── ACCEPT-ALL MODE ──────────────────────────────────────────────────────────
elif [ "$MODE" = "accept-all" ]; then
    print_msg "$YELLOW" "Accepting all snapshot diffs as new baseline..."
    echo ""

    LATEST_XCRESULT=$(find_latest_xcresult)

    if [ -z "$LATEST_XCRESULT" ]; then
        print_msg "$RED" "✗ No xcresult bundles found in: $RESULTS_DIR"
        echo ""
        print_msg "$YELLOW" "Run tests first using:"
        print_msg "$YELLOW" "  ./scripts/run-ui-tests.sh --quick"
        exit 1
    fi

    print_msg "$BLUE" "Using: $(basename "$LATEST_XCRESULT")"
    echo ""

    # Export all attachments to a temp directory
    EXPORT_DIR="${RESULTS_DIR}/snapshot-accept-${TIMESTAMP}"
    mkdir -p "$EXPORT_DIR"

    print_msg "$BLUE" "Exporting actual snapshot images from xcresult..."
    xcrun xcresulttool export \
        --type directory \
        --path "$LATEST_XCRESULT" \
        --output-path "$EXPORT_DIR" 2>/dev/null || true

    # Find Actual_*.png files — these are the current screenshots to promote as references
    ACCEPTED=0
    FAILED=0

    while IFS= read -r -d '' actual_img; do
        filename=$(basename "$actual_img")

        # Strip "Actual_" prefix to get the snapshot name
        snapshot_name="${filename#Actual_}"
        snapshot_name="${snapshot_name%.png}"

        # Destination: ReferenceImages/<TestClass>/<snapshotName>.png
        ref_path="${REFERENCE_DIR}/${SNAPSHOT_TEST_CLASS}/${snapshot_name}.png"
        ref_dir="$(dirname "$ref_path")"

        mkdir -p "$ref_dir"

        if cp "$actual_img" "$ref_path"; then
            print_msg "$GREEN" "  ✓ Accepted: $snapshot_name"
            ACCEPTED=$((ACCEPTED + 1))
        else
            print_msg "$RED" "  ✗ Failed to copy: $snapshot_name → $ref_path"
            FAILED=$((FAILED + 1))
        fi
    done < <(find "$EXPORT_DIR" -name "Actual_*.png" -print0 2>/dev/null)

    echo ""

    if [ $ACCEPTED -eq 0 ] && [ $FAILED -eq 0 ]; then
        print_msg "$YELLOW" "No Actual_*.png images found in xcresult bundle."
        echo ""
        print_msg "$YELLOW" "This means either:"
        print_msg "$YELLOW" "  • All snapshot tests passed (no diffs to accept)"
        print_msg "$YELLOW" "  • No snapshot tests were run in this xcresult"
        echo ""
        print_msg "$YELLOW" "To record fresh snapshots use: $0 --record"
    elif [ $FAILED -eq 0 ]; then
        print_msg "$GREEN" "✓ Accepted $ACCEPTED snapshot(s) as the new reference baseline"
        echo ""
        print_msg "$BLUE" "Reference images updated in: $REFERENCE_DIR"
        echo ""
        print_msg "$YELLOW" "Remember to commit the updated reference images:"
        print_msg "$YELLOW" "  git add ILSApp/ILSAppUITests/SnapshotTests/ReferenceImages/"
        print_msg "$YELLOW" "  git commit -m 'Update snapshot references'"
    else
        print_msg "$RED" "✗ Completed with errors — Accepted: $ACCEPTED, Failed: $FAILED"
        exit 1
    fi
fi

echo ""
print_msg "$BLUE" "Done."
echo ""
