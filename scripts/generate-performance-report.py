#!/usr/bin/env python3
"""ILS iOS App - Performance Trend Report Generator

Reads performance-history/ JSON files and generates a GitHub Actions Markdown
job summary showing metric trends over the last 30 CI builds.

History file format (YYYYMMDD_HHMMSS_<sha8>.json):
  {
    "timestamp":  "2026-03-01T12:00:00Z",
    "commit_sha": "abc12345",
    "branch":     "master",
    "metrics":    { "cold_launch_seconds": 2.3, "session_scroll_cpu_pct": 38.5, ... }
  }

Icon legend in output tables:
  🔴  value exceeds fail_threshold (regression)
  🟡  value exceeds warning_threshold (caution)
  🟢  value improved more than 5% below baseline
  ⚪  stable — within warning bounds
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
# History file loading
# ---------------------------------------------------------------------------

def load_history_files(history_dir: str, limit: int = 30) -> list:
    """Load, sort, and return the last ``limit`` history JSON files.

    Files are sorted by the ``timestamp`` field inside each JSON document,
    falling back to the filename (which is also timestamp-prefixed) so that
    lexicographic order matches chronological order.
    """
    dir_path = Path(history_dir)
    if not dir_path.is_dir():
        return []

    entries = []
    for p in sorted(dir_path.glob("*.json")):
        try:
            with open(p, encoding="utf-8") as fh:
                data = json.load(fh)
            data["_filename"] = p.name
            entries.append(data)
        except (json.JSONDecodeError, OSError):
            continue

    def _sort_key(entry: dict) -> str:
        return entry.get("timestamp", "") or entry.get("_filename", "")

    entries.sort(key=_sort_key)
    return entries[-limit:]


# ---------------------------------------------------------------------------
# Trend icon helper
# ---------------------------------------------------------------------------

def _trend_icon(value: float, baseline_spec: dict) -> str:
    """Return an emoji icon representing how ``value`` compares to thresholds."""
    fail_threshold = baseline_spec.get("fail_threshold")
    warning_threshold = baseline_spec.get("warning_threshold")
    baseline_value = baseline_spec.get("baseline_value")

    if fail_threshold is not None and value > fail_threshold:
        return "🔴"
    if warning_threshold is not None and value > warning_threshold:
        return "🟡"
    if isinstance(baseline_value, (int, float)) and baseline_value > 0:
        if value < baseline_value * 0.95:
            return "🟢"
    return "⚪"


# ---------------------------------------------------------------------------
# Per-metric statistics
# ---------------------------------------------------------------------------

def _compute_stats(values: list) -> dict:
    """Return min / max / avg / latest for a list of float values."""
    if not values:
        return {}
    return {
        "min": min(values),
        "max": max(values),
        "avg": sum(values) / len(values),
        "latest": values[-1],
        "count": len(values),
    }


# ---------------------------------------------------------------------------
# Markdown generation
# ---------------------------------------------------------------------------

def generate_markdown(
    history: list,
    baselines: dict,
    title: str = "Performance Trend Dashboard",
    artifact_run_url: str = "",
) -> str:
    """Return the full Markdown report as a single string."""
    lines = []

    lines.append(f"## {title}")
    lines.append("")

    if not history:
        lines.append("_No performance history data found in `performance-history/`._")
        lines.append("")
        lines.append(
            "Populate the history directory by running CI on the master branch. "
            "The workflow saves one JSON file per run to `performance-history/`."
        )
        return "\n".join(lines)

    baseline_metrics: dict = baselines.get("metrics", {})

    # All metric keys that appear in history AND have a baseline entry
    all_keys = sorted(
        {k for entry in history for k in entry.get("metrics", {}).keys()}
        & set(baseline_metrics.keys())
    )

    # Per-metric statistics across the full window
    metric_stats: dict = {}
    for key in all_keys:
        values = [
            float(entry["metrics"][key])
            for entry in history
            if key in entry.get("metrics", {})
        ]
        if values:
            metric_stats[key] = _compute_stats(values)

    # -----------------------------------------------------------------------
    # Header summary
    # -----------------------------------------------------------------------
    window = len(history)
    first_ts = (history[0].get("timestamp", "") or "")[:10]
    last_ts = (history[-1].get("timestamp", "") or "")[:10]
    last_sha = (history[-1].get("commit_sha", "") or "")[:8]
    last_branch = history[-1].get("branch", "") or ""

    date_range = ""
    if first_ts and last_ts and first_ts != last_ts:
        date_range = f" ({first_ts} → {last_ts})"
    elif last_ts:
        date_range = f" ({last_ts})"

    lines.append(
        f"**Window:** last {window} build{'s' if window != 1 else ''}{date_range}"
    )
    if last_sha:
        branch_part = f" on `{last_branch}`" if last_branch else ""
        lines.append(f"**Latest commit:** `{last_sha}`{branch_part}")
    lines.append("")
    lines.append(
        "Icon legend: 🔴 regression &nbsp;·&nbsp; 🟡 warning "
        "&nbsp;·&nbsp; 🟢 improved &nbsp;·&nbsp; ⚪ stable"
    )
    lines.append("")

    if not metric_stats:
        lines.append("_No metrics matched baseline keys in the history files._")
        return "\n".join(lines)

    # -----------------------------------------------------------------------
    # Trend table: metrics × recent builds (up to 15 columns to avoid overflow)
    # -----------------------------------------------------------------------
    DISPLAY_BUILDS = min(15, len(history))
    display_history = history[-DISPLAY_BUILDS:]

    build_labels = []
    for entry in display_history:
        sha = (entry.get("commit_sha", "") or "")[:6]
        ts = (entry.get("timestamp", "") or "")
        label = sha if sha else ts[:10] if ts else "?"
        build_labels.append(f"`{label}`")

    lines.append("### Metric Trends")
    lines.append("")

    header_cols = " | ".join(build_labels)
    sep_cols = " | ".join(["---"] * DISPLAY_BUILDS)
    lines.append(f"| Metric | Unit | Baseline | Avg ({window}) | {header_cols} |")
    lines.append(f"| ------ | ---- | -------- | --- | {sep_cols} |")

    for key in all_keys:
        if key not in metric_stats:
            continue
        spec = baseline_metrics.get(key, {})
        unit = spec.get("unit", "")
        baseline_value = spec.get("baseline_value")
        stats = metric_stats[key]

        baseline_str = f"{baseline_value:.2f}" if isinstance(baseline_value, (int, float)) else "N/A"
        avg_str = f"{stats['avg']:.2f}"

        cells = []
        for entry in display_history:
            raw = entry.get("metrics", {}).get(key)
            if raw is None:
                cells.append("—")
            else:
                v = float(raw)
                icon = _trend_icon(v, spec)
                cells.append(f"{icon} {v:.2f}")

        row = " | ".join(cells)
        lines.append(f"| `{key}` | {unit} | {baseline_str} | {avg_str} | {row} |")

    lines.append("")

    # -----------------------------------------------------------------------
    # Summary statistics table (min / max / avg / latest vs baseline)
    # -----------------------------------------------------------------------
    lines.append(f"### Summary Statistics (last {window} builds)")
    lines.append("")
    lines.append("| Metric | Min | Max | Avg | Latest | Baseline | Status |")
    lines.append("| ------ | --- | --- | --- | ------ | -------- | ------ |")

    for key in all_keys:
        if key not in metric_stats:
            continue
        spec = baseline_metrics.get(key, {})
        stats = metric_stats[key]
        baseline_value = spec.get("baseline_value")
        unit = spec.get("unit", "")

        icon = _trend_icon(stats["latest"], spec)
        baseline_str = (
            f"{baseline_value:.2f} {unit}"
            if isinstance(baseline_value, (int, float))
            else "N/A"
        )

        lines.append(
            f"| `{key}` |"
            f" {stats['min']:.2f} |"
            f" {stats['max']:.2f} |"
            f" {stats['avg']:.2f} |"
            f" {stats['latest']:.2f} {unit} |"
            f" {baseline_str} |"
            f" {icon} |"
        )

    lines.append("")

    if artifact_run_url:
        lines.append("---")
        lines.append(f"_[View xcresult artifacts]({artifact_run_url})_")
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="generate-performance-report.py",
        description=(
            "Generate a Markdown performance trend dashboard from performance-history/ JSON files.\n"
            "Pipe the output to $GITHUB_STEP_SUMMARY to post it as an Actions job summary."
        ),
        formatter_class=_CapitalUsageFormatter,
        epilog=(
            "Examples:\n"
            "  %(prog)s                               # Print Markdown to stdout\n"
            "  %(prog)s -o report.md                  # Write to file\n"
            "  %(prog)s >> $GITHUB_STEP_SUMMARY       # Append to Actions summary\n"
            "  %(prog)s -d ./perf-history -n 20       # Custom dir, 20-build window\n"
            "  %(prog)s --artifact-url https://...    # Include artifact link footer\n"
        ),
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
        "-n", "--limit",
        type=int,
        default=30,
        metavar="N",
        help="Maximum number of historical builds to include in the window (default: 30).",
    )
    parser.add_argument(
        "-o", "--output",
        default=None,
        metavar="FILE",
        help="Write Markdown output to FILE instead of stdout.",
    )
    parser.add_argument(
        "--title",
        default="Performance Trend Dashboard",
        metavar="TEXT",
        help='Dashboard heading (default: "Performance Trend Dashboard").',
    )
    parser.add_argument(
        "--artifact-url",
        default="",
        metavar="URL",
        help="URL to xcresult artifacts; appended as a footer link.",
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

    # Load history files
    history = load_history_files(history_dir, limit=args.limit)

    if args.verbose:
        print(f"[INFO] History directory : {history_dir}", file=sys.stderr)
        print(f"[INFO] History files     : {len(history)}", file=sys.stderr)
        print(f"[INFO] Baselines file    : {baselines_path}", file=sys.stderr)
        print(f"[INFO] Build window      : {args.limit}", file=sys.stderr)

    # Generate Markdown report
    markdown = generate_markdown(
        history,
        baselines,
        title=args.title,
        artifact_run_url=args.artifact_url,
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
