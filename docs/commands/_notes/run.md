## Usage

Run `/fc:run` with a plan path and one step. The `implementer` subagent implements only that step,
adds meaningful tests, and runs the step's exact verification commands for its declared phase:

- **`red`**: the documented missing-behaviour failures must appear.
- **`step`**: this step's checks and the regressions pass. Only the future-step failures the plan
  records may remain.
- **`final`**: every completion check passes.

It ticks the step's checkbox only once that phase is met. It never starts the next step. To run
every remaining step in one go, use [`/fc:loop`](loop.md).

With `ai-factory/assurance.json`, it first shows the preset and its effective requirements. A ticked
final step is still not a completed delivery: independent review and completion are decided
afterwards.

See also: [Feature workflow: Run](../workflows/feature.md#7-run-one-step-at-a-time) and
[workflow.md: the rules that make it work](../../ai-factory/docs/workflow.md#the-rules-that-make-it-work).

## Examples

```
/fc:run ai-factory/plans/PMB-003-csv-export.md step 2
/fc:run ai-factory/plans/PMB-003-csv-export.md 3
```

## Writes

- Source and test files for that step.
- One ticked box: that step's checkbox in the plan.
- With artifact contracts enabled, also the step's evidence, recorded with
  `make -f ai-factory/make/ai.mk verify DELIVERY=<id> STEP=S<N>` (with `PHASE=red` for a `red`
  step). A `final` step also records `make -f ai-factory/make/ai.mk verify DELIVERY=<id> PHASE=final`.
  The box is ticked only when each recording exits 0, and is unticked again if
  `make -f ai-factory/make/ai.mk contracts DELIVERY=<id>` does not then report `valid`.

## Refuses or asks

- With no argument, it asks which plan and which step and stops. When the plan is obvious, it names
  the unticked steps; it never starts one on its own.
- When a required check cannot run, a new regression appears, or red failures differ from their
  recorded causes, it leaves the step unticked. It relays the explanation and asks you how to
  proceed. Headless, it reports and stops.
- It never edits a path in `ai-factory/docs/dont-touch.md`; the guard hook blocks it.
- When the repo has no `ai-factory/` workspace, it reports that it needs `/fc:adopt-sdlc`.
