# ASD-005 — Project-declared quality checks recorded as contracts evidence (B1)
Created: 2026-10-31T21:10:34.058Z

A contracts-enabled repo can declare its own quality checks in `ai-factory/quality.json`, whatever its stack: JS/TS, Go, Java or any other. Each check is an argv with an exit-code map, plus an optional JSON-path warn rule. `make quality` runs the checks and records each run as contracts evidence in a new phase, `quality`. Quality evidence lives in its own directory, `ai-factory/quality-evidence/`, which a 5.x plugin never reads. The evidence is bound to the code snapshot, the check's declaration, the base ref and the tool version. `{diff}` and `{files}` tokens hand a check everything changed since the base, with `ai-factory/` removed. Only diff- or files-scoped checks may be required. In B1, failed, errored or stale quality evidence produces informational `I_QUALITY_*` diagnostics and never blocks. A malformed `quality.json` makes `make quality` refuse and `make contracts` exit non-zero, and it shows only as a warning on the read-only paths. The plugin knows no tool. Three presets are documented in a new `ai-factory/docs/quality.md`: Fallow `audit`, golangci-lint and Biome. Repos without `quality.json`, and repos without contracts, behave exactly as they do today.

Parent: `ai-factory/explorations/ASD-005-quality-gate.md`, option B as decided on 2026-10-31, slice B1 only. No analysis exists. The developer's command confirmed the exploration's Q1, Q4 and Q6 defaults. The developer then answered this spec's open questions in two interviews, and decided risk findings R4–R7 of `ai-factory/risks/ASD-005-quality-checks.md` in a third. The session resolved findings R1–R3 and R8–R13 with their obvious fixes. Every finding is folded into the criteria below or recorded under Effort and risk. The schema files follow the existing naming convention (`contracts/schema/quality.v1.json`, `contracts/schema/quality-evidence.v1.json`). Java is covered only by an advisory whole-project example in `ai-factory/docs/quality.md` (AC57), not by a preset.

## User story
As a developer in a contracts-enabled repo of any stack, I want to declare my project's own quality checks as argv in one opt-in file and have them recorded as contracts evidence. That way, deterministic tool runs decide `passed`, `warned`, `failed`, `error` or `unavailable`. The result is tied to the exact code, check declaration, base and tool version it ran on, and it goes stale when any of them changes. It also keeps one evidence authority, so later slices can gate run, loop and review on it.

## Acceptance criteria

**Opt-in and legacy behaviour**
- **AC1.** Given an adopted repo with no `ai-factory/quality.json`, when `make verify`, `make contracts` and `contracts.js validate` run, then they produce the same evidence files, the same output and the same exit codes as before this change, and none of their output mentions quality.
- **AC2.** Given a repo with `ai-factory/quality.json` and no `ai-factory/contracts/config.json`, when `make -f ai-factory/make/ai.mk quality DELIVERY=<id>` runs, then it exits 0, starts no declared check command, writes no evidence file and prints no error or warning about quality.
- **AC3.** Given the repo of AC2, when `make doctor` runs, then its output carries no finding and no line about `quality.json` or quality checks.

**Declaring checks**
- **AC4.** Given `skills/ai-layout/templates/ai-factory/contracts/schema/quality.v1.json`, when it is read, then it describes a list of checks. Each check has:
  - a unique `name`;
  - an `argv` array;
  - a `required` flag;
  - a timeout;
  - an `exit` map from exit-code strings to `passed`, `warned`, `failed` or `error`;
  - optional `triggers`;
  - an optional JSON-path warn rule;
  - a `versionArgv`, which is required when `required` is `true` and optional otherwise.
