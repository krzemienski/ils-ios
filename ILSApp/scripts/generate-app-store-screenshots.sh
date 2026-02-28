#!/bin/bash
set -e

# ILS iOS App Store Screenshot Generator
# Runs AppStoreScreenshotTests on required device sizes and exports to AppStoreMetadata/screenshots/

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APPSTORE_METADATA_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/AppStoreMetadata"
SCHEME="ILSApp"
TEST_CLASS="AppStoreScreenshotTests"
RESULTS_DIR="${PROJECT_DIR}/test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Device configurations (device name -> output folder name)
DEVICE_67="iPhone 16 Pro Max"
DEVICE_55="iPhone 8 Plus"
FOLDER_67="6.7-inch"
FOLDER_55="5.5-inch"

# Options
VERBOSE=false
DEVICES_TO_RUN="all"

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

Generate App Store screenshots by running AppStoreScreenshotTests on required device sizes.
Screenshots are exported to AppStoreMetadata/screenshots/.

OPTIONS:
    --6.7               Only generate screenshots for 6.7-inch devices (iPhone 16 Pro Max)
    --5.5               Only generate screenshots for 5.5-inch devices (iPhone 8 Plus)
    -v, --verbose       Verbose xcodebuild output
    -h, --help          Show this help message

OUTPUT DIRECTORIES:
    AppStoreMetadata/screenshots/$FOLDER_67/   (6.7-inch — required)
    AppStoreMetadata/screenshots/$FOLDER_55/   (5.5-inch — required)

DEVICES:
    6.7-inch:  $DEVICE_67
    5.5-inch:  $DEVICE_55

EXAMPLES:
    # Generate all required screenshots
    $0

    # Generate only 6.7-inch screenshots
    $0 --6.7

    # Generate with verbose output
    $0 --verbose

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
        --6.7)
            DEVICES_TO_RUN="67"
            shift
            ;;
        --5.5)
            DEVICES_TO_RUN="55"
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

# Print header
print_msg "$BLUE" "========================================"
print_msg "$BLUE" "ILS App Store Screenshot Generator"
print_msg "$BLUE" "========================================"
echo "Project:  $PROJECT_DIR"
echo "Output:   $APPSTORE_METADATA_DIR/screenshots/"
echo "Devices:  $DEVICES_TO_RUN"
echo ""

# Create results directory
mkdir -p "$RESULTS_DIR"

