# ASD-004 — Command shortcuts
Created: 2026-11-02T18:24:56.152Z

**Goal:** Add three non-deprecated task shortcuts (`ba` and `analyze` for `analyse`, `scout` for `explore`). They come from one `TASK_SHORTCUTS` table in `make/models.js` and behave like their target in every place that takes a task name: plugin commands and skills, project Codex skills, the headless runner, routing, doctor, the run-log hook, cost, lifecycle and the user docs. Ship this as release 5.1.0.

**Spec:** `ai-factory/specs/ASD-004-command-shortcuts.md` (parent: `ai-factory/explorations/ASD-004-command-shortcuts.md`, option B).

**Risk file:** `ai-factory/risks/ASD-004-command-shortcuts.md`. It has no `## Reassessment`, so this plan carries findings R1–R10 from its body. Artifact contracts are not enabled in this repo (`ai-factory/contracts/config.json` is absent).

**Out of this plan:** `/fc:current`, which a separate spec covers. `/fc:start` and its `START_TASKS`, plus everything else the spec's *Out of scope* lists.

## Design

- **One table, two kinds.** `TASK_SHORTCUTS = Object.freeze({ ba: "analyse", analyze: "analyse", scout: "explore" })` sits beside `TASK_ALIASES`, which is unchanged. `canonicalTask` resolves a name through `TASK_ALIASES` first, then through `TASK_SHORTCUTS`, and returns any other name as it is. `aliasNotice` keeps reading `TASK_ALIASES` only, so it throws for a shortcut (AC3). Every "is this deprecated?" decision tests `Object.hasOwn(TASK_ALIASES, name)`, never `canonicalTask(name) !== name`. That applies to the runner's stderr line, the parser's `routing.aliased` list, the parser's duplicate message, the doctor line and the checks (R6).
- **Parser (AC16, AC17).** A shortcut key is stored under its target and is not pushed to `routing.aliased`. The parser records each shortcut key it read in a new `routing.shortcuts` list, so doctor can print its `ok` line. A duplicate, whether a target plus its shortcut or two shortcuts of one target, fails with a message of this form: ``duplicate task `analyse`: `ba` is its shortcut name, so map only `analyse` ``. The deprecated message stays as it is today.
- **Doctor (AC18–AC20).** For each key in `routing.shortcuts`, doctor prints `["ok", "routing", "routing.tasks.scout read as explore"]`. The deprecated finding and the `models` parse-error finding are unchanged.
- **Runner (AC13, AC14).** `runner.js` writes `runner: TASK=<x> is deprecated; running TASK=<y>` only when `<x>` is in `TASK_ALIASES`. For a shortcut it runs the target's task file and writes nothing extra.
- **Plugin entry points (AC4–AC7, AC9).** `sync-claude-commands.js` emits `commands/<shortcut>.md` with the `wrapper()` it already has. The description is `Shortcut for /fc:<target> — <target description>`, the `argument-hint` is the target's, the preamble is only `entryPreamble("claude", <target>)`, and the task path is the target's. `sync-codex-skills.js` emits `codex-skills/fc-<shortcut>/` with `taskBody(<target>, …, entryPreamble("codex", <target>))` and the description `Shortcut for $fc-<target> — <target description>`. It adds the shortcut skills before its `commands/` loop, as it already does for aliases, so `commands/ba.md` does not produce a second, generic skill. `/fc:check` and `$fc-check` output stays byte-for-byte the same (AC6).
- **Project Codex skills (AC8–AC10).** `make/sync-adapters.js` writes `.codex/skills/fc-<shortcut>/SKILL.md` while the target task exists. It uses the alias-skill body without `aliasNotice` and with the description `Shortcut for $fc-<target> — <target task description>`. It writes no Claude pointer for a shortcut, because the plugin ships `/fc:<shortcut>` natively. The `fc-check` block is left as it is (AC10).
- **Clash refusal (AC11).** All three tools throw `Task <name>.md uses the shortcut name of <target>; rename the task file` before they write anything when a task file has a shortcut name. In `sync-adapters.js` the check runs before the first `put()` flush, so that file gets no entry point and the run writes nothing (R1). AC12 for `sync-adapters.js` is **blocked on R2**, see Step 7 and *Open questions*.
- **Hook (AC21, AC22).** `log-task.js` replaces `const ALIASES = { check: "review" };` with one pinned object, the union of both tables: `{ check: "review", ba: "analyse", analyze: "analyse", scout: "explore" }`. The regex stays as it is (R7). `check-codex.sh` compares the pinned literal with `{ ...TASK_ALIASES, ...TASK_SHORTCUTS }` and fails when they differ (R5).
- **Cost and lifecycle (AC23).** No code change. Both already call `canonicalTask`. Fixture cases prove it.
- **User docs (AC27–AC31).** `sync-docs.js` may require only Node built-ins and `./_frontmatter.js`, a rule that `check-sync-docs.sh reader AC9-builtins-only` pins. So it **cannot** load `models.js`. It detects a shortcut from the command's own description prefix, `/^Shortcut for \/fc:([a-z0-9-]+) — /`, the same way it already detects `Deprecated — use /fc:`. A shortcut page gets a `> **Shortcut.** Runs [\`/fc:<target>\`](<target>.md) …` line. The notes waiver becomes "deprecated or shortcut needs only `## Usage`", which replaces `name === "check"`, so `check` keeps its waiver (AC29). The counts already derive from `commands/`. `docs/commands.md` and its "N project tasks / M plugin-level" line are generated, so they become 28 / 18 / 10 without a literal.
- **Counts (AC30, AC31, R8).** `check-risk.sh docs command-counts-25` has the literal `25`. Rename it `command-counts` and drop the literal. It keeps checking that README, `workflow.md` and the layout `SKILL.md` state the number of files in `commands/`. It also asserts that `commands/` holds exactly the task templates without `quick`, plus `quick`, plus one file per `TASK_ALIASES` and `TASK_SHORTCUTS` key, plus the plugin-level commands. The prose says 28, and `check-continuation.sh` already derives its count.

## Files

