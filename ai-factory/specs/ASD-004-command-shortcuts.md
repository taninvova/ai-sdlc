# ASD-004 — Command shortcuts /fc:ba, /fc:analyze and /fc:scout
Created: 2026-10-30T19:14:04.843Z

Three first-class, non-deprecated task shortcuts are added: `ba` and `analyze` → `analyse`, and `scout` → `explore`. They come from one `TASK_SHORTCUTS` table in `make/models.js`, next to `TASK_ALIASES`, and behave like their target everywhere a task name is accepted.

Parent: `ai-factory/explorations/ASD-004-command-shortcuts.md`, option B. The developer answered that exploration's open questions in an interview, and answered this spec's first open questions in a second interview. Both sets of answers are folded into the criteria below.

## User story
As a developer using the ai-sdlc plugin, I want short names (`/fc:ba`, `/fc:analyze`, `/fc:scout`) that run the `analyse` and `explore` tasks exactly as their full names do. That way I can reach those tasks quickly, without being told I used a deprecated name, and the task's model routing, run-log rows and cost grouping stay the same.

## Acceptance criteria

**The table**
- **AC1.** Given `skills/ai-layout/templates/ai-factory/make/models.js`, when it is loaded, then it exports a frozen `TASK_SHORTCUTS` equal to `{ ba: "analyse", analyze: "analyse", scout: "explore" }`, defined beside `TASK_ALIASES`, and `TASK_ALIASES` is still `{ check: "review" }`.
- **AC2.** Given `models.js`, when `canonicalTask` is called with `ba`, `analyze`, `scout` or `check`, then it returns `analyse`, `analyse`, `explore` and `review`, and it returns any other name unchanged.
- **AC3.** Given `models.js`, when `aliasNotice` is called with `ba`, `analyze` or `scout`, then it throws, just as it does for any name that is not in `TASK_ALIASES`. It still returns the deprecation line for `check`.

**Claude commands**
- **AC4.** Given `skills/ai-layout/scripts/sync-claude-commands.js`, when it runs, then it writes `commands/ba.md`, `commands/analyze.md` and `commands/scout.md`. Each one runs its target task with the target's own entry preamble (`entryPreamble("claude", <target>)`), and none of them contains the `aliasNotice` text or the word "deprecated".
- **AC5.** Given the generated `commands/ba.md`, `commands/analyze.md` and `commands/scout.md`, when their frontmatter is read, then each `description` is `Shortcut for /fc:<target> — ` followed by the target command's description (`/fc:analyse` for `ba` and `analyze`, `/fc:explore` for `scout`).
- **AC6.** Given the generated `commands/check.md`, when it is compared with its content before this change, then it is byte-for-byte unchanged.

**Codex skills**
- **AC7.** Given `skills/ai-layout/scripts/sync-codex-skills.js`, when it runs, then it writes `codex-skills/fc-ba/`, `codex-skills/fc-analyze/` and `codex-skills/fc-scout/`. Each one runs its target task with `entryPreamble("codex", <target>)`, and none of them contains the `aliasNotice` text or the word "deprecated".
- **AC8.** Given an adopted repo's `make/sync-adapters.js`, when it writes project Codex skills, then it writes `.codex/skills/fc-ba/`, `.codex/skills/fc-analyze/` and `.codex/skills/fc-scout/`. Each one runs its target task (`ai-factory/tasks/<target>.md`, and the target's agent when it has one), and none of them contains the `aliasNotice` text or the word "deprecated".
- **AC9.** Given the Codex skills of AC7 and AC8, when their `SKILL.md` frontmatter is read, then each `description` is `Shortcut for $fc-<target> — ` followed by the target task's description (`$fc-analyse` for `ba` and `analyze`, `$fc-explore` for `scout`).
- **AC10.** Given an adopted repo's `make/sync-adapters.js`, when it writes the project Codex skill `.codex/skills/fc-check/`, then that skill is byte-for-byte what it wrote before this change.

