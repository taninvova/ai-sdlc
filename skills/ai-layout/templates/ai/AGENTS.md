# {{app}} — instructions for AI tools

## What this is
One paragraph: what this project does and who uses it. Stack: {{stack}}. Scaffolded with ai-sdlc {{plugin_version}}{{overlay_note}}.

## Commands
{{commands}}
Slash commands: /t4:fleet /t4:design /t4:adr /t4:analyse /t4:explore /t4:spec /t4:plan /t4:test /t4:run /t4:fix /t4:chore /t4:check
Headless (CI only): make ai TASK=<name> INPUT="…"

## Non-negotiable rules
- Never edit paths listed in ai/docs/dont-touch.md
- Every behaviour change ships with a test
- No new dependency without an ADR in docs/adr/
{{rules_extra}}

## Read before working
ai/docs/coding-standards.md · ai/docs/definition-of-done.md · ai/docs/architecture.md · ai/docs/fleet.md
The spec in specs/ for the feature · the plan in ai/plans/ if one exists · ai/skills/<topic> for the area you touch

## Workflow
/t4:explore (options) → /t4:spec → /t4:plan → /t4:test red → /t4:run one step at a time → /t4:test gaps → /t4:check → commit `ai(<task>): …` → MR (label ai-assisted)
Plan first for anything touching more than ~3 files. Reset the working tree between steps.
Steering in chat for 20+ minutes with code changed? Stop, write the decision into the plan, commit, continue.

## Setup (once per developer)
Works with whatever provider your tool is already configured with — nothing here assumes one.
Pointing at a gateway instead: set the tool's base-URL and key env vars (Claude Code:
ANTHROPIC_BASE_URL, ANTHROPIC_API_KEY). ai/models.yaml pins a model per task if you need one.
Personal preferences go in ~/.claude/CLAUDE.md or CLAUDE.local.md, never in ai/.

## Owner
Owner: {{owner}} · Backup: {{backup}} · Prompt and doc changes via MR with a before/after run linked.
