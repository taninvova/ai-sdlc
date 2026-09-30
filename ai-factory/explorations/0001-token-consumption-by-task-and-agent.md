# 0001 — Track token consumption by task and by agent

## Request

The factory should be able to say how many tokens — and therefore how much money — each t4
task (`/t4:explore`, `/t4:spec`, `/t4:plan`, `/t4:run`, …) and each agent (`explorer`,
`specifier`, `planner`, `implementer`, `reviewer`, `tester`, `architect`, `analyst`) consumed,
per run, across the tools this plugin vends adapters for. Today `ai-factory/runs/log.csv` has
16 columns including `task`, tokens and `cost_usd`, but for an interactive session `task` is
always blank and no column names an agent — so an owner can see that a repo spent money, not
where it went.

## What exists today

**The log and its two writers.** `ai-factory/runs/log.csv` carries
`ts,session_id,source,user,branch,task,tool,model,turns,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,hit_rate,cost_usd,accepted`.
Two writers produce it and must stay byte-identical in their header and schema guard:
`skills/ai-hooks/scripts/session-stop.js` (source `session`) and
`skills/ai-layout/templates/ai-factory/make/log.js` (source `make`), pinned together by
`skills/ai-hooks/fixtures/check-log-schema.sh`. The shared guard lives in
`skills/ai-hooks/scripts/_log-schema.js`; the header appears a second time, by hand, in
`log.js` because an adopted repo cannot `require` the plugin's copy. Rows are buffered in
`log.pending.csv` (gitignored) and moved into `log.csv` by
`skills/ai-hooks/scripts/log-flush.js` on `git commit`, or by `make log-flush`.

**Pricing already works.** `session-stop.js` lines 19–37 price a run with the model the
transcript says ran, reading the `pricing:` block of `ai-factory/models.yaml` — exact id, then
longest-prefix match, then `default`, then built-in figures marked `~`. Nothing about per-agent
accounting needs new pricing code.

**Three gaps, all visible in this repo's own log.**

1. *`task` is never filled interactively.* `session-stop.js:50` writes `""` in that position.
   Only `make ai TASK=<name>` fills it (`ai.mk:43`).
