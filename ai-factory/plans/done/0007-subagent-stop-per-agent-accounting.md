# Plan 0007 — A SubagentStop hook: per-agent token accounting, and the task that groups it

**Goal.** Give `ai-factory/runs/log.csv` a seventeenth column, `agent`, a `source=agent` row written
from each concluded subagent's own transcript, a `task` column filled for interactive sessions, and
rows that are increments rather than cumulative snapshots — so the log can be summed by agent and
by task.

**Spec:** `ai-factory/specs/0007-subagent-stop-per-agent-accounting.md`
(decided: SD-001…SD-004; open questions 4–10 remain and are answered against below).

**Server vs client components.** Not applicable: this repo is a Claude Code plugin of markdown
prompts, Node hook scripts and bash fixtures. Nothing runs as a service and nothing renders
(`ai-factory/docs/architecture.md`, "Nothing runs as a service"). The equivalent split here is
*plugin-side* (`skills/ai-hooks/scripts/`, loaded from the installed plugin, may `require` its
siblings) versus *template-side* (`skills/ai-layout/templates/`, copied into an adopted repo,
cannot `require` anything from the plugin) — which is why `log.js` hand-copies the header guard and
why the two copies need a fixture to stay byte-identical.

---

## Files to create / modify

### Create

| Path | Why |
|---|---|
| `skills/ai-hooks/scripts/_usage.js` | The transcript sum, the `uuid` claim ledger and the `models.yaml` pricing block, extracted once so `session-stop.js` and `subagent-stop.js` share them. The spec's *Out of scope* permits this — "not moved into a shared module unless the plan finds that cheaper than the duplication it already accepts" — and it is: AC4 says "no new pricing code", and AC16's ledger has to be written by both scripts or the de-duplication does not span them. AC20 blesses a sibling explicitly. |
| `skills/ai-hooks/scripts/subagent-stop.js` | AC1–AC7 and AC16's agent half. |
| `skills/ai-hooks/scripts/log-task.js` | AC9. Named for what it does, like its siblings `log-edit.js` / `log-cmd.js` / `log-flush.js`, not for its event. |
| `skills/ai-hooks/fixtures/subagent-stop.json` | A captured `SubagentStop` payload beside `stop.json` (AC19). |
| `skills/ai-hooks/fixtures/agent-transcript.jsonl` | An agent transcript with `uuid` on every record (AC19). |
| `skills/ai-hooks/fixtures/agent-child-transcript.jsonl` | A fork child re-logging an inherited prefix of the above — same UUIDs, same tokens (AC16, AC19). |
| `skills/ai-hooks/fixtures/transcript-uuid.jsonl` | A session transcript carrying `uuid`, so the delta across two Stops can be pinned (AC14, AC19). The existing `transcript.jsonl` deliberately stays `uuid`-less — see Risk R5. |
| `skills/ai-hooks/fixtures/check-usage.sh` | The fixture for `_usage.js`'s three exports. Added in Step 2, which this table originally missed: none of the three is reachable from a hook until Step 3, so without it the de-dup path ships as dead, untested code and `coding-standards.md`'s "cover behaviour with a fixture" is unmet. Builds its inputs in a scratch dir, so it ships no fixture file and does not pre-empt `transcript-uuid.jsonl`. |
| `skills/ai-hooks/fixtures/check-subagent-stop.sh` | The AC19 fixture script. The definition of done already runs every `check-*.sh` under `fixtures/`, so a new one is picked up with no wiring. |

### Modify

