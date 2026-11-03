# ASD-007 — Live /fc:loop progress view
Created: 2026-11-02T20:29:56.022Z

A read-only `loop.js watch` subcommand draws a `/fc:loop` from its `state.json`: one progress bar for the plan and one line per step. On an ANSI terminal it redraws live; anywhere else it prints plain snapshots. It is reached through `make loop-watch`, a plugin-level `/fc:watch` command and a generated Codex `$fc-watch` skill. `loop.js` also gains additive `started_at` and `finished_at` fields, so the view can show how long a step has been running or how long it ran.

Parent: `ai-factory/explorations/ASD-007-terminal-progress-view.md`, Option A. The developer settled the exploration's open question 1: "working agents and pipeline" means a live view of a running `/fc:loop` (case a). Option C (a delivery phase strip in `/fc:current`) was not chosen. Option A also settles question 2 (the view runs in a second terminal) and question 4 (no C). Question 5 is settled here: the headless runner prints nothing new, and CI takes a snapshot with `make loop-watch`. No analysis exists for this feature.

`ai-factory/specs/ASD-006-current-command.md` is cited as context and as a release dependency. ASD-006 (`/fc:current`, release 5.2.0) puts "a live view of a running `/fc:run` or `/fc:loop` session" out of its scope. Its AC25 requires that its output not depend on loop state under `ai-factory/runs/`. This feature fills that gap without touching ASD-006's static listing. It lands after ASD-006 as release 6.0.0, a major release because it changes templates, on a branch taken from a `main` that already contains ASD-006. `main` is at 5.1.0 today (ASD-004).

## User story
As a developer running `/fc:loop <plan>`, I want to watch from a second terminal how far the loop has got, which steps are running and in which mode, which are waiting and which have failed, so that I can follow several agents working at once without reading `state.json` by hand or waiting for the loop's final report.

## Acceptance criteria
These criteria use the following terms:
- The **loop directory** is `ai-factory/runs/tmp/loop/`. A **loop state** is `<loop directory>/<loop id>/state.json`, schema `fc-loop-state`, written by `skills/ai-layout/templates/ai-factory/make/loop.js` (spec 0022).
- A **loop ID** is a string matching `loop.js`'s existing `LOOP_ID` pattern, `loop-YYYYMMDDTHHMMSSZ-xxxxxx`.
- The **watcher** is `node ai-factory/make/loop.js watch [<loop id>] [--follow] [--details]`.
- A **snapshot** is one rendering of one loop state.
- **Plain mode** applies when stdout is not a TTY, when `TERM` is `dumb`, or when `NO_COLOR` is set to a non-empty value. **Live mode** is every other case: stdout is a TTY, `TERM` is not `dumb`, and `NO_COLOR` is unset or empty.
- An **ANSI escape sequence** is any character sequence, after UTF-8 decoding, that starts with ESC (U+001B) or with the C1 control CSI (U+009B). Characters, not raw bytes, are meant throughout: the byte `0x9b` inside a multi-byte UTF-8 letter (for example `Л`, bytes `d0 9b`) is part of that letter, not a control.
- A **terminal control character** is, after UTF-8 decoding, any C0 control U+0000–U+001F except LF (U+000A), DEL (U+007F), any C1 control U+0080–U+009F, or a Unicode bidirectional control (U+061C, U+200E, U+200F, U+202A–U+202E, U+2066–U+2069).
- A **ticked** step is an entry of the state's `steps[]` whose `done` is `true`. The **total** is the number of entries in `steps[]`.
- A step **waits for** the steps `loop.js` already makes it wait for: the steps in its `depends`, plus every earlier step that has no `Depends on:` line (`waitsFor` in `loop.js`).
- A step's **status** is the first of these that holds, checked in this order:
  1. **done**: it is ticked.
  2. **running**: it has an entry in `running[]`. Its **mode** is that entry's `mode`, `main` or `worktree`.
  3. **applying**: its number is in `pending[]` (it finished in a worktree and is waiting to be applied).
  4. **failed**: it has a `finished[]` entry whose `result` is `failed`.
  5. **timeout**: it has a `finished[]` entry whose `result` is `timeout`.
  6. **waiting**: at least one step it waits for is not ticked.
  7. **ready**: none of the above.
- A loop has **ended** when its state has an `ended` object. A loop is **running** when its state has no `ended`.