- **AC5.** Given an `ai-factory/quality.json` with a check that is missing its `name`, `argv`, `required`, timeout or `exit` map, or two checks with the same `name`, when `make contracts` or `contracts.js validate` runs, then it reports an `I_QUALITY_CONFIG` diagnostic that names the file and the faulty check, and it exits non-zero.
- **AC6.** Given an `ai-factory/quality.json` with a check that sets `required: true` and declares no `versionArgv`, when `make contracts` or `contracts.js validate` runs, then it reports an `I_QUALITY_CONFIG` diagnostic that names the check and says `versionArgv` is required for a required check, and it exits non-zero.
- **AC7.** Given a check whose `triggers` contains a value other than `step`, `loop`, `review` or `final`, when `make contracts` or `contracts.js validate` runs, then it reports an `I_QUALITY_CONFIG` diagnostic that names the check and the unknown value, and it exits non-zero.
- **AC8.** Given a check that declares no `triggers`, when its evidence is recorded, then the evidence lists the triggers `step`, `loop`, `review` and `final`.
- **AC9.** Given a check whose `argv` contains neither `{diff}` nor `{files}` and that sets `required: true`, when `make contracts` or `contracts.js validate` runs, then it reports an `I_QUALITY_CONFIG` diagnostic that names the check and says that a whole-project check cannot be required, and it exits non-zero.
- **AC10.** Given a check whose `argv` contains neither `{diff}` nor `{files}` and that sets `required: false`, when `make quality` runs, then the check runs and its evidence records `scope: project` and `required: false`.
- **AC11.** Given a check whose `argv` contains `{diff}`, when its evidence is recorded, then it records `scope: diff`. Given one whose `argv` contains `{files}`, it records `scope: files`. Either check may set `required: true` without a validation diagnostic.
- **AC12.** Given a check, when `make quality` runs it, then its `argv` and `versionArgv` are started as an argv array with `shell: false`, and no part of either is run through a shell.
- **AC13.** Given a check whose `argv` or `versionArgv` has an element that contains `{` or `}`, or one of the other characters that the `Verify` metacharacter rule refuses today, when `make contracts` or `contracts.js validate` runs, then it reports an `I_QUALITY_CONFIG` diagnostic that names the check and the element, and it exits non-zero. The only exceptions are an element that is exactly `{diff}` or exactly `{files}`, which is accepted. A `{diff}` or `{files}` inside a longer element (for example `"--files={files}"`) is refused with a message saying that the token must be a whole argv element.
- **AC14.** Given an `ai-factory/quality.json` that is malformed in any of the ways of AC5, AC6, AC7, AC9 or AC13, or that is not valid JSON, when `make -f ai-factory/make/ai.mk quality DELIVERY=<id>` runs, with or without `STEP`, then it refuses to run. It prints the `I_QUALITY_CONFIG` diagnostic naming the error, exits non-zero, starts no declared program and writes no evidence or scratch file.
- **AC15.** Given the malformed `ai-factory/quality.json` of AC14, when `make contracts` runs, then the `I_QUALITY_CONFIG` diagnostic changes no artifact's or delivery's state: every spec, plan, quick and evidence artifact keeps the state it has without `quality.json`.

**Input tokens**
- **AC16.** Given a branch with changes committed since the merge-base with `main` or `develop`, plus staged, unstaged and untracked changes, both inside and outside `ai-factory/`, and a check with `{diff}` in its `argv`, when `make quality` runs it, then the runner writes one plain unified diff to `ai-factory/runs/tmp/quality/<run>.diff` and passes that file's path in place of the `{diff}` token. The diff:
  - compares the working tree with that base;
  - adds untracked files as new-file hunks;
  - holds every text change outside `ai-factory/`, whether committed or not, and none inside it;
  - has no `## …` section header lines;
  - lists a file that was staged and then edited again only once.
