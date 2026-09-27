# 0007 — A SubagentStop hook: per-agent token accounting, and the task that groups it

Summary: the run log gains the two dimensions it is missing — **which agent** spent the tokens
and **which t4 task** it spent them under — by writing a row at the moment a subagent concludes,
from the agent's own transcript, and by recording the task the session is running so both the
session row and the agent rows can be grouped by it. The cumulative-per-session defect is fixed
in the same change, because a dimension you cannot sum is not a dimension.

This is the **collection layer only**. It is the first of the three specs
`ai-factory/explorations/0001-token-consumption-by-task-and-agent.md` lists under *Next*, built
on its chosen **option A**. The reporting surfaces (`make cost`, the JSON/TSV export, the HTML
report) and the workspace fleet walker are the second and third specs and are out of scope here.

What the exploration settles and this spec does not reopen:

- **EXD-002** — `SubagentStop` fires for both request shapes, and its payload carries
  `session_id`, `agent_id`, `agent_type`, `agent_transcript_path`, `transcript_path` (the
  parent's), `cwd` and `stop_hook_active`. The per-agent row is therefore computable from the
  agent's own transcript, with the parent's never read. `SubagentStart` carries no
  `agent_transcript_path`, so nothing is registered on it.
- **EXD-001** — both audiences are in scope, which is why the collection layer must be right
  before any surface reads it, and why it ships first.
- **RS-001 and RS-002** are rejected; **options B, C and D** were considered and not chosen.
- Adding a column to `log.csv` is **breaking**: existing rows move to `log.previous.csv` on the
  next write, and the change ripples across `skills/ai-hooks/scripts/_log-schema.js`, the
  hand-copied header in `skills/ai-layout/templates/ai-factory/make/log.js`,
  `skills/ai-hooks/fixtures/check-log-schema.sh`, both `SKILL.md` files and
  `ai-factory/docs/workflow.md` §9. `ai-factory/AGENTS.md` requires that be stated in the MR and
  the CHANGELOG.

## Decided
**2026-09-26**: SD-001…SD-003 decided by the developer, SD-004 established by measurement. These
were Open questions 1–3 — the three that blocked the plan — and question 11. Recorded here, and
not reopened below.

| Id | Decision | Affects |
|---|---|---|
| SD-001 | **The agent name is a 17th column, `agent`.** Not encoded inside `tool` as `claude/explorer`: that overloads a field the reader already parses and forces every consumer to split it. | AC3, AC17. Closes exploration Q4 and answers `ai-factory/analyses/0001` Q-006, whose "keep as is" was only a proposal |
| SD-002 | **The `log.csv` header break is accepted.** The header does change, so every adopted repo's existing rows rotate into `log.previous.csv` on the next write; the MR and the CHANGELOG say so, as `ai-factory/AGENTS.md` requires. | AC17, now firm rather than conditional; AC15 |
| SD-003 | **Deltas at write.** Each new row records the increment since that session's previous row, not a re-sum of the whole transcript. **No migration script and no reinterpretation of the existing cumulative rows**: SD-002's header change already quarantines every one of them in `log.previous.csv`, which is exactly where rows written under the old semantics belong. That quarantine is a consequence of the break, not separate work — and it is not licence to read those rows later as if they were deltas. | AC14, AC15, AC16 |
| SD-004 | **Usage records are duplicated across agent transcripts, and the remedy is de-duplication by message `uuid` — not a depth rule.** A usage record belongs to exactly one agent, the one whose own turn produced it, and is counted once however many transcripts carry a copy. Measured 2026-09-26, session `1453ad4c-3ce5-43a9-b9fc-263c94b45c7b` in `-Users-tanin-code-nsix-svc`: a parent agent of 711 records / 317 with `usage` / 59,172,796 tokens, and four `spawnDepth: 2` `fork` children of 4.8M, 4.7M, 30.4M and 8.2M tokens (48,151,365 total), each re-logging 54 of the parent's records — 20 of them with `usage`, the same UUIDs and the same 1,944,712 tokens in all four, at positions 11–50, an inherited prefix rather than the child's own work. Naively summed, those tokens are counted five times: 7,778,848 of pure over-count in one session. The cause is context inheritance and it is `fork`-shaped; the plain subagents this feature is mostly about (the t4 step agents) are not forks and were **not** observed to share UUIDs — one tested directly carried only its own work. So the duplication is proven for forks and unobserved for non-forks, and the `uuid` rule is correct for both, which is why it is unconditional rather than conditional on agent type. | AC2, AC16, AC19. Was Open question 11 |

Seven open questions remain and are listed below. They keep their original numbers 4–10, so a
reference to one of them still lands; none of them blocks the plan.

## User story
As the owner of a repo that runs the t4 loop, I want every run recorded with the agent that did
the work and the task it was doing, in rows that can be added up, so that I can say where the
money went — `/t4:run`'s implementers, `/t4:explore`'s explorer, the reviewer — instead of only
that the repo spent some, and so that the report specs that follow have something true to read.

## Acceptance criteria

### The hook and the per-agent row

- **AC1** Given the release, When `hooks/hooks.json` is read, Then it registers `SubagentStop`,
  backed by a new `skills/ai-hooks/scripts/subagent-stop.js`; and When that script is run with
  any payload whose `cwd` holds neither `ai-factory/` nor `ai/`, Then it exits 0, writes no file
  and prints nothing to stdout or stderr.
- **AC2** Given a `SubagentStop` payload carrying `session_id`, `agent_id`, `agent_type` and an
  `agent_transcript_path` whose transcript holds assistant messages with `usage`, When the hook
  runs in a repo with the layout, Then exactly one row is appended to
  `ai-factory/runs/log.pending.csv` — never straight to `log.csv` — with `source` = `agent`,
  `session_id` from the payload, `turns`, `input_tokens`, `output_tokens`,
  `cache_read_tokens`, `cache_write_tokens` and `hit_rate` summed from **that transcript only**
  and subject to AC16's `uuid` rule, `model` the model that transcript names, and `user` and
  `branch` derived from `cwd` exactly as `session-stop.js` derives them.
- **AC3** Given that row, When it is read back, Then the payload's `agent_type` is in the new
  `agent` column verbatim — `implementer`, `specifier`, `reviewer` and so on — and `tool` still
  carries `claude` alone, unsplit and unqualified (SD-001). A `session` row leaves `agent` empty;
  so does a `make` row.
- **AC4** Given the agent's model is priced in `ai-factory/models.yaml`, When the row is written,
  Then `cost_usd` is computed by the same resolution `session-stop.js` uses — exact id, then
  longest matching prefix, then `default` — and carries no `~`; and given no match, Then the
  built-in figures are used and the value is prefixed `~`, as today. No new pricing code.
- **AC5** Given a payload whose `agent_transcript_path` is readable and whose parent
  `transcript_path` is absent or unreadable, When the hook runs, Then the row is still written in
  full: the parent transcript is not read for any field.
- **AC6** Given two `SubagentStop` events for the same `agent_id`, the second carrying
  `stop_hook_active: true` — a resumed agent — When both are processed, Then `log.pending.csv`
  holds one row for that `agent_id`, not two, and that agent's tokens are counted once.
- **AC7** Given a payload with no `agent_transcript_path`, or one pointing at a missing or
  unparseable file, or at a transcript with no `usage` on any message, When the hook runs, Then
  no row is written, the exit status is 0, and nothing is printed.
- **AC8** Given agent rows buffered in `log.pending.csv`, When the session runs `git commit` (or
  the developer runs `make log-flush`), Then `log-flush.js` moves them into
  `ai-factory/runs/log.csv` and stages it, exactly once, alongside the session rows —
  `fixtures/check-log-schema.sh`'s flush assertions hold for a pending file containing both
  kinds of row.

### Task attribution

- **AC9** Given the release, When `hooks/hooks.json` is read, Then it registers
  `UserPromptSubmit` backed by a new script in `skills/ai-hooks/scripts/`; and When a prompt that
  carries a `/t4:<name>` command is submitted in a repo with the layout, Then the task name is
  written to a session-scoped file under `ai-factory/runs/` keyed by `session_id`, **nothing is
  printed to stdout** — a print from this event enters the model's context and breaks the cached
  prefix — and the script no-ops in a repo without the layout.
- **AC10** Given that file holds `spec`, When a `SubagentStop` row and a `Stop` row are written
  for that session, Then both carry `spec` in the `task` column; and given no such file exists
  for the session, Then both leave `task` empty. A task is never inferred from the branch name,
  the agent type or the prompt text.
- **AC11** Given an interactive session that ran `/t4:plan`, When its session row reaches
  `log.csv`, Then `task` is `plan` — the column that `session-stop.js` writes empty today is
  filled for interactive sessions, not only for `make ai TASK=`.
- **AC12** Given a `specifier` spawned under `/t4:run` — the crossing measured in the
  exploration, 1 of 18 — When its row is written, Then `task` is `run` and the agent name is
  `specifier`: attribution follows the task the session is running, never a static
  agent→task map.
- **AC13** Given the release, When `skills/ai-hooks/SKILL.md`'s prescribed gitignore lines, the
  template's gitignore prescription and this repo's own `.gitignore` are read, Then each covers
  the task file; and When a session runs a `/t4:` command, Then `git status` afterwards does not
  show it.

### Rows that can be summed

- **AC14** Given a session whose `Stop` hook fires N times, When the rows carrying that
  `session_id` in `log.csv` are summed over `cost_usd`, `turns` and the four token columns, Then
  the totals equal the session's actual consumption, because each row carries **the increment
  since that session's previous row** rather than a re-sum of the whole transcript (SD-003). Today
  19 rows of one session sum to ~$1,240 for ~$159 of work; after this change the sum is the spend.
  And given the first row of a session, Then its increment is the whole transcript so far, so
  nothing is lost at the start.
- **AC15** Given a `log.csv` holding rows written by the previous version, whose numbers are
  cumulative snapshots, When the new writer next runs, Then the header no longer matches and the
  existing guard in `_log-schema.js` appends every one of those rows to
  `ai-factory/runs/log.previous.csv` and starts a fresh `log.csv` — no migration script is written
  and no old row is reinterpreted as a delta, then or later (SD-002, SD-003). The quarantine is
  the consequence of the header break, not separate work; `log.previous.csv` is where rows written
  under the old semantics belong, and moving them there is not permission to read them as if they
  were deltas.
- **AC16** Given a set of agent transcripts in which the same message `uuid` appears in more than
  one of them, When their rows are written, Then that record's tokens are counted **once**, for
  the agent whose own turn produced it, and every other transcript carrying a copy of it excludes
  it: de-duplication is by message `uuid`, unconditionally, for every agent type. Measured on
  session `1453ad4c-3ce5-43a9-b9fc-263c94b45c7b` in `-Users-tanin-code-nsix-svc`: four
  `spawnDepth: 2` `fork` agents under one parent each re-log 54 of the parent's records, 20 of
  them carrying `usage`, the same UUIDs and the same 1,944,712 tokens in all four — so a naive
  per-transcript sum counts those tokens five times and over-counts that one session by
  7,778,848 tokens. A depth rule cannot fix it, because the duplicates are an inherited prefix at
  positions 11–50 of each child file and depth says nothing about who spent them (SD-004).
  And given one session's session rows and agent rows summed together, Then no token is counted
  twice across the two kinds of row either: an agent's tokens are in its own row, and the rows say
  which is which.

### The ripple, the docs and the guards

- **AC17** Given the release — which **does** change the header, by adding `agent` (SD-001,
  SD-002) — When it is inspected, Then `skills/ai-hooks/scripts/_log-schema.js`'s `HEADER` and the
  hand-copied `HEADER` in `skills/ai-layout/templates/ai-factory/make/log.js` are byte-identical
  and both carry seventeen columns,
  `bash skills/ai-hooks/fixtures/check-log-schema.sh` passes, the column list quoted verbatim in
  `skills/ai-hooks/SKILL.md`, the count stated in `skills/ai-layout/SKILL.md` and the description
  in `ai-factory/docs/workflow.md` §9 all match it, and the CHANGELOG entry and the MR mark the
  change **breaking for every adopted repo**, state that existing rows move to `log.previous.csv`
  on the next write, and tell the developer what that means for a log they have been keeping —
  the statement `ai-factory/AGENTS.md` requires of a template change.
- **AC18** Given the release, When `skills/ai-hooks/SKILL.md` and `ai-factory/docs/workflow.md`
  §9 are read, Then neither still says that tokens spent inside a subagent are absent from the
  log: both describe the agent rows, what `source=agent` means, and which dimensions can now be
  grouped — closing `ai-factory/analyses/0001` FR-020 and PROP-013, whose current requirement is
  that the under-count be *documented*.
- **AC19** Given the release, When the hook fixtures are run, Then a fixture pins
  `subagent-stop.js` against a captured `SubagentStop` payload and a fixture agent transcript —
  in the shape of `skills/ai-hooks/fixtures/transcript.jsonl` — asserting AC2, AC4, AC5, AC6 and
  AC7; a fixture pair of a parent and a child transcript sharing UUIDs pins AC16's `uuid`
  de-duplication, with the shared records counted once; a fixture pins AC14's delta across two
  consecutive `Stop` events for one session; `skills/ai-hooks/fixtures/check-detect.sh` covers the
  two new scripts across its four layout-detection cases (new name only, old name only, both,
  neither); and `check-log-schema.sh` covers the seventeen-column header and a pending file mixing
  `session` and `agent` rows (AC8, AC17).
- **AC20** Given the release, When the two new scripts are read, Then each requires only `fs`,
  `path`, `child_process` and its siblings under `skills/ai-hooks/scripts/` — no package.json, no
  lockfile, no build step — so `ai-factory/AGENTS.md`'s "no new dependency without an ADR" rule is
  satisfied without one, and `architecture.md`'s "nothing runs as a service" still holds.
- **AC21** Given a repo that has taken this update and still holds `ai/` rather than
  `ai-factory/`, When a subagent concludes and when a `/t4:` prompt is submitted, Then both new
  scripts behave exactly as they do in a migrated repo, writing under `ai/runs/` — the 1.0.0 hook
  fallback in `_common.js` `aiDir()` covers the new events too, and `hooks/hooks.json`'s
  description still describes every registered event.

## Out of scope
- **The reporting surfaces.** `make cost` (R1), the versioned JSON/TSV export (R3) and the
  single-file HTML report (R2) are the exploration's second spec. Nothing here prints, renders,
  aggregates or totals anything: this spec's output is rows in a CSV.
- **The workspace fleet walker.** The third spec, and explicitly not this plugin's to ship —
  `ai-factory/designs/0001-layout-version-and-drift.md` §6 forbids this repo from enumerating
  other repos. Session de-duplication *across* logs, nested layouts and the coverage hole for the
  22 unadopted repos all belong there.
- **Options B, C and D**: reconciling from Claude Code's `subagents/` directory at Stop,
  a read-only `make cost` reconciler over the transcripts, and gateway-level accounting.
  Considered and not chosen; B is retained in the exploration as a record, not a fallback.
- **RS-001** (a local Next.js app) and **RS-002** (a `/t4:cost` task that has a model sum the CSV)
  — rejected in the exploration, kept there so they are not re-proposed.
- **Per-agent attribution for Codex.** Impossible by construction: `sync-adapters.sh` tells Codex
  to read `ai-factory/agents/<x>.md` and follow it in the same session, so one session is the task
  and the agent. Codex keeps writing `source=make` rows as it does today.
- **Cursor.** No local export exists; nothing this spec builds can see it.
- **`SubagentStart`.** It carries no `agent_transcript_path`, so there is nothing to read at
  start. No event is registered on it.
- **The pricing logic and `ai-factory/models.yaml`'s shape.** Reused verbatim (AC4); not changed,
  not extended, not moved into a shared module unless the plan finds that cheaper than the
  duplication it already accepts.
- **Filling `accepted`.** It stays a hand-filled column at commit time.
- **Anything `log.csv` cannot carry**: per-plan-step cost inside `/t4:run`, wall-clock duration,
  tool-call counts and lines changed. The exploration establishes that none is obtainable from
  this file at any effort.
- **Rewriting history, and any migration script.** No adopted repo's existing rows are converted
  into the new meaning: the header break moves them to `log.previous.csv` and nothing reinterprets
  them there (SD-003, AC15).

## Open questions
The three that blocked the plan, and question 11, are answered under **Decided**
(SD-001…SD-004). These seven remain, for the developer, at their original numbers.

4. **One row per agent, or one row per task with the agents rolled up?** Option A implies per
   agent and AC2 is written that way, but exploration Q2 is still recorded as open: per agent is
   finer and sums to the task; per task keeps `log.csv` small. Confirm.
5. **What does `accepted` mean on a per-agent row?** It is per commit, which suits neither
   granularity, and it is empty in all 19 rows measured (exploration Q9). If it stays empty,
   cost-per-accepted-change — the only real ROI number — never arrives, and the later report must
   show the column's coverage rather than average over it.
6. **Codex parity.** Is "task filled, agent = the session" acceptable, or must the log be able to
   say that a number is not comparable across tools (exploration Q5)?
7. **Cursor.** Accept "not measured" in the docs, or is closing that gap a requirement — in which
   case only the rejected option D does it (exploration Q6)?
8. **The one residual in EXD-002.** The background case was proven in print mode with an explicit
   `run_in_background: true`; interactive *and* background was not directly exercised. Shape was
   not the discriminator in the tested mode, so the exploration calls this a residual to confirm
   in passing rather than a gate. Confirm it during implementation, and say so in the MR.
9. **When is the task file removed, and what happens between tasks?** Unstated by the request. A
   session that runs `/t4:plan`, then types a plain prompt, then runs `/t4:run` — does the file
   keep the last `/t4:` name, or clear on a non-command prompt? A background agent still running
   from the previous task would be attributed to the new one under last-writer-wins.
10. **What fills `task` for a session that never typed a `/t4:` command at all?** AC10 says empty;
    confirm that an empty value is wanted rather than a named bucket, given the later report has
    to show an `unattributed` row either way.

## Data touched
No models, no schema, no database — this repo is markdown prompts and Node hook scripts. What
changes is files under `ai-factory/runs/`:
- `log.csv` and `log.pending.csv` — a **seventeenth column, `agent`** (SD-001), a new `source`
  value `agent`, one row per concluded subagent, the `task` column filled for interactive sessions,
  and session rows carrying deltas rather than cumulative snapshots (SD-003).
- `log.previous.csv` — receives every existing row, because the header changes (SD-002, AC15).
- A new session-scoped task file under `ai-factory/runs/`, gitignored (AC9, AC13).
- Unchanged: `sessions.jsonl`, `edits.jsonl`, `cmds.jsonl`, `ai-factory/runs/*.json`, and
  `models.yaml`'s keys and pricing block.

## Routes touched
None — nothing serves a request. The surfaces are hook events in `hooks/hooks.json`:
`SubagentStop` added, `UserPromptSubmit` added, `Stop` changed (AC10, AC11, AC14). `SessionStart`,
the two `PreToolUse` and the two `PostToolUse` entries are untouched. No `/t4:` command is added,
removed or changed.

## Components likely involved
- `hooks/hooks.json` — the two new registrations and the description (AC1, AC9, AC21).
- `skills/ai-hooks/scripts/subagent-stop.js` — new; the whole of AC2–AC7, and the `uuid`
  de-duplication of AC16, which needs the UUIDs already attributed to another agent or to the
  session kept somewhere it can read. Reuses `session-stop.js`'s transcript sum and pricing block.
- `skills/ai-hooks/scripts/<user-prompt-submit>.js` — new; AC9 alone. Must stay silent.
- `skills/ai-hooks/scripts/session-stop.js` — the `task` column (AC11), the empty `agent` column
  (AC3) and the delta at write (AC14, SD-003), which needs the session's previous totals kept
  somewhere the next `Stop` can read.
- `skills/ai-hooks/scripts/log-flush.js` — AC8 only; the cumulative fix happens at write, not here.
- `skills/ai-hooks/scripts/_log-schema.js` — `HEADER` and `COLS` gain the seventeenth column, and
  the shared guard is what quarantines every existing row; one half of AC17, and the whole of
  AC15.
- `skills/ai-layout/templates/ai-factory/make/log.js` — the hand-copied header and guard; the
  other half of AC17. It cannot `require` the plugin's copy, which is why the fixture exists.
- `skills/ai-hooks/scripts/_common.js` — `aiDir()`, which gives the new scripts the layout
  detection and the `ai/` fallback for free (AC1, AC21).
- `skills/ai-hooks/fixtures/` — `check-log-schema.sh`, `check-detect.sh`, a new agent-transcript
  fixture and a captured `SubagentStop` payload beside `stop.json` (AC19).
- `skills/ai-hooks/SKILL.md` — the event table, the under-count paragraph, the column list and
  the gitignore lines (AC13, AC17, AC18).
- `skills/ai-layout/SKILL.md` — the one line stating the column count (AC17).
- `ai-factory/docs/workflow.md` §9 — what the hooks record (AC17, AC18). This repo's file is the
  only copy: `skills/ai-layout/templates/ai-factory/docs/` ships no `workflow.md`.
- `.gitignore` and the template's prescription — the task file (AC13).
- `CHANGELOG.md` — the breaking note, if the header moves (AC17).