| Path | Why |
|---|---|
| `skills/ai-hooks/scripts/_log-schema.js` | `HEADER` gains `agent`; `COLS` follows from it. The existing guard is what quarantines every old row — AC15 needs no new code (AC17). |
| `skills/ai-layout/templates/ai-factory/make/log.js` | The hand-copied `HEADER` must stay byte-identical, and the headless row gains an empty `agent` field in the same position (AC3, AC17). |
| `skills/ai-hooks/scripts/session-stop.js` | Empty `agent`, filled `task`, delta at write, and the move onto `_usage.js` (AC3, AC10, AC11, AC14). |
| `skills/ai-hooks/scripts/log-flush.js` | Read only. AC8 is satisfied by the existing code — pending rows are moved whatever their `source` — so this file changes only if the fixture proves otherwise. |
| `hooks/hooks.json` | The two new registrations and the description (AC1, AC9, AC21). |
| `skills/ai-hooks/fixtures/check-log-schema.sh` | Seventeen columns; the two hand-written literal rows in its tests 5 and 6 gain a field; a pending file mixing `session` and `agent` rows; the AC14 delta (AC8, AC14, AC17, AC19). |
| `skills/ai-hooks/fixtures/check-detect.sh` | Its four layout cases extended to `subagent-stop.js` and `log-task.js` (AC19, AC21). |
| `skills/ai-layout/scripts/check-entrypoints.sh` | Its `IGNORE` array gains the two state-file lines, which is what mechanically ties SKILL.md's prescription to this repo's `.gitignore` (AC13). |
| `skills/ai-hooks/SKILL.md` | Event table, column list, the under-count paragraph, the `uuid` rule and the gitignore section (AC13, AC17, AC18). |
| `skills/ai-layout/SKILL.md` | Line 41, "the same 16 columns" (AC17). |
| `ai-factory/docs/workflow.md` §9 | What the hooks record; this repo holds the only copy — `templates/ai-factory/docs/` ships no `workflow.md` (AC17, AC18). |
| `ai-factory/docs/architecture.md` line 7 | "Hooks … fire on SessionStart, PreToolUse, PostToolUse and Stop" becomes false the moment AC1 lands. Not in the spec's component list; found while reading. |
| `.gitignore` | The two state files — `.counted.*` in Step 2, the step that starts writing it; `.task.*` in Step 5 (AC13). |
| `skills/ai-layout/templates/ai-factory/make/ai.mk` | One line in `clean-runs`, which today deletes `*.json` only. Beyond the ACs — see Risk R7. |
| `CHANGELOG.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json` | The breaking statement `ai-factory/AGENTS.md` requires, and the bump `check-versions.sh` enforces (AC17, definition of done 3). |

**Not created:** no template file, so no new symlink under the dont-touch `ai-factory/make/` and no
new `.sdlc.json` entry from `manifest.js`'s template walk. Every new file is plugin-side. Both new
scripts require only `fs`, `path`, `child_process` and their siblings, so AC20 holds with no ADR.

### Decisions this plan makes where the spec left the shape free

- **Column position.** `agent` goes immediately after `tool`:
  `…,task,tool,agent,model,…`. SD-001's whole point is that the agent is *beside* the tool rather
  than inside it, and reading `claude,implementer` adjacently says so. Nothing depends on position —
  the header break quarantines every existing row and no consumer exists yet (spec 0008 is unwritten).
