# 0006 — The layout directory is ai-factory/

**Goal:** rename the layout directory `ai/` → `ai-factory/` and move `specs/`, `docs/adr/` and
`docs/workflow.md` into it, in the templates and in this repo, and ship the migration an adopted
repo runs to follow — without this repo or any adopted repo losing its dont-touch guard or its
run log while it is half-done.

**Spec:** `specs/0006-ai-factory-layout.md` · **Settled there:** the name `ai-factory`;
`ai-factory/docs/workflow.md`; hooks get the old-path fallback and prompts do not; the migration
refuses a dirty tree; `/t4:doctor` reports a half-migrated repo; 1.0.0; the migration command and
the hook fallback are both transitional. **Settled here:** open question 1 — the AC5 scan gets its
own script, `skills/ai-layout/scripts/check-paths.sh` (step 4). **Settled in step 10:** the migration refuses on tracked changes only, naming untracked files
rather than refusing for them; `/t4:migrate-layout` goes in 1.1.0 and the hooks' fallback not
before 2.0.0.

## The shape of the work, measured

- **84 tracked files** name `ai/`, `specs/`, `docs/adr` or `docs/workflow` and must be rewritten.
- **23 tracked files** are history that moves but must **not** be rewritten: `ai/plans/**`,
  `ai/designs/**`, `ai/analyses/**`, `specs/0001`–`0005`, `docs/adr/0001`–`0007`. Plus
  `CHANGELOG.md`, whose released entries stay as written (AC9).
- **22 symlinks must be recreated, not sed-ed** — a symlink's target is not file content:
  `ai/tasks/*.md` (12), `ai/make/*` (4), `ai/agents/*.md` (4), `ai/models.yaml` (1), all pointing
  into `skills/ai-layout/templates/ai/…` or `agents/`, and `docs/adr/0000-template.md` (1)
  pointing into `templates/docs/adr/`. `.claude/agents/*.md` (4) are generated and regenerate.
- **One detection point:** `skills/ai-hooks/scripts/_common.js` `aiDir()`, `path.join(cwd, "ai")`.

## Files to create / modify

| File | Why |
|---|---|
| `skills/ai-hooks/scripts/_common.js` | `aiDir()` prefers `ai-factory/`, falls back to `ai/`. The whole of AC6, and the reason the rest of this plan is safe to run. |
| `skills/ai-hooks/scripts/{guard-paths.js,log-flush.js,_log-schema.js}` | take their paths from `aiDir()` instead of naming `ai/`, so one change covers them. |
| `hooks/hooks.json` | description names both directories (AC6). |
| `skills/ai-layout/templates/ai/` → `templates/ai-factory/` | **git mv** — the payload every adopted repo receives (AC1). |
| `skills/ai-layout/templates/specs/` → `templates/ai-factory/specs/` | **git mv** (AC1). |
| `skills/ai-layout/templates/docs/adr/` → `templates/ai-factory/adr/` | **git mv**; `templates/docs/` then goes (AC1). |
| `skills/ai-layout/templates/{AGENTS.md,CLAUDE.md,Makefile}` | the three root entry points: `See ai-factory/AGENTS.md`, `@ai-factory/AGENTS.md`, `include ai-factory/make/ai.mk` (AC2). |
| `templates/ai-factory/make/sync-adapters.sh` | 15 hardcoded paths, **and** the stale-adapter regexes, which must recognise a previously generated file pointing at `ai/tasks/` or nothing cleans up in a migrated repo. |
| `templates/ai-factory/make/{ai.mk,log.js,gate.js}` | the headless runner's paths and the log path. |
| `templates/ai-factory/{AGENTS.md,models.yaml,tasks/*.md,agents/*.md,docs/*.md}` | every path a prompt or context doc names (AC7). |
| `skills/ai-layout/scripts/manifest.js` | `MANIFEST` → `ai-factory/.sdlc.json`; `SKIP` run-log pattern. `walk` needs no edit — it reads the templates tree (AC18). |
| `skills/ai-layout/scripts/doctor.sh` | the directory it looks for, plus the half-migrated and unmigrated reports (AC22). |
| `skills/ai-layout/scripts/{check-adapters.sh,check-doctor.sh,check-manifest.sh,check-versions.sh}` | the paths they assert and the comment citations (AC7). |
| `skills/ai-hooks/fixtures/check-log-schema.sh` + fixtures | the log path; the 16 columns do not move (AC12). |
| `skills/{ai-layout,ai-hooks}/SKILL.md` | the layout inventory and the gitignore/gitattributes prescriptions (AC1, AC2, AC7). |
| `agents/*.md` (all eight) | each names the directory it may write and the ones it may not (AC5, AC7). |
| `commands/{adopt-sdlc.md,doctor.md,setup-tracker.md,sync-sdlc.md}` | paths they name; `sync-sdlc.md` gains the old-layout short-circuit (AC17). |
| `commands/migrate-layout.md` | **new** — thin prompt over the script (AC13). |
| `skills/ai-layout/scripts/migrate-layout.sh` | **new** — refusals, `git mv`, path-only rewrite, adapter run, manifest refresh, two-phase report (AC14–AC16, AC23). |
| `skills/ai-layout/scripts/check-migrate.sh` | **new** — fixture-driven proof of the above (AC20). |
| `skills/ai-layout/scripts/check-paths.sh` | **new** — the AC5 scan, proved against a scratch edit (AC19). |
| `ai/` → `ai-factory/`, `specs/` → `ai-factory/specs/`, `docs/adr/` → `ai-factory/adr/`, `docs/workflow.md` → `ai-factory/docs/workflow.md` | this repo follows its own templates (AC4). |
| `.gitignore`, `.gitattributes` | `ai-factory/runs/…` (AC2). |
| `ai-factory/adr/0008-*.md` | **new** — the decision, the bounded exception to the sync rule, the 1.1.0 removal (AC8, AC24). |
| `README.md`, `CHANGELOG.md`, four manifests | 1.0.0, breaking, migration, hook fallback, grep-your-own-CI (AC21). |

