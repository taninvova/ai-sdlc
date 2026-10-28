---
name: ai-layout
user-invocable: false
description: The ai-factory/ directory every fc repo carries — AGENTS.md contract, context docs, task prompts (fleet, design, adr, analyse, explore, spec, plan, risk, test, run, loop, fix, chore, quick, review, report — exposed as /fc:<name>), reviewer, tester, architect, analyst, risk, explorer, specifier, planner and implementer agents, plans, explorations, risk files, run log, Makefile include, tool adapters. Use when adding the layout to a repo, adding or changing a task prompt or context doc, or when a session asks where an AI-related file belongs.
---

# ai-layout

Use `node <installed-plugin>/skills/ai-layout/scripts/adopt.js .` for new adoption. It
creates only `ai-factory/`, fills project placeholders, writes the project name and ID prefix
(`--name`, `--prefix`; Pembina → PMB) to `ai-factory/project.json`, detects declared commands without
running them, and refuses an existing workspace. Existing root and host files are preserved.
The installed plugin supplies hooks and all 25 native Claude commands (one of them the deprecated
/fc:check, which runs the review task); the workspace carries complete
local task and agent procedures, runner scripts and project additions.

Never write into `.claude/`, `.cursor/` or `.codex/` by hand. Default sync writes no external
files. Only after an explicit request, select adapters with
`node ai-factory/make/sync-adapters.js --adapters=claude,codex,cursor` (or a selected subset).
Generated entries point at local canonical content. Codex skills and adapters use native delegation when available, with complete local agent
procedures; otherwise they run inline and label reviews as self-checks.

```
ai-factory/AGENTS.md                  the contract, < 60 lines, no dynamic content
ai-factory/models.yaml                blank = the tool's own model (any provider) · or pin an id · opt-in per-task routing · per-model prices
ai-factory/docs/architecture.md       shape, module map, data ownership, environments
ai-factory/docs/fleet.md              service map the architect reads; /fc:fleet fills it by asking
ai-factory/docs/knowledge.md          knowledge seam: the only file that names how a declared source is read (ADR 0007)
ai-factory/docs/coding-standards.md   rules that hold in every repo; overlays add framework rules
ai-factory/docs/definition-of-done.md
ai-factory/docs/dont-touch.md         guard-paths.js reads the backticked prefixes
ai-factory/tasks/*.md                 fleet design adr analyse explore spec plan risk test run loop fix chore quick review report  → /fc:<name>
ai-factory/skills/                    empty here; overlays add framework skills
ai-factory/agents/reviewer.md         project copy of the plugin reviewer (may add project checks)
ai-factory/agents/tester.md           project copy of the plugin tester (test conventions go here)
ai-factory/agents/architect.md        project copy of the plugin architect (boundaries, settled ADRs)
ai-factory/agents/analyst.md          project copy of the plugin analyst (domain terms, decision owners)
ai-factory/agents/risk.md             project copy of the plugin risk agent — /fc:risk runs in it
ai-factory/agents/explorer.md         project copy of the plugin explorer — /fc:explore runs in it
ai-factory/agents/specifier.md        project copy of the plugin specifier — /fc:spec runs in it
ai-factory/agents/planner.md          project copy of the plugin planner — /fc:plan runs in it
ai-factory/agents/implementer.md      project copy of the plugin implementer — /fc:run runs in it (test commands go here)
ai-factory/designs/                   /fc:design output: where a capability lives, contracts, data ownership
ai-factory/analyses/                  /fc:analyse output: requirements pack — facts, assumptions, proposals, questions apart
ai-factory/explorations/            /fc:explore output: options + recommendation per request
ai-factory/risks/                     /fc:risk output: one file per spec (its plan shares it) or change; committed by default
ai-factory/plans/  ai-factory/plans/done/     plans in flight / merged
ai-factory/runs/log.csv               header only; the Stop hook and ai-factory/make/log.js append the same 17 columns
ai-factory/make/ai.mk                 headless runner for CI (make ai / review / contracts / verify / ids-check)
ai-factory/make/runner.js  models.js  gate.js  contracts.js  delivery-report.js  delivery-status.js  continue.js  assurance.js  ids.js  loop.js  lifecycle.js  lifecycle-events.js  safe-files.js  log.js  cost.js  sync-adapters.js  sync-adapters.sh
                                      models.js parses models.yaml and resolves each task's model — runner, routed dispatch, sync and doctor share it
                                      cost.js reads log.csv for `make cost` — read-only, 17 columns by name
                                      contracts.js validates spec/plan/quick sidecars and records evidence (opt-in)
                                      delivery-status.js prints one delivery's read-only status for `/fc:state --delivery <id>`
                                      continue.js inspects a planned delivery read-only and hands off one task for /fc:continue
                                      assurance.js shows, selects (`set <preset> --apply`) and checks completion for an opt-in assurance preset
                                      ids.js takes the next `<PREFIX>-<NNN>` ID (PMB-001) and creates each new artefact (`ids.js new <kind> <slug>`); the format is owned there alone, legacy four-digit and letter-and-digit names stay valid, `ids.js check` (make ids-check) finds clashes
                                      loop.js owns /fc:loop's decisions: plan selection, `Depends on:` validation, scheduling, worktrees, apply-back, ticks, stop causes and the TASK=loop exit code
ai-factory/contracts/                 README + v1 schemas; config.json (created by `contracts.js enable`) opts in
ai-factory/project.json               the project's name and artefact ID prefix ({"name": "Pembina", "prefix": "PMB"}); adoption asks and writes it (`ids.js init`), never by hand
ai-factory/assurance.json             opt-in preset selection (light|standard|strict), written only by `assurance.js set <preset> --apply`; adoption and sync never create it
ai-factory/quick/  ai-factory/evidence/   with contracts only: quick checklists; committed verification evidence
ai-factory/reports/<id>/              make delivery-report (/fc:report): completion.md + completion.json snapshots
ai-factory/runs/tmp/worktrees/        /fc:loop's temporary git worktrees; /fc:review, make review and hooks skip it, and test, lint and typecheck tools must exclude it
ai-factory/runs/lifecycle/            opt-in lifecycle events, one immutable file each (gitignored); make lifecycle reads them
ai-factory/.sdlc.json                 which ai-sdlc version this repo holds + a hash per received file;
                              written by /fc:adopt-sdlc, read by /fc:sync-sdlc, never by hand
ai-factory/specs/              one file per feature, Given/When/Then
ai-factory/adr/                0000-template.md; /fc:adr writes here
```

