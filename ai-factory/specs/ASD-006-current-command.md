# ASD-006 — Command /fc:current — plans in progress
Created: 2026-11-02T18:25:02.699Z

`/fc:current` is a read-only, plugin-level command that shows only the plans actually under way, as a compact table with each plan's progress and the next step to pick up. It is available as a Claude command (`/fc:current`), a Codex skill (`$fc-current`) and a generated user docs page.

No parent exploration or analysis exists for this feature. The developer answered the shape and surface questions in this session, and those answers are the requirements below. `ai-factory/specs/ASD-004-command-shortcuts.md` and its plan `ai-factory/plans/ASD-004-command-shortcuts.md` are cited only as context: ASD-004 lands first as 5.1.0, and this feature rebases onto it.

## User story
As a developer using the ai-sdlc plugin, I want one command that shows only the plans I have started but not finished, each with its progress and the next step to pick up. That way I can see what is in progress without scanning past every spec and plan that has not been started yet.

## Acceptance criteria
These criteria use the following terms:
- A **plan** is a file `ai-factory/plans/*.md`, not one under `ai-factory/plans/done/`. Its steps are its `- [ ] Step N — …`, `- [x] Step N — …` and `- [~] Step N — …` lines.
- A **ticked** step is `- [x]`, a **started** step is `- [~]` and an **unticked** step is `- [ ]`.
- A **withdrawn** step is one the plan records as `**Result — Step N withdrawn; …**`, the record `skills/ai-layout/scripts/state.sh` reads.
- An **open** step is a step that is not ticked and not withdrawn, so it is either started or unticked.
- A plan is **in progress** when it has at least one ticked or started step and at least one open step.
- A **runnable** step is an open step that `/fc:loop`'s rule in `skills/ai-layout/templates/ai-factory/make/loop.js` would start. Under that rule, every step it waits for must be ticked. It waits for the steps on its `Depends on: N, M` line, or for every earlier step when it has no such line.
- The **next step** of an in-progress plan is its first runnable step in file order. When the plan has no runnable step, the next step is its first open step in file order.
- **Progress** is the number of ticked steps over the number of steps that are not withdrawn. A started step adds nothing to the first number.

**What it lists**
- **AC1.** Given a plan with no `Depends on:` lines whose steps are, in file order, two ticked steps followed by two unticked steps, when `/fc:current` runs, then the output has one row for that plan. The row shows the plan ID, its path, progress `2/4`, and Step 3's number and title as the next step.
- **AC2.** Given a plan with one started step, two unticked steps and no ticked step, when `/fc:current` runs, then that plan is listed.
- **AC3.** Given a plan with no `Depends on:` lines whose steps are three ticked steps followed by one started step, with no unticked step, when `/fc:current` runs, then that plan is listed. Its progress is `3/4` and its next step is the started Step 4.
- **AC4.** Given a plan whose every step is unticked, when `/fc:current` runs, then that plan is not in the output.
- **AC5.** Given a plan whose every step is ticked, when `/fc:current` runs, then that plan is not in the output.
- **AC6.** Given a plan whose steps are ticked except for unticked steps that are withdrawn, when `/fc:current` runs, then that plan is not in the output.
- **AC7.** Given a spec that no plan names in its `Spec:` line, when `/fc:current` runs, then neither that spec nor any row for it is in the output.
- **AC8.** Given a plan under `ai-factory/plans/done/` with one ticked and one unticked step, when `/fc:current` runs, then that plan is not in the output.
- **AC9.** Given a repo with these files:
  - two in-progress plans;
  - one plan with no ticked or started step;
  - one plan with every step ticked;
  - one spec with no plan.

  When `/fc:current` runs, then the table has exactly two rows, one per in-progress plan, and nothing else is listed.
- **AC10.** Given a plan with Steps 1–4 where Step 1 is ticked and Steps 2–4 are unticked, with Step 2 carrying `Depends on: 4` and Step 3 carrying `Depends on: 1`, when `/fc:current` runs, then the next step shown for that plan is Step 3.
- **AC11.** Given a plan with Steps 1–3 where Step 1 is ticked, Step 2 is started with no `Depends on:` line, and Step 3 is unticked with `Depends on: 1`, when `/fc:current` runs, then the next step shown is Step 2, the started step.
- **AC12.** Given a plan with Steps 1–4 with these states:
  - Step 1 is ticked;
  - Step 2 is unticked and withdrawn;
  - Steps 3 and 4 are unticked and each carries `Depends on: 2`, so no open step is runnable.

  When `/fc:current` runs, then the next step shown is Step 3, the first open step in file order.
