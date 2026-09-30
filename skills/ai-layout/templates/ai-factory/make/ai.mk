# Headless entry points. Values cross into Node as literal environment data.
TOOL ?= claude
TASK ?= chore
override RUNS := ai-factory/runs
# $(value ...) prevents GNU make from evaluating embedded $(shell ...) or $().
# A simply expanded export also prevents a second expansion during export.
override TOOL := $(value TOOL)
override TASK := $(value TASK)
override SDLC_MODEL_EXPLICIT := $(if $(filter command line,$(origin MODEL)),1,)
override MODEL := $(value MODEL)
override CMD := $(value CMD)
override INPUT := $(value INPUT)
override INPUT_FILE := $(value INPUT_FILE)
override JSON := $(value JSON)
override TSV := $(value TSV)
override REVIEW_SCOPE := $(value REVIEW_SCOPE)
override GATE_ENFORCE := $(value GATE_ENFORCE)

export TOOL TASK MODEL CMD INPUT INPUT_FILE
export SDLC_MODEL_EXPLICIT
export JSON
export TSV
export REVIEW_SCOPE GATE_ENFORCE

.PHONY: ai review ai-sync log-flush clean-runs cost
ai:
	@node ai-factory/make/runner.js ai
review:
	@node ai-factory/make/runner.js review
ai-sync:
	@bash ai-factory/make/sync-adapters.sh
log-flush:
	@node ai-factory/make/runner.js log-flush
clean-runs:
	@node ai-factory/make/runner.js clean-runs
cost:
	@node ai-factory/make/cost.js $(RUNS)/log.csv