**Surface**
- **AC1.** Given a loop state for loop ID `L`, when `node ai-factory/make/loop.js watch L` runs, then it prints one snapshot of that loop on stdout and exits 0.
- **AC2.** Given the loop of AC1, when `make -f ai-factory/make/ai.mk loop-watch LOOP=L` runs, then its output is identical to that of `node ai-factory/make/loop.js watch L` in the same mode. When `LOOP` is not given, its output is identical to that of `node ai-factory/make/loop.js watch` with no loop ID.
- **AC3.** Given the running loop of AC1 in plain mode, when `make -f ai-factory/make/ai.mk loop-watch LOOP=L FOLLOW=1` runs until the loop ends, then its output is identical to that of `node ai-factory/make/loop.js watch L --follow` over the same state changes. Without `FOLLOW`, the target passes no `--follow` and prints one snapshot.
- **AC4.** Given the loop state of AC43, when `make -f ai-factory/make/ai.mk loop-watch LOOP=L DETAILS=1` runs, then its output is identical to that of `node ai-factory/make/loop.js watch L --details`. Without `DETAILS`, the target passes no `--details`, and the output contains neither string of AC43.
- **AC5.** Given `commands/watch.md`, when it is read, then it tells the model to run only `node ai-factory/make/loop.js watch`, with the developer's argument appended verbatim, as `commands/state.md` does with its script. It also tells the model to change nothing, to launch no agent or subagent, to invoke no other command or skill, and to ask the developer nothing.
- **AC6.** Given a repo with the loop of AC1, when `/fc:watch L` runs in a session, then it shows one snapshot of loop `L`, as AC1 prints it, and does not follow.
- **AC7.** Given `/fc:watch` with `--follow` among its arguments, when it runs, then it prints one line saying that following is for a terminal. The line names `make -f ai-factory/make/ai.mk loop-watch` and `node ai-factory/make/loop.js watch --follow` as the way to follow a loop. It runs no watcher and prints no snapshot.
- **AC8.** Given a repo where `ai-factory/make/loop.js` does not exist, or exists without the `watch` subcommand (it answers `unknown subcommand 'watch'`), when `/fc:watch` runs, then it prints one line that names `/fc:sync-sdlc` as the fix, and prints no snapshot.
- **AC9.** Given `commands/watch.md`, when `node skills/ai-layout/scripts/sync-codex-skills.js` runs, then it generates `codex-skills/fc-watch/SKILL.md` from that command, and `node skills/ai-layout/scripts/sync-codex-skills.js --check` exits 0 on the committed tree.

**Which loop**
- **AC10.** Given a loop directory with three loops, where loop `A` has ended, loop `B` is running with `created_at` `2026-11-02T10:00:00Z`, and loop `C` is running with `created_at` `2026-11-02T11:00:00Z`, when the watcher runs with no loop ID, then it prints a snapshot of loop `C`.
- **AC11.** Given a loop directory with two loops that have both ended, when the watcher runs with no loop ID, then it prints one table with one row per loop, newest `created_at` first. Each row shows the loop ID, the plan path, the status and the `created_at` time. The status is `ended` with the `ended.code`. No step line and no progress bar are printed, and the exit status is 0.
- **AC12.** Given a repo with no loop directory, or an empty one, when the watcher runs with no loop ID, then it prints one line saying that there are no loops under `ai-factory/runs/tmp/loop/`, and exits 0.

**Errors**
- **AC13.** Given the argument `../../etc` or `loop-1`, which is not a loop ID, or an option the watcher does not take, such as `--foo`, when the watcher runs with it, then it prints one line naming that argument as refused, followed by the watcher's usage. It reads no file under the loop directory, prints no snapshot and exits 2.
- **AC14.** Given a loop ID `L` with no `<loop directory>/L/state.json`, when the watcher runs with `L`, then it prints one line, `no loop state for L`, and exits 2.
- **AC15.** Given a loop state whose first read does not parse as JSON, as when `loop.js` is partway through rewriting it in place, and whose next read parses, when the watcher prints a snapshot, then the snapshot draws the parsed state and the watcher exits 0.
- **AC16.** Given a loop state that never parses as JSON, when the watcher runs without `--follow`, then it reads the file at most 5 times, about 100 ms apart. It then prints one line naming the state file as unreadable and exits 1.
- **AC17.** Given the watcher following a loop with `--follow`, when one interval's reads of the state never parse, then the watcher keeps the last view it drew, does not exit, and draws again from the next read that parses.