- **AC13.** Given a plan of 12 steps where 4 are ticked, 2 are started, 1 is withdrawn and 5 are unticked, when `/fc:current` runs, then its progress reads `4/11`.
- **AC14.** Given an in-progress plan, when its row is read, then the row names only that plan's next step, not every open step.
- **AC15.** Given two in-progress plans `ai-factory/plans/ASD-006-b.md` and `ai-factory/plans/ASD-004-a.md`, whichever was created or changed last, when `/fc:current` runs twice, then both times the ASD-004 row comes before the ASD-006 row, and the two outputs are identical.

**Empty, missing and unreadable**
- **AC16.** Given a repo with `ai-factory/plans/` where no plan is in progress, when `/fc:current` runs, then the output is exactly one line saying that no plan is in progress, no table is printed, and the exit status is 0.
- **AC17.** Given a git repo with no `ai-factory/plans/` directory, when `/fc:current` runs, then the output is exactly one line explaining that there is no `ai-factory/plans/` directory, no table is printed, and the exit status is 0.
- **AC18.** Given a plan in `ai-factory/plans/` with either of these faults, when `/fc:current` runs, then the table has a row for that plan with its path and a one-line reason, and no next step for it:
  - a step line whose marker is not `[ ]`, `[x]` or `[~]`;
  - a `Depends on:` line that is not a comma-separated list of step numbers.
- **AC19.** Given the repo of AC9 plus one plan as in AC18, when `/fc:current` runs, then the two in-progress plans are listed as in AC9. The unreadable plan has its own reason row; it is neither left out nor shown as in progress.

**Argument**
- **AC20.** Given two in-progress plans, one whose `Spec:` line names spec `ASD-900` and one naming another spec, when `/fc:current --spec ASD-900` runs, then the table lists only the plan whose `Spec:` line names `ASD-900`.
- **AC21.** Given a repo where no plan's `Spec:` line names `ASD-901`, when `/fc:current --spec ASD-901` runs, then the output is exactly one line explaining that no plan belongs to `ASD-901`, no table is printed, and the exit status is 0.
- **AC22.** Given any other argument, such as `--done` or `ASD-900` without `--spec`, when `/fc:current` runs with it, then the output is one line that refuses the argument and names `--spec <id>` as the only accepted one, and no table is printed.

**Read-only**
- **AC23.** Given the repo of AC9 under git with a clean working tree, when `/fc:current` runs, then `git status --porcelain` is still empty afterwards, and no file under `ai-factory/` has changed.
- **AC24.** Given `commands/current.md`, when it is read, then it tells the model to run only the listing script, as `commands/state.md` does. It also tells the model to change nothing, to launch no agent or subagent, to invoke no other command or skill, and to ask the developer nothing.
- **AC25.** Given the repo of AC9, when `/fc:current` runs twice, then both outputs are identical. One run has no `/fc:run` or `/fc:loop` session running. The other has run or loop state under `ai-factory/runs/`, for example a loop's directory under `ai-factory/runs/tmp/loop/`.

**Implementation boundary**
- **AC26.** Given the feature's diff against the `main` it branches from, when it is read, then the listing is done by a new script under `skills/ai-layout/scripts/` beside `state.sh`. `commands/state.md`, `skills/ai-layout/scripts/state.sh` and `codex-skills/fc-state/SKILL.md` are byte-for-byte unchanged.
- **AC27.** Given the feature's diff against the `main` it branches from, when it is read, then no file under `skills/ai-layout/templates/` has changed and no `ai-factory/tasks/current.md` exists.
- **AC28.** Given a git repo with an in-progress plan in `ai-factory/plans/` but no adopted workspace (no `ai-factory/make/` and no `ai-factory/tasks/`), when `/fc:current` runs, then it lists that plan.

