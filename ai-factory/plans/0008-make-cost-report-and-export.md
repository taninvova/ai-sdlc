# Plan 0008 — `make cost`: the token-spend report and the versioned export

**Goal:** Build one dependency-free Node script and one `cost` target that turn a repo's
`ai-factory/runs/log.csv` into a rendered token-spend table and the same numbers as a versioned
machine-readable export, with the arithmetic provable against fixtures before a single real agent row
exists.

**Spec:** [`ai-factory/specs/0008-make-cost-report-and-export.md`](../specs/0008-make-cost-report-and-export.md)

## Before anything else: the decisions this plan rests on

**Nine of the spec's ten open questions are answered** — question 1 on 2026-09-26, the rest on
2026-09-27 — so no step below is blocked and nothing here rests on a guess. The decisions that shape
the work:

- **Tokens only, no money in either surface.** AC2's metric list and field names are final, **AC3 is
  withdrawn**, and AC7 stands unchanged because neither surface prices anything. `cost_usd` is never
  read.
- **Four stacked tables**, one per grouping (task, agent, branch, day), each with all seven metrics —
  ~76 characters, so AC9's 80-column limit costs no metric (Step 6).
- **`JSON=1` and `TSV=1`, no filters in v1** (Step 5).
- **An integer export version starting at `1`**: additions keep it, renames, removals and changes of
  meaning increment it, consumers ignore unknown fields (Steps 4 and 9). Note the asymmetry AC6 now
  spells out — the check script fails on an addition even though the version does not move.
- **`accepted` coverage prints only when a value exists**; the docs carry the standing fact (Steps 6
  and 9).
- **Multi-tool totals carry a footnote** naming the contributing tools, which is really about the
  by-agent table (Step 6).
- **"Cursor is not measured" is stated plainly** in the docs section describing what the report can
  answer (Step 9).
- **`report.html` is gitignored, and that line ships in this release** even though R2 is v2 (Step 9).

The one question still open, **7**, is not this spec's to answer: it asks what a *fleet consumer*
should do with a session that moved, and that belongs to the fleet spec. Nothing here waits on it.

**The one sequencing constraint that remains.** This feature ships after
`ai-factory/specs/0007-subagent-stop-per-agent-accounting.md`. **Status as of 2026-09-27: 0007 exists
and is merged to `main`** — it was written and partly built on the branch `ai/0007-steps-1-2`, which is
why this plan was first drafted saying the spec was absent; the numbering gap was an unmerged branch,
not a missing decision. Six of its seven steps are done: the 17-column header with `agent` at
**position 8** (not appended last — index by name, never by position), the rotation of pre-existing
rows into `log.previous.csv`, deltas at write, `subagent-stop.js`, the task column, and the docs and
2.0.0 release. **Step 7, the live run, is outstanding.**

So building here is unblocked and Risk R1's condition is substantially met: the rotation and the deltas
have both landed, in this repo too — `log.previous.csv` was created at 11:13 on 2026-09-27 when the
header changed. What still waits on 0007 step 7 is **releasing**: that run is what confirms the harness
actually sends `agent_transcript_path` and `agent_type` on `SubagentStop` and delivers `ev.prompt` to
`UserPromptSubmit`. Until it does, the `agent` and `task` dimensions this report groups by may be empty
in practice for every adopted repo, which would make a shipped `make cost` technically correct and
practically useless.

## Files to create / modify

