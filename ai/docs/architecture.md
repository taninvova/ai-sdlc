# Architecture — ai-sdlc

## Shape
A Claude Code plugin loaded from `.claude-plugin/plugin.json`. Nothing runs as a service.
Three surfaces reach a developer: plugin commands (`commands/*.md` → `/sdlc:*`), skills
(`skills/*/SKILL.md`, model-invoked), and the `reviewer` agent (`agents/reviewer.md`).
Hooks in `hooks/hooks.json` fire on SessionStart, PreToolUse, PostToolUse and Stop.

## Module map
- `commands/` — the three plugin slash commands
- `agents/reviewer.md` — canonical reviewer; adopted repos symlink or override it
- `skills/ai-layout/` — the `ai/` layout skill plus `templates/`, the payload copied into
  adopted repos by /sdlc:adopt. Task prompts here become `/ai-<name>` there
- `skills/ai-hooks/` — hook scripts and fixtures; `_common.js` holds event parsing and
  the `ai/` detection that makes every script a no-op elsewhere
- `ai/` — this repo's own layout, symlinked to the templates (see ai/AGENTS.md)

## Data ownership
Owns the templates and the prompt text. Writes only to `ai/runs/` in the repo it runs in.
Reads `ai/models.yaml` for model aliases; the LiteLLM proxy at llm.nsix.io resolves them.

## Environments
Developer machines and CI. `make ai` / `make review` are the headless path; developers use
slash commands. `GATE_ENFORCE=1` turns review blockers into a non-zero exit.

## What is deliberately not here
No application scaffolding — that belongs to nextjs-scaffold and nestjs-scaffold.
No stack-specific rules in the base templates; those arrive as overlay docs and ai/skills/.
No hook that prints to stdout, and no hook that assumes a repo has the layout.