- **State files.** Two, both under `ai-factory/runs/`, both gitignored, both keyed by `session_id`:
  - `.task.<session_id>` — one line, the bare task name (`spec`, not `/t4:spec`). The exploration's
    own proposal.
  - `.counted.<session_id>` — newline-delimited claim ledger, `u:<message uuid>` and
    `a:<agent_id>`. One file serves AC16 (a uuid is counted once across every transcript of the
    session), AC14 (the session row counts only unclaimed records, so it *is* the increment) and
    AC6 (a resumed agent's `agent_id` is already claimed, so the second event writes no row).
    Deriving the delta from the same ledger avoids a second state file whose two numbers could
    disagree, and it survives a flush — the previous totals cannot be recovered from
    `log.pending.csv`, which `log-flush.js` deletes.
- **Records with no `uuid` are counted and never claimed.** AC16 assumes every usage record carries
  one; the shipped `transcript.jsonl` fixture carries none. Counting them keeps the failure mode
  "may over-count on a transcript format that omits `uuid`" rather than "silently loses tokens".
- **Release version: `1.0.1`.** See ambiguity A-4 — `1.1.0` and `2.0.0` are both reserved by the
  1.0.0 CHANGELOG entry and ADR 0008 for removals this release must not make.

---

## Steps

- [x] **Step 1 — the seventeenth column, in both writers and every place that quotes it.**
  Add `agent` after `tool` in `_log-schema.js`'s `HEADER` and in the hand-copied `HEADER` in
  `templates/ai-factory/make/log.js`; emit an empty field in that position from `session-stop.js`
  and from `log.js`'s row. Update the column list in `skills/ai-hooks/SKILL.md`, "16 columns" in the
  same file and in `skills/ai-layout/SKILL.md` line 41, and the count wherever `ai-factory/docs/workflow.md`
  §9 implies it. In `check-log-schema.sh`, add an explicit `[ "$cols" = 17 ]` assertion and widen the
  two **literal 16-field rows hand-written in its tests 5 and 6** (the `,keep,` row and the
  `Doe, Jane` row) — miss these and a valid row is quarantined by the very test meant to prove it is not.
  *Proves:* AC3 (the empty `agent` on `session` and `make` rows), AC15, AC17.
  *Tests:* `bash skills/ai-hooks/fixtures/check-log-schema.sh` (header byte-identity, 17 columns,
  guard not drifted, test 3's whole-file quarantine of a non-matching header);
  `bash skills/ai-hooks/fixtures/check-detect.sh`; `bash skills/ai-layout/scripts/check-entrypoints.sh`.

- [x] **Step 2 — `_usage.js`: one transcript sum, one claim ledger, one pricing block.**
  New sibling exporting (a) `sumTranscript(file, claim)` — walks the JSONL, takes
  `r.message?.usage || r.usage`, skips a record whose `uuid` is already claimed, claims each `uuid`
  it counts, returns `{turns, inp, out, cr, cw, model}`; (b) `claims(ai, session_id)` — read/append
  over `.counted.<session_id>`, creating nothing until there is something to claim; (c)
  `price(ai, model)` — the exact-id → longest-prefix → `default` resolution lifted verbatim from
  `session-stop.js`, returning the `~` marker unchanged. Move `session-stop.js` onto it with no
  behaviour change yet: claims are recorded but not yet enforced against the session's own row.
  The row is unchanged, but the *tree* is not: this is the step that starts creating
  `.counted.<session_id>`, so the `ai-factory/runs/.counted.*` line lands here too — in this repo's
  `.gitignore`, in `skills/ai-hooks/SKILL.md`'s gitignore section, in `check-entrypoints.sh`'s
  `IGNORE` array and in `clean-runs`. Pulled back from Step 5, which kept AC13 false for three steps.
  *Proves:* AC4 (unchanged resolution, no new pricing code), AC13's `.counted.*` half, the machinery
  for AC14 and AC16.
  *Tests:* the whole existing suite must pass **unchanged** — this step is a refactor.
  `node --check` on every script; `bash skills/ai-hooks/fixtures/check-log-schema.sh`;
  `bash skills/ai-hooks/fixtures/check-detect.sh`; `bash skills/ai-layout/scripts/check-paths.sh`
  (the new file is in its scan set — a comment naming the pre-1.0.0 directory fails the build);
  `bash skills/ai-layout/scripts/check-entrypoints.sh` (the three copies of the new glob agree);
  `bash skills/ai-hooks/fixtures/check-usage.sh`.

- [x] **Step 3 — deltas at write.**
  `session-stop.js` now counts only records whose `uuid` is unclaimed, so the row it appends is the
  increment since that session's previous row; the first row of a session claims nothing yet and so
  carries the whole transcript. Add `transcript-uuid.jsonl` and a case in `check-log-schema.sh`: run
  the Stop hook, append two more `usage` records to the fixture, run it again, and assert the second
  row's four token columns and `turns` carry only the new records and that the two rows **sum** to
  the transcript total.
  *Proves:* AC14, and SD-003's "no migration script" by construction — nothing reads an old row.
  *Tests:* `bash skills/ai-hooks/fixtures/check-log-schema.sh`; `bash skills/ai-hooks/fixtures/check-detect.sh`
  (its two-Stop assertion still passes precisely because `transcript.jsonl` has no `uuid`).

- [x] **Step 4 — `subagent-stop.js`, and the event that calls it.**
  New script: `aiDir(ev)` guard first (exit 0, silent, no file, outside a layout repo); exit 0 if
  `agent_transcript_path` is missing, unreadable, unparseable or yields no `usage`; exit 0 if
  `a:<agent_id>` is already claimed; otherwise claim the `agent_id`, sum **that transcript only**
  through `_usage.js`, price it, and append one row to `log.pending.csv` with `source=agent`,
  `tool=claude`, `agent=<agent_type>` verbatim, `user`/`branch` from `cwd` via `_common.js`. The
  parent `transcript_path` is never opened. Register `SubagentStop` in `hooks/hooks.json` and extend
  its `description`. Update `ai-factory/docs/architecture.md`'s event list.
  Add `subagent-stop.json`, `agent-transcript.jsonl`, `agent-child-transcript.jsonl` and
  `check-subagent-stop.sh` asserting: one row with the right `source`/`agent`/`tool`/`model`
  (AC2, AC3); the priced and the `~`-estimated cost (AC4); a payload whose parent `transcript_path`
  points nowhere still writes a full row (AC5); a second event for the same `agent_id` with
  `stop_hook_active: true` writes no second row (AC6); the four no-row cases are silent and exit 0
  (AC7); and parent-then-child over the shared-UUID pair counts the inherited prefix **once**, with
  the two rows summing to the union of the two transcripts (AC16).
  Extend `check-detect.sh`'s four cases to this script.
  *Proves:* AC1, AC2, AC3, AC4, AC5, AC6, AC7, AC16, AC20, AC21.
  *Tests:* `bash skills/ai-hooks/fixtures/check-subagent-stop.sh`; `bash skills/ai-hooks/fixtures/check-detect.sh`;
  `node -e 'JSON.parse(require("fs").readFileSync("hooks/hooks.json","utf8"))'`.

- [x] **Step 5 — the task file, and the column it fills.**
  New `log-task.js`: `aiDir(ev)` guard; match `/t4:([a-z][a-z0-9-]*)` in `ev.prompt`; on a match
  write the bare name to `.task.<session_id>`; **write nothing to stdout or stderr, ever** — a print
  from `UserPromptSubmit` enters the model's context and breaks the cached prefix. No match: do
  nothing at all (see ambiguity Q9 — nothing clears the file). Register `UserPromptSubmit` in
  `hooks/hooks.json`. `session-stop.js` and `subagent-stop.js` each read the file and fill `task`,
  leaving it empty when the file is absent; neither infers a task from the branch, the agent type or
  the prompt text. Add the gitignore line `ai-factory/runs/.task.*` to
  `skills/ai-hooks/SKILL.md`'s gitignore section, to this repo's
  `.gitignore`, and to `check-entrypoints.sh`'s `IGNORE` array — which then asserts all three agree.
  Add the same glob to `clean-runs` in `templates/ai-factory/make/ai.mk`.
  (`ai-factory/runs/.counted.*` was pulled forward into Step 2 in all four places — Step 2 is the
  step that starts writing it, and leaving the ignore here made AC13 false for three steps. Only
  `.task.*` remains this step's, because nothing writes it until now.)
  *Proves:* AC9, AC10, AC11, AC12, AC13.
  *Tests:* `check-detect.sh`'s four cases for `log-task.js`, asserting empty stdout and empty stderr;
  a case in `check-subagent-stop.sh` writing `.task.<sid>` with `run` and asserting a `specifier`
  row carries `task=run` and `agent=specifier` (AC12); a case in `check-log-schema.sh` asserting the
  session row carries the same `task` (AC10, AC11) and that with no file the column is empty;
  `bash skills/ai-layout/scripts/check-entrypoints.sh`.

- [x] **Step 6 — the docs, the breaking statement, the version.**
  `skills/ai-hooks/SKILL.md`: two rows in the event table, the 17-column list, the `source` values
  (`session` · `agent` · `make`), the `uuid` de-duplication rule including the no-`uuid` fallback,
  the delta semantics, and — deleting the paragraph at lines 25–29 — what the agent rows now carry
  instead of "recovering them is a separate change". `ai-factory/docs/workflow.md` §9: the same,
  in the developer's register, replacing the "a session that delegated a step under-counts"
  sentence. Add the CHANGELOG top entry: **breaking for every adopted repo**, existing rows move to
  `log.previous.csv` on the next write, what that means for a log they have been keeping, and — see
  Risk R1 — a repeat of the six clauses `check-release-docs.sh` asserts on the *top* entry (breaking,
  run `/t4:migrate-layout` in each repo, the hooks keep accepting both names with the guard and the
  log, grep your own CI/pipeline/tooling, the command goes in 1.1.0, the fallback in 2.0.0). Bump
  `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` and `.codex-plugin/plugin.json` to
  the same version.
  *Proves:* AC17's documentation half, AC18.
  *Tests:* `bash skills/ai-layout/scripts/check-release-docs.sh`; `bash skills/ai-layout/scripts/check-versions.sh`;
  `bash skills/ai-layout/scripts/check-entrypoints.sh`; `bash skills/ai-layout/scripts/check-paths.sh`.

- [x] **Step 7 — the live run, and the residual the spec asks to confirm in passing.**

  **Completion — accepted by the developer on 2026-09-29.** Marked done at the
  developer's explicit request after stopping the live validation session. The
  session `3f337135-352c-4f6f-b988-1c9920107d6a` produced a background-agent row with
  `source=agent`, `task=explore`, and `agent=t4:explorer`. Foreground execution was
  unavailable in Claude Code 2.1.277: its Agent tool runs subagents in the background
  and exposes no `run_in_background` parameter. Final accounting reconciliation
  was not completed. This acceptance closes the remaining work; it does not claim
  those unperformed checks passed. The original requirements and historical result
  below are retained for context.

  Restart a session so the hooks load from the updated plugin, then in this repo run one `/t4:`
  command that delegates to a step agent **interactively** and one that delegates **in the
  background**, and record: the `log.pending.csv` rows with their `agent` and `task` values, that
  the session rows sum rather than climb, that `git status` shows neither state file, and that
  nothing was printed. This is open question 8 — "confirm it during implementation, and say so in
  the MR" — and it is also the before/after run the definition of done requires for a hook change.
  Write it up beside `ai-factory/runs/0006-live-runs.md` and link it in the MR.
  *Proves:* AC19 end to end, AC21 in a real repo, AC13's `git status` clause; answers Q8.
  *Tests:* the run transcript itself — the coding standards say a prompt or hook change is proved by
  a run, not by an assertion.

  **Historical result — Step 7 was not run, and is withdrawn. The box is deliberately left unticked.** Recorded
  2026-09-28, when the developer took this plan out of the active queue and filed it to
  `ai-factory/plans/done/` with Steps 1–6 done. Two things put the step out of reach of any agent as
  the repo stands, and neither is a judgement that it is not worth running:
  - **It needs a restarted session.** The hooks load from the installed plugin, not the working tree
    (Risk R12), so the run only exercises this change after a restart — and no agent can restart the
    session it is itself running in. That is the developer's action.
  - **The step agents it names are not registered agent types.** The step asks for a `/t4:` command
    that delegates to a *step agent*, but `ai-factory/agents/` symlinks only four of the eight
    definitions under `agents/` — `analyst`, `architect`, `reviewer`, `tester` — and only those four
    are spawnable. `explorer`, `implementer`, `planner` and `specifier` exist as definitions with no
    registration. A faithful run today would therefore record the wrong agent names, or none.

  **What this filing leaves outstanding, said plainly rather than closed:**
  - **The before/after run the definition of done requires for a hook change is outstanding.** Steps
    1–6 changed hooks, and no live run proves them. Everything in *Verification* passes; the
    fixtures are not the run, and the coding standards say so in the line quoted above.
  - **Spec 0007's open question 8 remains unanswered.** Interactive *and* background delegation was
    never directly exercised, which is exactly the residual Q8 asked to confirm in passing. Filing
    this plan does not answer it.
  - **AC19 end to end, AC21 in a live repo and AC13's `git status` clause are proved by fixture
    only**, not by the run this step specified.

  Nothing here claims the feature has been seen working in a live session. The step stands as
  written for whoever next restarts a session in this repo; it is withdrawn from the queue, not from
  the record.

---

## Risks, and how each is checked

| # | Risk | Check |
|---|---|---|
| R1 | `check-release-docs.sh` asserts six migration clauses on the CHANGELOG's **top** entry and ties that entry's version to `plugin.json`. A new top entry that does not repeat them fails the release guard — an unstated cost of AC17. | Step 6 repeats them; `bash skills/ai-layout/scripts/check-release-docs.sh`. |
| R2 | Version collision — see A-4. | `check-versions.sh` proves the manifests agree; the number itself is the developer's call. |
| R3 | `check-log-schema.sh` tests 5 and 6 hand-write literal 16-field rows. Left alone, the fixture quarantines rows it is asserting are valid, and the failure reads as a bug in the writer. | Step 1 widens them; the fixture fails loudly if missed. |
| R4 | `make log-flush` refuses when pending and `log.csv` have different headers, which is exactly the state right after this upgrade. The first flush must come from a session so the hook migrates. | Already the behaviour, and `ai.mk` prints that reason; Step 6 says so in the CHANGELOG. |
| R5 | A usage record with no `uuid` cannot be de-duplicated, so on a transcript format that omits it every Stop re-counts the whole file. | The rule is stated in SKILL.md; `transcript.jsonl` keeps the un-`uuid`ed path covered and `transcript-uuid.jsonl` the deduped one, so both behaviours are pinned rather than assumed. |
| R6 | First-claim-wins attributes a shared `uuid` to whichever agent concluded first — see A-1. Totals are right; the name on the row may be the child's rather than the parent's. | The AC16 fixture asserts *counted once* and the summed total, which is what is provable. The attribution gap is reported, not hidden. |
| R7 | `.task.*` and `.counted.*` accumulate under `runs/` forever; `clean-runs` deletes `*.json` only. No AC covers this. | Step 5's one-line `clean-runs` extension; flagged here because it is the one thing in this plan no acceptance criterion asks for. |
| R8 | A hook that prints breaks the cached prefix — worst from `UserPromptSubmit`. | `check-detect.sh` already asserts empty stdout; Step 5 extends it to stderr for both new scripts. |
| R9 | `check-paths.sh` scans everything under `skills/`; a comment in a new script naming the pre-1.0.0 layout directory fails the build, and neither new script may hard-code either directory name. | Both use `aiDir()`; `bash skills/ai-layout/scripts/check-paths.sh`. |
| R10 | Parallel subagents conclude at once: two `SubagentStop` processes read the ledger, neither sees the other's claim, and a shared `uuid` is counted twice. A fixture cannot provoke this reliably. | Mitigated, not eliminated: claim before writing the row, and append (`O_APPEND`, one short write) rather than rewrite. Recorded here as accepted. |
| R13 | Claims are durable before the row is: `sumTranscript` appends `u:<uuid>` during the sum, and the row is appended afterwards inside a `try { … } catch {}`. A swallowed write failure leaves uuids claimed with no row. Harmless while `session-stop.js` passes a non-enforcing `has` (every Stop re-reports the whole transcript, so it self-heals), but from Step 3 those tokens are excluded from every later delta, against AC14's "the totals equal the session's actual consumption". | **Accepted, not mitigated — Step 3 must choose deliberately**: either claim only after the row is durably appended, or keep claim-before-write for R10's race and accept the loss. R10 accepts the ordering for concurrency; this row records what the ordering costs on failure. |
| R11 | `SubagentStop` adds a transcript read to the turn's critical path. | Bounded by construction — one transcript, once per agent, unlike the rejected option B which re-read every subagent file on every Stop. |
| R12 | The plugin loads from the installed copy, not the working tree, so a fixture can pass while a live session still runs the old hooks and writes 16-field rows into a 17-field file. | Step 7 restarts the session first; `workflow.md` §9 already warns about this and the guard quarantines the mismatched rows. |

---

## Verification — everything that must pass at the end

Run from the repo root, each directly and never piped (a pipeline reports `tail`'s status, and a
failure reads as a pass):

```
for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done
for f in skills/ai-hooks/fixtures/check-*.sh skills/ai-layout/scripts/*.sh; do bash -n "$f"; done
node -e 'JSON.parse(require("fs").readFileSync("hooks/hooks.json","utf8"))'
for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f" || echo "FAIL $f"; done
bash ai-factory/make/sync-adapters.sh && git diff --stat && bash ai-factory/make/sync-adapters.sh && git diff --stat
node skills/ai-hooks/scripts/session-stop.js  < skills/ai-hooks/fixtures/stop.json
node skills/ai-hooks/scripts/subagent-stop.js < skills/ai-hooks/fixtures/subagent-stop.json
```

Named individually, because each carries one half of an acceptance criterion:

- `skills/ai-hooks/fixtures/check-log-schema.sh` — AC8, AC14, AC15, AC17, AC19
- `skills/ai-hooks/fixtures/check-subagent-stop.sh` — AC2, AC3, AC4, AC5, AC6, AC7, AC12, AC16, AC19
- `skills/ai-hooks/fixtures/check-detect.sh` — AC1, AC19, AC21
- `skills/ai-layout/scripts/check-entrypoints.sh` — AC13
- `skills/ai-layout/scripts/check-release-docs.sh` and `check-versions.sh` — AC17
- `skills/ai-layout/scripts/check-paths.sh` — AC20's "siblings only" and the no-hard-coded-directory rule

And, not reducible to a command: the Step 7 run transcript, linked in the MR, which is what proves
AC19 end to end, AC21 in a live repo, and open question 8.

---

## Ambiguities

Named where they touch a step, per the planner's rule that a plan built on a guess encodes the
guess. None of them blocked writing this plan.

### The spec's seven open questions

| Q | Bites? | What the plan does |
|---|---|---|
| 4 — one row per agent, or per task rolled up? | No | AC2 is written per agent and the plan follows it. A reversal would rewrite Step 4 entirely, so it is worth confirming before Step 4 starts rather than after. |
| 5 — what does `accepted` mean on an agent row? | No | Resolved by the spec's own *Out of scope*: `accepted` stays hand-filled at commit time, so an agent row leaves it empty like every other. The consequence the question raises — that cost-per-accepted-change never arrives — lands on spec 0008, not here. |
| 6 — Codex parity | No | Out of scope in the spec; no step touches Codex. |
| 7 — Cursor | No | Out of scope in the spec; nothing here can see it. |
| 8 — the EXD-002 residual (interactive *and* background) | Becomes a step | The spec itself says confirm in passing and say so in the MR, so it is Step 7 rather than a gate. |
| 9 — when is the task file removed, and what happens between tasks? | **Yes — Step 5** | Nothing in the ACs says. AC10 speaks only of the file's *existence*. The plan implements the minimum the criteria allow: only a `/t4:` prompt writes, last writer wins, nothing clears the file, nothing deletes it. The consequence the question predicts is real and unmitigated — a background agent still running from `/t4:plan` concludes after `/t4:run` was typed and is attributed to `run`. AC12 asks for exactly this last-writer-wins behaviour in the one crossing it names, so the criteria cannot distinguish the wanted case from the unwanted one. If the answer is "clear on a non-command prompt", Step 5 changes; if it is "per-agent capture at SubagentStart", the spec's own *Out of scope* forbids it. |
| 10 — what fills `task` for a session that never typed `/t4:`? | No | AC10 says empty; the plan writes empty. Spec 0008 decides what an `unattributed` bucket is called at the reporting end. |

### Found while planning

- **A-1 — AC16 names an owner it gives no way to identify.** "Counted once, **for the agent whose
  own turn produced it**" is two requirements. The first is implementable and pinned. The second is
  not: a `SubagentStop` hook sees one transcript at one moment and no field says which agent
  produced a record; SD-004 rules out the depth rule, and the measured duplicates sit at positions
  11–50 of the child rather than at its head, so position does not identify them either. The plan
  claims by order of conclusion, which for a fork means the **children** claim the parent's
  inherited prefix, because a parent concludes after them. Every token is counted exactly once and
  the session totals are right; the `agent` name on the row may be the child's where SD-004 says the
  parent earned it. Correcting it needs a signal the payload does not carry.
- **A-2 — where the seventeenth column goes.** Unspecified. Plan: after `tool`. Free to change while
  no consumer exists.
- **A-3 — the ledger the spec asks for but does not locate.** AC14 and AC16 both say state must live
  "somewhere it can read" and stop there. The plan invents `.counted.<session_id>` and gives it the
  same lifetime as `.task.<session_id>` — which means Q9's lifetime question applies to it too, with
  a sharper edge: a stale ledger for a resumed `session_id` would make the next Stop's delta too
  small, where a stale task file only mislabels.
  The opposite hazard is the sharper one and the key is what decides it: a session **forked to a new
  `session_id` off the same transcript** gets an empty ledger, and under Step 3 re-counts the whole
  inherited transcript as its first increment — the very over-count AC16 exists to prevent, one
  level up. Step 3 should decide deliberately whether the ledger is keyed by `session_id` or by
  transcript path; `session_id` is the plan's choice, not the spec's requirement.
- **A-4 — the release version.** `1.1.0` is reserved by the 1.0.0 CHANGELOG entry and by ADR 0008
  for the release that removes `/t4:migrate-layout`; `2.0.0` for the one that removes the `ai/`
  fallback, which AC21 requires this release to keep. Shipping this as `1.1.0` publishes a
  deprecation notice that contradicts itself. The plan picks `1.0.1` — the only number that claims
  no reserved slot — and notes that semver would want a major for a breaking payload change. The
  developer may prefer to re-aim the reserved numbers instead, which is an edit to ADR 0008 and
  `check-release-docs.sh` and therefore its own chore.
- **A-5 — the CHANGELOG guard's shape.** `check-release-docs.sh` was written when 1.0.0 was the only
  entry and asserts the migration clauses on whatever entry is on top. Every release from now on
  either repeats them or the guard is re-scoped to the entry that introduced the rename. The plan
  repeats them (cheapest, and they are still in force); re-scoping is the better long-term fix and
  is not this spec's.
- **A-6 — usage records with no `uuid`.** AC16 assumes the key always exists; the repo's own shipped
  fixture disproves it. The plan states the fallback explicitly — counted, never claimed — and keeps
  a fixture on each side of it.
- **A-7 — AC2 subjects `turns` to the `uuid` rule too**, so a de-duplicated record also loses its
  turn. That is what the plan implements, and it is the only reading that keeps `turns` summable
  alongside the token columns; noted because the spec states it only in passing.
