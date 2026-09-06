# Headless runner — used by CI. Developers use slash commands.
TOOL  ?= claude
TASK  ?= chore
RUNS  := ai/runs
CMD   ?= claude
MODEL  = $(shell sed -n 's/^$(TOOL): *//p' ai/models.yaml 2>/dev/null | head -1)
# Blank in models.yaml means "whatever the tool is configured with" — pass no --model at all,
# so this works against any provider rather than requiring an id the endpoint may not know.
MODEL_ARG = $(if $(strip $(MODEL)),--model "$(MODEL)",)

.PHONY: ai review ai-sync clean-runs

# INPUT reaches the recipe as an environment variable, never interpolated into the shell
# line — `make review` passes a whole diff through it, quotes and all.
export INPUT

ai:
	@mkdir -p $(RUNS)
	@OUT=$(RUNS)/$$(date +%Y%m%d-%H%M%S)-$(TOOL)-$(TASK).json; \
	PF=$$(mktemp); \
	{ cat ai/tasks/$(TASK).md; printf '\n## Input\n'; \
	  if [ -n "$(INPUT_FILE)" ]; then cat "$(INPUT_FILE)"; else printf '%s\n' "$$INPUT"; fi; } > $$PF; \
	$(CMD) -p "$$(cat $$PF)" $(MODEL_ARG) --output-format json > $$OUT; \
	rm -f $$PF; \
	node ai/make/log.js $$OUT $(TASK) $(TOOL) "$(MODEL)" >> $(RUNS)/log.csv; \
	echo "run saved: $$OUT"

# The diff goes to a file, never through a make variable: make re-expands `$` in a value,
# which would silently corrupt any diff containing one.
review:
	@mkdir -p $(RUNS); \
	BASE=$$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD develop); \
	git diff $$BASE...HEAD > $(RUNS)/.review-input; \
	$(MAKE) ai TASK=check INPUT_FILE=$(RUNS)/.review-input && \
	node ai/make/gate.js $$(ls -t $(RUNS)/*-check.json | head -1)

ai-sync:
	@bash ai/make/sync-adapters.sh

clean-runs:
	@find $(RUNS) -name '*.json' -mtime +30 -delete
