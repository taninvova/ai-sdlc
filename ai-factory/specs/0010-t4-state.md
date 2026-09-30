# 0010 — `/t4:state`: list the repo's outstanding specs and plans

Summary: one plugin command, `/t4:state`, that prints a table of the work still outstanding in this
repo — the specs under `ai-factory/specs/` and the plans under `ai-factory/plans/` — each outstanding
plan shown with its steps rather than as a bare title. With no argument it lists what is incomplete;
`--done` and `--next` narrow or shift that listing. It is read-only, prints to the terminal only, and
is backed by a deterministic script so two runs over the same tree agree.

## What is there today

Facts, established by reading the repo:

- **`commands/`** holds five plugin-level commands — `adopt-sdlc, doctor, migrate-layout,
  setup-tracker, sync-sdlc`. These exist in every repo, with or without an `ai-factory/` layout; the
  twelve project tasks under `ai-factory/tasks/` only exist once a repo has adopted. Spec 0002 Open
  question 3 settled `/t4:doctor` as a plugin command for exactly that reason, and `/t4:state`
  follows it.
- **`ai-factory/tasks/`** holds twelve prompt files — `adr, analyse, check, chore, design, explore,
  fix, fleet, plan, run, spec, test`. Each is a symlink into
  `skills/ai-layout/templates/ai-factory/tasks/`, each becomes `/t4:<name>` via
  `ai-factory/make/sync-adapters.sh`, and `ai-factory/tasks/` is on `ai-factory/docs/dont-touch.md`.
  These are *prompts*, not units of work, and none has a completion state — they are not what
  `/t4:state` lists.
- **Steps live in plans.** `ai-factory/plans/<NNNN>-<slug>.md` carries `- [ ] Step N — …` lines,
  written by the `planner`, sized for one `/t4:run`, and ticked to `- [x]` by the `implementer` only
  when lint, typecheck and tests are green.
- **`- [~]` is a hand-written, undocumented marker that means "partly done".**
  `ai-factory/tasks/plan.md` and `run.md` define only `- [ ]` and the tick; nothing in the repo
  writes or reads `- [~]`. It occurs twice — `ai-factory/plans/done/0003-tracker-setup.md` Step 2 and
  `ai-factory/plans/done/0004-knowledge-seam.md` Step 5 — and both occurrences sit directly above a
  `**Result — … proved; … outstanding.**` block, so the marker means "step partly done: some
  acceptance criteria proved, some outstanding". `/t4:state` therefore treats a `- [~]` step as not
  complete. The two plan files are not edited by this feature.
- **`ai-factory/plans/` is empty but for `done/`.** Six plans — 0001–0006 — sit in
  `ai-factory/plans/done/`, and every one of their 48 checkboxes is `[x]` or `[~]`; not one `- [ ]`
  remains anywhere in the repo. So on today's tree the only incomplete plan steps are the two `- [~]`
  ones, both inside filed plans.
- **Two specs have no plan.** `ai-factory/specs/0008-make-cost-report-and-export.md` and
  `0009-remove-serena.md` exist (both untracked on `main` as of this spec) with no counterpart in
  `ai-factory/plans/`, and both carry unanswered Open questions, which `ai-factory/docs/workflow.md`
  says makes a spec unbuildable. Spec numbers run 0001–0006 then 0008–0010; **0007 is absent**, so
  the spec/plan number is not a dense sequence and no scan may assume it is.
- **`/t4:doctor` is the read-only reporting precedent.** `commands/doctor.md` drives
  `skills/ai-layout/scripts/doctor.sh`; spec 0002 fixes that it writes nothing (AC1), reports
  `unknown` with a reason rather than failing when a check cannot be answered (AC12), behaves
  identically headless (AC10), and says so in one line when there is nothing to report (AC11).
  `/t4:state` is built the same way: a prompt over a deterministic script.
- **A new plugin command is a template change.** Adding a file under `commands/` means regenerated
  `.claude/`, `.cursor/` and `.codex/` adapters, a `ai-factory/.sdlc.json` manifest entry in every
  adopted repo, a CHANGELOG entry and a version bump — `ai-factory/AGENTS.md`: *"Template changes are
  breaking for every adopted repo."*