**What it draws**
- **AC18.** Given a loop state whose `steps[]` has 5 entries, 2 of them ticked, when the watcher prints a snapshot, then the snapshot has one progress bar for the plan. The bar reads `2/5` and names the plan path recorded in the state.
- **AC19.** Given a loop state whose `steps[]` has 5 entries, when the watcher prints a snapshot, then each of the 5 step numbers appears on exactly one step line, the lines are in the order of `steps[]`, and there is no step line for any other number.
- **AC20.** Given a loop state whose plan file holds `- [ ] **Step 2 — Add the parser**`, when the watcher prints a snapshot, then Step 2's line shows the title `Add the parser`.
- **AC21.** Given a loop state whose plan file no longer exists at the recorded path, when the watcher prints a snapshot, then every step line is drawn with its number and status but no title, and the watcher exits 0.
- **AC22.** Given a loop state where Step 1 is ticked, when the watcher prints a snapshot, then Step 1's line shows `done`.
- **AC23.** Given a loop state where Step 2 has a `running[]` entry with mode `main`, when the watcher prints a snapshot, then Step 2's line shows `running` and `main`.
- **AC24.** Given a loop state where Steps 2 and 3 each have a `running[]` entry with mode `worktree`, when the watcher prints a snapshot, then the lines for Steps 2 and 3 each show `running` and `worktree`.
- **AC25.** Given a loop state where Step 2's number is in `pending[]`, when the watcher prints a snapshot, then Step 2's line shows `applying`.
- **AC26.** Given a loop state where Step 3 is not ticked and has a `finished[]` entry with `result` `failed`, when the watcher prints a snapshot, then Step 3's line shows `failed`.
- **AC27.** Given a loop state where Step 3 is not ticked and has a `finished[]` entry with `result` `timeout`, when the watcher prints a snapshot, then Step 3's line shows `timeout`.
- **AC28.** Given a loop state where Step 4 has `Depends on: 2, 3`, neither Step 2 nor Step 3 is ticked, and Step 4 has no other status, when the watcher prints a snapshot, then Step 4's line shows `waiting on 2, 3`.
- **AC29.** Given a loop state where Step 3 has no `Depends on:` line, Step 1 is ticked and Step 2 is not, when the watcher prints a snapshot, then Step 3's line shows `waiting on 2`, naming only the step it still waits for.
- **AC30.** Given a loop state where Step 5 is not ticked, not running, not applying, not failed and not timed out, and every step it waits for is ticked, when the watcher prints a snapshot, then Step 5's line shows `ready`.
- **AC31.** Given a loop state whose `causes[]` holds one cause with `kind` `conflict`, `step` 3 and a `message`, when the watcher prints a snapshot, then the snapshot shows that cause's kind, its step number and its message.
- **AC32.** Given a loop state that has ended with `ended.code` 4, when the watcher prints a snapshot, then the snapshot says that the loop has ended and shows code 4.

**Elapsed time and the `started_at` field**
- **AC33.** Given a plan that `loop.js start` has accepted, when `loop.js next` starts a step, then that step's `running[]` entry carries a `started_at` field. The field holds an ISO 8601 UTC timestamp in the same format as the state's `created_at`.
- **AC34.** Given a running step whose `running[]` entry has a `started_at`, when `loop.js finish` records its result (`met`, `failed` or `timeout`), then the step's `finished[]` entry carries that same `started_at` and a `finished_at` field. `finished_at` holds the time `finish` ran, in the same format as `created_at`, and is not earlier than `started_at`.
- **AC35.** Given a running step whose `running[]` entry has no `started_at`, as a state written before this feature has, when `loop.js finish` records its result, then its `finished[]` entry carries a `finished_at` and no `started_at`, and `finish` prints the same answer as it would for a step with one.
- **AC36.** Given the loop state after AC33, when it is compared with the state the same `loop.js` commands write without this feature, then the only differences are the `started_at` field on `running[]` entries and the `started_at` and `finished_at` fields on `finished[]` entries, and the state's `version` is still 1. Every other `loop.js` subcommand prints the same JSON object on stdout as before, except that the `usage` text it carries gains the `watch` line. `bash skills/ai-layout/scripts/check-loop.sh` exits 0 with its existing assertions unchanged.
- **AC37.** Given a loop state where Step 2 is running and its `running[]` entry has a `started_at` 252 seconds before the snapshot is drawn, when the watcher prints a snapshot, then Step 2's line shows `4m12s`. An elapsed time under a minute is drawn as `<s>s`, such as `37s`. An elapsed time of an hour or more is drawn as `<h>h<mm>m<ss>s`, such as `1h04m12s`.
- **AC38.** Given a loop state where Step 2 is running and its `running[]` entry has no `started_at`, as a state written before this feature has, when the watcher prints a snapshot, then Step 2's line shows its elapsed time as unknown. Every other line is drawn as AC18–AC32 say, and the watcher exits 0.
- **AC39.** Given a loop state where Step 1 is done, Step 2 failed and Step 3 timed out, and each of their `finished[]` entries has a `started_at` and a `finished_at` 252 seconds later, when the watcher prints a snapshot, then each of the three lines shows the duration `4m12s`, in the format AC37 describes.
- **AC40.** Given a loop state where Step 1 is done and its `finished[]` entry has no `started_at`, or has no `finished_at`, when the watcher prints a snapshot, then Step 1's line shows its duration as unknown, every other line is drawn as AC18–AC32 say, and the watcher exits 0.
- **AC41.** Given a loop state where Step 1 is ticked and has no `finished[]` entry, as when it was ticked before the loop started, when the watcher prints a snapshot, then Step 1's line shows `done` and no duration.
- **AC42.** Given a running loop whose `created_at` is 10 minutes before the snapshot, when the watcher prints a snapshot, then the snapshot shows the loop's total elapsed time as `10m00s`. Given an ended loop, the total is measured from `created_at` to `ended.at`.

