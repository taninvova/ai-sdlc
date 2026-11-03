# ASD-007 — Terminal progress view for working agents and the pipeline
Created: 2026-11-02T20:26:45.834Z

## Request
The developer's words: "add visialization for working agents and pipeline in terminal with progress
bar or something else". In this project's terms, that means a terminal view of ai-sdlc work while
it is happening. It would show which step agents (implementers, reviewer, tester) are working,
and how far a run has got, as a progress bar or a similar display. The wording does not say which
of three things is meant:
- (a) a live view of a running `/fc:loop`: its steps, modes and worktrees;
- (b) where a delivery stands on the explore → spec → plan → test red → run → test gaps → review → report pipeline;
- (c) a view of headless runs (`make ai TASK=…`) in CI.

Each option below states which of these it serves. The choice between them is the first open question.

## What exists today
- **Loop state (facts).** `skills/ai-layout/templates/ai-factory/make/loop.js` (spec 0022) writes
  `ai-factory/runs/tmp/loop/<loop id>/state.json` under a lock (`state.lock`). The state holds the
  plan path, `effective_parallel`, `steps[]` (with `number`, `done` and `depends`), `running[]`
  (`{step, mode}` only), `pending`, `finished[]` (with `result` and `output`), `causes[]` and
  `ended`. `outcome.json` is written at `end`. Running entries carry **no start time**. Only the loop's
  `created_at` and `ended.at` are timestamps. Every subcommand prints one JSON object on stdout for
  `tasks/loop.md` to act on. Nothing renders that state for a person while the loop runs.
- **Run log and hooks (facts).** `hooks/hooks.json` writes `ai-factory/runs/log.csv`. It writes one
  row per turn (Stop) and one row per *concluded* subagent (SubagentStop), along with
  `sessions.jsonl` (with `plan_in_flight`), `cmds.jsonl` and `edits.jsonl`. No hook records that a
  subagent has *started*. Hook scripts must never write to stdout.
- **Lifecycle telemetry (facts).** `make/lifecycle-events.js` defines `run_started`,
  `phase_started`, `wait_started`/`wait_ended`, `phase_ended` and `run_ended` as immutable files.
  They are written only when a repo opts in via `ai-factory/contracts/config.json`. This repo has
  no `ai-factory/runs/lifecycle/`.
- **Static status (facts).** `/fc:state` (`skills/ai-layout/scripts/state.sh`) lists outstanding
  specs and plans. `make/delivery-status.js` (spec 0019) prints one contract delivery's status and
  says outright that it is "evidence-derived, not a claim that work is running". The drafted
  ASD-006 `/fc:current` shows a progress count (`4/11`) and the next step for each in-progress
  plan. It lists a *live view of a running /fc:run or /fc:loop* as **out of scope**, and its
  output must not change whether a loop is running (AC25).
- **Headless (facts).** `make/runner.js` reports on stderr and prints the result or loop report on
  stdout at the end. It shows no progress while the run is under way.
- **Constraints.** Node stdlib only, with no npm progress-bar library (coding-standards.md). A
  change under `templates/` reaches every adopted repo and is breaking (AGENTS.md).
  `ai-factory/make/` is a symlink: the edit goes to `skills/ai-layout/templates/ai-factory/make/`.
  No similar renderer exists anywhere in the repo.

## Options
**A. A read-only loop watcher (serves a).** Add a new `make/loop-watch.js`, or a `loop.js watch <id>`
subcommand, plus a `make loop-watch` target. It reads `state.json` without taking the lock and draws
one bar for the plan (ticked/total) and one line per step: done, running (main/worktree), waiting
on N, or failed. `--follow` redraws on an interval when stdout is a TTY. Otherwise it prints one
plain snapshot, which keeps CI logs clean. It runs in a second terminal. For elapsed time,
`loop.js` would add `started_at` to `running[]` entries. The field is additive, and readers treat
a missing one as unknown. *Changes:* make/ (template), ai.mk, a check with state fixtures, docs,
CHANGELOG. *Effort L* (size L: new artefact and check; uncertainty M: torn reads during a write,
redraw on a terminal without ANSI support). *Risks:* a reader racing the writer (mitigated by
reading again on a parse error); a template change. *Later:* the obvious base for (c), because
`TASK=loop` could start it. It does nothing for single `/fc:run` sessions. No ADR or migration.