- **No existing surface reports across plans.** Nothing in `commands/`, `ai-factory/tasks/`,
  `skills/ai-layout/scripts/` or `skills/ai-layout/templates/ai-factory/make/` reads more than one
  plan. The nearest existing behaviour is one sentence at the end of `ai-factory/tasks/run.md` —
  *"Name the unticked steps if the plan is obvious — do not start one on your own."* — a fallback for
  a bare `/t4:run` over a single plan the session has already identified, not a command of its own.

## User story

As a developer returning to this repo after time away, I want one command that lists the work still
outstanding together with the steps each piece is made of, so that I can see what is left and pick
the next step up without opening every file under `ai-factory/` to reconstruct it.

## Acceptance criteria

- **AC1** Given the plugin is available in a repo, When the developer types `/t4:state`, Then the
  command exists under that exact name, is invocable with no argument, no path and no number, and
  runs to completion. The name is `state`; no other spelling is provided and no existing command
  gains a mode.
- **AC2** Given a repo with specs under `ai-factory/specs/` and plans under `ai-factory/plans/`
  (including `ai-factory/plans/done/`), When `/t4:state` runs with no argument, Then every spec and
  every plan that is not yet complete appears in the output exactly once, and nothing else is listed.
  The prompt files under `ai-factory/tasks/` are never listed.
- **AC3** Given an item in the output, When the listing is read, Then the item is identified by its
  repository-relative artefact path, and an outstanding plan is accompanied by its step-level
  detail — each incomplete step's identifier and its one-line description. A plan entry carrying only
  a title and no steps does not satisfy this criterion.
- **AC4** Given an item that is complete, When `/t4:state` runs with no argument, Then that item does
  not appear in the output at all — not struck through, not greyed, not shown with a done marker.
  "Not started yet" and "part done" are what the default listing shows.
- **AC5** Given a repo with at least one complete item, When `/t4:state --done` runs, Then the
  complete items appear in the output, each identified by path, in the same table shape as the
  default listing.
- **AC6** Given a repo with outstanding work, When `/t4:state --next` runs, Then the output is a
  strict subset of the default listing — never an item the default listing omits — and the command
  states in one line which item it selected and why.
- **AC7** Given any invocation of `/t4:state` that has something to list, When the output is read,
  Then it is a table: one row per listed item or step, a header row naming the columns, and the same
  columns in the same order for every row. Prose paragraphs in place of rows do not satisfy this
  criterion.
- **AC8** Given `/t4:state` runs, When the filesystem is compared before and after, Then no file has
  been created anywhere — no report, no cache, no export. The listing exists only as terminal output
  in the session that ran it.
- **AC9** Given `/t4:state` runs, When the working tree is compared before and after, Then no file
  under `ai-factory/` or anywhere else is edited or deleted, no checkbox is ticked or unticked, and no
  plan is moved between `ai-factory/plans/` and `ai-factory/plans/done/`.
- **AC10** Given a plan step written `- [~]`, When `/t4:state` runs with no argument, Then that step
  is listed as incomplete and its plan appears in the default listing. A plan whose every step is
  `- [x]` except one `- [~]` is outstanding, not done.
- **AC11** Given a repo where nothing matches the requested listing, When `/t4:state` runs, Then it
  exits successfully and says so in one line. An empty result is a valid answer, not an error and not
  silence.
- **AC12** Given an artefact the command cannot read or cannot interpret — an unreadable file, a
  malformed plan, a step line in a shape no rule covers — When `/t4:state` runs, Then that artefact is
  reported as unknown together with the reason, every other artefact is still listed, and the
  unreadable one is never reported as complete.
- **AC13** Given the same tree, When `/t4:state` runs twice with no change in between, Then both runs
  produce the same rows in the same order. The listing is derived from artefacts on disk, never from
  the session's memory of earlier chat, and a headless run agrees with an interactive one.
- **AC14** Given the command's implementation, When it produces the listing, Then the scan, the
  completeness decision and the row data come from a deterministic script under
  `skills/ai-layout/scripts/`, invoked the way `commands/doctor.md` invokes `doctor.sh`; the prompt
  presents the script's output and does not itself infer which items are outstanding.
- **AC15** Given a workspace of sibling repos, When `/t4:state` runs in one of them, Then it reads
  only paths inside that repo. No sibling repo is read and no aggregate is produced.