**Default view and `--details`**
- **AC43.** Given a loop state where a worktree step's `running[]` entry has `worktree` `ai-factory/runs/tmp/worktrees/W-S2`, a `finished[]` entry has `output` `SECRET-MARKER`, and neither string occurs in any cause message, when the watcher prints a snapshot without `--details`, then neither string appears in its output.
- **AC44.** Given the loop state of AC43, when the watcher prints a snapshot with `--details`, then Step 2's line, or a line under it, shows its worktree path. The saved output of each step with a `finished[]` entry that has `output` is shown under that step.
- **AC45.** Given a loop state whose cause message, step `output` and plan step title contain ESC (U+001B), BEL (U+0007), CR (U+000D), DEL (U+007F), the C1 control CSI (U+009B), another C1 control (U+0085) and a bidirectional override (U+202E), alongside a Cyrillic title (`Перевірка Л`, whose UTF-8 bytes include `0x9b`), when the watcher prints a snapshot, with or without `--details`, then no terminal control character appears in the output, except the ANSI escape sequences that live mode itself writes, and the Cyrillic title is printed intact, byte for byte (R2, R3). In `--details` output, newlines inside a step's saved output are kept as line breaks. Every other printed string from the state or the plan is drawn on one line.

**Terminal modes**
- **AC46.** Given live mode and a running loop, when the watcher runs with `--follow` and `loop.js` then ticks one more step in the loop state, then within 2 seconds the watcher redraws in place without being restarted, and the bar's ticked count goes up by one. It redraws once a second.
- **AC47.** Given live mode and the watcher following a running loop, when the loop state records that the loop has ended, then the watcher draws the final view once, including every cause in `causes[]`, and exits 0.
- **AC48.** Given live mode and the watcher following a running loop, when it receives SIGINT (Ctrl-C), then it exits 0, writes the sequence that shows the cursor again, and leaves the terminal on a new line.
- **AC49.** Given plain mode, when the watcher runs with or without `--follow` and with or without `--details`, then its output contains no ANSI escape sequence. This holds in each plain-mode case: stdout not a TTY, `TERM=dumb`, and `NO_COLOR=1` on a TTY.
- **AC50.** Given plain mode and a running loop, when the watcher runs with `--follow`, then it prints a snapshot at once and a new snapshot only after the bytes of `state.json` have changed. When the state records that the loop has ended, it prints the final snapshot, including every cause in `causes[]`, and exits 0.
- **AC51.** Given live mode or plain mode, when the watcher runs without `--follow`, then it prints one snapshot and exits.
- **AC51a.** Given the watcher, when it decides how wide to draw, then it uses, in this order: `--width <n>`; else the `COLUMNS` environment variable when it is a whole number; else, on a TTY, the terminal's own width; else 100. Every line it prints is at most that many characters wide: step titles are cut and end in `…` to fit, and the bar shrinks to fit. Widths below 40 are drawn at 40. Given `--width` with a value that is not a whole number from 40 to 500, it refuses in one line plus usage, reads nothing and exits 2, as AC13 does for other bad options. Given `--width 60` with a 72-character title, the step's line is at most 60 characters and its title ends in `…`. This lets another drawing surface, such as the ASD-008 pane, run the plain-mode watcher at its own width (ASD-008 exploration, open question 7).
- **AC52.** Given the watcher with `--follow` on a loop that has already ended, when it runs, then it prints the final view once and exits 0.
- **AC52a.** Given the watcher with `--follow` on loop `L` whose `state.json` is deleted while it follows, when the next interval finds no file, then it rereads with the bounds of AC16 (at most 5 reads, about 100 ms apart); if the file is still missing it prints one line, `loop state for L is gone`, and exits 1 (live mode restores the cursor first). If the file reappears within those reads, it keeps following with no message (R10).
- **AC52b.** Given the watcher with `--follow` on a loop that has not recorded `ended`, and whose `state.json` has not changed for longer than that loop's `step_timeout` minutes (30 by default), when it draws, then the view adds one line naming how long since the last update, for example `no update for 31m — the loop may have stopped; Ctrl-C to quit`; it keeps following and does not exit on its own; the line disappears on the first draw after `state.json` changes. In plain mode the line is printed once when the stall begins, not on every interval, and printed again only after a change and a new stall (R10).