**B. A host status line (serves a, partly b).** Ship a status-line script that Claude Code runs
after each turn. It would render one line from the session's `/fc:` task, the active loop's state
and the plan's progress, for example `fc:loop ASD-004 ▰▰▰▱▱ 3/5 · S4 S5 running`. *Changes:* a
new script under `skills/`, an install step, docs. *Effort L/XL* (uncertainty XL). *Unknowns, as
opinion:* whether a plugin can contribute a status line, or only user or project settings can;
`.claude/` is in dont-touch.md, and workspace-boundary.md forbids new external entry files without
an explicit request. It would be Claude-only, with no Codex equivalent known. It updates only per
turn, so it is not live while subagents run. It would need a spike before a spec.

**C. A pipeline strip in the static listing (serves b).** Add a phase column to `/fc:current`
(ASD-006) or `/fc:state` that draws where each delivery stands, for example
`spec ✓ plan ✓ red ✓ run ▰▰▱ 2/4 review · report ·`. It is derived from the plan, the step marks
and the contracts evidence `delivery-status.js` already reads. *Changes:* the ASD-006 script and
check, and possibly `delivery-status.js`. *Effort M/L.* *Risks:* it overlaps ASD-006 directly. The
phases before the plan (explore, spec) and the test phases can be read reliably only with
contracts on. It is a snapshot, not "working agents". *Later:* the natural follow-up once ASD-006
lands. It would amend or follow ASD-006 rather than run in parallel with it.

**D. A lifecycle-event dashboard (serves a, b, c).** Add `make lifecycle-watch`, which tails
`runs/lifecycle/events/` and draws runs, phases and waits for interactive and headless work
alike. The hooks would also emit a subagent-start event (a new PreToolUse `Task` matcher or a new
event type). *Changes:* lifecycle-events.js and its byte-identical hook copy, hooks.json, a hook
fixture, a new renderer, check-lifecycle.sh. *Effort XL* (cross-cutting, a hook change, event
schema v2). *Risks:* it works only where lifecycle is opted in. It changes a hook and a schema
that adopters record. *Later:* the most general option, at the highest cost. It probably needs an
ADR for the schema change.

## Comparison
| Option | Effort | Risk | Reversibility | Fits architecture.md | Recommendation |
|---|---|---|---|---|---|
| A loop watcher | L | low–medium | high (read-only, one additive field) | yes: loop.js owns loop state; a read-only reader beside it | **recommended** |
| B status line | L/XL | high (host support unknown, dont-touch `.claude/`) | medium | partly: crosses the workspace boundary | no, spike first |
| C pipeline strip | M/L | medium (ASD-006 overlap) | high | yes | follow-up to ASD-006 |
| D lifecycle dashboard | XL | high (hook and schema change) | low | yes, but opt-in only | not now |

## Recommendation
**Option A** (opinion). `/fc:loop` is the only place in ai-sdlc where several agents work at once,
and its `state.json` already holds almost everything a progress view needs. A read-only reader
in Node stdlib works the same under Claude, Codex and headless runs, and it leaves ASD-006's
deliberately static listing untouched. Two answers would change this. If "pipeline" means the
phases of a delivery, choose **C** as an ASD-006 follow-up. If the developer wants the view
inside the session rather than in a second terminal, a **B** spike comes first.

### Effort and risk
Effort **L**: size L (a new artefact and check under the templates), uncertainty M (a known
reader pattern; the unknowns are torn reads and terminal redraw).
- Uncertain requirements: **present**. The request does not say whether it means a, b or c.
- Authorization: **absent**. It reads local files under `ai-factory/runs/tmp/loop/` only.
- Public contracts: **present**. It adds a new make target or subcommand, and adds `started_at`
  to the `fc-loop-state` schema that adopted repos receive.
- Migrations: **absent**. The field is additive, and old states read as "unknown elapsed".
- Dependencies: **absent**. Node stdlib only.
- Service ownership: **absent**. It stays within one plugin repo, with no fleet boundary.

Present triggers: uncertain requirements and public contracts. Run `/fc:risk` once the spec exists.

## Open questions
1. Which of a (a live `/fc:loop`), b (where a delivery stands in the pipeline) or c (headless/CI) does
   "working agents and pipeline" mean? More than one?
2. Should the view run in a second terminal (A), inside the agent session (B), or as part of a
   listing command (C)?
3. Should a single `/fc:run` session (one implementer, no loop state) also be shown? If it should,
   what source records a running agent, given that no hook marks a subagent's start?
4. If C is chosen: does it amend ASD-006 before it ships, or follow it as a separate spec once
   5.2.0 lands?
5. Under `TASK=loop`, should the runner print progress itself on stderr, or leave CI to a snapshot?

## Next
`/fc:spec ai-factory/explorations/ASD-007-terminal-progress-view.md option A`