**Name clash**
- **AC11.** Given a task file whose name is a shortcut (for example `ba.md`) in the tasks directory each tool reads, when `sync-claude-commands.js`, `sync-codex-skills.js` or `make/sync-adapters.js` runs, then it refuses with a message naming the file and its target, in the form `Task ba.md uses the shortcut name of analyse; rename the task file`, and writes no entry point for that file.
- **AC12.** Given a task file whose name is a deprecated alias (`check.md`), when `sync-claude-commands.js` or `sync-codex-skills.js` runs, then it still refuses with today's "uses the deprecated name of review" message; and when an adopted repo's `make/sync-adapters.js` runs, then it keeps today's behaviour: it writes that project task's own `.codex/skills/fc-check/` skill, skips the alias skill, and adds no refusal.

**Headless runner and routing**
- **AC13.** Given `make ai TASK=ba`, `TASK=analyze` or `TASK=scout` with an `INPUT`, when the runner starts, then it runs the target task (`analyse` or `explore`) with that input and writes no deprecation line to stderr.
- **AC14.** Given `make ai TASK=check`, when the runner starts, then it still writes `runner: TASK=check is deprecated; running TASK=review` to stderr and runs `review`.
- **AC15.** Given `models.js dispatch --task <shortcut>` for each of the three shortcuts, when it runs against any `models.yaml`, then its directive is identical to `dispatch --task <target>`.
- **AC16.** Given a `models.yaml` whose `routing.tasks` has a shortcut key (for example `scout:` with a tool mapping) and no key for its target, when `readModels` parses it, then the mapping is stored under the target (`routing.tasks.explore`), and the key is not added to `routing.aliased`.
- **AC17.** Given a `models.yaml` whose `routing.tasks` maps a shortcut key and its target (for example `ba:` and `analyse:`), or two shortcuts of the same target (`ba:` and `analyze:`), when `readModels` parses it, then parsing fails with a duplicate-task error. The error names the target and names the shortcut key (whichever of the two keys is the shortcut, in either order), so only the target should be mapped. Headless and routed runs stop, as they do today for `check:` plus `review:`.

**Doctor**
- **AC18.** Given the `models.yaml` of AC16, when doctor runs, then it outputs an `ok` line for the `routing` area that names the key and its target in the form `routing.tasks.scout read as explore`. It outputs no `finding` for that key, and the line does not contain the word "deprecated" or ask for the key to be renamed.
- **AC19.** Given the `models.yaml` of AC17, when doctor runs, then it outputs a `finding` for the `models` area that carries the parse error of AC17.
- **AC20.** Given a `models.yaml` whose `routing.tasks` has the key `check`, when doctor runs, then its output for that key is unchanged: a `finding` saying it uses the deprecated name of `review`.

**Run log and cost**
- **AC21.** Given the `log-task.js` hook, whose regex is unchanged and matches the first command form anywhere in the prompt, when that first form is any of the forms below, then the hook writes the name shown to `.task.<session>`:
  - `/fc:ba`, `/fc:analyze`, `$fc-ba`, `$fc-analyze` or `$fc:fc-ba`: `analyse`
  - `/fc:scout`, `$fc-scout` or `$fc:fc-scout`: `explore`
  - `/fc:check` or `$fc-check`: `review`, as before
- **AC22.** Given `skills/ai-hooks/fixtures/check-codex.sh`, when it runs, then it asserts that the hook's pinned table equals the union of `TASK_ALIASES` and `TASK_SHORTCUTS` from `models.js`, and it fails when the two differ.
- **AC23.** Given run-log rows or lifecycle events labelled with a shortcut name, when `make cost` groups by task and `make/lifecycle.js` reads or records a phase or task, then a shortcut name is counted under its target.

**Documentation**
- **AC24.** Given `ai-factory/docs/architecture.md`, when the paragraph that today begins "Owns the deprecated task names" is read, then it describes one alias table in `make/models.js` with two kinds: deprecated (`check` → `review`) and shortcut (`ba` and `analyze` → `analyse`, `scout` → `explore`). It says that only deprecated names get the deprecation notice, and that the `log-task.js` hook pins the union of both kinds.
- **AC25.** Given `README.md`, when its command tables are read, then they contain one line mapping `/fc:ba` and `/fc:analyze` to `/fc:analyse` and `/fc:scout` to `/fc:explore`, naming the Codex forms `$fc-ba`, `$fc-analyze` and `$fc-scout`. The line does not call the shortcuts deprecated.
- **AC26.** Given `ai-factory/AGENTS.md` and the shipped template `skills/ai-layout/templates/ai-factory/AGENTS.md`, when their `Slash commands:` line is read, then it names `/fc:ba`, `/fc:analyze` and `/fc:scout` as shortcuts of `/fc:analyse` and `/fc:explore`.