- **AC16** Given an adopted repo that syncs to the release carrying this feature, When the sync
  completes, Then `/t4:state` is available there: the command ships in `commands/`, the generated
  `.claude/`, `.cursor/` and `.codex/` adapters include it, `ai-factory/.sdlc.json` lists it, the
  command tables in `ai-factory/docs/workflow.md` name it, and `CHANGELOG.md` and the plugin version
  record the change.

- **AC17 — withdrawal correction (2026-09-29).** Given an unchecked or partly done numbered
  step and an explicit `**Result — Step N withdrawn; …**`, `**Result — Step N withdrawn.**`,
  or `**Result — Step N withdrawn**` record in that plan (optionally `is withdrawn`, as in
  plan 0009), When the listing runs, Then that
  step is resolved without changing its checkbox and is omitted from default and `--next`.
  The record must be an ordinary line with at most three leading spaces, outside fenced code;
  quoted examples, indented code, conditional prose and different step numbers do not qualify.
  If every other step is ticked or withdrawn, `--done` lists the plan as `closed`, with a
  withdrawal explanation, rather than claiming it is `complete`. A spec whose paired plans
  are all complete or closed inherits `closed` if any plan is closed. Another pending or
  unknown paired plan still takes precedence. A closed state describes the recorded work;
  it does not prove acceptance criteria or answer remaining spec questions. Malformed steps
  remain unknown, and the archived records remain byte-identical.

AC17 refines “incomplete” in AC2–AC3 and AC10 to exclude explicitly withdrawn steps, and
extends AC5 to closed items. It resolves the withdrawn-step case only: blocked, deferred,
or merely not-run work without the numbered result above remains pending. A withdrawal
record must be removed or corrected if the step is reopened; the scanner does not interpret
later free-form prose as a status change.

## Out of scope

- **Doing any of the listed work.** `/t4:state` lists; it never starts a step, never invokes
  `/t4:run`, and never ticks a box. AC9 is what holds that line. Even `--next`, which names the item
  to pick up, does not pick it up.
- **Changing how steps are written or ticked.** `ai-factory/tasks/plan.md` keeps prescribing
  `- [ ] Step N — …` and `run.md` keeps owning the tick.
- **Documenting or standardising `- [~]`.** This spec records what the marker means today and fixes
  how `/t4:state` counts it (AC10). Adding it to `ai-factory/tasks/plan.md` as prescribed notation is
  a separate change.
- **Editing the two filed plans that contain `- [~]`.** `ai-factory/plans/done/0003-tracker-setup.md`
  and `0004-knowledge-seam.md` are the record of past runs and stay byte-identical.
- **Writing a report file, an export, or a machine-readable mode.** AC8 is terminal output only. A
  JSON or CSV form, and any `make` target that consumes one, is a later feature.
- **Anything about tickets, keys or trackers.** No ticket key was resolved for this request and this
  repo carries no `ai-factory/docs/tracker.md`; the listing is built from repo artefacts only.
- **Cross-repo or fleet-wide reporting.** AC15 keeps it to one repo, and
  `ai-factory/docs/architecture.md` is explicit that this plugin never reads another repo.
- **Cost, token or time reporting.** `ai-factory/runs/log.csv` and the `make cost` work specified in
  `ai-factory/specs/0008-make-cost-report-and-export.md` are a separate surface; `/t4:state` reports
  outstanding work, not spend.
- **Estimating, prioritising or scheduling.** No effort figures, no assignee, no importance ordering
  beyond whatever `--next` selects.
- **Shipping as a project task.** `/t4:state` is a plugin command; no file is added under
  `skills/ai-layout/templates/ai-factory/tasks/`.

## Open questions

Four details remain unsettled. None of them blocks the ACs above, but each must be decided before
the command's output is fixed.

1. **What exactly does `--next` select?** AC6 fixes only that it returns a subset of the default
   listing and explains its choice. The rule itself is open: the lowest-numbered outstanding plan's
   first incomplete step, the lowest-numbered spec with no plan, the most recently modified artefact,
   or the first row of the default listing whatever that is.
2. **What are the table's columns?** Candidates: artefact path, number, kind (spec or plan), state,
   step identifier, step description, the command to run next. Which of these appear, in what order,
   and whether a spec row and a plan-step row share one column set or the table is sectioned by kind.
