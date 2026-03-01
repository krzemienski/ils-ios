#!/bin/bash

# ILS iOS App - Performance Baseline Updater
# Runs performance tests, extracts metrics, and updates performance-baselines.json
# for intentional baseline updates when performance characteristics change.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BASELINES_FILE="${PROJECT_DIR}/performance-baselines.json"
EXTRACT_SCRIPT="${SCRIPT_DIR}/extract-performance-metrics.sh"
PROJECT_FILE="${PROJECT_DIR}/ILSApp/ILSApp.xcodeproj"
SCHEME="ILSApp"
DESTINATION="platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14"

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
Usage: $(basename "$0") [OPTIONS]

Runs performance tests and updates performance-baselines.json with new measured values.
Without --confirm the script performs a dry-run, showing proposed changes without writing.

Options:
    -h, --help              Show this help message
    -y, --confirm           Actually write the updated baselines (required to persist changes)
    -r, --reason TEXT       Reason for the baseline update (recommended with --confirm)
    -x, --xcresult PATH     Use an existing .xcresult bundle instead of running tests
    -s, --skip-tests        Skip running tests; requires --xcresult or --metric
    -m, --metric KEY=VALUE  Manually override a specific baseline value (repeatable)
    -t, --threshold PCT     Override regression threshold percentage in baselines (default: 10)
    -v, --verbose           Show verbose output

Examples:
    $(basename "$0")
    $(basename "$0") --confirm --reason "Optimized session list rendering"
    $(basename "$0") --xcresult TestResults.xcresult --confirm --reason "iPhone 16 baseline"
    $(basename "$0") --skip-tests --metric cold_launch_seconds=2.8 --confirm --reason "new device"
    $(basename "$0") --skip-tests --metric warm_launch_seconds=1.2 --metric cold_launch_seconds=2.5

EOF
}

check_dependencies() {
    if ! command -v jq > /dev/null 2>&1; then
        log_error "jq not found. Install with: brew install jq"
        exit 1
    fi
    if ! command -v xcresulttool > /dev/null 2>&1; then
        log_error "xcresulttool not found. Please install Xcode command-line tools."
        exit 1
    fi
    if [ ! -f "$BASELINES_FILE" ]; then
        log_error "Baselines file not found: $BASELINES_FILE"
        exit 1
    fi
    if [ ! -f "$EXTRACT_SCRIPT" ]; then
        log_error "Extract script not found: $EXTRACT_SCRIPT"
        exit 1
    fi
}

check_jq_only() {
    if ! command -v jq > /dev/null 2>&1; then
        log_error "jq not found. Install with: brew install jq"
        exit 1
    fi
    if [ ! -f "$BASELINES_FILE" ]; then
        log_error "Baselines file not found: $BASELINES_FILE"
        exit 1
    fi
}

run_performance_tests() {
    local result_path="$1"

    log_info "Running performance tests..."
    log_info "Project:     $PROJECT_FILE"
    log_info "Scheme:      $SCHEME"
    log_info "Destination: $DESTINATION"
    log_info "Results:     $result_path"
    echo ""

    if [ ! -d "$PROJECT_FILE" ]; then
        log_error "Xcode project not found: $PROJECT_FILE"
        exit 1
    fi

    local test_log="${PROJECT_DIR}/perf_baseline_run.log"

    set +e
    xcodebuild test \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:ILSAppUITests/LaunchPerformanceTests \
        -only-testing:ILSAppUITests/ScrollPerformanceTests \
        -only-testing:ILSAppUITests/ChatRenderPerformanceTests \
        -only-testing:ILSAppUITests/SearchPerformanceTests \
        -only-testing:ILSAppUITests/MemoryPerformanceTests \
        -only-testing:ILSAppUITests/MemoryLeakTests \
        -only-testing:ILSAppUITests/LargeListRenderTests \
        -only-testing:ILSAppUITests/MemoryThresholdTests \
        -resultBundlePath "$result_path" \
        -quiet 2>&1 | tee "$test_log"
    local exit_code=$?
    set -e

    if [ $exit_code -ne 0 ]; then
        log_warning "Some tests failed (exit $exit_code). Metrics from passing tests will still be used."
        log_info "Full output: $test_log"
    else
        log_success "All performance tests passed."
        rm -f "$test_log"
    fi

    if [ ! -d "$result_path" ]; then
        log_error "No xcresult bundle produced at: $result_path"
        exit 1
    fi

    log_success "Results: $result_path"
    echo ""
}