| File | Why |
| --- | --- |
| `skills/ai-layout/templates/ai-factory/make/cost.js` | **New.** The reader, the aggregation engine, the export and the renderer. CommonJS, Node built-ins only, no build step (AC17), beside `log.js` and `gate.js` (AC18). |
| `skills/ai-layout/templates/ai-factory/make/ai.mk` | The `cost` target, its `.PHONY` entry, and the `JSON=1` variable AC1 names. `RUNS` already points at `ai-factory/runs` (AC8, AC10, AC21). |
| `ai-factory/make/cost.js` | **New symlink** into the template, so this repo dogfoods the target (AC18). The directory is symlinks only and is on `ai-factory/docs/dont-touch.md` — see Step 8 for who creates it. |
| `skills/ai-layout/scripts/check-cost.sh` | **New.** The AC6 schema pin and the AC22 arithmetic fixtures, modelled on `skills/ai-hooks/fixtures/check-log-schema.sh`. Placed with the other `check-*.sh` because the thing under test is a layout template, not a hook; the spec allows either location. |
| `skills/ai-hooks/fixtures/cost/*.csv` | **New.** The fixture logs whose totals are known by construction (AC22), beside the existing fixtures. |
| `skills/ai-layout/SKILL.md` | The layout inventory gains the new template file (AC20). |
| `skills/ai-hooks/SKILL.md` | The prescribed gitignore list gains `ai-factory/runs/report.html` — decided 2026-09-27, shipping ahead of the v2 file itself. |
| `ai-factory/docs/workflow.md` | The new section: that `make cost` exists, what it can answer, and what the log cannot see at all (AC20). |
| `CHANGELOG.md` | One entry. Not breaking — nothing is removed and no schema moves (AC20). |
| `.claude-plugin/plugin.json` | Version bump for the template change, which `check-versions.sh` and `check-release-docs.sh` police. |

**Not touched:** `log.csv`'s header and column count (0007's change, not this one),
`skills/ai-hooks/scripts/_log-schema.js` except as Risk R2 requires, every hook script, every task
prompt, every agent, `models.yaml`, `.gitattributes`, and `ai-factory/runs/` in any way at all
(AC16).

## Server vs client components

Not applicable, and stating it plainly rather than inventing a split: this repo runs nothing as a
service. `ai-factory/docs/architecture.md` says "nothing runs as a service" and
`.claude-plugin/plugin.json` records no runtime dependency. The whole deliverable is one CommonJS
script invoked synchronously by `make`, writing to stdout and exiting. There is no server, no client,
no process that outlives the command, and no port.

## Steps

- [x] **Step 1 — The reader, and the guard it must not fork.** Create
  `skills/ai-layout/templates/ai-factory/make/cost.js` with the record-aware read: the
  `records()`/`width()` pair copied **byte-identically** from the shared guard block in
  `skills/ai-hooks/scripts/_log-schema.js`, between the same
  `--- shared schema guard`/`--- end shared schema guard ---` markers, because a template file cannot
  `require` the plugin's copy. Index columns **by header name, never by position**, so the 17th
  `agent` column 0007 adds is picked up without a code change and its absence is not a crash.
  Classify every record: conforming, wrong-width (excluded and counted, AC14), or unreadable. Note
  for the implementer: AC15's pre-0007 cumulative rows need **no separate detector** — an older
  writer's 16-field row under a 17-column header is wrong-width and is excluded by AC14's rule. That
  is the whole mechanism, and it is why the spec can forbid every repair heuristic. Do not add one.
  No aggregation in this step.
  *Proves:* AC13, AC14, AC15, AC17. *Tests:* `node --check` on the file; fixtures for a quoted
  comma, a wrong-width row and a pre-0007 row piped through the reader, asserting counts.