- **AC17.** Given the changes of AC16, including a changed binary file outside `ai-factory/`, when the `{diff}` file is written, then it holds no GIT binary patch and no hunk or header for that binary file.
- **AC18.** Given a repo whose recorded base ref is `none` (AC46), when the `{diff}` file is written, then it compares the working tree with `HEAD`, adding untracked files as new-file hunks, with `ai-factory/` removed.
- **AC19.** Given the changes of AC16, including a file outside `ai-factory/` deleted since the base, and a check whose `argv` is `["biome","ci","{files}"]`, when `make quality` runs it, then the runner replaces the `{files}` element with one argv element per file outside `ai-factory/` changed since the base: committed, staged, unstaged or untracked. Each path is repo-relative and prefixed `./` (for example `biome ci ./a.ts ./b.ts`), and the list leaves out the deleted file. When the base ref is `none`, the list is the files changed against `HEAD`, including untracked ones.
- **AC20.** Given a changed file outside `ai-factory/` whose name begins with `-` (for example `-x.ts`), when `{files}` is expanded, then it is passed as `./-x.ts`.
- **AC21.** Given a branch with commits since the base that change files outside `ai-factory/`, and a clean working tree, when `make quality` runs a check with `{diff}` or `{files}`, then the check is started and is not recorded as `not_run`.
- **AC22.** Given a branch and working tree with no change outside `ai-factory/` since the base (or against `HEAD`, when the base ref is `none`), and a check with `{diff}` or `{files}` in its `argv`, when `make quality` runs, then that check's command is not started. Its evidence is recorded with the status `not_run` and the reason `no changed files in scope`.
- **AC23.** Given the `not_run` evidence of AC22, including for a check with `required: true`, when `contracts.js validate` runs, then that evidence causes no diagnostic and no non-zero exit.
- **AC24.** Given a `make quality` run that wrote a `{diff}` file, when the run ends, whether its checks passed, failed or timed out, then no file it wrote remains under `ai-factory/runs/tmp/quality/`.
- **AC25.** Given the changes of AC16, when `runner.js` builds the `working-tree` review diff, then it is byte-for-byte what it was before this change, `ai-factory/` changes included.

**Status mapping**
- **AC26.** Given a check whose exit code is a key in its `exit` map, when it is recorded, then the evidence status is that key's mapped value.
- **AC27.** Given a check whose exit code is not a key in its `exit` map, when it is recorded, then the evidence status is `error`.
- **AC28.** Given a check with a JSON-path warn rule (for example `$.verdict == "warn"`) whose exit code maps to `passed`, and whose stdout is JSON matching the rule, when it is recorded, then the evidence status is `warned`. When the stdout is JSON that does not match the rule, the status stays `passed`.
- **AC29.** Given a check with a JSON-path warn rule, whose exit code maps to `passed` and whose stdout cannot be parsed as JSON, when it is recorded, then the evidence status is `error`.
- **AC30.** Given a check that runs past its declared timeout and has started a child process of its own, when it is recorded, then the check's whole process group is killed, so neither the check nor its child is still running, and the evidence status is `error`.
- **AC31.** Given a check whose `argv` program does not exist or cannot be executed, when it is recorded, then the evidence status is `unavailable`.
- **AC32.** Given a check whose start fails for any other reason, for example a `{files}` list too long to pass (`E2BIG` or an equivalent), when it is recorded, then the evidence status is `error`, not `failed`.
- **AC33.** Given in-scope files that change while a check runs, when it is recorded, then the evidence status is `error`, with the reason `files changed during the check`. In B1 this blocks nothing, like any other `error` (AC48).

**Recording**
- **AC34.** Given a contracts-enabled repo with a valid `ai-factory/quality.json`, when `make -f ai-factory/make/ai.mk quality DELIVERY=<id> STEP=<n>` runs, then it runs every declared check and writes step-level evidence with the phase `quality` to `ai-factory/quality-evidence/<id>/S<n>.json`. That file validates against `contracts/schema/quality-evidence.v1.json`. Each check's entry carries:
  - its `name`, `required`, `scope`, triggers, argv and exit code;
  - its status and, where AC22 or AC33 apply, its reason;
  - the `snapshot_sha256` of the in-scope files;
  - a digest of the check's declaration;
  - the base ref;
  - the tool version;
  - for each of stdout and stderr, a digest of the full output and an excerpt of its last 200 lines or its last 16 KB, whichever limit is reached first.

  It never carries the content of the `{diff}` file.
