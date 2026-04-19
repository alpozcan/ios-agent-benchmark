#!/usr/bin/env python3
"""
OQM Scorer — Output Quality Metric Calculator

Reads raw metrics from gather-metrics.py output and calculates weighted composite scores.

Usage:
    python3 oqm-scorer.py raw-metrics.json
    python3 oqm-scorer.py raw-metrics.json --build-errors build-a:18 build-b:2
    python3 oqm-scorer.py raw-metrics.json --html results/oqm-radar.html
"""

import json
import argparse
import sys


# ═══ Scoring Functions ═══

def score_dry(d):
    score = 100
    score -= min(d.get("dry_uuid_inits", 0) * 2, 20)
    score -= min(d.get("dry_empty_catch", 0) * 10, 20)
    return max(0, score)


def score_solid(d):
    score = 0
    # [S] Single Responsibility
    s = 100 - min(d.get("god_classes", 0) * 12, 60)
    score += s * 0.2
    # [O] Open/Closed
    o = min(d.get("solid_protocols", 0) * 10 + d.get("solid_protocol_conformances", 0) * 3, 100)
    score += o * 0.2
    # [L] Liskov
    l = min(d.get("solid_protocol_extensions", 0) * 30, 60)
    score += l * 0.2
    # [I] Interface Segregation
    if d.get("solid_protocols", 0) > 0:
        avg = d.get("solid_protocol_conformances", 0) / d["solid_protocols"]
        i = 100 if avg < 8 else max(0, 100 - (avg - 8) * 10)
    else:
        i = 0
    score += i * 0.2
    # [D] Dependency Inversion
    dd = max(0, 100 - d.get("solid_concrete_in_ui", 0) * 15)
    score += dd * 0.2
    return min(100, max(0, score))


def score_security(d):
    score = 0
    val = min(d.get("sec_input_validation", 0) * 1.5 + d.get("sec_sanitization", 0) * 5, 100)
    score += val * 0.33
    safety = min(d.get("sendable", 0) * 4 + d.get("sec_weak_var", 0) * 5, 100)
    score += safety * 0.33
    danger = d.get("force_unwrap", 0) + d.get("try_bang", 0) * 5 + d.get("fatalError", 0) * 5
    score += max(0, 100 - danger * 10) * 0.34
    return min(100, max(0, score))


def score_critical_bugs(build_errors, d):
    score = 100
    score -= min(build_errors * 3, 40)
    score -= max(0, (build_errors - 8) * 1.5)
    score -= d.get("force_unwrap", 0) * 3
    score -= d.get("unchecked_sendable", 0) * 2
    leaks = max(0, d.get("closures_with_self", 0) - d.get("closures_weak_self", 0))
    score -= min(leaks * 0.5, 8)
    return max(0, score)


def score_api_accuracy(api_errors, schema_ok, d):
    score = 100
    score -= api_errors * 6
    if not schema_ok:
        score -= 15
    return max(0, score)


def score_ios(d):
    score = 0
    modern = d.get("ios_observable", 0) * 10 + d.get("ios_state", 0) + d.get("ios_onChange", 0) * 3
    score += min(modern, 80) * 0.2
    sd = d.get("ios_predicate", 0) * 5 + d.get("ios_transient", 0) * 5
    score += min(sd, 100) * 0.2
    a11y = d.get("ios_accessibility", 0) * 3
    score += min(a11y, 100) * 0.2
    l10n = d.get("ios_localization", 0)
    score += min(l10n, 100) * 0.2
    binding = d.get("ios_binding", 0) * 10
    score += min(binding, 100) * 0.2
    return min(100, max(0, score))


def score_architecture(d):
    score = 0
    abstraction = min(d.get("generics", 0) * 4 + d.get("typealias", 0) * 5 + d.get("enums", 0) * 1.5, 100)
    score += abstraction * 0.33
    errors = min(d.get("throw_throws", 0) * 8 + d.get("custom_errors", 0) * 6 + d.get("result_type", 0) * 8, 100)
    score += errors * 0.33
    pe = d.get("solid_protocol_extensions", 0) * 25
    score += min(pe, 100) * 0.34
    return min(100, max(0, score))


def score_readability(d):
    score = 0
    docs = min(d.get("doc_comments", 0) * 0.5, 50)
    score += docs * 0.3
    priv = min(d.get("solid_types", 0) * 0.3, 30)  # proxy for encapsulation
    score += priv * 0.3
    clean = max(0, 100 - d.get("print_debug", 0) * 5)
    score += clean * 0.4
    return min(100, max(0, score))


