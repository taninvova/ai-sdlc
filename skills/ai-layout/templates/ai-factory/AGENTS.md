# {{app}} — instructions for AI tools

## What this is
One paragraph: what this project does and who uses it. Stack: {{stack}}. Scaffolded with ai-sdlc {{plugin_version}}{{overlay_note}}.

## Commands
{{commands}}
Slash commands: /t4:fleet /t4:design /t4:adr /t4:analyse /t4:explore /t4:spec /t4:plan /t4:test /t4:run /t4:fix /t4:chore /t4:quick /t4:check /t4:report
Headless (CI only): make -f ai-factory/make/ai.mk ai TASK=<name> INPUT="…"

## Non-negotiable rules
- Never edit paths listed in ai-factory/docs/dont-touch.md
- Every behaviour change ships with a test
- No new dependency without an ADR in ai-factory/adr/
- Keep project work in ai-factory/; follow docs/workspace-boundary.md. Preserve existing external entry files; create no new ones without an explicit request.
{{rules_extra}}

## Read before working
Read the applicable protection rules and coding standards, then only the context this task needs.
Read architecture when placement is uncertain; fleet for cross-service work; the named spec/plan
when the selected workflow requires them. Reuse unchanged context already in this session.

## Workflow
Small, understood local change: /t4:quick. Bug: /t4:fix. Maintenance: /t4:chore.
Uncertain requirements, authorization, public contracts, migrations, dependencies or service
boundaries: /t4:explore → /t4:spec → /t4:plan → /t4:test red → /t4:run → /t4:test gaps → /t4:check (→ /t4:report with contracts).
Preserve existing changes. Never reset a working tree to start or finish a step. File count is
not a risk classifier. Match verification to the phase and run required final checks at completion.

## Setup (once per developer)
Works with whatever provider your tool is already configured with — nothing here assumes one.
Pointing at a gateway instead: set the tool's base-URL and key env vars (Claude Code:
ANTHROPIC_BASE_URL, ANTHROPIC_API_KEY). ai-factory/models.yaml pins a model per task if you need one.
Personal preferences go in ~/.claude/CLAUDE.md or CLAUDE.local.md, never in ai-factory/.

## Owner
Owner: {{owner}} · Backup: {{backup}} · Prompt and doc changes via MR with a before/after run linked.