- **AC35.** Given a check that prints 1,000 lines of 10 bytes to stdout, when it is recorded, then its stdout excerpt is exactly the last 200 lines. Given a check that prints 300 lines of 100 bytes to stderr, when it is recorded, then its stderr excerpt is the last 16 KB of that output, at most 16,384 bytes. In both cases the digest covers the full output. No setting in `quality.json` or the environment changes either limit.
- **AC36.** Given the repo of AC34, when the same target runs with `DELIVERY=<id>` and no `STEP`, then it writes delivery-level evidence with the phase `quality` to `ai-factory/quality-evidence/<id>/delivery.json`, carrying the same fields.
- **AC37.** Given a delivery with quality evidence, when `make quality` runs, then it adds and changes no file under `ai-factory/evidence/`. When the 5.1.0 `contracts.js validate` runs on that repo, then its output and exit code are the same as for the same repo without `ai-factory/quality-evidence/`.
- **AC38.** Given a check that declares `versionArgv` (for example `fallow --version`), when `make quality` records it, then the evidence's tool version is that command's output at run time.
- **AC39.** Given a check with `required: false` and no `versionArgv`, when it is recorded, then the evidence's tool version is `unknown`.
- **AC40.** Given a check whose `versionArgv` program does not exist, cannot be executed, exits non-zero or runs past the check's timeout, when it is recorded, then that check's evidence status is `error`.

**Validation and staleness**
- **AC41.** Given quality evidence and an `ai-factory/quality.json`, when `contracts.js validate` or `make contracts` runs, then neither starts any program declared in `argv` or `versionArgv`. They compare stored data only.
- **AC42.** Given recorded quality evidence, when an in-scope file outside `ai-factory/` changes afterwards, then `contracts.js validate` reports a `I_QUALITY_STALE` warning for it.
- **AC43.** Given recorded quality evidence, when only files under `ai-factory/` other than `quality.json` change afterwards, then `contracts.js validate` reports no `I_QUALITY_STALE` warning for it.
- **AC44.** Given recorded quality evidence, when that check's declaration in `ai-factory/quality.json` changes, then `contracts.js validate` reports a `I_QUALITY_STALE` warning for it.
- **AC45.** Given recorded quality evidence, when it is recorded, then its base ref is the merge-base with `main` or `develop`, the same base that `runner.js` uses for review's `branch` scope. When that merge-base later differs from the one recorded, `contracts.js validate` reports a `I_QUALITY_STALE` warning for it.
- **AC46.** Given a repo where neither a merge-base with `main` nor one with `develop` can be found, for example a fresh repo with neither branch, or a shallow clone with no local `main` or `develop`, when quality evidence is recorded, then its base ref is `none`. `contracts.js validate` then reports `I_QUALITY_STALE` only on a change to the snapshot, the declaration digest or the tool version.
- **AC47.** Given quality evidence for a check, and a later `make quality` run that recorded a different tool version for the same check name, when `contracts.js validate` runs, then it reports a `I_QUALITY_STALE` warning for the earlier evidence. Given a tool that was upgraded but no later `make quality` run, it reports no tool-version staleness.
- **AC48.** Given quality evidence, when `contracts.js validate` or `make contracts` runs, then:
  - `passed` and `warned` count as a pass, and the output names every `warned` check;
  - `failed`, `error` and `unavailable` evidence is reported with the warnings `I_QUALITY_FAILED`, `I_QUALITY_ERROR` and `I_QUALITY_UNAVAILABLE`;
  - none of these diagnostics, nor `I_QUALITY_STALE`, makes the exit code non-zero or changes any artifact's or delivery's state, including for a check with `required: true`. Only `I_QUALITY_CONFIG` makes the exit code non-zero (AC5, AC6, AC7, AC9 and AC13).
