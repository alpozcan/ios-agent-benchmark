#!/bin/bash
# score.sh — End-to-end metric collection for one run.
#
# Usage:
#   RUN_DIR=./run RUN_TAG=run1 ./scripts/score.sh
#
# Collects:
#   - code volume, SOLID, concurrency, platform, security metrics via gather-metrics.py
#   - build-fix convergence from results/fix-summary-$RUN_TAG.txt
#   - cold launch timings from results/launch-$RUN_TAG.json (if launch-test.sh ran)
#   - writes a single consolidated JSON to results/metrics-$RUN_TAG.json

set -eo pipefail

REPO="${REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
RUN_DIR="${RUN_DIR:?RUN_DIR must be set}"
RUN_DIR="$(cd "$RUN_DIR" && pwd)"
RUN_TAG="${RUN_TAG:?RUN_TAG must be set}"
RESULTS_DIR="${RESULTS_DIR:-$REPO/results}"

log() { echo "[$(date +%H:%M:%S)] $1"; }

mkdir -p "$RESULTS_DIR"

log "----------------------------------------"
log "Scoring ${RUN_TAG}"
log "Run dir: ${RUN_DIR}"
log "Results: ${RESULTS_DIR}"
log "----------------------------------------"

FILES=$(find "$RUN_DIR/Atlas" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
LINES=$(find "$RUN_DIR/Atlas" -name "*.swift" -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
DI_REGS=$(grep -rc 'register(' "$RUN_DIR/Atlas/DI/" --include='*.swift' 2>/dev/null | awk -F: '{s+=$2}END{print s}' || echo 0)
ENTITIES=$(find "$RUN_DIR/Atlas/Data/Entities" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
SCREENS=$(find "$RUN_DIR/Atlas/UI/Screens" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
SEEDS=$(grep -c 'title:' "$RUN_DIR/Atlas/Seeding/TopicSeeds.swift" 2>/dev/null || echo 0)
PROTOCOLS=$(grep -rc '^protocol ' "$RUN_DIR/Atlas/" --include='*.swift' 2>/dev/null | awk -F: '{s+=$2}END{print s}' || echo 0)

IMPL_START=$(cat "$RESULTS_DIR/impl-start-${RUN_TAG}.txt" 2>/dev/null || echo 0)
IMPL_END=$(cat "$RESULTS_DIR/impl-end-${RUN_TAG}.txt" 2>/dev/null || echo 0)
FIX_START=$(cat "$RESULTS_DIR/fix-start-${RUN_TAG}.txt" 2>/dev/null || echo 0)
FIX_END=$(cat "$RESULTS_DIR/fix-end-${RUN_TAG}.txt" 2>/dev/null || echo 0)
IMPL_TIME=$((IMPL_END - IMPL_START))
FIX_TIME=$((FIX_END - FIX_START))
TOTAL_TIME=$((FIX_END - IMPL_START))

CONVERGENCE=""
for c in $(seq 1 7); do
    BUILD_LOG="$RESULTS_DIR/build-${RUN_TAG}-cycle${c}.txt"
    if [ -f "$BUILD_LOG" ]; then
        EC=$(grep -c "error:" "$BUILD_LOG" 2>/dev/null || echo 0)
        CONVERGENCE="${CONVERGENCE}${c}:${EC} "
    fi
done

CLEAN=$(grep "CLEAN_BUILD" "$RESULTS_DIR/fix-summary-${RUN_TAG}.txt" 2>/dev/null || echo "none")

LAUNCH_AVG=""
LAUNCH_STDDEV=""
if [ -f "$RESULTS_DIR/launch-${RUN_TAG}.json" ]; then
    LAUNCH_AVG=$(python3 -c "import json; d=json.load(open('$RESULTS_DIR/launch-${RUN_TAG}.json')); print(d.get('avg_ms', ''))" 2>/dev/null || echo "")
    LAUNCH_STDDEV=$(python3 -c "import json; d=json.load(open('$RESULTS_DIR/launch-${RUN_TAG}.json')); print(d.get('stddev_ms', ''))" 2>/dev/null || echo "")
fi

python3 - "$RUN_TAG" "$FILES" "$LINES" "$DI_REGS" "$ENTITIES" "$SCREENS" "$SEEDS" "$PROTOCOLS" \
         "$IMPL_TIME" "$FIX_TIME" "$TOTAL_TIME" "$CONVERGENCE" "$CLEAN" "$LAUNCH_AVG" "$LAUNCH_STDDEV" \
         "$RESULTS_DIR/metrics-$RUN_TAG.json" <<'PYEOF'
import json, sys
tag, files, lines, di, ents, screens, seeds, protos, impl, fix, total, conv, clean, avg, stddev, out = sys.argv[1:]

def ival(x):
    try:
        return int(x)
    except (ValueError, TypeError):
        return 0

def fval(x):
    if x in (None, ""):
        return None
    try:
        return float(x)
    except (ValueError, TypeError):
        return None

result = {
    "tag": tag,
    "files": ival(files),
    "lines": ival(lines),
    "di_registrations": ival(di),
    "coredata_entities": ival(ents),
    "ui_screens": ival(screens),
    "seed_topics": ival(seeds),
    "protocols": ival(protos),
    "impl_time_s": ival(impl),
    "fix_time_s": ival(fix),
    "total_time_s": ival(total),
    "error_convergence": conv.strip() if conv else "",
    "clean_build": clean.strip() if clean else "",
    "launch_avg_ms": fval(avg),
    "launch_stddev_ms": fval(stddev),
}
with open(out, "w") as f:
    json.dump(result, f, indent=2)
print(json.dumps(result, indent=2))
PYEOF

log ""
log "Scoring complete. Results at $RESULTS_DIR/metrics-$RUN_TAG.json"