## Rules for AGENTS.md
- Under 60 lines: what it is, commands, non-negotiables, what to read, workflow, setup, owner.
- No dates, counts, git status or generated lists — it is the cached prefix.
- Plain relative paths in the body; no `@` imports (tool-neutral). Root CLAUDE.md is the only `@`.

## Rules for task prompts
- Fixed text first; `$ARGUMENTS` at the END so the cached prefix is stable.
- Each task states: read first · steps · what done means · output.
- Code-changing tasks use their declared red/step/final verification phase and report evidence. Run full required checks at completion.
- A task that keeps needing chat steering is missing a line; add it via MR.

## Interactive vs headless
Installed plugin commands or explicit task paths are the default in strict mode. Optional
project adapters expose the same tasks only when requested. From the project root,
`make -f ai-factory/make/ai.mk ai TASK=<name> INPUT=…` runs the local file headless.
Use `INPUT_FILE=<path>` for large or multiline input; configuration is passed as data,
never shell program text. No root Makefile is required. Match verification to the phase.

## Strict workspace default

Adoption copies only ai-factory/ and preserves all existing root files. Use the installed
`adopt.js` script; it detects commands without running them. Complete agent templates are
materialized from canonical agents plus explicit project additions before release. Run
`node skills/ai-layout/scripts/materialize-agents.js --check` to verify that payload.
No sibling repo, overlay or integration is required. Scratch belongs in ai-factory/runs/tmp/.
Default sync changes no external files; host pointers require an explicit request. Read
ai-factory/docs/workspace-boundary.md for ownership and host limitations.

## The loop

For a local, understood small enhancement, use `/fc:quick`: acceptance checklist, implementation, relevant checks, and labeled self-review. Use `/fc:fix` for a bug and `/fc:chore` for maintenance. Escalate uncertain or high-risk work to the planned loop.
/fc:explore → /fc:spec → /fc:plan → /fc:test red → /fc:run (one step) → /fc:test gaps → /fc:review → commit → MR.
/fc:loop <plan> is the opt-in exception to one step per /fc:run: every unticked step, independent
ones in parallel worktrees, then one /fc:review, and never a commit on the developer's branch.
/fc:explore is optional for small, obvious changes; mandatory when the request could be
built more than one way or touches an RMQ contract, a schema, or a public API.

/fc:design comes before all of it, and only when the capability spans services, its home is
undecided, or it creates or changes a contract between services — it decides WHERE a
capability lives and feeds one or more specs, possibly across repos. /fc:explore decides HOW
to build it in one repo whose home is already known. /fc:adr records any decision that
outlives the change, including every new dependency. /fc:fleet fills ai-factory/docs/fleet.md, the
map /fc:design reads — run it once per repo, then whenever a service or contract changes.

/fc:analyse comes before /fc:explore and /fc:spec when the request is still a business
description — several actors, permissions, rules, a lifecycle, undecided policy. It settles
WHAT is needed as a pack in ai-factory/analyses/ that /fc:spec reads; it never writes a spec, a plan
or code, and never turns an assumption into a fact.

## Adding a task
1. Write ai-factory/tasks/<name>.md with a `description:` front-matter line.
2. Use the installed command or explicit task path in strict mode. If the user requested external adapters, run `node ai-factory/make/sync-adapters.js --adapters=<claude|codex|cursor>`; the selected `/fc:<name>` entry appears.
3. Run it twice on a real input; fix the prompt; MR.
