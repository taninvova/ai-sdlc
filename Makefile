include ai-factory/make/ai.mk

# The plugin's own regression suite. Adopted repos do not ship these scripts, so this target lives
# here rather than in the ai.mk template.
.PHONY: check
check:
	@set -e; for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do \
	  echo "== $$f"; bash "$$f" < /dev/null; \
	done
