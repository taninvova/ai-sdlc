# 0008 — `make cost`: the token-spend report, and the versioned export a fleet view reads

Summary: one dependency-free Node script and one `cost` target in `ai-factory/make/ai.mk` turn a
repo's `ai-factory/runs/log.csv` into an answer to "where did the tokens go" — a rendered table of
token spend by task, by agent, by branch and by day for the developer at a terminal (**R1**), and
the same numbers as a versioned, machine-readable JSON/TSV export for whoever is looking across the
fleet (**R3**). One aggregation, two surfaces, so "spend per task" is defined once. **Spend is
counted in tokens and turns, never in money** — decided 2026-09-27, see below.

**Depends on `ai-factory/specs/0007-subagent-stop-per-agent-accounting.md`, and ships after it.**
**Status 2026-09-27: 0007 is written, merged and six of its seven steps are built** — the 17-column
header with `agent` at position 8, the rotation into `log.previous.csv`, deltas at write,
`subagent-stop.js`, the task column, and the docs and 2.0.0 release. Only its live run is outstanding.
When this spec was first drafted 0007 appeared absent because it lived on an unmerged branch; the
decision of 2026-09-27 that it ships as its own spec first turned out to describe work already under
way. What it decides is on record below (the `agent` column, delta rows, the rotation).
This is not sequencing taste. Measured in `ai-factory/explorations/0001-token-consumption-by-task-and-agent.md`:
every row in `ai-factory/runs/log.csv` is a **cumulative snapshot of its session**, so the 19 rows
of one session sum to ~$1,240 for ~$159 of work; `task` is **blank on every interactive row**; and
there is **no `agent` column at all**. The two aggregations this feature exists to provide have
nothing to group by, and no reader can synthesise either — taking the maximum per `session_id`
instead of the sum would be a guess about writer semantics, which is exactly what
`skills/ai-hooks/scripts/_log-schema.js` refuses to do ("rows are never reinterpreted … guessing is
what caused the original mixed-schema bug"). A report shipped first would answer the headline
question with one bucket labelled blank and a total wrong by ~8×, and the first person to quote it
in a budget conversation would be quoting a bug. What *can* be built before 0007 lands is the
aggregation engine and the export's shape, against fixture CSVs (AC6, AC22).

What exploration 0001 settles and this spec does not reopen:

- **EXD-001** — both audiences are in scope: a developer at a terminal *and* an owner looking
  across the fleet. R1 and R3 are therefore both v1, and they are not a hedge.
- **R3's schema is designed first**, even though both ship in one change. R1's table layout can be
  relaid out whenever; the moment a collector in another repo parses R3, a renamed field is a
  breaking change for a consumer no fixture here can reach. This repo already paid that bill once —
  `log.csv`'s header is hand-duplicated in `_log-schema.js` and
  `skills/ai-layout/templates/ai-factory/make/log.js` and held together only by
  `skills/ai-hooks/fixtures/check-log-schema.sh`.
- **A reader must de-duplicate by `session_id` across logs, not only within one.** A session that
  changes working directory is written to several layouts, because `aiDir()` in
  `skills/ai-hooks/scripts/_common.js` is `path.join(cwd, name)` with no upward walk. Measured:
  four sessions appear in more than one of the workspace's ten logs, and taking the maximum
  snapshot *within* each log and then summing across logs still over-counts them by **$83.52**
  against correct spend of **$147.48** — a 57% overstatement on the overlapping sessions alone.
  Only two of the four involve a parent layout, so this cannot be waived by settling the nesting
  question. The walker is not this spec's (see *Out of scope*); what this spec owes it is an export
  that makes the de-duplication possible (AC4).
- **RS-001**, a local Next.js app, is **rejected** by the developer (2026-09-25): it would be the
  plugin's first dependency, first lockfile, first build step and first long-running process, and
  contradicts `.claude-plugin/plugin.json`'s "no runtime dependency", `ai-factory/AGENTS.md`'s "no
  application code, no build step" and `ai-factory/docs/architecture.md`'s "nothing runs as a
  service". **RS-002**, a `/t4:cost` task that has a model sum the CSV, is not recommended there
  either. Neither is re-proposed here.
- **The report shows what the log can honestly carry and nothing else.** Obtainable from the
  columns: `branch`, `user`, `tool`, `model`, day, `session_id`, the four token columns, `hit_rate`,
  `turns`, `cost_usd`. Obtainable once 0007 lands: **per task**, **per agent**, and **any sum across
  runs**. Not obtainable from `log.csv` at any effort, and therefore absent: per-plan-step cost
  inside `/t4:run`, wall-clock duration, tool-call counts, lines changed, and anything about Cursor.

**Decided 2026-09-26 by the developer**, after this spec was first written, and settling what
exploration 0001 left open about the shape this report reads:

- **The agent name arrives as a 17th `agent` column in `log.csv`** — not encoded as
  `claude/explorer` inside the existing `tool` field. On record: encoding overloads a field the
  reader already parses and forces every consumer to split it. So the export's agent and tool
  dimensions are two independent fields, and no consumer of R3 ever splits a value (AC2).
- **The header break is accepted.** `log.csv` gains a column, and the existing rows rotate into
  `ai-factory/runs/log.previous.csv` by the guard that already does this.
- **Rows are written as deltas** from 0007 onwards. The reader therefore sums the rows it finds in
  the current `log.csv`, because they are deltas by construction; the old cumulative rows are
  **quarantined by the header rotation**, not migrated and not reinterpreted. This does not loosen
  AC15: the reader still applies no repair heuristic to a cumulative row, wherever it finds one.

**Decided 2026-09-27 by the developer**, answering Open question 3 — the last one that blocked the
plan:

- **The export carries tokens only, and no money at all.** The metrics are the four token columns,
  `turns`, `hit_rate` and the row count; `cost_usd` is not a metric of this feature, in either
  surface. On record: nine of the workspace's ten logs sit in layouts that may run different models,
  `cost_usd` is already `~`-marked or empty per row, and a rolled-up dollar figure would be summing
  prices set in ten separate `models.yaml` files. A fleet view that wants money applies one price
  list to the token counts itself, which makes its totals comparable by construction.
- **No money in the rendered table either.** Not only in the export: pricing locally for the
  terminal would put a number in the table that is absent from the export, and AC7 exists to
  guarantee that every number appearing in both is identical. One arithmetic, two surfaces, holds
  only if neither surface prices anything. This is what keeps AC7 unchanged.
- **AC3 is therefore withdrawn**, not deferred, and AC2's metric list is final. `cost_usd`'s three
  states — priced exactly, estimated, not priced — stop being this feature's problem, because it
  never reads the column.

**Also decided 2026-09-27 by the developer**, answering every remaining open question except 7:

- **0007 is written as its own spec and ships first** (was: an undeclared gap in the numbering). The
  rotation is the riskier half of this work — it breaks the header, quarantines every existing row and
  changes what a row *means* from snapshot to delta — so it earns its own criteria and its own review
  rather than a subsection here. This spec's engine is provable against fixtures meanwhile, so
  splitting costs no calendar time.
- **The default table is four stacked tables, one per grouping** — task, agent, branch, day — each
  carrying all seven metrics: rows, turns, input, output, cache read, cache write, hit rate. Measured
  against AC9's limit: a 12-character label plus the seven columns is ~76 characters, so nothing has
  to be dropped and no dimension becomes a composite key (Open question 4).
- **The flag surface is `JSON=1` and `TSV=1`, and there are no filters in v1.** Two booleans match
  `ai.mk`'s existing `TOOL`/`TASK`/`MODEL`/`INPUT` variables; `FORMAT=tsv` cannot replace the `JSON=1`
  that AC1 fixes, and carrying both would be two ways to say one thing. A filter added later is cheap;
  an export field renamed later is not (Open question 5).
- **The export's version is a plain integer starting at `1`.** Adding a field leaves it alone; any
  rename, removal or change in an existing field's meaning increments it. A consumer's obligation is
  therefore to ignore fields it does not know, and the docs say so. Semver expresses nothing useful
  over a flat aggregate. The first published document is read by whoever will write the fleet
  collector before it ships (Open question 6).
- **The `accepted` coverage line appears only when at least one row carries a value**, and the docs
  say plainly that the column is hand-filled and usually empty. A permanent "0 of N" teaches every
  reader to skip a line (Open question 8).
- **A total whose rows span more than one `tool` carries a footnote naming the contributing tools.**
  The sums themselves stand — a token is a token whichever CLI spent it — so this is not a refusal to
  add them. It earns its place on the **by-agent** table, where Codex rows collapse into one
  agent-equals-session bucket while Claude rows spread across real agent names, so a reader is
  otherwise comparing a part against a whole (Open question 9).
- **"Cursor is not measured" is accepted and stated plainly**, in the same docs section that says what
  the report *can* answer rather than in a footnote — a total that silently omits a tool is a trap, one
  that names its coverage is merely scoped. Closing the gap needs the rejected option D (Open
  question 10).
- **The v2 `report.html` is gitignored, decided now.** It would render user, branch and per-session
  spend into a file whose removal from a shared history later means a rewrite, and it is regenerable
  from a tracked `log.csv` by the target this spec adds. So the line lands in
  `skills/ai-hooks/SKILL.md`'s prescribed gitignore list in this release, before any `report.html`
  exists to be committed by accident (Open question 2).

The request handed to this spec was the single word "reporting". Everything above and below is
taken from exploration 0001, which the session named as the source of record, plus the decisions
recorded immediately above; nothing is inferred from the word itself.

## User story
As a developer running the t4 loop in a repo, I want `make cost` to tell me what this repo's runs
cost, broken down by task, agent, branch and day, so that I can see which step of the loop is
expensive without opening a CSV or trusting a model's arithmetic.

As the owner of the fleet, I want the same numbers as a versioned machine-readable export from each
repo, so that something I write elsewhere can roll them up without this plugin ever knowing that
collector exists.

## Acceptance criteria

### The export — the contract, fixed first

- **AC1** Given a repo with the layout and a readable `ai-factory/runs/log.csv`, When `make cost
  JSON=1` is run, Then stdout carries one JSON document and nothing else — no progress line, no
  banner, no path echo — the exit status is 0, and the document is a complete answer for that one
  layout's log.
- **AC2** Given that document, When it is read by something that has never seen this repo, Then it
  states a **schema version** of its own, and it names, in documented and stable field names, both
  the grouping dimensions — task, agent, tool, model, branch, user, day and session — and the
  metrics per group: number of rows, `turns`, `input_tokens`, `output_tokens`,
  `cache_read_tokens`, `cache_write_tokens` and `hit_rate`. **No money:** the decision of 2026-09-27
  keeps `cost_usd` out of the export entirely, so a consumer that wants a dollar figure prices the
  token counts itself. A consumer needs no knowledge of `log.csv`'s column order to use it. **Agent
  and tool are two separate fields**, carrying the 17th `agent` column and the `tool` column
  verbatim: because the decision of 2026-09-26 keeps the agent out of `tool`, no consumer of this
  export ever splits a value to recover a dimension, and a field name is never a composite. This
  metric list and these names are now **final** — both decisions that could still have moved them
  have been taken.
- ~~**AC3** Given rows whose `cost_usd` is empty — every Codex row, by design — and rows whose value
  is `~`-prefixed, When the export is produced, Then the three states are distinguishable in it:
  priced exactly, priced from the built-in figures (an estimate), and **not priced**. A not-priced
  row is never exported as a zero, and a count of them is carried beside every cost total.~~
  — **withdrawn 2026-09-27** by the tokens-only decision. Nothing reads `cost_usd`, so its three
  states are not this feature's concern. The number is kept and not renumbered: the plan, the check
  scripts and any review cite AC numbers, and reusing AC3 for something else later would make two
  records disagree about what AC3 means.
- **AC4** Given two exports produced from two different layouts' logs, both of which recorded the
  same `session_id`, When a consumer reads both, Then it can tell that it is the same session and
  de-duplicate it — the session key survives into the export rather than being aggregated away.
  This is what makes the measured $83.52 over-count on four sessions detectable by a fleet view
  this repo does not ship.
- **AC5** Given the same log, When `make cost TSV=1` is run, Then it carries the same numbers and the
  same field names as the JSON, one header line plus one line per group, and pipes into `column -t` to
  give a legible table on a machine where nothing else is installed. `TSV=1` and `JSON=1` are the only
  two mode variables, and v1 takes no filter of any kind (decided 2026-09-27).
- **AC6** Given the release, When a check script under `skills/` is run, Then it asserts the export's
  schema version and every field name against fixture CSVs with known contents, and **fails on any
  departure from the expected field set — a rename, a removal or an addition** — because
  `check-log-schema.sh`'s mechanism reaches only writers inside this repo and a fleet consumer is
  outside it. And When the docs are read, Then one section names the export a **contract** and states
  the version rule decided 2026-09-27: the version is a plain integer starting at `1`; **adding** a
  field does not change it, while **renaming** a field, **removing** one, or changing what an existing
  one means does; a consumer must therefore ignore fields it does not recognise; and a rename is a
  breaking change for a consumer this repo cannot see.
  Note the two halves are deliberately not symmetrical, and this is the reconciliation of the version
  rule with the check that existed before it: an addition **fails the check** until someone updates its
  expected set, which is the deliberate gate, but it does **not** require a version bump, because a
  collector reading version `1` keeps working when a field it never reads appears. The check guards
  against accidental drift; the version communicates breakage.
- **AC7** Given one log and one set of options, When both `make cost` and `make cost JSON=1` are
  run, Then every number that appears in both is identical: the rendered table is a view over the
  exported structure, not a second implementation of the arithmetic.

### The rendered table

- **AC8** Given a repo with the layout and a `log.csv` holding rows, When `make cost` is run with
  no arguments, Then it prints token spend grouped by **task**, by **agent**, by **branch** and by
  **day**, reading `ai-factory/runs/log.csv` and no other file, and exits 0. Spend here means tokens
  and turns; no column of this table holds money (decision of 2026-09-27). And Given rows from more
  than one `tool`, Then any total drawn from them carries a footnote naming the contributing tools —
  which matters most on the by-agent table, where Codex attributes one session as both task and agent
  while Claude spreads across named agents.
- **AC9** Given that output, When it is read in an 80-column terminal, Then no line wraps. The default
  layout, decided 2026-09-27, is **four stacked tables — one per grouping: task, agent, branch, day —
  each carrying all seven metrics** (rows, turns, input, output, cache read, cache write, hit rate).
  Measured, that is a 12-character label column plus seven numeric columns, about 76 characters, so no
  metric is dropped and no two dimensions are folded into a composite key.
- **AC10** Given a layout whose `log.csv` is missing, holds only its header, or holds no row after
  the exclusions of AC14 and AC15, When `make cost` or `make cost JSON=1` is run, Then it says so
  explicitly, naming the file it read and the row count it found, and exits 0 — an empty table with
  no explanation reads as a broken feature. This is the case at the workspace root today, whose own
  log has zero rows and which inherits this target through its `ai.mk` include.
- **AC11** Given rows whose `task` is empty, or which carry no agent, When the report and the export
  are produced, Then those rows appear under an explicitly named bucket for unattributed spend, with
  their row count visible. They are neither dropped nor folded silently into another group's total.
- **AC12** Given the `accepted` column — hand-filled, and empty in all 19 rows measured — When the
  report is produced and **at least one row carries a value**, Then it states the column's **coverage**
  (how many rows carry one) rather than presenting an average over the few that do. And Given no row
  carries a value, Then no coverage line is printed at all (decided 2026-09-27): a permanent "0 of N"
  trains a reader to skip a line. The docs carry the standing fact instead — that the column is
  hand-filled and usually empty (AC20).
- **AC13** Given a `log.csv` containing a field that is quoted because it holds a comma or a
  newline, When either mode reads it, Then that record is counted once and in full: the reader is
  record-aware, not line-aware, as `records()` in `_log-schema.js` already is.

### Reading the log without guessing

- **AC14** Given rows whose field count is not the header's, When either mode runs, Then those rows
  are excluded from every total and their count is reported in the output. They are not
  reinterpreted into the columns that do exist, and the log is not rewritten to remove them.
- **AC15** Given rows written before spec 0007's collection change — cumulative snapshots of a
  session — When either mode runs, Then those rows are never added together as if they were per-run
  figures, and any that are reachable are excluded from every total with the output stating that
  they were and why. In the normal case they are not reachable at all: the accepted header break
  rotates every one of them into `ai-factory/runs/log.previous.csv`, and **the reader reads
  `log.csv` only** — it does not read, merge, reconcile or offer to include `log.previous.csv`, in
  either mode. A row that survives in `log.csv` — appended by an older writer after the rotation, or
  carried in by a merge — is excluded by the same rule. **The reader applies no repair heuristic to
  a cumulative row, in either file**: no maximum-per-session, no de-duplication by guesswork, no
  inference of the writer's semantics from a row's shape. Quarantine is where those rows stay;
  reading them later would reinterpret them, which is the thing `_log-schema.js` exists to refuse.
  What the reader sums from the current `log.csv` is deltas, because the writer defines them so —
  not because the reader decided it.
- **AC16** Given the release, When either mode is run, Then nothing under `ai-factory/runs/` is
  created, modified, moved or deleted: the target is read-only over the log, so running it can never
  cost a developer a row.

### Shipping it

- **AC17** Given the new script, When it is read, Then it requires only Node built-ins and its own
  siblings under `ai-factory/make/` — no `package.json`, no lockfile, no build step, no vendored
  library — so `ai-factory/AGENTS.md`'s "no new dependency without an ADR" is satisfied without one,
  `.claude-plugin/plugin.json`'s "no runtime dependency" stays true, and `node --check` passes on it
  as it does on every other script here.
- **AC18** Given the release, When `skills/ai-layout/templates/ai-factory/make/` is listed, Then the
  new script sits there beside `log.js` and `gate.js`; `ai.mk` declares a `cost` target and lists it
  in `.PHONY`; this repo's `ai-factory/make/` carries one further per-file symlink into the template
  (the directory is symlinks only — `ai-factory/docs/dont-touch.md` forbids editing it directly);
  and `node skills/ai-layout/scripts/manifest.js check <repo> <plugin>` reports a freshly adopted
  repo up to date, with the new file tracked in `ai-factory/.sdlc.json`.
- **AC19** Given a scratch repo that has just taken `/t4:adopt-sdlc`, When `make cost` is run in it,
  Then it behaves as AC10 requires for a header-only log — it is usable from the moment the layout
  lands, not only once rows exist.
- **AC20** Given the release, When the docs are read, Then `skills/ai-layout/SKILL.md`'s layout
  inventory lists the new file, `ai-factory/docs/workflow.md` gains a section telling a developer
  that `make cost` exists and what it can and cannot answer, and the CHANGELOG carries an entry.
  The docs state which dimensions are meaningful only for rows written by the 0007 collection
  change, and disclose what the log cannot see at all — per-plan-step cost, wall-clock, tool-call
  counts, lines changed, and Cursor, which has no local export of any kind. Three wordings are fixed by
  the decisions of 2026-09-27: **Cursor's absence is stated plainly in the same section that says what
  the report can answer**, not in a footnote, so nobody reads "spend by task" without learning what is
  missing from it; the `accepted` column is described as hand-filled and usually empty; and the export
  section states the integer version rule of AC6. The docs also record that this feature reports tokens
  and turns and never money, and why.
- **AC21** Given the release, When the new script and the `cost` target are inspected, Then neither
  reads, lists, walks or enumerates any directory outside the repo it runs in — one layout's log and
  nothing else. `ai-factory/designs/0001-layout-version-and-drift.md` §6 forbids this plugin from
  reaching into another repo, and the target the workspace root inherits through its `ai.mk` include
  must be the same single-layout target, not a walker.
- **AC22** Given the release, When the arithmetic is checked, Then a check script runs the
  aggregation over fixture `log.csv` files whose totals are known by construction — including a log
  with quoted fields (AC13), one with a wrong-width row (AC14), one with pre-0007 rows (AC15), one
  with empty and `~`-prefixed costs (AC3), one with empty `task` (AC11) and a header-only one
  (AC10) — and fails if any total departs from the expected value. The engine is therefore provable
  before a single real agent row exists.

## Out of scope
- **The HTML report (R2) — that is v2.** One self-contained `ai-factory/runs/report.html`, inline
  CSS, inline JSON, hand-rolled inline SVG for any chart, no CDN, no build, no server, written to
  disk and opened from disk. It is named here so the v1 script is written with a second renderer in
  mind, and it is specified in its own spec, not this one. Whether it is gitignored or committed is
  Open question 2 and must be answered before it is built.
- **The collection layer.** `ai-factory/specs/0007-subagent-stop-per-agent-accounting.md` owns the
  `SubagentStop` hook, the agent dimension, filling `task` for interactive sessions and making rows
  summable. Nothing here writes a row, changes `log.csv`'s header, or touches a hook.
- **The workspace fleet walker.** The third spec in exploration 0001's *Next*, and explicitly not
  this plugin's: `designs/0001` §6 — "ai-sdlc keeps no registry and never reaches into another repo
  … whoever wants a fleet-wide view collects it". Discovery of layout directories, nested layouts as
  peer rows, `session_id` de-duplication across logs, omitting the 22 never-adopted repos, listing
  adopted-but-empty layouts as "no data" and disclosing the coverage hole all belong there, in the
  workspace's own hand-written root `Makefile`. This spec's only obligation to it is AC4.
- **RS-001** (a local Next.js app, rejected) and **RS-002** (a `/t4:cost` task that has a model sum
  the CSV, not recommended). Kept in the exploration so they are not re-proposed.
- **Pricing.** `ai-factory/models.yaml`'s `pricing:` block and the exact-id → longest-prefix →
  `default` → built-in resolution already work and are not changed, moved or extended. Since the
  decision of 2026-09-27 the report does not read `cost_usd` at all — it neither prices nor reports
  money — so the writer's pricing path is untouched and unread by this feature rather than consumed
  by it.
- **Any source other than `ai-factory/runs/log.csv`.** Not the Claude Code transcripts under
  `~/.claude/projects/`, not `ai-factory/runs/*.json`, not `sessions.jsonl`, `edits.jsonl` or
  `cmds.jsonl` — that was option C, considered and not chosen as the primary route, and it depends
  on an undocumented directory layout and on files `clean-runs` deletes after 30 days.
- **Gateway accounting** (option D) and anything requiring a provider to be assumed.
- **Filling `accepted`.** It stays hand-filled at commit time; the report reports its coverage.
- **Changing what any `/t4:` command does.** No prompt, agent or slash command is added or altered.

## Open questions
A spec with open questions is not buildable. **Nine of the ten are now answered** — 1 on 2026-09-26,
the rest on 2026-09-27 — and the one that remains, 7, is explicitly not this spec's to answer: it asks
what a *fleet consumer* should do with a session that moved, and that choice belongs to the fleet spec.
Everything this spec builds is decided. Each answered question below keeps its original text struck
through with the decision beside it, so a later reader can see what was chosen and what it was chosen
over.

1. ~~**What does 0007 decide about the agent's carrier, and what does that make the export's field
   names?**~~ — **decided 2026-09-26 by the developer.** The agent name is a **17th `agent` column**
   in `log.csv`, not `claude/explorer` inside `tool`: encoding overloads a field the reader already
   parses and forces every consumer to split it. The header break this causes is **accepted**, and
   rows become **deltas** from 0007 onwards, with the existing cumulative rows quarantined by the
   header rotation into `log.previous.csv`. So the export's dimension names are frozen: agent and
   tool are two independent fields and no value is ever a composite (AC2), and the reader sums the
   current `log.csv` because the writer defines its rows as deltas (AC15). Nothing here is left for
   the plan to choose.
2. ~~**Is the generated HTML report (v2) gitignored or committed?**~~ — **decided 2026-09-27:
   gitignored, and the line lands in this release.** Exploration Q10. Gitignored keeps `runs/` clean and
   avoids leaking user, branch and spend data; committed would make it attachable to an MR without a
   rebuild, which is weak when the file is regenerable from a tracked `log.csv` by the target this spec
   adds — and `log.csv` already needed `merge=union` to survive two branches. Removing a committed
   report from a shared history later means a rewrite. The line goes into
   `skills/ai-hooks/SKILL.md`'s prescribed gitignore list now, before any `report.html` exists, even
   though R2 itself is v2.
3. ~~**Does the export carry money, or only tokens?**~~ — **decided 2026-09-27 by the developer:
   tokens only, and no money in the rendered table either.** On record: nine of the workspace's ten
   logs sit in layouts that may run different models, `cost_usd` is already `~`-marked or empty per
   row, and summing across layouts would mean summing prices set in ten separate `models.yaml` files;
   a fleet view applies one price list to the token counts instead. Pricing locally for the terminal
   only was considered and rejected, because a number in the table and absent from the export
   contradicts AC7. Consequences already written in: AC2's metric list is final and carries no cost
   field, **AC3 is withdrawn**, AC8 prints tokens and turns, and AC7 stands unchanged. Nothing here
   is left for the plan to choose.
4. ~~**What is the default aggregation of the rendered table?**~~ — **decided 2026-09-27: four stacked
   tables, one per grouping, each with all seven metrics.** AC9 required the default to fit 80 columns
   and deliberately did not choose; task × agent with the four token columns does not fit. The chosen
   layout measures ~76 characters, so it drops no metric. It was chosen over a single wide
   dimension/value table, which fits trivially but makes a reader reconstruct four groupings from one
   interleaved list — worse at the one thing the report exists for. The cost is vertical space: four
   tables rather than one.
5. ~~**What is the flag surface?**~~ — **decided 2026-09-27: `JSON=1` and `TSV=1`, no filters in v1.**
   Two booleans match `ai.mk`'s existing variable style. `FORMAT=tsv` was rejected because it cannot
   replace the `JSON=1` that AC1 already fixes, and carrying both would be two ways to say one thing.
   Filters are deliberately absent: one added later is cheap, while a field added to the export's
   contract later is not. A developer wanting a date window pipes the TSV through `awk` meanwhile. The
   cost: `make cost` always aggregates the whole log.
6. ~~**What version does the export start at, and what is its compatibility rule?**~~ — **decided
   2026-09-27: a plain integer starting at `1`; additions do not bump it, renames, removals and changes
   of meaning do; consumers ignore unknown fields; and yes, the first published document is read by
   whoever will write the fleet collector before it ships.** Semver was rejected as expressing nothing
   useful over a flat aggregate — either a consumer's field reads still work or they do not. See AC6 for
   the one asymmetry this creates: the check script fails on an addition even though the version does
   not move, because accidental drift and communicated breakage are different jobs.
7. **What does a fleet consumer do with a session that moved, now that rows are deltas?** The
   mechanism is no longer in doubt — deltas at write, cumulative rows quarantined by the header
   rotation (decided 2026-09-26) — so this is narrower than it was, and it is not a question about
   arithmetic. `aiDir()` still has no upward walk, so a session that changes working directory still
   writes some of its deltas into one layout's log and the rest into another's: the $83.52 over-count
   on four measured sessions is not created by cumulative rows alone, and deltas do not fix it.
   **AC4's obligation therefore stands unchanged** — the session key survives into the export so the
   overlap is visible. What is open is what the consumer should then *do*: exploration 0001
   recommends attributing the session to one layout and listing the others as "also touched", and
   says plainly that per-layout attribution of a session that moved is a choice, not a fact. That
   choice belongs to the fleet spec, but if this export is meant to make one attribution easier than
   another, say so before its field names are published (Open question 6).
8. ~~**Is `accepted` ever going to be filled?**~~ — **decided 2026-09-27: the coverage line appears only
   when at least one row carries a value, and the docs state that the column is hand-filled and usually
   empty.** Exploration Q9; the column is empty in all 19 rows measured. A permanent "0 of N" trains a
   reader to skip a line, which is worse than silence, while a line that appears only when the data does
   explains itself. The premise had also narrowed: cost-per-accepted-change was the ROI number that made
   the column worth filling, and this feature reports no money, so the most it could now offer is
   tokens-per-accepted-change. The cost: someone who starts filling the column gets no "it's working"
   signal until the first value lands.
9. ~~**Must the report be able to say a number is not comparable across tools?**~~ — **decided
   2026-09-27: a total whose rows span more than one `tool` carries a footnote naming the contributing
   tools.** Exploration Q5. Per-agent attribution is impossible for Codex by construction —
   `sync-adapters.sh` tells Codex to inline the agent in the same session, so one session is the task
   *and* the agent. The money half went moot with the tokens-only decision. The sums themselves stand,
   because a token is a token whichever CLI spent it; the footnote exists for the **by-agent** table,
   where Codex collapses into one bucket while Claude spreads across named agents, so a reader would
   otherwise compare a part against a whole. Rejected: marking such a total "not comparable", which
   claims a judgement the report cannot actually make. The cost: a reader who skips footnotes still
   mis-reads the agent table.
10. ~~**Cursor.**~~ — **decided 2026-09-27: "not measured" is accepted, stated plainly in the docs
    section that says what the report can answer.** Exploration Q6. Closing the gap needs the rejected
    option D, and nothing in the log's write path can see a tool that does not write to it; the
    alternatives were a Cursor-side integration this plugin does not own, or a guessed number, and a
    guess in a spend report is worse than a stated absence. The cost is real and is now on the record:
    if Cursor is in meaningful use, `make cost` is not a complete picture of spend and never will be,
    and anyone quoting it in a budget conversation needs to know that.

## Data touched
No models, no schema, no database — this repo is markdown prompts and Node scripts. What the
feature reads and writes:
- **Read:** `ai-factory/runs/log.csv` only, and only its documented columns — the 16 that exist today
  plus the 17th `agent` column 0007 adds (decided 2026-09-26), **except `cost_usd`, which this
  feature does not read at all** (decided 2026-09-27). Read-only, never rewritten (AC16).
  **Not read:** `log.previous.csv`, where the header rotation quarantines the old cumulative rows
  (AC15).
- **Written:** stdout. Nothing else in v1. R2's `ai-factory/runs/report.html` is still v2, but its
  gitignore line ships now (decided 2026-09-27), so no v2 run can commit it by accident.
- **New files:** one script under `skills/ai-layout/templates/ai-factory/make/`; one further per-file
  symlink under this repo's `ai-factory/make/`; one check script under `skills/`; fixture `log.csv`
  files for AC22; a new entry in every adopted repo's `ai-factory/.sdlc.json` as the manifest walks
  the template tree.
- **Edited:** `skills/ai-layout/templates/ai-factory/make/ai.mk` (the `cost` target and `.PHONY`),
  `skills/ai-layout/SKILL.md` (the inventory line), `ai-factory/docs/workflow.md`, `CHANGELOG.md`, and
  — following the decision of 2026-09-27 — `skills/ai-hooks/SKILL.md`, whose prescribed gitignore list
  gains `ai-factory/runs/report.html` now, ahead of the v2 file itself.
- **Unchanged by this spec:** `log.csv`'s header and column count — the 17th `agent` column and the
  rotation it triggers are 0007's change, not this one — `log.pending.csv`, `log.previous.csv`,
  `models.yaml`'s keys and pricing block, every hook script, every task prompt, every agent,
  and `.gitattributes`. **No longer on this list:** the prescribed gitignore list, which Open question 2
  moved into scope when it landed on "gitignored, now" — see *Edited* above.

## Routes touched
None — nothing serves a request and nothing runs as a service. The surface is one new make target,
`make cost`, in `ai-factory/make/ai.mk`, with a machine-readable mode selected by a variable (Open
question 5). No hook event is added or changed, and no `/t4:` command is added, removed or altered.
Note that the workspace root includes this same `ai.mk` and therefore inherits the target; AC10 and
AC21 are what make that inheritance harmless rather than misleading.

## Components likely involved
- `skills/ai-layout/templates/ai-factory/make/<cost>.js` — new; the aggregation engine, the export
  and the renderer. In the shape of `log.js` and `gate.js`: CommonJS, built-ins only, no build step
  (AC17). Reuses the quote-aware `records()`/`width()` reading that `_log-schema.js` already
  defines, which is where AC13 and AC14 come from — note that a template file cannot `require` the
  plugin's copy, the same constraint that forced `log.js` to hand-copy the guard and that
  `fixtures/check-log-schema.sh` exists to police.
- `skills/ai-layout/templates/ai-factory/make/ai.mk` — the `cost` target, `.PHONY`, and the variable
  that selects the machine mode. `RUNS` already points at `ai-factory/runs` (AC8, AC10, AC21).
- `ai-factory/make/` in this repo — one new per-file symlink into the template; the directory is
  dont-touch and holds symlinks only.
- A new check script beside `skills/ai-layout/scripts/check-*.sh` or
  `skills/ai-hooks/fixtures/check-*.sh` — the schema pin of AC6 and the arithmetic fixtures of
  AC22, modelled on `check-log-schema.sh`, which already pins a shape two writers share.
- Fixture `log.csv` files for AC22, beside the existing `skills/ai-hooks/fixtures/`.
- `skills/ai-layout/scripts/manifest.js` — no code change expected; it walks the template tree, so
  the new file becomes a tracked entry on its own. AC18 is what proves it.
- `skills/ai-layout/SKILL.md` — the layout inventory (AC20).
- `ai-factory/docs/workflow.md` — the new section, and the honest statement of what the report
  cannot answer (AC20). §9 already describes what the hooks record; 0007 rewrites its under-count
  paragraph, and this spec adds the reading surface beside it.
- `CHANGELOG.md` — one entry. Not breaking: nothing is removed and no schema moves. An adopted repo
  that takes the update gains a target it did not have.
- `ai-factory/explorations/0001-token-consumption-by-task-and-agent.md` — the source of record for
  every measured figure quoted above; not edited by this work.
