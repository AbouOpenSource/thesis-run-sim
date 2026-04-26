# thesis-run-sim

Code repository for the thesis work on constraint-aware RL for memory optimization in distributed
deep learning.

This repository is intentionally code-only. The thesis LaTeX sources and compiled PDF live in the
separate `document_thesis_full` project and are not included here.

## Contents

- `rl_memory_agent`: RL agent scaffold with toy environment and SimGrid online controller
- `simgrid_cluster_env`: SimGrid-based cluster simulator, batch runner, plotting, and aggregation

Both are tracked as Git submodules.

## Quick Start

```bash
git clone --recurse-submodules https://github.com/AbouOpenSource/thesis-run-sim.git
cd thesis-run-sim
make submodules
```

If you already cloned without submodules:

```bash
make submodules
```

## Environment Setup

The root `Makefile` is a convenience wrapper around the two subprojects.

Install the RL package in editable mode:

```bash
make rl-install
```

Install matplotlib for telemetry plots:

```bash
make rl-matplotlib
```

Install SimGrid from system packages:

```bash
make sim-install-system
```

Or install SimGrid from source under a prefix:

```bash
make sim-install-source PREFIX="$HOME/.local"
```

Build the SimGrid simulator:

```bash
make sim-build
```

## Useful Commands

Run the toy RL environment:

```bash
make rl-toy
```

Run the RL agent against the SimGrid simulator in online mode:

```bash
make rl-simgrid
```

Launch the overnight batch:

```bash
make overnight
```

Resume the latest unfinished batch:

```bash
make overnight-resume
```

Inspect the current overnight process:

```bash
make overnight-status
```

Aggregate the latest batch, or point to a specific one:

```bash
make aggregate
make aggregate BATCH=simgrid_cluster_env/runs_overnight/batch_YYYYMMDD_HHMMSS
```

## Runtime Outputs

Batch runs are written under `simgrid_cluster_env/runs_overnight/` by default. Each batch contains
per-run telemetry, agent checkpoints, plots, and a `summary.csv`.

The repository `.gitignore` is set to ignore `runs*/` inside `simgrid_cluster_env`, so generated
experiment outputs are kept out of version control.

## Notes

- The RL submodule supports selectable reward modes, checkpointing, and resume from saved
  checkpoints.
- The SimGrid submodule supports resumable batch execution and scenario-level aggregation.
- The root repository is meant to coordinate the code experiments only. Thesis text belongs in the
  separate LaTeX project.
