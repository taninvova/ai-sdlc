# Plan 0009 — Remove `.serena`

**Goal:** Confirm on the record that `.serena/` is gone from this repo's working tree and that its
removal changed nothing tracked — because the deletion itself has already happened by hand, and every
further thing the spec reaches is either blocked on an unanswered open question or lives outside any
path `/t4:run` may write.

**Spec:** [`ai-factory/specs/0009-remove-serena.md`](../../specs/0009-remove-serena.md)

## Before anything else: read this, then decide whether to run it at all

**Four of the spec's five open questions are unanswered, and the one thing that was buildable is
already built.** `.serena/` was deleted by hand — `rm -rf .serena` — before this plan was written. The
directory is absent, nothing under it was ever tracked, so the deletion produced no diff and there is
nothing to commit. **AC1, AC2, AC3, AC4 and AC5 are all true on the tree as it stands right now**, and
each was checked for this plan (the commands are in *Verification*, and each was run verbatim before
being written down).

That leaves a plan with **no file change the spec permits**. The reasoning, so it does not have to be
redone:

- **AC4 says `.gitignore` is the only tracked file that may differ, "and it differs only if Open
  question 2 says it should."** Open question 2 is unanswered. So the one tracked edit in play cannot
  be made — planning it either way would encode a guess. See Ambiguity Q2.
- **No new check can be added either.** A check asserting `.serena/` stays absent would be a new file
  under `skills/`, which is a tracked file other than `.gitignore` — AC4 forbids it — and per the
  spec's *Out of scope* the change carries "no CHANGELOG entry and no manifest version bump", which
  `check-versions.sh` and `check-release-docs.sh` would then require. **AC5 can therefore be observed
  but never enforced.** That is the spec's own choice, not an oversight in this plan.
- **Open questions 1 and 5 are outside every path this repo can write.** See *What cannot be planned
  here*.

**So the honest recommendation is that this spec is closed as done-by-hand, not run.** Step 1 below
exists for the developer who wants the closure written down rather than taken on trust; it is a
read-and-record step that touches this plan file and nothing else. Step 2 exists only to name what
would follow if Open question 2 is answered, and must not be run before it is.

## The state this plan starts from

Established by reading the repo on 2026-09-28, **after** the deletion. Where this disagrees with the
spec's *What is there today*, the spec is stale or wrong and this section is what holds:

- **`.serena/` is absent.** `test -e .serena` fails. The working tree is clean and `main` is level
  with `origin/main` (`git rev-list --left-right --count origin/main...HEAD` → `0 0`).
- **Nothing under `.serena/` was ever tracked.** `git ls-files .serena` and `git log -- .serena` are
  both empty, so the deletion is invisible to git — there is no commit to make for it.
- **The `.gitignore` rule survives, at lines 21–24, not 18–21.** Lines 21–23 are the three-line
  comment, line 24 is `.serena/`. **The spec's line numbers are wrong**: lines 15–19 are the
  `.claude/settings.json` rule and its four-line comment, which is what the Serena comment refers back
  to ("a personal choice, like `.claude/settings.json` above"). The spec's "`.gitignore` line 21
  ignores it" is likewise line 24.
- **That surviving comment already answers part of Open question 1.** It states as standing fact that
  Serena "regenerates the directory on activation, so nothing is lost by not sharing it". So the repo's
  own recorded position is that deletion is *not* permanent and does not need to be.
- **`.serena/` has not regenerated yet — which proves nothing.** No Serena tool has been called in
  this repo since the deletion. The comment above says what happens when one is. Absence today is not
  evidence of absence tomorrow, and no step below may treat it as such.
- **All thirteen `check-*.sh` pass on this tree, run directly.** Nine under
  `skills/ai-layout/scripts/`, four under `skills/ai-hooks/fixtures/`. AC3 is already satisfied; the
  baseline is green, so any later failure is attributable.
