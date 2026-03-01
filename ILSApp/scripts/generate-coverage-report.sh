#!/bin/bash
set -e

# ILS iOS App Coverage Report Generator
# Parses xcresult bundle and outputs code coverage summary

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="${PROJECT_DIR}/test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Default values
XCRESULT_PATH=""
OUTPUT_DIR="${RESULTS_DIR}/coverage"
MIN_COVERAGE=0
FORMAT="text"
SHOW_FILES=false
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

Generate code coverage report from an xcresult bundle

OPTIONS:
    -r, --result PATH       Path to .xcresult bundle (required, or uses latest in test-results/)
    -o, --output DIR        Output directory for reports (default: test-results/coverage)
    -m, --min-coverage PCT  Minimum coverage percentage (0-100, default: 0)
    -f, --format FORMAT     Output format: text, json, html (default: text)
    --files                 Show per-file coverage breakdown
    -v, --verbose           Verbose output
    -h, --help              Show this help message

EXAMPLES:
    # Generate report from latest xcresult bundle
    $0

    # Generate report from specific bundle
    $0 --result test-results/TestResults_20240101_120000.xcresult

    # Enforce minimum 80% coverage
    $0 --min-coverage 80

    # Generate JSON report with file breakdown
    $0 --format json --files

    # Generate HTML report
    $0 --format html --output coverage-reports

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
        -r|--result)
            XCRESULT_PATH="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -m|--min-coverage)
            MIN_COVERAGE="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        --files)
            SHOW_FILES=true
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

# Validate format
if [[ "$FORMAT" != "text" && "$FORMAT" != "json" && "$FORMAT" != "html" ]]; then
    print_msg "$RED" "Invalid format: $FORMAT (must be text, json, or html)"
    exit 1
fi

# Find xcresult bundle if not specified
if [ -z "$XCRESULT_PATH" ]; then
    if [ -d "$RESULTS_DIR" ]; then
        XCRESULT_PATH=$(find "$RESULTS_DIR" -name "*.xcresult" -type d | sort | tail -1)
    fi
    if [ -z "$XCRESULT_PATH" ]; then
        print_msg "$RED" "No .xcresult bundle found. Run tests first or specify --result PATH"
        exit 1
    fi
    print_msg "$YELLOW" "Using latest result bundle: $XCRESULT_PATH"
fi

# Validate xcresult bundle exists
if [ ! -d "$XCRESULT_PATH" ]; then
    print_msg "$RED" "xcresult bundle not found: $XCRESULT_PATH"
    exit 1
fi

# Ensure xcrun is available
if ! command -v xcrun &> /dev/null; then
    print_msg "$RED" "xcrun not found. Xcode command line tools must be installed."
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Print configuration
print_msg "$BLUE" "========================================"
print_msg "$BLUE" "ILS iOS App Coverage Report Generator"
print_msg "$BLUE" "========================================"
echo "Result Bundle: $XCRESULT_PATH"
echo "Output Dir:    $OUTPUT_DIR"
echo "Format:        $FORMAT"
echo "Min Coverage:  ${MIN_COVERAGE}%"
echo ""

# Extract coverage data using xccov
print_msg "$BLUE" "Extracting coverage data..."

COVERAGE_JSON="${OUTPUT_DIR}/coverage_raw_${TIMESTAMP}.json"
if ! xcrun xccov view --report --json "$XCRESULT_PATH" > "$COVERAGE_JSON" 2>/dev/null; then
    print_msg "$YELLOW" "Warning: xccov JSON extraction failed, trying legacy format..."
    xcrun xccov view --report "$XCRESULT_PATH" > "${OUTPUT_DIR}/coverage_text_${TIMESTAMP}.txt" 2>/dev/null || true
fi

print_msg "$BLUE" "========================================"
print_msg "$BLUE" "Coverage Summary"
print_msg "$BLUE" "========================================"

EXIT_CODE=0

