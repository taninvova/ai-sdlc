---
description: Move this repo from the pre-1.0.0 layout to ai-factory/ — ai/, specs/ and docs/adr/ in one reviewable change
allowed-tools: Bash, Read, Glob
---
ai-sdlc 1.0.0 renamed the layout directory and moved two more into it: `ai/` → `ai-factory/`,
`specs/` → `ai-factory/specs/`, `docs/adr/` → `ai-factory/adr/`. This command makes that move in
THIS repo. It is the only thing that does — ai-sdlc never reaches into a repo on its own
(ADR 0002), so every adopted repo runs this itself, once, when it takes the update.

Until it is run, the hooks still work: they accept the old directory name as well as the new one
until 2.0.0, so a repo that has updated the plugin but not yet migrated keeps its dont-touch guard
and its run log. Nothing is silently disarmed. Prompts are not so forgiving — they name the new
paths only, so `/t4:spec` and friends will look in `ai-factory/` before this has run.

1. Run it from the repo root:
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/scripts/migrate-layout.sh"`
2. Print its output as-is. It reports what it moved and what it rewrote as two separate lists,
   because they are two different kinds of change and the second is the one worth reading.
3. If it refuses, report the reason and STOP. Do not work around it: every refusal is a case
   where the right move cannot be decided without the developer — work in flight on a tracked
   file, a half-migrated repo, or the same file present under both layouts. An untracked file is
   not a refusal; it is named in the output, because the second commit's `git add -A` would
   include it.
4. Do not commit. Relay the two-commit instruction it prints, in that order and unchanged: the
   moves are staged and the rewrite is not, because git pairs a rename by similarity: a file whose
   path lines are most of its content — a short prompt, a stub — drops below the threshold when the
   move and the rewrite land together, and loses its history. Two commits make that independent of
   file size. Tell the developer to review `git diff --cached -M` for the moves and `git diff` for
   the rewrite.

What it does NOT do: deliver new prompt text. The rewrite is bounded to path strings, so the
prompts in this repo keep saying what they said before, about the new paths. Taking an upstream
change is `/t4:sync-sdlc`, separately and reviewably (ADR 0008).