**User docs (ASD-003, on rebase)**
These hold on this feature's branch after it is rebased onto a `main` that contains ASD-003.
- **AC27.** Given `node skills/ai-layout/scripts/sync-docs.js`, when it runs, then it writes `docs/commands/ba.md`, `docs/commands/analyze.md` and `docs/commands/scout.md`, and each page marks the command as a shortcut for its target and links the target's page. Each page's kind is taken from its target (a project task, since `analyse` and `explore` are project tasks), never "Plugin-level command"; the generated `docs/commands/check.md` likewise takes its kind from `review`.
- **AC28.** Given `docs/commands/_notes/ba.md`, `docs/commands/_notes/analyze.md` and `docs/commands/_notes/scout.md`, when they are read, then each one contains a `## Usage` heading followed by non-empty content that points to the target command, and none of the other three headings that ASD-003 requires.
- **AC29.** Given the shortcut notes files of AC28, when `node skills/ai-layout/scripts/sync-docs.js --check` runs, then it reports no notes failure for them, just as it reports none for `check.md`, and it still fails on a notes file of a non-shortcut command that lacks one of the four headings.
- **AC29a.** Given `docs/commands/_notes/_groups.md`, when it is read, then `ba`, `analyze` and `scout` each appear in the "Decide before building" group, and `bash skills/ai-layout/scripts/check-docs.sh` exits 0 with no ungrouped-command failure.
- **AC30.** Given the statements of the number of `/fc:*` commands in `README.md` (line 31 today), `ai-factory/docs/workflow.md` (lines 112 and 144 today), `docs/installation.md` (line 41 today) and `docs/README.md` (line 40 today), when they are read, then each states the number of files in `commands/` (28 after this change). Shortcuts count as commands but not as project task entry points, so the "project task entry points" count stays 18.
- **AC31.** Given the command-count test in `skills/ai-layout/scripts/check-risk.sh` (today `command-counts-25`, a literal 25), when it runs, then it computes the expected count from the files in `commands/` instead of a literal, checks every statement named in AC30 against it, and passes after this change.

**Checks and release**
- **AC32.** Given the full check suite (`skills/ai-layout/scripts/check-*.sh` and `skills/ai-hooks/fixtures/check-*.sh`), when it runs after the change, then every check passes. This includes `check-adapters.sh` and `check-start-routing.sh`, which must count or accept the three shortcut entry points without a deprecation notice.
- **AC33.** Given `CHANGELOG.md`, when the 5.1.0 entry is read, then it:
  - lists the three shortcuts and their targets, and says that they are not deprecated;
  - marks the template change **breaking for adopted repos**;
  - says that `TASK=<shortcut>`, `routing.tasks` shortcut keys and the project `$fc-<shortcut>` skills arrive only after `/fc:sync-sdlc`.
- **AC34.** Given this feature's branch, when it is compared with `main`, then it branches from a `main` that already contains ASD-003's 5.0.1 release, and every version field that `skills/ai-layout/scripts/check-versions.sh` reads is `5.1.0`. That is `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` and the plugin entry in `.claude-plugin/marketplace.json`, plus the `docs/README.md` version line that ASD-003 checks. (`.agents/plugins/marketplace.json` carries no version field.)

## Out of scope
- `/fc:start`: its classifier returns canonical names from `START_TASKS`, and it never returns a shortcut.
- `/fc:continue`, `/fc:loop` and the contracts and delivery-report tooling, apart from the canonicalisation they already get from `canonicalTask`.
- Shortcuts for any task other than `analyse` and `explore`, and shortcuts that an adopted repo declares itself (exploration option C).
- A new doctor line kind. The shortcut note uses the existing `ok` kind.
- Rewriting recorded run-log rows, lifecycle events or routing records.
- Deprecating, renaming or removing `/fc:check` or any existing command.
- Any edit to ASD-003's files on the `docs/asd-003-user-docs` branch (`ai-factory/specs/ASD-003-user-docs.md`, its plan and its risk file). ASD-003's generator, notes, docs and counts change only on this feature's own branch, after rebasing onto a `main` that contains ASD-003 (AC27–AC31).