**Read-only**
- **AC53.** Given a running loop whose `state.lock` is held by another process, when the watcher prints a snapshot, then it prints the snapshot without waiting for the lock, and the lock file is unchanged afterwards.
- **AC54.** Given a loop state in a git repo with a clean working tree, when the watcher runs, with and without `--follow` until the loop ends, then every file under the loop directory and the plan file are byte-for-byte unchanged afterwards. No new file exists under `ai-factory/`, and `git status --porcelain` is still empty.
- **AC55.** Given a running loop with a ready step, when the watcher follows it for 3 intervals and no other process runs `loop.js`, then `running[]`, `pending[]`, `finished[]`, `causes[]` and every step's `done` are unchanged. The watcher starts, finishes, applies and ends nothing.
- **AC56.** Given the repo of ASD-006's AC9, built by `bash skills/ai-layout/scripts/check-current.sh fixture <dir>` (ASD-006's fixture builder), with a running loop's directory under the loop directory, when `node skills/ai-layout/scripts/current.js <dir>` (what `/fc:current` runs) runs before and while the watcher follows that loop, then both outputs are identical. `bash skills/ai-layout/scripts/check-current.sh` (ASD-006's check) exits 0.

**Headless**
- **AC57.** Given the feature's diff, when it is read, then `skills/ai-layout/templates/ai-factory/make/runner.js` is byte-for-byte unchanged.
- **AC58.** Given `skills/ai-layout/templates/ai-factory/tasks/loop.md`, when it is compared with its version on the `main` this feature branches from, then exactly one line has been added. That line tells the developer how to start the watcher in a second terminal, naming `make -f ai-factory/make/ai.mk loop-watch` and the loop ID. No other line changed.

**Implementation boundary**
- **AC59.** Given `skills/ai-layout/templates/ai-factory/make/ai.mk`, when it is read, then it has a `loop-watch` target, listed in `.PHONY`, that runs `node ai-factory/make/loop.js watch`. It passes `LOOP` as the loop ID when it is set, `--follow` when `FOLLOW=1`, and `--details` when `DETAILS=1`. With none of them set, it passes no argument. `LOOP`, `FOLLOW` and `DETAILS` are captured with `override NAME := $(value NAME)` and reach Node only through the environment, as every other variable in `ai.mk` does; the recipe never expands them into the command line. Given `make loop-watch 'LOOP=$(shell touch pwned)'` or `make loop-watch 'LOOP=x; touch pwned'`, then no file `pwned` is created, and `loop.js watch` refuses the value as a malformed loop ID (AC13), exit 2 (R1).
- **AC60.** Given the feature's diff, when it is read, then the watcher's code is in `skills/ai-layout/templates/ai-factory/make/loop.js`. No new file is added under `skills/ai-layout/templates/ai-factory/make/`, and nothing was edited through the `ai-factory/make/` symlink.
- **AC61.** Given `loop.js`'s source, when its `require` calls are read, then each one names a Node built-in module or a file under `skills/ai-layout/templates/ai-factory/make/`. No `package.json` dependency is added.
- **AC62.** Given the feature's diff, when it is read, then `hooks/hooks.json`, everything under `skills/ai-hooks/`, `make/lifecycle-events.js`, `make/delivery-status.js`, `skills/ai-layout/scripts/state.sh`, `commands/state.md`, `commands/current.md` and ASD-006's listing script `skills/ai-layout/scripts/current.js` are byte-for-byte unchanged.

