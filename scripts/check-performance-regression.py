#!/usr/bin/env python3
"""ILS iOS App - Performance Regression Checker

Compares measured performance metrics against baselines and fails (exit 1)
if any metric regresses more than the configured threshold (default: 10%).
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

# ANSI color codes
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
BOLD = "\033[1m"
NC = "\033[0m"  # No Color


def colored(text: str, color: str) -> str:
    if sys.stdout.isatty():
        return f"{color}{text}{NC}"
    return text


# ---------------------------------------------------------------------------
# Custom argparse formatter so --help starts with "Usage:" (capital U)
# ---------------------------------------------------------------------------

class _CapitalUsageFormatter(argparse.RawDescriptionHelpFormatter):
    def _format_usage(self, usage, actions, groups, prefix=None):
        if prefix is None:
            prefix = "Usage: "
        return super()._format_usage(usage, actions, groups, prefix)


# ---------------------------------------------------------------------------
# Metric mapping: xcresult output → baseline key
# Keys are (partial_test_name_lower, partial_metric_id_lower)
# ---------------------------------------------------------------------------

_XCRESULT_METRIC_MAP: dict[tuple[str, str], str] = {
    ("testcoldlaunchperformance", "clock"):                 "cold_launch_seconds",
    ("testwarmlaunchperformance", "clock"):                 "warm_launch_seconds",
    ("testsessionlistscrollperformance", "cpu"):            "session_scroll_cpu_pct",
    ("testsessionlistscrollperformance", "hitch"):          "session_scroll_hitch_ms_per_s",
    ("testchatmessagelistrenderperformance", "cpu"):        "chat_scroll_cpu_pct",
    ("testchatviewinitialrenderperformance", "cpu"):        "chat_initial_render_cpu_pct",
    ("testsearchqueryresponsetime", "cpu"):                 "search_query_cpu_pct",
    ("testsearchqueryresponsetime", "clock"):               "search_query_clock_s",
    ("testincrementalsearchresponsetime", "cpu"):           "incremental_search_cpu_pct",
    ("testsessionlistscrollmemoryfootprint", "memory"):     "memory_session_browse_mb",
    ("testsessionbrowsingretaincycles", "memory"):          "memory_session_leak_mb",
    ("testchatnavigationretaincycles", "memory"):           "memory_chat_navigation_leak_mb",
    ("testsessionlistidlememorythreshold", "memory"):       "memory_session_idle_mb",
    ("testchatviewmemorythreshold", "memory"):              "memory_chat_active_mb",
    ("testlargelistscrollperformance_100", "cpu"):          "large_list_100_cpu_pct",
    ("testlargelistscrollperformance_100", "hitch"):        "large_list_100_hitch_ms_per_s",
    ("testlargelistscrollperformance_1000", "cpu"):         "large_list_1k_cpu_pct",
    ("testlargelistscrollperformance_10000", "cpu"):        "large_list_10k_cpu_pct",
    ("testapplicationidlecpu", "cpu"):                      "idle_cpu_pct",
    ("testbackgroundprocessingcpu", "cpu"):                 "background_cpu_pct",
    ("testchatstreamingcpu", "cpu"):                        "chat_streaming_cpu_pct",
    ("testcrashfreesessions", "crash"):                     "crash_free_sessions_pct",
}


def _load_json(path: str) -> Any:
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _parse_xcresult_metrics(metrics_array: list) -> dict[str, float]:
    """Map xcresult-style metrics array (from extract-performance-metrics.sh)
    to a flat {baseline_key: measured_value} dict."""
    result: dict[str, float] = {}
    for entry in metrics_array:
        test_id = (entry.get("test_id") or entry.get("test_name") or "").lower()
        metric_id = (entry.get("metric_id") or entry.get("metric_name") or "").lower()
        average = entry.get("average")
        if average is None:
            continue
        for (test_substr, metric_substr), baseline_key in _XCRESULT_METRIC_MAP.items():
            if test_substr in test_id and metric_substr in metric_id:
                result[baseline_key] = float(average)
                break
    return result


def _normalize_metrics(raw: Any) -> dict[str, float]:
    """Accept either a flat dict, a nested {"metrics": {...}} dict,
    or an xcresult array; always return {key: float}."""
    if isinstance(raw, list):
        return _parse_xcresult_metrics(raw)
    if isinstance(raw, dict):
        inner = raw.get("metrics", raw)
        if isinstance(inner, dict):
            return {k: float(v) for k, v in inner.items() if isinstance(v, (int, float))}
    raise ValueError("Metrics JSON must be an object or array.")


# ---------------------------------------------------------------------------
# Regression comparison
# ---------------------------------------------------------------------------

def _check_regressions(
    measured: dict[str, float],
    baselines: dict,
    threshold_pct: float | None,
    verbose: bool,
) -> tuple[list[dict], list[dict], list[dict]]:
    """Return (regressions, warnings, passing) lists."""
    default_threshold = float(baselines.get("regression_threshold_pct", 10))
    baseline_metrics: dict = baselines.get("metrics", {})

    regressions: list[dict] = []
    warnings: list[dict] = []
    passing: list[dict] = []

    for metric_key, measured_value in measured.items():
        if metric_key not in baseline_metrics:
            if verbose:
                print(colored(f"  [SKIP] {metric_key}: no baseline defined", YELLOW))
            continue

        spec = baseline_metrics[metric_key]
        baseline_value = spec.get("baseline_value")
        if baseline_value is None or baseline_value == 0:
            if verbose:
                print(colored(f"  [SKIP] {metric_key}: baseline_value is zero/missing", YELLOW))
            continue

        effective_threshold = threshold_pct if threshold_pct is not None else default_threshold
        fail_threshold = spec.get("fail_threshold")
        warning_threshold = spec.get("warning_threshold")
        unit = spec.get("unit", "")
        pct_change = ((measured_value - baseline_value) / abs(baseline_value)) * 100.0

        record: dict = {
            "key": metric_key,
            "description": spec.get("description", ""),
            "baseline": baseline_value,
            "measured": measured_value,
            "pct_change": round(pct_change, 2),
            "unit": unit,
            "threshold": effective_threshold,
            "test_class": spec.get("test_class", ""),
            "test_method": spec.get("test_method", ""),
        }

        # Explicit fail_threshold takes priority over percentage threshold
        if fail_threshold is not None and measured_value > fail_threshold:
            record["reason"] = (
                f"exceeds hard fail threshold ({fail_threshold} {unit})"
            )
            regressions.append(record)
        elif pct_change > effective_threshold:
            record["reason"] = (
                f"{pct_change:.1f}% increase from baseline (limit: {effective_threshold:.0f}%)"
            )
            regressions.append(record)
        elif warning_threshold is not None and measured_value > warning_threshold:
            record["reason"] = (
                f"exceeds warning threshold ({warning_threshold} {unit})"
            )
            warnings.append(record)
        else:
            record["reason"] = "within bounds"
            passing.append(record)

    return regressions, warnings, passing


# ---------------------------------------------------------------------------
# Report formatting
# ---------------------------------------------------------------------------

def _fmt_line(record: dict, label: str, color: str) -> str:
    direction = "+" if record["pct_change"] >= 0 else ""
    return (
        f"  {colored(label, color)} {colored(record['key'], BOLD)}\n"
        f"    Measured : {record['measured']:.3f} {record['unit']}\n"
        f"    Baseline : {record['baseline']:.3f} {record['unit']}\n"
        f"    Change   : {direction}{record['pct_change']:.1f}%\n"
        f"    Reason   : {record['reason']}\n"
    )


def _print_report(
    regressions: list[dict],
    warnings: list[dict],
    passing: list[dict],
) -> None:
    total = len(regressions) + len(warnings) + len(passing)
    bar = colored("═" * 60, BLUE)

    print()
    print(bar)
    print(colored("  ILS Performance Regression Report", BOLD))
    print(bar)
    print()

    if passing:
        print(colored(f"✅  PASSING ({len(passing)})", GREEN))
        for r in passing:
            direction = "+" if r["pct_change"] >= 0 else ""
            print(
                f"  {colored('PASS', GREEN)} {r['key']}: "
                f"{r['measured']:.3f} {r['unit']} "
                f"({direction}{r['pct_change']:.1f}%)"
            )
        print()

    if warnings:
        print(colored(f"⚠️   WARNINGS ({len(warnings)})", YELLOW))
        for r in warnings:
            print(_fmt_line(r, "WARN", YELLOW), end="")
        print()

    if regressions:
        print(colored(f"❌  REGRESSIONS ({len(regressions)})", RED))
        for r in regressions:
            print(_fmt_line(r, "FAIL", RED), end="")
        print()

    print(
        bar + "\n"
        f"  Checked: {total}  |  "
        + colored(f"Passed: {len(passing)}", GREEN) + "  |  "
        + colored(f"Warnings: {len(warnings)}", YELLOW) + "  |  "
        + colored(
            f"Regressions: {len(regressions)}",
            RED if regressions else GREEN,
        )
    )
    print(bar)
    print()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="check-performance-regression.py",
        description=(
            "Compare measured performance metrics against baselines.\n"
            "Exits with code 1 if any metric regresses more than the threshold."
        ),
        formatter_class=_CapitalUsageFormatter,
        epilog=(
            "Examples:\n"
            "  %(prog)s metrics.json\n"
            "  %(prog)s -b performance-baselines.json metrics.json\n"
            "  %(prog)s --threshold 5 metrics.json\n"
            "  %(prog)s --warn-only metrics.json\n"
            "  %(prog)s -o report.json metrics.json\n"
        ),
    )

    parser.add_argument(
        "metrics_file",
        help=(
            "Path to metrics JSON file. Accepts either a flat {key: value} object, "
            "a {metrics: {key: value}} object, or a xcresult array from "
            "extract-performance-metrics.sh."
        ),
    )
    parser.add_argument(
        "-b", "--baselines",
        default=None,
        metavar="FILE",
        help=(
            "Path to baselines JSON file "
            "(default: performance-baselines.json in project root)."
        ),
    )
    parser.add_argument(
        "-t", "--threshold",
        type=float,
        default=None,
        metavar="PCT",
        help=(
            "Override regression threshold percentage "
            "(default: regression_threshold_pct from baselines file, typically 10)."
        ),
    )
    parser.add_argument(
        "--warn-only",
        action="store_true",
        help="Report regressions as warnings but always exit 0.",
    )
    parser.add_argument(
        "-o", "--output",
        default=None,
        metavar="FILE",
        help="Write JSON report to FILE in addition to stdout.",
    )
    parser.add_argument(
        "-q", "--quiet",
        action="store_true",
        help="Suppress human-readable output (useful with --output).",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Show verbose output including skipped/unmapped metrics.",
    )

    return parser


def main() -> int:
    parser = _build_parser()
    args = parser.parse_args()

    # Resolve baselines path
    if args.baselines:
        baselines_path = args.baselines
    else:
        script_dir = Path(__file__).resolve().parent
        baselines_path = str(script_dir.parent / "performance-baselines.json")

    # Load baselines
    if not os.path.exists(baselines_path):
        print(
            colored(f"[ERROR] Baselines file not found: {baselines_path}", RED),
            file=sys.stderr,
        )
        return 2

    try:
        baselines = _load_json(baselines_path)
    except (json.JSONDecodeError, OSError) as exc:
        print(colored(f"[ERROR] Failed to load baselines: {exc}", RED), file=sys.stderr)
        return 2

    # Load metrics
    if not os.path.exists(args.metrics_file):
        print(
            colored(f"[ERROR] Metrics file not found: {args.metrics_file}", RED),
            file=sys.stderr,
        )
        return 2

    try:
        raw_metrics = _load_json(args.metrics_file)
    except (json.JSONDecodeError, OSError) as exc:
        print(colored(f"[ERROR] Failed to load metrics: {exc}", RED), file=sys.stderr)
        return 2

    try:
        measured = _normalize_metrics(raw_metrics)
    except ValueError as exc:
        print(colored(f"[ERROR] {exc}", RED), file=sys.stderr)
        return 2

    if not measured:
        print(colored("[WARNING] No numeric metrics found in metrics file.", YELLOW), file=sys.stderr)
        return 0

    if args.verbose:
        print(colored(f"[INFO] Loaded {len(measured)} metrics from: {args.metrics_file}", BLUE))
        print(colored(f"[INFO] Baselines file: {baselines_path}", BLUE))
        if args.threshold is not None:
            print(colored(f"[INFO] Threshold override: {args.threshold}%", BLUE))

    # Compare
    regressions, warnings, passing = _check_regressions(
        measured,
        baselines,
        threshold_pct=args.threshold,
        verbose=args.verbose,
    )

    # Human-readable report
    if not args.quiet:
        _print_report(regressions, warnings, passing)

    # Optional JSON report
    if args.output:
        report = {
            "summary": {
                "total_checked": len(regressions) + len(warnings) + len(passing),
                "passed": len(passing),
                "warnings": len(warnings),
                "regressions": len(regressions),
                "regression_detected": len(regressions) > 0,
            },
            "regressions": regressions,
            "warnings": warnings,
            "passing": passing,
        }
        try:
            with open(args.output, "w", encoding="utf-8") as fh:
                json.dump(report, fh, indent=2)
            if not args.quiet:
                print(colored(f"[INFO] JSON report written to: {args.output}", BLUE))
        except OSError as exc:
            print(colored(f"[ERROR] Failed to write report: {exc}", RED), file=sys.stderr)

    # Exit code
    if regressions and not args.warn_only:
        if not args.quiet:
            print(colored("❌  Performance regression detected — failing.", RED))
        return 1

    if not args.quiet:
        if regressions:
            print(colored("⚠️   Regressions present (warn-only mode) — passing.", YELLOW))
        else:
            print(colored("✅  No performance regressions detected.", GREEN))

    return 0


if __name__ == "__main__":
    sys.exit(main())
