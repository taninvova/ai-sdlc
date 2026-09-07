---
description: Regenerate .claude/ and .cursor/ adapters from this repo's ai/ directory
allowed-tools: Bash, Read, Glob
---
This command is for repos that carry the `ai/` layout. It does nothing in other repos.

1. Check that `ai/tasks/` exists and contains at least one `.md` file. If not, report
   "No ai/ layout in this repo — /ai-sdlc:sync applies to scaffolded projects." and STOP.
2. If `ai/make/sync-adapters.sh` is missing, copy it from
   `${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/templates/ai/make/sync-adapters.sh`.
3. Run `bash ai/make/sync-adapters.sh`.
4. Report what changed under `.claude/` and `.cursor/` (`git status --short`).
5. Report layout drift — whether this repo's `ai/` is behind the installed templates:
   `node "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/scripts/manifest.js" check . "${CLAUDE_PLUGIN_ROOT}"`
   Print its output as-is. It only reports: it changes nothing under `ai/`, and a repo with
   no `ai/.sdlc.json` is told how to start one rather than treated as an error. Do not act on
   the findings in this task — taking an upstream change is a separate, reviewable edit.
Never edit anything under `.claude/` or `.cursor/` by hand — they are generated.
