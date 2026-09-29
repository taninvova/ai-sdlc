---
description: Regenerate .claude/ and .cursor/ adapters from this repo's ai-factory/ directory
allowed-tools: Bash, Read, Glob
---
This command is for repos that carry the `ai-factory/` layout. It does nothing in other repos.

1. Check that `ai-factory/tasks/` exists and contains at least one `.md` file.
   - If instead `ai/tasks/` holds the `.md` files, this repo is on the pre-1.0.0 layout. Report  <!-- path-scan-ok -->
     that 1.0.0 renamed the layout, that the move is made by `/t4:migrate-layout` — removed in
     2.1.0, so it has to be run from an ai-sdlc checkout at 2.0.0 or earlier — and that the hooks
     keep working until it is run, then STOP. Do not sync: the adapters would be generated from
     a directory the prompts no longer name, and drift across the rename is not comparable.
   - If neither holds any, report "No ai-factory/ layout in this repo — /t4:sync-sdlc applies to
     scaffolded projects." and STOP.
2. If `ai-factory/make/sync-adapters.sh` is missing, copy it from
   `${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/templates/ai-factory/make/sync-adapters.sh`.
3. Run `bash ai-factory/make/sync-adapters.sh`.
4. Report what changed under `.claude/` and `.cursor/` (`git status --short`).
5. Report layout drift — whether this repo's `ai-factory/` is behind the installed templates:
   `node "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/scripts/manifest.js" check . "${CLAUDE_PLUGIN_ROOT}"`
   Print its output as-is. It only reports: it changes nothing under `ai-factory/`, and a repo with
   no `ai-factory/.sdlc.json` is told how to start one rather than treated as an error. A repo still
   on the old layout gets the migration instruction instead of a per-file report, because across
   the rename every path differs and the list would bury the one thing to do. Do not act on the
   findings in this task — taking an upstream change is a separate, reviewable edit.
Never edit anything under `.claude/` or `.cursor/` by hand — they are generated.
