# Headless runner — used by CI. Developers use slash commands.
TOOL  ?= claude
TASK  ?= chore
RUNS  := ai/runs
MODEL  = $(shell sed -n 's/^$(TOOL): *//p' ai/models.yaml 2>/dev/null | head -1)

# Blank in models.yaml means "whatever the tool is configured with" — pass no model flag at
# all, so this works against any provider rather than requiring an id the endpoint may not
# know. The two CLIs differ in flags and in output shape, so RUN is built per tool.
ifeq ($(TOOL),codex)
CMD       ?= codex
MODEL_ARG  = $(if $(strip $(MODEL)),-m "$(MODEL)",)
# codex exec takes the prompt on stdin (`-`), streams JSONL events to stdout, and writes the
# final message to -o. log.js and gate.js read both.
RUN        = $(CMD) exec --json --skip-git-repo-check $(MODEL_ARG) -o $$OUT.last.txt - < $$PF > $$OUT
else
CMD       ?= claude
MODEL_ARG  = $(if $(strip $(MODEL)),--model "$(MODEL)",)
# The prompt goes in on stdin, never as an argument: every task file starts with `---`, which
# the CLI parses as an option and refuses. Codex takes stdin below for the same reason.
RUN        = $(CMD) -p $(MODEL_ARG) --output-format json < $$PF > $$OUT
endif

.PHONY: ai review ai-sync log-flush clean-runs

# INPUT reaches the recipe as an environment variable, never interpolated into the shell
# line — `make review` passes a whole diff through it, quotes and all.
export INPUT

ai:
	@mkdir -p $(RUNS)
	@OUT=$(RUNS)/$$(date +%Y%m%d-%H%M%S)-$(TOOL)-$(TASK).json; \
	PF=$$(mktemp); \
	{ cat ai/tasks/$(TASK).md; printf '\n## Input\n'; \
	  if [ -n "$(INPUT_FILE)" ]; then cat "$(INPUT_FILE)"; else printf '%s\n' "$$INPUT"; fi; } > $$PF; \
	$(RUN); ST=$$?; \
	rm -f $$PF; \
	if [ $$ST -ne 0 ] || [ ! -s $$OUT ]; then \
	  echo "make ai: $(TOOL) failed (exit $$ST) and wrote $$(wc -c < $$OUT | tr -d ' ') bytes to $$OUT" >&2; \
	  echo "make ai: no row logged — a failed run is not a run" >&2; \
	  exit 1; \
	fi; \
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

# Sessions buffer their log.csv rows in log.pending.csv (gitignored) so the tracked file is not
# dirty every turn; a `git commit` run inside a session moves them across through the plugin's
# log-flush hook. This is the same move for a commit made from a terminal. The two files must
# carry the same header — a pending file on another schema is left for the hook to migrate.
log-flush:
	@P=$(RUNS)/log.pending.csv; L=$(RUNS)/log.csv; \
	[ -s $$P ] || { echo "log-flush: nothing pending"; exit 0; }; \
	[ -s $$L ] || head -1 $$P > $$L; \
	[ "$$(head -1 $$P)" = "$$(head -1 $$L)" ] || { echo "log-flush: $$P and $$L have different headers — commit from a session so the hook migrates them" >&2; exit 1; }; \
	tail -n +2 $$P >> $$L && rm -f $$P && git add -- $$L && echo "log-flush: rows moved into $$L and staged"

clean-runs:
	@find $(RUNS) -name '*.json' -mtime +30 -delete