- [x] **Step 2 — The fixture corpus and the check harness.** Create
  `skills/ai-hooks/fixtures/cost/` with one `log.csv` per case the spec enumerates, each with totals
  known by construction: quoted fields (AC13), a wrong-width row (AC14), pre-0007 rows (AC15), empty
  `task` (AC11), header-only (AC10). No cost fixture is needed — `cost_usd` is never read (decision of
  2026-09-27), so the column's empty and `~`-prefixed states have nothing to assert. Create
  `skills/ai-layout/scripts/check-cost.sh` with `set -euo pipefail`, running the reader over each and
  failing if a count departs from the expected value. The aggregation assertions land in later steps;
  this step builds the harness and the cases that Step 1 already satisfies.
  *Proves:* AC22 (the harness), and pins Step 1's behaviour. *Tests:* `bash
  skills/ai-layout/scripts/check-cost.sh` passes and fails loudly when a fixture total is edited.

- [x] **Step 3 — The aggregation engine.** Group the conforming records by each dimension the spec
  names — task, agent, tool, model, branch, user, day, session — and compute per group: row count,
  `turns`, `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_write_tokens` and `hit_rate`.
  Rows with an empty `task`, or carrying no agent, go to an **explicitly named unattributed bucket**
  with their count visible, never dropped and never folded into another group (AC11). Report the
  `accepted` column's **coverage** — how many rows carry a value — never an average over the few that
  do (AC12). Keep `session_id` as a retained key so two layouts' exports can be de-duplicated
  (AC4). **No cost metric at all**, here or anywhere: the decision of 2026-09-27 keeps `cost_usd`
  unread, so the engine never opens that column.
  *Proves:* AC4, AC11, AC12, and AC2 in full. *Tests:* new cases in `check-cost.sh`
  asserting each group's totals against the fixtures; a two-layout fixture pair sharing a
  `session_id`, asserting the key survives in both.

- [x] **Step 4 — The JSON export envelope.** `make cost JSON=1` writes **one JSON document to stdout
  and nothing else** — no progress line, no banner, no path echo — and exits 0 (AC1). The document
  carries a schema-version field, and names every dimension and metric in documented, stable field
  names, with **agent and tool as two independent fields** carrying their columns verbatim so no
  consumer ever splits a value (AC2). Diagnostics, if any, go to stderr. Extend `check-cost.sh` to
  assert the exact field-name set and fail on **any** departure from it — rename, removal or addition
  (AC6's pin). The version field carries the integer **`1`** (decided 2026-09-27). Read AC6's closing
  note before writing the assertion: the check fails on an addition, but an addition does **not** bump
  the version — the check guards accidental drift, the version communicates breakage, and they are
  deliberately not the same rule. The version's documented meaning is written up in Step 9.
  *Proves:* AC1, AC2 (token metrics), AC6's check-script half. *Tests:* `make cost JSON=1 | node -e
  'JSON.parse(...)'` yields one document with nothing before or after it; `check-cost.sh` field-name
  assertion fails on a deliberate rename.

- [x] **Step 5 — The TSV mode.** `make cost TSV=1` serialises the same structure as one header line
  plus one line per group, with the same field names as the JSON, piping cleanly into `column -t`
  (AC5). `TSV=1` beside `JSON=1` is the whole flag surface, and **v1 takes no filter of any kind**
  (decided 2026-09-27) — do not add a date, branch or task selector, however easy it looks.
  *Proves:* AC5. *Tests:* a fixture's TSV output and JSON output compared field by field; the TSV
  piped through `column -t`; `check-cost.sh` asserting no filter variable is honoured.

- [x] **Step 6 — The rendered table.** `make cost` with no arguments prints token spend grouped by
  task, by agent, by branch and by day, reading `ai-factory/runs/log.csv` and no other file, exiting 0
  (AC8) — and it renders **as a view over the structure Step 3 produces**, so every number appearing in
  both modes is identical and the arithmetic exists once (AC7). The layout is decided (2026-09-27):
  **four stacked tables, one per grouping, each carrying all seven metrics** — rows, turns, input,
  output, cache read, cache write, hit rate — which measures ~76 characters against AC9's 80-column
  limit, so no metric is dropped and no dimensions are folded into a composite key. Two output rules
  come with it: a total whose rows span more than one `tool` carries a **footnote naming the
  contributing tools**, which is what keeps the by-agent table honest where Codex collapses into a
  single agent-equals-session bucket (AC8); and the `accepted` **coverage line prints only when at
  least one row carries a value** (AC12).
  *Proves:* AC7, AC8, AC9, AC12. *Tests:* a fixture rendered and diffed against the export's numbers;
  every output line asserted ≤ 80 characters; a mixed-`tool` fixture asserting the footnote appears and
  names both tools; a fixture with no `accepted` value asserting no coverage line, and one with a value
  asserting it appears.

- [x] **Step 7 — The empty and missing cases.** A `log.csv` that is missing, header-only, or holds no
  row after AC14 and AC15's exclusions makes both modes **say so explicitly, naming the file read and
  the row count found, and exit 0** (AC10) — an empty table with no explanation reads as a broken
  feature, and this is the workspace root's state today. Prove the same behaviour in a scratch repo
  that has just taken `/t4:adopt-sdlc`, where the log is header-only (AC19).
  *Proves:* AC10, AC19. *Tests:* the header-only fixture in both modes; a real
  `/t4:adopt-sdlc` scratch repo with `make cost` run in it, recorded as the before/after run.

- [ ] **Step 8 — The target, the symlink, the manifest.** Add the `cost` target to
  `skills/ai-layout/templates/ai-factory/make/ai.mk` and list it in `.PHONY`, invoking
  `node ai-factory/make/cost.js` with `$(RUNS)`. The target must read **one layout's log and nothing
  else** — no directory outside the repo listed, walked or enumerated, because the workspace root
  inherits this same `ai.mk` through its include (AC21). Then the per-file symlink
  `ai-factory/make/cost.js → ../../skills/ai-layout/templates/ai-factory/make/cost.js`, matching the
  four that exist. **Note for whoever runs this step:** `ai-factory/make/` is on
  `ai-factory/docs/dont-touch.md` and the `guard-paths` hook blocks an agent from writing there, and
  no script in the repo creates these symlinks — the four present were made by hand. So this one is
  the developer's `ln -s`, not the implementer's, and `/t4:run` should stop and say so rather than
  attempt it.
  *Proves:* AC18, AC21. *Tests:* `node skills/ai-layout/scripts/manifest.js check <repo> <plugin>`
  reports a freshly adopted repo up to date with the new file tracked in `ai-factory/.sdlc.json`;
  `bash skills/ai-layout/scripts/check-manifest.sh`; a grep over `cost.js` and the target for any
  path leaving the repo.

- [x] **Step 9 — Docs, the contract statement, and the release.** `skills/ai-layout/SKILL.md`'s
  inventory gains the file; `ai-factory/docs/workflow.md` gains a section saying `make cost` exists,
  which dimensions are meaningful only for rows written by 0007's collection change, and what the log
  cannot see at all — per-plan-step cost, wall-clock, tool-call counts, lines changed, and Cursor
  (AC20). One section names the export a **contract** and states the version rule in full: a plain
  integer starting at `1`, additions leaving it alone, renames and removals and changes of meaning
  incrementing it, consumers obliged to ignore fields they do not recognise, and a rename breaking for a
  consumer this repo cannot see (AC6's docs half). Four wordings are fixed by the decisions of
  2026-09-27 and are no longer open: **Cursor's absence is stated plainly in the same section that says
  what the report can answer**, not in a footnote; the **`accepted` column is described as hand-filled
  and usually empty**, which is the standing fact that replaces a permanent "0 of N" line; the
  **multi-tool footnote** is explained where the by-agent table is described; and the docs record that
  this feature reports **tokens and turns, never money**, and why. Also in this step, per the same round
  of decisions: `skills/ai-hooks/SKILL.md`'s prescribed gitignore list gains
  `ai-factory/runs/report.html` — R2's file is still v2, but the line ships now so no later run can
  commit a rendered report of user, branch and spend data by accident. CHANGELOG entry and version bump.
  *Proves:* AC6 (docs half), AC20. *Tests:* `bash skills/ai-layout/scripts/check-release-docs.sh`;
  `bash skills/ai-layout/scripts/check-versions.sh`; a freshly adopted scratch repo's `.gitignore`
  carrying the `report.html` line.

- [x] **Step 10 — Read-only, proved.** Assert that running either mode creates, modifies, moves or
  deletes nothing under `ai-factory/runs/` (AC16), so the target can never cost a developer a row.
  Add the assertion to `check-cost.sh`: snapshot the directory, run both modes, compare.
  *Proves:* AC16. *Tests:* `check-cost.sh`'s new case; `git status --porcelain ai-factory/runs/`
  empty after a real `make cost` in this repo.

## Risks and how each is checked

- **R1 — Shipping before 0007 turns the engine into the bug it exists to prevent.** Against a
  *pre*-0007 header of 16 columns, every row is a cumulative snapshot that is *conforming to that
  header*, so nothing excludes it and `make cost` would sum snapshots — the spec's ~$1,240-for-$159
  measurement is exactly this. **Largely retired as of 2026-09-27:** 0007's rotation and deltas have
  landed, so a repo taking 2.0.0 quarantines its cumulative rows into `log.previous.csv`, which the
  reader never opens. What remains of the risk is a repo that takes `make cost` *without* 2.0.0's
  header change, which the release gate below prevents, and the fact that nothing in the reader can
  detect a cumulative row on its own — as Step 1 confirmed, and as the spec forbids it from trying.
  *Checked by:* the release gate — the `cost` target does not ship in a release that does not already
  carry 0007's rotation; and `check-cost.sh` asserting that a 16-field row under a 17-column header is
  excluded and counted, which is the post-rotation shape of the same row.
- **R2 — A third copy of the schema guard, and only two are pinned.** `_log-schema.js` and `log.js`
  hold byte-identical copies today, held together by `check-log-schema.sh`; `cost.js` makes three,
  and an unpinned copy will drift. *Checked by:* extending `check-log-schema.sh` to diff all three
  guard blocks, not two. This is the one edit this plan makes to an existing check script, and it is
  why `skills/ai-hooks/scripts/_log-schema.js` appears in the risk list rather than the untouched
  list.
- **R3 — A renamed export field breaks a consumer no fixture here can reach.** The whole reason the
  spec fixes R3's schema first. *Checked by:* AC6's field-name assertion in `check-cost.sh`, which
  fails on any rename, removal or addition without a version change.
- **R4 — Column-position indexing.** Indexing by position rather than header name would break the
  moment 0007 inserts the 17th column. *Checked by:* Step 1's by-name lookup, and a fixture whose
  columns are in a different order.
- **R5 — The dont-touch symlink.** An implementer that tries to create `ai-factory/make/cost.js` is
  blocked by `guard-paths`, and may then "work around" it by editing the template's consumer or
  weakening the rule. *Checked by:* Step 8 naming the symlink as the developer's action and requiring
  `/t4:run` to stop rather than attempt it.
- **R6 — Stdout purity.** One stray diagnostic on stdout makes AC1 false and breaks every consumer
  parsing the document. *Checked by:* piping `make cost JSON=1` straight into a JSON parser in
  `check-cost.sh`, with any leading or trailing byte a failure.
- **R7 — A decision quietly widened during implementation.** Nothing is blocked now, which moves the
  risk: the temptation is no longer to guess but to improve on a decision — adding a filter because it
  is three lines, bumping the version on an addition because that feels tidier, or making the coverage
  line permanent. Each of those was considered and rejected on the record. *Checked by:* `/t4:check`
  reading the diff against the spec's decision blocks, not only its ACs; and `check-cost.sh` asserting
  the two that are machine-checkable — no filter variable is honoured, and no coverage line appears
  when no row carries a value.

## Verification

Run from the repo root, all of them green, before the MR:

```
node --check skills/ai-layout/templates/ai-factory/make/cost.js
bash skills/ai-layout/scripts/check-cost.sh
bash skills/ai-hooks/fixtures/check-log-schema.sh      # now pinning three guard copies (R2)
bash skills/ai-layout/scripts/check-manifest.sh
bash skills/ai-layout/scripts/check-paths.sh
bash skills/ai-layout/scripts/check-versions.sh
bash skills/ai-layout/scripts/check-release-docs.sh
make cost                                              # this repo's own log
make cost JSON=1 | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8"))'
git status --porcelain ai-factory/runs/                 # empty — AC16
```

And in a scratch repo that has just taken `/t4:adopt-sdlc`, `make cost` printing the AC10 message for
a header-only log (AC19) — recorded in the MR as the before/after run, which is how this repo proves
behaviour per `ai-factory/docs/coding-standards.md` ("no test runner").

**Every AC is now verifiable.** AC3 is withdrawn rather than deferred, and the questions that gated
AC5, AC6, AC9, AC12 and AC20 were all answered on 2026-09-27. The only thing outside this plan's reach
is the release order: AC18 and AC19 are proved in a scratch repo, but the feature does not ship to
adopted repos until spec 0007's rotation has landed (Risk R1).
