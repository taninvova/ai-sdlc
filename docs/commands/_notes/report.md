## Usage

Run `/fc:report` with a delivery ID after review, or any time you need to know where a delivery
stands. It needs artifact contracts. It runs `make -f ai-factory/make/ai.mk delivery-report DELIVERY=<id>`,
which reads only that delivery's contract sidecars, Markdown, evidence and optional telemetry.

The report gives:

- the status, `ready`, `incomplete`, `blocked` or `unverified`, with every reason and its evidence;
- one row per criterion;
- the changed files and the checks that actually ran;
- the review findings and the open follow-up;
- a draft MR description.

The exit code is 0 for `ready` and 1 for any other status; the report is still written. Exit 2 means
it could not be generated. With `ai-factory/assurance.json`, it then runs
`node ai-factory/make/assurance.js complete <id>` and says whether completion may be claimed.

See also: [Feature workflow: Report](../workflows/feature.md#10-report-artifact-contracts-enabled) and
[workflow.md: artifact contracts](../../ai-factory/docs/workflow.md#artifact-contracts-opt-in).

## Examples

```
/fc:report d-20260930-1a2b3c
/fc:report
```

## Writes

- `ai-factory/reports/<id>/completion.md` and `completion.json`.

It edits no source artifact and publishes nothing: no tracker comment, no MR, no commit. The MR
description inside the report is a draft for you.

## Refuses or asks

- With no argument, it lists the delivery IDs from `make -f ai-factory/make/ai.mk contracts JSON=1`
  with their state, asks which one to report on, and stops. It never guesses one.
- It never reruns checks to change the result and never edits the report.
- When the status is not `ready`, it names the command that addresses each reason (`make … verify`,
  `make … review DELIVERY=<id>`, `contracts.js init …`) and stops.
- It never claims completion while `assurance.js complete` exits non-zero.
- When `ai-factory/make/delivery-report.js` is missing, it reports that `/fc:sync-sdlc` shows the
  template drift, and stops.