# Parse and display coverage based on format
if [ "$FORMAT" = "json" ]; then
    # JSON output
    OUTPUT_FILE="${OUTPUT_DIR}/coverage_${TIMESTAMP}.json"
    if [ -f "$COVERAGE_JSON" ]; then
        cp "$COVERAGE_JSON" "$OUTPUT_FILE"
        print_msg "$GREEN" "JSON coverage report saved to: $OUTPUT_FILE"

        # Extract total line coverage for threshold check
        TOTAL_COVERAGE=$(python3 -c "
import json, sys
try:
    with open('${COVERAGE_JSON}') as f:
        data = json.load(f)
    lc = data.get('lineCoverage', 0)
    print('{:.1f}'.format(lc * 100))
except Exception as e:
    print('0')
" 2>/dev/null || echo "0")
    else
        print_msg "$YELLOW" "No JSON coverage data available"
        TOTAL_COVERAGE="0"
    fi

elif [ "$FORMAT" = "html" ]; then
    # HTML output
    OUTPUT_FILE="${OUTPUT_DIR}/coverage_${TIMESTAMP}.html"
    TOTAL_COVERAGE="0"

    if [ -f "$COVERAGE_JSON" ]; then
        TOTAL_COVERAGE=$(python3 -c "
import json, sys
try:
    with open('${COVERAGE_JSON}') as f:
        data = json.load(f)
    lc = data.get('lineCoverage', 0)
    print('{:.1f}'.format(lc * 100))
except:
    print('0')
" 2>/dev/null || echo "0")

        python3 << PYEOF
import json
from datetime import datetime

with open('${COVERAGE_JSON}') as f:
    data = json.load(f)

total = data.get('lineCoverage', 0) * 100
targets = data.get('targets', [])

color = '#2ecc71' if total >= 80 else ('#f39c12' if total >= 60 else '#e74c3c')

rows = ''
for target in sorted(targets, key=lambda t: t.get('name', '')):
    t_cov = target.get('lineCoverage', 0) * 100
    t_color = '#2ecc71' if t_cov >= 80 else ('#f39c12' if t_cov >= 60 else '#e74c3c')
    rows += f'<tr><td>{target.get("name","")}</td><td style="color:{t_color}">{t_cov:.1f}%</td><td>{target.get("coveredLines",0)}</td><td>{target.get("executableLines",0)}</td></tr>'

    if ${SHOW_FILES}:
        for src in sorted(target.get('files', []), key=lambda f: f.get('name', '')):
            f_cov = src.get('lineCoverage', 0) * 100
            f_color = '#2ecc71' if f_cov >= 80 else ('#f39c12' if f_cov >= 60 else '#e74c3c')
            rows += f'<tr style="background:#f9f9f9"><td>&nbsp;&nbsp;{src.get("name","")}</td><td style="color:{f_color}">{f_cov:.1f}%</td><td>{src.get("coveredLines",0)}</td><td>{src.get("executableLines",0)}</td></tr>'

html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>ILS iOS Coverage Report</title>
<style>body{{font-family:sans-serif;max-width:900px;margin:40px auto;padding:0 20px}}
h1{{color:#333}}table{{width:100%;border-collapse:collapse}}
th{{background:#333;color:#fff;padding:8px;text-align:left}}
td{{padding:8px;border-bottom:1px solid #ddd}}.total{{font-size:2em;color:{color}}}</style>
</head><body>
<h1>ILS iOS App — Coverage Report</h1>
<p>Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
<p class="total">Total Coverage: {total:.1f}%</p>
<table><tr><th>Target / File</th><th>Coverage</th><th>Covered Lines</th><th>Executable Lines</th></tr>
{rows}</table></body></html>"""

with open('${OUTPUT_FILE}', 'w') as f:
    f.write(html)
PYEOF
        print_msg "$GREEN" "HTML coverage report saved to: $OUTPUT_FILE"
    else
        print_msg "$YELLOW" "No coverage data available for HTML report"
    fi

else
    # Text output (default)
    TOTAL_COVERAGE="0"

    if [ -f "$COVERAGE_JSON" ]; then
        # Extract and display text summary from JSON
        python3 << PYEOF
import json, sys

with open('${COVERAGE_JSON}') as f:
    data = json.load(f)

total = data.get('lineCoverage', 0) * 100
targets = data.get('targets', [])
covered = data.get('coveredLines', 0)
executable = data.get('executableLines', 0)

print(f"  Total Line Coverage: {total:.1f}%")
print(f"  Covered Lines:       {covered}")
print(f"  Executable Lines:    {executable}")
print("")
print("  By Target:")
for target in sorted(targets, key=lambda t: t.get('lineCoverage', 0)):
    t_cov = target.get('lineCoverage', 0) * 100
    t_name = target.get('name', 'Unknown')
    t_covered = target.get('coveredLines', 0)
    t_exec = target.get('executableLines', 0)
    bar_filled = int(t_cov / 5)
    bar = '█' * bar_filled + '░' * (20 - bar_filled)
    print(f"    {t_name:<40} {bar} {t_cov:5.1f}%  ({t_covered}/{t_exec})")

    if ${SHOW_FILES}:
        for src in sorted(target.get('files', []), key=lambda f: f.get('lineCoverage', 0)):
            f_cov = src.get('lineCoverage', 0) * 100
            f_name = src.get('name', 'Unknown')
            f_covered = src.get('coveredLines', 0)
            f_exec = src.get('executableLines', 0)
            print(f"      {f_name:<38} {f_cov:5.1f}%  ({f_covered}/{f_exec})")
PYEOF
        TOTAL_COVERAGE=$(python3 -c "
import json
with open('${COVERAGE_JSON}') as f:
    data = json.load(f)
print('{:.1f}'.format(data.get('lineCoverage', 0) * 100))
" 2>/dev/null || echo "0")

        # Save text report
        OUTPUT_FILE="${OUTPUT_DIR}/coverage_${TIMESTAMP}.txt"
        xcrun xccov view --report "$XCRESULT_PATH" > "$OUTPUT_FILE" 2>/dev/null || true
        print_msg "$BLUE" "Text coverage report saved to: $OUTPUT_FILE"

    elif [ -f "${OUTPUT_DIR}/coverage_text_${TIMESTAMP}.txt" ]; then
        cat "${OUTPUT_DIR}/coverage_text_${TIMESTAMP}.txt"
        print_msg "$YELLOW" "Note: Could not parse coverage percentage for threshold check"
    else
        print_msg "$YELLOW" "No coverage data found in result bundle"
        print_msg "$YELLOW" "Coverage data requires tests built with -enableCodeCoverage YES"
    fi
fi

# Clean up raw JSON (keep only formatted output)
rm -f "$COVERAGE_JSON"

echo ""
print_msg "$BLUE" "========================================"

# Threshold check
if [ -n "$TOTAL_COVERAGE" ] && [ "$MIN_COVERAGE" -gt 0 ] 2>/dev/null; then
    COVERAGE_INT=$(echo "$TOTAL_COVERAGE" | cut -d. -f1)
    if [ "$COVERAGE_INT" -ge "$MIN_COVERAGE" ]; then
        print_msg "$GREEN" "✓ Coverage ${TOTAL_COVERAGE}% meets minimum threshold of ${MIN_COVERAGE}%"
    else
        print_msg "$RED" "✗ Coverage ${TOTAL_COVERAGE}% is below minimum threshold of ${MIN_COVERAGE}%"
        EXIT_CODE=1
    fi
fi

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    print_msg "$GREEN" "✓ Coverage report generated successfully"
else
    print_msg "$RED" "✗ Coverage report completed with threshold violations"
fi
echo ""

exit $EXIT_CODE
