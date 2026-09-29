---
description: List this repo's outstanding specs and plans, each outstanding plan shown with its incomplete steps
allowed-tools: Bash, Read
---
Report what is still outstanding in this repo. **Change nothing.** Do not edit a file, tick or
untick a checkbox, move a plan between `ai-factory/plans/` and its `done/` subdirectory, start a
step, or hand one to `/t4:run` — this lists work, it never does any, and being read-only is what
makes it safe to run before anyone knows what is left. Do not ask the developer anything: this
reports, it does not interview, and it must behave the same in a headless run.

1. Run:
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/scripts/state.sh" . "${CLAUDE_PLUGIN_ROOT}"`
   It does the scan, decides what is outstanding and prints the rows. It always exits 0; a
   non-zero exit means the script itself failed, which is itself worth reporting.

1b. **Hand the developer's argument to that command.** Whatever the developer typed after
   `/t4:state` is the `Context:` line at the very end of this prompt. Append it verbatim, after
   the second path, and run the command with it — so `/t4:state --done` runs that same command
   with `--done` on the end, and `/t4:state` with nothing typed runs it exactly as written above.
   Pass the argument through unchanged: do not interpret it, do not translate it into a
   different flag, do not silently drop one you do not recognise, and do not answer it yourself.
   The script decides what every argument means, including the ones whose rule is not settled
   yet — it answers those in one line, and that line is the answer, not an error to route
   around. An argument accepted here and never passed on is the worst outcome of all: the
   command would look like it had honoured the flag while listing something else entirely.

2. The script decides; you present. Do not re-read `ai-factory/specs/` or `ai-factory/plans/` to
   check its answer, do not open a plan to count its checkboxes, and do not add an item it left
   out or drop one it listed. It reads the files on disk, so its answer is the same twice running
   and the same headless; a listing reassembled from this session's memory of earlier chat is
   neither.

3. Present the rows as a table. One header row naming the columns, then one row per row the
   script emitted, and the same columns in the same order for every row — including the rows that
   have nothing in a field. A paragraph of prose describing the work is not a table and does not
   replace one.

4. **Which columns, provisionally.** The script prints a tab-separated header line and then
   tab-separated rows carrying six fields — `kind`, `number`, `state`, `path`, `step`, `detail`.
   Render them as they come: one column per field, in the order the header line gives, with the
   header line's own names. This is deliberately provisional. Which of the six become columns, in
   what order, and whether a spec row and a plan-step row share one column set or the table is
   sectioned by kind, is an open question on `ai-factory/specs/0010-t4-state.md` and is not
   settled here. So do not invent a column, merge two, reorder them or drop one on your own
   judgement — when the answer lands, this instruction is the one place it changes.

5. If the script answers in a single line rather than a table — nothing to list because the repo
   has no layout, or nothing outstanding because every spec and plan is complete — pass that line
   through as it stands and stop. An empty result is a valid answer, not an error and not
   silence, so do not pad it, do not go looking for work it missed, and do not turn it into a
   table with no rows.

6. A row whose `state` is `unknown` is an artefact the script could not read or could not
   interpret, and its `detail` field carries the reason. Keep both: show the row with the rest,
   with its reason beside it. Never quietly promote it to complete, never leave it out because it
   spoils the table, and never guess at what its steps would have said.

7. After the table, at most two lines of your own, and only where they change what the developer
   does next: how many items the table lists — outstanding ones by default, finished ones under
   `--done`, never a count of something it did not list — and whether anything came back
   `unknown`. An
   `unknown` is not a pass — say what it would take to answer it. Add nothing else: no estimate,
   no priority order, no assignee, and no offer to start a step.

Do not print the script's raw output and then summarise it. One table.

Context: $ARGUMENTS