- **AC49.** Given a delivery whose quality evidence holds failed, errored and stale entries for required checks, or a repo whose `ai-factory/quality.json` is malformed as in AC14, when `make/continue.js`, `make/delivery-status.js` and `make/delivery-report.js` run for that delivery, then their outcome, state and readiness are the same as for that delivery with no `ai-factory/quality-evidence/` and no `quality.json`. They list the `I_QUALITY_*` diagnostics as warnings, and nothing else differs.
- **AC50.** Given the repo of AC49, when the reviewer agent reads contracts validation for that delivery as `agents/reviewer.md` directs, then the validation it reads shows the `I_QUALITY_*` diagnostics as warnings. The delivery state it reads is the same as without quality evidence and `quality.json`.
- **AC51.** Given existing `red`, `step`, `final`, `quick`, `review` and attestation evidence written before this change, when `contracts.js validate` runs after it, then that evidence validates exactly as before and none of it is rewritten.

**Tool neutrality and boundary**
- **AC52.** Given `skills/ai-layout/templates/` after this change, when its scripts, tasks and agents are searched, then none names, invokes or parses the output of Fallow, Biome, golangci-lint or any Java tool. Those names appear only in `ai-factory/docs/quality.md`.
- **AC53.** Given `/fc:adopt-sdlc` or `/fc:sync-sdlc` run after this change, when they finish, then they have written no file outside `ai-factory/`, and no `package.json`, lockfile, `go.mod`, `biome.json`, `.fallowrc.json`, `.golangci.yml` or `.gitignore` was created or changed.

**Documentation**
- **AC54.** Given `skills/ai-layout/templates/ai-factory/docs/quality.md`, when it is read, then it describes:
  - the `quality.json` format;
  - the statuses and which ones count as a pass;
  - the `I_QUALITY_*` diagnostics, and that no quality evidence blocks in this release. That includes `I_QUALITY_CONFIG`, which makes `make quality` refuse and `make contracts` exit non-zero;
  - the excerpt limits: the last 200 lines or 16 KB per stream, whichever is reached first, plus a digest of the full output;
  - the `{diff}` and `{files}` tokens, what they cover since the base, and the `./` prefix;
  - the scope rule (only diff- or files-scoped checks may be required);
  - the triggers and their default;
  - the staleness inputs, including that a tool upgrade shows only at the next `make quality`;
  - the `make quality` target and the `ai-factory/quality-evidence/` location.

  It also states:
  - that on `main` itself the base is `HEAD`'s own commit, and that a shallow CI clone without a local `main` or `develop` records base `none`, so local and CI staleness can differ;
  - that check output is logged and an excerpt is kept in evidence;
  - that adopters should pin each tool's version and record whatever ADR their own dependency rules require;
  - that quality evidence needs 6.0.0 on every machine and in CI that should see it;
  - that tools are installed and root config files are edited by hand, and that adoption and sync write nothing outside `ai-factory/`;
  - that later slices extend `quality.v1` and `quality-evidence.v1` additively, and that a breaking change gets a `v2` schema.
- **AC55.** Given `ai-factory/docs/quality.md`, when its presets are read, then it gives three check entries, ready to copy into `ai-factory/quality.json`, that validate against `quality.v1.json`:
  - Fallow `audit`, using `--diff-file {diff}`, an `exit` map with 0 `passed`, 1 `failed` and 2 `error`, and the warn rule `$.verdict == "warn"`;
  - Go golangci-lint, using `run --new-from-patch {diff}`;
  - Biome, using `ci {files}`.
- **AC56.** Given the presets of AC55, when they are read, then each one also documents how to exclude `ai-factory/` in that tool's own config:
  - `.fallowrc.json` `ignorePatterns: ["ai-factory/**"]`;
  - Biome `!!**/ai-factory`;
  - golangci-lint `issues.exclude-dirs: [ai-factory]`.

  The docs also state that the runner's diff and files filter is the guarantee.
- **AC57.** Given `ai-factory/docs/quality.md`, when its Java section is read, then it shows a whole-project check (a Gradle or Maven Checkstyle, PMD or SpotBugs run) with `required: false`. It states that such a check stays advisory until a baseline wrapper exists.