# ─── RUN SCREENSHOTS FOR A GIVEN DEVICE ───────────────────────────────────────
run_screenshots() {
    local device_name="$1"
    local folder_name="$2"
    local output_dir="${APPSTORE_METADATA_DIR}/screenshots/${folder_name}"

    print_msg "$BLUE" "----------------------------------------"
    print_msg "$BLUE" "Device: $device_name → $folder_name"
    print_msg "$BLUE" "----------------------------------------"
    echo ""

    local result_bundle="${RESULTS_DIR}/AppStoreScreenshots_${folder_name}_${TIMESTAMP}.xcresult"

    # Build xcodebuild command targeting only AppStoreScreenshotTests
    XCODEBUILD_CMD="xcodebuild test"
    XCODEBUILD_CMD="$XCODEBUILD_CMD -project \"${PROJECT_DIR}/ILSApp.xcodeproj\""
    XCODEBUILD_CMD="$XCODEBUILD_CMD -scheme \"$SCHEME\""
    XCODEBUILD_CMD="$XCODEBUILD_CMD -destination \"platform=iOS Simulator,name=${device_name}\""
    XCODEBUILD_CMD="$XCODEBUILD_CMD -only-testing:\"ILSAppUITests/${TEST_CLASS}\""
    XCODEBUILD_CMD="$XCODEBUILD_CMD -resultBundlePath \"${result_bundle}\""

    if [ "$VERBOSE" = false ]; then
        XCODEBUILD_CMD="$XCODEBUILD_CMD -quiet"
    fi

    if [ "$VERBOSE" = true ]; then
        print_msg "$YELLOW" "Running command:"
        echo "$XCODEBUILD_CMD"
        echo ""
    fi

    print_msg "$BLUE" "Running AppStoreScreenshotTests..."
    echo ""

    # Run tests — exit 0 even on failure so screenshots are always exported
    if eval $XCODEBUILD_CMD; then
        print_msg "$GREEN" "✓ Tests passed for $device_name"
    else
        print_msg "$YELLOW" "⚠ Some tests failed — extracting any captured screenshots anyway"
    fi

    echo ""

    # Export screenshots from xcresult
    if [ -d "$result_bundle" ]; then
        local export_dir="${RESULTS_DIR}/appstore-export-${folder_name}-${TIMESTAMP}"
        mkdir -p "$export_dir"

        print_msg "$BLUE" "Extracting screenshots from xcresult..."
        xcrun xcresulttool export \
            --type directory \
            --path "$result_bundle" \
            --output-path "$export_dir" 2>/dev/null || true

        # Find all PNG screenshots captured during tests
        local screenshots=()
        while IFS= read -r -d '' img; do
            screenshots+=("$img")
        done < <(find "$export_dir" -name "*.png" -print0 2>/dev/null)

        if [ ${#screenshots[@]} -eq 0 ]; then
            print_msg "$YELLOW" "⚠ No screenshots found in xcresult — the test may not have captured any"
            echo ""
            return 0
        fi

        # Copy screenshots to AppStoreMetadata output directory
        mkdir -p "$output_dir"
        local copied=0

        for img in "${screenshots[@]}"; do
            local filename
            filename="$(basename "$img")"
            if cp "$img" "${output_dir}/${filename}"; then
                copied=$((copied + 1))
            fi
        done

        print_msg "$GREEN" "✓ Exported $copied screenshot(s) to:"
        print_msg "$GREEN" "  $output_dir"
        echo ""

        # Clean up temp export directory
        rm -rf "$export_dir"
    else
        print_msg "$YELLOW" "⚠ xcresult bundle not found — xcodebuild may have failed before capturing"
        echo ""
    fi

    return 0
}

# ─── RUN FOR EACH REQUIRED DEVICE SIZE ────────────────────────────────────────
OVERALL_EXIT=0

if [ "$DEVICES_TO_RUN" = "all" ] || [ "$DEVICES_TO_RUN" = "67" ]; then
    run_screenshots "$DEVICE_67" "$FOLDER_67" || OVERALL_EXIT=1
fi

if [ "$DEVICES_TO_RUN" = "all" ] || [ "$DEVICES_TO_RUN" = "55" ]; then
    run_screenshots "$DEVICE_55" "$FOLDER_55" || OVERALL_EXIT=1
fi

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
print_msg "$BLUE" "========================================"
print_msg "$BLUE" "Screenshot Generation Complete"
print_msg "$BLUE" "========================================"
echo ""

print_msg "$BLUE" "Screenshots saved to:"
if [ "$DEVICES_TO_RUN" = "all" ] || [ "$DEVICES_TO_RUN" = "67" ]; then
    echo "  $APPSTORE_METADATA_DIR/screenshots/$FOLDER_67/"
fi
if [ "$DEVICES_TO_RUN" = "all" ] || [ "$DEVICES_TO_RUN" = "55" ]; then
    echo "  $APPSTORE_METADATA_DIR/screenshots/$FOLDER_55/"
fi

echo ""
print_msg "$YELLOW" "App Store Submission Instructions:"
echo "  1. Open App Store Connect → Your App → Screenshots"
echo "  2. For 6.7-inch slot: upload files from screenshots/$FOLDER_67/"
echo "  3. For 5.5-inch slot: upload files from screenshots/$FOLDER_55/"
echo "  4. Arrange screenshots in the desired order"
echo "  5. Save and submit with your next release"
echo ""
print_msg "$BLUE" "Done."
echo ""

exit 0
