#!/usr/bin/env python3
"""ILS iOS App - Reliability Metrics Release Notes Generator

Loads the latest performance-history/ JSON snapshot and combines it with
CLI-supplied crash-free rate and session count to produce a Markdown release
notes block suitable for App Store submissions, GitHub releases, or CI
job summaries.

Metrics reported:
  - Crash-free sessions % (supplied via --crash-free-rate)
  - Memory ceiling        (memory_chat_active_mb from latest history file)
  - Energy impact summary (idle_cpu_pct, chat_streaming_cpu_pct)

Each metric is compared against performance-baselines.json thresholds and
assigned one of three statuses:
  ✅ pass  — at or below warning_threshold  (or at/above for crash-free)
  ⚠️ warn  — between warning and fail thresholds
  ❌ fail  — beyond fail_threshold

Usage:
  python3 scripts/generate-release-notes.py --crash-free-rate 99.8 --session-count 1500
"""

import argparse
import json
import os
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Custom argparse formatter so --help starts with "Usage:" (capital U)
# ---------------------------------------------------------------------------

class _CapitalUsageFormatter(argparse.RawDescriptionHelpFormatter):
    def _format_usage(self, usage, actions, groups, prefix=None):
        if prefix is None:
            prefix = "Usage: "
        return super()._format_usage(usage, actions, groups, prefix)


# ---------------------------------------------------------------------------
# History file loading — return the single latest snapshot
# ---------------------------------------------------------------------------

def load_latest_history(history_dir: str) -> dict:
    """Return the most recent history JSON entry, or an empty dict if none found.

    Files are sorted by the ``timestamp`` field inside each JSON document,
    falling back to the filename (which is also timestamp-prefixed) so that
    lexicographic order matches chronological order.
    """
    dir_path = Path(history_dir)
    if not dir_path.is_dir():
        return {}

    entries = []
    for p in sorted(dir_path.glob("*.json")):
        try:
            with open(p, encoding="utf-8") as fh:
                data = json.load(fh)
            data["_filename"] = p.name
            entries.append(data)
        except (json.JSONDecodeError, OSError):
            continue

    if not entries:
        return {}

    def _sort_key(entry: dict) -> str:
        return entry.get("timestamp", "") or entry.get("_filename", "")

    entries.sort(key=_sort_key)
    return entries[-1]


# ---------------------------------------------------------------------------
# Threshold evaluation
# ---------------------------------------------------------------------------

def _metric_status(value: float, spec: dict, higher_is_worse: bool = True) -> str:
    """Return 'pass', 'warn', or 'fail' for a metric value against its spec.

    Parameters
    ----------
    value:
        The measured value.
    spec:
        Dict with ``warning_threshold`` and ``fail_threshold`` keys.
    higher_is_worse:
        True  (default) — exceeding thresholds is bad (CPU, memory).
        False           — falling below thresholds is bad (crash-free rate).
    """
    warn_threshold = spec.get("warning_threshold")
    fail_threshold = spec.get("fail_threshold")

    if higher_is_worse:
        if fail_threshold is not None and value > fail_threshold:
            return "fail"
        if warn_threshold is not None and value > warn_threshold:
            return "warn"
        return "pass"
    else:
        # Lower is worse (e.g. crash-free rate)
        if fail_threshold is not None and value < fail_threshold:
            return "fail"
        if warn_threshold is not None and value < warn_threshold:
            return "warn"
        return "pass"


def _status_icon(status: str) -> str:
    """Return a Markdown-friendly emoji for a pass/warn/fail status string."""
    return {"pass": "✅", "warn": "⚠️", "fail": "❌"}.get(status, "❓")


def _status_label(status: str) -> str:
    """Return a human-readable label for a pass/warn/fail status string."""
    return {"pass": "Pass", "warn": "Warning", "fail": "Fail"}.get(status, status)


# ---------------------------------------------------------------------------
# Markdown generation
# ---------------------------------------------------------------------------