| File | Why |
|---|---|
| `skills/ai-layout/templates/ai-factory/make/models.js` | `TASK_SHORTCUTS`, `canonicalTask`, the parser's shortcut duplicate and `routing.shortcuts`, the doctor `ok` line, the export (AC1–AC3, AC15–AC20). |
| `skills/ai-layout/templates/ai-factory/make/runner.js` | Deprecation line only for `TASK_ALIASES` names (AC13, AC14). |
| `skills/ai-layout/templates/ai-factory/models.yaml` | Comment near line 30: a shortcut key is read as its target; map the canonical key (R4). |
| `skills/ai-layout/templates/ai-factory/make/sync-adapters.js` | Project `fc-<shortcut>` skills and the clash refusal (AC8–AC11); AC12 per R2. |
| `skills/ai-layout/scripts/sync-claude-commands.js` | Shortcut commands and the clash refusal (AC4–AC6, AC11, AC12). |
| `skills/ai-layout/scripts/sync-codex-skills.js` | Shortcut plugin skills and the clash refusal (AC7, AC9, AC11, AC12). |
| `commands/ba.md`, `commands/analyze.md`, `commands/scout.md` (generated) | New `/fc:` entry points (AC4, AC5). |
| `codex-skills/fc-ba/`, `codex-skills/fc-analyze/`, `codex-skills/fc-scout/` (generated) | New `$fc-` plugin skills (AC7, AC9). |
| `skills/ai-hooks/scripts/log-task.js` | Pinned union table (AC21). |
| `skills/ai-hooks/SKILL.md` | Line 35 describes the hook's table; name shortcuts too (AC21 doc). |
| `skills/ai-hooks/fixtures/check-codex.sh` | Hook cases for every AC21 form; union equality (AC21, AC22, R5). |
| `skills/ai-layout/scripts/check-model-selection.sh` | Table, `canonicalTask`, `aliasNotice`, parser and doctor cases (AC1–AC3, AC16–AC20). |
| `skills/ai-layout/scripts/check-interactive-model-routing.sh` | `dispatch --task <shortcut>` equals `dispatch --task <target>` on both hosts (AC15). |
| `skills/ai-layout/scripts/check-runner-security.sh` | `TASK=ba|analyze|scout` runs the target, with no deprecation on stderr; `TASK=check` unchanged (AC13, AC14). |
| `skills/ai-layout/scripts/check-cost.sh`, `skills/ai-layout/scripts/check-lifecycle.sh` | Shortcut-labelled rows and events counted under the target (AC23). |
| `skills/ai-layout/scripts/check-start-routing.sh` | `direct-entries-unchanged` branches on the table each name comes from (AC32, R6). |
| `skills/ai-layout/scripts/check-plugin-hosts.sh` | Shortcut entry points exist with the AC5 and AC9 descriptions; generator clash refusal on a scratch copy (AC4, AC5, AC7, AC9, AC11, AC12). |
| `skills/ai-layout/scripts/check-adapters.sh` | Skill count = tasks + aliases + shortcuts; shortcut skills carry no notice; clash refusal on a scratch tree (AC8–AC11, AC32, R6). |
| `skills/ai-layout/scripts/sync-docs.js` | Shortcut detection, page marker and notes waiver (AC27, AC29). |
| `skills/ai-layout/scripts/check-sync-docs.sh` | Fixture command `ba` (shortcut) with Usage-only notes; generate, notes and failure cases (AC27, AC29), Step 8. Step 5 also rewrites the ASD-003 case `reader AC11-sync-scripts-untouched` (generators' `--check` plus `/fc:check` entry points identical to the pinned pre-ASD-004 commit), by the developer's decision. |
| `docs/commands/_notes/ba.md`, `analyze.md`, `scout.md` (new) | `## Usage` only, pointing at the target (AC28). |
| `docs/commands/_notes/_groups.md` | Put the three shortcuts in the *Decide before building* group, or `--check` fails as ungrouped (AC27). |
| `docs/commands.md`, `docs/commands/ba.md`, `analyze.md`, `scout.md` (generated) | The reference pages (AC27, AC31). |
| `skills/ai-layout/scripts/check-risk.sh` | `command-counts-25` → derived `command-counts` (AC31, R8). |
| `ai-factory/docs/workflow.md` | 25 → 28 at lines 112 and 144; shortcut row in the command table near line 530; map-the-canonical-key note near line 669 (AC30, R4). |
| `README.md` | Count at line 31 → 28; the shortcut line beside `/fc:check` at line 46 (AC25, AC30). |
| `skills/ai-layout/SKILL.md` | Count at line 13 → 28 (AC31). |
| `docs/README.md`, `docs/installation.md` | Count 25 → 28 (AC31); `docs/README.md` line 3 → 5.1.0 (AC34). |
| `docs/headless-ci.md`, `docs/commands/_notes/sync-sdlc.md` | `TASK=<shortcut>` accepted without a notice; project `fc-<shortcut>` skills (AC13, AC8 docs). |
| `ai-factory/docs/architecture.md` | The "Owns the deprecated task names" paragraph rewritten (AC24). |
| `ai-factory/AGENTS.md`, `skills/ai-layout/templates/ai-factory/AGENTS.md` | `Slash commands:` line names the shortcuts (AC26). |
| `CHANGELOG.md` | 5.1.0 entry (AC33; R1, R3, R4, R10). |
| `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.agents/plugins/marketplace.json` | 5.0.1 → 5.1.0 (AC34). |

Not changed, and diffed in Step 12 to prove it: `commands/check.md` and `codex-skills/fc-check/SKILL.md` (AC6), `make/cost.js` and `make/lifecycle.js` (AC23), the `START_TASKS` classifier, and `ai-factory/specs/`.

## Server vs client components

Not applicable. There is no application code here: Node scripts and hooks run locally, alongside markdown prompts and docs.

## Steps

- [x] Step 1 — Gate: ASD-003's 5.0.1 is on `main`, and the feature branch starts from it (R8; precondition for AC27–AC31 and AC34)
  Effort: S · Estimate: dev 0.25–0.5 h, /fc:run ~5–10 min (assumption: no file changes; only git and check commands are run and their output recorded)
  - Refuse to continue (stop the run and report) if any of these fail: `git merge-base --is-ancestor 84ea88b HEAD`; `.claude-plugin/plugin.json` version is `5.0.1`; `skills/ai-layout/scripts/sync-docs.js`, `check-docs.sh` and `check-sync-docs.sh` exist.
  - Work on a feature branch created from that `main`. The uncommitted edit to `ai-factory/specs/ASD-004-command-shortcuts.md` is the developer's to commit; do not edit or reset it.
  - Record the baseline: run the full check suite and note any check that already fails before this change. Later steps compare against this list.
  - Tests: none new. Phase: `step`.
  - Verify (step): `git merge-base --is-ancestor 84ea88b HEAD`; `bash skills/ai-layout/scripts/check-versions.sh`; `bash skills/ai-layout/scripts/check-docs.sh`; `for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f" || echo "FAIL $f"; done`.

- [x] Step 2 — `TASK_SHORTCUTS`, `canonicalTask`, parser and doctor in `models.js` — AC1, AC2, AC3, AC16, AC17, AC18, AC19, AC20
  Effort: M · Estimate: dev 1.5–2.5 h, /fc:run ~15–30 min (assumption: size M, three files with tests; uncertainty S, it mirrors the existing `TASK_ALIASES` handling)
  - In `models.js`: add the table and update `canonicalTask`; leave `aliasNotice` reading only `TASK_ALIASES`. In the parser, write the shortcut duplicate message, push only `TASK_ALIASES` names to `routing.aliased`, and record shortcut keys in `routing.shortcuts`. Doctor gets the `ok` line. Export `TASK_SHORTCUTS`. Update the comment above the table so it describes both kinds.
  - Template `models.yaml` comment: a shortcut key is read as its target; map the target (R4).
  - Tests in `skills/ai-layout/scripts/check-model-selection.sh`:
    - `TASK_SHORTCUTS` is frozen and deep-equals the AC1 object, and `TASK_ALIASES` is unchanged (AC1).
    - `canonicalTask` maps the four names and passes `spec` through (AC2).
    - `aliasNotice` throws for each shortcut and returns the line for `check` (AC3).
    - `scout:` alone is stored under `explore`, `aliased` is `[]`, and `shortcuts` is `["scout"]` (AC16).
    - `ba:`+`analyse:`, `analyse:`+`ba:` and `ba:`+`analyze:` are each rejected with the line-numbered shortcut duplicate message naming `analyse` (AC17).
    - Doctor prints `ok|routing|routing.tasks.scout read as explore` with no `finding` and no "deprecated" or "rename" (AC18). A duplicate gives a `models` finding carrying the parse error (AC19). The `check` finding is unchanged (AC20).
    - Update the template `routing` deep-equal at line 44 if `shortcuts: []` is added to the parsed shape.
  - Verify (red): `bash skills/ai-layout/scripts/check-model-selection.sh`. Expected red: the first new assertion fails because `TASK_SHORTCUTS` is `undefined` (AC1). Running the remaining new cases one at a time, the expected failures are: `canonicalTask("ba")` returns `ba`; `aliasNotice("claude","ba")` already throws, which is not a red failure; `routing.tasks.scout` is stored as `scout`; `ba:`+`analyse:` parses; and doctor has no `read as explore` line.
  - Verify (step): `bash skills/ai-layout/scripts/check-model-selection.sh`; `bash skills/ai-layout/scripts/check-doctor.sh`; `node --check skills/ai-layout/templates/ai-factory/make/models.js`.

- [x] Step 3 — Runner and dispatch accept shortcuts without a notice — AC13, AC14, AC15
  Effort: M · Estimate: dev 1–2 h, /fc:run ~15–25 min (assumption: size M, a one-line runner change plus cases in two checks; uncertainty S)
  Depends on: 2
  - `runner.js`: write the deprecation line only when `Object.hasOwn(models.TASK_ALIASES, requested)`.
  - Tests:
    - `check-runner-security.sh`: in its fixture, add `analyse` and `explore` task files. For `TASK` in `ba`, `analyze` and `scout`, the run reads the target's task file and its model rules, and stderr does not match `/deprecated/` (AC13). The existing `TASK=check` loop still passes, and stderr has `runner: TASK=check is deprecated; running TASK=review` (AC14).
    - `check-interactive-model-routing.sh`: a new `check("shortcut names route to the target worker", …)`. On both hosts, `dispatch --task <shortcut>` stdout equals `dispatch --task <target>` stdout, and the dispatch records say the target (AC15).
  - Verify (red): `bash skills/ai-layout/scripts/check-runner-security.sh`. Expected red: for `TASK=ba`, stderr contains `runner: TASK=ba is deprecated; running TASK=analyse`, because Step 2 made `canonicalTask` resolve `ba` and the runner still tests `task !== requested`. `check-interactive-model-routing.sh` may already pass after Step 2; that is not a red failure.
  - Verify (step): `bash skills/ai-layout/scripts/check-runner-security.sh`; `bash skills/ai-layout/scripts/check-interactive-model-routing.sh`; `bash skills/ai-layout/scripts/check-review-scope.sh`.

- [x] Step 4 — Hook pins the union; cost and lifecycle count shortcuts under the target — AC21, AC22, AC23
  Effort: M · Estimate: dev 1–2 h, /fc:run ~15–25 min (assumption: size M, a hook line and cases in three checks; uncertainty S, `cost.js` and `lifecycle.js` already canonicalise)
  Depends on: 2
  - `log-task.js`: pin `const ALIASES = { check: "review", ba: "analyse", analyze: "analyse", scout: "explore" };` and update the comment above it. Do not change the regex (R7). In `skills/ai-hooks/SKILL.md` line 35, say that a shortcut is written as its target too.
  - Tests:
    - `check-codex.sh`: a new `check('a shortcut name attributes its target', …)`. Each AC21 prompt writes the name shown: `/fc:ba`, `/fc:analyze`, `$fc-ba`, `$fc-analyze`, `$fc:fc-ba` → `analyse`; `/fc:scout`, `$fc-scout`, `$fc:fc-scout` → `explore`; `/fc:check`, `$fc-check` → `review`. Change the pin assertion at line 67 to compare against `{ ...TASK_ALIASES, ...TASK_SHORTCUTS }` in the same serialisation, with a failure message that names both tables (AC22).
    - `check-cost.sh`: an inline fixture with rows labelled `ba`, `analyze`, `scout` and `analyse`. `grp … task` gives `analyse=3/… explore=1/…`, and the logged rows still read verbatim (AC23).
    - `check-lifecycle.sh`: events recorded with `--phase scout` and `--task ba`, and an old event with `phase: "ba"`, read as `explore` and `analyse` (AC23).
  - Verify (red): `bash skills/ai-hooks/fixtures/check-codex.sh`. Expected red: `/fc:ba` writes `ba`, not `analyse`, and the pin assertion fails with "log-task.js ALIASES differs …". `check-cost.sh` and `check-lifecycle.sh` cases pass already after Step 2; that is not a red failure, because they prove AC23 as regressions.
  - Verify (step): `bash skills/ai-hooks/fixtures/check-codex.sh`; `bash skills/ai-layout/scripts/check-cost.sh`; `bash skills/ai-layout/scripts/check-lifecycle.sh`; `for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done`.

- [x] Step 5 — Plugin generators: shortcut commands and skills, clash refusal, entry checks — AC4, AC5, AC6, AC7, AC9 (plugin), AC11 (generators), AC12 (generators)
  Effort: L · Estimate: dev 2–3 h, /fc:run ~25–40 min (assumption: size L, two generators, six generated entry points and two checks; uncertainty S, the alias pattern exists)
  Depends on: 2
  - Make the generator changes described under *Design → Plugin entry points* and *Clash refusal*. Regenerate with `node skills/ai-layout/scripts/sync-claude-commands.js` and `node skills/ai-layout/scripts/sync-codex-skills.js`.
  - Tests:
    - `check-start-routing.sh direct-entries-unchanged`: a `TASK_ALIASES` name must include `aliasNotice`. A `TASK_SHORTCUTS` name must not include it and must not match `/deprecated/i`. Any other name whose canonical differs fails. Every entry dispatches its canonical task with the target's unchanged `entryPreamble` (AC4, AC7, R6).
    - `check-plugin-hosts.sh`:
      - For each shortcut, `commands/<s>.md` and `codex-skills/fc-<s>/SKILL.md` exist. Their descriptions equal `Shortcut for /fc:<t> — <commands/<t>.md description>` and `Shortcut for $fc-<t> — <task description>`, and they load `ai-factory/tasks/<t>.md` (AC5, AC9).
      - On a scratch copy under `ai-factory/runs/tmp/` (the scripts, `models.js` and the task templates at the same relative paths) plus `tasks/ba.md`, each generator exits non-zero with `Task ba.md uses the shortcut name of analyse; rename the task file` and writes no `commands/ba.md` or `codex-skills/fc-ba/` (AC11). With `tasks/check.md` it fails with today's `uses the deprecated name of review` (AC12, generators).
    - AC6: `git diff --exit-code main -- commands/check.md codex-skills/fc-check/SKILL.md` exits 0.
  - Expected still-red after this step, fixed in Step 9: `check-docs.sh` (no pages for the three new commands; ungrouped), `check-risk.sh docs` (literal 25), and `check-continuation.sh` (README and `workflow.md` say 25, but `commands/` holds 28).
  - Verify (red): `bash skills/ai-layout/scripts/check-plugin-hosts.sh`. Expected red: `commands/ba.md does not exist` (AC4/AC5), and the scratch refusal case fails because the generator writes `commands/ba.md` for a `ba.md` task (AC11).
  - Verify (step): `bash skills/ai-layout/scripts/check-plugin-hosts.sh`; `bash skills/ai-layout/scripts/check-start-routing.sh`; `node skills/ai-layout/scripts/sync-claude-commands.js --check`; `node skills/ai-layout/scripts/sync-codex-skills.js --check`; `git diff --exit-code main -- commands/check.md codex-skills/fc-check/SKILL.md`.
  - **Amended 2026-11-02 by the developer, during `/fc:loop`:** Step 5 also updates the ASD-003 case `check-sync-docs.sh reader AC11-sync-scripts-untouched`. It asserted both generators unchanged since `86cf595`, which AC4 and AC7 make impossible, and no step owned it. It now requires both generators' `--check` to pass and `commands/check.md` and `codex-skills/fc-check/SKILL.md` to stay byte-identical to `84ea88b` (full SHA pinned as `PRE_ASD004`, the commit before this plan), so it needs no local `main` ref (review finding, fixed after the loop).

- [x] Step 6 — Project Codex shortcut skills and the shortcut clash in `sync-adapters.js` — AC8, AC9 (project), AC10, AC11 (sync-adapters)
  Effort: M · Estimate: dev 1.5–2.5 h, /fc:run ~20–30 min (assumption: size M, one template script and one check; uncertainty S, it copies the alias-skill block)
  Depends on: 2
  - Make the `sync-adapters.js` changes described under *Design → Project Codex skills* and *Clash refusal* (shortcut names only). Run `bash ai-factory/make/sync-adapters.sh --adapters=all` to refresh this repo's adapters.
  - Tests in `check-adapters.sh`:
    - The skill count is `tasks + aliases + shortcuts`, counting a name only when its target task exists. The final summary line names shortcuts too.
    - For each shortcut, `.codex/skills/fc-<s>/SKILL.md` has `name: fc-<s>` and the AC9 description, dispatches `--task <t>`, points at `ai-factory/tasks/<t>.md` (and `ai-factory/agents/<agent>.md` when the target delegates), contains neither the `aliasNotice` text nor "deprecated", and has no `.claude/commands/fc/<s>.md` (AC8, AC9, R6).
    - The existing `fc-check` assertions are unchanged (AC10 structure; the byte comparison is in Step 12).
    - On a scratch tree that copies `skills/ai-layout/templates/ai-factory`, add `tasks/scout.md`. `sync-adapters.sh` exits non-zero with `Task scout.md uses the shortcut name of explore; rename the task file`, and the adapter directories are as they were before the run (AC11).
    - The idempotence check at the top still holds.
  - Verify (red): `bash skills/ai-layout/scripts/check-adapters.sh`. Expected red: "18 tasks and 1 deprecated names but 19 codex skills" (or the updated count message) because no shortcut skill is written, and the scratch clash case exits 0.
  - Verify (step): `bash skills/ai-layout/scripts/check-adapters.sh`; `bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh`; `node --check skills/ai-layout/templates/ai-factory/make/sync-adapters.js`; `bash skills/ai-layout/scripts/check-doctor.sh`.

- [x] Step 7 — AC12 in `sync-adapters.js`: deprecated task-file name keeps today's skip (R2 option b) — AC12 (sync-adapters)
  Effort: S · Estimate: dev 0.5–1 h, /fc:run ~10–15 min (assumption: size S, one branch in one script and one case in one check; uncertainty S once the spec picks an option)
  Depends on: 6
  - **Unblocked 2026-11-02:** the developer chose option (b) for R2 and AC12 is amended to match. Implement option (b) only; option (a) below is kept as the rejected alternative.
  - Option (a), a new refusal: `sync-adapters.js` throws `Task check.md uses the deprecated name of review; rename the task file` before writing, and Step 11's CHANGELOG names it as breaking. Test: a scratch-tree case in `check-adapters.sh` with `tasks/check.md` exits non-zero with that message and changes no adapters.
  - Option (b), keep today's behaviour: no code change. Test: the same scratch case with `tasks/check.md` exits 0, writes `.codex/skills/fc-check/` from the project `check.md` task, not the alias skill, and the run writes no deprecation refusal.
  - Verify (red): `bash skills/ai-layout/scripts/check-adapters.sh`. Expected red under (a) only: the `check.md` scratch case exits 0. Under (b) the case passes at once, which is not a red failure.
  - Verify (step): `bash skills/ai-layout/scripts/check-adapters.sh`.

- [x] Step 8 — `sync-docs.js` recognises shortcuts and waives their notes — AC27 (generator), AC29
  Effort: M · Estimate: dev 1–2 h, /fc:run ~15–25 min (assumption: size M, the generator and its fixture check; uncertainty S, it mirrors `deprecatedFor`)
  Depends on: 1
  - `sync-docs.js`: add `shortcutFor` from the description prefix and the page line `> **Shortcut.** Runs [\`/fc:<t>\`](<t>.md) under a shorter name.`. Change `requiredFor` to take the command and return `["Usage"]` when `deprecatedFor || shortcutFor`. Keep the `./_frontmatter.js`-only require rule.
  - Tests in `check-sync-docs.sh`: add the fixture command `ba` (`Shortcut for /fc:run — Implement one step of a plan`, so it points at a fixture target) and a group row for it.
    - `generate AC27-shortcut-page`: the page marks the command as a shortcut and links `run.md`, and its kind is taken from its target (`run` is a project task, so the page says project task, not plugin-level; R13, amended AC27).
    - `generate AC27-deprecated-kind-from-target`: the `check` fixture page takes its kind from `review` (project task), not plugin-level.
  - `sync-docs.js` kind: when a command is a shortcut or deprecated alias, decide its kind from the target's task file, not from its own name.
    - `notes AC29-shortcut-usage-only-ok`: Usage-only notes pass, an empty Usage fails, and the existing `AC25-check-usage-only-ok` still passes.
    - `notes AC29-non-shortcut-still-needs-four`: dropping `## Examples` from `review` still fails.
    - Update every existing case's expected counts or fixture lists that change with the sixth fixture command.
  - Verify (red): `bash skills/ai-layout/scripts/check-sync-docs.sh generate` and `bash skills/ai-layout/scripts/check-sync-docs.sh notes`. Expected red: `AC27-shortcut-page` fails with no shortcut marker or no link to `run.md`, and `AC29-shortcut-usage-only-ok` fails because `--check` reports `docs/commands/_notes/ba.md has no "## Examples" heading`.
  - Verify (step): `bash skills/ai-layout/scripts/check-sync-docs.sh`; `node --check skills/ai-layout/scripts/sync-docs.js`.

- [x] Step 9 — Real docs tree: notes, groups, generated pages and the command count of 28 — AC27, AC28, AC30, AC31
  Effort: L · Estimate: dev 1.5–2.5 h, /fc:run ~20–35 min (assumption: size L, more than five files and three new notes; uncertainty S, the generator is proven by Step 8)
  Depends on: 5, 8
  - Write `docs/commands/_notes/{ba,analyze,scout}.md`, each with `## Usage` and nothing else. Each one links `analyse.md` or `explore.md` and says it is the same task, not deprecated (AC28). Add the three to `_groups.md` in *Decide before building*. Run `node skills/ai-layout/scripts/sync-docs.js`.
  - Counts 25 → 28: `README.md` line 31, `ai-factory/docs/workflow.md` lines 112 and 144 (the "18 project task entry points" stays), `skills/ai-layout/SKILL.md` line 13, `docs/README.md` line 40, `docs/installation.md` line 41 (AC30, AC31).
  - `check-risk.sh`: rename `command-counts-25` to `command-counts`, remove the literal `25`, and add the composition assertion described under *Design → Counts* (R8).
  - Tests: `check-risk.sh docs command-counts`, `check-continuation.sh` (derived README and workflow counts), and `check-docs.sh` (pages current, notes valid, no ungrouped command, links resolve).
  - Verify (red): `bash skills/ai-layout/scripts/check-docs.sh`. Expected red (left by Step 5): `docs/commands/ba.md` and the other two pages are missing, `ba`/`analyze`/`scout` are in no group, and `docs/commands.md` is stale. Also `bash skills/ai-layout/scripts/check-risk.sh docs`. Expected red: `commands/ holds 28 commands, not 25`.
  - Verify (step): `bash skills/ai-layout/scripts/check-docs.sh`; `bash skills/ai-layout/scripts/check-risk.sh`; `bash skills/ai-layout/scripts/check-continuation.sh`; `bash skills/ai-layout/scripts/check-sync-docs.sh`; `bash skills/ai-layout/scripts/check-paths.sh`.

- [x] Step 10 — Prose: architecture, README, both `AGENTS.md`, workflow, headless and sync notes — AC24, AC25, AC26
  Effort: M · Estimate: dev 1–1.5 h, /fc:run ~15–20 min (assumption: size M, about seven prose edits and no new test; uncertainty S, wording only)
  Depends on: 9
  - `architecture.md` paragraph: one alias table in `make/models.js` with two kinds, deprecated (`check` → `review`) and shortcut (`ba`, `analyze` → `analyse`; `scout` → `explore`). Only deprecated names get the notice, and `log-task.js` pins the union of both kinds (AC24).
  - `README.md` line 46: one line mapping `/fc:ba` and `/fc:analyze` to `/fc:analyse` and `/fc:scout` to `/fc:explore`, with `$fc-ba`, `$fc-analyze` and `$fc-scout`, not called deprecated. Add a note to map the canonical key in `models.yaml` (AC25, R4).
  - Both `Slash commands:` lines name the shortcuts as shortcuts of `/fc:analyse` and `/fc:explore`, keep one such line each, and stay under 60 lines (AC26; the `check-risk.sh agents-md-lists-risk` rule).
  - `workflow.md`: a shortcut row next to the `/fc:check` row near line 530; the TASK and routing notes near lines 602 and 669. `docs/headless-ci.md`: `TASK=ba|analyze|scout` run the target with no notice. `docs/commands/_notes/sync-sdlc.md`: list the `fc-<shortcut>` project skills, then rerun `sync-docs.js`.
  - Tests: no new test. The AC24–AC26 wording is checked by reading the files in Step 12. Existing phrase checks must stay green.
  - Verify (step): `bash skills/ai-layout/scripts/check-risk.sh`; `bash skills/ai-layout/scripts/check-continuation.sh`; `bash skills/ai-layout/scripts/check-docs.sh`; `bash skills/ai-layout/scripts/check-paths.sh`; `bash skills/ai-layout/scripts/check-workspace.sh`.

- [x] Step 11 — Release 5.1.0: CHANGELOG and every version field — AC33, AC34
  Effort: M · Estimate: dev 0.5–1 h, /fc:run ~10–20 min (assumption: size M, six files and no check change; uncertainty S, a mechanical bump on the 5.0.1 pattern)
  - New top `## 5.1.0` entry. It must:
    - list the three shortcuts and their targets and say they are not deprecated;
    - mark the template change **breaking for adopted repos**;
    - say that `TASK=<shortcut>`, `routing.tasks` shortcut keys and project `$fc-<shortcut>` skills arrive only after `/fc:sync-sdlc` (AC33, R4).
  - The entry also names:
    - the R1 refusal: the exact `Task <name>.md uses the shortcut name of <target>; rename the task file` message and the rename step;
    - the R10 duplicate-key parse failure and its fix;
    - that shortcuts are a stable public name, so a later retirement goes through `TASK_ALIASES` (R3);
    - the Step 7 outcome for `check.md` under R2.
  - Set `5.1.0` in `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, both marketplace plugin entries, and `docs/README.md` line 3 (AC34). Rerun `sync-docs.js` if any generated page carries the version.
  - Tests: `check-versions.sh` (all fields agree), `check-release-docs.sh` (entry ties to the manifests), and `check-docs.sh` (version line).
  - Verify (red): `bash skills/ai-layout/scripts/check-release-docs.sh`. Expected red, if it ties the top entry to the manifest version: after the manifests are bumped and before the entry is written, it reports no `5.1.0` entry. Otherwise there is no red phase.
  - Verify (step): `bash skills/ai-layout/scripts/check-versions.sh`; `bash skills/ai-layout/scripts/check-release-docs.sh`; `bash skills/ai-layout/scripts/check-docs.sh`.

- [x] Step 12 — Final verification and MR evidence — AC6, AC10, AC24, AC25, AC26, AC32, AC34
  Effort: S · Estimate: dev 0.5–1 h, /fc:run ~15–25 min (assumption: size S, no files change; uncertainty S)
  - Run every command under *Verification → final*.
  - AC10 byte comparison: in a `git worktree` of `main` under `ai-factory/runs/tmp/`, run `bash ai-factory/make/sync-adapters.sh --adapters=codex` and compare its `.codex/skills/fc-check/SKILL.md` with this branch's using `cmp`. Remove the worktree afterwards.
  - Read the AC24–AC26 paragraphs against the spec wording, and record the result.
  - Prepare the MR text. Per `ai-factory/AGENTS.md`, it needs a before and after run: `/fc:ba`, `$fc-scout` and `make ai TASK=scout` on this branch, and `/fc:check` unchanged. It also needs a "breaking for adopted repos" line.
  - Phase: `final`.

## Risks and how each is checked

| Risk | Check |
|---|---|
| R1 (major): adopted repos with a `ba.md`, `analyze.md` or `scout.md` task stop syncing. | Steps 5 and 6 test the refusal message and that nothing is written. Step 11's CHANGELOG names the message and the rename step. The doctor pre-warning is not required by the spec, so it is not planned. |
| R2 (major): AC12 adds a new `sync-adapters.js` refusal when read literally. | Step 7 is blocked until the spec chooses (a) or (b). Steps 5 and 6 do not touch that `check.md` path. |
| R3 (minor): shortcuts cannot be cleanly removed later. | Step 11's CHANGELOG says they are stable public names, retired through `TASK_ALIASES`. |
| R4 (minor): version skew in unsynced repos. | AC33's "only after `/fc:sync-sdlc`" sentence, plus map-the-canonical-key notes in `models.yaml`, README and `workflow.md` (Steps 2, 10, 11). |
| R5 (minor): the hook table drifts. | Step 4 changes `check-codex.sh` to compare against the union (AC22). |
| R6 (minor): relaxed checks let a deprecated alias that lost its notice pass. | Steps 5 and 6 branch on the source table. A `TASK_ALIASES` name still needs its notice, and an unknown differing name fails. |
| R7 (minor): the hook regex is not anchored. | Not changed (the spec says "regex unchanged"). Step 4 tests only prompts that start with the form. Listed as an ambiguity. |
| R8 (major): depends on ASD-003, and literal counts. | Step 1 gate. Step 9 replaces the literal `25` in `check-risk.sh` with a derived count. `check-continuation.sh` and the `sync-docs.js` index already derive theirs. |
| R9 (minor): `/fc:analyze` and `/fc:analyse` look alike. | The AC5 description prefix, asserted in Step 5. |
| R10 (minor): a duplicate key stops every run after sync. | AC17 and AC19 cases in Step 2, and the CHANGELOG line in Step 11. |
| `aliasNotice`-based checks start failing for shortcut entries. | Step 5 `check-start-routing.sh`, and the full suite in Step 12. |
| Parallel `/fc:loop` steps edit the same file. | Steps 3–6 and 8 each own different check files. Step 10 waits for Step 9 because they share `README.md` and `workflow.md`. Step 11 waits for everything. |

## Verification

| Phase | Command | ACs | Expected red (identity → cause) |
|---|---|---|---|
| red (Step 2) | `bash skills/ai-layout/scripts/check-model-selection.sh` | AC1–AC3, AC16–AC20 | table assertion → `TASK_SHORTCUTS` undefined; scout key → stored as `scout`; `ba`+`analyse` → parses; doctor → no `read as explore` line |
| red (Step 3) | `bash skills/ai-layout/scripts/check-runner-security.sh` | AC13 | `TASK=ba` stderr → contains `is deprecated` |
| red (Step 4) | `bash skills/ai-hooks/fixtures/check-codex.sh` | AC21, AC22 | `/fc:ba` → writes `ba`; pin assertion → differs from the union |
| red (Step 5) | `bash skills/ai-layout/scripts/check-plugin-hosts.sh` | AC4, AC5, AC7, AC9, AC11 | `commands/ba.md` missing; scratch `ba.md` task → generator writes instead of refusing |
| red (Step 6) | `bash skills/ai-layout/scripts/check-adapters.sh` | AC8, AC9, AC11 | skill count off by three; scratch `scout.md` → exit 0 |
| red (Step 7) | `bash skills/ai-layout/scripts/check-adapters.sh` | AC12 | under option (a) only: scratch `check.md` → exit 0 |
| red (Step 8) | `bash skills/ai-layout/scripts/check-sync-docs.sh generate`, `bash skills/ai-layout/scripts/check-sync-docs.sh notes` | AC27, AC29 | `AC27-shortcut-page` → no marker or link; `AC29-shortcut-usage-only-ok` → missing `## Examples` reported |
| red (Step 9) | `bash skills/ai-layout/scripts/check-docs.sh`, `bash skills/ai-layout/scripts/check-risk.sh docs` | AC27, AC28, AC31 | missing pages, ungrouped commands; `commands/ holds 28 commands, not 25` |
| step | per step, as listed in each step | per step | — |
| final | `git merge-base --is-ancestor 84ea88b HEAD` | AC34 | — |
| final | `for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f" \|\| echo "FAIL $f"; done` (never piped to `tail`) | AC32 and every AC with a test | none; any `FAIL` line not in Step 1's baseline blocks completion |
| final | `node skills/ai-layout/scripts/sync-claude-commands.js --check`; `node skills/ai-layout/scripts/sync-codex-skills.js --check`; `node skills/ai-layout/scripts/sync-docs.js --check` | AC4, AC7, AC27 | — |
| final | `git diff --exit-code main -- commands/check.md codex-skills/fc-check/SKILL.md skills/ai-layout/templates/ai-factory/make/cost.js skills/ai-layout/templates/ai-factory/make/lifecycle.js` | AC6, AC23 | — |
| final | the `cmp` of `fc-check` against a `main` worktree (Step 12) | AC10 | — |
| final | `for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done`; `bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh`; `bash ai-factory/make/sync-adapters.sh` run twice with no diff | AC32 | — |
| final | `bash skills/ai-layout/scripts/check-versions.sh` | AC34 | — |

Final completion requires every `final` row to pass, and Step 7 to be resolved: either run under the R2 decision, or the spec amended so that it is not needed.

## Open questions (from the spec, carried as ambiguities)

1. **R2 / AC12 blocks Step 7.** Does `sync-adapters.js` gain a new refusal for a `check.md` task, option (a), or keep today's skip, option (b)? The plan does not guess. Step 7 holds both outcomes and must not run until the spec is amended.
2. **R1 doctor pre-warning.** The spec does not require it, so it is not planned. The CHANGELOG carries the message and the rename step.
3. **R7 / AC21 "starts with".** The hook regex matches anywhere in the prompt, and the spec says it is unchanged. Step 4 tests only prompts that start with a form, and does not anchor the regex.
4. **AC31 "expect 28".** The plan derives the count from `commands/` instead of the literal 28, per R8. The prose states 28.
5. **AC27–AC31 "on rebase".** ASD-003 is already merged on `main` (5.0.1, `84ea88b`), so there is no rebase. Step 1 checks this, and the feature branch starts from that `main`.
6. **Not stated in the spec.** The `argument-hint` of a shortcut entry point, and which docs group the shortcuts go in. The plan copies the target's hint, as `/fc:check` does, and puts the shortcuts in *Decide before building*.

## MR description

**ASD-004: command shortcuts `/fc:ba`, `/fc:analyze`, `/fc:scout` (release 5.1.0)**

### Summary

- Adds three shortcuts that are not deprecated: `/fc:ba` and `/fc:analyze` (`$fc-ba`, `$fc-analyze`) run `/fc:analyse`, and `/fc:scout` (`$fc-scout`) runs `/fc:explore`. Each one runs its target's task file and shows no notice.
- The names come from one `TASK_SHORTCUTS` table in `make/models.js`, kept beside the unchanged `TASK_ALIASES` (`check` → `review`). `canonicalTask` resolves both. Only `TASK_ALIASES` names get the deprecation notice, the runner's stderr line, `routing.aliased` and the doctor finding.
- Shortcuts are handled in every place that takes a task name:
  - plugin commands and skills (`commands/{ba,analyze,scout}.md`, `codex-skills/fc-{ba,analyze,scout}/`)
  - project Codex skills (`sync-adapters.js`)
  - the headless runner (`TASK=ba|analyze|scout` with no notice)
  - `models.yaml` routing, where a shortcut key is read as its target, and mapping both is a parse error
  - doctor, which prints an `ok` line for a shortcut key
  - the `log-task.js` hook, which pins the union of both tables
  - cost and lifecycle, which count a shortcut under its target
  - the generated user docs
- The command count goes from 25 to 28 in the docs. `check-risk.sh` now works the count out from `commands/` instead of using the literal 25.

### Release and blast radius

- Version **5.1.0** in `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, the `.claude-plugin/marketplace.json` plugin entry and `docs/README.md` line 3. The CHANGELOG has a `## 5.1.0` entry.
- **Breaking for adopted repos.** These templates change: `make/models.js`, `make/runner.js`, `make/sync-adapters.js`, the `models.yaml` comment and the `AGENTS.md` `Slash commands:` line. Adopted repos get them through `/fc:sync-sdlc`.
- **R1:** sync and both plugin generators now refuse a task file named `ba.md`, `analyze.md` or `scout.md`, with `Task <name>.md uses the shortcut name of <target>; rename the task file`, and write nothing. An affected repo must rename that file before it syncs.
- **R10:** a `models.yaml` that maps a shortcut and its target, or two shortcuts of one target, fails to parse and stops routed runs until the extra key is removed.
- In an unsynced repo, `TASK=<shortcut>`, shortcut routing keys and the project `$fc-<shortcut>` skills arrive only after `/fc:sync-sdlc`.

### Final verification (Step 12, run directly, not piped)

| Command | ACs | Exit |
|---|---|---|
| `git merge-base --is-ancestor 84ea88b HEAD` | AC34 | 0 |
| `for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f" \|\| echo "FAIL $f"; done` (38 checks, each exit recorded) | AC32 and every AC with a test | 0 for all 38, no `FAIL` line |
| `node skills/ai-layout/scripts/sync-claude-commands.js --check` | AC4 | 0 ("Claude task command wrappers verified: 21") |
| `node skills/ai-layout/scripts/sync-codex-skills.js --check` | AC7 | 0 ("Codex skills verified: 30") |
| `node skills/ai-layout/scripts/sync-docs.js --check` | AC27 | 0 ("User command docs current: 29") |
| `git diff --exit-code main -- commands/check.md codex-skills/fc-check/SKILL.md skills/ai-layout/templates/ai-factory/make/cost.js skills/ai-layout/templates/ai-factory/make/lifecycle.js` | AC6, AC23 | 0 |
| `cmp` of `.codex/skills/fc-check/SKILL.md` from `sync-adapters.sh --adapters=codex` in a `main` worktree (`ai-factory/runs/tmp/`, removed afterwards) with this branch's | AC10 | 0 |
| `git diff --exit-code main -- .codex/skills/fc-check/SKILL.md` | AC10 | 0 |
| `for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done` | AC32 | 0, no failures |
| `bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh` | AC32 | 0 |
| `bash ai-factory/make/sync-adapters.sh` twice, plus `--adapters=all` twice; adapter file hashes compared | AC32 | 0 each; no diff between the runs |
| `bash skills/ai-layout/scripts/check-versions.sh` | AC34 | 0 ("3 manifests and docs/README.md all at 5.1.0") |

AC24–AC26 were checked by reading the text against the spec:
- `architecture.md` describes one alias table with two kinds. It says only deprecated names get the notice, and that `log-task.js` pins the union.
- `README.md` line 46 maps `/fc:ba`, `/fc:analyze` and `/fc:scout` with their `$fc-` forms, and does not call them deprecated.
- Both `Slash commands:` lines name the three as shortcuts of `/fc:analyse` and `/fc:explore`.

### Before/after runs

- Not attached yet; the developer must link them, as `ai-factory/AGENTS.md` requires. The runs to attach:
  - `/fc:ba` and `$fc-scout` on this branch.
  - `make ai TASK=scout` on this branch, which runs the explore task with no deprecation line.
  - `/fc:check` unchanged against `main`: it still prints the deprecation notice and runs review.
- Test evidence for the same behaviour:
  - `check-runner-security.sh`: `TASK=ba|analyze|scout` run the target with no `deprecated` on stderr, and `TASK=check` still reports it.
  - `check-interactive-model-routing.sh`: `dispatch --task <shortcut>` output equals the target's, except for the random dispatch ID.

### Known deviations

- **R2:** the developer chose option (b). AC12 was amended so `sync-adapters.js` keeps today's `check.md` behaviour. Step 7's test therefore passed with no red phase.
- **Step 5:** by the developer's decision during the loop, it also updated the ASD-003 case `check-sync-docs.sh reader AC11-sync-scripts-untouched`. That case asserted the generators were unchanged since 86cf595. It now checks both generators' `--check` and AC6 byte-identity. The now-unused `BASELINE` constant in `check-sync-docs.sh` was left in place.
- **Step 3:** a shortcut's dispatch stdout equals its target's except for the random dispatch ID, which the test masks.
- **Steps 8 and 9:** the docs index line counts 18 project tasks, 4 shortcut-or-deprecated names and 6 plugin-level. The plan's Design said 10 plugin-level, written before AC27 was amended.
- **Step 9:** it also updated the count in `skills/ai-layout/SKILL.md`, which AC30 does not list.
- **AC34:** it names a version field in `.agents/plugins/marketplace.json` that does not exist. The three manifests plus `docs/README.md` carry 5.1.0.
- **AC17:** its wording ("the second key is its shortcut name") does not hold when the shortcut comes first. The error names whichever key is the shortcut.
- **Step 1:** its text mentions an uncommitted spec edit that was already committed (7ae2e99).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
