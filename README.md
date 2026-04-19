# ios-agent-benchmark

A long-horizon iOS coding benchmark designed to stress-test autonomous coding agents on a single, realistic iOS project from spec to clean build.

The benchmark is **agent-agnostic**. It does not assume any particular model, vendor, or CLI. You plug your agent in through an `AGENT_CMD` wrapper, and the harness handles scaffolding, prompting, build-fix looping, and metric collection.

## What gets measured

A run produces a single iOS project from a fixed PRD. The harness records:

- **Implementation phase metrics** — wall-clock time, files written, lines of code, protocol / entity / registration counts
- **Build-fix loop metrics** — cycles used, errors per cycle, convergence shape, time spent fixing, clean-build cycle
- **Runtime metrics** — five cold-launch samples on simulator after clean build
- **Code quality metrics** — protocol conformances, force-unwraps, `@MainActor` usage, `Sendable` adoption, decorator coverage, DI registrations, accessibility labels, and more (see `scripts/gather-metrics.py`)

Two runs on the same PRD produce directly comparable metric sets.

## What the benchmark is good for

- Comparing two coding agents head-to-head on a realistic iOS workload
- Tracking a single agent's capability across model versions
- Measuring self-repair quality (convergence shape, fix-time ratio)
- Studying output distribution (which layers an agent prioritizes)
- Reproducing long-horizon iOS-coding capability claims independently

## What the benchmark is not

- Not a synthetic micro-benchmark. It takes 20-60 minutes per run and tests sustained planning, not snippet correctness.
- Not an evaluation of runtime UX quality. A clean build with a placeholder UI will pass the build gate; metrics distinguish between complete and skeletal outputs.
- Not a statistical study out of the box. `n=1` per run; reproducibility requires repeated runs.

## Requirements

- macOS with Xcode 18+ (includes `xcodebuild`)
- [Tuist](https://tuist.io) for project generation
- iPhone 16 Pro simulator with iOS 18.4 (or adjust `DEST` in `scripts/build-fix-loop.sh`)
- Python 3.11+ for the metric scripts
- An agent CLI of your choice (see "Plugging in your agent" below)

## Quick start

```bash
# 1. Scaffold a run directory
RUN_DIR=./run ./scripts/prep-clean.sh

# 2. Point the harness at your agent wrapper
AGENT_CMD=./my-agent-wrapper.sh

# 3. Run the implementation phase
RUN_DIR=./run AGENT_CMD="$AGENT_CMD" RUN_TAG=run1 ./scripts/run-impl.sh

# 4. Run the build-fix loop (up to 7 cycles)
RUN_DIR=./run AGENT_CMD="$AGENT_CMD" RUN_TAG=run1 ./scripts/build-fix-loop.sh 7

# 5. If clean build, measure cold launch and collect metrics
RUN_DIR=./run RUN_TAG=run1 ./scripts/launch-test.sh
RUN_DIR=./run RUN_TAG=run1 ./scripts/score.sh
```

See [`RUNBOOK.md`](./RUNBOOK.md) for the full walkthrough.

## Plugging in your agent

The harness invokes `"$AGENT_CMD"` once per phase, pipes the prompt into stdin, and expects the agent to write files under `$RUN_DIR/Atlas/` using its own file-editing tools. That's the only contract.

Your wrapper script decides how to call your underlying CLI. Examples of what a wrapper might do:

- Pipe the prompt into a CLI that accepts stdin directly
- Forward the prompt as a positional argument to a CLI that expects one
- Prepend a system prompt, set environment variables, route to a specific model, capture token usage

A minimal wrapper is about 5 lines of bash. Anything more is up to you.

## Project layout

```
ios-agent-benchmark/
├── README.md               # this file
├── RUNBOOK.md              # step-by-step runbook
├── PRD.md                  # Tier 1 Atlas spec
├── Project.swift           # Tuist project manifest
├── Tuist.swift             # Tuist config
├── prompts/
│   └── implementation.md   # Tier 1 implementation instructions
└── scripts/
    ├── prep-clean.sh       # reset scaffold
    ├── run-impl.sh         # implementation phase
    ├── build-fix-loop.sh   # build-fix cycles
    ├── launch-test.sh      # 5x cold launch measurement
    ├── score.sh            # run metrics end-to-end
    ├── gather-metrics.py   # collect raw metrics from an output tree
    ├── oqm-scorer.py       # open-quality-metrics scoring
    └── results-aggregator.py  # aggregate across runs
```

## License

MIT. See [`LICENSE`](./LICENSE).