## Server vs client components
Not applicable — no application code. The split that matters is **what the plugin ships** versus
**what the migration rewrites inside someone else's repo**. Everything in the first is ours to
change freely; everything in the second is bounded by AC23 to path strings, because a migration
that also delivered new prompt text would be `/t4:sync-sdlc` wearing a disguise.

## Steps

- [x] **Step 1 — Hooks accept both names, before anything moves.** `aiDir()` returns
  `ai-factory/` if present, else `ai/`, else null; the three scripts that name `ai/` derive from
  it; `hooks.json` description names both. Nothing else in this step.
  *Why first:* the plugin is loaded from this working tree, so from step 2 onward this repo's own
  guard and run log depend on detection already accepting the new name — and an adopted repo that
  updates before migrating depends on it accepting the old one.
  *Proves:* AC6. *Check:* `node --check` on every hook script; every fixture under
  `skills/ai-hooks/fixtures/`; `check-log-schema.sh`; and a live probe in this repo, still on
  `ai/`, that a write to a dont-touch path is refused with the guard's own message.

- [x] **Step 2 — Rename the layout, templates and this repo together.** `git mv` the templates
  tree and `git mv ai ai-factory`; recreate the 22 symlinks with `ln -sfn` and assert each
  resolves; rewrite the 84 files with AC5's guarded pattern, excluding the 23 history files and
  `CHANGELOG.md`; update `templates/{AGENTS.md,CLAUDE.md,Makefile}`, `.gitignore`,
  `.gitattributes`, `manifest.js`, `sync-adapters.sh` (including the stale-adapter regexes),
  `doctor.sh` and the four check scripts; regenerate adapters.
  *Why one step:* the symlinks tie the templates to this repo's layout, so a tree that is half
  renamed has 22 dangling links and a generator that cannot run.
  *Proves:* AC2, AC6 on the new name, AC11, AC12, and AC4/AC10 for everything but the three
  moves. *Check:* `test -e` on all 22 (BSD `readlink` has no `-e`, so the check must be portable); `sync-adapters.sh` twice with no diff;
  `check-adapters.sh`; `check-log-schema.sh`; `git diff -M --stat` over the 23 history paths shows
  renames with zero content change; the guard probe of step 1 repeated, now under `ai-factory/`.