**Docs**
- **AC63.** Given `docs/commands/_notes/watch.md`, when it is read, then it has non-empty `## Usage`, `## Examples`, `## Writes` and `## Refuses or asks` sections. `docs/commands/_notes/_groups.md` lists `watch` in the `Build and verify` group, next to `loop`. `node skills/ai-layout/scripts/sync-docs.js` generates `docs/commands/watch.md`, and `bash skills/ai-layout/scripts/check-docs.sh` exits 0.
- **AC64.** Given `docs/commands/_notes/loop.md`, when it is read, then it has a line that points at `/fc:watch` and `make -f ai-factory/make/ai.mk loop-watch` for following a running loop.
- **AC65.** Given `docs/headless-ci.md`, when it is read, then it shows `make -f ai-factory/make/ai.mk loop-watch LOOP=<loop id>` as the way to print a loop snapshot in CI.
- **AC66.** Given `ai-factory/docs/workflow.md`, when its section on `/fc:loop` in "4. The main loop" is read, then it mentions the watcher, `/fc:watch` and `make loop-watch`.
- **AC67.** Given every doc that states the number of `/fc:*` commands, when `bash skills/ai-layout/scripts/check-risk.sh` runs, then each stated count equals the number of files in `commands/`, which now includes `watch.md`, and the check exits 0. No check compares a count with a literal.

**Checks and release (ai-factory/docs/definition-of-done.md)**
- **AC68.** Given the check suite, when it is read, then a check (a new `check-loop-watch.sh` or an extension of `check-loop.sh`) renders loop-state fixtures and asserts AC1–AC4 and AC10–AC55, including AC51a, AC52a and AC52b.
- **AC69.** Given the full check suite (`skills/ai-layout/scripts/check-*.sh` and `skills/ai-hooks/fixtures/check-*.sh`), when each check is run directly, then every one exits 0.
- **AC70.** Given `CHANGELOG.md`, when its `6.0.0` entry is read, then the entry sits above the `5.2.0` entry for ASD-006. It describes `loop.js watch`, `/fc:watch`, `$fc-watch`, the `make loop-watch` target, the `started_at` and `finished_at` fields and the new line in `tasks/loop.md`. It states that the change is breaking for adopted repos because it changes templates (`loop.js`, `ai.mk` and `tasks/loop.md`), that this is why the release is a major one, and that adopted repos pick it up with `/fc:sync-sdlc`.
- **AC71.** Given the release, when `bash skills/ai-layout/scripts/check-versions.sh` runs, then it exits 0, with every manifest and the `docs/README.md` version line on `6.0.0`.

## Out of scope
- A view of a single `/fc:run` session, or of any agent outside a `/fc:loop`. The watcher reads loop state only, and no hook records that a subagent has started (exploration question 3, settled by the chosen option).
- Where a delivery stands in the explore → spec → plan → test → run → review → report pipeline, and any change to `/fc:current` (ASD-006) or `/fc:state` (Option C, not chosen).
- A Claude Code status line or any other in-session live view (Option B), and any file under `.claude/`. `/fc:watch` in a session prints one snapshot only.
- Lifecycle events, a subagent-start hook, or any change to the hooks or the lifecycle schema (Option D).
- Progress within a step, such as the implementer's tool calls or the run log. A step's saved output is shown only after it finished, and only with `--details`.
- Any write by the watcher: starting, stopping, ticking, finishing, applying or ending a step or a loop, taking or clearing `state.lock`, and cleaning up loop directories or worktrees.
- Progress printed by the headless runner under `make ai TASK=loop`: `runner.js` is unchanged.
- A `fc-loop-state` schema version 2. Every new field is additive.
- An npm progress-bar or terminal library.

## Effort and risk
Effort **L**.
- Size is L: a new subcommand, a new plugin command with its generated Codex skill, a new make target and a new or extended check with state fixtures, across more than 5 files. The files are `loop.js`, `ai.mk`, `tasks/loop.md`, `commands/watch.md`, `codex-skills/fc-watch/SKILL.md`, the check and its fixtures, the notes pages and `_groups.md`, the generated docs, `headless-ci.md`, `workflow.md`, `CHANGELOG.md` and the version files.
- Uncertainty is M: the behaviour is settled, and reading a JSON file and drawing text is a known pattern. `loop.js` already defines every state the view draws. The minor unknowns are torn reads, since `writeState` truncates and rewrites `state.json` in place rather than renaming it; in-place redraw and cursor restore on SIGINT; and testing live mode without a real TTY.

