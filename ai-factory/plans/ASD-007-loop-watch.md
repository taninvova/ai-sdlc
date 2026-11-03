# ASD-007 — Loop watch
Created: 2026-11-02T21:05:09.609Z

**Goal:** Add a read-only `loop.js watch` subcommand that draws a running or ended `/fc:loop` from its `state.json` (live redraw on an ANSI terminal, plain snapshots elsewhere). It is reached through `make loop-watch`, `/fc:watch` and `$fc-watch`, and `loop.js next` and `finish` gain additive `started_at` and `finished_at` fields. Ship it as release 6.0.0 after ASD-006's 5.2.0.

**Spec:** `ai-factory/specs/ASD-007-loop-watch.md` (parent: `ai-factory/explorations/ASD-007-terminal-progress-view.md`, Option A).

**Risk file:** `ai-factory/risks/ASD-007-loop-watch.md`. It has no `## Reassessment`, so this plan carries findings R1–R13 from its body. R1, R2, R3 and R10 are already settled in the spec (AC59, AC45 and the terms, AC52a and AC52b). Artifact contracts are not enabled in this repo (`ai-factory/contracts/config.json` is absent).

**Gate (R7), passed 2026-11-02.** ASD-006 (`/fc:current`) shipped as 5.2.0 (`2bdd3a7`) and this branch was rebased onto it; Step 1 is the gate that checked this. (An earlier run stopped here before ASD-006 merged.) AC56, AC62, AC67 and AC70 name ASD-006's files, check and release. Step 1 records their real names, and later steps use those names.

## Design