2. *No agent dimension at all.* `ai-factory/analyses/0001` already records this: **FR-020**
   (cost accounting — document the under-count), **DEC-010**, **Q-006** ("`tool` column for a
   delegated step: still `claude`/`codex` with no per-agent attribution?") and **PROP-013**
   ("have `/t4:explore` consider a SubagentStop hook … to recover subagent token usage").
   This exploration is that PROP-013.
3. *Rows are cumulative, not deltas, and cannot be summed.* Stop fires after every turn and
   `session-stop.js` re-sums the whole transcript each time. All 19 rows in
   `ai-factory/runs/log.csv` share one `session_id`, with `turns` climbing 96 → 1039 and
   `cost_usd` climbing $4.19 → $159.47. Adding the `cost_usd` column up gives ~$1,240 for
   ~$159 of work. Any "spend by task" report built on this column is wrong before it starts.

**What the tools actually expose** (measured on this machine: Claude Code 2.1.274,
codex-cli 0.155.1, from `~/.claude/projects/` and `~/.codex/sessions/`):

| | per-session tokens | per-task | per-agent | cost |
|---|---|---|---|---|
| Claude Code, interactive | yes — `message.usage` per turn in the main transcript; already summed | not a field, but the transcript carries a `<command-name>/t4:spec</command-name>` marker on the user turn, and `UserPromptSubmit` sees the typed text | **yes** — each subagent writes `<project>/<session_id>/subagents/agent-<agentId>.jsonl` plus `agent-<agentId>.meta.json` (`agentType`, `description`, `toolUseId`, `spawnDepth`, `requestShape`) | none reported; priced locally from `models.yaml` |
| Claude Code, `claude -p --output-format json` | yes — `usage`, `num_turns`, and a provider-reported `total_cost_usd` | yes, `make ai TASK=` already passes it | **counts but no tokens**: the result carries `subagent_stats` (`spawned`, `requested.{background,foreground,unset}`, `started_in_background`, `completed`, `failed`, `by_type`), so agent *types* and counts are there and per-agent spend is not — hooks do fire here (EXD-002 was run in this mode), so a hook-based answer covers this path too | yes, `total_cost_usd` |
| Codex, `codex exec --json` | yes — `turn.completed.usage`, parsed by `log.js:90-101`; rollouts also carry a `token_count` event with `total_token_usage` | yes, via `TASK` / the `t4-<task>` skill name | **impossible by construction** — `sync-adapters.sh` tells Codex "plugins cannot ship subagents … read `ai-factory/agents/<x>.md` and follow it yourself, in this session". One session is the task *and* the agent | none; `cost_usd` is deliberately left empty |
| Cursor | **no local export** — the whole adapter is `.cursor/rules/ai.mdc`, an always-apply rule | no | no | no; usage exists only in Cursor's own dashboard/admin API |

Three measured facts that decide the options:

- **Subagent tokens are not in the main transcript, and no longer even as sidechain rows.**
  Across every transcript in `~/.claude/projects/`, `isSidechain` appears zero times in a main
  file; every sidechain row is in the separate `subagents/` file. `session-stop.js` reads only
  `ev.transcript_path`, so a delegated step contributes **nothing** to the row today. In one
  real session (`25860e5f`) the main transcript is 919 turns / 335M tokens and 18 subagents add
  44.2M tokens — 12% of the spend, entirely invisible, and the share is far higher in a session
  that mostly delegates.
- **Claude Code has the hook seam already.** Strings in the 2.1.274 binary: `SubagentStart` —
  *"Input to command is JSON with agent_id and agent_type"*; `SubagentStop` — *"Right before a
  subagent (Agent tool call) concludes its response. Input to command is JSON with agent_id,
  agent_type, and agent_transcript_path"*; both match on the `agent_type` field.
  `hooks/hooks.json` registers neither (SessionStart, PreToolUse ×2, PostToolUse ×2, Stop only).
- **Agent → task attribution is derivable and exact.** Joining each `.meta.json`'s `toolUseId`
  to the `Agent` tool-use block in the main transcript, then back to the nearest preceding
  `<command-name>`, resolved **18 of 18** agents in session `25860e5f` (`explorer`→`/t4:explore`,
  `specifier`→`/t4:spec`, `planner`→`/t4:plan`, ten `implementer`s→`/t4:run`, `architect`→`/t4:adr`).
  Note the one crossing: a `specifier` was spawned under `/t4:run`, so a static agent→task map
  would have mis-filed it.

Reading the `Agent` tool *result* is a dead end: it carried `agentType`/`totalTokens`/`usage`
only for **synchronous** agents and only the final iteration; every t4 step agent observed runs
`requestShape: background`, and those results carry no usage at all.

**No dependencies anywhere in the machinery.** Measured: the plugin has no `package.json`, and
every Node file under `skills/ai-hooks/scripts/` and `templates/ai-factory/make/` requires only
`fs`, `path`, `child_process` and its own relative siblings. `ai-factory/AGENTS.md` calls the
stack "markdown prompts + Node hook scripts + bash. No application code, no build step";
`.claude-plugin/plugin.json` advertises "Standalone — no dependency on any other repo and no
runtime dependency"; `ai-factory/docs/architecture.md` says "Nothing runs as a service".

## Options — collection

(Option C below is the collection-side "change nothing, reconcile on demand" choice; the
*surface* question is separate and is treated in **Options — reporting surface**.)

### A — `SubagentStop` hook: one row per agent, written at the source

Register `SubagentStop` in `hooks/hooks.json` and add
`skills/ai-hooks/scripts/subagent-stop.js`: read `agent_id`, `agent_type` and
`agent_transcript_path` from the event, sum that transcript's usage exactly as `session-stop.js`
does, price it with the same `models.yaml` logic, append one row with `source=agent`, the new
`agent` column filled, and the task resolved from a session-scoped task file (below). Fix (3) at
the same time: make `session-stop.js` emit the session's *delta* since its last row, or dedupe
on `session_id` at flush.

Task attribution: a `UserPromptSubmit` hook writes the `/t4:<name>` it sees to
`ai-factory/runs/.task.<session_id>` (gitignored); Stop and SubagentStop read it. Cheap,
silent, and — unlike a static agent→task map — right when `/t4:run` spawns a `specifier`.

*Changes:* `hooks/hooks.json`, one new script, `_log-schema.js` HEADER (+`agent`),
the hand-copied header and guard in `templates/ai-factory/make/log.js`,
`fixtures/check-log-schema.sh`, `skills/ai-hooks/SKILL.md`,
`templates/ai-factory/docs/workflow.md` §9, CHANGELOG.
*Effort:* **M** — the script is ~40 lines of reused code; the cost is the schema ripple across
two writers plus the fixture that pins them, and the docs that quote the 16 columns verbatim.
*Risks:* a header change moves every adopted repo's existing rows to `log.previous.csv` on the
next write — breaking, and `ai-factory/AGENTS.md` requires it to be called so in the MR and
CHANGELOG. `stop_hook_active` must be honoured so a resumed agent is not double-counted.
The firing risk is **gone** — see EXD-002 below: both events fire for both request shapes, and
the `SubagentStop` payload carries `agent_transcript_path`, so the row is computable at Stop
without touching the parent transcript.
*Later:* makes per-agent budgets and a `/t4:cost` report trivial; adds a second hook event to
keep working across Claude Code versions.
*ADR:* none — no new dependency; a documented hook event of a tool already required.

### B — Reconcile at Stop from the `subagents/` directory

No new hook event. `session-stop.js` derives
`dirname(transcript_path)/<session_id>/subagents/*.jsonl`, sums each alongside its `.meta.json`
for `agentType`, and emits the session row plus one row per agent. Task comes from the main
transcript's `<command-name>` markers joined on `toolUseId` — the join proved above at 18/18,
so no new hook and no state file.

*Changes:* `session-stop.js` and the same schema ripple as A. No `hooks.json` change.
*Effort:* **M**, similar to A, minus the hooks.json entry, plus the join code.
*Risks:* the `<project>/<session>/subagents/` layout is an undocumented internal of Claude Code;
a version bump moves it and the hook — which must never print — fails silently, so the log just
quietly stops growing an agent dimension. Cost is the other problem: Stop fires every turn and
this re-reads every subagent transcript each time (44 MB in the session measured), on the
critical path of the turn.
*Later:* works on any Claude Code that writes those files, including older ones; harder to keep
correct.

### C — A reader, not a writer: reconcile the transcripts on demand

Leave both writers and the schema exactly as they are. Add
`ai-factory/make/cost.js` and a `cost` target that reconciles on demand: the session and
subagent transcripts under `~/.claude/projects/`, the `make ai` run JSONs in
`ai-factory/runs/*.json`, and `models.yaml` pricing — printing spend by task, by agent and by
branch. Nothing is breaking; no adopted repo's log migrates.

*Changes:* one new file in `templates/ai-factory/make/`, one `ai.mk` target, one doc section.
*Effort:* **S** — no schema, no hook, no fixture change, no CHANGELOG breaking note.
*Risks:* answers only about what is still on disk. `clean-runs` deletes `ai-factory/runs/*.json`
after 30 days, transcripts are outside the repo and outside git, and nothing is captured for a
teammate or for CI — so it is a local diagnostic, not the fleet-wide budget view the request
asks for. Depends on the same undocumented directory layout as B.
*Later:* the natural front-end for A or B once either lands; does not block them.

### D — Account at the gateway

Stop trying to measure inside the tools. Point every tool at one gateway (`ANTHROPIC_BASE_URL`
is already the documented path in `ai-factory/AGENTS.md`) and read spend per key, per model,
per developer from it.

*Changes:* nothing in this repo except docs; a gateway, keys and an ADR. *Effort:* **L**, mostly
outside this repo. *Risks:* the only option that sees **Cursor** at all — and it still cannot
split by task or agent, because neither Claude Code nor Codex lets a subagent tag its requests
with a header. Cuts against architecture.md's "no provider is assumed". *ADR:* required.

## Options — reporting surface

### What the report must assume about the collection layer

This is the crux, and it decides sequencing rather than design. Every surface below reads
`ai-factory/runs/log.csv`, so every surface inherits its two defects:

- **Rows are cumulative per session, so they cannot be summed.** A report that adds `cost_usd`
  over this repo's own log shows ~$1,240 for ~$159 of work. No surface can detect or repair
  this: the rows are individually well-formed and only the `session_id` repetition hints at it.
  A reader *could* take the max per `session_id` instead of the sum — but that is a guess about
  writer semantics, exactly what `_log-schema.js` refuses to do ("rows are never reinterpreted …
  guessing is what caused the original mixed-schema bug").
- **`task` is blank on every interactive row and there is no `agent` column.** Measured: all 19
  rows in `ai-factory/runs/log.csv` have `task` empty and `accepted` empty. So the two
  aggregations the request actually asks for — per task, per agent — have no data to group by.

**Therefore: no reporting option can usefully ship before the collection fix** (opinion, held
firmly). A report shipped first would answer the headline question with one bucket labelled
blank and a total that is wrong by ~8×, and the first person to quote it in a budget
conversation would be quoting a bug. The one thing worth building early is the *aggregation
engine* (R1), because it is shared by every surface and can be unit-tested against fixture CSVs
before real rows exist.

### What a per-task report can honestly show

Producible from the 16 columns **today**, no collection change: group by `branch`, `user`,
`tool`, `model`, day (`ts`), `session_id`; tokens split four ways (`input_tokens`,
`output_tokens`, `cache_read_tokens`, `cache_write_tokens`) with `hit_rate` and `turns`;
`cost_usd`, with `~`-prefixed values shown as estimates and empty values (every Codex row, by
design) counted as *not priced* rather than as zero.

Needs the collection fix: **per task** (blank interactively), **per agent** (no column), and
**any sum across runs** (cumulative rows). Marked as such in the report until it lands.

Not obtainable from `log.csv` at all, at any effort: per-plan-**step** cost inside `/t4:run`
(`ai-factory/plans/` is not joined to the log); wall-clock (`totalDurationMs` exists in the
transcripts, no column carries it); tool-call counts and lines changed (`toolStats` in
transcripts, `edits.jsonl`/`cmds.jsonl` per session but gitignored); anything about **Cursor**.
`accepted` would give cost-per-accepted-change — the only real ROI number — but it is filled by
hand and is empty in every row measured, so the report must show coverage of that column, not
an average over the filled ones.

Honest v1: rows = task × agent; columns = runs, turns, in / out / cache-read / cache-write,
hit_rate, cost, not-priced count; plus a by-day and a by-branch view; plus an explicit
`unattributed` row rather than silently folding blank-`task` rows into a zero.

### R1 — CLI only: `make cost`, Node with no dependencies

`templates/ai-factory/make/cost.js` in exactly the style of `log.js` and `gate.js` — CommonJS,
built-ins only — reusing the quote-aware `records()`/`width()` readers already in the schema
guard, printing fixed-width tables to stdout. Plus a `cost` target in `ai.mk`.

*Changes:* one new template file, one `ai.mk` target, one section in
`templates/ai-factory/docs/workflow.md`; the file becomes a tracked entry in `.sdlc.json`.
*Effort:* **S** — no dependency, no build, no schema change, nothing breaking.
*Risks:* a task × agent × four-token-columns table is wide for 80 columns, so the default view
has to choose an aggregation; no trend view. *Later:* it is the aggregation engine every other
surface reuses, so the numbers get defined once, in testable code. *Deps/ADR:* none.

### R2 — R1 plus a generated single-file HTML report

`make cost HTML=1` writes one self-contained `ai-factory/runs/report.html` — inline CSS, inline
JSON, hand-rolled inline SVG for any chart, no CDN, no build — and prints the path to open.

*Changes:* R1's file plus a template-literal renderer, a gitignore line
(`ai-factory/runs/*.html`) and one doc line.
*Effort:* **S–M** — M because a readable hand-written HTML/CSS/SVG renderer inside a template
literal is real work, and because a chart library would be a vendored dependency needing an ADR.
*Risks:* a generated artefact in `runs/` must be gitignored or it becomes a merge-conflict
machine — `log.csv` already needs `merge=union` for exactly that reason — and if it is committed
it leaks user, branch and cost data. No live refresh; stale unless regenerated.
*Later:* attachable to an MR and producible in CI, which is what makes the "before/after run
linked in the MR" rule cheap to satisfy for cost claims. *Deps/ADR:* none, provided charts stay
hand-rolled.

### R3 — machine format only: `make cost JSON=1`

A pivoted JSON and TSV on stdout and nothing else; the view is whatever the developer already
has — a spreadsheet, `column -t`, or the workspace's own observability. Genuinely a different
surface rather than a flag on R1: R1 renders a table for a human and is free to change its
layout, R3 is a **contract** other things parse, so it must be versioned and cannot be
reformatted casually. TSV also pipes into `column -t` for a passable table on a machine where
nothing else is installed.

*Changes:* one flag on R1's script plus one doc section naming the shapes as a contract.
*Effort:* **S**. *Risks:* "the report" is then owned by nobody, so two developers see different
numbers and no view can be asked to fix itself; a new adopter gets no default answer; and once
something parses it, changing a field name is a breaking change for a consumer this repo cannot
see. *Later:* the only route to the fleet roll-up EXD-001 puts in scope — a workspace-level
collector can consume it without this repo knowing the collector exists. *Deps/ADR:* none.

### Decided: both audiences (EXD-001)

`EXD-*` is this exploration's own register; `analyses/0001` already uses `DEC-*` up to DEC-014.

| Id | Decision | Source | Affects |
|---|---|---|---|
| EXD-001 | **Both audiences are in scope: a developer at a terminal *and* an owner looking across the fleet.** | the developer, 2026-09-25 | R1 and R3 both in v1; former Q8 closed; former Q7 (per-repo vs fleet) closed as "both"; adds the fleet path below |
| EXD-002 | **`SubagentStop` fires for a `requestShape: background` agent.** Option A is unblocked and B is no longer needed as its fallback. | direct test, 2026-09-25, Claude Code 2.1.274 | closes Q1; removes the gate on option A and on the first spec |

**EXD-002, reproducibly.** An isolated scratch directory with a `--settings` file registering
`SubagentStart`, `SubagentStop` and `Stop` as command hooks that append their stdin JSON to a
file, then:

```
claude -p '<prompt>' --settings <file> --allowed-tools Agent --output-format json
```

What it established, all measured:

1. **The `Agent` tool takes a `run_in_background` boolean**, which the binary strips from the
   exposed schema under some conditions — `n.omit({run_in_background:!0})` behind a two-predicate
   check — so it is absent interactively but present in `-p` print mode. That is how the
   background shape was forced. (Corroborated here independently: `run_in_background` appears 37
   times in the 2.1.274 binary, with that exact `omit({run_in_background:!0})` guard.)
2. **Both events fire, for both shapes.** One run spawned foreground
   (`subagent_stats.requested {foreground:1}`), a second background (`{background:1}`,
   `started_in_background:1`); `SubagentStart` and `SubagentStop` fired in both. **Request shape
   is not a gate.**
3. **The `SubagentStop` payload carries what option A needs**: `hook_event_name`, `session_id`,
   `agent_id`, `agent_type`, `agent_transcript_path`, `transcript_path` (the parent's), `cwd`,
   `prompt_id`, `permission_mode`, `effort`, `stop_hook_active`, `last_assistant_message`.
   **`cwd` is present**, which is what `aiDir()` needs to stay a no-op outside a layout.
   `SubagentStart` carries less — `session_id`, `transcript_path`, `cwd`, `prompt_id`,
   `agent_id`, `agent_type` — and **no `agent_transcript_path`**, so the token read must happen
   at Stop, not Start.
4. **Tokens are readable from `agent_transcript_path`**: per-assistant-message `usage` with
   `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens` —
   the same shape `session-stop.js` already sums. The trivial test agent came to input 2 /
   output 6 / cache-write 46,798 over one message. A per-agent row is therefore computable at
   `SubagentStop` **without reading the parent transcript at all**.
5. **A join-key trap:** the `.meta.json` field `agentId` is **null**, while the filename is
   `agent-<agent_id>.jsonl` / `.meta.json` and the hook's `agent_id` matches the filename. Join
   hook → meta **by filename, never by the `agentId` field**. The meta still carries `toolUseId`,
   `spawnDepth`, `agentType` and `requestShape`, so the task-attribution join through `toolUseId`
   (18/18 above) is intact.
6. **One residual, not a blocker:** the background case was proven in print mode with an explicit
   `run_in_background: true`. An interactive session spawns async by default, and that exact
   combination — interactive *and* background — was not directly exercised. Since both events
   fired for both shapes within the same mode, shape is evidently not the discriminator, so this
   is a residual to confirm in passing during implementation rather than a gate.

So R1 and R3 are not a hedge, they are the two audiences: R1 renders for the developer in the
repo, R3 is the contract the fleet view consumes. **The contract is designed first, and both ship
in one change.** Design order is not a preference — R1's table layout can be rewritten any time,
but the moment a workspace collector parses R3 a renamed field is a breaking change for a
consumer *in another repo* that no fixture here can pin. This repo already paid that bill once:
`log.csv`'s header is duplicated by hand in `_log-schema.js` and `templates/ai-factory/make/log.js`
and held together only by `fixtures/check-log-schema.sh`, because a shape with two writers drifts.
A fleet collector is a third consumer that `check-log-schema.sh` cannot reach. So: fix the
grouping keys and metric names as R3's versioned JSON schema, then make R1 a renderer over the
same structure. Shipping them apart costs more than it saves — R3 is a flag on R1's script.

### The fleet path

**Measured, in this workspace** (the parent workspace directory, confirmed **not** a git repo:
`git rev-parse` returns "fatal: not a git repository"; 29 leaf directories are):

- **Ten `runs/log.csv` files exist, 322 rows total** (re-scanned two levels deeper than my first
  pass, which missed the two grouping directories and reported 8 / 296):

  | rows | log |
  |---:|---|
  | 0 | `ai/runs/` — the workspace root itself, header only |
  | 19 | `ai/sdlc/ai-factory/` |
  | 26 | `infra/ai/` — **`infra/` itself** |
  | 6 | `infra/fleet/ai/` |
  | 93 | `infra/mayhem/ai/` — the largest |
  | 0 | `svc/ai/` — **`svc/` itself**, header only |
  | 16 | `svc/pricesync-svc/ai/` |
  | 77 | `webapp/clients/ai/` |
  | 29 | `webapp/platorm/ai/` |
  | 56 | `webapp/storefront/ai/` |

  **22 of the 29 leaf repos have no layout at all**, and two of the ten logs belong to
  directories that are not repos.
- **Nine of the ten are on the pre-1.0 `ai/` name; only `ai/sdlc` is on `ai-factory/`.** Any
  walker must accept both, which is exactly `LAYOUT_DIRS = ["ai-factory", "ai"]` in
  `skills/ai-hooks/scripts/_common.js`.
- **Layouts nest, and the nesting levels are not git repos.** `infra/` and `svc/` each carry a
  full layout (`agents AGENTS.md designs docs explorations make models.yaml plans runs tasks`,
  plus `.sdlc.json` and their own `Makefile`) *above* adopted children — `infra/mayhem`,
  `infra/fleet`, `svc/pricesync-svc`. Verified: `git rev-parse` in `.`, `infra` and `svc` all
  return "fatal: not a git repository", so three of the ten logs sit in non-repos.
- The root's existing fan-out is `REPOS := $(dir $(wildcard svc/*/package.json core/*/package.json webapp/*/package.json))`,
  looped by `lint:` and `test:` with `infra/` delegated separately via `$(MAKE) -C infra`.
  **Reusing `REPOS` for cost would be wrong**: it keys on `package.json`, so it reaches exactly
  four logs / 178 rows (`webapp/clients`, `webapp/storefront`, `webapp/platorm`,
  `svc/pricesync-svc`) and misses six logs / **144 of the 322 rows** — including `infra/mayhem`'s
  93, the biggest single log, and `ai/sdlc` itself.

**Nested layouts: what the walker does, and why.** A parent log is **a peer row, not a roll-up of
its children.** The reason is in the hook: `aiDir()` in `_common.js` is `path.join(cwd, name)`
with **no upward walk**, so a row is written to the layout in the session's own working directory
and nowhere else. `infra/ai/runs/log.csv` is therefore the log of sessions whose cwd was `infra/`
itself — not a total that already contains `infra/mayhem`'s 93 rows. Likewise `svc/ai/`'s empty
log is *not* a parent of `svc/pricesync-svc`'s 16 rows; it is an adopted-but-empty layout and gets
the "no data" row already decided above, sitting beside its child's row. So **"one row per repo"
is wrong as a unit: the unit is one layout directory**, keyed by the path holding `ai-factory/`
or `ai/` relative to the walk root — because `infra/`, `svc/` and the workspace root are layouts
and are *not* repos. Nested layouts become sibling rows at different depths, and the report must
print the path so the nesting is visible rather than implied.

**The walker must de-duplicate by `session_id` across logs, and this is independent of nesting.**
The cause is simply that **one session changed working directory across layouts** while `aiDir()`
has no upward walk, so its cumulative snapshots landed in whichever layout was under the cwd at
each Stop. Nesting is one way that happens, not the reason — measured, four sessions appear in more
than one log and **only two of the four involve a parent layout at all**:

| session | logs (rows, max `cost_usd`) | relationship |
|---|---|---|
| `38f58217` | `infra/fleet` (1, $9.02) + `infra/mayhem` (2, $10.92) | **siblings** |
| `b1fb3f51` | `webapp/storefront` (1, $4.21) + `webapp/clients` (1, $1.43) | **siblings** |
| `e2c1779f` | `infra/ai` (5, $9.75) + `infra/fleet` (2, $8.38) + `infra/mayhem` (1, $12.40) | parent + 2 children |
| `fbd41837` | `infra/ai` (21, $119.95) + `infra/mayhem` (11, $54.95) | parent + child |

So de-duplication across logs is required whether or not any layouts nest, and **it cannot be
waived by settling the nesting question** — resolving parent-versus-peer fixes neither of the two
sibling cases.

**The error survives the per-log fix, and here is its size.** Taking the maximum snapshot *within*
each log — the de-duplication already recommended for the cumulative defect — and then summing
across logs still over-counts these four sessions by **$83.52**, against correct spend of
**$147.48** for them: a 57% overstatement on the overlapping sessions alone. (Per session, rounded:
$9.02 + $1.43 + $18.13 + $54.95; the unrounded total is $83.5219, so the rounded components sum to
a cent more.) That is the number that justifies keying on `session_id` **across** logs rather than
per log. Recommended: one key per session over the whole walk, take the global maximum snapshot as
that session's spend, attribute it to the log holding that maximum, and list the other layouts it
touched as "also touched" rather than as separate spend. Per-layout attribution of a session that
moved is a **choice, not a fact** — the rows record only where the cwd was when each Stop fired —
and the report should say so instead of implying precision it does not have.

One caveat on all the figures above: these logs are live. `webapp/clients` read 77 rows at the
start of this exploration and 80 by the end, so the ten-log inventory is a snapshot, and a fleet
report is a snapshot too.

**Three traps worth naming.** First, because the root includes the template `ai.mk`, adding a
`cost` target there means the root inherits it *for free* — and it would run with `RUNS :=
ai/runs` and report the root's own log, which has **zero rows**. A developer at the root would
run `make cost`, see nothing, and conclude the feature is broken. Second, a session in one of the
22 unadopted repos writes **nowhere**: because `aiDir()` never walks up, work in
`infra/krakend-gateway` or `infra/templates` is invisible even though `infra/` above them is
adopted — a coverage hole the fleet total must disclose, not quietly absorb. Third, the fleet view
inherits both collection defects once per layout and multiplies them: all **322 rows across ten
logs** are cumulative-per-session with `task` blank, so a roll-up built today would be wrong ten
times over, double-count the sessions above, and attribute nothing.

One smaller consequence: all 26 rows in `infra/ai/runs/log.csv` have an **empty `branch`**, because
`infra/` is not a git repo, so `branch(cwd)` in `_common.js` gets nothing from `git rev-parse` and
writes "". A by-branch view is therefore blank for every non-repo layout, which is three of ten.

**Where the aggregator lives: the workspace owns it; the plugin must not vend it.** This is not
opinion, it is an accepted decision in this repo. `ai-factory/designs/0001-layout-version-and-drift.md`
§6: "ai-sdlc keeps no registry and **never reaches into another repo** — which is precisely what
the standalone rule requires. Option 'central registry', already rejected, is now forbidden";
and "`/t4:fleet` may not enumerate adopted repos from this repo — that is knowledge of other
repos … an adopted repo records its own version, and **whoever wants a fleet-wide view collects
it**." A walker shipped in the template would be the plugin enumerating other repos, i.e. the
forbidden thing wearing a Makefile. So:

- **The plugin ships**, in the template, per repo: R1 (`make cost`) and R3 (`make cost JSON=1`) —
  a versioned, documented export of *this* repo's log and nothing else. That is R3's real job,
  and it is precisely the "once something surfaces `ai/runs/`" that design 0001 leaves open.
- **The workspace owns** the walker and the rendered fleet view, in its own hand-written root
  `Makefile` (which is already hand-written: it defines `REPOS`, `lint`, `test` and is not a
  template copy) plus, if a dashboard is ever wanted, a workspace app — never in this plugin
  (RS-001).

**Discovery: by the artefact, not by adoption metadata** (recommended). The walker looks for a
readable `<repo>/{ai-factory,ai}/runs/log.csv`. `.sdlc.json` is the ADR-0001 adoption marker but
is the wrong key here: `ai/sdlc` has **no** `.sdlc.json` (it is the template, not an adopter, per
`ai-factory/AGENTS.md` "This repo is its own template") and would be silently dropped. Discovery
by the file the report actually consumes degrades correctly in both directions.

**Representation.** Never-adopted repos are **omitted** — 22 of 29 would otherwise be 76% empty
noise. Adopted-but-empty repos are **listed with zero rows and "no data"**, because that
distinction is itself a finding: it means the layout is present and the hooks are not writing,
which is exactly the root's current state. And **yes, `ai/sdlc` appears as one row among the
others** — the plugin repo runs the loop on itself by design ("The layout exists here so plugin
changes run through the loop they prescribe"), so excluding it would hide the factory's own cost
from the only person asking where the budget went.

### Rejected, recorded so it is not re-proposed

Matching the `PROP-*` register convention in `ai-factory/analyses/0001`, where PROP-009 is kept
with status **Rejected** rather than deleted:

| Id | Surface | Status |
|---|---|---|
| RS-001 | A local Next.js app started on demand (`make report`, served on localhost, live drill-down per run and agent) | **Rejected** by the developer, 2026-09-25: too heavy. It would be the plugin's first dependency, first lockfile, first build step and first long-running process, and so needs an ADR that would have to amend `.claude-plugin/plugin.json`'s advertised "Standalone — no dependency on any other repo and no runtime dependency", `ai-factory/AGENTS.md`'s "No application code, no build step" and `architecture.md`'s "Nothing runs as a service". Measured, all three are literally true today: no `package.json`, and only `fs`/`path`/`child_process` in every script. An on-demand `npx` invocation does **not** rescue it — a Next app needs its own `package.json`, so something is installed somewhere on first run, it needs network, and without a lockfile two developers resolve different trees, turning a declared dependency into an undeclared one. The web-page requirement is met by R2 instead: one generated file, opened from disk, no server. **If an interactive dashboard is ever genuinely wanted it belongs in the consuming workspace, not here** — `webapp/storefront` in the parent workspace (`base-shop`) already runs `next ^14.2.23`, and a dashboard inherently wants every repo's `log.csv` at once — see *The fleet path*, and it would consume R3's contract like any other fleet view. Kept for the record. |
| RS-002 | A `/t4:cost` task that has a model read `log.csv` and write a markdown report into `ai-factory/runs/` | **Not recommended** (opinion): no dependency and no code, but a model summing a CSV is non-deterministic and unverifiable, and arithmetic is the one thing a 30-line script does better and cheaper. Kept for the record. |

## Comparison

| Option | Effort | Risk | Reversibility | Fits architecture.md | Recommend |
|---|---|---|---|---|---|
| A — `SubagentStop` hook, row per agent | M | Low–Med — breaking schema change only; the firing risk is closed by EXD-002 | High — revert the header, rows move to `log.previous.csv` as designed | Yes — writes only to `ai-factory/runs/`, silent, prices from `models.yaml` | **Yes** |
| B — reconcile from `subagents/` at Stop | M | High — undocumented path, silent failure, re-reads MBs every turn | High, same as A | Yes, but the per-turn cost cuts against "no hook that slows every tool call" | ~~Fallback~~ — no longer needed (EXD-002) |
| C — `make cost` reader | S | Low — nothing breaks | Total — delete the file | Yes | Only as a companion |
| D — gateway accounting | L | Med — org change, no task/agent split | Low once adopted | No — assumes a provider | No |

Reporting surface:

| Option | Effort | Risk | Reversibility | Fits architecture.md / "standalone" | Recommend |
|---|---|---|---|---|---|
| R1 — `make cost`, CLI, no deps | S | Low | Total — delete one file | Yes — same shape as `log.js`/`gate.js` | **Yes, v1 (developer audience)** |
| R3 — machine format (`JSON=1`, TSV) | S | Low–Med — becomes a contract a repo outside this one parses, and no fixture here can pin it | Total, until something parses it | Yes | **Yes, v1 (fleet audience); shape designed first** |
| R2 — R1 + single-file HTML | S–M | Low–Med — generated artefact must be gitignored or it leaks and conflicts | Total | Yes, if charts stay hand-rolled SVG | Yes, v2 |
| F — fleet walker over every layout's R3 | S–M | Med — layouts nest and `REPOS` as written misses 144 of 322 rows; needs `session_id` de-duplication across logs | Total | **Not in this plugin** — enumerating other repos is forbidden by designs/0001 §6 | Yes, but **workspace-owned** |
| ~~RS-001 — local Next.js app~~ | L | — | — | **No** — contradicts plugin.json, AGENTS.md and architecture.md | **Rejected** (see above) |

## Recommendation

**Collection: A, unchanged.** The reporting requirement strengthens it rather than altering it —
every surface below needs the `agent` column and non-cumulative rows, and none of them can
synthesise either. A is the only option using a seam the tool documents, handing over exactly
`agent_id`, `agent_type` and `agent_transcript_path`, with no path guessing and one firing per
agent; the schema ripple lands on machinery (`_log-schema.js`, `check-log-schema.sh`,
`log.previous.csv`) already built to absorb it, and it closes FR-020 / Q-006 / PROP-013.

**A now carries no unresolved gate.** EXD-002 tested the one thing that could have sunk it: both
subagent events fire for both request shapes, and `SubagentStop` hands over `agent_type`,
`agent_transcript_path` and `cwd` — so the per-agent row is computed from the agent's own
transcript, the hook stays a no-op outside a layout, and B's undocumented-path and
re-read-every-turn risks are simply not incurred. B is retained in this doc as the record of a
considered alternative, not as a live fallback.

*What would change my mind now:* only the residual in EXD-002 item 6 — if an interactive
background spawn turned out not to fire `SubagentStop` after all, despite shape not being the
discriminator in the tested mode. Worth one confirmation during implementation; not a reason to
hold the spec.

**Reporting: R1 and R3 together in v1, R2 next — because EXD-001 says both audiences.** That is
now a consequence, not a hedge: R1 is the developer's view inside the repo, R3 is the export the
owner's fleet view consumes. **R3's schema is designed first**, even though both ship in the same
change, because R1's table can be relaid out whenever and R3 cannot once a collector in another
repo parses it — and `check-log-schema.sh`, the mechanism this repo uses to stop a shared shape
drifting, only reaches writers inside this repo. R1 then renders from that structure, so "spend
per task" is defined once. R2 satisfies the web-page requirement as a single generated file opened
from disk — no server, no dependency, no ADR (RS-001).

**The fleet aggregator is workspace-owned, not plugin-vended.** `designs/0001` §6 forbids this
plugin from enumerating other repos; the walker therefore belongs in the workspace root's own
hand-written `Makefile`, discovering **layout directories** — not repos — by the presence of a
readable `{ai-factory,ai}/runs/log.csv`, treating a parent layout as a peer row rather than a
roll-up, de-duplicating sessions by `session_id` across logs, omitting the 22 never-adopted
repos, listing adopted-but-empty layouts as "no data", and including `ai/sdlc` as one row. What
the plugin owes it is exactly R3: a versioned per-layout export. Note the trap — a `cost` target in the template `ai.mk` is inherited
by the root through `include ai/make/ai.mk` and would report the root's own **zero-row** log, so
the root target must be a different, walking target, not the inherited one.

**Sequencing: reporting ships after the collection fix, not before.** Over today's `log.csv` a
report would total ~$1,240 for ~$159 of work and bucket every interactive run under a blank
task — and the fleet view multiplies that across all 322 rows in ten logs, two of which already
hold cumulative snapshots of the same sessions as their children. The only part worth
building early is R3's schema plus R1's aggregation against fixture CSVs.

*What would change my mind on the surface:* a group-level CI runner and token in the GitLab group —
the same condition design 0001 names as what would make its rejected push option cheap — would
turn the fleet half from pull into push, and the walker would become a CI job publishing one
artefact rather than a target a developer runs.

## Open questions

1. ~~**Does `SubagentStop` fire for a background/async agent?**~~ — **resolved by EXD-002**
   (tested 2026-09-25, Claude Code 2.1.274): yes, for both request shapes. Nothing blocks option
   A or the first spec. One residual to confirm in passing: the interactive + background
   combination, per EXD-002 item 6.
2. **One row per agent, or one row per task with the agents rolled up?** Per agent is finer and
   sums to the task; per task keeps `log.csv` small. The `accepted` column is per commit, which
   suits neither cleanly.
3. **Deltas or cumulative?** Fixing (3) changes what every existing row in every adopted repo
   means. Cleanest is a new `source` value and a header change so old rows are migrated out
   rather than silently reinterpreted — consistent with the guard's existing "never reinterpret"
   rule. Owner's call.
4. **Does `agent` become a 17th column, or does `tool` carry `claude/explorer`?** Q-006 in
   `ai-factory/analyses/0001` is still open and proposed "keep as is".
5. **Codex parity.** Per-agent is impossible there by construction. Is filling `task` for Codex
   and stating "agent = the session" acceptable, or must the report be able to say a number is
   not comparable across tools?
6. **Cursor.** Accept "not measured" in the docs, or is closing that gap a requirement — in
   which case only D does it?
7. ~~**Per-repo CSV or a fleet roll-up?**~~ — **closed by EXD-001**: both (see *The fleet path*).
   Residual, not blocking: does the walker discover repos by a readable `runs/log.csv` (what is
   recommended here) or from an explicit list in the workspace's own `ai/docs/fleet.md`? The
   second is legitimate for a workspace reading its own map — the prohibition in `designs/0001`
   §6 binds *this plugin*, not the workspace — but it goes stale the moment a repo adopts.
8. ~~**Who reads the report?**~~ — **closed by EXD-001**: both. So is the former Q7 (per-repo or
   fleet): both, with the split settled in *The fleet path*.
9. **Is `accepted` going to be filled?** Cost-per-accepted-change is the only real ROI number
   the report could produce, and the column is filled by hand — empty in all 19 rows measured.
   If it stays empty the report should show its coverage rather than average over the few
   filled rows. Related: `accepted` is per commit, while rows would now be per agent.
10. **Is the HTML report gitignored or committed?** Gitignored keeps `runs/` clean and avoids
    leaking user, branch and cost data; committed makes it attachable to an MR without a
    rebuild. `ai-factory/runs/log.csv` is the one tracked file in there today, and it needed
    `merge=union` to survive two branches.
11. **Who writes the workspace walker, and does it wait for EPIC-004?** The fleet target is the
    workspace's work, not this repo's, but the workspace root is also the subject of EPIC-004
    (workspace-root mode), which `analyses/0001` marks "needs the extending ADR and `/t4:design`
    first". Building the walker now in the root `Makefile` is small and independent; building it
    *as part of* root mode is not. Not blocking either spec below.
12. **Does the fleet export carry money or only tokens?** Nine of the ten logs are in layouts that
    may run different models, and `cost_usd` is already `~`-marked or empty per row. Summing
    across layouts means summing prices set in ten separate `models.yaml` files.

## Next

Three specs, in this order — the second is worthless before the first, and the third consumes
the second's export.

```
/t4:spec per-agent and per-task token accounting in ai-factory/runs/log.csv: a SubagentStop hook writes one row per agent with agent_type, tokens and cost; a UserPromptSubmit hook fills the task column for interactive sessions; session rows become deltas — closes ai-factory/analyses/0001 FR-020, Q-006, PROP-013
```

```
/t4:spec a make cost target that reports spend by task, agent, branch and day from ai-factory/runs/log.csv — a dependency-free Node script in the shape of make/log.js, whose versioned JSON/TSV export (the fleet contract) is specified before the rendered table it also prints, plus an optional single-file HTML report written to ai-factory/runs/ and opened from disk; no server, no walker (RS-001 rejected, EXD-001)
```

Third, and **not in this repo** — the fleet walker is the workspace's, per `designs/0001` §6. Run
this one from the parent workspace directory (which has its own adopted layout at `ai/` and its own
`specs/`), after the export above exists:

```
/t4:spec a root-level make cost that walks every LAYOUT directory carrying {ai-factory,ai}/runs/log.csv — not every repo: infra/, svc/ and the root are layouts and are not git repos, and layouts nest above adopted children. Discovery by that file rather than by .sdlc.json or REPOS; a parent layout is a peer row, never a roll-up of its children; sessions de-duplicated by session_id across logs, attributed to the log holding the maximum snapshot with the other layouts listed as also-touched; never-adopted repos omitted; adopted-but-empty listed as no data; ai/sdlc included as one row; the coverage hole for unadopted repos disclosed in the output
```

**Nothing now blocks the first spec** — EXD-002 closed the one gate, so it is written against
option A. The second needs only the first to land; the third needs only the second's export to
be published.
