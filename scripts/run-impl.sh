#!/bin/bash
# run-impl.sh — Run the implementation phase against any coding agent.
#
# Usage:
#   RUN_DIR=./run AGENT_CMD="your-agent-wrapper" RUN_TAG=run1 ./scripts/run-impl.sh
#
# Required environment variables:
#   RUN_DIR   — directory the agent will write files into (must be scaffolded by prep-clean.sh)
#   AGENT_CMD — the command (or wrapper script) that accepts a prompt on its CLI and
#               writes files to the current working directory using its own tools.
#   RUN_TAG   — short tag for this run, used in result filenames (e.g. run1, modelA)
#
# Optional:
#   RESULTS_DIR — where to write logs and metrics (default: ./results)
#
# The AGENT_CMD contract:
#   - Must accept a single prompt via stdin or a final positional argument
#     (the wrapper is responsible for whichever the underlying CLI expects)
#   - Must execute in the current working directory
#   - Must create Swift files under ./Atlas/ per the instructions in the prompt
#   - Must not invoke xcodebuild; the harness handles that separately
#   - Stdout/stderr are captured for post-hoc inspection; structured JSON lines
#     are preserved verbatim if the agent emits them

set -eo pipefail

REPO="${REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
RUN_DIR="${RUN_DIR:?RUN_DIR must be set}"
RUN_DIR="$(cd "$RUN_DIR" && pwd)"
AGENT_CMD="${AGENT_CMD:?AGENT_CMD must be set}"
RUN_TAG="${RUN_TAG:?RUN_TAG must be set}"
RESULTS_DIR="${RESULTS_DIR:-$REPO/results}"
SESSION_LOG="$RESULTS_DIR/session-impl-${RUN_TAG}.log"

log() { echo "[$(date +%H:%M:%S)] $1"; }

mkdir -p "$RESULTS_DIR"

log "----------------------------------------"
log "  Implementation: ${RUN_TAG}"
log "  Run dir:        ${RUN_DIR}"
log "  Agent cmd:      ${AGENT_CMD}"
log "  Session log:    ${SESSION_LOG}"
log "----------------------------------------"

IMPL_START=$(date +%s)
echo "$IMPL_START" > "$RESULTS_DIR/impl-start-${RUN_TAG}.txt"
log "Start: $(date)"

cd "$RUN_DIR"
rm -f "$SESSION_LOG"

# Compose the prompt from PRD + implementation spec + final directive.
PROMPT=$(cat <<EOF
$(cat "$REPO/PRD.md")

---

$(cat "$REPO/prompts/implementation.md")

---

Implement everything described in the PRD and implementation prompt. Write ALL
Swift files under $(pwd)/Atlas/ using your file-editing tools. Do NOT run
xcodebuild. Do NOT write tests. When every file exists and the implementation
is complete, reply exactly: ATLAS_IMPLEMENTATION_COMPLETE
EOF
)

# Hand the prompt to the agent wrapper. The wrapper decides how to invoke the
# underlying CLI (via stdin pipe, positional arg, etc.) and streams output back.
echo "$PROMPT" | "$AGENT_CMD" 2>&1 | tee "$SESSION_LOG"

IMPL_END=$(date +%s)
echo "$IMPL_END" > "$RESULTS_DIR/impl-end-${RUN_TAG}.txt"
IMPL_DURATION=$((IMPL_END - IMPL_START))

IMPL_FILES=$(find "$RUN_DIR/Atlas" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
IMPL_LINES=$(find "$RUN_DIR/Atlas" -name "*.swift" -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')

log ""
log "----------------------------------------"
log "Implementation complete"
log "Duration: ${IMPL_DURATION}s ($(( IMPL_DURATION / 60 ))m $(( IMPL_DURATION % 60 ))s)"
log "Files:    ${IMPL_FILES}"
log "Lines:    ${IMPL_LINES}"
log "----------------------------------------"