def generate_markdown(
    crash_free_rate: float,
    session_count: int,
    latest_metrics: dict,
    baselines: dict,
    commit_sha: str = "",
    branch: str = "",
    timestamp: str = "",
) -> str:
    """Return the full Markdown release notes block as a single string."""
    lines = []
    baseline_metrics: dict = baselines.get("metrics", {})

    lines.append("## Reliability Metrics")
    lines.append("")

    # Commit / snapshot context
    if commit_sha or timestamp:
        sha_part = f"`{commit_sha[:8]}`" if commit_sha else ""
        branch_part = f" on `{branch}`" if branch else ""
        ts_part = f" — {timestamp[:10]}" if timestamp else ""
        context = " ".join(filter(None, [sha_part + branch_part + ts_part]))
        if context:
            lines.append(f"_Latest CI snapshot: {context.strip()}_")
            lines.append("")

    # -----------------------------------------------------------------------
    # 1. Crash-free sessions
    # -----------------------------------------------------------------------
    crash_free_spec = baseline_metrics.get("crash_free_sessions_pct", {})
    crash_free_status = _metric_status(crash_free_rate, crash_free_spec, higher_is_worse=False)
    crash_free_icon = _status_icon(crash_free_status)
    crash_free_baseline = crash_free_spec.get("baseline_value", 100.0)

    lines.append("### Crash-Free Sessions")
    lines.append("")
    lines.append(
        f"| Metric | Value | Sessions | Baseline | Status |"
    )
    lines.append(
        f"| ------ | ----- | -------- | -------- | ------ |"
    )
    lines.append(
        f"| Crash-free rate |"
        f" **{crash_free_rate:.1f}%** |"
        f" {session_count:,} |"
        f" {crash_free_baseline:.1f}% |"
        f" {crash_free_icon} {_status_label(crash_free_status)} |"
    )
    lines.append("")

    # -----------------------------------------------------------------------
    # 2. Memory ceiling (memory_chat_active_mb)
    # -----------------------------------------------------------------------
    MEMORY_KEY = "memory_chat_active_mb"
    memory_spec = baseline_metrics.get(MEMORY_KEY, {})
    memory_value = latest_metrics.get(MEMORY_KEY)

    lines.append("### Memory Ceiling")
    lines.append("")

    if memory_value is not None:
        memory_value = float(memory_value)
        memory_status = _metric_status(memory_value, memory_spec, higher_is_worse=True)
        memory_icon = _status_icon(memory_status)
        memory_baseline = memory_spec.get("baseline_value", "N/A")
        memory_warn = memory_spec.get("warning_threshold", "N/A")
        memory_fail = memory_spec.get("fail_threshold", "N/A")

        lines.append("| Metric | Value | Baseline | Warn Threshold | Fail Threshold | Status |")
        lines.append("| ------ | ----- | -------- | -------------- | -------------- | ------ |")
        lines.append(
            f"| Active chat memory (peak) |"
            f" **{memory_value:.1f} MB** |"
            f" {memory_baseline} MB |"
            f" {memory_warn} MB |"
            f" {memory_fail} MB |"
            f" {memory_icon} {_status_label(memory_status)} |"
        )
    else:
        lines.append(
            "_Memory ceiling data not available in latest history snapshot._"
        )
    lines.append("")

    # -----------------------------------------------------------------------
    # 3. Energy impact summary (idle_cpu_pct, chat_streaming_cpu_pct)
    # -----------------------------------------------------------------------
    ENERGY_KEYS = [
        ("idle_cpu_pct", "Idle CPU"),
        ("chat_streaming_cpu_pct", "Chat streaming CPU"),
    ]

    lines.append("### Energy Impact")
    lines.append("")
    lines.append("| Metric | Value | Baseline | Warn Threshold | Fail Threshold | Status |")
    lines.append("| ------ | ----- | -------- | -------------- | -------------- | ------ |")

    any_energy_data = False
    for key, label in ENERGY_KEYS:
        spec = baseline_metrics.get(key, {})
        value = latest_metrics.get(key)
        if value is None:
            lines.append(
                f"| {label} | _no data_ | — | — | — | — |"
            )
            continue

        any_energy_data = True
        value = float(value)
        status = _metric_status(value, spec, higher_is_worse=True)
        icon = _status_icon(status)
        baseline_value = spec.get("baseline_value", "N/A")
        warn_threshold = spec.get("warning_threshold", "N/A")
        fail_threshold = spec.get("fail_threshold", "N/A")
        unit = spec.get("unit", "percent")
        unit_label = "%" if "percent" in unit else unit

        lines.append(
            f"| {label} |"
            f" **{value:.1f}{unit_label}** |"
            f" {baseline_value}{unit_label} |"
            f" {warn_threshold}{unit_label} |"
            f" {fail_threshold}{unit_label} |"
            f" {icon} {_status_label(status)} |"
        )

    if not any_energy_data:
        lines.append("")
        lines.append(
            "_Energy impact data not available in latest history snapshot._"
        )
    lines.append("")

    # -----------------------------------------------------------------------
    # 4. Overall status summary
    # -----------------------------------------------------------------------
    all_statuses = [crash_free_status]

    if memory_value is not None:
        all_statuses.append(
            _metric_status(float(memory_value), memory_spec, higher_is_worse=True)
        )

    for key, _ in ENERGY_KEYS:
        v = latest_metrics.get(key)
        if v is not None:
            spec = baseline_metrics.get(key, {})
            all_statuses.append(_metric_status(float(v), spec, higher_is_worse=True))

    if "fail" in all_statuses:
        overall_icon = "❌"
        overall_text = "One or more metrics exceeded the fail threshold."
    elif "warn" in all_statuses:
        overall_icon = "⚠️"
        overall_text = "One or more metrics exceeded the warning threshold."
    else:
        overall_icon = "✅"
        overall_text = "All reliability metrics are within acceptable bounds."

    lines.append("### Overall Status")
    lines.append("")
    lines.append(f"{overall_icon} **{overall_text}**")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="generate-release-notes.py",
        description=(
            "Generate a Markdown reliability metrics block from the latest\n"
            "performance-history/ snapshot and CLI-supplied crash stats.\n"
            "Pipe the output to $GITHUB_STEP_SUMMARY or include in release notes."
        ),
        formatter_class=_CapitalUsageFormatter,
        epilog=(
            "Examples:\n"
            "  %(prog)s --crash-free-rate 99.8 --session-count 1500\n"
            "  %(prog)s --crash-free-rate 100.0 --session-count 500 -o release-notes.md\n"
            "  %(prog)s --crash-free-rate 98.5 --session-count 200 >> $GITHUB_STEP_SUMMARY\n"
        ),
    )

    parser.add_argument(
        "--crash-free-rate",
        type=float,
        required=True,
        metavar="FLOAT",
        help="Crash-free session rate as a percentage (e.g. 99.8 means 99.8%%).",
    )
    parser.add_argument(
        "--session-count",
        type=int,
        required=True,
        metavar="INT",
        help="Total number of sessions measured for the crash-free rate.",
    )
    parser.add_argument(
        "-d", "--history-dir",
        default=None,
        metavar="DIR",
        help=(
            "Path to the performance history directory "
            "(default: performance-history/ in project root)."
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
        "-o", "--output",
        default=None,
        metavar="FILE",
        help="Write Markdown output to FILE instead of stdout.",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Print progress information to stderr.",
    )

    return parser


def main() -> int:
    parser = _build_parser()
    args = parser.parse_args()

    # Validate crash-free rate range
    if not 0.0 <= args.crash_free_rate <= 100.0:
        print(
            f"[ERROR] --crash-free-rate must be between 0.0 and 100.0 "
            f"(got {args.crash_free_rate})",
            file=sys.stderr,
        )
        return 2

    if args.session_count < 0:
        print(
            f"[ERROR] --session-count must be a non-negative integer "
            f"(got {args.session_count})",
            file=sys.stderr,
        )
        return 2

    # Resolve paths relative to project root (script lives in scripts/)
    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent

    history_dir = args.history_dir or str(project_root / "performance-history")
    baselines_path = args.baselines or str(project_root / "performance-baselines.json")

    # Load baselines
    if not os.path.exists(baselines_path):
        print(f"[ERROR] Baselines file not found: {baselines_path}", file=sys.stderr)
        return 2

    try:
        with open(baselines_path, encoding="utf-8") as fh:
            baselines = json.load(fh)
    except (json.JSONDecodeError, OSError) as exc:
        print(f"[ERROR] Failed to load baselines: {exc}", file=sys.stderr)
        return 2

    # Load latest history snapshot
    latest = load_latest_history(history_dir)
    latest_metrics: dict = latest.get("metrics", {})
    commit_sha: str = latest.get("commit_sha", "")
    branch: str = latest.get("branch", "")
    timestamp: str = latest.get("timestamp", "")

    if args.verbose:
        print(f"[INFO] History directory  : {history_dir}", file=sys.stderr)
        print(f"[INFO] Latest snapshot    : {latest.get('_filename', 'none')}", file=sys.stderr)
        print(f"[INFO] Baselines file     : {baselines_path}", file=sys.stderr)
        print(f"[INFO] Crash-free rate    : {args.crash_free_rate}%", file=sys.stderr)
        print(f"[INFO] Session count      : {args.session_count}", file=sys.stderr)

    # Generate Markdown
    markdown = generate_markdown(
        crash_free_rate=args.crash_free_rate,
        session_count=args.session_count,
        latest_metrics=latest_metrics,
        baselines=baselines,
        commit_sha=commit_sha,
        branch=branch,
        timestamp=timestamp,
    )

    # Write or print output
    if args.output:
        try:
            with open(args.output, "w", encoding="utf-8") as fh:
                fh.write(markdown)
                fh.write("\n")
            if args.verbose:
                print(f"[INFO] Report written to: {args.output}", file=sys.stderr)
        except OSError as exc:
            print(f"[ERROR] Failed to write output: {exc}", file=sys.stderr)
            return 2
    else:
        print(markdown)

    return 0


if __name__ == "__main__":
    sys.exit(main())
