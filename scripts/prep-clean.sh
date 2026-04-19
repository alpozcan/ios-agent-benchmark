#!/bin/bash
# prep-clean.sh — Reset the run directory to a clean scaffold.
#
# Usage:
#   RUN_DIR=./run ./scripts/prep-clean.sh
#
# Environment variables:
#   RUN_DIR  — destination directory for the agent's output (required)
#   REPO     — benchmark repo root (default: script's parent directory)

set -e

REPO="${REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
RUN_DIR="${RUN_DIR:?RUN_DIR must be set, e.g. RUN_DIR=./run}"
RUN_DIR="$(cd "$(dirname "$RUN_DIR")" 2>/dev/null && pwd)/$(basename "$RUN_DIR")" || {
    mkdir -p "$RUN_DIR"
    RUN_DIR="$(cd "$RUN_DIR" && pwd)"
}

echo "=== Cleaning previous code in $RUN_DIR ==="
rm -rf "$RUN_DIR/Atlas"
rm -rf "$RUN_DIR/DerivedData"
rm -rf "$RUN_DIR/Atlas.xcworkspace"
rm -rf "$RUN_DIR/Atlas.xcodeproj"
rm -rf "$RUN_DIR/Derived"
rm -rf ~/Library/Developer/Xcode/DerivedData/Atlas-*
# Remove any agent-local state directories left behind by the wrapper.
# Customize AGENT_STATE_DIRS in your environment if your wrapper creates
# directories with different names.
for state in ${AGENT_STATE_DIRS:-.agent-state}; do
    rm -rf "$RUN_DIR/$state"
done

echo "=== Copying scaffold manifests ==="
cp "$REPO/Project.swift" "$RUN_DIR/Project.swift"
cp "$REPO/Tuist.swift"   "$RUN_DIR/Tuist.swift"

echo "=== Recreating directory scaffold ==="
for d in App Domain/{Models,Protocols/{Repositories,UseCases,Mappers,Coordinators,Services,Decorators},Errors} \
         Data/{Entities,Repositories,Mappers} Engine/{Graph,Search,Text,Similarity} DI \
         Features/{UseCases,Coordinators,Factories,Builders} \
         Services/{Platform,Infrastructure,Feature,Decorators,UI,Helpers} \
         Seeding UI/{Theme,Screens,Components,ViewModels} Extensions; do
    mkdir -p "$RUN_DIR/Atlas/$d"
done

echo "=== Regenerating Tuist workspace ==="
cd "$RUN_DIR" && tuist generate --no-open 2>&1 | tail -2

echo ""
echo "=== Verify ==="
echo "Directories: $(find $RUN_DIR/Atlas -type d | wc -l | tr -d ' ')"
echo "Swift files: $(find $RUN_DIR/Atlas -name '*.swift' | wc -l | tr -d ' ') (expect 0)"

echo ""
echo "Ready for implementation phase. Next: RUN_DIR=$RUN_DIR AGENT_CMD=... ./scripts/run-impl.sh"
