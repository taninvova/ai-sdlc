---
name: ai-layout
user-invocable: false
description: The ai-factory/ directory every t4 repo carries — AGENTS.md contract, context docs, task prompts (fleet, design, adr, analyse, explore, spec, plan, test, run, fix, chore, check — exposed as /t4:<name>), reviewer, tester, architect, analyst, explorer, specifier, planner and implementer agents, plans, explorations, run log, Makefile include, tool adapters. Use when adding the layout to a repo, adding or changing a task prompt or context doc, or when a session asks where an AI-related file belongs.
---

# ai-layout

Copy `templates/` to the repo root, preserving paths, then substitute
`{{app}}` `{{stack}}` `{{commands}}` `{{owner}}` `{{backup}}` `{{date}}` `{{plugin_version}}`.
Slots for framework overlays: `{{overlay_note}}` `{{rules_extra}}` `{{dod_extra}}`
`{{dont_touch_extra}}` `{{fleet_extra}}` — a scaffold plugin fills them; `/t4:adopt-sdlc`
removes them.
Never write into `.claude/`, `.cursor/` or `.codex/` by hand — `ai-factory/make/sync-adapters.sh`
generates all three from `ai-factory/`. Codex reads `.codex/skills/<name>/SKILL.md` as slash commands;
since it cannot take subagents, the nine agent-backed tasks get an inline-the-agent note.

```
ai-factory/AGENTS.md                  the contract, < 60 lines, no dynamic content
ai-factory/models.yaml                blank = the tool's own model (any provider) · or pin an id · per-model prices
ai-factory/docs/architecture.md       shape, module map, data ownership, environments
ai-factory/docs/fleet.md              service map the architect reads; /t4:fleet fills it by asking
ai-factory/docs/knowledge.md          knowledge seam: the only file that names how a declared source is read (ADR 0007)
ai-factory/docs/coding-standards.md   rules that hold in every repo; overlays add framework rules
ai-factory/docs/definition-of-done.md
ai-factory/docs/dont-touch.md         guard-paths.js reads the backticked prefixes
ai-factory/tasks/*.md                 fleet design adr analyse explore spec plan test run fix chore check  → /t4:<name>
ai-factory/skills/                    empty here; overlays add framework skills
ai-factory/agents/reviewer.md         project copy of the plugin reviewer (may add project checks)
ai-factory/agents/tester.md           project copy of the plugin tester (test conventions go here)
ai-factory/agents/architect.md        project copy of the plugin architect (boundaries, settled ADRs)
ai-factory/agents/analyst.md          project copy of the plugin analyst (domain terms, decision owners)
ai-factory/agents/explorer.md         project copy of the plugin explorer — /t4:explore runs in it
ai-factory/agents/specifier.md        project copy of the plugin specifier — /t4:spec runs in it
ai-factory/agents/planner.md          project copy of the plugin planner — /t4:plan runs in it
ai-factory/agents/implementer.md      project copy of the plugin implementer — /t4:run runs in it (test commands go here)
ai-factory/designs/                   /t4:design output: where a capability lives, contracts, data ownership
ai-factory/analyses/                  /t4:analyse output: requirements pack — facts, assumptions, proposals, questions apart
ai-factory/explorations/            /t4:explore output: options + recommendation per request
ai-factory/plans/  ai-factory/plans/done/     plans in flight / merged
ai-factory/runs/log.csv               header only; the Stop hook and ai-factory/make/log.js append the same 17 columns
ai-factory/make/ai.mk                 headless runner for CI (make ai / make review)
ai-factory/make/gate.js  log.js  cost.js  sync-adapters.sh
                                      cost.js reads log.csv for `make cost` — read-only, 17 columns by name
ai-factory/.sdlc.json                 which ai-sdlc version this repo holds + a hash per received file;
                              written by /t4:adopt-sdlc, read by /t4:sync-sdlc, never by hand
ai-factory/specs/              one file per feature, Given/When/Then
ai-factory/adr/                0000-template.md; /t4:adr writes here
AGENTS.md  →  "See ai-factory/AGENTS.md"      CLAUDE.md  →  "@ai-factory/AGENTS.md"
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
Slash commands (generated from ai-factory/tasks/) are the default for developers.
`make ai TASK=<name> INPUT=…` runs the same file headless — CI uses this. Pass
`INPUT_FILE=<path>` instead for anything large or containing `$`, quotes or newlines (a diff):
make re-expands values routed through a variable, a file is passed through untouched.
Both read identical bytes, so the cache is shared.

## The loop
/t4:explore → /t4:spec → /t4:plan → /t4:test red → /t4:run (one step) → /t4:test gaps → /t4:check → commit → MR.
/t4:explore is optional for small, obvious changes; mandatory when the request could be
built more than one way or touches an RMQ contract, a schema, or a public API.

/t4:design comes before all of it, and only when the capability spans services, its home is
undecided, or it creates or changes a contract between services — it decides WHERE a
capability lives and feeds one or more specs, possibly across repos. /t4:explore decides HOW
to build it in one repo whose home is already known. /t4:adr records any decision that
outlives the change, including every new dependency. /t4:fleet fills ai-factory/docs/fleet.md, the
map /t4:design reads — run it once per repo, then whenever a service or contract changes.

/t4:analyse comes before /t4:explore and /t4:spec when the request is still a business
description — several actors, permissions, rules, a lifecycle, undecided policy. It settles
WHAT is needed as a pack in ai-factory/analyses/ that /t4:spec reads; it never writes a spec, a plan
or code, and never turns an assumption into a fact.

## Adding a task
1. Write ai-factory/tasks/<name>.md with a `description:` front-matter line.
2. `bash ai-factory/make/sync-adapters.sh` → `/<name>` appears.
3. Run it twice on a real input; fix the prompt; MR.