## Effort and risk
Effort **L**. Size is L: well over 5 files, including:
- `models.js`, `runner.js`, `sync-adapters.js` and the two generators;
- the `log-task.js` hook and at least four check scripts;
- six generated plugin entry points;
- three docs pages and three notes files on rebase, ASD-003's generator and checks, and `workflow.md`;
- `architecture.md`, `README.md`, both `AGENTS.md` files, `CHANGELOG.md` and the version files.

Uncertainty is S: a known pattern from `TASK_ALIASES`, and the developer has answered every behavioural question.
- `dev 10–16 h (assumption: the models.js table, parser and doctor take 2–3 h; the generators, sync-adapters and clash refusal 2–3 h; the hook and check scripts 2–4 h; the docs, CHANGELOG and version bump 1–2 h; and the rebase onto ASD-003 with its generator, notes and counts 2–4 h)`
- `/fc:run ~75–150 min (assumption: 5–7 plan steps, with the generated entry points regenerated in one step and the rebase-time ASD-003 updates in one or two steps)`

Risk categories:
- Authorization: **absent**. The shortcuts dispatch the same tasks with the same tools and permissions; no access path changes.
- Data exposure: **absent**. No new data is read or written; run-log rows keep the canonical task names.
- Secrets: **absent**. No credential is read, written or passed.
- Injection: **absent**. The shortcut names are fixed entries in a table owned by the repo, and the hook's prompt regex is unchanged.
- Dependency/supply chain: **absent**. Node stdlib only; no new package.
- Migrations: **absent**. Recorded data is never rewritten, and a shortcut is read under its target.
- Rollback: **present**. Once adopted repos sync, their `TASK=ba` calls, `routing.tasks` shortcut keys and project `$fc-ba` skills depend on the table, so removing a shortcut later breaks them.
- Blast radius: **present**. The template change reaches every adopted repo on `/fc:sync-sdlc`, and three new names enter the public `/fc:` and `$fc-` namespaces. A repo with a task file named `ba`, `analyze` or `scout` stops syncing until it renames that file (AC11).

`/fc:start` risk triggers:
- Uncertain requirements: **absent**. The developer has answered every question from the exploration and from this spec.
- Authorization: **absent**. No access path changes.
- Public contracts: **present**. New `/fc:` commands, `$fc-` skills, `TASK=` values and `routing.tasks` keys, a new parse error and sync refusal, and a template change for every adopted repo.
- Migrations: **absent**. No data or layout move.
- Dependencies: **absent**. No new package.
- Service ownership: **absent**. A single plugin repo, with no fleet boundary.

