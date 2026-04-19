#!/bin/bash
# launch-test.sh — Cold launch measurement for iOS app
#
# Usage: ./launch-test.sh <bundle-id> <model-name> <results-dir>
#
# Measures process spawn time across 5 cold launches.

set -e

BUNDLE_ID="${1:?Usage: launch-test.sh <bundle-id> <model-name> <results-dir>}"
MODEL_NAME="${2:?model-name required}"
RESULTS_DIR="${3:?results-dir required}"

DEVICE="iPhone 16 Pro"
ITERATIONS=5
OUTPUT="$RESULTS_DIR/launch-${MODEL_NAME}.json"

echo "  Cold launch test: ${MODEL_NAME} (${ITERATIONS} iterations)"

# Build launch_times array
LAUNCH_TIMES="["

for i in $(seq 1 $ITERATIONS); do
    # Terminate app
    xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
    sleep 2
    
    # Cold launch and measure
    START=$(python3 -c "import time; print(time.time())")
    RESULT=$(xcrun simctl launch "$DEVICE" "$BUNDLE_ID" 2>&1)
    END=$(python3 -c "import time; print(time.time())")
    
    DURATION_MS=$(python3 -c "print(f'{($END - $START) * 1000:.1f}')")
    
    if echo "$RESULT" | grep -q "PID"; then
        PID=$(echo "$RESULT" | grep -o '[0-9]*')
        echo "  Launch $i: ${DURATION_MS}ms (PID: $PID)"
    else
        echo "  Launch $i: ${DURATION_MS}ms (CRASH or error: $RESULT)"
    fi
    
    if [ $i -lt $ITERATIONS ]; then
        LAUNCH_TIMES="${LAUNCH_TIMES}${DURATION_MS}, "
    else
        LAUNCH_TIMES="${LAUNCH_TIMES}${DURATION_MS}"
    fi
done

LAUNCH_TIMES="${LAUNCH_TIMES}]"

# Save results
python3 -c "
import json, datetime
times = ${LAUNCH_TIMES}
result = {
    'model': '${MODEL_NAME}',
    'bundle_id': '${BUNDLE_ID}',
    'iterations': ${ITERATIONS},
    'launch_times_ms': times,
    'avg_ms': round(sum(times) / len(times), 1),
    'min_ms': round(min(times), 1),
    'max_ms': round(max(times), 1),
    'stddev_ms': round((sum((x - sum(times)/len(times))**2 for x in times) / len(times))**0.5, 1),
    'timestamp': datetime.datetime.now().isoformat()
}
json.dump(result, open('${OUTPUT}', 'w'), indent=2)
print(f'  Average: {result[\"avg_ms\"]}ms (±{result[\"stddev_ms\"]}ms)')
"

# Wait for potential crash report
sleep 3
CRASH=$(xcrun simctl spawn "$DEVICE" log show --predicate "processImagePath CONTAINS 'Atlas'" --last 5s 2>/dev/null | grep -c "crash\|SIGABRT\|SIGSEGV" || echo "0")
if [ "$CRASH" -gt 0 ]; then
    echo "  ⚠ App appears to crash on launch (crash signals: $CRASH)"
fi