3. **Does `--done` replace the default listing or add to it?** Either it shows complete items instead
   of incomplete ones, or it widens the listing to everything with the state shown per row. AC5
   requires only that complete items appear.
4. **Do the filters combine?** Whether `/t4:state --done --next` is meaningful, an error, or
   silently equivalent to one of them, and whether any future filter is expected to compose with
   these two.

## Data touched

No models, no fields, no schema, no database — this repo is markdown prompts and Node/bash scripts.
What the feature touches:

- **Read:** `ai-factory/specs/*.md` (their numbers, titles and `## Open questions` sections) and
  `ai-factory/plans/**/*.md` including `ai-factory/plans/done/` (their `- [ ]`, `- [x]` and `- [~]`
  step lines, and the `**Goal:**` and `**Spec:**` lines each plan opens with). **Not read:**
  `ai-factory/tasks/*.md`, which are prompts with no completion state, and `ai-factory/runs/` —
  that is spend, not outstanding work, and the directory is dont-touch.
- **Written:** nothing. AC8 forbids any new file; the listing is terminal output only.
- **New files:** `commands/state.md` — the prompt — and one deterministic script beside
  `skills/ai-layout/scripts/doctor.sh` that does the scan (AC14), plus a `check-*.sh` with plan and
  spec fixtures to pin the completeness rules, `- [~]` included.
- **Edited, because a new plugin command is a template change:** `skills/ai-layout/SKILL.md` (the
  inventory), `ai-factory/docs/workflow.md` (§3 which-command, §5 the command table, §11 the short
  version), `CHANGELOG.md`, `.claude-plugin/plugin.json` version, and — regenerated, never
  hand-edited — `.claude/commands/t4/`, `.cursor/rules/`, `.codex/skills/` via
  `ai-factory/make/sync-adapters.sh`.
- **Unchanged:** the plan/step notation itself, `ai-factory/tasks/plan.md` and `run.md` as behaviour,
  the filed plans under `ai-factory/plans/done/`, every hook script, `log.csv`'s columns, and
  `ai-factory/docs/dont-touch.md`.

## Routes touched

None. Nothing here serves a request and nothing runs as a service
(`ai-factory/docs/architecture.md`: "Nothing runs as a service"). The surface added is one developer
entry point — the `/t4:state` slash command — reaching the same three adapters `sync-adapters.sh`
generates for Claude Code, Cursor and Codex. No hook event is added or changed, and no existing
command's behaviour changes: `/t4:doctor` and `/t4:run` are untouched.

## Components likely involved

- **`commands/state.md`** — the prompt, in the shape of `commands/doctor.md`: front-matter
  `description:` and `allowed-tools: Bash, Read`, an explicit change-nothing instruction, one step
  that runs the script with `"${CLAUDE_PLUGIN_ROOT}"`, and instructions for presenting the rows as a
  table. Its `description:` is what `sync-adapters.sh` lifts into every adopted repo's command menu,
  so it is part of the deliverable.
- **`skills/ai-layout/scripts/` — a new script beside `doctor.sh`** that walks
  `ai-factory/specs/*.md` and `ai-factory/plans/**/*.md`, classifies each item and each step, emits
  one row per listed thing, reports unreadable artefacts as unknown with a reason (AC12), and always
  exits 0. Precedent for parsing repo files with no build step: `doctor.sh`, `manifest.js`,
  `rewrite-paths.js`; the make-side `log.js` and `gate.js` are CommonJS with built-ins only.
- **`skills/ai-layout/scripts/check-adapters.sh`** — asserts prompt invariants today and is where
  `commands/state.md`'s invariants get pinned; **`check-manifest.sh`** and
  **`skills/ai-layout/scripts/manifest.js`** see any new template file as drift for adopted repos, so
  both must be updated for AC16.
- **`ai-factory/docs/workflow.md`** — §3, §5 and §11 each enumerate the commands; a command absent
  from those tables is invisible to the developer it is for.
- **`ai-factory/make/sync-adapters.sh`** (template:
  `skills/ai-layout/templates/ai-factory/make/`) — picks new command files up by glob; a change is
  needed only if `/t4:state` requires adapter wording of its own. `ai-factory/make/` in this repo
  holds symlinks and is dont-touch.
- **`ai-factory/agents/`** — none. Listing is a read of repo files behind a deterministic script, not
  a judgement, so no subagent is implied and nothing is delegated.
