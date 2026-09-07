# ai-sdlc — instructions for AI tools

## What this is
The `ai-sdlc` Claude Code plugin: the operating model for AI-native delivery at t4. It ships
the `ai/` layout as templates, the task prompts, the reviewer agent, and the logging and
dont-touch hooks. Standalone: it depends on no other repo. Framework overlay plugins build
on it through the `{{…_extra}}` template slots.
Stack: markdown prompts + Node hook scripts + bash. No application code, no build step.

## Commands
Syntax check hooks: `for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done`
Syntax check bash: `bash -n skills/ai-layout/templates/ai/make/sync-adapters.sh`
Adapter sync (this repo): `bash ai/make/sync-adapters.sh`
Hook fixtures: `node skills/ai-hooks/scripts/session-stop.js < skills/ai-hooks/fixtures/stop.json`
Slash commands: /t4:fleet /t4:design /t4:adr /t4:explore /t4:spec /t4:plan /t4:test /t4:step /t4:fix /t4:chore /t4:check
Headless (CI only): make ai TASK=<name> INPUT="…"

## This repo is its own template
`ai/tasks/`, `ai/agents/` and `ai/make/` here are **symlinks** into
`skills/ai-layout/templates/` and `agents/`. Edit the target, never the symlink, and never
add a real file under `ai/tasks/` — it would fork from what adopted repos receive.
The layout exists here so plugin changes run through the loop they prescribe.

## Non-negotiable rules
- Never edit paths listed in ai/docs/dont-touch.md
- A prompt, skill or hook change ships with a before/after run linked in the MR
- Hook scripts never print to stdout (cache-neutral) and no-op outside a repo with `ai/`
- Template changes are breaking for every adopted repo — say so in the MR and CHANGELOG

## Read before working
docs/workflow.md for how the commands fit together · ai/docs/coding-standards.md · ai/docs/definition-of-done.md · ai/docs/architecture.md · ai/docs/fleet.md
The spec in specs/ for the change · the plan in ai/plans/ if one exists

## Workflow
/t4:explore (options) → /t4:spec → /t4:plan → /t4:test red → /t4:step one step at a time →
/t4:test gaps → /t4:check → commit `ai(<task>): …` → MR (label ai-assisted)

## Setup (once per developer)
Works with whatever provider your tool is already configured with — nothing here assumes one.
Pointing at a gateway instead: set the tool's base-URL and key env vars (Claude Code:
ANTHROPIC_BASE_URL, ANTHROPIC_API_KEY). ai/models.yaml pins a model per task if you need one.
Personal preferences go in ~/.claude/CLAUDE.md or CLAUDE.local.md, never in ai/.

## Owner
Owner: tanin · Backup: TBD · Prompt and doc changes via MR with a before/after run linked.
