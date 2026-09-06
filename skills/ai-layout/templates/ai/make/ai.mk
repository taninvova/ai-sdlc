# Headless runner — used by CI. Developers use slash commands.
TOOL  ?= claude
TASK  ?= chore
RUNS  := ai/runs
MODEL  = $(shell sed -n 's/^$(TOOL): *//p' ai/models.yaml | head -1)

.PHONY: ai review ai-sync clean-runs

ai:
	@mkdir -p $(RUNS)
	@PROMPT="$$(cat ai/tasks/$(TASK).md)

## Input
$(INPUT)"; \
	OUT=$(RUNS)/$$(date +%Y%m%d-%H%M%S)-$(TOOL)-$(TASK).json; \
	claude -p "$$PROMPT" --model "$(MODEL)" --output-format json > $$OUT; \
	node ai/make/log.js $$OUT $(TASK) $(TOOL) "$(MODEL)" >> $(RUNS)/log.csv; \
	echo "run saved: $$OUT"

review:
	@BASE=$$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD develop); \
	$(MAKE) ai TASK=review INPUT="$$(git diff $$BASE...HEAD)" && \
	node ai/make/gate.js $$(ls -t $(RUNS)/*-review.json | head -1)

ai-sync:
	@bash ai/make/sync-adapters.sh

clean-runs:
	@find $(RUNS) -name '*.json' -mtime +30 -delete