- [x] **Step 3 — Move specs, ADRs and workflow.md in.** In the templates:
  `specs/` → `ai-factory/specs/`, `docs/adr/` → `ai-factory/adr/`, then `templates/docs/` is
  gone. In this repo the same, plus `docs/workflow.md` → `ai-factory/docs/workflow.md`, then
  `docs/` is gone. Recreate the ADR template symlink. Rewrite what still names the old three
  paths, history excluded. Regenerate adapters.
  *Proves:* AC1, AC4, AC7, AC10 including `t4-adr` naming `ai-factory/adr/`. *Check:* AC5's grep
  returns nothing; `git log --follow` on one moved spec, one moved ADR and
  `ai-factory/docs/workflow.md` reaches each file's first commit; sync twice, no diff.

- [x] **Step 4 — The scan becomes a check script.** New `check-paths.sh` owning AC5's pattern,
  lifting `scan_banned` and the scratch-prompt self-proof from `check-adapters.sh` rather than
  inventing a second way to prove a scan works.
  *Proves:* AC5, AC19. *Check:* passes on the tree as it stands; on a scratch copy with one
  `agents/*.md` edited back to `ai/`, exits non-zero and names that file.

- [x] **Step 5 — The migration.** `commands/migrate-layout.md` and `migrate-layout.sh`: the five
  refusals first and before any write (AC15), then `git mv` of the three paths, then a path-only
  rewrite of the repo's own `ai-factory/**` plus root `AGENTS.md`, `CLAUDE.md`, `Makefile`,
  `.gitignore`, `.gitattributes`, then `sync-adapters.sh`, then `manifest.js write`. Commits
  nothing. Reports moves and rewrites as two labelled lists. Idempotent.
  *Proves:* AC13, AC14, AC15, AC16, AC23. *Check:* `bash -n`; `check-paths.sh`; and a grep
  showing no prompt, command or hook invokes it (AC13).

- [x] **Step 6 — Fixtures for the migration.** `check-migrate.sh` builds synthetic repos in a
  temp dir — old layout, already migrated, each of the five refusals, and `ai/` with no `specs/`
  — asserting AC14–AC16 and, on the old-layout case, that every changed line contains one of the
  old paths and nothing else differs (AC23), and that `manifest.js check` afterwards reports up
  to date (AC18).
  *Proves:* AC20, and AC14–AC16, AC18, AC23 mechanically. *Check:* the script itself, twice,
  leaving no temp dir and touching nothing outside it.

- [x] **Step 7 — Tell the developer where they are.** `sync-sdlc.md` short-circuits on an
  old-layout repo to "run `/t4:migrate-layout`" instead of printing one removed-plus-added line
  per file (AC17). `doctor.sh` reports unmigrated, half-migrated and healthy, naming which
  directory the hooks are using; `check-doctor.sh` gains those cases.
  *Proves:* AC17, AC22. *Check:* `check-doctor.sh`; a synthetic old-layout repo run through the
  sync prompt's own steps.

