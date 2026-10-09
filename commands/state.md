---
description: List this repo's outstanding specs and plans, each outstanding plan shown with its incomplete steps, or show one contract delivery's status with --delivery <id>
allowed-tools: Bash, Read
---
Report what is still outstanding in this repo, or one contract delivery's status.
**Change nothing.** Do not edit a file, tick or untick a checkbox, move a plan between
`ai-factory/plans/` and its `done/` subdirectory, start a step, hand one to `/t4:run`, or run
tests, review, a report or `/t4:continue` — this lists work, it never does any, and being
read-only is what makes it safe to run before anyone knows what is left. Do not ask the developer anything: this
reports, it does not interview, and it must behave the same in a headless run.
**Launch no agent.** Start no subagent, background task or workflow, and invoke no other command
or skill — the one Bash call in step 1 is the only tool this command needs. A table of
outstanding steps is not a request to start one, however obvious the next one looks, and however
many `/t4:run` hand-offs came before it in this session.

1. Run:
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/scripts/state.sh" . "${CLAUDE_PLUGIN_ROOT}"`
   It does the scan, decides what is outstanding and prints the rows. Every listing, every
   refusal and every delivery status exits 0; a non-zero exit means the script, or under
   `--delivery` the workspace's delivery-status helper, failed at runtime — report its stderr
   line as that failure, never as a status or an empty answer.

1b. **Hand the developer's argument to that command.** Whatever the developer typed after
   `/t4:state` is the `Context:` line at the very end of this prompt. Append it verbatim, after
   the second path, and run the command with it — so `/t4:state --done` runs that same command
   with `--done` on the end, and `/t4:state` with nothing typed runs it exactly as written above.
   Pass the argument through unchanged: do not interpret it, do not translate it into a
   different flag, do not silently drop one you do not recognise, and do not answer it yourself.
   Pass `--delivery <id>` the same way, the ID exactly as typed. The script decides what every
   argument means, including the ones it refuses: `--done` and `--next` do not combine,
   `--delivery` combines with neither and needs exactly one delivery ID, a missing workspace
   helper is answered with `/t4:sync-sdlc` guidance, and a flag it does not recognise is named
   back with the ones it does take. It answers each of those in one line, and that line is the answer, not an error to
   route around — do not re-run without the flag, and do not fall back to the default listing on
   the developer's behalf. An argument accepted here and never passed on is the worst outcome of
   all: the command would look like it had honoured the flag while listing something else
   entirely.

2. The script decides; you present. Do not re-read `ai-factory/specs/` or `ai-factory/plans/` to
   check its answer, do not open a plan to count its checkboxes, and do not add an item it left
   out or drop one it listed. Under `--delivery`, likewise do not open the spec, plan, sidecars,
   evidence or reports to check, complete or reinterpret its rows. It reads the files on disk, so its answer is the same twice running
   and the same headless; a listing reassembled from this session's memory of earlier chat is
   neither.

3. Present the rows as a table. One header row naming the columns, then one row per row the
   script emitted, and the same columns in the same order for every row — including the rows that
   have nothing in a field. A paragraph of prose describing the work is not a table and does not
   replace one.

4. **Which columns, provisionally.** Render the header the script actually printed — the mode is
   whichever header line came back. The listing modes print a tab-separated header line and then
   tab-separated rows carrying six fields — `kind`, `number`, `state`, `path`, `step`, `detail`.
   Render them as they come: one column per field, in the order the header line gives, with the
   header line's own names. This is deliberately provisional. Which of the six become columns, in
   what order, and whether a spec row and a plan-step row share one column set or the table is
   sectioned by kind, is an open question on `ai-factory/specs/0010-t4-state.md` and is not
   settled here. So do not invent a column, merge two, reorder them or drop one on your own
   judgement — when the answer lands, this instruction is the one place it changes.

   Under `--delivery` the first line is `field` and `value` instead: a two-column table with one
   row per later line, in the order printed, a field repeated (such as `source`) kept as separate
   rows. Do not reshape it into the listing's six columns, merge or drop rows, or infer a phase,
   next action, approval or verified criterion its values do not state — `unknown`, `remaining`
   and `none recorded` stay exactly as written. Attested criteria stay apart from verified ones.

5. If the script answers in a single line rather than a table — nothing to list because the repo
   has no layout, nothing outstanding because every spec and plan is complete or closed, an argument it
   refused, or a delivery it or its helper refused — pass that line through as it stands and stop. An empty or refused result is a valid
   answer, not an error and not silence, so do not pad it, do not go looking for work it missed,
   and do not turn it into a table with no rows.

6. A row whose `state` is `unknown` is an artefact the script could not read or could not
   interpret, and its `detail` field carries the reason. Keep both: show the row with the rest,
   with its reason beside it. Never quietly promote it to complete, never leave it out because it
   spoils the table, and never guess at what its steps would have said.

   Under `--done`, preserve `closed` as distinct from `complete`: the recorded steps include
   explicit withdrawals, so there is no pending work but not all work was executed. The script
   reads numbered `**Result — Step N withdrawn; …**` records; do not infer withdrawals yourself.

7. After the table, at most two lines of your own, and only where they change what the developer
   does next. For a listing: how many items the table lists — outstanding ones by default, finished ones under
   `--done`, never a count of something it did not list — and whether anything came back
   `unknown`. An
   `unknown` is not a pass — say what it would take to answer it. For a delivery status: nothing
   beyond what its rows say — no next step of your own. Add nothing else: no estimate,
   no priority order, no assignee, and no offer to start a step.

Do not print the script's raw output and then summarise it. One table.

Then end your turn. Nothing follows the table and its two lines — no tool call, no agent, no
step started — until the developer types again.

Context: $ARGUMENTS