**Checks and release**
- **AC58.** Given the full check suite (`skills/ai-layout/scripts/check-*.sh` and `skills/ai-hooks/fixtures/check-*.sh`), when it runs after the change, then every check passes. This includes a check that covers AC1, AC2, AC5, AC6, AC9, AC13, AC14, AC15, AC16, AC17, AC19, AC20, AC21, AC22, AC23, AC24, AC27, AC30, AC31, AC32, AC33, AC35, AC37, AC39, AC40, AC41, AC44, AC46, AC47, AC48 and AC49.
- **AC59.** Given this feature's branch, when `skills/ai-layout/scripts/check-versions.sh` runs, then every version field it reads is `6.0.0`.
- **AC60.** Given `CHANGELOG.md`, when the 6.0.0 entry is read, then it:
  - describes `ai-factory/quality.json`, `ai-factory/quality-evidence/`, the `quality` evidence phase, the `warned` and `error` statuses, the `I_QUALITY_*` diagnostics and the `make quality` target;
  - says that they are opt-in, apply to contracts-enabled repos only, and block nothing in this release;
  - states that teammates and CI must upgrade to 6.0.0 together to see quality evidence;
  - marks the change as a template change, breaking for adopted repos.

## Out of scope
- **B2.** The per-step ✓/✗ panel after each `/fc:run` and `/fc:loop` step, its choices and `maxFixAttempts`, the serial interactive loop, the headless continue/stop rule, and acting on the `step` and `loop` triggers. This includes making `loop.js verifyStep` or `/fc:run`'s tick depend on quality evidence. It is a later, separate spec, together with its amendment to ADR ETT683 and spec 0022.
- **B3.** Acting on the `review` and `final` triggers. That covers recording quality evidence from `runner.js review`, `gate.js` and `assurance.js complete` refusing readiness on a failed, errored or stale required check, and `delivery-report.js` showing quality results.
- Any blocking on quality evidence in B1, beyond `I_QUALITY_CONFIG`'s non-zero exit from `make quality` and `make contracts`. Blocking starts in B2 and B3. They may add `E_` codes when they do, and they decide whether `not_run` on a required check may ever count as a pass once a gate reads it.
- Any change to `contracts/schema/diagnostics.v1.json`. The `I_QUALITY_*` codes fit its existing pattern.
- Configurable excerpt limits.
- **B4,** the `quality-gate` explain-only agent, dropped in favour of the optional fallow-skills plugin.
- Any installer or setup command that writes root files, and any fc flow that invokes `fallow-setup` or `fallow-cloud-setup`.
- Criteria on the exact behaviour of tool flags beyond what AC55 and AC56 state. The plan's first step verifies these:
  - that Fallow 3.38.1 `--diff-file` and golangci-lint `--new-from-patch` accept the AC16 diff;
  - Biome's `!!` force-ignore syntax;
  - golangci-lint's flags and `issues.exclude-dirs`;
  - whether `fallow audit` makes network calls;
  - the `main` and shallow-clone base behaviour of AC45 and AC46.
- Starting the plan before ASD-003 (5.0.1) and ASD-004 (5.1.0) are on `main`. This is sequencing, not a buildable criterion: the plan's first step refuses to start until both are there.
- A Java preset, and a baseline wrapper that would let a whole-project Java check be required.
- `fallow viz`, and `--format gitlab-codequality` output.
- Quality checks in contracts-disabled repos.
- Excluding `ai-factory/` from the review diff that `runner.js` builds.
- Linking ASD-003's user docs to `ai-factory/docs/quality.md`.
- The overlay plugin of exploration option C.

