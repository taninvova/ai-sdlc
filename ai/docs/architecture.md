# Architecture — ai-sdlc

## Shape
A Claude Code plugin loaded from `.claude-plugin/plugin.json`. Nothing runs as a service.
Three surfaces reach a developer: plugin commands (`commands/*.md` → `/t4:*`), skills
(`skills/*/SKILL.md`, model-invoked), and the `reviewer` agent (`agents/reviewer.md`).
Hooks in `hooks/hooks.json` fire on SessionStart, PreToolUse, PostToolUse and Stop.

## Module map
- `commands/` — the three plugin slash commands
- `agents/reviewer.md` — canonical reviewer; adopted repos symlink or override it
- `skills/ai-layout/` — the `ai/` layout skill plus `templates/`, the payload copied into
  adopted repos by /t4:adopt-sdlc. Task prompts here become `/t4:<name>` there
- `skills/ai-hooks/` — hook scripts and fixtures; `_common.js` holds event parsing and
  the `ai/` detection that makes every script a no-op elsewhere
- `ai/` — this repo's own layout, symlinked to the templates (see ai/AGENTS.md)

## Data ownership
Owns the templates, the prompt text and the `ai/.sdlc.json` schema. Writes only to `ai/runs/`
and, at adopt time, `ai/.sdlc.json` in the repo it runs in. Each adopted repo owns its own
manifest and is the source of truth for its layout version; this plugin keeps no registry of
adopter versions.
Reads `ai/models.yaml` for the model each headless task pins, and for per-model prices.
Blank there means the tool's own configured model, so no provider is assumed.

## Environments
Developer machines and CI. `make ai` / `make review` are the headless path; developers use
slash commands. `GATE_ENFORCE=1` turns review blockers into a non-zero exit.

## What is deliberately not here
No application scaffolding — that belongs to an overlay plugin, which supplies it through
the template slots. This repo never names, reads or version-pins one.
No stack-specific rules in the base templates; those arrive as overlay docs and ai/skills/.
No hook that prints to stdout, and no hook that assumes a repo has the layout.
