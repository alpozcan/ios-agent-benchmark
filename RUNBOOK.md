# RUNBOOK

End-to-end walkthrough for running a single benchmark iteration.

## Prerequisites

```bash
xcodebuild -version                 # Xcode 18 or newer
tuist version                       # any recent Tuist
python3 --version                   # 3.11+
xcrun simctl list devices | grep "iPhone 16 Pro"  # ensure simulator is available
```

## 1. Write an agent wrapper

The harness invokes `"$AGENT_CMD"` and pipes the prompt into its stdin. Your wrapper's job is to pass that prompt to whatever coding agent CLI you're evaluating.

A minimal example (`./my-agent.sh`):

```bash
#!/bin/bash
# Reads a prompt from stdin and hands it to the underlying agent CLI.
# Replace the command below with your agent's invocation.
PROMPT=$(cat)
my-coding-agent --non-interactive --allow-writes "$PROMPT"
```

Make it executable:

```bash
chmod +x ./my-agent.sh
```

The agent must:
- Accept the prompt
- Write Swift files under the current working directory's `Atlas/` folder
- Not invoke `xcodebuild` (the harness handles that)
- Not write tests (Tier 1 scope)
- Reply with `ATLAS_IMPLEMENTATION_COMPLETE` when done (the harness logs this but does not require it for later phases)

## 2. Scaffold a run directory

```bash
export RUN_DIR=$PWD/run
export RUN_TAG=run1
export AGENT_CMD=./my-agent.sh

./scripts/prep-clean.sh
```

This creates `./run/` with the Tuist manifests and empty Atlas/ subdirectories.

## 3. Implementation phase

```bash
./scripts/run-impl.sh
```

Expected duration: 20-60 minutes depending on the agent. The full prompt (PRD + implementation.md + final directive) is sent in a single call. Session output streams to `results/session-impl-$RUN_TAG.log`.

At the end you'll see file and line counts. Typical Tier 1 output is 100-250 Swift files and 10-15K lines.

## 4. Build-fix loop

```bash
./scripts/build-fix-loop.sh 7
```

Each cycle runs `tuist generate` + `xcodebuild`, groups errors by file, and feeds a structured error report back to your agent in a fresh invocation. The loop stops at clean build or after the maximum number of cycles.

Per-cycle artifacts land in `results/`:
- `build-$RUN_TAG-cycleN.txt` — full xcodebuild log
- `fix-prompt-$RUN_TAG-cycleN.md` — the error report sent to the agent
- `fix-log-$RUN_TAG-cycleN.log` — the agent's response stream

## 5. Cold-launch measurement

Only run this if cycle N produced a clean build.

```bash
./scripts/launch-test.sh
```

Launches the built `Atlas.app` on the iPhone 16 Pro simulator five times and records cold-launch timing samples.

## 6. Collect metrics

```bash
./scripts/score.sh
```

Aggregates volume, SOLID, quality, concurrency, platform, and security metrics from the output tree, plus build-fix convergence and cold-launch numbers, into `results/metrics-$RUN_TAG.json`.

## 7. Compare two runs

To compare agents A and B, repeat steps 2-6 twice with different `RUN_DIR` and `RUN_TAG`. Then aggregate:

```bash
python3 scripts/results-aggregator.py \
    results/metrics-runA.json \
    results/metrics-runB.json \
    > results/comparison.json
```

## Troubleshooting

- **`tuist generate` fails:** usually a stale `DerivedData/`. Re-run `prep-clean.sh`.
- **Agent writes outside `Atlas/`:** amend the wrapper or the final directive in `run-impl.sh` to be stricter about file paths.
- **Build fails with "No such module ProjectDescription":** this is normal when viewing `Project.swift` outside a Tuist workspace. Ignore it.
- **Simulator not found:** adjust `DEST` in `scripts/build-fix-loop.sh` to match an available simulator (`xcrun simctl list devices`).
- **Rate limits on the agent side:** the harness does not retry. Re-run the implementation phase or add retry logic in your wrapper.

## Reproducing a comparison

1. Freeze both agents' versions (`agent1 --version`, `agent2 --version`).
2. Run each agent three times with different `RUN_TAG` values.
3. Aggregate per-agent metrics and compute variance across the three runs.
4. Report median and stddev, not single-run numbers.