def score_efficiency(lines, files, turns, time_s, build_errors):
    compiling_pct = (lines - build_errors * 30) / max(lines, 1)
    score = compiling_pct * 40
    tpf = turns / max(files, 1)
    score += max(0, 100 - tpf * 10) * 0.3
    lpm = lines / max(time_s / 60, 0.1)
    score += min(lpm * 0.5, 30)
    return min(100, max(0, score))


# ═══ Weights ═══

WEIGHTS = {
    "critical_bugs": 0.25,
    "api_accuracy": 0.20,
    "security": 0.12,
    "solid": 0.10,
    "architecture": 0.08,
    "ios_practices": 0.08,
    "dry": 0.06,
    "readability": 0.06,
    "efficiency": 0.05,
}


def grade(score):
    if score >= 90: return "A+"
    if score >= 85: return "A"
    if score >= 80: return "A-"
    if score >= 75: return "B+"
    if score >= 70: return "B"
    if score >= 65: return "B-"
    if score >= 55: return "C"
    if score >= 40: return "D"
    return "F"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("metrics_file", help="JSON from gather-metrics.py")
    parser.add_argument("--build-errors", nargs=2, type=int, default=[0, 0], metavar=("A", "B"))
    parser.add_argument("--api-errors", nargs=2, type=int, default=[0, 0], metavar=("A", "B"))
    parser.add_argument("--schema-ok", nargs=2, type=int, default=[1, 1], metavar=("A", "B"))
    parser.add_argument("--turns", nargs=2, type=int, default=[50, 50], metavar=("A", "B"))
    parser.add_argument("--time-s", nargs=2, type=float, default=[1000, 1000], metavar=("A", "B"))
    parser.add_argument("--names", nargs=2, default=["model-a", "model-b"])
    args = parser.parse_args()

    with open(args.metrics_file) as f:
        raw = json.load(f)

    names = args.names
    datas = [raw[names[0]], raw[names[1]]]
    build_errs = args.build_errors
    api_errs = args.api_errors
    schema_ok = [bool(x) for x in args.schema_ok]
    turns = args.turns
    times = args.time_s

    print("=" * 65)
    print("  OUTPUT QUALITY METRIC (OQM)")
    print("  Weights:", " ".join(f"{k}({int(v*100)}%)" for k, v in WEIGHTS.items()))
    print("=" * 65)

    results = {}
    for i, (name, d) in enumerate(zip(names, datas)):
        scores = {
            "critical_bugs": score_critical_bugs(build_errs[i], d),
            "api_accuracy": score_api_accuracy(api_errs[i], schema_ok[i], d),
            "security": score_security(d),
            "solid": score_solid(d),
            "architecture": score_architecture(d),
            "ios_practices": score_ios(d),
            "dry": score_dry(d),
            "readability": score_readability(d),
            "efficiency": score_efficiency(d["lines"], d["files"], turns[i], times[i], build_errs[i]),
        }
        composite = sum(scores[k] * WEIGHTS[k] for k in WEIGHTS)
        scores["composite"] = composite
        results[name] = scores

    print(f"\n  {'Dimension':<20} {'Weight':>7} {names[0]:>10} {names[1]:>10} {'Delta':>8}")
    print(f"  {'─' * 58}")
    for dim in WEIGHTS:
        s0 = results[names[0]][dim]
        s1 = results[names[1]][dim]
        delta = s1 - s0
        sign = "+" if delta > 0 else ""
        print(f"  {dim:<20} {WEIGHTS[dim]:>6.0%} {s0:>10.1f} {s1:>10.1f} {sign}{delta:>7.1f}")

    print(f"  {'─' * 58}")
    c0 = results[names[0]]["composite"]
    c1 = results[names[1]]["composite"]
    delta = c1 - c0
    sign = "+" if delta > 0 else ""
    print(f"  {'COMPOSITE OQM':<20} {'':>7} {c0:>10.1f} {c1:>10.1f} {sign}{delta:>7.1f}")
    print()
    print(f"  {names[0]}: {grade(c0)} ({c0:.1f}/100)")
    print(f"  {names[1]}: {grade(c1)} ({c1:.1f}/100)")

    return results


if __name__ == "__main__":
    main()
