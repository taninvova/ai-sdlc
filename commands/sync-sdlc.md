---
description: Inspect workspace drift; generate host pointers only when explicitly requested
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
2. Run `node "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/templates/ai-factory/make/sync-adapters.js"`.
   Its default is strict mode: no external project files are written or removed. Existing host
   integration files are preserved. Do not use an older local generator that creates them by default.
   Only if the user explicitly requested particular host adapters, pass `--adapters=claude`,
   `--adapters=codex`, `--adapters=cursor`, or a comma-separated combination. Never infer all hosts.
3. Report layout drift with:
   `node "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/scripts/manifest.js" check . "${CLAUDE_PLUGIN_ROOT}"`
   Print its output as-is. This only reports: taking upstream changes remains a separate,
   reviewable edit that preserves local changes. Do not silently copy changed templates.
4. Report the selected mode and any changed files. Never hand-edit generated integration files.
