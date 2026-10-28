# {{app}} — instructions for AI tools

## What this is
One paragraph: what this project does and who uses it. Stack: {{stack}}. Scaffolded with ai-sdlc {{plugin_version}}{{overlay_note}}.

## Commands
{{commands}}
Slash commands: /fc:start /fc:continue /fc:fleet /fc:design /fc:adr /fc:analyse /fc:explore /fc:spec /fc:plan /fc:risk /fc:test /fc:run /fc:loop /fc:fix /fc:chore /fc:quick /fc:review /fc:report
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
Use /fc:start <request> to choose one existing workflow interactively; direct commands remain available.
Start only classifies, preserves original input and dispatches the destination independently.
Resume a contracts-enabled planned delivery with /fc:continue <delivery id>: it inspects evidence
read-only, asks when phases are uncertain, stops on spec drift for you to reconcile, and hands off
to at most one plan, test, run, review or report task in this session. Paths, quick deliveries and
contracts-disabled repos are unsupported. Headless TASK=start and TASK=continue are unsupported;
CI must name a destination task.
Small, understood local change: /fc:quick. Bug: /fc:fix. Maintenance: /fc:chore.
Uncertain requirements, authorization, public contracts, migrations, dependencies or service
boundaries: /fc:explore → /fc:spec → /fc:plan → /fc:test red → /fc:run → /fc:test gaps → /fc:review (→ /fc:report with contracts).
One step per /fc:run; the opt-in exception is /fc:loop <plan>: every unticked step, then one /fc:review, never a commit on your branch.
Preserve existing changes. Never reset a working tree to start or finish a step. File count is
not a risk classifier. Match verification to the phase and run required final checks at completion.

## Setup (once per developer)
Works with whatever provider your tool is already configured with — nothing here assumes one.
Pointing at a gateway instead: set the tool's base-URL and key env vars (Claude Code:
ANTHROPIC_BASE_URL, ANTHROPIC_API_KEY). ai-factory/models.yaml pins a model per task if you need one.
Personal preferences go in ~/.claude/CLAUDE.md or CLAUDE.local.md, never in ai-factory/.

## Owner
Owner: {{owner}} · Backup: {{backup}} · Prompt and doc changes via MR with a before/after run linked.
