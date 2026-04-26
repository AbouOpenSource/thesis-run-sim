SHELL := /bin/bash

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
RL_DIR := $(ROOT_DIR)/rl_memory_agent
SIM_DIR := $(ROOT_DIR)/simgrid_cluster_env

PYTHON ?= $(RL_DIR)/.venv/bin/python
PYTHONPATH_RUN ?= $(RL_DIR)/src

OUT_ROOT ?= $(SIM_DIR)/runs_overnight
OVERNIGHT_LOG ?= $(OUT_ROOT)/overnight.log
OVERNIGHT_PID ?= $(OUT_ROOT)/overnight.pid
RESUME_BATCH ?= $(shell ls -td "$(OUT_ROOT)"/batch_* 2>/dev/null | head -1)

CONTROLLERS ?= rl
SCENARIOS ?= nominal,tight_budget,io_slow,preempt
SEEDS ?= 0,1,2,3,4,5,6,7,8,9
UPDATES ?= 2000
ROLLOUT_STEPS ?= 64
CONTROL_INTERVAL ?= 10
REWARD_MODE ?= samples_per_second
SEQUENCE_LENGTH ?= 1
LOSS_DELTA_PER_UPDATE ?= 1.0
REWARD_SCALE ?= 1.0
OOM_PENALTY ?= 5.0
RESTART_PENALTY ?= 0.0
COST_COMPONENTS ?= mem_overflow,oom,comm_frac,io_frac
COST_LIMITS ?= 0.0,0.0,0.35,0.10
AGENT_SAVE_CHECKPOINTS ?= 1
AGENT_SAVE_EVERY_UPDATES ?= 100

ifeq ($(AGENT_SAVE_CHECKPOINTS),1)
AGENT_CHECKPOINT_ARGS := --agent-save-checkpoints --agent-save-every-updates "$(AGENT_SAVE_EVERY_UPDATES)"
else
AGENT_CHECKPOINT_ARGS :=
endif

.PHONY: help submodules rl-venv rl-install rl-matplotlib rl-toy rl-simgrid sim-install-system sim-install-source sim-build overnight overnight-resume overnight-status aggregate

help:
	@printf "%s\n" \
		"Targets:" \
		"  make submodules            Initialize/update the two Git submodules" \
		"  make rl-venv               Create the RL virtual environment" \
		"  make rl-install            Install the RL package in editable mode" \
		"  make rl-matplotlib         Install matplotlib in the RL virtualenv" \
		"  make rl-toy                Run the toy RL environment" \
		"  make rl-simgrid            Run the RL agent against SimGrid" \
		"  make sim-install-system    Install SimGrid from system packages" \
		"  make sim-install-source    Install SimGrid from source under a prefix" \
		"  make sim-build             Build the SimGrid cluster environment" \
		"  make overnight             Launch the overnight batch run" \
		"  make overnight-resume      Resume the latest overnight batch" \
		"  make overnight-status      Show the current overnight status" \
		"  make aggregate             Aggregate the latest batch or BATCH=..." \
		"" \
		"Common overrides:" \
		"  CONTROLLERS, SCENARIOS, SEEDS, UPDATES, REWARD_MODE" \
		"  AGENT_SAVE_EVERY_UPDATES, OUT_ROOT, RESUME_BATCH"

submodules:
	@git submodule update --init --recursive

rl-venv:
	@if [[ ! -x "$(PYTHON)" ]]; then \
		python3 -m venv "$(RL_DIR)/.venv"; \
	fi

rl-install: rl-venv
	"$(PYTHON)" -m pip install -e "$(RL_DIR)"

rl-matplotlib: rl-venv
	"$(PYTHON)" -m pip install matplotlib

rl-toy: rl-venv
	PYTHONPATH="$(PYTHONPATH_RUN)" "$(PYTHON)" -m rl_memory_agent.cli toy

rl-simgrid: rl-venv
	PYTHONPATH="$(PYTHONPATH_RUN)" "$(PYTHON)" -m rl_memory_agent.cli simgrid

sim-install-system:
	bash "$(SIM_DIR)/scripts/install_simgrid.sh" --system

sim-install-source:
	@prefix="$${PREFIX:-$$HOME/.local}"; \
	bash "$(SIM_DIR)/scripts/install_simgrid.sh" --source --prefix "$$prefix"

sim-build:
	cmake -S "$(SIM_DIR)" -B "$(SIM_DIR)/build"
	cmake --build "$(SIM_DIR)/build" -j