extract_from_xcresult() {
    local bundle_path="$1"

    log_info "Extracting performance metrics from: $(basename "$bundle_path")"
    bash "$EXTRACT_SCRIPT" --format json "$bundle_path" 2>/dev/null
}

# Map extracted metric array to proposed baseline updates.
# Returns a compact JSON object: { "baseline_key": new_value, ... }
map_metrics_to_baselines() {
    local metrics_json="$1"
    local current_baselines="$2"

    echo "$metrics_json" | jq -c \
        --argjson baselines "$current_baselines" \
        '
        . as $metrics |
        [
            $baselines.metrics | to_entries[] |
            . as $entry |
            ($entry.key) as $key |
            ($entry.value.test_class // "") as $tc |
            ($entry.value.test_method // "") as $tm |
            ($entry.value.unit // "") as $unit |

            # Find metrics whose test_id contains both the class and method names
            (
                $metrics | map(
                    select(
                        (.test_id | ascii_downcase | contains($tc | ascii_downcase)) and
                        (.test_id | ascii_downcase | contains($tm | ascii_downcase))
                    )
                )
            ) as $matching |

            # Disambiguate by metric type based on the baseline unit
            (
                if $unit == "seconds" then
                    $matching | map(select(.metric_name | ascii_downcase | test("time|clock|launch")))
                elif $unit == "percent" then
                    $matching | map(select(.metric_name | ascii_downcase | test("cpu")))
                elif $unit == "megabytes" then
                    $matching | map(select(.metric_name | ascii_downcase | test("memory|mem")))
                elif $unit == "milliseconds_per_second" then
                    $matching | map(select(.metric_name | ascii_downcase | test("hitch")))
                else
                    $matching
                end
            ) as $typed |

            # Emit a key/value pair for the first (best) candidate
            if ($typed | length) > 0 then
                { key: $key, value: ($typed[0].average | . * 100 | round | . / 100) }
            else
                empty
            end
        ] | from_entries
        ' 2>/dev/null || echo "{}"
}

show_proposed_changes() {
    local current_baselines="$1"
    local proposed_updates="$2"
    local manual_overrides="$3"

    echo ""
    log_info "═══════════════════════════════════════════════════"
    log_info "         PROPOSED BASELINE CHANGES                 "
    log_info "═══════════════════════════════════════════════════"

    local any_changes=false

    local xcresult_count=0
    if [ -n "$proposed_updates" ] && [ "$proposed_updates" != "{}" ] && [ "$proposed_updates" != "null" ]; then
        xcresult_count=$(echo "$proposed_updates" | jq 'length // 0')
    fi

    if [ "$xcresult_count" -gt 0 ]; then
        any_changes=true
        log_info "From test run ($xcresult_count metrics matched):"
        while IFS= read -r line; do
            local key new_val old_val unit change_pct
            key="${line%%=*}"
            new_val="${line#*=}"
            old_val=$(echo "$current_baselines" | jq -r --arg k "$key" '.metrics[$k].baseline_value // "N/A"')
            unit=$(echo "$current_baselines" | jq -r --arg k "$key" '.metrics[$k].unit // ""')
            if [ "$old_val" != "N/A" ] && [ "$old_val" != "0" ]; then
                change_pct=$(awk -v o="$old_val" -v n="$new_val" \
                    'BEGIN { printf "%+.1f%%", ((n - o) / o) * 100 }')
                echo -e "  ${CYAN}${key}${NC}: ${old_val} → ${new_val} ${unit} (${change_pct})"
            else
                echo -e "  ${CYAN}${key}${NC}: ${old_val} → ${new_val} ${unit}"
            fi
        done < <(echo "$proposed_updates" | jq -r 'to_entries[] | "\(.key)=\(.value)"')
    fi

    local manual_count=0
    if [ -n "$manual_overrides" ] && [ "$manual_overrides" != "{}" ] && [ "$manual_overrides" != "null" ]; then
        manual_count=$(echo "$manual_overrides" | jq 'length // 0')
    fi

    if [ "$manual_count" -gt 0 ]; then
        any_changes=true
        log_info "Manual overrides ($manual_count metrics):"
        while IFS= read -r line; do
            local key new_val old_val unit
            key="${line%%=*}"
            new_val="${line#*=}"
            old_val=$(echo "$current_baselines" | jq -r --arg k "$key" '.metrics[$k].baseline_value // "NOT FOUND"')
            unit=$(echo "$current_baselines" | jq -r --arg k "$key" '.metrics[$k].unit // ""')
            echo -e "  ${CYAN}${key}${NC}: ${old_val} → ${new_val} ${unit} (manual)"
        done < <(echo "$manual_overrides" | jq -r 'to_entries[] | "\(.key)=\(.value)"')
    fi

    if [ "$any_changes" = false ]; then
        log_warning "No matching metrics found to update."
        log_info "The xcresult may contain no performance data, or metric names did not match."
        log_info "Use --metric KEY=VALUE to manually set baseline values."
        log_info "Valid keys: $(echo "$current_baselines" | jq -r '.metrics | keys | join(", ")')"
    fi

    echo ""
}

build_updated_baselines() {
    local current_baselines="$1"
    local proposed_updates="$2"
    local manual_overrides="$3"
    local reason="$4"
    local threshold="${5:-10}"

    # Merge updates; manual overrides take precedence over extracted metrics
    local all_updates
    all_updates=$(printf '%s\n%s' "${proposed_updates:-{\}}" "${manual_overrides:-{\}}" \
        | jq -s 'add // {}')

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "$current_baselines" | jq \
        --argjson updates "$all_updates" \
        --arg ts "$timestamp" \
        --arg reason "$reason" \
        --argjson threshold "$threshold" \
        '
        .updated_at = $ts |
        (if $reason != "" then .update_reason = $reason else . end) |
        (if $threshold != 10 then .regression_threshold_pct = $threshold else . end) |
        .metrics = (
            .metrics | with_entries(
                if $updates | has(.key) then
                    (($updates[.key] / .value.baseline_value) as $scale |
                    .value.baseline_value = $updates[.key] |
                    .value.warning_threshold = (
                        .value.warning_threshold * $scale | . * 100 | round | . / 100
                    ) |
                    .value.fail_threshold = (
                        .value.fail_threshold * $scale | . * 100 | round | . / 100
                    ))
                else
                    .
                end
            )
        )
        '
}

backup_baselines() {
    local backup_path="${BASELINES_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$BASELINES_FILE" "$backup_path"
    log_info "Backed up current baselines to: $(basename "$backup_path")"
}

write_baselines() {
    local updated_json="$1"
    echo "$updated_json" > "$BASELINES_FILE"
    log_success "Baselines updated: performance-baselines.json"
}

# Parse arguments
CONFIRM=false
REASON=""
XCRESULT_PATH=""
SKIP_TESTS=false
MANUAL_OVERRIDES="{}"
THRESHOLD=10
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_usage
            exit 0
            ;;
        -y|--confirm)
            CONFIRM=true
            shift
            ;;
        -r|--reason)
            REASON="$2"
            shift 2
            ;;
        -x|--xcresult)
            XCRESULT_PATH="$2"
            shift 2
            ;;
        -s|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -m|--metric)
            KEY="${2%%=*}"
            VALUE="${2#*=}"
            if ! echo "$VALUE" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
                log_error "Invalid value '$VALUE' for --metric $KEY. Must be a positive number."
                exit 1
            fi
            MANUAL_OVERRIDES=$(echo "$MANUAL_OVERRIDES" \
                | jq --arg k "$KEY" --argjson v "$VALUE" '. + {($k): $v}')
            shift 2
            ;;
        -t|--threshold)
            if ! echo "$2" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
                log_error "Invalid threshold value: $2. Must be a positive number."
                exit 1
            fi
            THRESHOLD="$2"
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

