#!/bin/bash
# build-fix-loop.sh — Build, extract errors, feed them back to the agent.
#
# Usage:
#   RUN_DIR=./run AGENT_CMD="your-agent-wrapper" RUN_TAG=run1 ./scripts/build-fix-loop.sh [max_cycles]
#
# Each cycle:
#   1. tuist generate
#   2. xcodebuild
#   3. If clean -> done
#   4. Extract unique errors, group by file, include source context
#   5. Feed the grouped error report to $AGENT_CMD in a fresh invocation
#   6. Repeat, up to max_cycles (default 7)
#
# Same AGENT_CMD contract as run-impl.sh.

set -eo pipefail

MAX_CYCLES="${1:-7}"

REPO="${REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
RUN_DIR="${RUN_DIR:?RUN_DIR must be set}"
RUN_DIR="$(cd "$RUN_DIR" && pwd)"
AGENT_CMD="${AGENT_CMD:?AGENT_CMD must be set}"
RUN_TAG="${RUN_TAG:?RUN_TAG must be set}"
RESULTS_DIR="${RESULTS_DIR:-$REPO/results}"
DEST="${DEST:-platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4}"

log() { echo "[$(date +%H:%M:%S)] $1"; }

mkdir -p "$RESULTS_DIR"

log "----------------------------------------"
log "Build-Fix Loop: ${RUN_TAG}"
log "Run dir:    ${RUN_DIR}"
log "Agent cmd:  ${AGENT_CMD}"
log "Max cycles: ${MAX_CYCLES}"
log "Destination: ${DEST}"
log "----------------------------------------"

FIX_START=$(date +%s)
echo "$FIX_START" > "$RESULTS_DIR/fix-start-${RUN_TAG}.txt"
: > "$RESULTS_DIR/fix-summary-${RUN_TAG}.txt"

cycle=0
while [ $cycle -lt $MAX_CYCLES ]; do
    cycle=$((cycle + 1))
    log ""
    log "====== CYCLE $cycle/$MAX_CYCLES ======"

    # 1. Regenerate Tuist
    cd "$RUN_DIR"
    log "tuist generate..."
    tuist generate --no-open 2>&1 | tail -3

    # 2. Build
    log "xcodebuild..."
    BUILD_LOG="$RESULTS_DIR/build-${RUN_TAG}-cycle${cycle}.txt"
    set +e
    xcodebuild -workspace Atlas.xcworkspace -scheme Atlas \
        -destination "$DEST" \
        -derivedDataPath "$RUN_DIR/DerivedData" \
        build 2>&1 | tee "$BUILD_LOG" | grep -E "BUILD (SUCCEEDED|FAILED)" | tail -1
    BUILD_EXIT=${PIPESTATUS[0]}
    set -e

    # 3. Check result
    if [ $BUILD_EXIT -eq 0 ]; then
        log "CLEAN BUILD on cycle $cycle"
        echo "CLEAN_BUILD=true CYCLE=$cycle" >> "$RESULTS_DIR/fix-summary-${RUN_TAG}.txt"
        break
    fi

    # Count errors (unique)
    ERRORS=$(grep "error:" "$BUILD_LOG" | grep -v "generated" | sort -u)
    ERROR_COUNT=$(echo "$ERRORS" | grep -c "error:" 2>/dev/null || echo "0")
    WARNING_COUNT=$(grep -c "warning:" "$BUILD_LOG" 2>/dev/null || echo "0")
    log "Errors: $ERROR_COUNT  Warnings: $WARNING_COUNT"
    echo "CYCLE_${cycle}_ERRORS=$ERROR_COUNT" >> "$RESULTS_DIR/fix-summary-${RUN_TAG}.txt"

    # 4. Build the fix prompt with grouped errors + source context
    FIX_PROMPT="$RESULTS_DIR/fix-prompt-${RUN_TAG}-cycle${cycle}.md"
    python3 << 'PYEOF' - "$BUILD_LOG" "$RUN_DIR" "$FIX_PROMPT" "$ERROR_COUNT" "$WARNING_COUNT"
import sys, re, os
from collections import defaultdict

build_log_path = sys.argv[1]
project_dir = sys.argv[2]
output_path = sys.argv[3]
error_count = sys.argv[4]
warning_count = sys.argv[5]

errors_by_file = defaultdict(list)
seen = set()
with open(build_log_path) as f:
    for line in f:
        if "error:" in line and line not in seen:
            seen.add(line)
            match = re.match(r'(.+\.swift):(\d+):(\d+): error: (.+)', line.strip())
            if match:
                filepath, lineno, col, msg = match.groups()
                rel = filepath.split("/Atlas/", 1)[-1] if "/Atlas/" in filepath else filepath
                errors_by_file[f"Atlas/{rel}"].append((int(lineno), msg.strip()))

lines = []
lines.append(f"# Build Failed - Cycle Fix\n")
lines.append(f"**{error_count} errors**, {warning_count} warnings.\n")
lines.append("Fix ALL errors. Do NOT remove features. Do NOT comment out code. Fix root causes.\n")

for filepath, file_errors in sorted(errors_by_file.items()):
    lines.append(f"\n## `{filepath}`\n")
    full_path = os.path.join(project_dir, filepath)
    source_lines = []
    if os.path.exists(full_path):
        with open(full_path) as sf:
            source_lines = sf.readlines()

    for lineno, msg in sorted(file_errors):
        lines.append(f"- **Line {lineno}:** `{msg}`")
        if source_lines and 0 < lineno <= len(source_lines):
            start = max(0, lineno - 4)
            end = min(len(source_lines), lineno + 3)
            context = []
            for i in range(start, end):
                marker = ">>>" if i == lineno - 1 else "   "
                context.append(f"  {marker} {i+1:4d} | {source_lines[i].rstrip()}")
            lines.append("  ```swift")
            lines.extend(context)
            lines.append("  ```")
    lines.append("")

unmatched = [e for e in seen if not re.match(r'.+\.swift:\d+:\d+: error:', e.strip())]
if unmatched:
    lines.append("\n## Other Errors\n```")
    for e in unmatched[:20]:
        lines.append(e.strip())
    lines.append("```\n")

lines.append("\nAfter fixing all errors, reply: `ATLAS_FIX_COMPLETE`")

with open(output_path, "w") as f:
    f.write("\n".join(lines))

print(f"Fix prompt: {len(errors_by_file)} files with errors, {len(seen)} unique errors")
PYEOF

    # 5. Feed to the agent - each cycle runs in a fresh invocation
    log "Feeding errors to agent..."
    cd "$RUN_DIR"
    SESSION_LOG="$RESULTS_DIR/fix-log-${RUN_TAG}-cycle${cycle}.log"
    cat "$FIX_PROMPT" | "$AGENT_CMD" 2>&1 | tee "$SESSION_LOG"

    log "Cycle $cycle fix complete"
    sleep 3
done

FIX_END=$(date +%s)
echo "$FIX_END" > "$RESULTS_DIR/fix-end-${RUN_TAG}.txt"
FIX_DURATION=$((FIX_END - FIX_START))

log ""
log "----------------------------------------"
log "Fix phase complete: ${FIX_DURATION}s ($(( FIX_DURATION / 60 ))m $(( FIX_DURATION % 60 ))s)"
log "Cycles used: ${cycle}/${MAX_CYCLES}"
log "----------------------------------------"

FINAL_FILES=$(find "$RUN_DIR/Atlas" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
FINAL_LINES=$(find "$RUN_DIR/Atlas" -name "*.swift" -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
log "Final: ${FINAL_FILES} files, ${FINAL_LINES} lines"