**Surfaces**
- **AC29.** Given the plugin, when its commands are listed, then `commands/current.md` exists, and `/fc:current` run in the repo of AC9 gives the listing of AC9.
- **AC30.** Given the plugin, when `node skills/ai-layout/scripts/sync-codex-skills.js --check` runs, then it passes and `codex-skills/fc-current/SKILL.md` exists. `$fc-current` run in the repo of AC9 gives the listing of AC9.
- **AC31.** Given `commands/current.md` and `codex-skills/fc-current/SKILL.md`, when their frontmatter `description` is read, then neither calls the command a shortcut or an alias of `/fc:state` or `$fc-state`.
- **AC32.** Given `docs/commands/_notes/current.md`, when it is read, then it has the four headings that `sync-docs.js` requires (`## Usage`, `## Examples`, `## Writes`, `## Refuses or asks`), each with non-empty content.
- **AC33.** Given `docs/commands/_notes/_groups.md`, when it is read, then `current` appears in the backticked command list of the "Entry and resume" group and of no other group.
- **AC34.** Given `node skills/ai-layout/scripts/sync-docs.js`, when it runs, then it writes `docs/commands/current.md`, which labels `/fc:current` a plugin-level command, and lists `/fc:current` in `docs/commands.md`. After that, `bash skills/ai-layout/scripts/check-docs.sh` exits 0.
- **AC35.** Given a Claude Code session in a repo with `ai-factory/` and the plugin's hooks, when the developer's prompt is `/fc:current`, then `skills/ai-hooks/scripts/log-task.js` records `current` as the session's task, the same way it records any other command name. The same holds for the Codex prompt `$fc-current`.
- **AC36.** Given `/fc:start` and its routing table, when any request is classified, then `current` is never the destination, and `bash skills/ai-layout/scripts/check-start-routing.sh` exits 0.

**Project rules (ai-factory/docs/definition-of-done.md) and release**
- **AC37.** Given the full check suite (`skills/ai-layout/scripts/check-*.sh` and `skills/ai-hooks/fixtures/check-*.sh`), when each check is run directly, then every one exits 0.
- **AC38.** Given `README.md`, `ai-factory/docs/workflow.md`, `docs/installation.md`, `docs/README.md` and the generated `docs/commands.md`, when their statements of the number of `/fc:*` commands are read, then each equals the number of files in `commands/`. Following the derived-from-`commands/` rule that ASD-004 introduces, no check this feature adds or edits compares that number with a literal.
- **AC39.** Given `README.md`, when its command list is read, then it names `/fc:current` and its Codex form `$fc-current` (definition of done, item 7).
- **AC40.** Given this feature's branch, when it is compared with `main`, then it branches from a `main` that already contains ASD-004's 5.1.0 release. `bash skills/ai-layout/scripts/check-versions.sh` exits 0 with every manifest and the `docs/README.md` version line on `5.2.0`.
- **AC41.** Given `CHANGELOG.md`, when its 5.2.0 entry is read, then it describes `/fc:current` and `$fc-current` as a plugin-level, read-only command with no headless form. It states that the change is not breaking for adopted repos because no template changes.

## Out of scope
- Any change to what `/fc:state` lists, its flags, its refusals, its messages or its output, and any change to `state.sh` (AC26).
- A headless form. That means no `make ai TASK=current`, no change to the runner, `models.js`, `models.yaml` routing or a task template, and no `ai-factory/tasks/current.md` in adopted repos.
- A live view of a running `/fc:run` or `/fc:loop` session: its process, worktrees, progress within a step or run log.
- Listing specs, plans that have not been started, finished plans, plans under `ai-factory/plans/done/`, or a "done" view.
- Starting, ticking or handing off a step, and any other write.
- Contract deliveries (`/fc:state --delivery`) and `/fc:continue`.
- Routing from `/fc:start` to `current`.
- The shortcuts of ASD-004, and any shortcut or alias for `/fc:current`.

## Effort and risk
Effort **L**.
- Size is L: more than 5 files and a new artefact. The files are:
  - a new listing script and its check fixtures;
  - `commands/current.md` and the generated Codex skill;
  - the notes file, `_groups.md` and the generated docs;
  - the count statements, `README.md`, `CHANGELOG.md` and the version files.
- Uncertainty is M. The pattern is known: `state.sh` already parses step marks, withdrawn records and `Spec:` lines, and `loop.js` already defines the runnable rule. The listing rules are settled. The minor unknown is the rebase onto ASD-004's derived count checks.

