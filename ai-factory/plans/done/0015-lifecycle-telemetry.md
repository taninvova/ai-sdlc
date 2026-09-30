# Plan 0015 — Lifecycle telemetry

**Status:** Done. All seven steps are checked off, and the verification evidence and its limits are recorded below.

**Goal:** Add opt-in, delivery-level duration, retry, outcome and attribution-coverage telemetry beside the existing accounting, without changing `log.csv` or `make cost`.

**Spec:** `ai-factory/specs/0015-lifecycle-telemetry.md`

**Branch:** `feat/lifecycle-telemetry`, released as 2.7.0.

## Execution status — 2026-09-30

- **Checks.** `make check` passes. The new `skills/ai-layout/scripts/check-lifecycle.sh` has 13 cases:
  - the store copies are identical;
  - the writer and reader handle replay, validation, torn and unsupported files, 20 concurrent writers, symlink refusal and permission refusal;
  - hand-calculated interval unions, covering parallel runs, overlapping waits, active time and agent effort;
  - open runs, open waits, invalid clocks, monotonic clocks and empty deliveries all stay unknown;
  - retries, resumptions and reruns are counted separately;
  - attribution is explicit, including ambiguous overlap and unbound sessions;
  - pricing coverage is reported;
  - hook rows are byte-identical with lifecycle on, off and absent, and replays and copied transcripts are de-duplicated;
  - interactive binding works through the Bash hook;
  - headless runs show identity inheritance, outcomes, host-reported cost and hook de-duplication, with no prompt or output content in events;
  - `make cost` output is unchanged;
  - the export and retention work;
  - the completion report consumes the export.
- **Unchanged checks.** The existing accounting checks (`check-log-schema`, `check-usage`, `check-subagent-stop`, `check-codex`, `check-write-boundary`, `check-cost`) pass unchanged.
- **Commit layout.** Steps 1–2, 3–4 and 5–6 are committed in pairs because each pair shares its modules.
- **Not run.** Real-host smoke tests (a live Claude session and a live Codex session) were not run. Hook behaviour was exercised with synthetic hook payloads only. Codex session binding depends on a PostToolUse output field that has not been confirmed.
- **Release scope.** Monetary figures ship only as estimates or host-reported values, each with explicit provenance and an unknown remainder. No budget enforcement is added.

## Implementation sequence

- [x] **Step 1 — Specify identity propagation and fixtures.** AC2, AC6.
  - Run, attempt, wait and event IDs; explicit parent runs.
  - `DELIVERY`/`STEP` for headless runs, `T4_LIFECYCLE_RUN` for children, and explicit `lifecycle.js start` for interactive tasks.
  - **Verify:** the attribution cases in `check-lifecycle.sh`.
- [x] **Step 2 — Build the event writer and reader.** AC5, AC8, AC9.
  - `make/lifecycle-events.js`, with its hook mirror: one immutable, idempotent, atomically staged file per event, and a tolerant reader.
  - **Verify:** replay, concurrency, torn files, unsupported versions, traversal, symlink and permission cases.
- [x] **Step 3 — Instrument execution boundaries.** AC5, AC8.
  - The headless runner; six task procedures; the Bash hook binding.
  - Waits are recorded explicitly only.
  - **Verify:** runner success, failure and isolation cases; interactive binding.
- [x] **Step 4 — Link existing usage without changing its public schema.** AC1, AC3, AC9.
  - Stop and SubagentStop emit `usage_linked`, keyed by the unique claimed records.
  - Headless envelopes are superseded when the child's hooks report the same session.
  - **Verify:** identical rows on, off and absent; replay; copied transcripts; headless plus hooks.
- [x] **Step 5 — Implement metric aggregation.** AC4, AC5, AC6, AC7.
  - `make/lifecycle.js`: interval unions, retries, outcomes, coverage and cost provenance.
  - **Verify:** hand-calculated fixtures.
- [x] **Step 6 — Add exports and report integration.** AC1, AC7.
  - `make lifecycle` (human output and `t4-lifecycle-report` v1 JSON) and `make lifecycle-export` (telemetry v1).
  - `make delivery-report` consumes live numbers.
  - **Verify:** JSON stdout, the export contract, completion-report integration and unchanged `make cost`.
- [x] **Step 7 — Document retention and validate hosts.** AC1–AC9.
  - `lifecycle.js prune` keeps reported deliveries and marks pruned detail.
  - Docs and the 2.7.0 release.
  - **Verify:** `make check`. Real hosts: not run (see above).