- **One file, one branch (R6).** All watcher code lives in `skills/ai-layout/templates/ai-factory/make/loop.js` (AC60), under its own `// --- watch ---` section of function definitions. Loading the module does no work: no top-level I/O, no timers and no signal listeners. `main()` gets one new branch, `if (command === "watch") return watchCli(rest, { root, stdout: process.stdout, env: process.env })`, placed before the `start` fallthrough. Every other branch, `writeState` (R12), `readState`, `withStateLock` and `pause` stay as they are. The watch code `require`s nothing new: `node:fs` and `node:path` are already loaded, and `parsePlanSteps` and `stepLine` already exist (AC61). `module.exports` gains one key, `watch`, an object that holds the watcher's seams. Every existing export is unchanged, so `check-loop.sh`'s `require(LOOP)` and its fixture copy list (`loop.js`, `contracts.js`, `gate.js`, `safe-files.js`, `assurance.js`) still work unchanged.
- **A pure frame renderer, for this view and for ASD-008 (developer's design note; it adds no criteria).** The drawing is one pure function, `watch.frame(state, titles, now, { details, color, width })`. It returns the frame as an array of lines, with no I/O, no `process.stdout` and no timers.
  - `titles` is a `Map` from step number to title, or `null` when the plan cannot be read (AC21).
  - `now` is a millisecond timestamp.
  - `color` switches the SGR colouring that only live mode uses.
  - `width` is always a whole number of at least 40, in every mode (AC51a). `frame` guarantees that each line it returns is at most `width` characters wide, not counting the SGR sequences that `color` adds. Step titles are cut and end in `…`. The bar shrinks from 30 cells down to whatever room is left after `T/N steps`. Every other single-line string (the plan path, a cause message, the listing row) is also cut with `…`. Lines of a `--details` saved output are wrapped at `width`, never cut, so no output is lost (see *Ambiguities*). Widths are counted in characters, never bytes, so a cut never splits a letter.
  - The width comes from `watch.width({ arg, env, isTTY, columns })`, which is pure and is called outside `frame`. The order is `--width <n>`, then `COLUMNS` when it is a whole number, then the TTY's `columns` when stdout is a TTY, then 100. Any value below 40 is drawn at 40 (AC51a). Live mode re-reads it on each redraw, so a resized terminal is followed. ASD-008's pane can run the plain-mode watcher with `--width` or call `frame` with its own width.
  - Character stripping (AC45) happens inside `frame`, so every caller gets clean lines.

  The code around `frame` takes care of the rest: reading the state and the plan (`watch.readState`, `watch.titles`), picking the loop (`watch.select`), choosing the mode (`watch.mode({ isTTY, env })`), the plain and live writers, following, signals and the stall line. The stall line is added after `frame` returns, so `frame` stays a function of the state alone. Later, ASD-008's plugin pane can `require` the module and call `watch.frame` without a terminal. Exporting it does not change `check-loop.sh`'s `require`, so no follow-up is needed for that.
- **Statuses and times.** Status is checked in the spec's order: done, running (with its mode), applying, failed, timeout, waiting (`waiting on <unticked refs>`, taken from `waitsFor`), ready. Durations print as `37s`, `4m12s` and `1h04m12s`. An elapsed time or duration that cannot be computed prints as the word `unknown` (AC38, AC40). A ticked step with no `finished[]` entry prints no duration (AC41). The loop total runs from `created_at` to `now`, or to `ended.at` once the loop has ended (AC42). The header is `/fc:loop <id>  <plan>`, then `running · <total> elapsed` or `ended (code N) · <total>`. The bar is 30 cells with `T/N steps`. Below them come one line per step (`S<n>`, title, status, mode, time) and then the causes. The mock described in the session notes illustrates this layout only; the spec's wording decides.
- **Stripping (AC45, R2, R3).** Each string is decoded as UTF-8 text, never handled as bytes. From that text, drop C0 controls except LF, DEL, C1 U+0080–U+009F, and the bidi controls U+061C, U+200E, U+200F, U+202A–U+202E and U+2066–U+2069. LF is kept only inside a `--details` saved output; everywhere else it becomes a space. TAB is a C0 control, so it becomes a space too. The same stripping applies to the plan path in the listing table and to every cause field that is printed.
- **Reading (AC14–AC17, AC52a, R4, R12).** `watch.readState` reads `state.json` with no lock (AC53). A JSON parse failure is reread up to 5 times, about 100 ms apart. One-shot mode may use the existing synchronous `pause`. Follow mode uses async timers only (R9). ENOENT gives AC14 on the first read and AC52a while following. The plan path is resolved with `realpath` and must lie under `ai-factory/plans/` or `ai-factory/plans/done/`. Otherwise no titles are drawn, as AC21 does (R4). The no-ID listing skips directory names that do not match `LOOP_ID` and any `state.json` that `lstat` does not report as a regular file (R4).
- **Arguments (AC13, AC51a).** The arguments are an optional loop ID plus `--follow`, `--details` and `--width <n>`, all parsed by one pure `watch.parseArgs`. `--width` takes a separate value, which must match `^[0-9]+$` and lie between 40 and 500. A missing, non-numeric, fractional, negative or out-of-range value is refused, and so is a repeated `--width`. Anything else, or an ID that does not match `LOOP_ID`, is refused too. Every refusal happens before any filesystem call and gives one line naming the argument, then the usage, then exit 2. Error lines and the usage go to stderr; snapshots and the AC12 line go to stdout. Exit codes: 0 for a snapshot, a listing or no loops; 2 for a refusal or a missing state; 1 for an unreadable or vanished state.
- **Follow (AC46–AC52b, R9, R10).** The poll runs on `setInterval` at 1 s, never on `Atomics.wait`.
  - **Live mode** hides the cursor when it starts. Each redraw moves the cursor home and clears the screen below it (`ESC[H ESC[J`). The cursor is shown again and a newline written on `SIGINT` (exit 0, AC48), on `SIGTERM` and `SIGHUP` (exit 128+n, R9), on `exit`, and before the AC52a exit 1.
  - **Plain mode** prints a snapshot at once. After that it prints only when the bytes of the file change (AC50).
  - **The stall clock** starts at the file's `mtime` on the first read and restarts whenever the file's bytes change. Once it passes `step_timeout` minutes, live mode adds `no update for <N>m — the loop may have stopped; Ctrl-C to quit` to every draw. Plain mode prints it once per stall (AC52b).
  - When the state has `ended`, the final frame is drawn with every cause and the watcher exits 0 (AC47, AC50, AC52).
- **`started_at` and `finished_at` (AC33–AC36, R11).** `next(state, { now = new Date() } = {})` sets `started_at: now.toISOString()` on each `running[]` entry it pushes. `finish(…, { now = new Date() })` copies `started_at` into the `finished[]` record when the running entry has one, and always sets `finished_at`. `version` stays 1. The two new options default to the current time, so the existing calls `loop.next(state)` and `loop.finish(state, …)` in `check-loop.sh` behave as before.
- **Make target (AC59, R1).** Use the same capture pattern as every other `ai.mk` variable: `override LOOP := $(value LOOP)`, the same for `FOLLOW` and `DETAILS`, then `export LOOP FOLLOW DETAILS`. `loop-watch` is added to `.PHONY`. The recipe is one silent line, and make expands none of the three variables in it:

  ```
  @set --; [ -z "$$LOOP" ] || set -- "$$LOOP"; [ "$$FOLLOW" != 1 ] || set -- "$$@" --follow; [ "$$DETAILS" != 1 ] || set -- "$$@" --details; exec node ai-factory/make/loop.js watch "$$@"
  ```

  The shell reads each value from the environment as one quoted argument. In the final form the recipe must keep two properties: no `$(LOOP)`, `$(FOLLOW)` or `$(DETAILS)` appears anywhere in it, and with none of the three set, node gets no argument after `watch`.
- **Choosing the live-mode test method up front (R8).** Node has no pseudo-terminal, no dependency is allowed, and `script(1)` takes different arguments on each platform. The method has three layers:
  1. **In process (required).** `watch.mode` is called with `{ isTTY, env }` for every combination: TTY or not; `TERM` unset, `xterm` or `dumb`; `NO_COLOR` unset, empty or `1`. `watch.frame` is called with an injected `now`. These calls prove the mode rules (AC49) and every drawing criterion exactly, with no timing.
  2. **Child-process TTY harness (required, every platform).** The check writes `tty-harness.js` into the fixture under `ai-factory/runs/tmp/`. The harness sets `Object.defineProperty(process.stdout, "isTTY", { value: true })` and `columns = 100`. It then `require`s the fixture's own `ai-factory/make/loop.js` and calls `watch.cli(argv, { root })`, the same function `main()`'s watch branch calls. The check spawns the harness with real timers, real file rewrites and real signals (`child.kill("SIGINT")`). It proves:
     - AC46: a redraw within 2 s, with the count up by one, and between 2 and 5 frames in about 3 s;
     - AC47 and AC52: the final frame, then exit 0;
     - AC48: exit 0, stdout ending with `ESC[?25h` followed by `\n`;
     - AC52a and AC52b in live mode (the `mtime` is moved back 31 min with `fs.utimesSync`);
     - AC49: no ESC in the output with `TERM=dumb` and with `NO_COLOR=1`;
     - R9: `SIGTERM` also restores the cursor.

     A timing failure prints the measured delay.
  3. **`script(1)` smoke (optional, labelled).** On `Darwin`, the check runs `script -q /dev/null node ai-factory/make/loop.js watch <id>`. On `Linux`, it runs `script -qec "node ai-factory/make/loop.js watch <id>" /dev/null`, where `<id>` has already matched `LOOP_ID`. The output must contain an ESC sequence and `T/N steps`. When `script` is missing or the platform is another one, the check prints `SKIP follow/tty-smoke (<platform>): <reason>`. A skip counts as neither a pass nor a failure. Layer 2 remains the required proof.
- **The check file (AC68) and parallel steps.** The check is a new `skills/ai-layout/scripts/check-loop-watch.sh`, written in the style of `check-loop.sh`: groups, one Node heredoc, and fixture repos under `ai-factory/runs/tmp/`. `check-loop.sh` keeps all of its existing assertions (AC36, R6).
  - **Groups:** `fields`, `render`, `details`, `select`, `errors`, `follow`, `readonly`, `make`, `surface`, `docs`, `release`.
  - **Output format:** each failure prints `FAIL <group>/<case>: <message>`. A group that has no cases prints `FAIL <group>: no cases yet (plan ASD-007 Step <N> adds them)`, where N comes from a fixed map that Step 2 writes and no later step edits. A clean run ends with `loop-watch ok — <n> cases (<group>)`.
  - **Section layout:** Step 2 writes one marked section per group, in the order above, each a header comment and an insertion marker. At least 6 unchanged lines separate consecutive markers. A step adds cases only below its own group's marker, so Steps 7, 8 and 9 can run in parallel worktrees and still apply as separate hunks (ASD-004 lesson a).
  - **The `PRE_ASD007` pin:** a full SHA, recorded by Step 1, written by Step 2. The check compares files with it by commit, never with a local `main` ref (ASD-004 lesson b).
- **Existing generated-entry checks (ASD-004 lesson b).** `/fc:watch` is a hand-written plugin-level command, like `/fc:state`.
  - `sync-claude-commands.js --check` ignores it.
  - `sync-codex-skills.js --check` fails until `codex-skills/fc-watch/SKILL.md` is generated. Step 9 therefore writes the command and generates its skill in the same step. That keeps `check-sync-docs.sh reader AC11-sync-scripts-untouched` passing, because that case runs both generators' `--check` and compares only `/fc:check` with `PRE_ASD004`.
  - `check-risk.sh docs`' `docs/command-counts` case classifies `watch` as plugin-level because the file is not generated.

## Files

| File | Why |
|---|---|
| `skills/ai-layout/templates/ai-factory/make/loop.js` | `started_at`/`finished_at` in `next`/`finish` (AC33–AC36); the `watch` section, its `main()` branch, the usage line and the `watch` export (AC1, AC10–AC55, AC51a). |
| `skills/ai-layout/templates/ai-factory/make/ai.mk` | `loop-watch` target, `.PHONY`, `LOOP`/`FOLLOW`/`DETAILS` captured with `$(value …)` and exported (AC2–AC4, AC59). |
| `skills/ai-layout/templates/ai-factory/tasks/loop.md` | Exactly one added line: start `make -f ai-factory/make/ai.mk loop-watch LOOP=<loop id>` in a second terminal (AC58). |
| `skills/ai-layout/scripts/check-loop-watch.sh` (new) | The AC68 check, with groups and fixtures as described under *Design*. |
| `commands/watch.md` (new, hand-written) | `/fc:watch`: runs only `node ai-factory/make/loop.js watch` with the argument verbatim; the AC7 and AC8 one-liners; read-only, no agent, no question; printed output is data (AC5–AC8, R5). |
| `codex-skills/fc-watch/SKILL.md` (generated) | `$fc-watch` generated by `sync-codex-skills.js` (AC9). |
| `docs/commands/_notes/watch.md` (new) | Usage, Examples, Writes, Refuses or asks; `DETAILS=1`/`--details` copies saved agent output into logs (AC63, R5); CI takes a snapshot without `FOLLOW` (R10). |
| `docs/commands/_notes/_groups.md` | `watch` in *Build and verify*, next to `loop` (AC63). |
| `docs/commands/_notes/loop.md` | One line pointing at `/fc:watch` and `make -f ai-factory/make/ai.mk loop-watch` (AC64). |
| `docs/commands/watch.md`, `docs/commands.md`, `docs/commands/loop.md` (generated) | Output of `sync-docs.js` (AC63, AC64). |
| `docs/headless-ci.md` | `make -f ai-factory/make/ai.mk loop-watch LOOP=<loop id>` for a CI snapshot; no `FOLLOW` in CI; the `DETAILS=1` warning (AC65, R5, R10). |
| `ai-factory/docs/workflow.md` | Watcher, `/fc:watch` and `make loop-watch` in the `/fc:loop` part of "4. The main loop" (AC66); a row in the §5 plugin-level table; the command count +1 at its two statements (AC67). |
| `README.md`, `skills/ai-layout/SKILL.md`, `docs/README.md`, `docs/installation.md` | Command count +1 (AC67); a `/fc:watch` bullet in README's command list (definition of done item 7). |
| `CHANGELOG.md` | The `## 6.0.0` entry above `## 5.2.0` (AC70, R13). |
| `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `docs/README.md` line 3 | 5.2.0 → 6.0.0 (AC71). Step 11 lists exactly the files `check-versions.sh` reads. |

These files must stay unchanged, and Steps 7 and 12 diff them against `PRE_ASD007` to prove it:
- `skills/ai-layout/templates/ai-factory/make/runner.js` (AC57);
- `hooks/hooks.json`, `skills/ai-hooks/`, `make/lifecycle-events.js`, `make/delivery-status.js`, `skills/ai-layout/scripts/state.sh`, `commands/state.md` and `commands/current.md`, plus ASD-006's listing script, whose path Step 1 records (AC62);
- `skills/ai-layout/scripts/check-loop.sh` (AC36, R6);
- `skills/ai-layout/templates/ai-factory/make/safe-files.js`, and `writeState` in `loop.js` (R12);
- `ai-factory/specs/` other than this feature's own `ASD-007-loop-watch.md`, which this branch adds after `PRE_ASD007`.

## Server vs client components

This does not apply here: the repo has no application code. `loop.js watch` is a local Node CLI, and `/fc:watch` is a markdown prompt that runs it once.

## Steps

- [x] Step 1 — Gate: ASD-006's 5.2.0 is on `main` and this branch starts from it; pin `PRE_ASD007` (R7; precondition for AC56, AC62, AC67, AC70)
  Effort: S · Estimate: dev 0.25–0.5 h, /fc:run ~5–10 min (assumption: no file changes; only git and check commands run and their output is recorded)
  - Stop the run and report if any of these fail. Do not rebase, reset or merge on the developer's behalf.
    - `git fetch origin main` succeeds.
    - `git show origin/main:.claude-plugin/plugin.json` has version `5.2.0`, and `git show origin/main:CHANGELOG.md` has a `## 5.2.0` entry.
    - `git merge-base --is-ancestor origin/main HEAD` exits 0.
    - `commands/current.md` and `codex-skills/fc-current/SKILL.md` exist on HEAD, and `docs/commands/_notes/_groups.md` lists `current`.
  - Record these in the run report:
    - `PRE_ASD007`, the full SHA of `git merge-base origin/main HEAD`;
    - ASD-006's listing script path and its check's path. The ASD-006 plan fixes them as `skills/ai-layout/scripts/current.js` and `skills/ai-layout/scripts/check-current.sh` (with `check-current.sh fixture <dir>` building the AC9 repo); confirm they exist as named on `main`, and if ASD-006 shipped other names, amend AC56 and AC62 before Step 7;
    - the command count `ls commands/*.md | wc -l`, which this plan raises by one;
    - the baseline of the full check suite, noting any check that already fails.
  - Tests: none new. Phase: `step`.
  - Verify (step): `git fetch origin main`; `git merge-base --is-ancestor origin/main HEAD`; `bash skills/ai-layout/scripts/check-versions.sh`; `bash <ASD-006 check path>`; `for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f" || echo "FAIL $f"; done` (never piped).

- [x] Step 2 — `started_at` and `finished_at` in `next` and `finish`; scaffold `check-loop-watch.sh` — AC33, AC34, AC35, AC36 (state and JSON half)
  Effort: L · Estimate: dev 1.5–2.5 h, /fc:run ~20–35 min (assumption: size L because it adds a new check with a fixture builder; uncertainty S, two additive fields in known functions)
  - `loop.js`: add `now` to `next` and `finish` as described under *Design*. Add nothing else.
  - `check-loop-watch.sh`:
    - Write the scaffold described under *Design → The check file*: groups, the fixed `no cases yet` map (fields 2, render 3, details 4, select 5, errors 5, follow 6, readonly 7, make 8, surface 9, docs 10, release 11), the `PRE_ASD007` constant from Step 1, and a fixture builder copied from `check-loop.sh` `repo()`.
    - Add a `prior(dir)` helper that writes `PRE_ASD007`'s `loop.js` from `git show` into a second fixture.
  - Tests (`fields` group):
    - `AC33-next-started-at`: after `start` and `next`, each `running[]` entry has `started_at` that matches `^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$`, the same shape as `created_at`.
    - `AC34-finish-copies-started-at`: for each of `met`, `failed` and `timeout` (`finish --dry`), the `finished[]` record has the running entry's `started_at` and a `finished_at` that is not earlier than it.
    - `AC35-finish-without-started-at`: delete `started_at` from `running[]` in `state.json`, then run `finish`. The record has `finished_at` and no `started_at`. `finish`'s stdout JSON equals that of a twin fixture with `started_at`.
    - `AC36-state-and-answers-unchanged`: run `start`, `next`, `finish --dry` and `end` on both fixtures, current and `prior`. With `loop_id`, `created_at`, `ended.at` and the new fields normalised, every subcommand's stdout JSON is deep-equal and so is the final `state.json`. `version` is 1. The `usage` text is compared in Step 3.
    - `AC36-check-loop-unchanged`: `git diff --quiet PRE_ASD007 -- skills/ai-layout/scripts/check-loop.sh`.
  - Verify (red): `bash skills/ai-layout/scripts/check-loop-watch.sh fields`. Expected red:
    - `FAIL fields/AC33-next-started-at: Step 1's running[] entry has no started_at`;
    - `FAIL fields/AC34-finish-copies-started-at: Step 1's finished[] entry has no finished_at`;
    - `FAIL fields/AC35-finish-without-started-at: Step 1's finished[] entry has no finished_at`.

    The `AC36-*` cases pass at red, which is not a red failure: they guard against regressions.
  - Verify (step): `bash skills/ai-layout/scripts/check-loop-watch.sh fields`; `bash skills/ai-layout/scripts/check-loop.sh`; `node --check skills/ai-layout/templates/ai-factory/make/loop.js`.
  - Expected still red after this step: `bash skills/ai-layout/scripts/check-loop-watch.sh` with no group prints `FAIL <group>: no cases yet (plan ASD-007 Step N adds them)` for every group except `fields` until Step 11.

- [x] Step 3 — The pure `watch.frame` renderer and the one-shot `watch <id>` CLI in plain mode — AC1, AC18, AC19, AC20, AC21, AC22, AC23, AC24, AC25, AC26, AC27, AC28, AC29, AC30, AC31, AC32, AC36 (usage), AC37, AC38, AC39, AC40, AC41, AC42, AC49 (non-TTY), AC51 (plain), AC51a
  Effort: M · Estimate: dev 3–4 h, /fc:run ~30–45 min (assumption: size M, `loop.js` and one check group; uncertainty M, the layout, the time formats and the width fitting are new but fully specified)
  - `loop.js`:
    - Add the `// --- watch ---` section with `frame`, `titles` (it reuses `stepLine`, strips `**`, takes the text after `Step N —`, and applies the R4 realpath boundary), the status classifier and `formatDuration`.
    - Add `watch.width` and the width fitting inside `frame`, as described under *Design → A pure frame renderer* (AC51a).
    - Add `watch.parseArgs`, which takes the loop ID and `--width <n>` with the AC51a refusals. Step 4 adds `--details` to it and Step 6 adds `--follow`.
    - Add a minimal `watch.cli` that handles `watch <id> [--width <n>]` without `--follow`. It reads once with no rereads yet and writes the plain frame at the resolved width.
    - Add the `main()` branch and the USAGE line `       loop.js watch [<loop-id>] [--follow] [--details] [--width 40-500]`.
    - Add `module.exports.watch`.
  - Tests (`render` group). Most cases call `watch.frame` in process with a fixed `now`. A few spawn `node ai-factory/make/loop.js watch <id>` in a fixture, where stdout is a pipe and therefore not a TTY.
    - `AC1-one-snapshot`: the CLI exits 0 with one frame on stdout. `AC51-plain-one-shot`: the process exits by itself.
    - `AC18-bar-and-plan`: 5 steps, 2 ticked, so `2/5` and the plan path appear.
    - `AC19-one-line-per-step`: the order follows `steps[]`, with no extra numbers.
    - `AC20-title`: Step 2's title is `Add the parser`. `AC21-plan-missing`: no titles, exit 0. Also `R4-plan-outside`: a state whose `plan` is `../outside.md` gets no titles.
    - Statuses: `AC22-done`; `AC23-running-main`; `AC24-running-worktree`; `AC25-applying`; `AC26-failed`; `AC27-timeout`; `AC28-waiting-explicit` gives `waiting on 2, 3`; `AC29-waiting-implicit` gives `waiting on 2`; `AC30-ready`.
    - `AC31-cause`; `AC32-ended-code-4`.
    - Times: `AC37-elapsed-formats` gives `37s`, `4m12s` and `1h04m12s` from `started_at` with an injected `now`. `AC38-elapsed-unknown`; `AC39-durations`; `AC40-duration-unknown`; `AC41-ticked-before-start`; `AC42-total` gives `10m00s` while running and measures from `created_at` to `ended.at` once ended.
    - `AC49-plain-non-tty`: the CLI output has no U+001B and no U+009B.
    - `AC36-usage-gains-watch`: `USAGE` equals `PRE_ASD007`'s `USAGE` plus exactly the watch line, and the unknown-subcommand JSON for another name is unchanged.
    - Width (AC51a):
      - `AC51a-width-order`: in process, `watch.width` returns `--width` over `COLUMNS` over the TTY's `columns` over 100. `COLUMNS` values `abc`, `80.5` and an empty string are ignored. A value of 30 from any source is drawn at 40.
      - `AC51a-title-cut`: `--width 60` with a 72-character title. Through the CLI, Step 1's line is at most 60 characters and its title ends in `…`.
      - `AC51a-all-lines-fit`: for widths 40, 60 and 100 (in process, with a long plan path, a long cause message and 12 steps), every line is at most the width in characters, and the bar has fewer cells at 40 than at 100.
      - `AC51a-default-100`: the CLI on a pipe with no `COLUMNS` draws no line wider than 100.
      - `AC51a-columns-env`: the CLI with `COLUMNS=50` draws no line wider than 50.
      - `AC51a-refused`: `--width` given `39`, `501`, `60.5`, `-60`, `abc`, no value, or twice. Each gives one line naming the value, then the usage, exit 2, no frame. The case runs with the loop directory `chmod 000`, with the same root `SKIP` as `AC13-refusals` in Step 5.
    - CLI cases match the time loosely (`4m1[23]s`). Exact times are checked only in process.
  - Verify (red): `bash skills/ai-layout/scripts/check-loop-watch.sh render`. Expected red:
    - `FAIL render/AC1-one-snapshot: watch exited 2, not 0 (stderr: loop: unknown subcommand 'watch')`; the `AC51a-title-cut`, `AC51a-default-100`, `AC51a-columns-env` and `AC51a-refused` CLI cases fail the same way;
    - each in-process case fails with `FAIL render/<case>: loop.js exports no watch.frame()`, or `no watch.width()` for `AC51a-width-order`;
    - `FAIL render/AC36-usage-gains-watch: USAGE has no 'loop.js watch' line`.
  - Verify (step): `bash skills/ai-layout/scripts/check-loop-watch.sh fields`; `bash skills/ai-layout/scripts/check-loop-watch.sh render`; `bash skills/ai-layout/scripts/check-loop.sh`; `node --check skills/ai-layout/templates/ai-factory/make/loop.js`.

- [x] Step 4 — `--details` and character stripping — AC43, AC44, AC45, AC49 (`--details`, non-TTY)
  Effort: M · Estimate: dev 1–1.5 h, /fc:run ~15–25 min (assumption: size M, `loop.js` and one check group; uncertainty S once AC45 defines characters, not bytes)
  - `loop.js`: `frame` takes the `details` option. With it, the worktree path goes under the step line, and each saved `output` goes under its step with its LF kept. `watch.cli` accepts `--details`. Add a `sanitize(text, { keepNewlines })` helper as described under *Design → Stripping*.
  - Tests (`details` group):
    - `AC43-default-hides`: neither `ai-factory/runs/tmp/worktrees/W-S2` nor `SECRET-MARKER` appears.
    - `AC44-details-shows`: both appear under Step 2's line and under the finished step.
    - `AC51a-details-wrapped`: with `--width 40` and a saved output holding a 120-character line, every printed line is at most 40 characters, and the joined wrapped lines hold the whole output (see *Ambiguities*).
    - `AC45-controls-stripped`, run in process and through the CLI, with and without `--details`:
      - the fixture puts ESC, BEL, CR, DEL, U+009B, U+0085, U+202E and TAB into a cause message, an `output` and a plan title;
      - the decoded output has no terminal control character, and every LF in `--details` output comes from the saved output;
      - the bytes of `Перевірка Л` (`d0 9b` included) appear unchanged in stdout's raw buffer.
    - `AC49-plain-details`: the `--details` output has no ESC or U+009B.
  - Verify (red): `bash skills/ai-layout/scripts/check-loop-watch.sh details`. Expected red:
    - `FAIL details/AC44-details-shows: watch exited 2, not 0 (stderr: loop: '--details' is refused …)`, or `SECRET-MARKER` missing, depending on how Step 3 parsed arguments;
    - `FAIL details/AC45-controls-stripped: output holds U+001B …`.

    `AC43-default-hides` passes at red, which is not a red failure.
  - Verify (step): `bash skills/ai-layout/scripts/check-loop-watch.sh render`; `bash skills/ai-layout/scripts/check-loop-watch.sh details`; `node --check skills/ai-layout/templates/ai-factory/make/loop.js`.

- [x] Step 5 — Picking the loop, refusals and bounded rereads — AC10, AC11, AC12, AC13, AC14, AC15, AC16
  Effort: M · Estimate: dev 1.5–2.5 h, /fc:run ~20–30 min (assumption: size M, `loop.js` and two check groups; uncertainty M, torn reads against an in-place writer)
  - `loop.js`:
    - `watch.select`: with no ID, show the newest running loop by `created_at`. When every loop has ended, print the table, newest first: loop ID, plan, `ended <code>` and `created_at`. With no loops, print `no loops under ai-factory/runs/tmp/loop/`. Apply the R4 skips.
    - Argument refusal happens before any fs call.
    - `watch.readState` has the bounded rereads. Its unreadable line is `loop state <rel path> is unreadable`.
  - Tests:
    - `select` group: `AC10-newest-running`; `AC11-ended-table` (no bar, no step line, exit 0); `AC12-no-loops`, both with no directory and with an empty one; `R4-listing-skips` (a directory `not-a-loop`, and a `state.json` symlink).
    - `errors` group:
      - `AC13-refusals` for `../../etc`, `loop-1` and `--foo`: one line naming the argument, then the usage, exit 2, no frame. The case runs with the loop directory `chmod 000`, which proves nothing under it is read. The case is skipped with a printed `SKIP` when the check runs as root.
      - `AC14-missing-state` gives `no loop state for L`, exit 2.
      - `AC15-torn-then-valid` runs in process with an injected reader: the first read is `{"schema":`, the second is valid. One frame, exit 0.
      - `AC16-never-parses`: at most 5 reads about 100 ms apart, where 5 reads take between 350 and 1500 ms, then the unreadable line and exit 1.
  - Verify (red): `bash skills/ai-layout/scripts/check-loop-watch.sh select` and `bash skills/ai-layout/scripts/check-loop-watch.sh errors`. Expected red:
    - `FAIL select/AC10-newest-running: watch with no loop ID exited 2, not 0`, because Step 3's CLI requires an ID;
    - `FAIL errors/AC15-torn-then-valid: loop.js exports no watch.readState()`;
    - `FAIL errors/AC16-never-parses: read the state 1 time(s), not 5`.

    `AC13`/`AC14` may already pass after Step 3, which is not a red failure.
  - Verify (step): `bash skills/ai-layout/scripts/check-loop-watch.sh render`; `bash skills/ai-layout/scripts/check-loop-watch.sh details`; `bash skills/ai-layout/scripts/check-loop-watch.sh select`; `bash skills/ai-layout/scripts/check-loop-watch.sh errors`; `node --check skills/ai-layout/templates/ai-factory/make/loop.js`.

- [x] Step 6 — `--follow` in live and plain mode, signals, a vanished state and the stall line — AC17, AC46, AC47, AC48, AC49 (TTY cases), AC50, AC51 (live), AC51a (TTY width), AC52, AC52a, AC52b
  Effort: L · Estimate: dev 3–4.5 h, /fc:run ~35–60 min (assumption: size M, `loop.js` and one check group with the TTY harness; uncertainty L, async follow, signal handling and timing assertions are new in this repo)
  - `loop.js`:
    - Add `watch.mode`, plus the async follow loop, live redraws, plain change detection, the stall clock and signal and `exit` cleanup, as described under *Design → Follow* (R9, R10).
    - Leave `pause` and `withStateLock` untouched.
    - Add the vanished line `loop state for L is gone`.
  - Tests (`follow` group), using the three layers of R8 described under *Design*:
    - `AC49-mode-matrix`: in process, over the combinations of TTY, `TERM` and `NO_COLOR`.
    - `AC51a-tty-width`: the harness with `columns = 72` and no `COLUMNS` draws live frames whose lines, with SGR and cursor sequences removed, are at most 72 characters. With `COLUMNS=50` set as well, the limit is 50.
    - `AC49-tty-dumb` and `AC49-tty-no-color`: the harness output has no ESC.
    - `AC51-live-one-shot`: through the harness without `--follow`, one frame, then exit.
    - `AC46-live-redraw`: the check ticks a step through the fixture's `loop.js finish --dry`. A redraw follows within 2 s, the count goes up by 1, and 2–5 frames appear in about 3 s.
    - `AC47-live-end`, `AC48-sigint` and `R9-sigterm-restores`.
    - `AC50-plain-follow`: piped stdout. A snapshot appears at once, and no new one while the bytes are unchanged for 2 intervals. The final snapshot shows every cause, then exit 0.
    - `AC52-already-ended`.
    - `AC17-torn-while-following`: the check writes an invalid file for one interval, then a valid one. No exit, and the next frame is drawn.
    - `AC52a-gone`: the state is deleted, giving `loop state for L is gone`, exit 1, and in live mode the cursor shown first. `AC52a-reappears`: the file comes back within the rereads, so no message.
    - `AC52b-stall`, in live and plain mode: the `mtime` is moved back 31 min with `step_timeout` 30, so the line appears. It is printed once in plain mode, and it clears after a change.
    - `tty-smoke`, the optional layer 3.
  - Verify (red): `bash skills/ai-layout/scripts/check-loop-watch.sh follow`. Expected red:
    - `FAIL follow/AC49-mode-matrix: loop.js exports no watch.mode()`;
    - `FAIL follow/AC50-plain-follow: watch --follow exited 2, not following`, or `…was refused`, depending on Step 3's argument parsing;
    - `FAIL follow/AC46-live-redraw: no redraw within 2000 ms`.
  - Verify (step): `bash skills/ai-layout/scripts/check-loop-watch.sh follow`; `bash skills/ai-layout/scripts/check-loop-watch.sh render`; `bash skills/ai-layout/scripts/check-loop-watch.sh errors`; `bash skills/ai-layout/scripts/check-loop.sh`; `node --check skills/ai-layout/templates/ai-factory/make/loop.js`.

- [x] Step 7 — Read-only and boundary guards — AC53, AC54, AC55, AC56, AC57, AC60, AC61, AC62
  Effort: M · Estimate: dev 1–2 h, /fc:run ~15–25 min (assumption: size M, check cases only with no product code; uncertainty M, AC56 relies on ASD-006's fixture and script names from Step 1)
  Depends on: 6
  - Edit only the `readonly` section of `check-loop-watch.sh`, below its marker.
  - Tests (`readonly` group):
    - `AC53-lock-held`: `state.lock` is held with the check's own PID and a fresh mtime. The snapshot arrives within 1 s, and the lock's bytes, mtime and inode are unchanged.
    - `AC54-no-writes`: on a clean fixture repo, run the watcher one-shot, and with `--follow` until a scripted `end`. Hash every file under the loop directory and the plan before and after. `find ai-factory -newer` lists nothing new, and `git status --porcelain` is empty.
    - `AC55-follow-three-intervals`: follow a loop with a ready step for about 3.5 s, with no other `loop.js` process. `running`, `pending`, `finished`, `causes` and every `done` stay unchanged.
    - `AC56-current-unchanged`: build ASD-006's AC9 repo with ASD-006's own fixture builder when its check exports one; otherwise use the file set ASD-006's AC9 lists. Add a running loop's directory. ASD-006's listing script prints the same output before the watcher starts and while it follows. Then `bash <ASD-006 check path>` exits 0.
    - `AC57-runner-unchanged`: `git diff --quiet PRE_ASD007 -- skills/ai-layout/templates/ai-factory/make/runner.js`.
    - `AC60-one-file`: `git diff --name-only --diff-filter=A PRE_ASD007 -- skills/ai-layout/templates/ai-factory/make/` is empty, and every entry of `ai-factory/make/` is still a symlink into the template, unchanged since `PRE_ASD007` (the directory holds per-file symlinks, not one link).
    - `AC61-builtins-only`: every `require(` in `loop.js` names `node:*` or `./<file>.js` that exists in `make/`, and the diff adds no `package.json`.
    - `AC62-untouched`: `git diff --quiet PRE_ASD007 -- <the AC62 paths plus ASD-006's listing script>`.
    - `R12-writer-unchanged`: the `writeState` function text equals `PRE_ASD007`'s, and `safe-files.js` is unchanged.
  - Verify (red): `bash skills/ai-layout/scripts/check-loop-watch.sh readonly`. Expected red: none for behaviour, since Steps 3–6 built a reader. Before this step the group prints `FAIL readonly: no cases yet (plan ASD-007 Step 7 adds them)`. Any other red here is a real defect in Steps 3–6 and blocks the step.
  - Verify (step): `bash skills/ai-layout/scripts/check-loop-watch.sh readonly`; `bash <ASD-006 check path>`.

- [x] Step 8 — `make loop-watch` with `LOOP`, `FOLLOW` and `DETAILS` captured as data — AC2, AC3, AC4, AC59
  Effort: M · Estimate: dev 0.75–1.5 h, /fc:run ~10–20 min (assumption: size M, `ai.mk` and one check group; uncertainty S, the capture pattern exists in `ai.mk`)
  Depends on: 6
  - `ai.mk`: make the changes described under *Design → Make target*. Change no other target.
  - Tests (`make` group; the fixture copies the template `ai.mk`; `make -s -f ai-factory/make/ai.mk` runs with `MAKEFLAGS` and `MAKEOVERRIDES` cleared, as in `check-contracts.sh`):
    - `AC2-same-as-node`: with `LOOP=L`, stdout equals `node … watch L`. With no `LOOP`, it equals `node … watch`.
    - `AC3-follow`: with `FOLLOW=1` on a loop that a background script ends, stdout equals `node … watch L --follow` over the same scripted state changes. Without `FOLLOW`, one snapshot.
    - `AC4-details`: `DETAILS=1` equals `--details`. Without it, neither AC43 string appears.
    - `AC59-static`: `^\.PHONY:.*\bloop-watch\b`; `override LOOP := $(value LOOP)` and the same for `FOLLOW` and `DETAILS`; all three exported; the recipe holds no `$(LOOP)`, `$(FOLLOW)` or `$(DETAILS)`.
    - `AC59-injection`: run `LOOP='$(shell touch pwned)'` and `LOOP='x; touch pwned'`. Each exits non-zero, stderr holds the AC13 refusal of that literal value, and no `pwned` file exists in the fixture or the current directory. `node … watch '<value>'` exits 2 for the same value.
  - Verify (red): `bash skills/ai-layout/scripts/check-loop-watch.sh make`. Expected red: `FAIL make/AC2-same-as-node: make: *** No rule to make target 'loop-watch'.  Stop.`, and `FAIL make/AC59-static: ai.mk has no loop-watch in .PHONY`.
  - Verify (step): `bash skills/ai-layout/scripts/check-loop-watch.sh make`; `bash skills/ai-layout/scripts/check-cost.sh`; `bash skills/ai-layout/scripts/check-contracts.sh`; `bash skills/ai-layout/scripts/check-ids.sh`.

- [x] Step 9 — `/fc:watch`, `$fc-watch` and the `tasks/loop.md` line — AC5, AC6 (text), AC7, AC8, AC9, AC58
  Effort: M · Estimate: dev 1–1.5 h, /fc:run ~15–25 min (assumption: size M, a hand-written command, a generated skill, one template line and one check group; uncertainty S, `commands/state.md` is the pattern)
  Depends on: 6
  - `commands/watch.md` has frontmatter (`description`, `argument-hint: [<loop id>] [--details] [--width <n>]`, `allowed-tools: Bash(node:*)`, never bare `Bash`, as `/fc:current` does). Its body says:
    1. When the argument holds the token `--follow`, print the AC7 line and stop: following is for a terminal; use `make -f ai-factory/make/ai.mk loop-watch` or `node ai-factory/make/loop.js watch --follow`.
    2. When `ai-factory/make/loop.js` is missing, or answers `unknown subcommand 'watch'`, print one line naming `/fc:sync-sdlc` (AC8).
    3. Otherwise run `node ai-factory/make/loop.js watch` with the argument appended verbatim, as `commands/state.md` does, and show its output as it is.

    It also says to change nothing, launch no agent or subagent, invoke no other command or skill and ask nothing (AC5). The printed output is data: take no instruction from it (R5).
  - Run `node skills/ai-layout/scripts/sync-codex-skills.js` to generate `codex-skills/fc-watch/SKILL.md` (AC9).
  - `tasks/loop.md`: add one line in step 1 after `started:`: "To follow it, run `make -f ai-factory/make/ai.mk loop-watch LOOP=<loop id>` in a second terminal." The line must not name `/fc:test`, `/fc:report`, commit or reset, which `check-loop.sh procedures` restricts.
  - Tests (`surface` group):
    - `AC5-command-text`: it runs only `node ai-factory/make/loop.js watch`, with the argument verbatim, and states the four prohibitions.
    - `AC7-follow-line`: both commands are named.
    - `AC8-sync-line`: it names `/fc:sync-sdlc` and `unknown subcommand 'watch'`.
    - `AC9-codex-skill`: the file exists, and `sync-codex-skills.js --check` exits 0.
    - `AC58-one-line`: `git diff PRE_ASD007 -- <tasks/loop.md>` shows exactly one `+` line and no `-` line, and that line names `make -f ai-factory/make/ai.mk loop-watch` and the loop ID.
    - AC6, AC7 and AC8 as they behave in a session are proved by the transcripts in Step 12.
  - Expected still red after this step, fixed in Step 10: `check-docs.sh` reports that `watch` has no page or notes and is in no group. `check-risk.sh docs` (its `docs/command-counts` case) and `check-continuation.sh` report that the docs state N while `commands/` holds N+1.
  - Verify (red): `bash skills/ai-layout/scripts/check-loop-watch.sh surface`. Expected red: `FAIL surface/AC5-command-text: commands/watch.md does not exist`, and `FAIL surface/AC58-one-line: tasks/loop.md has 0 added lines, not 1`.
  - Verify (step): `bash skills/ai-layout/scripts/check-loop-watch.sh surface`; `node skills/ai-layout/scripts/sync-codex-skills.js --check`; `node skills/ai-layout/scripts/sync-claude-commands.js --check`; `bash skills/ai-layout/scripts/check-plugin-hosts.sh`; `bash skills/ai-layout/scripts/check-loop.sh procedures`; `bash skills/ai-layout/scripts/check-sync-docs.sh reader`.

- [x] Step 10 — Docs: notes, group, generated pages, headless CI, workflow and the command count — AC63, AC64, AC65, AC66, AC67
  Effort: L · Estimate: dev 1.5–2.5 h, /fc:run ~20–35 min (assumption: size L, more than five files; uncertainty S, `sync-docs.js` and the derived count already exist)
  - Edits:
    - Write `docs/commands/_notes/watch.md` with the four sections. It covers live versus plain mode, `--width` and `COLUMNS` (AC51a), `--details` and `DETAILS=1` copying saved agent output into terminals and CI logs (R5), CI taking a snapshot without `FOLLOW` (R10), and the stall line.
    - `_groups.md`: add `watch` after `loop` in *Build and verify*.
    - `_notes/loop.md`: add one line pointing at `/fc:watch` and `make -f ai-factory/make/ai.mk loop-watch`.
    - `docs/headless-ci.md`: under `TASK=loop`, show `make -f ai-factory/make/ai.mk loop-watch LOOP=<loop id>` with the R5 and R10 notes.
    - `workflow.md` "4. The main loop": in the `/fc:loop` bullet, name the watcher, `/fc:watch` and `make loop-watch`. Add a §5 plugin-level row.
    - Raise the command count by one in README (line ~31), `workflow.md` (two places), `skills/ai-layout/SKILL.md`, `docs/README.md` and `docs/installation.md`. Add a README `/fc:watch` bullet.
    - Run `node skills/ai-layout/scripts/sync-docs.js`.
  - Tests:
    - `docs` group:
      - `AC63-notes-sections`, with four non-empty sections;
      - `AC63-grouped`, `watch` in *Build and verify* next to `loop`;
      - `AC64-loop-notes`, `AC65-headless`, `AC66-workflow`, phrase assertions;
      - `R5-details-warning`, in the notes page and in `headless-ci.md`.
    - Existing checks: `check-docs.sh` (AC63), and `check-risk.sh docs` (its `docs/command-counts` case) with `check-continuation.sh` (AC67). No literal count is added to any check.
  - Verify (red): `bash skills/ai-layout/scripts/check-docs.sh`, left red by Step 9. Expected red: `watch` has no generated page or notes and is in no group. Also `bash skills/ai-layout/scripts/check-risk.sh docs`. Expected red: `README.md says N commands; commands/ holds N+1`, with N recorded in Step 1.
  - Verify (step): `bash skills/ai-layout/scripts/check-loop-watch.sh docs`; `bash skills/ai-layout/scripts/check-docs.sh`; `bash skills/ai-layout/scripts/check-risk.sh`; `bash skills/ai-layout/scripts/check-continuation.sh`; `bash skills/ai-layout/scripts/check-sync-docs.sh`; `bash skills/ai-layout/scripts/check-paths.sh`; `bash skills/ai-layout/scripts/check-state.sh`.

- [x] Step 11 — Release 6.0.0: CHANGELOG and every version field — AC70, AC71
  Effort: M · Estimate: dev 0.5–1 h, /fc:run ~10–20 min (assumption: size M, about five files and one check group; uncertainty S, a mechanical bump following the 5.1.0 pattern)
  - Write a `## 6.0.0 — <date>` entry above `## 5.2.0`. It covers:
    - `loop.js watch`, `/fc:watch`, `$fc-watch`, `make loop-watch` with `LOOP`, `FOLLOW` and `DETAILS`, the `started_at` and `finished_at` fields, and the new `tasks/loop.md` line;
    - **breaking for adopted repos**, because the templates `loop.js`, `ai.mk` and `tasks/loop.md` change, which is why the release is major; adopted repos pick it up with `/fc:sync-sdlc`;
    - that rolling back means resyncing an older plugin, and that a 6.0.0 number cannot be reused (R13);
    - that states from a 5.x `loop.js` show elapsed time as `unknown` (R11);
    - that `--details` and `DETAILS=1` print saved agent output (R5);
    - that CI should take snapshots without `FOLLOW` (R10).
  - Set `6.0.0` in every manifest `check-versions.sh` reads and on `docs/README.md` line 3. Rerun `sync-docs.js` if any generated page carries the version.
  - Tests:
    - `release` group: `AC70-entry` checks the order above `5.2.0` and that each named item and the word breaking are present.
    - `check-versions.sh` (AC71) and `check-release-docs.sh`.
  - Verify (red): `bash skills/ai-layout/scripts/check-loop-watch.sh release`. Expected red: `FAIL release/AC70-entry: CHANGELOG.md has no 6.0.0 entry`.
  - Verify (step): `bash skills/ai-layout/scripts/check-loop-watch.sh release`; `bash skills/ai-layout/scripts/check-versions.sh`; `bash skills/ai-layout/scripts/check-release-docs.sh`; `bash skills/ai-layout/scripts/check-docs.sh`.

- [x] Step 12 — Final verification and MR evidence — AC6, AC7, AC8, AC68, AC69 and every AC through the check suite
  Effort: S · Estimate: dev 0.5–1.5 h, /fc:run ~20–30 min (assumption: size S, no file changes; uncertainty S, though the session transcripts need a live Claude Code and Codex session)
  - Run every command under *Verification → final*. `bash skills/ai-layout/scripts/check-loop-watch.sh` with no group must print `loop-watch ok` and no `no cases yet` line.
  - Record the evidence for the MR. `ai-factory/AGENTS.md` requires a before and after run for a prompt change:
    - `/fc:watch <id>` showing one snapshot (AC6);
    - `/fc:watch --follow` giving the one line (AC7);
    - `/fc:watch` in a repo whose `loop.js` predates this change, giving the `/fc:sync-sdlc` line (AC8);
    - `$fc-watch` on Codex;
    - `make loop-watch FOLLOW=1` in a second terminal during a real `/fc:loop`;
    - whether the `tty-smoke` case ran or was skipped, and on which platform.
  - The MR text names the blast radius: the template changes reach every adopted repo on `/fc:sync-sdlc`, which makes the release 6.0.0 and breaking.
  - Phase: `final`.

## Risks and how each is checked

| Risk | Check |
|---|---|
| R1 (major): make or shell injection through `LOOP`. | Step 8 covers it with `AC59-static` and `AC59-injection`: no `pwned` file, the refusal, exit codes. |
| R2 and R3: byte-wise stripping corrupts UTF-8, or the strip list is incomplete. | Step 4 `AC45-controls-stripped`, using the full character list, TAB and the raw-buffer `Перевірка Л` check. |
| R4 (minor): the plan path or the listing reaches outside the repo. | Step 3 `R4-plan-outside` and Step 5 `R4-listing-skips`. |
| R5 (minor): `--details` copies agent output into logs or the model's context. | Default view tests in Step 4 (AC43), the `DETAILS=1` opt-in in Step 8 (AC4), the data-not-instructions line in Step 9 (`commands/watch.md`), and the warnings in Step 10 (`R5-details-warning`) and Step 11 (CHANGELOG). |
| R6 (major): a fault in the watcher breaks `/fc:loop` everywhere. | *Design → One file, one branch*. Every step that touches `loop.js` runs `node --check` and `check-loop.sh`, which stays unchanged (Step 2 `AC36-check-loop-unchanged`). Step 2 `AC36-state-and-answers-unchanged` diffs the answers against `PRE_ASD007`. |
| R7 (major): ASD-006 is not merged. | The Step 1 gate. Steps 7, 10 and 11 use the names Step 1 recorded. |
| R8 (major): live mode cannot be tested reliably. | The three-layer method under *Design*, decided before any code. Step 6 runs the required harness on every platform. A `script(1)` skip is printed, never silent. |
| R9 (minor): a blocking wait delays SIGINT, and the cursor stays hidden. | Async follow only. Step 6 `AC48-sigint` and `R9-sigterm-restores`. |
| R10 (minor): `--follow` never ends. | AC52a and AC52b in Step 6. The CI guidance comes in Steps 10 and 11. |
| R11 (minor): states from 5.x. | Step 2 `AC35-finish-without-started-at`; Step 3 `AC38-elapsed-unknown` and `AC40-duration-unknown`. |
| R12 (minor): the in-place writer changes. | Step 7 `R12-writer-unchanged`. Torn reads are handled by Step 5 AC15/AC16 and Step 6 AC17. |
| R13 (minor): rolling back. | The Step 11 CHANGELOG line. |
| Timing flakiness in AC46, AC16 and AC55. | Each check uses ranges, not exact values (AC46 at most 2000 ms with 2–5 frames; 5 reads in 350–1500 ms), and a failure prints the measured delay. Exact durations are asserted only in process, with an injected `now`. |
| Parallel worktree steps edit `check-loop-watch.sh` (ASD-004 lesson a). | Only Steps 7, 8 and 9 run in parallel. Each edits only below its own group marker, with at least 6 lines between markers, and none of them touches `loop.js`. Steps 3–6 run in sequence because they share `loop.js`. |
| Plan edits made inside a worktree are not applied back (ASD-004 lesson d). | No step edits this plan. Amendments are made by the developer in the main tree. |
| A new generated command breaks ASD-003's `AC11-sync-scripts-untouched` (ASD-004 lesson b). | Step 9 generates `fc-watch` in the same step and runs `check-sync-docs.sh reader`. |

## Verification

| Phase | Command | ACs | Expected red (identity → cause) |
|---|---|---|---|
| red (Step 2) | `bash skills/ai-layout/scripts/check-loop-watch.sh fields` | AC33–AC35 | `fields/AC33-next-started-at` → `Step 1's running[] entry has no started_at`; `fields/AC34-…` and `fields/AC35-…` → `… finished[] entry has no finished_at` |
| red (Step 3) | `bash skills/ai-layout/scripts/check-loop-watch.sh render` | AC1, AC18–AC32, AC36 (usage), AC37–AC42, AC49, AC51, AC51a | `render/AC1-one-snapshot` and the `AC51a-*` CLI cases → `watch exited 2, not 0 (stderr: loop: unknown subcommand 'watch')`; in-process cases → `loop.js exports no watch.frame()` or `no watch.width()`; `render/AC36-usage-gains-watch` → `USAGE has no 'loop.js watch' line` |
| red (Step 4) | `bash skills/ai-layout/scripts/check-loop-watch.sh details` | AC44, AC45, AC49, AC51a (wrapping) | `details/AC44-details-shows` → `--details` refused or `SECRET-MARKER` missing; `details/AC45-controls-stripped` → `output holds U+001B` |
| red (Step 5) | `bash skills/ai-layout/scripts/check-loop-watch.sh select`, `bash skills/ai-layout/scripts/check-loop-watch.sh errors` | AC10–AC12, AC15, AC16 | `select/AC10-newest-running` → exit 2 with no ID; `errors/AC15-torn-then-valid` → `loop.js exports no watch.readState()`; `errors/AC16-never-parses` → `read the state 1 time(s), not 5` |
| red (Step 6) | `bash skills/ai-layout/scripts/check-loop-watch.sh follow` | AC17, AC46–AC52b, AC51a (TTY width) | `follow/AC49-mode-matrix` → `loop.js exports no watch.mode()`; `follow/AC50-plain-follow` → `--follow` refused or not following; `follow/AC46-live-redraw` → `no redraw within 2000 ms` |
| red (Step 8) | `bash skills/ai-layout/scripts/check-loop-watch.sh make` | AC2–AC4, AC59 | `make/AC2-same-as-node` → `No rule to make target 'loop-watch'`; `make/AC59-static` → `ai.mk has no loop-watch in .PHONY` |
| red (Step 9) | `bash skills/ai-layout/scripts/check-loop-watch.sh surface` | AC5, AC7–AC9, AC58 | `surface/AC5-command-text` → `commands/watch.md does not exist`; `surface/AC58-one-line` → `tasks/loop.md has 0 added lines, not 1` |
| red (Step 10) | `bash skills/ai-layout/scripts/check-docs.sh`, `bash skills/ai-layout/scripts/check-risk.sh docs` | AC63, AC67 | `watch` has no page or notes and is ungrouped; `README.md says N commands; commands/ holds N+1` |
| red (Step 11) | `bash skills/ai-layout/scripts/check-loop-watch.sh release` | AC70 | `release/AC70-entry` → `CHANGELOG.md has no 6.0.0 entry` |
| red (Step 7) | none | — | none: the cases guard what Steps 3–6 built. Any red is a defect. |
| step | as listed in each step | per step | — |
| final | `git merge-base --is-ancestor <PRE_ASD007> HEAD` | AC70 precondition | — |
| final | `bash skills/ai-layout/scripts/check-loop-watch.sh` | AC1–AC5, AC7–AC67 (scripted parts), AC68, AC70 | none; no `FAIL` and no `no cases yet` line |
| final | `for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f" \|\| echo "FAIL $f"; done` (never piped) | AC69, AC36 (`check-loop.sh`), AC56 (ASD-006's check), AC63, AC67, AC71 | none; any `FAIL` line not in Step 1's baseline blocks completion |
| final | `node --check skills/ai-layout/templates/ai-factory/make/loop.js`; `for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done` | R6, definition of done 1 | — |
| final | `node skills/ai-layout/scripts/sync-codex-skills.js --check`; `node skills/ai-layout/scripts/sync-claude-commands.js --check`; `node skills/ai-layout/scripts/sync-docs.js --check` | AC9, AC63 | — |
| final | `git diff --exit-code <PRE_ASD007> -- skills/ai-layout/templates/ai-factory/make/runner.js skills/ai-layout/scripts/check-loop.sh hooks/hooks.json skills/ai-hooks skills/ai-layout/templates/ai-factory/make/lifecycle-events.js skills/ai-layout/templates/ai-factory/make/delivery-status.js skills/ai-layout/templates/ai-factory/make/safe-files.js skills/ai-layout/scripts/state.sh commands/state.md commands/current.md skills/ai-layout/scripts/current.js ai-factory/specs ':(exclude)ai-factory/specs/ASD-007-loop-watch.md'` (this feature's own spec is added after `PRE_ASD007`, so it is excluded) | AC57, AC62, AC36, R12 | — |
| final | `bash ai-factory/make/sync-adapters.sh`, run twice with no diff | definition of done 1 | — |
| final | `bash skills/ai-layout/scripts/check-versions.sh` | AC71 | — |
| final | the session transcripts of Step 12 | AC6, AC7, AC8 | — |

Final completion requires every `final` row to pass. The Step 1 gate must also have passed on the branch as it is at completion.

## Ambiguities (from the spec, not guessed past)

1. **Gate (R7).** ASD-006 is not planned or built, so this plan cannot start. Step 1 stops it until 5.2.0 is on `main`. The names of ASD-006's listing script and check exist only as examples in its spec ("for example `current.sh`", "`check-current.sh`"). Step 1 records the real names, and AC56 and AC62 use them. If ASD-006's AC9 or its file names change, amend AC56 and AC62 before Step 7.
2. **AC56 "the repo of ASD-006's AC9".** It is not settled whether ASD-006's check will export a fixture builder that this check can reuse. If it does not, Step 7 rebuilds the AC9 file set from the ASD-006 spec text, and the two can drift.
3. **AC5 against AC7.** AC5 says the argument is appended verbatim, as `/fc:state` does, and that the script decides. AC7 needs the prompt itself to recognise `--follow` and refuse it, because a plain-mode follow inside a session would never return. The plan has the prompt check for that one token only and pass everything else through.
4. **Output streams and the "unknown" word.** The spec does not say whether refusals go to stdout or stderr. The plan sends refusals and usage to stderr and snapshots to stdout. It also does not say how an unknown elapsed time is drawn. The plan prints the word `unknown`.
5. **Step titles.** AC20 shows a bold title. Plans in this repo write `- [ ] Step N — title — AC…`, and the spec does not say whether the trailing AC list is part of the title. The plan draws everything after `Step N —` and does not trim the AC list. Under AC51a a long title is cut with `…`.
6. **SIGTERM and SIGHUP exit codes.** AC48 fixes SIGINT at exit 0 only. The plan exits 128+n for SIGTERM and SIGHUP after restoring the cursor (R9).
7. **AC6–AC8 in a session.** These criteria describe a model running a prompt. They are proved by a static check of the command text (Step 9) and by session transcripts (Step 12), not by an automated run.
8. **A project task named `watch.md`.** `sync-adapters.js`'s `nativeClaudeCommands` set holds `state` but not the other plugin-level-only names, and the spec does not ask for `watch` to be added. An adopted repo with its own `tasks/watch.md` would get a project pointer beside the plugin's `/fc:watch`. This plan does not change it. ASD-006's spec raises the same collision for `current`.
9. **AC13 "reads no file".** It is proved with the loop directory set to `chmod 000`. That proof does not hold when the check runs as root, so the case prints a `SKIP` there, and the in-process case (refusal before any fs call) remains the proof.
10. **AC51a and strings other than titles.** AC51a says every printed line fits the width, but it names only how titles (cut with `…`) and the bar (shrinks) fit. The plan also cuts the plan path, cause messages and listing rows with `…`. It wraps `--details` saved output at the width rather than cutting it, so the opt-in view loses none of a step's output. A cut cause message can hide the end of a git error in the default view; `--details` does not bring it back, because causes are not saved output. If the developer prefers causes wrapped, Step 3's `AC51a-all-lines-fit` changes with them.
11. **AC51a and `make loop-watch`.** AC59 gives the make target `LOOP`, `FOLLOW` and `DETAILS` only, with no width switch. `COLUMNS` reaches Node through make's environment unchanged, which covers the width through make. The plan adds no `WIDTH` variable to `ai.mk`.

## MR description

**ASD-007: live `/fc:loop` progress view (`loop.js watch`, `/fc:watch`, `$fc-watch`, `make loop-watch`) — release 6.0.0**

### Summary

- `loop.js watch [<loop-id>] [--follow] [--details] [--width 40-500]` is a new subcommand that only reads. It draws a running or ended `/fc:loop` from its `state.json`: the plan path, a progress bar, one line per step (done, running main or worktree, applying, failed, timeout, waiting on N, ready), elapsed times and durations, the loop total and its stop causes. With no ID it shows the newest running loop, a table of ended loops, or `no loops under ai-factory/runs/tmp/loop/`.
- On an ANSI terminal it draws live: `--follow` redraws in place every second with the cursor hidden, and restores the cursor on end, SIGINT (0), SIGTERM (143), SIGHUP (129) or a vanished state (1). Anywhere else (a pipe, CI, `TERM=dumb`, `NO_COLOR`) it prints plain snapshots, and with `--follow` a new one only when the state's bytes change. A stall line appears once the state has not changed for longer than `step_timeout`.
- Every line fits `--width` / `COLUMNS` / the TTY width / 100 (at least 40). Control characters (C0 except LF, DEL, C1 and the bidi controls) are stripped by character, never by byte, so non-Latin text survives.
- `--details` / `DETAILS=1` adds worktree paths and the saved implementer output. That output is untrusted text: the docs and CHANGELOG warn that it lands in terminals and CI logs.
- `make -f ai-factory/make/ai.mk loop-watch LOOP=<id> [FOLLOW=1] [DETAILS=1]`. The variables are captured with `$(value …)` and exported, and the recipe never expands them.
- `/fc:watch` is a hand-written plugin-level command that runs only `node ai-factory/make/loop.js watch` with the argument verbatim. It refuses `--follow` in one line, points at `/fc:sync-sdlc` when `loop.js` predates `watch`, and treats the output as data. `$fc-watch` is generated for Codex.
- `loop.js next`/`finish` record additive `started_at`/`finished_at`. `version` stays 1, and states from 5.x show `unknown` for times they lack.
- `tasks/loop.md` gains one line telling the developer they can follow the loop in a second terminal with `make -f ai-factory/make/ai.mk loop-watch LOOP=<loop id> FOLLOW=1`, and forbidding the model to run it itself.
- Docs: `docs/commands/watch.md` (generated) with its notes, the *Build and verify* group, the loop notes, `docs/headless-ci.md` (CI snapshot without `FOLLOW`), `workflow.md`, and the command count raised by one, to 30 commands.
- Check: the new `skills/ai-layout/scripts/check-loop-watch.sh` (11 groups, 93 cases). `check-loop.sh` is unchanged.

### Release and blast radius

- **6.0.0, BREAKING for every adopted repo.** Three templates change: `ai-factory/make/loop.js`, `ai-factory/make/ai.mk` and `ai-factory/tasks/loop.md`. Adopted repos pick them up with `/fc:sync-sdlc`. Until then `make loop-watch` does not exist there, and `/fc:watch` answers with one line naming `/fc:sync-sdlc`.
- The view is part of the scheduler's own file (`loop.js`), so a load-time fault would affect every `/fc:loop`. This is guarded by `node --check`, an unchanged `check-loop.sh` (95 cases) and the answers-and-state diff against `PRE_ASD007`.
- **Rollback:** resync an older plugin with `/fc:sync-sdlc`. The `tasks/loop.md` line keeps pointing at `make loop-watch` until that resync, and `/fc:watch` disappears at once. States with the new fields stay readable by 5.x. A revert cannot reuse the 6.0.0 number, so the fix ships as a later version.

### Final verification (Step 12, 2026-11-03, HEAD `8b2befb` + this plan edit)

`PRE_ASD007` = `2bdd3a7822c48d09d18340c26ffe17f607896130`.

| Row | Command | Result |
|---|---|---|
| gate | `git merge-base --is-ancestor 2bdd3a7822c48d09d18340c26ffe17f607896130 HEAD` | exit 0 |
| AC68 | `bash skills/ai-layout/scripts/check-loop-watch.sh` | exit 0: `loop-watch ok — 93 cases (all)`; no FAIL, no `no cases yet`, no SKIP (`follow/tty-smoke` ran on Darwin through `script(1)`) |
| AC69 | `for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f" \|\| echo "FAIL $f"; done` (not piped) | 40 checks, no `FAIL` line (includes `check-loop.sh` 95 cases, `check-current.sh` 53, `check-versions.sh`, `check-docs.sh`, `check-risk.sh` 47, `check-sync-docs.sh` 46) |
| R6 / DoD 1 | `node --check skills/ai-layout/templates/ai-factory/make/loop.js`; `for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done` | exit 0; exit 0 |
| AC9, AC63 | `node skills/ai-layout/scripts/sync-codex-skills.js --check`; `… sync-claude-commands.js --check`; `… sync-docs.js --check` | exit 0 (32 skills); exit 0 (21 wrappers); exit 0 (31 command docs) |
| AC57, AC62, AC36, R12 | `git diff --exit-code 08978429… -- runner.js check-loop.sh hooks/hooks.json skills/ai-hooks lifecycle-events.js delivery-status.js safe-files.js state.sh commands/state.md commands/current.md skills/ai-layout/scripts/current.js ai-factory/specs ':(exclude)ai-factory/specs/ASD-007-loop-watch.md'` | exit 0 (every named path exists) |
| DoD 1 | `bash ai-factory/make/sync-adapters.sh`, twice | exit 0 both times; `git status` unchanged, no diff |
| AC71 | `bash skills/ai-layout/scripts/check-versions.sh` | exit 0: `versions ok — 3 manifests and docs/README.md all at 6.0.0` |
| AC6, AC7, AC8 | session transcripts | **PENDING**: need a live model session (see below) |

Script-level demo (a fixture repo under `ai-factory/runs/tmp/`, since removed):
- `loop.js watch <id>`, `watch` (no ID), `--details` and `--width 40` each printed one frame and exited 0. At width 40, titles and the plan path were cut with `…` and the bar shrank.
- `watch ../../etc` was refused with exit 2.
- `make loop-watch LOOP=<id>` printed the same frame.
- Plain `--follow` printed one snapshot at once and another only when the state changed.
- `make loop-watch LOOP=<id> FOLLOW=1 DETAILS=1` followed a scripted `finish --result failed` and then `end`, printed the saved output under the step, drew the final `ended (code 1)` frame and exited by itself after about 5 s.
- A follow on a loop that never ends exited on SIGINT.

A single one-shot snapshot of this branch's own live loop showed S1 and S2 as `unknown` (they ran before `started_at` existed), which is R11 in practice.

### Before/after runs still to attach (live rows, PENDING)

`ai-factory/AGENTS.md` requires a before/after run for a command or template change. These need a model session and are not yet run:
1. `/fc:watch` in Claude Code, with no ID: the newest running loop or the ended table.
2. `/fc:watch <id> --details`: one snapshot with details, no follow (AC6).
3. `/fc:watch --follow`: the one refusal line naming both follow commands (AC7).
4. `/fc:watch` in a repo whose `loop.js` predates `watch`: the `/fc:sync-sdlc` line (AC8).
5. `$fc-watch` in Codex.
6. `make -f ai-factory/make/ai.mk loop-watch LOOP=<id> FOLLOW=1` in a second terminal during a real `/fc:loop` (live redraw, final frame, exit).
7. `/fc:loop`'s new `tasks/loop.md` line, as it is printed at loop start. Compare with the 5.2.0 output for the before side.

### Risk findings R1–R13

| Risk | How it was handled |
|---|---|
| R1 (major) make/shell injection through `LOOP` | `$(value …)` capture plus export, and a recipe that never expands the variables. `make/AC59-static` and `make/AC59-injection` (`$(shell touch pwned)` and `x; touch pwned` are refused, and no `pwned` file is created). |
| R2 (major) byte-wise stripping breaks UTF-8 | Stripping works on decoded characters. `details/AC45-controls-stripped` checks that the raw bytes of `Перевірка Л` (`d0 9b`) survive. |
| R3 (minor) incomplete strip list | C0 except LF, DEL, C1 and the bidi controls, with TAB and CR turned into spaces. Covered by AC45. It is still a deny-list (residual risk). |
| R4 (minor) plan path or listing outside the repo | The plan path is checked with `realpath` against `ai-factory/plans/` (and `done/`). The listing skips names that are not loop IDs and non-regular `state.json` files. Covered by `render/R4-plan-outside` and `select/R4-listing-skips`. |
| R5 (minor) `--details` leaks agent output | Off by default (AC43). Opt-in through `--details`/`DETAILS=1` (AC4). `/fc:watch` treats output as data. Warned in the notes page, `headless-ci.md` and the CHANGELOG (`docs/R5-details-warning`). |
| R6 (major) a watcher fault breaks `/fc:loop` | One `// --- watch ---` section, a module load that does no work, and one `main()` branch. `check-loop.sh` is unchanged (`fields/AC36-check-loop-unchanged`), and answers and state are deep-equal with `PRE_ASD007` (`fields/AC36-state-and-answers-unchanged`). |
| R7 (major) ASD-006 not merged | The Step 1 gate passed on 5.2.0 (`2bdd3a7`). AC56 and AC62 use ASD-006's real `current.js` and `check-current.sh fixture`. |
| R8 (major) live mode hard to test | Three layers: the in-process mode matrix, a child-process TTY harness with real timers and signals, and an optional `script(1)` smoke test, which ran on Darwin here. |
| R9 (minor) blocking wait delays SIGINT | Follow mode uses async `setInterval` only. Covered by `follow/AC48-sigint` and `follow/R9-sigterm-restores`. |
| R10 (minor) `--follow` never ends | A vanished state exits 1 (AC52a). The stall line appears after `step_timeout` (AC52b). The docs tell CI to take snapshots without `FOLLOW`. |
| R11 (minor) 5.x states | `fields/AC35-finish-without-started-at`, `render/AC38-elapsed-unknown` and `render/AC40-duration-unknown`. Seen live on this branch's own loop (S1 and S2 `unknown`). |
| R12 (minor) in-place writer | `writeState` and `safe-files.js` are unchanged (`readonly/R12-writer-unchanged`). Torn reads get bounded rereads (`errors/AC15`, `errors/AC16`, `follow/AC17`). |
| R13 (minor) rollback | The CHANGELOG 6.0.0 rollback note: resync an older plugin, and the 6.0.0 number cannot be reused. |

### Known deviations

- **Commits:** a commit was made after each loop step, at the developer's request. Steps 7–9 ran in parallel worktrees, and their shared `check-loop-watch.sh` was split by section into separate commits (`0a37d37`, `d9efc06`, `cd26223`).
- **Fixed after review:** the `tasks/loop.md` follow line lacked `FOLLOW=1`, so it printed one snapshot. `8b2befb` adds `FOLLOW=1`, together with the CHANGELOG quote.
- **Plan wording fixed in `ecf3d18`:**
  - the R7 gate is recorded as passed;
  - `check-risk.sh docs` is used;
  - Step 9 uses `Bash(node:*)`;
  - AC60 checks per-file symlinks;
  - the Step 12 diff excludes this feature's own spec.
- **Decisions the steps made where the spec was silent:**
  - Refusals and usage go to stderr with a `loop: ` prefix; snapshots go to stdout.
  - `watch.stall` and `watch.sanitize` are exported as extra seams.
  - A CR in a plan title is stripped before parsing, in the watcher only.
  - Arguments are judged as typed.
  - Stripping removes control characters, not whole escape sequences, so `ESC[31m` leaves `[31m`.
  - The ended-loops table has a header row.
  - Unreadable loops are left out of the no-ID listing.
  - A no-ID `--follow` picks the loop synchronously, before the signal handlers are installed. A torn read can block for about 400 ms.
  - `/fc:watch --follow` is refused.
  - `make loop-watch` reports any failure as exit 2.
- **ASD-006 coupling:**
  - AC56 builds its repo with `check-current.sh fixture`.
  - Collision: an adopted repo's own `tasks/watch.md` would collide with `/fc:watch`, as ASD-006's `current` does, because the name is not in `nativeClaudeCommands`. Not addressed here.
- **ASD-008** (the Claude Code pane) exists on this branch only as an exploration. `watch.frame` is the pure renderer it can reuse.

- **After the loop's review** (in-session self-check, request_changes), fixed before the MR leaves Draft:
  - `tasks/loop.md`'s line was worded as an instruction to the model (and, with `FOLLOW=1`, would start a watcher that never returns inside the loop it watches). It now tells the developer they can follow the loop and forbids the model to run it. Still one added line (AC58).
  - `watchFollow` took its change baseline from a second read of `state.json`, not the read it displayed; a write between the two (e.g. `ended`) left the view stale and the watcher never exiting. Both now come from the same read, and an ended state there stops at once. New `follow` case `R-stale-first-read`, shown to fail on the earlier code.
  - `loop.js`'s header comment now documents the final `watch` (optional ID, `--follow`, `--details`, exit codes 0/1/2/129/143).
  - CHANGELOG: answers are unchanged apart from the `usage` text gaining the `loop.js watch` line; the `tasks/loop.md` bullet matches the new wording.
- Commit messages follow this repo's `ASD-NNN Step N: …` style (as ASD-003, ASD-004 and ASD-006 did), not definition-of-done item 6's `ai(<task>): …` form. The MR carries the `ai-assisted` label.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
