## Usage

Give one contract delivery ID (`d-YYYYMMDD-xxxxxx`). `/fc:continue` inspects that delivery's evidence read-only with `ai-factory/make/continue.js`, explains the next evidence-backed action and hands off to at most one existing task: `plan`, `test`, `run`, `review` or `report`. That task keeps its own questions, verification, report and stopping point; nothing is chained after it.

It needs artifact contracts enabled in the repo. Run it in an interactive session: there is no headless `TASK=continue`.

See also: [Feature workflow: coming back](../workflows/feature.md#coming-back-to-a-delivery), [workflow.md: Delivery status](../../ai-factory/docs/workflow.md#delivery-status).

## Examples

```
/fc:continue d-20261030-a1b2c3
```

The delivery ID is the `delivery_id` in the spec's `.contract.json` sidecar. `/fc:state --delivery <id>` shows one delivery's status without resuming it.

## Writes

Nothing itself: no artifact, sidecar, evidence, report, plan tick or workflow state. The one task it dispatches writes its usual output.

## Refuses or asks

- With no input, asks for the delivery ID and stops. A spec or plan path, or anything else that is not a delivery ID, is unsupported: it says so and stops.
- A quick delivery or a contracts-disabled workspace is unsupported: it reports the helper's reason and stops.
- With no `ai-factory/`, says the repo needs adoption; with `continue.js`, `models.js` or the destination task missing, reports template drift for `/fc:sync-sdlc`.
- When the evidence leaves a phase uncertain, asks you (for example whether gaps were tested) and re-inspects with your answer. It never answers or guesses for you; in a non-interactive run it reports the question and stops.
- Spec drift is `blocked`: it says which plan, tests, implementation, verification and review may need reconciling, and you reconcile before running it again. A `complete` delivery is reported ready for handoff, with no dispatch.
- Refuses `--task-model=<model>`; the destination runs under its own model policy.
