#!/bin/bash

# ILS iOS App - Performance Metrics Extractor
# Extracts metric values from an xcresult bundle using xcresulttool

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] <xcresult-path>

Extracts performance metric values from an xcresult bundle using xcresulttool.

Arguments:
    <xcresult-path>         Path to the .xcresult bundle

Options:
    -h, --help              Show this help message
    -o, --output FILE       Write JSON output to FILE (default: stdout)
    -m, --metric NAME       Extract only the named metric (e.g. "Clock Monotonic Time")
    -t, --test NAME         Extract metrics only for the named test (substring match)
    -f, --format FORMAT     Output format: json (default) or csv
    -v, --verbose           Show verbose output

Examples:
    $(basename "$0") TestResults.xcresult
    $(basename "$0") -m "Clock Monotonic Time" TestResults.xcresult
    $(basename "$0") -t "testAppLaunchPerformance" TestResults.xcresult
    $(basename "$0") -f csv -o metrics.csv TestResults.xcresult

EOF
}

check_xcresulttool() {
    if ! command -v xcresulttool > /dev/null 2>&1; then
        log_error "xcresulttool not found. Please install Xcode command-line tools."
        exit 1
    fi
}

check_jq() {
    if ! command -v jq > /dev/null 2>&1; then
        log_error "jq not found. Install with: brew install jq"
        exit 1
    fi
}

extract_metrics_json() {
    local bundle_path="$1"

    # Get the full result bundle as JSON
    xcresulttool get --path "$bundle_path" --format json 2>/dev/null
}

parse_performance_metrics() {
    local raw_json="$1"
    local filter_metric="$2"
    local filter_test="$3"

    # Navigate into actions -> actionResult -> testsRef, then iterate test nodes
    # xcresult JSON structure: actions._values[].actionResult.testsRef
    echo "$raw_json" | jq -r --arg metric "$filter_metric" --arg test "$filter_test" '
        # Collect all performance metrics from all test nodes
        [
            .actions._values[]? |
            .actionResult? |
            select(.testsRef? != null) |
            .testsRef
        ] as $refs |

        # Walk the full JSON looking for performanceMetrics
        .. |
        objects |
        select(has("performanceMetrics")) |
        . as $testNode |
        ($testNode.identifier._value // "unknown") as $testId |
        ($testNode.name._value // "unknown") as $testName |
        $testNode.performanceMetrics._values[]? |
        . as $metric |
        select(
            ($metric == null | not) and
            ($test == "" or ($testId | ascii_downcase | contains($test | ascii_downcase)) or
                           ($testName | ascii_downcase | contains($test | ascii_downcase))) and
            ($metric == "" or (($metric.identifier._value // "") | ascii_downcase | contains($metric | ascii_downcase)) or
                              (($metric.displayName._value // "") | ascii_downcase | contains($metric | ascii_downcase)))
        ) |
        {
            test_id: $testId,
            test_name: $testName,
            metric_id: ($metric.identifier._value // ""),
            metric_name: ($metric.displayName._value // ""),
            unit: ($metric.unitOfMeasurement._value // ""),
            average: ($metric.measurements._values | map(._value | tonumber) | add / length),
            min: ($metric.measurements._values | map(._value | tonumber) | min),
            max: ($metric.measurements._values | map(._value | tonumber) | max),
            samples: ($metric.measurements._values | length),
            measurements: ($metric.measurements._values | map(._value | tonumber))
        }
    ' 2>/dev/null
}

format_as_csv() {
    local json_metrics="$1"
    echo "test_id,test_name,metric_id,metric_name,unit,average,min,max,samples"
    echo "$json_metrics" | jq -r \
        '[.test_id, .test_name, .metric_id, .metric_name, .unit,
          (.average | tostring), (.min | tostring), (.max | tostring),
          (.samples | tostring)] | @csv' 2>/dev/null
}

# Parse arguments
OUTPUT_FILE=""
FILTER_METRIC=""
FILTER_TEST=""
OUTPUT_FORMAT="json"
VERBOSE=false
XCRESULT_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_usage
            exit 0
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -m|--metric)
            FILTER_METRIC="$2"
            shift 2
            ;;
        -t|--test)
            FILTER_TEST="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            if [ -z "$XCRESULT_PATH" ]; then
                XCRESULT_PATH="$1"
            else
                log_error "Unexpected argument: $1"
                print_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$XCRESULT_PATH" ]; then
    log_error "No xcresult path provided."
    print_usage
    exit 1
fi

if [ ! -e "$XCRESULT_PATH" ]; then
    log_error "xcresult bundle not found: $XCRESULT_PATH"
    exit 1
fi

if [[ "$OUTPUT_FORMAT" != "json" && "$OUTPUT_FORMAT" != "csv" ]]; then
    log_error "Invalid format '$OUTPUT_FORMAT'. Must be 'json' or 'csv'."
    exit 1
fi

# Check dependencies
check_xcresulttool
check_jq

if [ "$VERBOSE" = true ]; then
    log_info "Extracting metrics from: $XCRESULT_PATH"
    [ -n "$FILTER_METRIC" ] && log_info "Metric filter: $FILTER_METRIC"
    [ -n "$FILTER_TEST" ]   && log_info "Test filter:   $FILTER_TEST"
    log_info "Output format: $OUTPUT_FORMAT"
fi

# Extract raw JSON from xcresult
if [ "$VERBOSE" = true ]; then
    log_info "Running xcresulttool..."
fi

RAW_JSON=$(extract_metrics_json "$XCRESULT_PATH")

if [ -z "$RAW_JSON" ]; then
    log_error "No data returned from xcresulttool. Is the bundle valid?"
    exit 1
fi

# Parse performance metrics
METRICS=$(parse_performance_metrics "$RAW_JSON" "$FILTER_METRIC" "$FILTER_TEST")

if [ -z "$METRICS" ]; then
    log_warning "No performance metrics found matching the given filters."
    if [ -n "$OUTPUT_FILE" ]; then
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            echo "[]" > "$OUTPUT_FILE"
        else
            echo "test_id,test_name,metric_id,metric_name,unit,average,min,max,samples" > "$OUTPUT_FILE"
        fi
    else
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            echo "[]"
        else
            echo "test_id,test_name,metric_id,metric_name,unit,average,min,max,samples"
        fi
    fi
    exit 0
fi

# Format and output
if [ "$OUTPUT_FORMAT" = "json" ]; then
    OUTPUT=$(echo "$METRICS" | jq -s '.')
else
    OUTPUT=$(format_as_csv "$METRICS")
fi

if [ -n "$OUTPUT_FILE" ]; then
    echo "$OUTPUT" > "$OUTPUT_FILE"
    log_success "Metrics written to: $OUTPUT_FILE"
else
    echo "$OUTPUT"
fi