Time ranges:
- `dev 5–9 h (assumption: the listing script with its runnable-step rule, sort order and fixtures takes 3–5 h; the command, Codex skill, notes and generated docs 1–2 h; and the counts, README, CHANGELOG and 5.2.0 version bump after rebasing onto ASD-004 1–2 h)`
- `/fc:run ~40–80 min (assumption: 4–5 plan steps, with the Codex skill and docs regenerated in one step)`

Risk categories:
- Authorization: **absent**. The command reads plan files in the developer's own repo; no access path or permission changes.
- Data exposure: **absent**. It prints plan IDs, paths and step titles that are already in the repo, as `/fc:state` does. It has no headless form that would put them in a CI log.
- Secrets: **absent**. No credential is read, written or passed.
- Injection: **present**. The `--spec <id>` argument crosses into a Bash call the way `/fc:state`'s argument does (`commands/state.md` step 1b). Plan and step titles are also rendered by a model, so instruction-like text in a plan reaches the prompt.
- Dependency/supply chain: **absent**. Bash and Node stdlib only; no new package.
- Migrations: **absent**. No file format, layout or recorded data changes.
- Rollback: **absent**. The command writes nothing and has no headless or CI form, so reverting the release leaves no data or pipeline behind.
- Blast radius: **present**. A new name enters the public `/fc:` and `$fc-` namespaces in every repo that installs 5.2.0. An adopted repo's own `ai-factory/tasks/current.md`, if one exists, would collide with it. No template reaches adopted repos.

`/fc:start` risk triggers:
- Uncertain requirements: **absent**. The developer settled the listing, next-step, progress, ordering, empty-result and argument rules (AC1–AC22).
- Authorization: **absent**. No access path changes.
- Public contracts: **present**. There is a new `/fc:current` command, `$fc-current` skill and docs page, and a new accepted argument `--spec <id>`.
- Migrations: **absent**. No data or layout move.
- Dependencies: **absent**. No new package. Landing after ASD-004's 5.1.0 is a release dependency, not a package.
- Service ownership: **absent**. A single plugin repo, with no fleet boundary.

## Open questions
1. Run `/fc:risk ai-factory/specs/ASD-006-current-command.md`.

## Data touched
- Read: plan files directly under `ai-factory/plans/`, never `ai-factory/plans/done/`. From them it reads step lines, `Depends on:` lines, withdrawn-step records and `Spec:` lines.
- Written: none. The `log-task.js` hook writes a run-log row for `current`, but that is the hook's existing behaviour for any command name, not this command's.
- No change to the plan or spec format, the run-log schema, lifecycle events or contracts.

## Routes touched
- Slash command: `/fc:current` (new, plugin-level), with optional `--spec <id>`.
- Codex skill: `$fc-current` (new plugin skill `codex-skills/fc-current/`); no project skill in adopted repos.
- Headless: none.
- Docs: `docs/commands/current.md` (new, generated) and a row in `docs/commands.md`, in the "Entry and resume" group.

## Components likely involved
- A new listing script beside `skills/ai-layout/scripts/state.sh`, for example `skills/ai-layout/scripts/current.sh`. It applies the runnable-step rule of `skills/ai-layout/templates/ai-factory/make/loop.js` without changing that file.
- A new check, for example `skills/ai-layout/scripts/check-current.sh`, with plan fixtures for AC1–AC22.
- `commands/current.md`, hand-written like `commands/state.md`.
- `codex-skills/fc-current/SKILL.md`, generated by `skills/ai-layout/scripts/sync-codex-skills.js`. No change to the generator is expected.
- `docs/commands/_notes/current.md`, `docs/commands/_notes/_groups.md`, and the generated `docs/commands/current.md` and `docs/commands.md`. No change to `skills/ai-layout/scripts/sync-docs.js` is expected.
- `skills/ai-hooks/scripts/log-task.js`: no change expected, because its `/fc:` and `$fc-` pattern already records `current`.
- The count statements in `README.md`, `ai-factory/docs/workflow.md`, `docs/installation.md` and `docs/README.md`, and the count checks as ASD-004 leaves them (derived from `commands/`).
- The `README.md` command list, `CHANGELOG.md`, and the version files that `check-versions.sh` reads.
- Unchanged by design: `commands/state.md`, `skills/ai-layout/scripts/state.sh`, `codex-skills/fc-state/`, everything under `skills/ai-layout/templates/`, and `/fc:start`'s routing.