## Open questions
The open blocker and major findings of `ai-factory/risks/ASD-004-command-shortcuts.md`:
1. R1 (major, blast radius): AC11 makes `/fc:sync-sdlc` refuse in any adopted repo that has a project task file named `ba.md`, `analyze.md` or `scout.md`, so that repo stops syncing until it renames the file. Mitigation: refusing is the right call, since such a file would shadow or collide with the new plugin `/fc:<name>`. The CHANGELOG entry (AC33) should name the refusal, its exact message and the rename step. Inference: a doctor finding before sync would let a repo see this coming; the spec does not require one.
2. R2 (major, blast radius): AC12 says all three tools "still refuse" a `check.md` task file, but today only the two plugin generators refuse; `sync-adapters.js` writes the project task's own skill and skips the alias skill. Read literally, AC12 adds a new breaking refusal for adopted repos. Mitigation: before `/fc:plan`, amend AC12 to either (a) say the `sync-adapters.js` refusal for deprecated names is new and add it to AC33, or (b) limit AC12 to the two plugin generators and keep today's skip in `sync-adapters.js`. **Answered 2026-11-02 by the developer: (b).** AC12 is amended accordingly; no new refusal for adopted repos.
3. R8 (major, blast radius): AC27–AC31 and AC34 depend on ASD-003 being merged to `main`, and ASD-003 fixes the command count at 25 in several places. Mitigation: the plan's first step should refuse to start until ASD-003's 5.0.1 is on `main`. Where ASD-003's checks allow it, derive the counts from `commands/` instead of the literal 28, so the next command change does not break them again. **Resolved 2026-11-02:** ASD-003 is on `main` (84ea88b, 5.0.1), so the reassessment marks R8 mitigated.
4. R11 (major, blast radius, reassessment 2026-11-02): the command count is stated in more places than AC30 named, and `check-risk.sh` holds a literal 25. **Answered 2026-11-02 by the developer:** AC30 and AC31 now name every place and derive the count from `commands/`; shortcuts do not count as project task entry points.
5. R12 (major, blast radius, reassessment 2026-11-02): ASD-006 (`/fc:current`) edits the same counts, groups, README, CHANGELOG and versions. **Answered 2026-11-02 by the developer:** ASD-004 lands first as 5.1.0; ASD-006 rebases onto it and ships as 5.2.0.
6. R13 and R14 (minor, reassessment 2026-11-02): shortcut pages' kind, and their `_groups.md` entries. **Answered 2026-11-02 by the developer:** covered by the amended AC27 and the new AC29a.

## Data touched
- `TASK_SHORTCUTS` (new) and `canonicalTask` in `make/models.js`. `TASK_ALIASES` is unchanged.
- `routing.tasks` keys in an adopted repo's `ai-factory/models.yaml`, read only. Parsed `routing.aliased` keeps only deprecated names.
- The `.task.<session>` file under `ai-factory/runs/`, which holds the canonical task name.
- No change to the run-log row schema, lifecycle events or routing records.

## Routes touched
- Slash commands: `/fc:ba`, `/fc:analyze` and `/fc:scout` (new).
- Codex skills: `$fc-ba`, `$fc-analyze` and `$fc-scout` (new, as plugin skills and project skills).
- Headless: `make ai TASK=ba|analyze|scout` (new accepted values).
- `models.js dispatch --task <shortcut>` (new accepted values).
- Docs: `docs/commands/ba.md`, `docs/commands/analyze.md` and `docs/commands/scout.md` (new, on rebase).

## Components likely involved
- `skills/ai-layout/templates/ai-factory/make/models.js`: the table, `canonicalTask`, the parser's duplicate error and the doctor `ok` line.
- `skills/ai-layout/templates/ai-factory/make/runner.js`: the deprecation line printed only for deprecated names.
- `skills/ai-layout/templates/ai-factory/make/sync-adapters.js`: the project Codex shortcut skills and the clash refusal.
- `skills/ai-layout/scripts/sync-claude-commands.js` and `skills/ai-layout/scripts/sync-codex-skills.js`: the entry points and the clash refusal.
- Generated: `commands/ba.md`, `commands/analyze.md`, `commands/scout.md`, `codex-skills/fc-ba/`, `codex-skills/fc-analyze/` and `codex-skills/fc-scout/`.
- `skills/ai-hooks/scripts/log-task.js`: the pinned table.
- Checks: `skills/ai-hooks/fixtures/check-codex.sh`, `skills/ai-layout/scripts/check-adapters.sh`, `check-start-routing.sh`, `check-interactive-model-routing.sh`, and `check-doctor.sh` as needed.
- `make/cost.js` and `make/lifecycle.js`: covered through `canonicalTask`, with no code change expected.
- `ai-factory/docs/architecture.md`, `README.md`, `ai-factory/AGENTS.md`, `skills/ai-layout/templates/ai-factory/AGENTS.md` and `CHANGELOG.md`.
- The version files that `check-versions.sh` reads.
- On rebase onto ASD-003: `skills/ai-layout/scripts/sync-docs.js` and its checks (the shortcut notes waiver and the count of 28), the generated `docs/commands/*.md`, the three new `docs/commands/_notes/` files, `ai-factory/docs/workflow.md` and `docs/README.md`.