- **`check-entrypoints.sh` asserts six `.gitignore` lines, not five, and not the five the spec
  names.** Its `IGNORE` array is `ai-factory/runs/*.json`, `ai-factory/runs/*.jsonl`,
  `ai-factory/runs/log.pending.csv`, `ai-factory/runs/.counted.*`, `ai-factory/runs/.task.*`,
  `ai-factory/runs/report.html`. The spec's *Components likely involved* lists
  `.claude/settings.local.json` and `CLAUDE.local.md` among the asserted lines — those two are
  prescribed by `skills/ai-hooks/SKILL.md` and present in `.gitignore`, but the script does **not**
  assert them — and omits `.counted.*`, `.task.*` and `report.html`, which it does. The correction does
  not change AC3's outcome: none of the six is the Serena rule, and all thirteen checks pass either
  way.
- **`ai/sdlc` is *not* the only repo in the workspace with a `.serena/`.** Seven siblings have one:
  `libs/ui-components`, `infra/mayhem`, `infra/fleet`, `webapp/clients`, `webapp/storefront`,
  `webapp/console`, `svc/pricesync-svc`. Two of them — `infra/mayhem` and `infra/fleet` — have paths
  under `.serena/` **tracked in git**, which is a materially different and worse situation than the one
  this spec describes, and three (`infra/fleet`, `webapp/console`, `svc/pricesync-svc`) carry no
  gitignore rule for it. **The spec's claim to the contrary is false, and it is the premise Open
  question 3 rests on.** None of it is in this plan's reach — each is its own git repo.
- **The Serena MCP server is a top-level `mcpServers` entry in `/Users/tanin/.claude.json`** — the
  developer's machine-wide Claude Code config, not scoped to any project. There is no `.mcp.json` in
  this repo, none at the workspace root, and no mention of Serena anywhere under `.claude/` here. The
  repo cannot detach it, and as configured there is not even a per-project attachment to detach.
- **Remaining mentions of Serena in this repo, and what each is:**

  | Path | What it is | Editable here? |
  | --- | --- | --- |
  | `.gitignore` lines 21–24 | **A live rule.** The only tracked text this spec may touch | Only once Open question 2 is answered (AC4) |
  | `ai-factory/specs/0009-remove-serena.md` | This spec | **No** — the planner never writes `ai-factory/specs/` |
  | `ai-factory/specs/0010-t4-state.md` line 39 | A live spec's *factual* statement about this one | **No** — same rule, and it is another feature's spec |
  | `ai-factory/plans/done/0006-ai-factory-layout.md` lines 148, 177 | **Historical record** of the 0006 run | **No** — spec *Out of scope*; must stay byte-identical (AC4) |
  | `ai-factory/runs/0006-live-runs.md` lines 51, 67, 70 | **Historical record**, and `ai-factory/runs/` is on `ai-factory/docs/dont-touch.md` | **No** — the `guard-paths` hook exits 2 on any write |

- **Open question 4 is now moot and cannot be answered by action.** It asks whether anything in
  `.serena/` was wanted before it went. The directory is already gone, and with it `project.yml` and
  the settings it carried (`project_name`, `language_servers`, `ignore_all_files_in_gitignore`). The
  spec judged nothing was lost; that judgement is now irreversible either way. Recorded, not planned.

## Files to create / modify

| File | Why |
| --- | --- |
| `ai-factory/plans/0009-remove-serena.md` | **This file.** Step 1 appends its `**Result — …**` block and ticks its box, the way `ai-factory/plans/done/0003-tracker-setup.md` and `0004-knowledge-seam.md` carry theirs. It is the only file Step 1 may touch. |

**Nothing else.** Specifically not touched, and each for a stated reason:

- **`.gitignore`** — blocked on Open question 2 (AC4). Step 2 only.
- **`ai-factory/plans/done/0006-ai-factory-layout.md`** and **`ai-factory/runs/0006-live-runs.md`** —
  historical records; AC4 requires them byte-identical, the spec puts them out of scope, and the second
  is under `ai-factory/docs/dont-touch.md`.
- **`ai-factory/specs/*.md`** — the planner and the implementer do not write specs. Spec 0010's
  statement about this spec is a matter for whoever next revises 0010.
