# Architecture — ai-sdlc

## Shape
A Claude Code and Codex plugin loaded from `.claude-plugin/plugin.json` and
`.codex-plugin/plugin.json`. Nothing runs as a service. Three surfaces reach a developer: plugin
commands (`commands/*.md` → `/t4:*`, mirrored as Codex skills in `codex-skills/`), skills
(`skills/*/SKILL.md`, model-invoked), and the step agents (`agents/*.md`).
Hooks in `hooks/hooks.json` fire on SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop
and SubagentStop — the second remembering which `/t4:` command the session is running, so the rows
written later can be grouped by task, and the last writing one run-log row per concluded subagent,
from that agent's own transcript.

## Module map
- `commands/` — the plugin slash commands; task wrappers are generated from the task templates
- `codex-skills/` — generated Codex entry points reading the same task and agent procedures
- `agents/` — canonical step agents; adopted repos receive materialized copies with project additions
- `skills/ai-layout/` — the `ai-factory/` layout skill plus `templates/`, the payload copied into
  adopted repos by /t4:adopt-sdlc. Task prompts here become `/t4:<name>` there
- `skills/ai-hooks/` — hook scripts and fixtures; `_common.js` holds event parsing and
  the `ai-factory/` detection that makes every script a no-op elsewhere
- `ai-factory/` — this repo's own layout, symlinked to the templates (see ai-factory/AGENTS.md)

## Data ownership
Owns the templates, the prompt text and the `ai-factory/.sdlc.json` schema. The target write boundary
is one project workspace, `ai-factory/`, as recorded in ADR 0009 and docs/workspace-boundary.md.
Adoption creates only `ai-factory/`; host pointers are generated only on explicit request, and
runner scratch lives in `ai-factory/runs/tmp/` (plans 0011 and 0012).
Owns the artifact contract formats (`templates/ai-factory/contracts/`, validated by
`make/contracts.js`, spec 0013); adopted repos own their sidecars and evidence, opt in by creating
`ai-factory/contracts/config.json`, and keep both if they opt out. `make/delivery-report.js`
(spec 0014) assembles one delivery's evidence into `ai-factory/reports/<id>/`, read-only toward
everything else. `make/lifecycle.js` (spec 0015) aggregates opt-in lifecycle events that the
runner and the hooks write through `make/lifecycle-events.js`, mirrored byte-for-byte as
`skills/ai-hooks/scripts/_lifecycle-events.js`; the run log and `make cost` are unchanged.
Each adopted repo owns its own
manifest and is the source of truth for its layout version; this plugin keeps no registry of
adopter versions.
Reads `ai-factory/models.yaml` for the model each task pins, and for per-model prices. Blank
there means the tool's own configured model, so no provider is assumed. `make/models.js`
(spec 0016) is its only parser and resolver: the headless runner, interactive dispatch, adapter
sync and doctor all call it. Opt-in routing reaches interactive tasks only through generated,
content-addressed worker agents (`.claude/agents/`, `.codex/agents/`) written by an explicit sync.

## Environments
Developer machines and CI. `make ai` / `make review` are the headless path; developers use
slash commands. `GATE_ENFORCE=1` fails anything but a valid `approve` with no blockers; `make contracts` and
`make verify` validate and record artifact contracts where a repo opted in.

## What is deliberately not here
No application scaffolding — that belongs to an overlay plugin, which supplies it through
the template slots. This repo never names, reads or version-pins one.
No stack-specific rules in the base templates; those arrive as overlay docs and ai-factory/skills/.
No hook that prints to stdout, and no hook that assumes a repo has the layout.