## Effort and risk
Effort **L**. Size is L, and the risk fixes grew it again. It now covers:
- a new artefact and two schemas (`quality.v1.json`, `quality-evidence.v1.json`) in a separate evidence directory;
- a new evidence phase and two new statuses;
- five `I_QUALITY_*` codes within the existing diagnostics schema. `I_QUALITY_CONFIG` makes `make quality` refuse and `make contracts` fail, but blocks no read-only path;
- fixed output excerpts (the last 200 lines or 16 KB per stream);
- exit-map and JSON-path mapping;
- base-relative `{diff}` and `{files}` synthesis, with argv validation and the `./` prefix;
- the scope rule;
- a four-input staleness check computed from stored data only;
- the process-group timeout;
- scratch cleanup;
- a new `make quality` target;
- a 5.1.0-compatibility fixture;
- a new template doc with three presets and a Java example;
- a new check script.

It stays within contracts, diff synthesis, `ai.mk` and docs. It touches neither run, loop nor review behaviour, and it needs no ADR or migration, so it is not XL. Uncertainty is M: every behavioural question is decided, and the unknowns left are the tool flags and git base behaviour that the plan's first step verifies. The plan cannot start until ASD-003 (5.0.1) and ASD-004 (5.1.0) are on `main` (risk R12).
- `dev 29–43 h (assumption: verifying the tool flags and git base behaviour takes 3–5 h; the quality.json schema, argv validation, triggers and scope rule 3–5 h; recording in a separate quality-evidence directory with the phase, statuses, exit map, warn rule, process-group timeout, output digests and excerpt 8–11 h; base-relative {diff} and {files} synthesis, not_run and scratch cleanup 5–7 h; stored-data staleness, the I_QUALITY codes and the malformed-config refusal, with continue, status, report and reviewer unchanged 5–7 h; the check script, fixtures and 5.1.0 compatibility fixture 3–5 h; quality.md, architecture.md, CHANGELOG and the version bump 2–3 h)`
- `/fc:run ~150–300 min (assumption: 8–10 plan steps, the first of them the tool-flag and base verification, with no rework from a diff format that a tool rejects)`

Risk categories:
- Authorization: **absent**. No user, role or permission model is touched, and `quality.json` sits beside plan `verify` argv inside the same trust boundary.
- Data exposure: **present**. The `{diff}` file holds the full content of untracked files, and evidence keeps an excerpt of tool output, which can echo source lines.
- Secrets: **absent**. No credential is read, written or passed. Checks inherit the environment exactly as `Verify` commands do today.
- Injection: **present**. `quality.json` supplies argv that the runner executes, and changed file paths are substituted into argv through `{files}`.
- Dependency/supply chain: **present**. The documented presets rely on third-party binaries (Fallow, golangci-lint, Biome) that the developer installs and the plugin does not pin.
- Migrations: **absent**. The feature is opt-in, a missing `quality.json` or contracts config means legacy behaviour (AC1 and AC2), and no existing evidence is rewritten (AC51).
- Rollback: **present**. Once adopters write `quality.json` and record quality evidence, the phase, statuses, tokens, `I_QUALITY_*` codes and schemas become a contract that later slices must extend additively.
- Blast radius: **present**. It is a 6.0.0 template change that reaches every adopted repo on `/fc:sync-sdlc`. It modifies `contracts.js` validation, which `/fc:continue`, the delivery report, delivery status and the reviewer all share.

`/fc:start` risk triggers:
- Uncertain requirements: **present**. The behaviour is decided, but the tool flags behind the presets and the git base behaviour on `main` and in shallow clones are unverified until the plan's first step.
- Authorization: **absent**. No access path changes.
- Public contracts: **present**. A new adopter-owned file and two schemas, a new evidence directory, phase and statuses, the `I_QUALITY_*` warnings, the `{diff}` and `{files}` tokens, a new `make quality` target and a major template release.
- Migrations: **absent**. There is no data or layout move, and existing evidence is untouched.
- Dependencies: **present**. The presets depend on third-party CLIs and their flags.
- Service ownership: **present**. ADR 0009 forbids root-file writes, so tool setup stays with the developer by hand. Base owns none of it, and no overlay is built here.

