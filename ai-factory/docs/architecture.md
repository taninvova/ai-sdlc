# Architecture — ai-sdlc

## Shape
A Claude Code plugin loaded from `.claude-plugin/plugin.json`. Nothing runs as a service.
Three surfaces reach a developer: plugin commands (`commands/*.md` → `/t4:*`), skills
(`skills/*/SKILL.md`, model-invoked), and the `reviewer` agent (`agents/reviewer.md`).
Hooks in `hooks/hooks.json` fire on SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop
and SubagentStop — the second remembering which `/t4:` command the session is running, so the rows
written later can be grouped by task, and the last writing one run-log row per concluded subagent,
from that agent's own transcript.

## Module map
- `commands/` — the three plugin slash commands
- `agents/reviewer.md` — canonical reviewer; adopted repos symlink or override it
- `skills/ai-layout/` — the `ai-factory/` layout skill plus `templates/`, the payload copied into
  adopted repos by /t4:adopt-sdlc. Task prompts here become `/t4:<name>` there
- `skills/ai-hooks/` — hook scripts and fixtures; `_common.js` holds event parsing and
  the `ai-factory/` detection that makes every script a no-op elsewhere
- `ai-factory/` — this repo's own layout, symlinked to the templates (see ai-factory/AGENTS.md)

## Data ownership
Owns the templates, the prompt text and the `ai-factory/.sdlc.json` schema. The target write boundary
is one project workspace, `ai-factory/`, as recorded in ADR 0009 and docs/workspace-boundary.md.
Current adoption still copies root entry files, sync generates tool directories, and the runner
uses system temporary prompts; plans 0011 and 0012 must close those gaps before compliance is claimed.
Each adopted repo owns its own
manifest and is the source of truth for its layout version; this plugin keeps no registry of
adopter versions.
Reads `ai-factory/models.yaml` for the model each headless task pins, and for per-model prices.
Blank there means the tool's own configured model, so no provider is assumed.

## Environments
Developer machines and CI. `make ai` / `make review` are the headless path; developers use
slash commands. `GATE_ENFORCE=1` turns review blockers into a non-zero exit.

## What is deliberately not here
No application scaffolding — that belongs to an overlay plugin, which supplies it through
the template slots. This repo never names, reads or version-pins one.
No stack-specific rules in the base templates; those arrive as overlay docs and ai-factory/skills/.
No hook that prints to stdout, and no hook that assumes a repo has the layout.