- **Anything under `skills/`** — no new check, no template change; see the reasoning above.
- **`CHANGELOG.md`, `.claude-plugin/plugin.json`, every manifest** — the spec's *Out of scope* is
  explicit that no CHANGELOG entry and no version bump follow. `check-versions.sh` and
  `check-release-docs.sh` pass today with no bump, which confirms none is owed.
- **`~/.claude.json` and anything else under the developer's home** — not repo content, and not a path
  any `/t4:*` task writes.
- **Every sibling repo in the workspace** — each is its own git repo;
  `ai-factory/docs/architecture.md` is explicit that this plugin never reaches into another repo.

## Server vs client components

**Does not apply.** This repo is a Claude Code plugin — markdown prompts, bash and Node hook scripts.
`ai-factory/docs/architecture.md`: "Nothing runs as a service." There is no React tree, no rendering
boundary and no `"use client"` anywhere, so there is no server/client split to decide. The section is
kept only so its absence is visibly deliberate rather than forgotten.

## Steps

- [x] **Step 1 — Verify the removal and record it in this plan.** Run the eight assertions in
  *Verification* from the repo root, in order, and append a `**Result — …**` block to this plan naming
  what each returned, then tick this box. **Change no other file.** If every assertion passes, the
  block says so and the plan is filed to `ai-factory/plans/done/`; the spec is then closed as
  done-by-hand, with Open questions 1, 2, 3 and 5 recorded as still open and *not* resolved by the
  filing. If any assertion fails — most likely #1, because a Serena tool was called in the interval —
  the block records which, and **stops**: a regenerated `.serena/` is Open question 1, and deleting it
  a second time without an answer just restarts this loop.
  *Proved by:* assertions #1 (AC1), #2 and #3 (AC2), #5 — all thirteen `check-*.sh` exiting 0 (AC3),
  #6 and #7 (AC4), #1 and #4 together (AC5). No new test is written; per
  `ai-factory/docs/coding-standards.md` this repo has no test runner and proves behaviour by running
  the checks and recording the run.

  **Result — AC1, AC2, AC3, AC4 and AC5 proved on the tree as it stands; spec Open questions 1, 2, 3
  and 5 outstanding.** Run on 2026-09-28 from the repo root, in the order of
  *Verification*, each command verbatim and none of them piped. No Serena tool was called at any
  point in this run.
  **#1 (AC1) pass:** `! test -e .serena` exited 0, and `ls -a` at the root shows no `.serena` entry.
  The directory is absent and has not regenerated since the hand deletion.
  **#2 (AC2) pass:** `git ls-files .serena` printed nothing; the `test -z` around it exited 0.
  **#3 (AC2) pass:** `git log --oneline -- .serena` printed nothing; the `test -z` exited 0. The
  deletion is invisible to git, so there is no deletion of a tracked file to record and nothing to
  commit for it.
  **#4 (AC5, with #1) pass:** `git status --porcelain` printed exactly one line,
  `?? ai-factory/plans/0009-remove-serena.md` — the documented pre-commit state. No `?? .serena/`
  line, so R1 did not fire. Run again after #5 and identical, which also shows the thirteen checks
  leave no residue in the tree.
  **#5 (AC3) pass:** the loop over `skills/ai-layout/scripts/check-*.sh` and
  `skills/ai-hooks/fixtures/check-*.sh` printed no `FAIL` line. The globs matched thirteen scripts,
  nine and four, as this plan's *state* section records.
  **#6 (AC4) pass:** `git diff --stat origin/main...HEAD --` over
  `ai-factory/plans/done/0006-ai-factory-layout.md` and `ai-factory/runs/0006-live-runs.md` printed
  nothing. Both historical records are byte-identical to `origin/main`; neither was opened for
  writing, and R3 did not fire.
  **#7 (AC4) pass, with the caveat this plan already states:** `git diff --name-only
  origin/main...HEAD` printed nothing — the documented result for uncommitted Step 1. It is silent
  about this plan file, which is still **untracked**, so the assertion on its own cannot show that
  this file is the only thing that differs; #4 is what establishes that, and the two must be read
  together exactly as the comment in *Verification* says. `git rev-list --left-right --count
  origin/main...HEAD` reported zero ahead and zero behind, so the comparison was made against a
  level branch.
  **#8 pass:** `grep -n '^\.serena/$' .gitignore` returned `24:.serena/`. The rule is left exactly
  as it was, at line 24, under the three-line comment at lines 21–23 — confirming this plan's
  correction and **not** the spec's "lines 18–21".

  **What this filing does not settle.** Spec Open question 1 (is "remove" the deletion, or ceasing to
  run Serena here), **2** (do `.gitignore` lines 21–24 go with the directory — the only question that
  gates a file edit, and what blocks Step 2), **3** (is `ai/sdlc` the whole scope — asked on this
  plan's corrected facts, since seven sibling repos also carry a `.serena/` and two track paths under
  it) and **5** (detaching the MCP server, which is machine-wide in the developer's own config) are
  **all still open, and none is resolved by filing this plan.** Open question 4 is moot and stays
  moot: `.serena/project.yml` was already gone before this run. **AC5 is proved only as an
  observation of this moment, never as a guarantee** — the `.gitignore` comment at lines 21–23 states
  that the directory returns on activation, and nothing in this repo can prevent that. **Step 2 was
  not run and its checkbox is untouched:** Open question 2 has no written answer, and neither branch
  of it was chosen.

- [ ] **Step 2 — BLOCKED. Do not run until Open question 2 is answered in writing.** The question is
  whether `.gitignore` lines 21–24 go with the directory. Both answers are live changes and this plan
  picks neither:
  - *Answer "keep the rule":* Step 2 is **withdrawn**, no file changes, and Step 1 is the whole plan.
  - *Answer "remove the rule":* delete lines 21–24 (the three-line comment and `.serena/`) from
    `.gitignore`, leaving lines 1–20 byte-identical. *Proved by:* `bash
    skills/ai-layout/scripts/check-entrypoints.sh` exiting 0 — it re-asserts all six prescribed
    `ai-factory/runs/*` lines plus the `.gitattributes` line, so a delete that overshoots fails it —
    and `git diff --name-only origin/main...HEAD` naming `.gitignore` and nothing else (AC4). Note the
    consequence the spec already states: from then on a regenerated `.serena/` shows as `?? .serena/`
    in every `git status`, which is exactly the condition that refused the 0006 run recorded in
    `ai-factory/runs/0006-live-runs.md`.

  An implementer that reaches this step with no written answer **stops and reports**. It does not pick
  the tidier-looking option, and it does not read the answer out of the surviving comment — that
  comment explains why the rule exists, not whether it should be removed.

  **Result — Step 2 is withdrawn; not run, and no file changed.** Recorded 2026-09-28. The developer
  answered spec 0009's Open question 2 in writing: **keep the rule.** That is the first branch above,
  and by its own text Step 2 is then **withdrawn**, no file changes, and Step 1 is the whole plan. The
  box stays unticked because there was never anything to run on this answer — not because work is
  outstanding. `.gitignore` is untouched: 24 lines, the three-line comment at 21–23 and `.serena/` at
  line 24, exactly as Step 1's assertion #8 recorded it. **Open question 2 is answered and closed by
  this block** — Step 1's result block above records it as open, which it was on the day Step 1 ran;
  this is the later answer and supersedes it on that one question only. **Spec Open questions 1, 3
  and 5 remain open** and question 4 stays moot: the withdrawal resolves question 2 and nothing else.

## What cannot be planned here, and why

Named so nobody writes a step for it and so `/t4:run` does not try:

- **Open question 1, "stop using Serena here", and Open question 5, "detach the MCP server".** The
  server is a top-level `mcpServers` entry in `/Users/tanin/.claude.json` — the developer's own
  machine config, outside this repo and outside the workspace. No `/t4:run` step can reach it, no file
  in this repo can override it, and because the entry is machine-wide rather than project-scoped there
  is no per-project attachment to remove. **This is the developer's action, at their tool level, and it
  is what decides whether Open question 1's answer holds at all.** The spec already puts it out of
  scope; this plan agrees and adds that it is not merely out of scope but unreachable.
- **A repo-side guarantee that `.serena/` stays gone.** There is none, by the spec's own construction:
  the only mechanisms would be a new check file (forbidden by AC4) or a hook (a template change the
  spec's *Out of scope* rules out). What the repo *can* do it already does — the `.gitignore` rule
  keeps a regenerated directory from dirtying the tree. Whether that is enough is Open question 2.
- **Editing the two historical records.** `guard-paths` exits 2 on any write under
  `ai-factory/runs/`, and it should; `ai-factory/plans/done/0006-ai-factory-layout.md` is not guarded
  but is out of scope and covered by AC4. A block here is a finding to report, never something to route
  around by a different tool.
- **Anything in the seven sibling repos.** Each is its own git repo. That two of them **track** paths
  under `.serena/` is a real problem and a worse one than this spec's, but it is a separate spec in a
  separate repo — and Open question 3, which asks whether the scope widens, is unanswered.

## Ambiguities — each as a question the developer can answer directly

Every one is the spec's own Open question, restated so it can be answered in one line, with what it
blocks. **None is resolved in this plan.**

1. **Should the three-line comment and the `.serena/` rule at `.gitignore` lines 21–24 be deleted, or
   kept?** *Blocks:* Step 2, and therefore whether this change has any tracked diff at all. This is the
   only question that gates a file edit. (Spec Open question 2; note the spec's line numbers are wrong
   — they are 21–24, not 18–21.)
2. **Is deleting the directory the whole of "remove `.serena`", or does it also mean you stop running
   Serena in this repo?** *Blocks:* nothing in this plan — but it decides whether Step 1's green result
   means anything a week from now, since the repo's own `.gitignore` comment states Serena regenerates
   the directory on activation. (Spec Open question 1.)
3. **Will you detach the `serena` server from your Claude Code config, and if so is it going entirely
   or just for this project?** *Blocks:* the durability of the answer to question 2 above. As
   configured it is a machine-wide entry, so "just for this project" is not currently a thing that
   exists. Nobody but you can do this. (Spec Open question 5.)
4. **Is this a one-repo change, or does the same decision get applied to the seven sibling repos that
   also have a `.serena/` — two of which have it tracked in git?** *Blocks:* nothing here; this plan is
   scoped to `ai/sdlc` alone regardless of the answer. Asked because the spec's premise for this
   question — that `ai/sdlc` is the only such repo — is false. (Spec Open question 3, on corrected
   facts.)
5. **Was anything in `.serena/project.yml` worth keeping?** *Blocks:* nothing, and it can no longer be
   acted on — the file is already deleted. Asked only so the answer is on the record rather than
   assumed. (Spec Open question 4, now moot.)

## Risks and how each is checked

- **R1 — `.serena/` regenerates between reading this plan and running Step 1.** The likeliest failure,
  and not a hypothetical: `ai-factory/runs/0006-live-runs.md` records a run that this exact thing
  refused. Any Serena tool call in this repo recreates the directory. *Checked by:* Step 1 assertion #1
  being the first thing run and a stop condition, not a warning — and by Step 1 refusing to delete the
  directory a second time, which would hide the regeneration behind a passing result.
- **R2 — Step 2 gets run on a guess.** The surviving `.gitignore` comment is persuasive prose and
  reads like a decision, so an implementer may take it as the answer to Open question 2. It is not: it
  explains why the rule exists, which is an argument for *keeping* it, while the spec allows either
  reading. *Checked by:* Step 2 being marked BLOCKED with both branches written out and neither
  chosen, and by `git diff --name-only origin/main...HEAD` returning nothing at all when only Step 1
  has run.
- **R3 — Scope creep into the historical records.** A change whose subject is "remove all mention of
  X" invites tidying the five lines in
  `ai-factory/plans/done/0006-ai-factory-layout.md` and `ai-factory/runs/0006-live-runs.md`. They are
  the evidence that the 0006 run refused, which is the whole reason Open question 1 exists. *Checked
  by:* assertion #6 — a diff of exactly those two paths against `origin/main`, which must be empty —
  and by the `guard-paths` hook on the second.
- **R4 — Scope creep into the siblings.** Having learned that seven repos have a `.serena/` and two
  track it, the temptation is to fix them in passing. Each is a separate git repo and Open question 3
  is unanswered. *Checked by:* assertion #4 (`git status --porcelain`) covering only this repo, plus
  the flat statement in *What cannot be planned here*; a cross-repo change would show up as a commit in
  a repo this plan never names.
- **R5 — The plan gets padded to look like work.** There is one runnable step and no tracked diff. An
  implementer or reviewer may read that as an incomplete plan and invent a check script, a docs line or
  a CHANGELOG entry to fill it. Each of those breaks AC4 or the spec's *Out of scope*. *Checked by:*
  assertion #7 naming every tracked file that differs — which for Step 1 alone must be this plan file
  and nothing else — and by `/t4:check` reading the diff against the spec's *Out of scope* section, not
  only its ACs.
- **R6 — A green Step 1 is mistaken for the spec being permanently satisfied.** It is satisfied on the
  tree as it stands, with four open questions outstanding. *Checked by:* Step 1's `**Result — …**`
  block being required to name the questions that remain open, in the shape
  `**Result — … proved; … outstanding.**` that the two filed plans already use.

## Verification

Run from the repo root, in this order. Each line below was run
verbatim on 2026-09-28 and passed; there is no root `Makefile` in this repo, so no `make` target is
named. Never pipe a check to `tail`: the pipeline's status is `tail`'s and a failure would read as a
pass.

```
# 1 — AC1: nothing under .serena/ exists in the working tree
! test -e .serena

# 2, 3 — AC2: no tracked path under .serena/, and no history for it
test -z "$(git ls-files .serena)"
test -z "$(git log --oneline -- .serena)"

# 4 — AC5 (with #1): the tree carries nothing but this plan
git status --porcelain
#   before this plan is committed: exactly one line, "?? ai-factory/plans/0009-remove-serena.md"
#   after it is committed: prints nothing
#   "?? .serena/" on this line is R1 and a stop, not a warning

# 5 — AC3: all thirteen checks, run directly, not piped
for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do \
  bash "$f" >/dev/null 2>&1 || echo "FAIL $f"; done   # prints no FAIL line

# 6 — AC4: the two historical records are byte-identical to origin/main
git diff --stat origin/main...HEAD -- \
  ai-factory/plans/done/0006-ai-factory-layout.md ai-factory/runs/0006-live-runs.md   # prints nothing

# 7 — AC4: exactly which tracked files differ. This compares commits, so it says nothing about a
# file that is still untracked — read it together with #4, which does.
git diff --name-only origin/main...HEAD
#   uncommitted, Step 1 alone: prints nothing (the plan file is new and shows as "??" in #4)
#   committed, Step 1 alone: ai-factory/plans/0009-remove-serena.md, and nothing else
#   after Step 2, if and only if Open question 2 said remove: that file and .gitignore, nothing else

# 8 — the state of the rule Open question 2 is about, so the record says which way it was left
grep -n '^\.serena/$' .gitignore            # today: "24:.serena/"
```

Two things deliberately absent from the block above. **The generator and the syntax checks** from
`ai-factory/docs/definition-of-done.md` item 1 — `node --check` over the hook scripts, `bash -n` over
`sync-adapters.sh`, and `bash ai-factory/make/sync-adapters.sh` run twice for no diff — are not reached
because this change touches no script, no template and no adapter source; running the generator would
only risk dirtying a clean tree. Both syntax checks were run for this plan and pass. **A version bump
and a CHANGELOG entry** are not owed: the spec's *Out of scope* says so, and `check-versions.sh` and
`check-release-docs.sh` pass today without one.

**What verification cannot establish.** That `.serena/` stays gone. Assertion #1 is a statement about
this moment; the repo's own `.gitignore` comment says the directory comes back on activation, and the
only thing that would change that is outside this repo (Ambiguity 3). Every AC is checkable; **AC5 is
checkable only as an observation, never as a guarantee**, and no step in this plan pretends otherwise.