overnight:
	@mkdir -p "$(OUT_ROOT)"
	@PYTHONPATH="$(PYTHONPATH_RUN)" nohup "$(PYTHON)" "$(SIM_DIR)/python/batch_experiments.py" \
		--controllers "$(CONTROLLERS)" \
		--scenarios "$(SCENARIOS)" \
		--seeds "$(SEEDS)" \
		--agent-python "$(PYTHON)" \
		--plot-python "$(PYTHON)" \
		--updates "$(UPDATES)" \
		--rollout-steps "$(ROLLOUT_STEPS)" \
		--control-interval "$(CONTROL_INTERVAL)" \
		--reward-mode "$(REWARD_MODE)" \
		--sequence-length "$(SEQUENCE_LENGTH)" \
		--loss-delta-per-update "$(LOSS_DELTA_PER_UPDATE)" \
		--reward-scale "$(REWARD_SCALE)" \
		--oom-penalty "$(OOM_PENALTY)" \
		--restart-penalty "$(RESTART_PENALTY)" \
		--cost-components "$(COST_COMPONENTS)" \
		--cost-limits "$(COST_LIMITS)" \
		$(AGENT_CHECKPOINT_ARGS) \
		--out-root "$(OUT_ROOT)" \
		> "$(OVERNIGHT_LOG)" 2>&1 & echo $$! > "$(OVERNIGHT_PID)"
	@echo "overnight pid: $$(cat "$(OVERNIGHT_PID)")"
	@echo "log: $(OVERNIGHT_LOG)"

overnight-resume:
	@if [[ -z "$(RESUME_BATCH)" ]]; then \
		echo "No batch directory found under $(OUT_ROOT)."; \
		exit 1; \
	fi
	@mkdir -p "$(OUT_ROOT)"
	@PYTHONPATH="$(PYTHONPATH_RUN)" nohup "$(PYTHON)" "$(SIM_DIR)/python/batch_experiments.py" \
		--batch-dir "$(RESUME_BATCH)" \
		--skip-completed \
		--controllers "$(CONTROLLERS)" \
		--scenarios "$(SCENARIOS)" \
		--seeds "$(SEEDS)" \
		--agent-python "$(PYTHON)" \
		--plot-python "$(PYTHON)" \
		--updates "$(UPDATES)" \
		--rollout-steps "$(ROLLOUT_STEPS)" \
		--control-interval "$(CONTROL_INTERVAL)" \
		--reward-mode "$(REWARD_MODE)" \
		--sequence-length "$(SEQUENCE_LENGTH)" \
		--loss-delta-per-update "$(LOSS_DELTA_PER_UPDATE)" \
		--reward-scale "$(REWARD_SCALE)" \
		--oom-penalty "$(OOM_PENALTY)" \
		--restart-penalty "$(RESTART_PENALTY)" \
		--cost-components "$(COST_COMPONENTS)" \
		--cost-limits "$(COST_LIMITS)" \
		$(AGENT_CHECKPOINT_ARGS) \
		--out-root "$(OUT_ROOT)" \
		> "$(OVERNIGHT_LOG)" 2>&1 & echo $$! > "$(OVERNIGHT_PID)"
	@echo "overnight resume pid: $$(cat "$(OVERNIGHT_PID)")"
	@echo "batch: $(RESUME_BATCH)"
	@echo "log: $(OVERNIGHT_LOG)"

overnight-status:
	@if [[ ! -f "$(OVERNIGHT_PID)" ]]; then \
		echo "No pid file: $(OVERNIGHT_PID)"; \
		exit 0; \
	fi; \
	pid="$$(cat "$(OVERNIGHT_PID)")"; \
	if ps -p "$$pid" >/dev/null 2>&1; then \
		echo "overnight running: $$pid"; \
	else \
		echo "overnight not running: $$pid"; \
	fi; \
	echo "log: $(OVERNIGHT_LOG)"; \
	if [[ -f "$(OVERNIGHT_LOG)" ]]; then tail -n 20 "$(OVERNIGHT_LOG)"; fi

aggregate:
	@batch="$${BATCH:-$$(ls -td "$(OUT_ROOT)"/batch_* 2>/dev/null | head -1)}"; \
	if [[ -z "$$batch" ]]; then \
		echo "No batch directory found under $(OUT_ROOT)."; \
		echo "Usage: make aggregate BATCH=simgrid_cluster_env/runs_overnight/batch_YYYYMMDD_HHMMSS"; \
		exit 1; \
	fi; \
	"$(PYTHON)" "$(SIM_DIR)/python/aggregate_summary.py" "$$batch"; \
	echo "summary: $$batch/summary.csv"; \
	echo "aggregate csv: $$batch/aggregate_by_scenario_controller.csv"; \
	echo "aggregate md: $$batch/aggregate_by_scenario_controller.md"
