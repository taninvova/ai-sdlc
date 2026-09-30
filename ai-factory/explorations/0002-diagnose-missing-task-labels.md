# Exploration 0002 — diagnosing missing `task` labels in the CSV run logs

## Request
Two read-only ways to tell a developer *why* `task` is empty in `ai-factory/runs/`: (a) a check in
`/t4:doctor`, or (b) an offline audit of the existing CSVs. The live-validation case plan 0007 left
open (Step 7, withdrawn).

## What exists today
- `runs/log.csv`: 19 rows on the **pre-0007 16-column header** (no `agent`), `task` empty in all 19.
  `log.pending.csv` has the 17-column header — one real `session` row with `task=explore`, one
  fixture `agent` row with `task` empty.
- `log-task.js` writes `.task.<session_id>`; `_common.js` `task()` returns `""` on ENOENT.
  `session-stop.js:36` and `subagent-stop.js:37` look it up by `ev.session_id`.
- Empty is ambiguous by design: no `/t4:` prompt typed (AC10, legitimate); a stale cached plugin
  lacking the `UserPromptSubmit` registration (R12); a subagent `session_id` unlike the parent's;
  last-writer-wins (Q9).
- `skills/ai-layout/scripts/doctor.sh`: read-only bash, one `[ok]/[finding]/[unknown]` line plus a
  remedy, pinned by `check-doctor.sh`. It reads nothing under `runs/`; `commands/doctor.md` forbids
  writing. `runs/` is dont-touch, so both options are read-only regardless.

## Options
**A — a `task` section in `doctor.sh`.** ~20 lines: is `UserPromptSubmit` registered in the copy a
session loads, does a `.task.*` exist, do the newest pending rows carry a task. Plus a
`check-doctor.sh` case and a line in `commands/doctor.md`. **S**, existing idiom, no ADR. Risk: the
fixture must not read the developer's own runs.

**B — an offline audit script.** Dependency-free Node shaped like `templates/…/make/log.js`, counting
empty `task` across the three CSVs by `source` and `session_id`. **M**: new entry point, template
copy, `make` target, fixture, adapter sync. Risk: on today's data it can only say "unattributable",
and it overlaps the unwritten spec 0008.

## Comparison
| Option | Effort | Risk | Reversible | Fits architecture | Recommend |
|---|---|---|---|---|---|
| A | S | low | yes, delete it | yes, the diagnosis surface | **yes** |
| B | M | medium | a template ships | partly, duplicates 0008 | later |

## Recommendation
**A.** The cause is a session condition — registration, `session_id`, no command typed — and doctor
is where those live; historical rows cannot answer it. Opinion: once `log.csv` holds hundreds of
17-column rows, B is cheaper, inside spec 0008.

## Open questions
1. Report on the session running doctor, or on every `.task.*` present?
2. Is an empty `task` on a `make` row ever a finding?
3. Compare working-tree `hooks.json` with the cached copy, when doctor reports cache drift already?

## Next
```
/t4:spec a read-only task-attribution check in /t4:doctor: whether UserPromptSubmit is registered in the plugin copy a session loads, whether ai-factory/runs/.task.<session_id> exists, and whether the newest log.pending.csv rows carry a task — one line with a remedy, plus a check-doctor.sh case; writes nothing, ignores 16-column rows
```
