# Spec 0015 — Lifecycle telemetry

**Summary:** Record delivery-level duration, waits, retries, outcomes and attribution coverage as an opt-in event stream beside the existing accounting. Aggregate it without ever reporting a missing measurement as zero, and without changing the 17-column run log or `make cost`.

**Source:** The owner's P1 "Lifecycle telemetry" implementation plan (2026-09-30). It builds on the delivery IDs of spec 0013, and its export feeds the completion report of spec 0014.

## Scope and boundary

- **Opt-in.** Telemetry is off unless `ai-factory/contracts/config.json` sets `"lifecycle": {"enabled": true}`.
- **Storage.** Events stay local, under the gitignored `ai-factory/runs/lifecycle/`.
- **Out of scope.** No dashboard, remote collector, productivity ranking or budget enforcement.
- **Money.** Dollar values appear only in the new lifecycle interface, always with their provenance. A value that is not known is shown as unknown.

## Acceptance criteria

| ID | Given / When / Then |
|---|---|
| AC1 | Given lifecycle enabled or disabled, when hooks and the headless runner write the run log, then the rows and the `make cost` export are unchanged. |
| AC2 | Given runs and usage, when a delivery is aggregated, then its totals include only explicitly associated runs, and unattributed activity is visible. |
| AC3 | Given replayed hooks, copied transcripts, or a headless run whose child hooks also report, when aggregated, then no usage or retry is counted twice. |
| AC4 | Given parallel work, when aggregated, then elapsed time is an interval union, and agent effort is labelled separately and may exceed it. |
| AC5 | Given missing ends, unsupported events, invalid clocks or missing wait signals, when aggregated, then the affected metrics are partial or unknown, never fabricated. |
| AC6 | Given concurrent deliveries or delegated agents, when usage is attributed, then neither can overwrite the other's attribution; an ambiguous case stays unattributed. |
| AC7 | Given unknown model pricing, when cost is aggregated, then that portion is unknown, and zero-priced usage is distinct from missing pricing. |
| AC8 | Given a telemetry write failure, when a task, hook or headless run proceeds, then its outcome and edits are unaffected; diagnostics go to stderr, never to machine-readable stdout. |
| AC9 | Given any event, when stored, then it holds IDs, timings, outcomes and usage references only, never prompts, document contents, secrets or raw command output. |

## Defined behavior

- **Identity.** Each run, attempt, wait and event has a unique ID, and delegated work carries an explicit parent run ID. A run's delivery is taken only from an explicit `--delivery`, the headless `DELIVERY`, or its parent run.
- **Attribution.** Usage is attributed in only two ways:
  - a `T4_LIFECYCLE_RUN` inherited from a headless parent;
  - a session binding that the command hook observes when `lifecycle.js start` runs, combined with overlapping record timestamps.

  Anything else stays unattributed.
- **Retries.** A retry is another attempt of the same phase and step after a failure. An attempt after an interruption is counted as a resumption, and one after a success as a rerun.
- **Waiting** covers only explicit `wait-start` and `wait-end` intervals.
- **Timing.** A crashed run stays open. Durations use the monotonic clock within one process and wall clocks otherwise, and a negative duration is flagged `invalid_clock`.
- **Retention.** Pruning keeps every delivery that has a saved completion report, and records what it removed.

## Out of scope

Automatic wait detection, host signals that do not exist today, and remote collection.

## Open questions

- Codex's PostToolUse payload is not verified to carry command output. Until it is, interactive Codex session binding is a documented coverage gap.