# Validate argument combinations
if [ "$SKIP_TESTS" = true ] && [ -z "$XCRESULT_PATH" ] && [ "$MANUAL_OVERRIDES" = "{}" ]; then
    log_error "--skip-tests requires --xcresult PATH or at least one --metric KEY=VALUE"
    print_usage
    exit 1
fi

if [ -n "$XCRESULT_PATH" ] && [ ! -e "$XCRESULT_PATH" ]; then
    log_error "xcresult bundle not found: $XCRESULT_PATH"
    exit 1
fi

# Main execution
log_info "═══════════════════════════════════════════════════"
log_info "     ILS Performance Baseline Updater              "
log_info "═══════════════════════════════════════════════════"
echo ""

if [ "$CONFIRM" = false ]; then
    log_warning "DRY RUN — pass --confirm to write changes"
    echo ""
fi

# Check dependencies based on what operations are needed
if [ "$SKIP_TESTS" = true ] && [ -z "$XCRESULT_PATH" ]; then
    check_jq_only
else
    check_dependencies
fi

# Load current baselines
CURRENT_BASELINES=$(cat "$BASELINES_FILE")

# Run tests and/or extract metrics
PROPOSED_UPDATES="{}"

if [ "$SKIP_TESTS" = false ]; then
    # Determine xcresult path
    if [ -z "$XCRESULT_PATH" ]; then
        XCRESULT_PATH="${PROJECT_DIR}/PerformanceBaseline_$(date +%Y%m%d_%H%M%S).xcresult"
        run_performance_tests "$XCRESULT_PATH"
    fi

    # Extract metrics from xcresult bundle
    METRICS_JSON=$(extract_from_xcresult "$XCRESULT_PATH")

    if [ "$VERBOSE" = true ]; then
        local_count=$(echo "$METRICS_JSON" | jq 'length // 0' 2>/dev/null || echo "0")
        log_info "Extracted $local_count metric entries from xcresult"
    fi

    if [ -n "$METRICS_JSON" ] && [ "$METRICS_JSON" != "[]" ] && [ "$METRICS_JSON" != "null" ]; then
        PROPOSED_UPDATES=$(map_metrics_to_baselines "$METRICS_JSON" "$CURRENT_BASELINES")
    else
        log_warning "No performance metrics extracted from xcresult bundle."
        log_info "Ensure performance tests were included and ran successfully."
    fi