Time ranges:
- `dev 9–15 h (assumption: the snapshot renderer with statuses, elapsed times and control-character stripping takes 3–4 h; follow in live and plain mode with SIGINT handling 2–3 h; loop selection, error cases, started_at, finished_at and step durations 1–3 h; the fixture check 2–3 h; /fc:watch, the Codex skill, ai.mk with its LOOP, FOLLOW and DETAILS switches, tasks/loop.md, docs, CHANGELOG and the version bump after rebasing onto ASD-006 1–2 h)`
- `/fc:run ~60–120 min (assumption: 5–7 plan steps, with the renderer, follow modes, selection and errors, the command surface and the docs and release split into separate steps)`

Risk categories:
- Authorization: **absent**. It reads local files under `ai-factory/runs/tmp/loop/` and the plan in the developer's own repo; no access path changes.
- Data exposure: **present**. The default view prints plan step titles and stop-cause messages, and a cause message can embed a worktree path or git error text. `--details` adds worktree paths and saved implementer output, which can be large or hold secrets the agent echoed. It is opt-in and stays out of the default view (AC43), and `make loop-watch` passes it only with `DETAILS=1` (AC4), so a CI log gets saved output only when a job asks for it.
- Secrets: **absent**. The feature reads, writes and passes no credential of its own. Output that an agent may have echoed is covered under data exposure.
- Injection: **present**. The loop ID argument becomes a file path; it is checked against `LOOP_ID` before any read (AC13). Strings from the state and the plan are written to a terminal, where control sequences would act; they are stripped (AC45). `/fc:watch` appends the developer's argument to a shell command the model runs, as `/fc:state` does.
- Dependency/supply chain: **absent**. Node stdlib only (AC61).
- Migrations: **absent**. `started_at` and `finished_at` are additive, the schema stays version 1, and a state without them reads as unknown elapsed time or duration (AC38, AC40).
- Rollback: **absent**. Reverting removes a reader, a command, a make target, one task line and two additive fields. `loop.js` ignores fields it does not read, so states written with `started_at` and `finished_at` stay readable.
- Blast radius: **present**. `loop.js`, `ai.mk` and `tasks/loop.md` are templates that reach every adopted repo on `/fc:sync-sdlc`, which is why the release is a major one (6.0.0). The watcher, and the new fields that `next` and `finish` write, live in the same file as the scheduler that every `/fc:loop` runs through, so a fault in `loop.js` breaks `/fc:loop` in every adopted repo, not just the view.

`/fc:start` risk triggers:
- Uncertain requirements: **absent**. The developer settled every question the spec raised: the surface and make switches, selection, error cases, follow, terminal modes, labels, content, elapsed times and durations, headless use and the release.
- Authorization: **absent**. No access path changes.
- Public contracts: **present**. There is a new `/fc:watch` command, a new `$fc-watch` Codex skill, a new `loop.js watch` subcommand, a new `make loop-watch` target, a new line in `tasks/loop.md` and new `started_at` and `finished_at` fields in the `fc-loop-state` schema. Adopted repos receive all of them.
- Migrations: **absent**. No data or layout move; the fields are additive.
- Dependencies: **absent**. No new package. Landing after ASD-006 is a release dependency, not a package.
- Service ownership: **absent**. A single plugin repo, with no fleet boundary.

## Open questions
The open major and blocker findings of `ai-factory/risks/ASD-007-loop-watch.md` (assessed 2026-11-02; no blocker):
1. R1 (major, injection): `LOOP` in the new make target. **Resolved in the spec 2026-11-02:** AC59 now requires the `$(value …)` / environment pattern and tests both injection forms.
2. R2 (major, injection) and R3 (minor): stripping by byte would corrupt UTF-8 text, and the strip list was incomplete. **Resolved in the spec 2026-11-02:** the terms define controls as decoded characters (C0 except LF, DEL, C1, bidirectional controls) and AC45 adds a Cyrillic fixture.
3. R6 (major, blast radius): the watcher lives in `loop.js`, which every `/fc:loop` runs through. For `/fc:plan`: keep the watch code inside `main()`'s `watch` branch, keep the module importable and `check-loop.sh` unchanged.
4. R7 (major, blast radius): AC56, AC62, AC67 and AC70 assume ASD-006 (5.2.0) has merged. For `/fc:plan`: the first step refuses to start until 5.2.0 is on `main`.
5. R8 (major, blast radius): live mode (AC46–AC48) needs a real terminal to test, Node has no pseudo-terminal and no dependency is allowed. For `/fc:plan`: choose the test method up front.
6. R10 (minor): `--follow` on a loop that never records `ended`, or whose `state.json` disappears. **Answered 2026-11-02 by the developer:** a vanished state exits 1 after bounded rereads (AC52a); a stalled loop shows a "no update for …" line past its `step_timeout` and keeps following until Ctrl-C (AC52b).