- [x] **Step 8 — Prove both paths live, under Claude Code.** In a scratch repo: `/t4:adopt-sdlc`
  from nothing, then confirm only `ai-factory/` plus the three root files arrived, the manifest
  tracks `ai-factory/` paths, `sync-adapters.sh` writes all three adapter trees and `make -n ai
  TASK=spec` resolves its include. Then a second scratch repo adopted at 0.27.1, with real specs
  and ADRs and a hand-edited prompt, taken through `/t4:migrate-layout` end to end; transcripts
  kept for the MR.
  *Proves:* AC3, and AC14/AC18 as a run rather than a fixture. *Check:* the transcripts; `git log
  --follow` inside the scratch repo; `manifest.js check` reporting up to date afterwards.

  **Result — AC3, AC14 and AC18 proved as runs.** Two scratch repos, the plugin loaded from this
  working tree, each command a real headless session (`claude -p "/t4:<cmd>" --plugin-dir …`,
  stream-json transcripts kept).
  **Adopt (AC3):** a small Node library with no layout. `/t4:adopt-sdlc --owner dev` detected the
  stack from package.json, and the repo gained `ai-factory/` plus `AGENTS.md`, `CLAUDE.md`,
  `Makefile`, the two git files and the three generated adapter trees — 12 Claude commands, 12
  Codex skills, 1 Cursor rule — and no top-level `ai/`, `specs/` or `docs/`.
  `ai-factory/.sdlc.json` tracks 38 files: the three root entry points and the rest under
  `ai-factory/`, none naming the old layout. `make -n ai TASK=spec` resolves the include and
  writes into `ai-factory/runs/`.
  **Migrate (AC14, AC18):** a repo adopted at 0.27.1 — the full template set wound back to the old
  layout, two specs, an ADR, a plan, its own history, and `ai/tasks/spec.md` edited by hand. First
  run **refused**: Serena's MCP server had created `.serena/` during the session, so the tree was
  dirty. The session reported the refusal, diagnosed the cause and stopped rather than working
  around it — the prompt's "do not work around it" rule holding under a real agent. With the tree
  clean it moved 4 paths, rewrote 36 files, committed nothing, left the moves staged and the
  rewrite unstaged, and the hand-edited paragraph survived with its paths rewritten. Following the
  printed two-commit order, `git log --follow` reaches the original commit for the AGENTS, spec,
  ADR and plan files. `manifest.js check` afterwards: "up to date — every tracked file matches."
  **Worth reconsidering (open question 4):** the dirty-tree refusal fired for a reason that had
  nothing to do with the repo. Untracked files cannot affect `git mv` or the rewrite; they only
  matter because the developer's own `git add -A` for the second commit would sweep them in.
  Refusing on tracked modifications and warning about untracked ones would have let this run
  through. Left strict, as decided.

- [x] **Step 9 — ADR 0008, docs, 1.0.0.** ADR 0008: the decision, the bounded exception to
  `/t4:sync-sdlc`'s separate-reviewable-edit rule with its reason, both transitional pieces and
  1.1.0 (AC8, AC24). Finish the prose: `README.md`, both `SKILL.md`, `workflow.md`'s own links,
  and `coding-standards.md`'s "no-op when `ai/` is absent" line, which is now two names.
  CHANGELOG 1.0.0 — breaking, run `/t4:migrate-layout`, the hooks keep working meanwhile, grep
  your own CI. Version 1.0.0 in all four manifests.
  *Proves:* AC7, AC8, AC9, AC21, AC24; definition of done 3 and 7. *Check:* `check-versions.sh`;
  `check-paths.sh`; `check-manifest.sh`; README's command table against what ships.

## Finishing — steps 10 to 16

Steps 1–9 built the release. These close it. Step 10 is a gate: two of its answers change code, so
nothing after it should be committed until they are settled.

- [x] **Step 10 — Settle the two open decisions.** Both are yours, both change shipped files.
  (a) **The dirty-tree refusal.** It fired in step 8's live run because an MCP server created
  `.serena/` mid-session — a reason unrelated to the repo. Untracked files cannot affect `git mv`
  or the rewrite; they matter only because the developer's own `git add -A` for the second commit
  would sweep them in. Options: leave strict; or refuse on tracked modifications and warn about
  untracked ones. Changing it touches `migrate-layout.sh`, `check-migrate.sh`'s `dirty` case and
  the CHANGELOG sentence about refusals.
  (b) **The removal version.** `1.1.0` is my assumption, now written into `ai-factory/adr/0008`,
  the CHANGELOG, `_common.js`, `hooks.json`, `commands/migrate-layout.md` and
  `check-paths.sh`'s exclusion comment. Confirm it or name another; `grep -rn '1\.1\.0'` finds
  every place it is promised.
  *Proves:* nothing new. *Check:* if (a) changes, `check-migrate.sh` still passes and its `dirty`
  case asserts the new behaviour.

  **Result — both settled, and neither the way the plan assumed.**
  **(a) Narrowed, not kept.** The refusal is now on uncommitted changes to *tracked* files; an
  untracked file is named in the output and the move proceeds. The refusal exists so the move is
  reviewable as its own commit, and only tracked work in flight threatens that — while refusing for
  an untracked file demonstrably blocked a real migration over a scratch directory an MCP server had
  created. Naming it still matters, because the second commit's `git add -A` would sweep it in.
  `check-migrate.sh` gained the case, and it fails if the warning is dropped.
  **(b) Split, not confirmed.** The two transitional pieces do not expire together, because
  removing them fails in different ways. `/t4:migrate-layout` goes in **1.1.0**: its absence is a
  missing slash command, which is loud, and the script survives in any older checkout. The hooks'
  fallback waits for **2.0.0**: removing it disarms the dont-touch guard and stops the run log in any
  repo that never migrated, silently — the exact failure the fallback was added to prevent, and not
  something to do in a minor release. Updated in all fifteen places the promise appears.

