# ai-sdlc — instructions for AI tools

## What this is
The `ai-sdlc` Claude Code plugin: the operating model for AI-native delivery at t4. It ships
the `ai-factory/` layout as templates, the task prompts, the reviewer agent, and the logging and
dont-touch hooks. Standalone: it depends on no other repo. Framework overlay plugins build
on it through the `{{…_extra}}` template slots.
Stack: markdown prompts + Node hook scripts + bash. No application code, no build step.

## Commands
Syntax check hooks: `for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done`
Syntax check bash: `bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh`
Adapter sync (this repo): `bash ai-factory/make/sync-adapters.sh`
Checks (all of them): `for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f" || echo "FAIL $f"; done`
  — never pipe one to `tail`: the pipeline's status is `tail`'s, and a failure reads as a pass
Hook fixtures: `node skills/ai-hooks/scripts/session-stop.js < skills/ai-hooks/fixtures/stop.json`
Slash commands: /t4:fleet /t4:design /t4:adr /t4:analyse /t4:explore /t4:spec /t4:plan /t4:test /t4:run /t4:fix /t4:chore /t4:quick /t4:check
Headless (CI only): make ai TASK=<name> INPUT="…"

## This repo is its own template
`ai-factory/tasks/`, `ai-factory/agents/` and `ai-factory/make/` here are **symlinks** into
`skills/ai-layout/templates/` and `agents/`. Edit the target, never the symlink, and never
add a real file under `ai-factory/tasks/` — it would fork from what adopted repos receive.
The layout exists here so plugin changes run through the loop they prescribe.

## Non-negotiable rules
- Never edit paths listed in ai-factory/docs/dont-touch.md
- A prompt, skill or hook change ships with a before/after run linked in the MR
- Hook scripts never print to stdout (cache-neutral) and no-op outside a repo with `ai-factory/`
- Template changes are breaking for every adopted repo — say so in the MR and CHANGELOG
- Keep plugin-owned project work in ai-factory/; follow docs/workspace-boundary.md. Preserve existing external entry files; create no new ones without an explicit request.

## Read before working
Read the applicable protection rules and coding standards, then only the context this task needs.
Read architecture when placement is uncertain; fleet for cross-service work; the named spec/plan
when the selected workflow requires them. Reuse unchanged context already in this session.

## Workflow
Small, understood local change: /t4:quick. Bug: /t4:fix. Maintenance: /t4:chore.
Uncertain requirements, authorization, public contracts, migrations, dependencies or service
boundaries: /t4:explore → /t4:spec → /t4:plan → /t4:test red → /t4:run → /t4:test gaps → /t4:check.
Preserve existing changes. Never reset a working tree to start or finish a step. File count is
not a risk classifier. Match verification to the phase and run required final checks at completion.

## Setup (once per developer)
Works with whatever provider your tool is already configured with — nothing here assumes one.
Pointing at a gateway instead: set the tool's base-URL and key env vars (Claude Code:
ANTHROPIC_BASE_URL, ANTHROPIC_API_KEY). ai-factory/models.yaml pins a model per task if you need one.
Personal preferences go in ~/.claude/CLAUDE.md or CLAUDE.local.md, never in ai-factory/.

## Owner
Owner: tanin · Backup: TBD · Prompt and doc changes via MR with a before/after run linked.