Residual risks, from `ai-factory/risks/ASD-005-quality-checks.md`:
- **R8.** On `main` itself the merge-base is `HEAD`, so the base ref moves with every commit. A shallow CI clone records `none` where a local clone records a sha, so staleness can differ between them. `quality.md` documents this (AC54), and the plan's first step verifies it.
- **R10.** Preset tools are not pinned by the plugin, their flags are unverified, and it is not established whether `fallow audit` makes network calls. The docs tell adopters to pin a version (AC54), and the plan's first step verifies the flags and the network question.
- **R13.** The new file, schemas, statuses, `I_QUALITY_*` codes and tokens are a public contract. Later slices extend them additively under `v1`; a breaking change needs `v2` (AC54).
- Declared argv still runs with the developer's or CI's full environment and privileges, as `Verify` does today.
- Until B2 and B3, a failed or skipped required check is information only (AC48). A malformed `quality.json` fails `make contracts` and `make quality`, but shows only as a warning on read-only paths (AC14, AC49).

## Open questions
None.

## Data touched
- `ai-factory/quality.json` (new, owned by the adopted repo). Each check has `name`, `argv`, `required`, a timeout, an `exit` map, optional `triggers`, an optional JSON-path warn rule and a `versionArgv` (required for required checks, optional for advisory ones).
- `ai-factory/quality-evidence/<delivery id>/S<n>.json` and `delivery.json` (new, phase `quality`). Each entry holds the snapshot, the declaration digest, the base ref (or `none`), the tool version (or `unknown`), the status and reason, and, per stream, a full-output digest with an excerpt of the last 200 lines or 16 KB.
- `skills/ai-layout/templates/ai-factory/contracts/schema/quality.v1.json` and `quality-evidence.v1.json` (new). `diagnostics.v1.json` and `evidence.v1.json` are unchanged.
- `ai-factory/evidence/`: unchanged. Existing evidence is never rewritten, and no quality file is written there.
- `ai-factory/runs/tmp/quality/<run>.diff` (new runner scratch, deleted when the run ends).
- `ai-factory/contracts/config.json`: read only, as the opt-in signal. `code_scope` is unchanged.
- Version fields read by `check-versions.sh` (6.0.0).

## Routes touched
- `make -f ai-factory/make/ai.mk quality DELIVERY=<id> [STEP=<n>]` (new).
- `make contracts` and `node ai-factory/make/contracts.js validate`, which gain quality validation, stored-data staleness and the `I_QUALITY_*` diagnostics. Only `I_QUALITY_CONFIG` makes the exit code non-zero. `make verify` is unchanged.
- No slash command changes in B1.

## Components likely involved
- `skills/ai-layout/templates/ai-factory/make/contracts.js`: quality config loading and argv validation (tokens, triggers, scope rule, `versionArgv`), recording into `quality-evidence/`, the exit map and warn rule, the process-group timeout, spawn-error mapping, the `quality` phase and statuses, the stored-data staleness and the `I_QUALITY_*` warnings.
- A quality diff and file-list builder: base-relative, untracked files as new-file hunks, no `--binary`, `ai-factory/` removed, `./` prefix. It is new code beside `runner.js`'s `reviewInput()`, which stays unchanged.
- `skills/ai-layout/templates/ai-factory/make/ai.mk`: the `quality` target.
- `skills/ai-layout/templates/ai-factory/contracts/schema/quality.v1.json`, `quality-evidence.v1.json` and `contracts/README.md`.
- `make/continue.js`, `make/delivery-status.js`, `make/delivery-report.js` and `agents/reviewer.md`: they show `I_QUALITY_*` as warnings, and their outcome is otherwise verified unchanged (AC49).
- `skills/ai-layout/templates/ai-factory/docs/quality.md` (new).
- A new check script under `skills/ai-layout/scripts/` with fixtures, including one that runs the 5.1.0 validator (AC37).
- `ai-factory/docs/architecture.md` (Data ownership: `quality.json`, `quality-evidence/`, the `quality` phase and the `make quality` target).
- `CHANGELOG.md`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`.