## Data touched
- Read: `ai-factory/runs/tmp/loop/<loop id>/state.json`: `loop_id`, `plan`, `created_at`, `steps[]` (`number`, `id`, `done`, `explicit`, `depends`), `running[]` (`step`, `mode`, `worktree`, and the new `started_at`), `pending`, `finished[]` (`step`, `mode`, `result`, `worktree`, `output`, and the new `started_at` and `finished_at`), `causes[]` (`kind`, `step`, `message`) and `ended` (`at`, `code`). `worktree` and `output` are printed only with `--details`.
- Read: every `state.json` under `ai-factory/runs/tmp/loop/` when no loop ID is given, for selection and the listing table.
- Read: the plan file named in the state's `plan`, for step titles only.
- Written by `loop.js`: `running[].started_at`, set when `loop.js next` starts a step, and `finished[].started_at` (copied from the running entry when it has one) and `finished[].finished_at`, set when `loop.js finish` records a result. No other field of `fc-loop-state` or `fc-loop-outcome` changes, and `version` stays 1.
- Written by the watcher: nothing.
- No change to the plan or spec format, the run log, lifecycle events, contracts or `state.lock`.

## Routes touched
- CLI: `node ai-factory/make/loop.js watch [<loop id>] [--follow] [--details]` (new subcommand). `loop.js`'s usage text gains its line.
- Make target: `make -f ai-factory/make/ai.mk loop-watch [LOOP=<loop id>] [FOLLOW=1] [DETAILS=1]` (new, in the `ai.mk` template that adopted repos receive).
- Slash command: `/fc:watch [<loop id>] [--details]` (new, plugin-level, `commands/watch.md`), printing one snapshot.
- Codex skill: `$fc-watch` (new, `codex-skills/fc-watch/SKILL.md`, generated by `sync-codex-skills.js`).
- Headless `TASK=` names: none added; `make ai TASK=loop` is unchanged.

## Components likely involved
- `skills/ai-layout/templates/ai-factory/make/loop.js`: the `watch` subcommand (selection, reading with bounded rereads, rendering, live and plain follow, SIGINT handling, control-character stripping), its usage line, `next()` adding `started_at` to the `running[]` entry it pushes, and `finish()` adding `started_at` and `finished_at` to the `finished[]` record.
- `skills/ai-layout/templates/ai-factory/make/ai.mk`: the `loop-watch` target with its `LOOP`, `FOLLOW` and `DETAILS` switches, and its `.PHONY` entry.
- `skills/ai-layout/templates/ai-factory/tasks/loop.md`: one line on starting the watcher.
- `commands/watch.md` (new) and `codex-skills/fc-watch/SKILL.md` (generated by `skills/ai-layout/scripts/sync-codex-skills.js`).
- `skills/ai-layout/scripts/check-loop.sh` or a new `check-loop-watch.sh`, with state fixtures under `ai-factory/runs/tmp/` as `check-loop.sh` already builds them.
- Docs: `docs/commands/_notes/watch.md` (new), `docs/commands/_notes/_groups.md`, `docs/commands/_notes/loop.md`, the pages `skills/ai-layout/scripts/sync-docs.js` generates (`docs/commands/watch.md`, `docs/commands.md`), `docs/headless-ci.md`, `ai-factory/docs/workflow.md`, and any doc whose command count `check-risk.sh` derives from `commands/`.
- `CHANGELOG.md` and the version files that `check-versions.sh` reads.
- Unchanged by design: `hooks/hooks.json`, `skills/ai-hooks/`, `make/lifecycle-events.js`, `make/delivery-status.js`, `make/runner.js`, `skills/ai-layout/scripts/state.sh`, `commands/state.md`, and ASD-006's `/fc:current` files.
