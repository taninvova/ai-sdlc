---
name: ai-layout
user-invocable: false
description: The ai/ directory every n6 repo carries — AGENTS.md contract, context docs, task prompts (explore, spec, plan, step, fix, chore, check — exposed as /ai-<name>), reviewer, plans, explorations, run log, Makefile include, tool adapters. Use when adding the layout to a repo, adding or changing a task prompt or context doc, or when a session asks where an AI-related file belongs.
---

# ai-layout

Copy `templates/` to the repo root, preserving paths, then substitute
`{{app}}` `{{stack}}` `{{commands}}` `{{owner}}` `{{backup}}` `{{date}}` `{{plugin_version}}`.
Slots for framework overlays: `{{overlay_note}}` `{{rules_extra}}` `{{dod_extra}}`
`{{dont_touch_extra}}` — a scaffold plugin fills them; `/sdlc:adopt` removes them.
Never write into `.claude/` or `.cursor/` by hand — `ai/make/sync-adapters.sh` generates them.

```
ai/AGENTS.md                  the contract, < 60 lines, no dynamic content
ai/models.yaml                n6: proxy aliases · standalone: one model · pricing block for hooks
ai/docs/architecture.md       shape, module map, data ownership, environments
ai/docs/coding-standards.md   rules that hold in every repo; overlays add framework rules
ai/docs/definition-of-done.md
ai/docs/dont-touch.md         guard-paths.js reads the backticked prefixes
ai/tasks/*.md                 explore spec plan step fix chore check  → /ai-<name> slash commands
ai/skills/                    empty here; overlays add framework skills
ai/agents/reviewer.md         project copy of the plugin reviewer (may add project checks)
ai/explorations/            /ai-explore output: options + recommendation per request
ai/plans/  ai/plans/done/     plans in flight / merged
ai/runs/log.csv               header only; hooks append
ai/make/ai.mk                 headless runner for CI (make ai / make review)
ai/make/gate.js  log.js  sync-adapters.sh
specs/                        one file per feature, Given/When/Then
docs/adr/                     0000-template.md
AGENTS.md  →  "See ai/AGENTS.md"      CLAUDE.md  →  "@ai/AGENTS.md"
```

## Rules for AGENTS.md
- Under 60 lines: what it is, commands, non-negotiables, what to read, workflow, setup, owner.
- No dates, counts, git status or generated lists — it is the cached prefix.
- Plain relative paths in the body; no `@` imports (tool-neutral). Root CLAUDE.md is the only `@`.

## Rules for task prompts
- Fixed text first; `$ARGUMENTS` at the END so the cached prefix is stable.
- Each task states: read first · steps · what done means · output.
- Code-changing tasks end by running lint/typecheck/tests and reporting.
- A task that keeps needing chat steering is missing a line; add it via MR.

## Interactive vs headless
Slash commands (generated from ai/tasks/) are the default for developers.
`make ai TASK=<name> INPUT=…` runs the same file headless — CI uses this.
Both read identical bytes, so the cache is shared.

## The loop
/ai-explore → /ai-spec → /ai-plan → /ai-step (one step) → /ai-check → commit → MR.
/ai-explore is optional for small, obvious changes; mandatory when the request could be
built more than one way or touches an RMQ contract, a schema, or a public API.

## Adding a task
1. Write ai/tasks/<name>.md with a `description:` front-matter line.
2. `bash ai/make/sync-adapters.sh` → `/<name>` appears.
3. Run it twice on a real input; fix the prompt; MR.