fi

# Show the proposed changes (dry-run view)
show_proposed_changes "$CURRENT_BASELINES" "$PROPOSED_UPDATES" "$MANUAL_OVERRIDES"

# Determine if there is anything to write
TOTAL_CHANGES=$(
    printf '%s\n%s' "${PROPOSED_UPDATES:-{\}}" "${MANUAL_OVERRIDES:-{\}}" \
        | jq -s 'add | length // 0'
)

if [ "$CONFIRM" = true ]; then
    if [ "$TOTAL_CHANGES" -eq 0 ]; then
        log_warning "Nothing to update. No metrics were matched and no manual overrides were given."
        exit 0
    fi

    if [ -z "$REASON" ]; then
        log_warning "No --reason provided. Consider documenting why these baselines changed."
    fi

    # Build, backup, and write updated baselines
    UPDATED_BASELINES=$(build_updated_baselines \
        "$CURRENT_BASELINES" "$PROPOSED_UPDATES" "$MANUAL_OVERRIDES" "$REASON" "$THRESHOLD")

    backup_baselines
    write_baselines "$UPDATED_BASELINES"

    echo ""
    log_success "═══════════════════════════════════════════════════"
    log_success "  Baselines updated! Commit this change:           "
    log_success "  git add performance-baselines.json               "
    if [ -n "$REASON" ]; then
        log_success "  git commit -m \"perf: update baselines — $REASON\""
    else
        log_success "  git commit -m \"perf: update performance baselines\" "
    fi
    log_success "═══════════════════════════════════════════════════"
else
    log_info "DRY RUN complete — no files were modified."
    log_info "Run with --confirm to apply these changes."
fi

exit 0