- [x] **Step 11 — `/t4:test ai-factory/specs/0006-ai-factory-layout.md gaps`.** Close the ACs no
  check asserts, and record the ones that cannot be closed by a script. Known gaps, so the tester
  need not rediscover them: **AC8/AC24** — ADR 0008 exists and says what it must (assertable:
  grep the ADR for the decision, the bounded exception, and the removal version); **AC17** — the
  `/t4:sync-sdlc` prompt's own old-layout branch (the `manifest.js` half is already pinned by
  `check-manifest.sh`); **AC21** — the CHANGELOG carries the migration instruction, the breaking
  note and the CI warning; **AC2** — the three root entry points in the templates. **AC4** cannot
  be asserted before step 14.
  *Proves:* AC8, AC17, AC21, AC24 by check rather than by eye. *Check:* each new assertion fails
  when the thing it guards is removed — the house rule for every scan in this repo.

- [x] **Step 12 — Correct the spec where the build proved it wrong.** Four edits, all of them
  findings from steps 1–9 rather than second thoughts:
  (a) **AC5** lists `ai-factory/adr/0008-*` in the scan set, but ADRs are records and 0008 cannot
  state the decision without naming `ai/`. Records are exempt; say so.
  (b) **AC17**'s rationale describes a per-file drift report that cannot occur — `MANIFEST` moved,
  so an unmigrated repo's manifest is invisible and the report is unreachable. The real failure is
  three pieces of wrong advice in a row, measured in step 7.
  (c) **Open question 1** is closed — the scan is `check-paths.sh`, built in step 4.
  (d) The **1.1.0 assumption** note goes or is confirmed, per step 10(b).
  *Proves:* AC9's spirit — a spec that records what was actually decided. *Check:* `check-paths.sh`
  still passes; the spec's AC numbering is unbroken.

  **Result.** AC5 now describes a scan that works — the obvious pattern is blind to `templates/ai/`
  because it excludes a preceding `/` to protect `~/code/ai/ai-sdlc` — and records, ADRs
  included, are stated to be out of the scanned set, which removes the contradiction of asking a
  scan to pass over the ADR that decides the rename. AC17's rationale is replaced by the measured
  failure: not a long report, but three wrong answers in a row, ending at `/t4:adopt-sdlc`
  scaffolding a second layout. Open questions closed, each recording where it landed rather than
  being deleted. AC numbering unbroken at 24; `check-paths.sh` unaffected, specs being records.

  **Result — the suite goes from 8 checks to 10, and one AC turned out to be unmet.**
  The tester added `check-release-docs.sh` (AC8, AC17's prompt half, AC21, AC24) and
  `check-entrypoints.sh` (AC2), reporting 50 mutations all red and modifying nothing outside its two
  new files. I re-ran four mutations myself on clean copies — the two removal versions swapped, the
  CHANGELOG's CI-grep line deleted, the sync branch's STOP removed, an ADR citation restored to a
  path — each fails naming the file. AC7's first clause needs no test: "each names the new path" is
  what `check-paths.sh` already fails on.
  **AC7's second clause was not met, and is now.** The templates cited ai-sdlc's own ADRs by path —
  `see ai-factory/adr/0007` — which inside an adopted repo resolves to *that* repo's ADR 7: nothing
  today, something unrelated once they write a seventh. Pre-existing (it read `docs/adr/0007`
  before), untouched by the rename, and a failing AC either way. The six citations in
  `templates/ai-factory/docs/{tracker,knowledge}.md` now read "ai-sdlc's ADR 0007" with no path; the
  two seam copies stay byte-identical, as `check-adapters.sh` requires. This repo's own `fleet.md`
  keeps its paths — there they resolve.
  **Two gaps the tester found and left to me, both closed.** AC13's "none of them invokes it" had no
  assertion: it is now a grep separating *recommending* `/t4:migrate-layout`, which doctor and sync
  must do, from naming `migrate-layout.sh`, which only its own command may. AC1's inventory was
  unasserted beyond one clause — a file dropped from the templates would ship to every future adopter
  with no drift check able to notice, since `manifest.js` tracks only what a repo received. All 13
  entries are named now. Six further mutations prove the three additions red.
  **Still blocked on step 14:** AC9 and AC4's `git log --follow` clause — nothing is committed, so
  there is no history to follow and no "before" to diff.

- [x] **Step 13 — `/t4:check`.** Independent read-only review of the whole diff against the spec,
  the plan, the coding standards and the dont-touch rules. Do it after 11 and 12 so the reviewer
  reads a correct spec and the finished test set.
  *Proves:* definition of done 5. *Check:* no `blocker` findings open.

  **Result — `request_changes`: one blocker, one major, five minor. All seven fixed; all verified
  before fixing.**
  **Blocker, and it was mine.** Step 10(a) stopped the migration refusing on untracked files, which
  opened a path where `git mv` dies on a directory whose contents are all untracked — "fatal: source
  directory is empty" — *after* `ai/` has already moved. Reproduced: exit 128 with `ai-factory/`
  created, `specs/` still at the root, every prompt still naming `ai/`, no adapters, no manifest — and
  the second run took the "already migrated" early exit and printed "nothing to move", exit 0. A
  wrecked repo with a false all-clear, which is the silent failure this whole feature exists to
  prevent. Fixed three ways: a pre-flight refusal for any directory with no tracked file, before the
  first write, so AC15's "a refusal moves nothing" holds; the early exit now asks what is *left* to do
  rather than whether `ai/` is gone, which makes the command resumable and recovers a half-migrated
  repo; and `move_into` uses `git mv -k` plus a plain `mv` so a mixed directory does not abort.
  **Major, also mine.** This repo's own rewrite pass edited the run log — 13 rows in
  `log.previous.csv` and 2 in `log.csv` had their `branch` column changed from `ai/architect-agent`
  and `ai/tester-agent`, the branches the work actually ran on, to `ai-factory/…` branches that never
  existed. The shipped migration excludes `runs/` for exactly this reason; my exclusion list did not.
  Both files restored from HEAD; the 16 columns still pin.
  **Five minor, each fixed:** `check-doctor.sh` asserted the hooks work "until 1.1.0", a leftover from
  before step 10(b) split the versions, so it would have passed a doctor promising the wrong one — and
  its pragma sat inside the failure message, printing to the developer; two comments were garbled by
  splicing new text mid-sentence, one of them in a file adopted repos receive verbatim; `cmdWrite`
  still sent an unmigrated repo to `/t4:adopt-sdlc`, the advice AC17 identifies as dangerous, reachable
  by hand; `manifest.js write` failures were swallowed while the report claimed "refreshed"; and only
  one of AC14's two `docs/` clauses was asserted, so an `rm -rf` there would have deleted an adopted
  repo's own documentation unnoticed.
  Four new fixture cases pin the blocker, the resume, docs preservation and the `cmdWrite` advice.
  The reviewer also checked what I asked it to be suspicious of and found it sound: the eight
  `check-paths.sh` exclusions and its pragmas are honest, the 22 symlinks resolve, sync is idempotent,
  and an independent wider scan found no stale instruction.

- [x] **Step 14 — Commit as two commits, and prove the history.** This repo has the problem it
  ships a fix for: `git log --follow` on a moved spec currently reaches **0** commits, and
  everything is staged as one change. Reconstruct the split — save the working tree, `git reset
  --hard HEAD`, redo only the renames with `git mv` (including the 22 symlinks, whose targets
  change and so belong to the second commit), commit; restore the tree, `git add -A`, commit.
  Messages: `ai(run): plan 0006 — move the layout to ai-factory/ (paths unchanged)` then
  `ai(run): plan 0006 — 1.0.0, ai-factory/ everywhere`.
  *Proves:* AC4, at last. *Check:* the first commit is R100 renames only; `git log --follow` reaches
  the original commit for a moved spec, a moved ADR and `ai-factory/docs/workflow.md`; all eight
  checks still pass afterwards.

- [x] **Step 15 — Preserve the evidence.** Step 8's two headless transcripts are in the session
  scratchpad, which does not survive the session. Definition of done 2 wants them linked from the
  MR: copy them somewhere durable, or paste the two result blocks into the MR description.
  *Proves:* definition of done 2. *Check:* the MR links or contains a before/after run.

  **Result.** `ai-factory/runs/0006-live-runs.md` — committed, 149 lines: the command line used, and
  what each of the three sessions reported, verbatim and trimmed. The raw stream-json transcripts are
  ~490 KB and `ai-factory/runs/*.jsonl` is gitignored, so they are deliberately not in the repo; the
  extract is what a reviewer needs, and the file says so. The refused run is kept alongside the two
  that worked, because a refusal the session declined to work around is the more interesting evidence.

  **Result — two commits on `ai/ai-factory-layout`; AC4 and AC9 proved at last.**
  `6a49bdf` is **96 renames, every one R100, zero content change**. `362a243` is the 131 files that
  changed, and touches no record at all. `git log --follow` now reaches back past the rename: 5
  commits for spec 0001, 5 for ADR 0001, 18 for `workflow.md`, 16 for `ai-factory/AGENTS.md`, 9 for
  plan 0005 — AC4, which could not be checked until something was committed. AC9: all 23 record
  paths are R100 renames and the CHANGELOG is +64/−0. Ten checks pass on the committed tree, all 26
  symlinks resolve, sync is idempotent, version 1.0.0.
  **Two mistakes made and recovered during the reconstruction, both worth knowing.**
  `git reset --hard` does not remove a directory that still holds ignored files, so `ai-factory/`
  survived the reset via `runs/log.pending.csv` — and `git mv ai ai-factory` then moved the layout
  *inside* it, producing `ai-factory/ai/`. Undone, the stray directory set aside, the renames redone.
  And the AC9 check appeared to fail: a pathspec naming only `ai-factory/...` cannot pair a rename,
  so every record read as an addition with all lines inserted. Given both sides it is R100, and
  commit 2's diff for those files is empty. That is the third time in this plan that a one-sided
  pathspec has manufactured a false alarm; the Verification block's own AC9 command has the same
  flaw and now names both sides.

- [x] **Step 16 — MR, labelled `ai-assisted`.** Name the blast radius in the description, not only
  in the CHANGELOG: breaking for every adopted repo, one command to migrate, hooks keep working
  meanwhile, and grep your own CI. Link ADR 0008.
  *Proves:* definition of done 3 and 6. *Check:* the label is on, and the description names the
  blast radius.

  **Result.** Merge request 3, labelled `ai-assisted`, from
  `ai/ai-factory-layout` into `main`. The description names the blast radius rather than leaving it in
  the CHANGELOG: breaking for every adopted repo, one command to migrate, the hooks working meanwhile,
  the two deprecations with their different end dates, and grep your own CI. It links the spec, the
  plan and ADR 0008, states why the two commits are two, and records what `/t4:check` found — the
  blocker and the major both being mine.

## Risks

| Risk | How it is checked |
|---|---|
| This repo silently loses its guard and log the moment `ai/` is renamed — the plugin is loaded from this tree. | Step 1 lands detection first; step 2's check repeats the live guard probe under the new name. |
| The 22 symlinks break. `sed` cannot edit a link target, so a rewrite pass looks like it worked and leaves 22 dangling links. | `test -e` on every one of the 22 in step 2, and again after step 3 for the ADR template. |
| A blanket rewrite eats history — 23 files whose whole value is recording what was true then. | Explicit exclusion; `git diff -M --stat` over those paths must show renames and zero content change (AC9). |
| The rewrite hits an `ai/`-shaped substring it must not: `ai-sdlc`, `ai-layout`, `ai-hooks`, `.agents/`, or a URL like `claude.ai/`. | AC5's guarded pattern for both the scan and the rewrite; no such URL is in this tree today, but `migrate-layout.sh` runs in repos that may have one, so it uses the same guard. |
| `sync-adapters.sh` stops recognising already-generated adapters, which point at `ai/tasks/`, and leaves orphans behind in every migrated repo. | Step 2 makes the cleanup regexes accept both names; step 6's fixture asserts no `.claude/commands/t4/*.md` still points at `ai/tasks/` after migrating. |
| The migration smuggles upstream prompt text into an adopted repo under cover of a rename. | AC23's path-only assertion, measured on a fixture diff in step 6. |
| An adopted repo's CI, pipeline or tooling names `ai/` where the plugin cannot see it. | Not fixable here. AC21's CHANGELOG line tells the developer to grep; step 9. |
| Hooks and commands are read from the loaded plugin, so mid-plan behaviour may lag the working tree until the session reloads. | Steps 1, 5 and 7 are verified by running the scripts directly, not only through a slash command. |

## Verification

```
bash skills/ai-layout/scripts/check-paths.sh          # AC5, AC19
bash skills/ai-layout/scripts/check-migrate.sh        # AC14–AC16, AC18, AC20, AC23
bash skills/ai-layout/scripts/check-adapters.sh       # AC10
bash skills/ai-layout/scripts/check-doctor.sh         # AC22
bash skills/ai-layout/scripts/check-manifest.sh       # AC18
bash skills/ai-layout/scripts/check-versions.sh       # AC21 — all four at 1.0.0
bash skills/ai-hooks/fixtures/check-detect.sh         # AC6
bash skills/ai-hooks/fixtures/check-log-schema.sh     # AC12
for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done
bash -n skills/ai-layout/scripts/migrate-layout.sh
bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh
bash ai-factory/make/sync-adapters.sh && bash ai-factory/make/sync-adapters.sh   # no diff
git ls-files -s | awk '$1=="120000"{print $4}' \
  | while read -r l; do test -e "$l" || echo "DANGLING $l"; done                  # all 22 resolve
# Both sides of the move, or rename detection cannot pair them and every record reads as new:
git diff -M --name-status HEAD~2 HEAD -- 'ai/plans/*' 'ai-factory/plans/*' \
  'specs/000[1-5]*' 'ai-factory/specs/000[1-5]*' 'docs/adr/000[1-7]*' 'ai-factory/adr/000[1-7]*'
```

Plus steps 8's two scratch-repo transcripts, and `/t4:check`.

## Planning notes

- **AC3 and AC4 were corrected in the spec after this plan was drafted**, so the two now agree:
  AC4 records the real shape — three directories of per-file symlinks (12, 4, 4) plus
  `models.yaml` and the ADR template, 22 in all — and AC3 asks for `make -n`, the dry include
  check, rather than a live headless run. Nothing in the steps changed.
- **Left alone, and pre-existing:** `ai/agents/` links only four of the eight agents. Not this
  plan's business; the count is what it is on both sides of the rename.
- **Step 2 is the largest step and cannot be usefully split.** Every smaller cut leaves either
  dangling symlinks or a generator that cannot run. It is mechanical, and every part of it is
  checked by a command rather than by reading.
- **This plan and its spec move in steps 2–3**, to `ai-factory/plans/0006-…` and
  `ai-factory/specs/0006-…`. Their prose keeps the paths that were true when it was written, like
  every other record (AC9).
- **Nothing here changes what any task does.** If a prompt behaves differently after the rename,
  that is a defect in the rewrite, not a new behaviour to accept.
