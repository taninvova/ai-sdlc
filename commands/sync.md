---
description: Regenerate .claude/ and .cursor/ adapters from this repo's ai/ directory
allowed-tools: Bash, Read, Glob
---
This command is for repos that carry the `ai/` layout. It does nothing in other repos.

1. Check that `ai/tasks/` exists and contains at least one `.md` file. If not, report
   "No ai/ layout in this repo — /sdlc:sync applies to scaffolded projects." and STOP.
2. If `ai/make/sync-adapters.sh` is missing, copy it from
   `${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/templates/ai/make/sync-adapters.sh`.
3. Run `bash ai/make/sync-adapters.sh`.
4. Report what changed under `.claude/` and `.cursor/` (`git status --short`).
Never edit anything under `.claude/` or `.cursor/` by hand — they are generated.
