#!/usr/bin/env python3
"""
results-aggregator.py — Combine per-run metrics JSONs into a comparison table.

Usage:
    python3 results-aggregator.py results/metrics-runA.json results/metrics-runB.json [...]

Emits a JSON comparison table with one column per input run, side-by-side on
stdout, plus a compact human-readable summary on stderr.

Each input JSON is expected to be the output of scripts/score.sh for a run —
i.e. a flat dict with keys like `tag`, `files`, `lines`, `impl_time_s`,
`fix_time_s`, `total_time_s`, `error_convergence`, `clean_build_cycle`,
`launch_avg_ms`, `launch_stddev_ms`.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


METRIC_ORDER = [
    "files",
    "lines",
    "impl_time_s",
    "fix_time_s",
    "total_time_s",
    "error_convergence",
    "clean_build_cycle",
    "launch_avg_ms",
    "launch_stddev_ms",
]


def fmt(value) -> str:
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:.2f}"
    return str(value)


def main() -> int:
    if len(sys.argv) < 3:
        print(
            "usage: results-aggregator.py metrics-A.json metrics-B.json [...]",
            file=sys.stderr,
        )
        return 1

    runs: list[dict] = []
    for arg in sys.argv[1:]:
        path = Path(arg)
        if not path.exists():
            print(f"[skip] {path} not found", file=sys.stderr)
            continue
        data = json.loads(path.read_text())
        runs.append(data)

    if not runs:
        print("No valid inputs", file=sys.stderr)
        return 1

    tags = [r.get("tag", Path(a).stem) for r, a in zip(runs, sys.argv[1:])]

    comparison = {"tags": tags, "metrics": {}}
    for key in METRIC_ORDER:
        comparison["metrics"][key] = [r.get(key) for r in runs]

    # derived: self_repair_ratio = fix_time / total_time
    comparison["metrics"]["self_repair_ratio_pct"] = []
    for r in runs:
        total = r.get("total_time_s") or 0
        fix = r.get("fix_time_s") or 0
        ratio = (fix / total * 100) if total else None
        comparison["metrics"]["self_repair_ratio_pct"].append(
            round(ratio, 1) if ratio is not None else None
        )

    # stdout: machine-readable
    print(json.dumps(comparison, indent=2))

    # stderr: human-readable table
    col_width = max(18, max(len(t) for t in tags) + 2)
    print("", file=sys.stderr)
    print(f"{'metric':<24}" + "".join(f"{t:>{col_width}}" for t in tags), file=sys.stderr)
    print("-" * (24 + col_width * len(tags)), file=sys.stderr)
    for key, values in comparison["metrics"].items():
        row = f"{key:<24}" + "".join(f"{fmt(v):>{col_width}}" for v in values)
        print(row, file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
